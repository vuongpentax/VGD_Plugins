module VGD
  module BIM
    # Mặt trước của món đồ: một trong bốn hướng nằm ngang theo trục cục bộ của món (+x, -x, +y, -y). Z cục bộ là hướng lên.
    # Mặt trước lưu ở định nghĩa (dictionary VGD_BIM_TABLE, cùng chỗ với Hãng / Link / Cỡ) nên mọi bản sao của một component
    # dùng chung một mặt trước, mỗi bản sao xoay thế nào ngoài thế giới thì mặt trước xoay theo. Không đổi hình học.
    #
    # Phần này là logic thuần (không gọi SketchUp) để kiểm thử được ngoài SketchUp: nhận số đo đã tính sẵn từ FrontProbe và
    # chọn mặt trước theo thứ tự ưu tiên: bằng chứng tường (mặt sau sát tường) rồi chi tiết hình học (mặt trước nhiều mặt nhỏ,
    # mặt sau là tấm phẳng). Hai nguồn trùng nhau thì tin cậy cao; chỉ một nguồn thì trung bình hoặc thấp; mâu thuẫn thì thấp và
    # phải duyệt tay.
    module Front
      DICTIONARY = 'VGD_BIM_TABLE'.freeze
      DIRECTIONS = %w[+x -x +y -y].freeze
      VECTORS = {'+x' => [1.0, 0.0], '-x' => [-1.0, 0.0], '+y' => [0.0, 1.0], '-y' => [0.0, -1.0]}.freeze
      OPPOSITE = {'+x' => '-x', '-x' => '+x', '+y' => '-y', '-y' => '+y'}.freeze
      # Quay 90° ngược chiều kim đồng hồ nhìn từ trên xuống: +x -> +y -> -x -> -y -> +x
      TURN = {'+x' => '+y', '+y' => '-x', '-x' => '-y', '-y' => '+x'}.freeze
      SOURCES = %w[auto manual].freeze
      CONFIDENCES = %w[high medium low].freeze

      # Ngưỡng (mm / tỉ lệ). Đây là giá trị khởi đầu chưa chỉnh trên model thật; chỉ cần đổi ở đây.
      WALL_NEAR = 250.0      # mặt cách vật cản gần hơn mức này coi là sát tường
      WALL_GAP = 400.0       # mặt đối diện phải thoáng hơn mặt sát tường ít nhất mức này mới kết luận
      FREE_MAX = 3000.0      # khoảng thoáng tối đa tính tới (mm); tia không chạm gì thì bằng mức này
      SLAB_RATIO = 0.12      # lớp ngoài cùng của mỗi mặt (tỉ lệ kích thước theo hướng đó) dùng để đếm chi tiết
      SLAB_MIN = 30.0        # lớp ngoài cùng tối thiểu (mm)
      FACING = 0.85          # mặt tính là "hướng ra" khi cosin pháp tuyến với hướng đó từ mức này trở lên
      MIN_DETAIL = 4         # ít hơn số mặt nhỏ này thì chưa đủ để kết luận bằng hình học
      DETAIL_RATIO = 1.5     # mặt nhiều chi tiết nhất phải hơn mặt tiếp theo ít nhất tỉ lệ này
      DETAIL_STRONG = 2.5    # từ tỉ lệ này trở lên là bằng chứng hình học mạnh
      ALIGNED_MIN = 0.7      # tỉ lệ diện tích mặt đứng song song trục cục bộ tối thiểu; thấp hơn là món lệch góc
      ALIGNED_COS = 0.985    # coi là song song trục khi |cosin| từ mức này trở lên (khoảng 10°)

      def self.opposite(dir); OPPOSITE.fetch(dir); end
      def self.turn(dir); TURN.fetch(dir); end
      def self.valid?(dir); DIRECTIONS.include?(dir); end

      # Hướng cục bộ gần nhất với một vector theo trục thế giới (chỉ xét thành phần ngang).
      # xaxis / yaxis: trục X, Y của món trong thế giới (từ ma trận biến đổi, không cần chuẩn hóa).
      def self.local_direction(world, xaxis, yaxis)
        lx = dot(world, xaxis) / norm(xaxis)
        ly = dot(world, yaxis) / norm(yaxis)
        return nil if lx.abs < 1e-9 && ly.abs < 1e-9
        lx.abs >= ly.abs ? (lx >= 0 ? '+x' : '-x') : (ly >= 0 ? '+y' : '-y')
      end

      # Vector ngang của hướng cục bộ trong thế giới (không chuẩn hóa).
      def self.world_vector(dir, xaxis, yaxis)
        x, y = VECTORS.fetch(dir)
        [xaxis[0] * x + yaxis[0] * y, xaxis[1] * x + yaxis[1] * y, xaxis[2] * x + yaxis[2] * y]
      end

      # faces: danh sách {n: [x, y, z] pháp tuyến đơn vị (cục bộ), c: [x, y, z] tâm mặt tính từ góc nhỏ nhất của khung bao (mm), a: diện tích mm²}.
      # size: [rộng X, sâu Y, cao Z] mm. free: {dir => khoảng thoáng mm} hoặc nil nếu không đo được tia.
      # Kết quả: {dir:, confidence:, notes: [...], detail: {dir => số mặt}, free:, aligned:}. dir là nil khi chưa chọn được.
      def self.analyze(faces:, size:, free: nil, upright: true, mirrored: false, dynamic: false)
        notes = []
        notes << 'món không đứng thẳng (trục Z không hướng lên)' unless upright
        notes << 'món bị lật gương' if mirrored
        notes << 'component động' if dynamic
        return result(nil, 'low', notes, {}, free, nil) unless upright

        detail = detail_counts(faces, size)
        aligned = aligned_ratio(faces)
        notes << 'món lệch góc so với trục, mặt trước chỉ gần đúng' if aligned && aligned < ALIGNED_MIN
        wall = free ? wall_evidence(free) : {pick: nil, candidates: DIRECTIONS, notes: []}
        notes.concat(wall[:notes])
        geo = geometry_pick(detail, wall[:candidates])
        dir, confidence = combine(wall, geo, notes)
        confidence = 'low' if aligned && aligned < ALIGNED_MIN
        confidence = 'low' if mirrored || dynamic
        result(dir, confidence, notes, detail, free, aligned)
      end

      def self.result(dir, confidence, notes, detail, free, aligned)
        {dir: dir, confidence: confidence, notes: notes, detail: detail, free: free, aligned: aligned}
      end

      # Mặt sau sát tường: đúng một mặt sát (<= WALL_NEAR) và mặt đối diện thoáng hơn nhiều thì mặt đối diện là mặt trước.
      # Hai mặt kề nhau cùng sát tường (góc phòng) thì chỉ loại hai mặt đó khỏi ứng viên. Hai mặt đối diện cùng sát thì không kết luận.
      def self.wall_evidence(free)
        near = DIRECTIONS.select { |d| free[d] && free[d] <= WALL_NEAR }
        return {pick: nil, candidates: DIRECTIONS, notes: []} if near.empty? || near.size == 4
        return {pick: nil, candidates: DIRECTIONS, notes: ['kẹp giữa hai tường, không dùng được bằng chứng tường']} if near.size == 2 && near[0] == OPPOSITE[near[1]]
        if near.size == 1
          back = near.first
          front = OPPOSITE[back]
          # Hình học vẫn xét cả bốn hướng để phát hiện mâu thuẫn với tường.
          return {pick: front, candidates: DIRECTIONS, notes: ["sát tường phía #{back}"]} if free[front].to_f >= free[back].to_f + WALL_GAP
          return {pick: nil, candidates: DIRECTIONS, notes: []}
        end
        rest = DIRECTIONS - near
        {pick: nil, candidates: rest, notes: ['ở góc tường (hai mặt kề sát tường)']}
      end

      # Số mặt "hướng ra" nằm trong lớp ngoài cùng của từng mặt khung bao.
      def self.detail_counts(faces, size)
        counts = DIRECTIONS.to_h { |d| [d, 0] }
        faces.each do |face|
          n = face[:n]
          c = face[:c]
          DIRECTIONS.each do |d|
            vx, vy = VECTORS[d]
            next unless n[0] * vx + n[1] * vy >= FACING
            axis = d.end_with?('x') ? 0 : 1
            extent = size[axis].to_f
            slab = [extent * SLAB_RATIO, SLAB_MIN].max
            edge = d.start_with?('+') ? extent - c[axis] : c[axis]
            counts[d] += 1 if edge <= slab
          end
        end
        counts
      end

      # Tỉ lệ diện tích mặt đứng (|nz| nhỏ) có pháp tuyến song song một trục cục bộ. nil khi không có mặt đứng nào.
      def self.aligned_ratio(faces)
        total = 0.0
        ok = 0.0
        faces.each do |face|
          n = face[:n]
          next if n[2].abs > 0.3
          total += face[:a]
          ok += face[:a] if n[0].abs >= ALIGNED_COS || n[1].abs >= ALIGNED_COS
        end
        total.zero? ? nil : ok / total
      end

      def self.geometry_pick(detail, candidates)
        ranked = candidates.sort_by { |d| -detail[d] }
        best = ranked[0]
        return {pick: nil, strong: false} if best.nil? || detail[best] < MIN_DETAIL
        runner = DIRECTIONS.reject { |d| d == best }.map { |d| detail[d] }.max
        ratio = runner.zero? ? Float::INFINITY : detail[best].to_f / runner
        return {pick: nil, strong: false} if ratio < DETAIL_RATIO
        {pick: best, strong: ratio >= DETAIL_STRONG}
      end

      def self.combine(wall, geo, notes)
        if wall[:pick] && geo[:pick]
          return [wall[:pick], 'high'] if wall[:pick] == geo[:pick]
          notes << "tường chỉ #{wall[:pick]} nhưng chi tiết hình học chỉ #{geo[:pick]}: cần duyệt"
          return [wall[:pick], 'low']
        end
        return [wall[:pick], 'medium'] if wall[:pick]
        if geo[:pick]
          notes << 'mặt có nhiều chi tiết nhất'
          corner = wall[:candidates].size < 4
          return [geo[:pick], 'high'] if corner && geo[:strong]
          return [geo[:pick], geo[:strong] ? 'medium' : 'low']
        end
        notes << 'chưa đủ bằng chứng, cần duyệt'
        [nil, 'low']
      end

      # Số lần quay 90° ngược chiều kim đồng hồ (nhìn từ trên xuống) để đưa mặt trước về -y. 0 nghĩa là đã đúng.
      def self.align_turns(dir)
        turns = 0
        current = dir
        until current == '-y'
          current = TURN.fetch(current)
          turns += 1
        end
        turns
      end

      # Hướng từ tâm món tới camera khi chụp, theo mặt trước (vector ngang đơn vị trong thế giới, hướng ra khỏi món).
      # 'front': nhìn thẳng vào mặt trước. 'isometric': từ phía trước, bên phải (người đứng ngoài nhìn vào mặt trước) và phía trên,
      # cùng tỉ lệ 1 : 1 : 0,8 như khi chụp theo trục thế giới (mặt trước -Y thì ra đúng (1, -1, 0,8)).
      # side: 'right' (mặc định) hoặc 'left' (đối xứng qua mặt phẳng nhìn thẳng mặt trước), chỉ dùng cho Iso: món sát tường bên phải thì chụp từ bên trái.
      # yaw / pitch (độ) chỉ dùng cho 'front': yaw dương = camera dời sang bên phải của người nhìn vào mặt trước (cùng quy ước với Iso phải), âm = sang trái,
      # để thấy một chút bên hông món; pitch dương = nhìn từ trên xuống. Cả hai bằng 0 thì nhìn thẳng như cũ.
      def self.camera_direction(name, front, side = 'right', yaw: 0, pitch: 0)
        fx, fy = front
        case name
        when 'front'
          turn = yaw * Math::PI / 180.0
          lift = pitch * Math::PI / 180.0
          hx = fx * Math.cos(turn) - fy * Math.sin(turn) # bên phải của người nhìn vào mặt trước là (-fy, fx)
          hy = fy * Math.cos(turn) + fx * Math.sin(turn)
          [hx * Math.cos(lift), hy * Math.cos(lift), Math.sin(lift)]
        when 'isometric'
          raise ArgumentError, 'Bên của góc Iso không hợp lệ.' unless %w[right left].include?(side)
          side == 'left' ? [fx + fy, fy - fx, 0.8] : [fx - fy, fy + fx, 0.8]
        else raise ArgumentError, 'Góc nhìn không hợp lệ.'
        end
      end

      # Rộng (ngang nhìn từ mặt trước) và Sâu (theo hướng mặt trước) từ kích thước theo trục X, Y cục bộ. Mặt trước theo trục X thì hai chiều
      # đổi chỗ. Chưa có mặt trước thì giữ nguyên (Rộng = X, Sâu = Y).
      def self.frame_sizes(x_size, y_size, dir)
        dir && dir.end_with?('x') ? [y_size, x_size] : [x_size, y_size]
      end

      # ---- Lưu / đọc (dictionary của định nghĩa) ----
      def self.read(definition)
        return {dir: nil, source: nil, confidence: nil, note: ''} unless definition.respond_to?(:get_attribute)
        dir = definition.get_attribute(DICTIONARY, 'front')
        return {dir: nil, source: nil, confidence: nil, note: ''} unless valid?(dir)
        source = definition.get_attribute(DICTIONARY, 'front_source')
        confidence = definition.get_attribute(DICTIONARY, 'front_confidence')
        {dir: dir, source: SOURCES.include?(source) ? source : 'manual', confidence: CONFIDENCES.include?(confidence) ? confidence : 'low',
         note: definition.get_attribute(DICTIONARY, 'front_note', '').to_s}
      end

      # Thủ công luôn tin cậy cao. dir không hợp lệ thì báo lỗi, không ghi nửa chừng.
      def self.write(definition, dir, source: 'manual', confidence: 'high', note: '')
        raise ArgumentError, 'Hướng mặt trước không hợp lệ.' unless valid?(dir)
        raise ArgumentError, 'Nguồn mặt trước không hợp lệ.' unless SOURCES.include?(source)
        raise ArgumentError, 'Độ tin cậy không hợp lệ.' unless CONFIDENCES.include?(confidence)
        definition.set_attribute(DICTIONARY, 'front', dir)
        definition.set_attribute(DICTIONARY, 'front_source', source)
        definition.set_attribute(DICTIONARY, 'front_confidence', confidence)
        note.to_s.empty? ? definition.delete_attribute(DICTIONARY, 'front_note') : definition.set_attribute(DICTIONARY, 'front_note', note.to_s[0, 300])
      end

      def self.clear(definition)
        %w[front front_source front_confidence front_note].each { |key| definition.delete_attribute(DICTIONARY, key) }
      end

      # Nhãn cho bảng.
      def self.label(dir)
        dir ? dir.upcase : ''
      end

      def self.state_label(info)
        return '' unless info[:dir]
        return 'Thủ công' if info[:source] == 'manual'
        {'high' => 'Tự động · cao', 'medium' => 'Tự động · trung bình', 'low' => 'Cần duyệt'}.fetch(info[:confidence], 'Cần duyệt')
      end

      def self.dot(a, b); a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; end
      def self.norm(v); Math.sqrt(dot(v, v)); end
    end
  end
end
