module VGD
  module BIM
    # Đổi tên hàng loạt: tính tên mới cho từng dòng của bảng khối lượng từ một mẫu tên. Không đụng model:
    # dialog.rb áp dụng kết quả trong một bước hoàn tác duy nhất.
    #
    # Mẫu tên ghép từ các mục: {tên} (tên hiện tại, trống thì lấy tên họ), {họ} (tên định nghĩa), {phân loại} (tag),
    # {nhóm} (nhóm hạng mục), {số} (số thứ tự). Sau khi ghép: tìm và thay chữ, đổi kiểu chữ, thêm tiền tố / hậu tố.
    module Rename
      ORDERS = %w[table position name].freeze
      CASES = %w[none upper lower title].freeze
      TOKEN_PATTERN = /\{(tên|họ|phân loại|nhóm|số)\}/
      MAX_TEMPLATE = 400  # độ dài tối đa của mẫu và của từng ô chữ
      MAX_NAME = 200      # độ dài tối đa của một tên mới

      # Kiểm tra dữ liệu người dùng gửi lên (payload từ JSON) và đưa về dạng chuẩn.
      def self.normalize(payload)
        payload ||= {}
        options = {
          template: payload.key?('template') ? payload['template'].to_s : '{tên}',
          find: payload['find'].to_s,
          replace: payload['replace'].to_s,
          prefix: payload['prefix'].to_s,
          suffix: payload['suffix'].to_s,
          case: payload['case'].to_s.empty? ? 'none' : payload['case'].to_s,
          order: payload['order'].to_s.empty? ? 'table' : payload['order'].to_s,
          start: integer(payload.fetch('start', 1), 'Số bắt đầu', 0, 999_999),
          pad: integer(payload.fetch('pad', 2), 'Số chữ số', 0, 8),
          step: integer(payload.fetch('step', 1), 'Bước nhảy', 1, 1000)
        }
        %i[template find replace prefix suffix].each do |key|
          raise ArgumentError, 'Một ô chữ dài quá 400 ký tự.' if options[key].length > MAX_TEMPLATE
        end
        raise ArgumentError, 'Thứ tự đánh số không hợp lệ.' unless ORDERS.include?(options[:order])
        raise ArgumentError, 'Kiểu chữ không hợp lệ.' unless CASES.include?(options[:case])
        options
      end

      def self.integer(value, label, min, max)
        number = Integer(value.to_s.strip, 10)
        raise ArgumentError, 'range' unless number >= min && number <= max
        number
      rescue ArgumentError
        raise ArgumentError, "#{label} phải là số nguyên từ #{min} đến #{max}."
      end

      # items: [{index:, name:, definition:, tag:, tag_group:, locked:, position: [x, y, z] (mm)}]
      # Trả về {rows: [{index:, old:, new:, status:, duplicate:}], counts: {...}}.
      # status: ok (sẽ đổi), same (giữ nguyên), locked (bị khóa), empty (tên mới trống), long (tên mới quá dài).
      def self.plan(items, options)
        numbers = {}
        sort_items(items.reject { |item| item[:locked] }, options[:order]).each_with_index do |item, position|
          numbers[item[:index]] = options[:start] + position * options[:step]
        end
        rows = items.map { |item| row_for(item, numbers[item[:index]], options) }
        flag_duplicates(rows)
        {rows: rows, counts: counts(rows)}
      end

      def self.row_for(item, number, options)
        old = item[:name].to_s
        return {index: item[:index], old: old, new: old, status: 'locked', duplicate: false} if item[:locked]
        fresh = build_name(item, number, options)
        status = if fresh.empty? then 'empty'
                 elsif fresh.length > MAX_NAME then 'long'
                 elsif fresh == old then 'same'
                 else 'ok'
                 end
        {index: item[:index], old: old, new: status == 'ok' || status == 'same' ? fresh : old, status: status, duplicate: false}
      end

      def self.build_name(item, number, options)
        display = item[:name].to_s.strip.empty? ? item[:definition].to_s : item[:name].to_s
        text = options[:template].gsub(TOKEN_PATTERN) do
          case Regexp.last_match(1)
          when 'tên' then display
          when 'họ' then item[:definition].to_s
          when 'phân loại' then item[:tag].to_s
          when 'nhóm' then item[:tag_group].to_s
          else number_text(number, options[:pad])
          end
        end
        text = text.gsub(options[:find]) { options[:replace] } unless options[:find].empty?
        text = change_case(text, options[:case])
        (options[:prefix] + text + options[:suffix]).strip
      end

      def self.number_text(number, pad)
        pad.zero? ? number.to_s : number.to_s.rjust(pad, '0')
      end

      def self.change_case(text, mode)
        case mode
        when 'upper' then text.upcase
        when 'lower' then text.downcase
        when 'title' then text.split(/(\s+)/).map(&:capitalize).join
        else text
        end
      end

      def self.sort_items(items, order)
        case order
        when 'position'
          items.sort_by { |item| (item[:position] || [0.0, 0.0, 0.0]).map { |v| v.to_f.round(1) } + [item[:index]] }
        when 'name'
          items.sort_by { |item| [natural_key(display_name(item)), item[:index]] }
        else
          items.sort_by { |item| item[:index] }
        end
      end

      def self.display_name(item)
        item[:name].to_s.strip.empty? ? item[:definition].to_s : item[:name].to_s
      end

      # Số trong tên so sánh theo giá trị: T2 đứng trước T10.
      def self.natural_key(text)
        text.downcase.scan(/\d+|\D+/).map { |part| part.match?(/\A\d+\z/) ? [0, part.to_i, ''] : [1, 0, part] }
      end

      # Tên (sau khi đổi) xuất hiện nhiều lần trong đợt thì đánh dấu trùng; vẫn cho đổi vì SketchUp cho phép trùng tên.
      def self.flag_duplicates(rows)
        tally = Hash.new(0)
        rows.each { |row| tally[row[:new]] += 1 }
        rows.each { |row| row[:duplicate] = tally[row[:new]] > 1 }
      end

      def self.counts(rows)
        tally = Hash.new(0)
        rows.each { |row| tally[row[:status]] += 1 }
        {total: rows.size, ok: tally['ok'], same: tally['same'], locked: tally['locked'], empty: tally['empty'],
         long: tally['long'], duplicate: rows.count { |row| row[:duplicate] }}
      end
    end
  end
end
