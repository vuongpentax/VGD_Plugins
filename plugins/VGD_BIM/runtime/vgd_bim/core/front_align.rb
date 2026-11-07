require_relative 'front'
require_relative 'front_probe'

module VGD
  module BIM
    # Sửa trục của món theo mặt trước: xoay nội dung của định nghĩa quanh trục Z tại gốc, theo bội của 90°, để mặt trước thành hướng -Y,
    # rồi bù ngược cho mọi bản sao (transformation = cũ * R⁻¹) nên hình trong model không đổi chỗ. Gốc tọa độ giữ nguyên.
    # ĐỔI HÌNH HỌC model (trục của định nghĩa), khác với phần còn lại của Mặt trước. Người gọi phải bọc trong một thao tác SketchUp
    # (Data.transaction) để Ctrl+Z hoàn tác cả hình học lẫn dữ liệu, và xem plan trước khi apply.
    module FrontAlign
      TARGET = '-y'.freeze

      # records: các dòng của Table.build. Trả về {items: [{definition:, name:, dir:, turns:, instances:}], skipped: [{name:, reason:}], aligned: số loại đã đúng}.
      # Mỗi định nghĩa chỉ xét một lần dù có nhiều bản sao trong danh sách.
      def self.plan(records)
        items = []
        skipped = []
        aligned = 0
        records.group_by { |record| Geometry.definition(record[:entity]) }.each do |definition, group|
          name = label(definition, group.map { |record| record[:entity] })
          dir = Front.read(definition)[:dir]
          if dir.nil? then skipped << {name: name, reason: 'chưa có mặt trước'}; next end
          if dir == TARGET then aligned += 1; next end
          reason = group.any? { |record| record[:locked] } ? 'nằm trong đối tượng bị khóa' : blocked_reason(definition)
          if reason then skipped << {name: name, reason: reason}; next end
          items << {definition: definition, name: name, dir: dir, turns: Front.align_turns(dir), instances: definition.instances.to_a}
        end
        {items: items, skipped: skipped, aligned: aligned}
      end

      # Lý do không sửa được định nghĩa này (nil nếu sửa được). Một bản sao bị khóa hoặc lật gương thì bỏ cả định nghĩa.
      def self.blocked_reason(definition)
        return 'là ảnh' if definition.respond_to?(:image?) && definition.image?
        return 'component động' if FrontProbe.dynamic?(definition, definition)
        return 'không có hình bên trong' if definition.entities.to_a.empty?
        instances = definition.instances.to_a
        return 'không có bản sao nào trong model' if instances.empty?
        return 'có bản sao bị khóa' if instances.any? { |instance| instance.respond_to?(:locked?) && instance.locked? }
        return 'có bản sao bị lật gương' if instances.any? { |instance| FrontProbe.mirrored?(FrontProbe.axes_of(instance.transformation)) }
        nil
      end

      # Thực hiện kế hoạch (trong một thao tác do người gọi mở). Nếu có lỗi giữa chừng thì ném lỗi để người gọi hủy cả thao tác.
      def self.apply(plan)
        plan[:items].each do |item|
          definition = item[:definition]
          rotation = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), item[:turns] * Math::PI / 2.0)
          definition.entities.transform_entities(rotation, definition.entities.to_a)
          inverse = rotation.inverse
          item[:instances].each { |instance| instance.transformation = instance.transformation * inverse }
          info = Front.read(definition)
          Front.write(definition, TARGET, source: info[:source], confidence: info[:confidence], note: info[:note])
        end
        plan[:items].size
      end

      # Tên dễ nhận ra: tên của bản sao đầu tiên có tên, rồi tên định nghĩa.
      def self.label(definition, entities)
        name = entities.map { |entity| entity.name.to_s.strip }.find { |text| !text.empty? } || definition.name.to_s.strip
        name.empty? ? '(chưa đặt tên)' : name
      end
    end
  end
end
