module VGD
  module Structure
    # Đọc đối tượng SketchUp THƯỜNG trong model (nhóm / component cấp cao nhất không do plugin dựng) và nhận diện loại theo TAG của đối tượng
    # (tên tag theo bộ mẫu của VGD BIM: Schema::TAGS, ví dụ S. COLUMN, A. WALL). Tag là cách Structure biết đối tượng là cột, dầm, tường...
    # Chỉ đọc hình bao có hướng (kích thước theo trục cục bộ, tâm, góc xoay quanh trục đứng, đáy và đỉnh), không đọc từng mặt. Đối tượng nghiêng hoặc
    # đang bị khóa không nhận. Chưa xác minh trong SketchUp thật: Group#definition, bounds cục bộ, Transformation#xaxis, find theo entityID.
    module SuScan
      UP_MIN = 0.999 # thành phần z của trục đứng cục bộ tối thiểu để coi là không nghiêng

      # tên tag (khóa so sánh) => loại Structure
      def self.kind_by_tag
        @kind_by_tag ||= Schema::TAGS.each_with_object({}) { |(kind, spec), h| h[key(spec[:name])] = kind }
      end

      def self.key(name)
        name.to_s.strip.gsub(/\s+/, ' ').downcase
      end

      def self.plugin_made?(e)
        e.get_attribute('VGD_BIM_SOURCE', 'plugin') == Schema::PLUGIN_ID || !e.get_attribute(Schema::DICTIONARY, 'kind').nil?
      end

      # Trả về {objects: [mô tả], untagged: số đối tượng chưa có tag nhận diện, skipped: [lý do]}.
      def self.scan(model)
        objects = []
        untagged = 0
        skipped = []
        model.entities.to_a.each do |e|
          next unless (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid? && !plugin_made?(e)
          kind = kind_by_tag[key(e.layer && e.layer.name)]
          unless kind
            untagged += 1
            next
          end
          d = describe(e, kind)
          d ? objects << d : skipped << "#{name_of(e)}: nghiêng hoặc khối bị lật, không nhận."
        end
        {objects: objects, untagged: untagged, skipped: skipped}
      end

      def self.name_of(e)
        n = e.name.to_s.strip
        n = e.definition.name.to_s if n.empty? && e.respond_to?(:definition)
        n.empty? ? "##{e.entityID}" : n
      end

      # Hình bao có hướng của đối tượng trong thế giới (mm). nil nếu nghiêng.
      def self.describe(e, kind)
        t = e.transformation
        defn = e.definition
        b = defn.bounds
        xa, ya, za = t.xaxis, t.yaxis, t.zaxis
        return nil if za.z.abs < UP_MIN * za.length
        sx = ModelSync.to_mm(b.width) * xa.length
        sy = ModelSync.to_mm(b.height) * ya.length
        sz = ModelSync.to_mm(b.depth) * za.length
        c = t * b.center
        cx = ModelSync.to_mm(c.x)
        cy = ModelSync.to_mm(c.y)
        cz = ModelSync.to_mm(c.z)
        flip = za.z < 0 ? -1 : 1
        {'id' => e.entityID, 'kind' => kind, 'tag' => e.layer.name, 'name' => name_of(e), 'locked' => e.locked?, 'center' => [cx.round(1), cy.round(1)],
         'size' => [sx.round(1), sy.round(1), sz.round(1)], 'angle' => (Math.atan2(xa.y, xa.x) * 180.0 / Math::PI).round(3), 'z0' => (cz - sz / 2.0 * flip).round(1), 'z1' => (cz + sz / 2.0 * flip).round(1)}
      end

      def self.find(model, id)
        model.entities.to_a.find { |e| e.respond_to?(:entityID) && e.entityID == id && e.valid? }
      end

      # Đối tượng SketchUp thường (có tag nhận diện) đang chọn trong SketchUp, để mặt bằng sáng đúng đối tượng: [{level: nil, kind: 'suobj', ref: entityID}].
      def self.selection_items(model)
        model.selection.to_a.each_with_object([]) do |e, out|
          next unless (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid? && !plugin_made?(e) && kind_by_tag[key(e.layer && e.layer.name)]
          out << {level: nil, kind: 'suobj', ref: e.entityID.to_s}
        end
      end

      # Trong MỘT thao tác của người gọi: xóa các đối tượng gốc đã được nhận, trả về {entityID => VGD ID cũ hoặc nil} để dựng bản mới giữ ID. Đối tượng không còn,
      # đã bị khóa, hoặc đã do plugin dựng thì không đụng tới.
      def self.take(model, ids)
        Array(ids).each_with_object({}) do |id, out|
          e = find(model, id)
          next if e.nil? || e.locked? || plugin_made?(e)
          out[id] = e.get_attribute(IdKeeper::DICTIONARY, IdKeeper::KEY)
          e.erase!
        end
      end

      # Gán tag theo bộ mẫu BIM cho các đối tượng đang chọn (nhóm / component). Trả về số đối tượng đã gán.
      def self.tag_selection(model, kind)
        spec = Schema::TAGS[kind] or raise ArgumentError, 'Loại tag không hợp lệ.'
        targets = model.selection.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid? && !e.locked? && !plugin_made?(e) }
        return 0 if targets.empty?
        model.start_operation('VGD Structure · Gán tag', true)
        begin
          layer = TagStore.ensure(model, spec)
          targets.each { |e| e.layer = layer }
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        targets.size
      end
    end
  end
end
