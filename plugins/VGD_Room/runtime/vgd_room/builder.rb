module VGD
  module Room
    # Dựng khối 3D của phòng từ dữ liệu phòng do VGD_BIM gửi (xem docs/vgd_bim/BRIDGE.md, loại room_volume).
    # Khối là một Group: mặt ở cao độ sàn theo viền, đùn lên đúng chiều cao; đặt trên tag VGD_ROOMS, vật liệu trong suốt.
    # Mang dữ liệu cầu nối: VGD_BIM_ID.guid (VGD ID do BIM cấp, dựng lại thì giữ ID cũ) và VGD_BIM_SOURCE (plugin, phiên bản, loại, mã phòng).
    module Builder
      TAG = 'VGD_ROOMS'.freeze
      MATERIAL = 'VGD_Room'.freeze
      ID_DICTIONARY = 'VGD_BIM_ID'.freeze
      SOURCE_DICTIONARY = 'VGD_BIM_SOURCE'.freeze
      MM_PER_INCH = 25.4
      MAX_POINTS = 200
      MAX_HEIGHT = 100_000
      MAX_NAME = 60
      ROOM_ID = /\Arm_[0-9a-f]{8}\z/
      GUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

      def self.number?(value)
        value.is_a?(Numeric) && value.finite?
      end

      # Kiểm tra lại dữ liệu phòng (ranh giới tin cậy: BIM đã kiểm tra, nhưng plugin này cũng có thể được gọi từ nơi khác).
      def self.validate!(room, vgd_id)
        raise ArgumentError, 'Dữ liệu phòng không hợp lệ.' unless room.is_a?(Hash)
        raise ArgumentError, 'Giá trị mã phòng không hợp lệ.' unless room['id'].is_a?(String) && room['id'].match?(ROOM_ID)
        raise ArgumentError, 'VGD ID không hợp lệ.' unless vgd_id.is_a?(String) && vgd_id.match?(GUID)
        boundary = room['boundary']
        raise ArgumentError, "Giá trị viền phòng không hợp lệ: cần từ 3 đến #{MAX_POINTS} điểm, mỗi điểm là hai số X, Y (mm)." unless boundary.is_a?(Array) && boundary.size.between?(3, MAX_POINTS) &&
                                                                                                                         boundary.all? { |p| p.is_a?(Array) && p.size == 2 && p.all? { |v| number?(v) } }
        raise ArgumentError, "Giá trị chiều cao phải là số lớn hơn 0 và không quá #{MAX_HEIGHT} mm." unless number?(room['height']) && room['height'].positive? && room['height'] <= MAX_HEIGHT
        raise ArgumentError, 'Giá trị cao độ sàn phải là một số.' unless number?(room['elevation'])
        name = room['name'].to_s
        raise ArgumentError, "Tên phòng không hợp lệ (tối đa #{MAX_NAME} ký tự)." if name.empty? || name.length > MAX_NAME
      end

      def self.label(room)
        number = room['number'].to_s.strip
        ['Phòng', (number unless number.empty?), room['name'].to_s.strip].compact.join(' · ')
      end

      # Khối đã dựng cho phòng này (theo VGD_BIM_SOURCE.ref) trong cấp gốc của model; không có thì nil.
      def self.find(model, room_id)
        return nil unless model.respond_to?(:entities)
        model.entities.to_a.find do |entity|
          entity.is_a?(Sketchup::Group) && entity.valid? && entity.get_attribute(SOURCE_DICTIONARY, 'plugin') == 'vgd_room' && entity.get_attribute(SOURCE_DICTIONARY, 'ref') == room_id
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

      # Tạo hoặc dựng lại khối phòng trong MỘT thao tác (một bước hoàn tác); lỗi thì hủy hết. Trả về Group.
      def self.build(model, room, vgd_id)
        validate!(room, vgd_id)
        model.start_operation('VGD_Room · Dựng khối phòng', true)
        begin
          old = find(model, room['id'])
          kept_id = ''
          if old
            raise 'Khối phòng cũ đang bị khóa. Hãy mở khóa rồi dựng lại.' if old.locked?
            kept_id = old.get_attribute(ID_DICTIONARY, 'guid').to_s
            old.erase!
          end
          group = model.entities.add_group
          z = room['elevation'] / MM_PER_INCH
          points = room['boundary'].map { |x, y| Geom::Point3d.new(x / MM_PER_INCH, y / MM_PER_INCH, z) }
          face = group.entities.add_face(points)
          face.reverse! if face.normal.z < 0 # đùn theo pháp tuyến: mặt phải hướng lên
          face.pushpull(room['height'] / MM_PER_INCH)
          group.name = label(room)
          group.layer = model.layers.add(TAG)
          group.material = material_for(model)
          group.set_attribute(ID_DICTIONARY, 'guid', kept_id.match?(GUID) ? kept_id : vgd_id)
          group.set_attribute(SOURCE_DICTIONARY, 'plugin', 'vgd_room')
          group.set_attribute(SOURCE_DICTIONARY, 'plugin_version', VGD::Room::VERSION)
          group.set_attribute(SOURCE_DICTIONARY, 'kind', 'room')
          group.set_attribute(SOURCE_DICTIONARY, 'ref', room['id'])
          model.commit_operation
          group
        rescue StandardError
          model.abort_operation
          raise
        end
      end
    end
  end
end
