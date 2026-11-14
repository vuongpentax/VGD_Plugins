module VGD
  module BIM
    # Đặt Mã đối tượng (trường `code` của dữ liệu VGD, do người dùng đặt, khác VGD ID) hàng loạt: tiền tố + số thứ tự theo thứ tự các món gửi lên.
    # Chỉ tính kế hoạch; việc ghi do UI::Dialog#table_assign_codes làm trong một Data.transaction.
    module ObjectCode
      MAX_PREFIX = 20
      MAX_START = 99_999
      PAD_RANGE = (1..6).freeze
      CONTROL = /[\u0000-\u001f\u007f]/

      # others: mã của các món khác trong bảng (không nằm trong lần đặt này) để không trùng.
      # items: [{index:, code:, locked:}] theo thứ tự đánh số. Món có mã giữ nguyên (trừ overwrite), món khóa bỏ qua.
      def self.plan(items, prefix:, start:, pad:, overwrite: false, others: [])
        text = prefix.is_a?(String) ? prefix.strip : ''
        raise ArgumentError, "Hãy nhập tiền tố mã (tối đa #{MAX_PREFIX} ký tự, không có ký tự điều khiển)." if text.empty? || text.length > MAX_PREFIX || text.match?(CONTROL)
        raise ArgumentError, "Số bắt đầu phải là số nguyên từ 0 đến #{MAX_START}." unless start.is_a?(Integer) && start.between?(0, MAX_START)
        raise ArgumentError, "Số chữ số phải là số nguyên từ #{PAD_RANGE.first} đến #{PAD_RANGE.last}." unless pad.is_a?(Integer) && PAD_RANGE.cover?(pad)
        raise ArgumentError, 'Hãy chọn ít nhất một dòng trong bảng.' if items.empty?
        plan = {assign: {}, kept: [], locked: []}
        number = start
        items.each do |item|
          if item[:locked] then plan[:locked] << item[:index]
          elsif !item[:code].to_s.empty? && !overwrite then plan[:kept] << item[:index]
          else
            plan[:assign][item[:index]] = "#{text}#{number.to_s.rjust(pad, '0')}"
            number += 1
          end
        end
        taken = (items.reject { |item| plan[:assign].key?(item[:index]) }.map { |item| item[:code] } + others).map { |code| code.to_s.downcase }.reject(&:empty?)
        clash = plan[:assign].values.find { |code| taken.include?(code.downcase) }
        raise ArgumentError, "Mã #{clash} đã có ở món khác. Hãy đổi tiền tố hoặc số bắt đầu." if clash
        plan
      end
    end
  end
end
