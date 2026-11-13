module VGD_Cabinet_Draw
  # Mở / đóng ngăn kéo trượt ra vào (dựng phối cảnh). Mặt hộc và thùng của cùng một hộc trượt cùng nhau theo trục Y của thùng tủ.
  # Chỉ là vị trí hiển thị: độ mở lưu ở thuộc tính 'slide_open_mm' của từng tấm, không ràng buộc va chạm với cánh.
  module DrawerSlide
    extend self

    DICT = 'VGD_Cabinet_Draw'.freeze
    ATTR = 'slide_open_mm'.freeze
    RESERVE_MM = 20.0 # phần ray còn bám khi mở hết (100% = sâu thùng − 20 mm)

    def kind_of(entity)
      entity.get_attribute(DICT, 'kind')
    end

    def front?(entity); kind_of(entity) == 'drawer_front'; end
    def box?(entity); kind_of(entity) == 'drawer_box'; end

    # Mặt hộc và thùng của một tủ (rỗng nếu chưa có ngăn kéo).
    def parts(root)
      container = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == Operations::DRAWER_CONTAINER }
      return [] unless container
      container.definition.entities.to_a.select { |e| e.valid? && (front?(e) || box?(e)) }
    end

    def key_of(entity)
      [entity.get_attribute(DICT, 'op'), entity.get_attribute(DICT, 'op_index')]
    end

    # Các tấm cùng hộc (mặt hộc + thùng) với những tấm được chọn.
    def partners(root, selected)
      keys = selected.map { |entity| key_of(entity) }
      parts(root).select { |entity| keys.include?(key_of(entity)) }
    end

    # Tủ chứa mặt hộc / thùng này.
    def cabinet_of(entity, entities = Sketchup.active_model.entities, depth = 0)
      return nil if depth > 8
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        return e if ModelData.cabinet?(e) && parts(e).include?(entity)
        found = cabinet_of(entity, e.definition.entities, depth + 1)
        return found if found
      end
      nil
    end

    def open_mm(entity)
      entity.get_attribute(DICT, ATTR, 0.0).to_f
    end

    def max_mm(entity)
      value = ModelData.params(entity)['slide_max_mm']
      value ? value.to_f : 0.0
    end

    def any_open?(root)
      parts(root).any? { |entity| open_mm(entity) > 0.01 }
    end

    # Đặt độ mở cho các tấm: unit '%' (0..100 của tầm trượt) hoặc 'mm'. Trả về số tấm đã di chuyển.
    def set_open(entities, value, unit = '%')
      number = Float(value)
      raise ArgumentError, 'Độ mở phải từ 0 trở lên.' if number < 0
      moved = 0
      entities.each do |entity|
        next unless entity.valid?
        max = max_mm(entity)
        target = unit.to_s == 'mm' ? number : max * number / 100.0
        target = [[target, 0.0].max, max].min
        delta = target - open_mm(entity)
        next if delta.abs < 1e-6
        entity.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, -delta.mm, 0))) # ra phía trước = hướng -Y
        entity.set_attribute(DICT, ATTR, target)
        moved += 1
      end
      moved
    end

    def close(entities)
      set_open(entities, 0, 'mm')
    end

    def open_all(root, value, unit = '%')
      set_open(parts(root), value, unit)
    end

    def close_all(root)
      close(parts(root))
    end
  end
end
