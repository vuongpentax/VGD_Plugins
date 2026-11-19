module VGD
  module Structure
    # Đọc HÌNH THẬT trong model SketchUp để dựng mặt cắt 2D: duyệt nhóm / component (kể cả lồng nhau, có phép biến đổi), lấy các mặt và cạnh theo tọa độ thế giới (mm),
    # rồi nhờ `SectionGeometry` cắt và chiếu. Nhận cả đối tượng do plugin dựng lẫn đối tượng SketchUp thường; mỗi đường viền kèm nguồn (loại, tầng, mã hoặc id SketchUp,
    # tag) để bấm trên mặt cắt chọn đúng đối tượng. Chưa xác minh trong SketchUp thật: Group#definition, Face#loops, Edge#soft? / smooth? / hidden?, Entity#hidden?, Layer#visible?.
    module SuSection
      MAX_FACES = 150_000   # quá mức này thì dừng và báo cắt bớt (mặt cắt vẫn dựng với phần đã đọc)
      MAX_EDGES = 120_000
      MAX_BEYOND = 40_000   # số đoạn cạnh phía sau gửi cho cửa sổ
      MAX_POLYS = 40_000    # số mặt gửi cho cửa sổ mặt đứng (giữ các mặt gần nhất khi quá nhiều)

      # section: {'a' => [x, y], 'b' => [x, y], 'dir' => 1 | -1, 'depth' => mm}. Trả về {length:, cut: [{pts:, closed:, src:}], beyond: [[[s,z],[s,z]]...], truncated: bool, faces:, edges:}.
      def self.build(model, section)
        plane = SectionGeometry.plane(section['a'], section['b'], section['dir'], section['depth'])
        sources = collect(model, plane)
        cut = []
        beyond = []
        sources[:items].each do |src|
          SectionGeometry.loops(SectionGeometry.cut_faces(plane, src[:faces])).each { |l| cut << l.merge(src: src[:meta]) }
          beyond.concat(SectionGeometry.beyond(plane, src[:edges]))
        end
        beyond = beyond.first(MAX_BEYOND)
        {length: plane.length.round(1), cut: cut, beyond: beyond, truncated: sources[:truncated] || beyond.size >= MAX_BEYOND, faces: sources[:faces], edges: sources[:edges]}
      end

      # Mặt đứng từ hình thật: mọi mặt của model (không cắt, không giới hạn độ sâu) nhìn từ hướng `view` (xem ElevationGeometry). Mặt xa đến gần, MAX_POLYS mặt gần nhất nếu quá nhiều.
      def self.elevation(model, view)
        sources = collect(model, nil)
        faces = sources[:items].flat_map { |src| src[:faces].map { |f| f.merge(src: src[:meta]) } }
        result = ElevationGeometry.project(view, faces)
        polys = result[:polys]
        truncated = sources[:truncated] || polys.size > MAX_POLYS
        {polys: polys.last(MAX_POLYS), bounds: result[:bounds], truncated: truncated, faces: sources[:faces], edges: sources[:edges]}
      end

      # Gom mặt và cạnh theo "nguồn": phần tử do plugin dựng (mỗi phần tử một nguồn), đối tượng SketchUp thường cấp cao nhất (một nguồn), hình rời (một nguồn chung).
      # plane = nil: không lọc theo mặt cắt (mặt đứng cần mọi đối tượng).
      def self.collect(model, plane)
        state = {items: [], faces: 0, edges: 0, truncated: false}
        walk(model.entities, Geom::Transformation.new, nil, plane, state)
        state
      end

      def self.new_source(state, meta)
        src = {meta: meta, faces: [], edges: []}
        state[:items] << src
        src
      end

      def self.walk(entities, transform, source, plane, state)
        entities.to_a.each do |e|
          break if state[:truncated]
          next unless e.valid?
          next if e.respond_to?(:hidden?) && e.hidden?
          next if e.respond_to?(:layer) && e.layer && e.layer.respond_to?(:visible?) && !e.layer.visible?
          if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            t = transform * e.transformation
            next unless reaches?(e, t, plane)
            if source
              walk(entities_of(e), t, source, plane, state)
            else
              meta = meta_for(e)
              walk(entities_of(e), t, meta == :container ? nil : new_source(state, meta), plane, state)
            end
          else
            add_geometry(e, transform, source || (state[:loose] ||= new_source(state, {kind: 'geom', level: nil, ref: nil, tag: nil})), state)
          end
        end
      end

      # Nguồn của một nhóm / component: phần tử plugin (VGD_BIM_SOURCE), đối tượng SketchUp thường (theo id), hoặc :container nếu chỉ là nhóm chứa của plugin.
      def self.meta_for(e)
        if e.get_attribute('VGD_BIM_SOURCE', 'plugin') == Schema::PLUGIN_ID
          kind = ModelSync::UI_KIND[e.get_attribute('VGD_BIM_SOURCE', 'kind').to_s]
          level, ref = e.get_attribute('VGD_BIM_SOURCE', 'ref').to_s.split(':', 2)
          return {kind: kind, level: level, ref: ref, tag: e.layer && e.layer.name}
        end
        return :container if !e.get_attribute(Schema::DICTIONARY, 'kind').nil?
        {kind: 'suobj', level: nil, ref: e.entityID.to_s, tag: e.layer && e.layer.name}
      end

      # Hộp bao thế giới (xấp xỉ theo 8 góc của hộp bao cục bộ) có chạm vùng cắt + tầm nhìn không (để bỏ qua sớm các đối tượng xa).
      def self.reaches?(e, t, plane)
        return true if plane.nil?
        b = e.respond_to?(:definition) ? e.definition.bounds : nil
        return true unless b && b.respond_to?(:min)
        corners = [b.min, b.max].then { |lo, hi| [lo.x, hi.x].product([lo.y, hi.y], [lo.z, hi.z]) }
        loc = corners.map { |x, y, z| SectionGeometry.local(plane, world(t, x, y, z)) }
        ts = loc.map { |p| p[1] * plane.dir }
        ss = loc.map(&:first)
        ts.max >= -1.0 && ts.min <= plane.depth + 1.0 && ss.max >= -plane.depth && ss.min <= plane.length + plane.depth
      end

      def self.entities_of(e)
        e.respond_to?(:definition) ? e.definition.entities : e.entities
      end

      def self.world(t, x, y, z)
        p = t * Geom::Point3d.new(x, y, z)
        [ModelSync.to_mm(p.x), ModelSync.to_mm(p.y), ModelSync.to_mm(p.z)]
      end

      def self.add_geometry(e, transform, source, state)
        if e.is_a?(Sketchup::Face)
          return state[:truncated] = true if state[:faces] >= MAX_FACES
          state[:faces] += 1
          source[:faces] << face_data(e, transform)
        elsif e.is_a?(Sketchup::Edge)
          return if e.respond_to?(:soft?) && (e.soft? || e.smooth? || e.hidden?)
          return state[:truncated] = true if state[:edges] >= MAX_EDGES
          state[:edges] += 1
          a, b = edge_points(e)
          source[:edges] << [world(transform, a.x, a.y, a.z), world(transform, b.x, b.y, b.z)]
        end
      end

      def self.edge_points(e)
        e.respond_to?(:start) ? [e.start.position, e.end.position] : [e.from, e.to]
      end

      def self.face_data(face, transform)
        if face.respond_to?(:loops)
          loops = face.loops
          outer = loops.find(&:outer?) || loops.first
          holes = loops.reject { |l| l.equal?(outer) }
          {'outer' => outer.vertices.map { |v| world(transform, v.position.x, v.position.y, v.position.z) }, 'loops' => holes.map { |l| l.vertices.map { |v| world(transform, v.position.x, v.position.y, v.position.z) } }}
        else
          {'outer' => face.points.map { |p| world(transform, p.x, p.y, p.z) }, 'loops' => []}
        end
      end
    end
  end
end
