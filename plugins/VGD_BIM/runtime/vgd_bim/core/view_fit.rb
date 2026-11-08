module VGD
  module BIM
    # Tính camera để thu phóng tới một hộp bao (tọa độ thế giới, inch), giữ nguyên hướng nhìn và hướng lên của camera hiện tại.
    # Dùng thay View#zoom cho đối tượng nằm sâu trong group (SketchUp tính theo tọa độ cục bộ nên lệch) và vì View#zoom không nhận hộp bao.
    # Toán thuần (mảng số), không gọi SketchUp; phần gán camera nằm ở UI::Dialog.
    module ViewFit
      MARGIN = 1.1     # chừa 10% lề quanh đối tượng
      MIN_RADIUS = 1.0 # inch: hộp bao suy biến (điểm, mặt phẳng mỏng) vẫn có khoảng cách dương

      # direction / up: hướng nhìn và hướng lên của camera hiện tại. aspect = rộng / cao của khung nhìn.
      # Trả về {eye:, target:, up:, height:}; height chỉ có khi camera song song (Camera#height).
      def self.camera(min, max, direction:, up:, perspective:, fov:, fov_is_height:, aspect:)
        center = (0..2).map { |axis| (min[axis] + max[axis]) / 2.0 }
        radius = [Math.sqrt((0..2).sum { |axis| ((max[axis] - min[axis]) / 2.0)**2 }), MIN_RADIUS].max
        dir = normalize(direction)
        ratio = aspect.to_f.positive? ? aspect.to_f : 1.0
        if perspective
          half = narrow_half_angle(fov.to_f * Math::PI / 180.0, fov_is_height, ratio)
          distance = radius / Math.sin(half) * MARGIN
          height = nil
        else
          distance = radius * 3.0 # chỉ để không cắt mất hình; kích thước hiển thị do height quyết định
          height = 2.0 * radius * MARGIN * [1.0, 1.0 / ratio].max
        end
        {eye: (0..2).map { |axis| center[axis] - dir[axis] * distance }, target: center, up: up, height: height}
      end

      # Nửa góc nhìn hẹp hơn trong hai góc (ngang, dọc); fov của SketchUp là góc ngang, hoặc góc dọc nếu fov_is_height.
      def self.narrow_half_angle(fov, fov_is_height, ratio)
        half = fov / 2.0
        other = fov_is_height ? Math.atan(Math.tan(half) * ratio) : Math.atan(Math.tan(half) / ratio)
        [half, other].min
      end

      def self.normalize(vector)
        length = Math.sqrt(vector.sum { |value| value * value })
        length.zero? ? [0.0, 1.0, 0.0] : vector.map { |value| value / length }
      end
    end
  end
end
