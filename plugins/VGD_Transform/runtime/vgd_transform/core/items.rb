module VGD
  module Transform
    # Lỗi "không có gì để làm" (độ dời 0, hệ số 1...). Khi kéo trực tiếp, lỗi này nghĩa là đưa món về như lúc bắt đầu kéo.
    class NothingToDo < ArgumentError; end

    # Món đang chọn: kiểm tra, tâm biến đổi và hệ trục. Logic thuần, không gọi SketchUp.
    # Một món (đọc ở core/model_ops.rb): {index:, name:, locked:, origin: [mm], axes: [3 vector đơn vị thế giới],
    #   scale: [sx, sy, sz] so với definition, bounds: {min: [mm], max: [mm]} hộp bao thế giới, size: [mm] kích thước theo trục riêng}.
    module Items
      WORLD_AXES = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]].freeze
      PIVOTS = %w[item selection world].freeze
      COORDS = %w[world local].freeze

      module_function

      # Món nào khóa hoặc không đo được vị trí thì không biến đổi gì cả, để cả nhóm không lệch nhau.
      def check(items)
        raise ArgumentError, 'Chưa chọn group hoặc component nào.' if items.empty?
        items.each do |item|
          raise ArgumentError, "#{item[:name]} đang khóa. Bỏ khóa hoặc bỏ chọn món đó rồi thử lại." if item[:locked]
          raise ArgumentError, "Không đo được vị trí của #{item[:name]}." if item[:origin].nil?
        end
      end

      # Tâm biến đổi của một món, giống ô "Use Center" của 3ds Max.
      # item: điểm gốc của món (Pivot Point Center); selection: tâm hộp bao hình của cả lựa chọn (Selection Center);
      # world: gốc tọa độ thế giới (Transform Coordinate Center, hệ World).
      def pivot_for(items, mode, item)
        case mode
        when 'item' then item[:origin]
        when 'selection' then selection_center(items)
        when 'world' then [0.0, 0.0, 0.0]
        else raise ArgumentError, 'Tâm biến đổi không hợp lệ.'
        end
      end

      # Tâm hộp bao (theo trục thế giới) bao trọn hình của mọi món.
      def selection_center(items)
        (0..2).map { |i| (items.map { |it| it[:bounds][:min][i] }.min + items.map { |it| it[:bounds][:max][i] }.max) / 2.0 }
      end

      # Ba trục (vector đơn vị, hệ thế giới) để dời / xoay / scale: World là trục thế giới, Local là trục riêng của món.
      def frame(item, coord)
        case coord
        when 'world' then WORLD_AXES
        when 'local' then item[:axes]
        else raise ArgumentError, 'Hệ trục không hợp lệ.'
        end
      end

      # Ba góc (độ) quanh X, rồi Y, rồi Z (trục thế giới) tạo ra hướng của món: R = Rz * Ry * Rx, cột của R là ba trục riêng (axes).
      # Cùng quy ước với công cụ Xoay (xoay X, rồi Y, rồi Z), nên xoay (30, 20, 40) rồi đọc lại ra đúng (30, 20, 40).
      # Quanh Y gần ±90° (gimbal lock) góc X và Z không tách được: lấy X = 0 và dồn hết vào Z.
      def euler_degrees(axes)
        sin_beta = [[-axes[0][2], 1.0].min, -1.0].max
        beta = Math.asin(sin_beta)
        if Math.cos(beta).abs > 1e-6
          alpha = Math.atan2(axes[1][2], axes[2][2])
          gamma = Math.atan2(axes[0][1], axes[0][0])
        else
          alpha = 0.0
          gamma = Math.atan2(-axes[1][0], axes[1][1])
        end
        [alpha, beta, gamma].map { |radians| radians * 180.0 / Math::PI }
      end

      # Giá trị chung của mọi món theo từng trục (nil nếu các món khác nhau trên trục đó). Dùng để hiện ô Tuyệt đối.
      def common(items, tolerance)
        return [nil, nil, nil] if items.empty?
        (0..2).map do |i|
          values = items.map { |item| yield(item)[i] }
          values.max - values.min <= tolerance ? values.first : nil
        end
      end
    end
  end
end
