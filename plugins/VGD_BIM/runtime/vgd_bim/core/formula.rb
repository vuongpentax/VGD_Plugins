require_relative 'measure'

module VGD
  module BIM
    # Công thức khối lượng đơn giản (cột mốc 3c) do người dùng đặt cho một tag, ví dụ "(Rộng + Sâu) x 2". Chỉ có số, bốn phép tính, ngoặc và các số đo
    # của dòng (mét, m², m³); không có hàm, không có chuỗi, không bao giờ chạy mã Ruby (tự đọc từng ký hiệu rồi tính trên cây phép tính).
    # Tên số đo không phân biệt hoa thường và dấu (Measure.normalize); "x" và "×" đọc như dấu nhân, dấu phẩy thập phân được nhận như dấu chấm.
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

      # Cây phép tính của công thức, hoặc ArgumentError với lời giải thích cho người dùng.
      def self.parse!(text)
        raise ArgumentError, 'Hãy nhập công thức.' unless text.is_a?(String) && !text.strip.empty?
        raise ArgumentError, "Công thức dài tối đa #{MAX_LENGTH} ký tự." if text.length > MAX_LENGTH
        tokens = tokenize(text)
        parser = Parser.new(tokens)
        tree = parser.expression(0)
        raise ArgumentError, "Công thức sai ở \"#{parser.peek_text}\"." unless parser.done?
        tree
      end

      # Biến có trong cây (để báo thiếu số đo).
      def self.variables(tree)
        case tree[0]
        when :var then [tree[1]]
        when :num then []
        when :neg then variables(tree[1])
        else variables(tree[1]) | variables(tree[2])
        end
      end

      # values: {w:, d:, h:, area:, volume:} (số hoặc nil). Trả về [kết quả, ghi chú]: kết quả nil khi thiếu số đo hoặc chia cho 0.
      def self.evaluate(tree, values)
        missing = variables(tree).reject { |key| values[key].is_a?(Numeric) }
        return [nil, "thiếu số đo #{missing.map { |key| LABELS.fetch(key) }.join(', ')}"] unless missing.empty?
        result = compute(tree, values)
        result.finite? ? [result.round(4), nil] : [nil, 'công thức chia cho 0']
      rescue ZeroDivisionError
        [nil, 'công thức chia cho 0']
      end

      def self.compute(tree, values)
        case tree[0]
        when :num then tree[1]
        when :var then values.fetch(tree[1]).to_f
        when :neg then -compute(tree[1], values)
        when :+ then compute(tree[1], values) + compute(tree[2], values)
        when :- then compute(tree[1], values) - compute(tree[2], values)
        when :* then compute(tree[1], values) * compute(tree[2], values)
        when :/
          divisor = compute(tree[2], values)
          raise ZeroDivisionError if divisor.zero?
          compute(tree[1], values) / divisor
        end
      end

      # Ký hiệu: [:num, số] / [:var, khóa] / [:op, '+'] / [:open] / [:close]. Chữ liền nhau cách bằng khoảng trắng ghép thành một tên ("Diện tích").
      def self.tokenize(text)
        source = Measure.normalize(text.tr('×', '*'))
        tokens = []
        i = 0
        while i < source.size
          char = source[i]
          if char.match?(/\s/)
            i += 1
          elsif char.match?(/[0-9.,]/)
            number = source[i..][/\A[0-9]+(?:[.,][0-9]+)?|\A[.,][0-9]+/]
            raise ArgumentError, "Số không hợp lệ ở \"#{source[i, 8]}\"." unless number
            tokens << [:num, number.tr(',', '.').to_f]
            i += number.size
          elsif char.match?(/[a-z_]/)
            word = source[i..][/\A[a-z_]+(?:\s+[a-z_]+)*/]
            i += word.size
            tokens.concat(name_tokens(word))
          elsif '+-*/'.include?(char)
            tokens << [:op, char]
            i += 1
          elsif char == '('
            tokens << [:open]
            i += 1
          elsif char == ')'
            tokens << [:close]
            i += 1
          else
            raise ArgumentError, "Công thức có ký tự không dùng được: \"#{char}\"."
          end
        end
        raise ArgumentError, 'Hãy nhập công thức.' if tokens.empty?
        tokens
      end

      # Một cụm chữ: "x" đứng riêng là dấu nhân; còn lại ghép thành tên số đo (thử cả cụm, rồi từng chữ).
      def self.name_tokens(word)
        parts = word.split(/\s+/)
        out = []
        until parts.empty?
          if parts.first == 'x'
            out << [:op, '*']
            parts.shift
            next
          end
          taken = parts.size.downto(1).find { |n| NAMES.key?(parts.first(n).join('_')) && !parts.first(n).include?('x') }
          raise ArgumentError, "Không biết số đo \"#{parts.first}\". Dùng: Rộng, Sâu, Cao, Diện tích, Thể tích." unless taken
          out << [:var, NAMES.fetch(parts.first(taken).join('_'))]
          parts.shift(taken)
        end
        out
      end

      # Đọc theo thứ tự ưu tiên: + - thấp hơn * /; dấu trừ đứng đầu là số âm.
      class Parser
        def initialize(tokens); @tokens = tokens; @pos = 0; end
        def done?; @pos >= @tokens.size; end
        def peek; @tokens[@pos]; end
        def peek_text
          token = peek
          return 'cuối công thức' unless token
          token[0] == :num ? token[1].to_s : {op: token[1], open: '(', close: ')', var: token[1].to_s}[token[0]].to_s
        end

        def expression(depth)
          raise ArgumentError, 'Công thức lồng ngoặc quá sâu.' if depth > MAX_DEPTH
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
          when :open
            inner = expression(depth + 1)
            raise ArgumentError, 'Công thức thiếu dấu ngoặc đóng ")".' unless take&.first == :close
            inner
          when :op
            raise ArgumentError, "Công thức sai ở \"#{token[1]}\"." unless token[1] == '-'
            [:neg, factor(depth + 1)]
          else
            raise ArgumentError, 'Công thức có dấu ngoặc đóng ")" thừa.'
          end
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
