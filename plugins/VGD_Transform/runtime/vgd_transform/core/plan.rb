module VGD
  module Transform
    # Ghép công cụ với ô nhập: đọc chuỗi người dùng nhập và gọi đúng hàm tính. Logic thuần, không gọi SketchUp.
    # payload: {'tool' =>, 'values' => {x, y, z}, 'pivot' => item|selection|world, 'coord' => world|local, 'uniform' =>}.
    module Plan
      TOOLS = %w[move_abs move_off rotate scale scale_abs].freeze

      module_function

      # unit: đơn vị của file ('mm', 'cm', 'm', 'in', 'ft', 'yd'). Trả về {moves: [{index:, steps:}]}.
      def build(items, payload, unit)
        tool = payload['tool'].to_s
        raise ArgumentError, 'Công cụ không hợp lệ.' unless TOOLS.include?(tool)
        values = payload['values'].is_a?(Hash) ? payload['values'] : {}
        pivot = option(payload['pivot'], Items::PIVOTS, 'Tâm biến đổi không hợp lệ.')
        coord = option(payload['coord'], Items::COORDS, 'Hệ trục không hợp lệ.')
        case tool
        when 'move_abs' then Translate.absolute(items, lengths(values, unit), pivot)
        when 'move_off' then Translate.offset(items, lengths(values, unit), coord)
        when 'rotate' then RotateScale.rotate(items, numbers(values), pivot, coord)
        when 'scale' then RotateScale.scale(items, scale_specs(values, payload['uniform'] ? true : false), pivot, coord)
        when 'scale_abs' then RotateScale.absolute_scale(items, numbers(values), pivot)
        end
      end

      # Giá trị lựa chọn từ giao diện; thiếu thì dùng giá trị đầu (mặc định), sai thì báo lỗi.
      def option(value, allowed, message)
        return allowed.first if value.nil? || value.to_s.empty?
        raise ArgumentError, message unless allowed.include?(value.to_s)
        value.to_s
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
