module VGD
  module BIM
    # Khối 3D của phòng (nhập từ VGD_Room vào VGD_BIM, 1.1.1-beta.13): từ 1.1.1-beta.50 là KHUNG DÂY (chỉ có cạnh, không có mặt) để mặt cắt
    # (section plane) của SketchUp không bị khối đặc tô kín hay cắt: viền sàn, viền trần và cạnh đứng ở mỗi góc (cả viền các lỗ).
    # Khối là một Group trên tag VGD_ROOMS; mang VGD_BIM_ID.guid (VGD ID, dựng lại thì giữ ID cũ)
    # và VGD_BIM_SOURCE (kind = room, ref = mã phòng). Khối đặc do bản cũ dựng cũng được nhận diện qua kind / ref và bị thay bằng khung dây khi dựng lại.
    module RoomVolume
      TAG = 'VGD_ROOMS'.freeze
      TAG_COLOR = [110, 160, 210].freeze # màu tag VGD_ROOMS khi mới tạo (hiện khi bật Tô màu theo tag); tag đã có thì giữ màu của người dùng
      ID_DICTIONARY = 'VGD_BIM_ID'.freeze
      SOURCE_DICTIONARY = 'VGD_BIM_SOURCE'.freeze
      MM_PER_INCH = 25.4
      MAX_POINTS = 200
      MAX_HOLES = 50 # lỗ trong phòng (cột, hộp kỹ thuật)
      MAX_BATCH = 500
      MAX_HEIGHT = 100_000
      MAX_NAME = 60
      ROOM_ID = /\Arm_[0-9a-f]{8}\z/
      GUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

      def self.number?(value)
        value.is_a?(Numeric) && value.finite?
      end

      def self.ring?(value)
        value.is_a?(Array) && value.size.between?(3, MAX_POINTS) && value.all? { |p| p.is_a?(Array) && p.size == 2 && p.all? { |v| number?(v) } }
      end

      # Kiểm tra dữ liệu phòng trước khi đụng model (BIM đã kiểm tra khi lưu, đây là chốt chặn thứ hai).
      def self.validate!(room, vgd_id)
        raise ArgumentError, 'Dữ liệu phòng không hợp lệ.' unless room.is_a?(Hash)
        raise ArgumentError, 'Giá trị mã phòng không hợp lệ.' unless room['id'].is_a?(String) && room['id'].match?(ROOM_ID)
        raise ArgumentError, 'VGD ID không hợp lệ.' unless vgd_id.is_a?(String) && vgd_id.match?(GUID)
        raise ArgumentError, "Giá trị viền phòng không hợp lệ: cần từ 3 đến #{MAX_POINTS} điểm, mỗi điểm là hai số X, Y (mm)." unless ring?(room['boundary'])
        raise ArgumentError, "Giá trị chiều cao phải là số lớn hơn 0 và không quá #{MAX_HEIGHT} mm." unless number?(room['height']) && room['height'].positive? && room['height'] <= MAX_HEIGHT
        raise ArgumentError, 'Giá trị cao độ sàn phải là một số.' unless number?(room['elevation'])
        name = room['name'].to_s
        raise ArgumentError, "Tên phòng không hợp lệ (tối đa #{MAX_NAME} ký tự)." if name.empty? || name.length > MAX_NAME
        holes = room['holes']
        return if holes.nil?
        raise ArgumentError, "Giá trị lỗ của phòng không hợp lệ: tối đa #{MAX_HOLES} lỗ, mỗi lỗ từ 3 đến #{MAX_POINTS} điểm." unless holes.is_a?(Array) && holes.size <= MAX_HOLES && holes.all? { |ring| ring?(ring) }
      end

      def self.label(room)
        number = room['number'].to_s.strip
        ['Phòng', (number unless number.empty?), room['name'].to_s.strip].compact.join(' · ')
      end

      # Khối đã dựng cho phòng này (theo VGD_BIM_SOURCE.ref, kind = room) ở cấp gốc của model; không có thì nil.
      def self.find(model, room_id)
        return nil unless model.respond_to?(:entities)
        find_in(model.entities.to_a, room_id)
      end

      # Tìm trong cả các group lồng nhau (người dùng có thể đưa khối vào group khác, dựng lại mà không thấy thì sẽ tạo bản trùng). Chỉ đi vào group.
      def self.find_in(entities, room_id)
        entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group) && entity.valid?
          return entity if entity.get_attribute(SOURCE_DICTIONARY, 'kind') == 'room' && entity.get_attribute(SOURCE_DICTIONARY, 'ref') == room_id
          found = find_in(entity.entities.to_a, room_id)
          return found if found
        end
        nil
      end

      # Tag VGD_ROOMS; mới tạo thì đặt màu xanh nhạt, đã có thì giữ nguyên màu.
      def self.tag_for(model)
        existed = model.layers.to_a.any? { |layer| layer.name == TAG }
        layer = model.layers.add(TAG)
        layer.color = TAG_COLOR unless existed
        layer
      end

      # Khung dây của một vòng (viền ngoài hoặc viền lỗ): viền ở sàn, viền ở trần và cạnh đứng ở mỗi góc. Trả về số cạnh dự kiến.
      def self.add_wire(entities, ring, z_floor, z_top)
        floor = ring.map { |x, y| Geom::Point3d.new(x / MM_PER_INCH, y / MM_PER_INCH, z_floor) }
        ceiling = ring.map { |x, y| Geom::Point3d.new(x / MM_PER_INCH, y / MM_PER_INCH, z_top) }
        entities.add_edges(floor + [floor.first])
        entities.add_edges(ceiling + [ceiling.first])
        floor.each_index { |i| entities.add_line(floor[i], ceiling[i]) }
        ring.size * 3
      end

      # Dựng một khối phòng BÊN TRONG thao tác đang mở (không tự mở / đóng thao tác). Dữ liệu đã được kiểm tra. Trả về Group.
      # Khối chỉ có cạnh: nếu SketchUp tự tạo mặt từ các cạnh khép kín thì xóa mặt; không còn đủ cạnh thì báo lỗi (thao tác bị hủy, khối cũ còn nguyên).
      def self.create_volume(model, room, vgd_id)
        old = find(model, room['id'])
        kept_id = ''
        if old
          raise 'Khối phòng cũ đang bị khóa. Hãy mở khóa rồi dựng lại.' if old.locked?
          kept_id = old.get_attribute(ID_DICTIONARY, 'guid').to_s
          old.erase!
        end
        group = model.entities.add_group
        z_floor = room['elevation'] / MM_PER_INCH
        z_top = z_floor + room['height'] / MM_PER_INCH
        expected = ([room['boundary']] + Array(room['holes'])).sum { |ring| add_wire(group.entities, ring, z_floor, z_top) }
        faces = group.entities.grep(Sketchup::Face)
        group.entities.erase_entities(faces) unless faces.empty?
        raise 'Không tạo được khung dây của phòng (SketchUp không giữ đủ cạnh).' if group.entities.grep(Sketchup::Edge).size < expected
        group.name = label(room)
        group.layer = tag_for(model)
        group.set_attribute(ID_DICTIONARY, 'guid', kept_id.match?(GUID) ? kept_id : vgd_id)
        group.set_attribute(SOURCE_DICTIONARY, 'plugin', 'vgd_bim')
        group.set_attribute(SOURCE_DICTIONARY, 'plugin_version', BIM::VERSION)
        group.set_attribute(SOURCE_DICTIONARY, 'kind', 'room')
        group.set_attribute(SOURCE_DICTIONARY, 'ref', room['id'])
        group
      end

      # Dựng hoặc dựng lại khối phòng trong MỘT thao tác (một bước hoàn tác); lỗi thì hủy hết. Trả về Group.
      def self.build(model, room, vgd_id)
        validate!(room, vgd_id)
        model.start_operation('VGD_BIM · Dựng khối phòng', true)
        begin
          group = create_volume(model, room, vgd_id)
          model.commit_operation
          group
        rescue StandardError
          model.abort_operation
          raise
        end
      end

      # Dựng nhiều khối phòng trong MỘT thao tác (một bước hoàn tác cho cả đợt). items: [[room, vgd_id], ...].
      # Kiểm tra hết trước khi đụng model; lỗi ở phòng nào thì hủy cả đợt. Trả về mảng Group theo thứ tự items.
      def self.build_many(model, items)
        raise ArgumentError, "Danh sách phòng cần dựng không hợp lệ (1 đến #{MAX_BATCH} phòng)." unless items.is_a?(Array) && items.size.between?(1, MAX_BATCH) && items.all? { |item| item.is_a?(Array) && item.size == 2 }
        items.each { |room, vgd_id| validate!(room, vgd_id) }
        raise ArgumentError, 'Có hai phòng trùng mã trong cùng một đợt dựng.' if items.map { |room, _| room['id'] }.uniq.size != items.size
        model.start_operation('VGD_BIM · Dựng khối nhiều phòng', true)
        begin
          groups = items.map { |room, vgd_id| create_volume(model, room, vgd_id) }
          model.commit_operation
          groups
        rescue StandardError
          model.abort_operation
          raise
        end
      end
    end
  end
end
