module VGD
  module BIM
    # Khối 3D của phòng (nhập từ VGD_Room vào VGD_BIM, 1.1.1-beta.13): mặt ở cao độ sàn theo viền, đùn lên đúng chiều cao.
    # Khối là một Group trên tag VGD_ROOMS, vật liệu trong suốt; mang VGD_BIM_ID.guid (VGD ID, dựng lại thì giữ ID cũ)
    # và VGD_BIM_SOURCE (kind = room, ref = mã phòng). Khối do VGD_Room bản cũ dựng cũng được nhận diện qua kind / ref.
    module RoomVolume
      TAG = 'VGD_ROOMS'.freeze
      MATERIAL = 'VGD_Room'.freeze
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
        model.entities.to_a.find do |entity|
          entity.is_a?(Sketchup::Group) && entity.valid? && entity.get_attribute(SOURCE_DICTIONARY, 'kind') == 'room' && entity.get_attribute(SOURCE_DICTIONARY, 'ref') == room_id
        end
      end

      def self.material_for(model)
        material = model.materials[MATERIAL]
        return material if material
        material = model.materials.add(MATERIAL)
        material.color = [110, 160, 210]
        material.alpha = 0.25
        material
      end

      # Dựng một khối phòng BÊN TRONG thao tác đang mở (không tự mở / đóng thao tác). Dữ liệu đã được kiểm tra. Trả về Group.
      def self.create_volume(model, room, vgd_id)
        old = find(model, room['id'])
        kept_id = ''
        if old
          raise 'Khối phòng cũ đang bị khóa. Hãy mở khóa rồi dựng lại.' if old.locked?
          kept_id = old.get_attribute(ID_DICTIONARY, 'guid').to_s
          old.erase!
        end
        group = model.entities.add_group
        z = room['elevation'] / MM_PER_INCH
        to_points = ->(ring) { ring.map { |x, y| Geom::Point3d.new(x / MM_PER_INCH, y / MM_PER_INCH, z) } }
        face = group.entities.add_face(to_points.call(room['boundary']))
        Array(room['holes']).each { |ring| group.entities.add_face(to_points.call(ring)).erase! } # mặt trong viền lỗ bị xóa: để lại lỗ trên mặt sàn
        face.reverse! if face.normal.z < 0 # đùn theo pháp tuyến: mặt phải hướng lên
        face.pushpull(room['height'] / MM_PER_INCH)
        group.name = label(room)
        group.layer = model.layers.add(TAG)
        group.material = material_for(model)
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
