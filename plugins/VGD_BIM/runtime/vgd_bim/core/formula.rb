require 'bigdecimal'
require_relative 'measure'

module VGD
  module BIM
    # Công thức khối lượng do người dùng đặt cho một tag (cột mốc 3c), viết như công thức Excel, ví dụ "(Rộng + Sâu) x 2" hay "ROUNDUP(Rộng / 0,6; 0)".
    # Có: số, + - * /, so sánh (= <> < > <= >=), ngoặc, các số đo của dòng (mét, m², m³) và một số hàm Excel (FUNCTIONS) tính đúng như Excel.
    # Không bao giờ chạy mã Ruby: tự đọc từng ký hiệu rồi tính trên cây phép tính. Khi xuất Excel, cây được dịch lại thành công thức Excel (to_excel)
    # với số đo thay bằng ô của dòng, nên người dùng sửa số đo trên Excel là khối lượng tự tính lại.
    # Tên số đo và tên hàm không phân biệt hoa thường và dấu (Measure.normalize); "x" và "×" đứng riêng là dấu nhân; "1,05" là số thập phân;
    # dấu ";" (hoặc "," không nằm giữa hai chữ số) ngăn các đối số của hàm như Excel.
    module Formula
      MAX_LENGTH = 200
      MAX_DEPTH = 20
      # Tên số đo (đã chuẩn hóa, các chữ nối bằng "_") => khóa biến.
      NAMES = {
        'rong' => :w, 'w' => :w, 'width' => :w,
        'sau' => :d, 'd' => :d, 'depth' => :d,
        'cao' => :h, 'h' => :h, 'height' => :h,
        'dien_tich' => :area, 'dientich' => :area, 'area' => :area,
        'the_tich' => :volume, 'thetich' => :volume, 'volume' => :volume
      }.freeze
      LABELS = {w: 'Rộng', d: 'Sâu', h: 'Cao', area: 'Diện tích', volume: 'Thể tích'}.freeze
      # Hàm (tên chuẩn hóa => [tên Excel, số đối số ít nhất, nhiều nhất]).
      FUNCTIONS = {
        'round' => ['ROUND', 2, 2], 'roundup' => ['ROUNDUP', 2, 2], 'rounddown' => ['ROUNDDOWN', 2, 2], 'ceiling' => ['CEILING', 2, 2],
        'min' => ['MIN', 1, 30], 'max' => ['MAX', 1, 30], 'if' => ['IF', 2, 3], 'abs' => ['ABS', 1, 1], 'sqrt' => ['SQRT', 1, 1], 'pi' => ['PI', 0, 0]
      }.freeze
      COMPARE = %w[= <> < > <= >=].freeze

      # Lỗi khi tính (giống lỗi #DIV/0!, #NUM! của Excel): ô khối lượng để trống kèm ghi chú.
      class Undefined < StandardError; end

      # Cây phép tính của công thức, hoặc ArgumentError với lời giải thích cho người dùng.
      def self.parse!(text)
        raise ArgumentError, 'Hãy nhập công thức.' unless text.is_a?(String) && !text.strip.empty?
        raise ArgumentError, "Công thức dài tối đa #{MAX_LENGTH} ký tự." if text.length > MAX_LENGTH
        parser = Parser.new(tokenize(text.strip.sub(/\A=/, '')))
        tree = parser.comparison(0)
        raise ArgumentError, 'Dấu ";" chỉ dùng để ngăn các đối số của hàm.' if parser.peek&.first == :sep
        raise ArgumentError, "Công thức sai ở \"#{parser.peek_text}\"." unless parser.done?
        tree
      end

      # Biến có trong cây (để báo thiếu số đo).
      def self.variables(tree)
        case tree[0]
        when :var then [tree[1]]
        when :num then []
        when :neg then variables(tree[1])
        when :call then tree[2].flat_map { |arg| variables(arg) }.uniq
        else variables(tree[1]) | variables(tree[2])
        end
      end

      # values: {w:, d:, h:, area:, volume:} (số hoặc nil). Trả về [kết quả, ghi chú]: kết quả nil khi thiếu số đo hoặc phép tính không xác định.
      def self.evaluate(tree, values)
        missing = variables(tree).reject { |key| values[key].is_a?(Numeric) }
        return [nil, "thiếu số đo #{missing.map { |key| LABELS.fetch(key) }.join(', ')}"] unless missing.empty?
        result = compute(tree, values)
        result.finite? ? [result.round(4), nil] : [nil, 'công thức chia cho 0']
      rescue ZeroDivisionError
        [nil, 'công thức chia cho 0']
      rescue Undefined => error
        [nil, error.message]
      end

      def self.compute(tree, values)
        case tree[0]
        when :num then tree[1]
        when :var then values.fetch(tree[1]).to_f
        when :neg then -compute(tree[1], values)
        when :call then call(tree[1], tree[2].map { |arg| -> { compute(arg, values) } })
        when :/
          divisor = compute(tree[2], values)
          raise ZeroDivisionError if divisor.zero?
          compute(tree[1], values) / divisor
        else
          a = compute(tree[1], values)
          b = compute(tree[2], values)
          case tree[0]
          when :+ then a + b
          when :- then a - b
          when :* then a * b
          else compare(tree[0], a, b) ? 1.0 : 0.0
          end
        end
      end

      def self.compare(op, a, b)
        case op
        when :'=' then a == b
        when :'<>' then a != b
        when :< then a < b
        when :> then a > b
        when :<= then a <= b
        else a >= b
        end
      end

      # Hàm tính đúng như Excel (làm tròn bằng BigDecimal theo chữ số thập phân, không bị sai số dấu phẩy động). args: các lambda, IF chỉ tính nhánh được chọn.
      def self.call(name, args)
        number = ->(i) { args[i].call }
        digits = -> { number.call(1).truncate }
        decimal = ->(value) { BigDecimal(value.to_s) }
        case name
        when 'round' then decimal.call(number.call(0)).round(digits.call, :half_up).to_f
        when 'roundup' then decimal.call(number.call(0)).round(digits.call, :up).to_f
        when 'rounddown' then decimal.call(number.call(0)).round(digits.call, :down).to_f
        when 'ceiling'
          value = number.call(0)
          step = number.call(1)
          return 0.0 if step.zero?
          raise Undefined, 'CEILING: số dương cần bội số dương' if value.positive? && step.negative?
          ((decimal.call(value) / decimal.call(step)).ceil * decimal.call(step)).to_f
        when 'min' then args.map(&:call).min
        when 'max' then args.map(&:call).max
        when 'if' then number.call(0).zero? ? (args[2] ? args[2].call : 0.0) : args[1].call
        when 'abs' then number.call(0).abs
        when 'sqrt'
          value = number.call(0)
          raise Undefined, 'SQRT: căn bậc hai của số âm' if value.negative?
          Math.sqrt(value)
        when 'pi' then Math::PI
        end
      end

      # Công thức Excel (không có dấu "=" đầu) từ cây: refs là {khóa biến => biểu thức Excel của số đo đó (ô hoặc ô x hệ số đổi đơn vị)}.
      def self.to_excel(tree, refs)
        case tree[0]
        when :num then excel_number(tree[1])
        when :var then "(#{refs.fetch(tree[1])})"
        when :neg then "(-#{to_excel(tree[1], refs)})"
        when :call then "#{FUNCTIONS.fetch(tree[1])[0]}(#{tree[2].map { |arg| to_excel(arg, refs) }.join(',')})"
        when *COMPARE.map(&:to_sym) then "((#{to_excel(tree[1], refs)}#{tree[0]}#{to_excel(tree[2], refs)})*1)" # TRUE / FALSE của Excel thành 1 / 0 như plugin
        else "(#{to_excel(tree[1], refs)}#{tree[0]}#{to_excel(tree[2], refs)})"
        end
      end

      def self.excel_number(value)
        return value.to_i.to_s if value == value.round && value.abs < 1.0e15
        format('%.15g', value).upcase
      end

      # Ký hiệu: [:num, số] / [:var, khóa] / [:func, tên] / [:op, '+'] / [:cmp, '<='] / [:open] / [:close] / [:sep].
      # Chữ liền nhau cách bằng khoảng trắng ghép thành một tên ("Diện tích").
      def self.tokenize(text)
        source = Measure.normalize(text.tr('×', '*'))
        tokens = []
        i = 0
        while i < source.size
          char = source[i]
          rest = source[i..]
          if char.match?(/\s/)
            i += 1
          elsif (number = rest[/\A[0-9]+(?:[.,][0-9]+)?|\A\.[0-9]+/])
            tokens << [:num, number.tr(',', '.').to_f]
            i += number.size
          elsif char.match?(/[a-z_]/)
            word = rest[/\A[a-z_]+(?:\s+[a-z_]+)*/]
            i += word.size
            tokens.concat(name_tokens(word))
          elsif (op = rest[/\A(?:<>|<=|>=|[=<>])/])
            tokens << [:cmp, op]
            i += op.size
          elsif '+-*/'.include?(char)
            tokens << [:op, char]
            i += 1
          elsif char == '('
            tokens << [:open]
            i += 1
          elsif char == ')'
            tokens << [:close]
            i += 1
          elsif ';,'.include?(char)
            tokens << [:sep]
            i += 1
          else
            raise ArgumentError, "Công thức có ký tự không dùng được: \"#{char}\"."
          end
        end
        raise ArgumentError, 'Hãy nhập công thức.' if tokens.empty?
        tokens
      end

      # Một cụm chữ: "x" đứng riêng là dấu nhân, tên hàm là hàm; còn lại ghép thành tên số đo (thử cả cụm, rồi bớt dần từng chữ).
      def self.name_tokens(word)
        parts = word.split(/\s+/)
        out = []
        until parts.empty?
          if parts.first == 'x'
            out << [:op, '*']
            parts.shift
            next
          end
          if FUNCTIONS.key?(parts.first)
            out << [:func, parts.shift]
            next
          end
          taken = parts.size.downto(1).find { |n| NAMES.key?(parts.first(n).join('_')) && !parts.first(n).include?('x') }
          raise ArgumentError, "Không biết số đo \"#{parts.first}\". Dùng: Rộng, Sâu, Cao, Diện tích, Thể tích." unless taken
          out << [:var, NAMES.fetch(parts.first(taken).join('_'))]
          parts.shift(taken)
        end
        out
      end

      # Thứ tự ưu tiên như Excel: so sánh thấp nhất, rồi + -, rồi * /, rồi dấu trừ đứng trước.
      class Parser
        def initialize(tokens); @tokens = tokens; @pos = 0; end
        def done?; @pos >= @tokens.size; end
        def peek; @tokens[@pos]; end
        def peek_text
          token = peek
          return 'cuối công thức' unless token
          case token[0]
          when :num then token[1].to_s
          when :open then '('
          when :close then ')'
          when :sep then ';'
          when :func then token[1].upcase
          when :var then LABELS.fetch(token[1])
          else token[1].to_s
          end
        end

        def comparison(depth)
          raise ArgumentError, 'Công thức lồng ngoặc quá sâu.' if depth > MAX_DEPTH
          left = expression(depth)
          return left unless peek && peek[0] == :cmp
          op = take[1].to_sym
          [op, left, expression(depth)]
        end

        def expression(depth)
          left = term(depth)
          while peek && peek[0] == :op && '+-'.include?(peek[1])
            op = take[1].to_sym
            left = [op, left, term(depth)]
          end
          left
        end

        def term(depth)
          left = factor(depth)
          while peek && peek[0] == :op && '*/'.include?(peek[1])
            op = take[1].to_sym
            left = [op, left, factor(depth)]
          end
          left
        end

        def factor(depth)
          token = take
          raise ArgumentError, 'Công thức chưa xong (thiếu số hoặc số đo ở cuối).' unless token
          case token[0]
          when :num then [:num, token[1]]
          when :var then [:var, token[1]]
          when :func then function(token[1], depth)
          when :open
            inner = comparison(depth + 1)
            raise ArgumentError, 'Công thức thiếu dấu ngoặc đóng ")".' unless take&.first == :close
            inner
          when :op
            raise ArgumentError, "Công thức sai ở \"#{token[1]}\"." unless token[1] == '-'
            [:neg, factor(depth + 1)]
          when :sep then raise ArgumentError, 'Dấu ";" chỉ dùng để ngăn các đối số của hàm.'
          else
            raise ArgumentError, "Công thức sai ở \"#{token[1] || ')'}\"."
          end
        end

        def function(name, depth)
          excel, low, high = FUNCTIONS.fetch(name)
          raise ArgumentError, "Sau tên hàm #{excel} cần dấu ngoặc \"(\"." unless take&.first == :open
          args = []
          unless peek&.first == :close
            loop do
              args << comparison(depth + 1)
              break unless peek&.first == :sep
              take
            end
          end
          raise ArgumentError, "Hàm #{excel} thiếu dấu ngoặc đóng \")\"." unless take&.first == :close
          unless args.size.between?(low, high)
            want = low == high ? low.to_s : "#{low} đến #{high}"
            raise ArgumentError, "Hàm #{excel} cần #{want} đối số, ngăn bằng dấu \";\" (đang có #{args.size})."
          end
          [:call, name, args]
        end

        def take
          token = @tokens[@pos]
          @pos += 1 if token
          token
        end
      end
    end
  end
end
