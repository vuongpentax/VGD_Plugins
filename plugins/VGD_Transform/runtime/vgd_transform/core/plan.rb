module VGD
  module Transform
    # Ghép công cụ (Move / Rotate / Scale) với ô nhập: đọc chuỗi người dùng nhập và gọi đúng hàm tính. Logic thuần, không gọi SketchUp.
    # Ruby đọc lại ô nhập mỗi lần áp dụng.
    module Plan
      TOOLS = %w[move_abs move_off rotate scale].freeze

      module_function

      # items: danh sách món (core/move.rb). payload: {'tool' =>, 'values' => {x, y, z}, 'pivot' =>, 'uniform' =>}.
      # unit: 'mm', 'cm', 'm', 'in' hoặc 'ft' (đơn vị của file). Trả về {moves: [{index:, steps:}]}.
      def build(items, payload, unit)
        tool = payload['tool'].to_s
        raise ArgumentError, 'Công cụ không hợp lệ.' unless TOOLS.include?(tool)
        values = payload['values'].is_a?(Hash) ? payload['values'] : {}
        case tool
        when 'move_abs' then Translate.absolute(items, lengths(values, unit))
        when 'move_off' then Translate.offset(items, lengths(values, unit))
        when 'rotate' then RotateScale.rotate(items, numbers(values), payload['pivot'].to_s)
        when 'scale' then RotateScale.scale(items, scale_specs(values, payload['uniform'] ? true : false), payload['pivot'].to_s)
        end
      end

      def lengths(values, unit)
        %w[x y z].map { |axis| Units.parse_length(values[axis], unit) }
      end

      def numbers(values)
        %w[x y z].map { |axis| Units.parse_number(values[axis]) }
      end

      # Scale đều: chỉ đọc ô X và chỉ nhận hệ số (áp cho cả ba trục). Scale không đều: đọc ba ô X, Y, Z (ô trống là giữ nguyên).
      def scale_specs(values, uniform)
        if uniform
          spec = Units.parse_scale(values['x'])
          raise ArgumentError, 'Hãy nhập hệ số scale.' if spec.nil?
          raise ArgumentError, 'Scale đều chỉ nhận hệ số (ví dụ 1.5). Để đặt kích thước theo đơn vị, chọn Không đều.' if spec.is_a?(Hash)
          [spec, spec, spec]
        else
          list = %w[x y z].map { |axis| Units.parse_scale(values[axis]) }
          raise ArgumentError, 'Hãy nhập ít nhất một ô (X, Y hoặc Z).' if list.all?(&:nil?)
          list
        end
      end
    end
  end
end
