module VGD
  module Transform
    # Ghép công cụ (Move / Rotate / Scale) với ô nhập: đọc chuỗi người dùng nhập, gọi đúng hàm tính, và tạo dòng mô tả để xem trước.
    # Logic thuần, không gọi SketchUp. Ruby luôn gọi lại hàm này lúc xem trước và lúc áp dụng (không tin kết quả cũ).
    module Plan
      TOOLS = %w[move_abs move_off rotate scale].freeze
      AXIS_LABELS = %w[X Y Z].freeze

      module_function

      # items: danh sách món (core/move.rb). payload: {'tool' =>, 'values' => {x, y, z}, 'pivot' =>, 'uniform' =>}.
      # unit: 'mm', 'cm', 'm', 'in' hoặc 'ft' (đơn vị của file). Trả về {moves: [...]}.
      def build(items, payload, unit)
        tool = payload['tool'].to_s
        raise ArgumentError, 'Công cụ không hợp lệ.' unless TOOLS.include?(tool)
        values = payload['values'].is_a?(Hash) ? payload['values'] : {}
        case tool
        when 'move_abs' then Translate.absolute(items, lengths(values, unit))
        when 'move_off' then Translate.offset(items, lengths(values, unit))
        when 'rotate' then RotateScale.rotate(items, numbers(values), payload['pivot'].to_s)
        when 'scale' then RotateScale.scale(items, factors(values, payload['uniform'] ? true : false), payload['pivot'].to_s)
        end
      end

      # Mô tả một bước để hiển thị: độ dời / góc / hệ số, và điểm gốc mới của món (theo đơn vị của file).
      def describe(item, steps, unit)
        parts = steps.map { |step| describe_step(step, unit) }
        target = Steps.apply_steps(steps, item[:origin])
        "#{parts.join(' · ')} → điểm gốc (#{target.map { |v| Units.format_length(v, unit) }.join(', ')})"
      end

      def describe_step(step, unit)
        case step[:kind]
        when 'translate'
          "dời #{step[:delta].each_with_index.map { |d, i| "Δ#{AXIS_LABELS[i]} #{Units.format_length(d, unit)}" }.join(', ')}"
        when 'rotate'
          axis = AXIS_LABELS[step[:axis].index(1.0)]
          "xoay #{Units.format_number(step[:degrees])}° quanh #{axis}"
        when 'scale'
          factors = step[:factors].map { |f| Units.format_number(f) }
          factors.uniq.size == 1 ? "scale ×#{factors.first}" : "scale ×#{factors.join(' · ')}"
        end
      end

      def lengths(values, unit)
        %w[x y z].map { |axis| Units.parse_length(values[axis], unit) }
      end

      def numbers(values)
        %w[x y z].map { |axis| Units.parse_number(values[axis]) }
      end

      # Scale đều: chỉ đọc ô X (làm hệ số chung cho ba trục). Scale không đều: đọc ba ô X, Y, Z (ô trống là 1).
      def factors(values, uniform)
        if uniform
          factor = Units.parse_number(values['x'])
          raise ArgumentError, 'Hãy nhập hệ số scale.' if factor.nil?
          [factor, factor, factor]
        else
          list = %w[x y z].map { |axis| Units.parse_number(values[axis]) }
          raise ArgumentError, 'Hãy nhập ít nhất một hệ số (X, Y hoặc Z).' if list.all?(&:nil?)
          list.map { |f| f.nil? ? 1.0 : f }
        end
      end
    end
  end
end
