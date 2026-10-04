# encoding: UTF-8
module VGD
  module Library
    module Advanced
      def self.read_faces(entities, inherited = nil, depth = 0, &block)
        raise 'Cấu trúc quá sâu.' if depth > 64
        entities.each do |entity|
          next unless entity.valid? && !entity.hidden?
          next if entity.respond_to?(:locked?) && entity.locked?
          if entity.is_a?(Sketchup::Face)
            block.call(entity, entity.material || inherited, inherited)
          elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
            read_faces(entity.definition.entities.to_a, entity.material || inherited, depth + 1, &block)
          end
        end
      end

      def self.texture_materials(model)
        list = []
        if model.selection.empty?
          list << Materials.current(model)
        else
          read_faces(model.selection.to_a, Geometry.selection_inherited(model)) do |face, material, _|
            list << material << face.back_material
          end
        end
        list.compact.select { |m| m.texture }.uniq
      end

      def self.audit(model)
        raise 'Chọn group/component cần kiểm tra.' if model.selection.empty?
        faces = []
        read_faces(model.selection.to_a, Geometry.selection_inherited(model)) do |face, material, shell|
          faces << { id: face.persistent_id.to_s, face: material.display_name, shell: shell.display_name } if shell && face.material && face.material != shell
        end
        faces
      end

      def self.fix_nesting(model, strategy)
        raise 'Chọn group/component cần sửa vật liệu lồng.' if model.selection.empty?
        raise 'Chọn kiểu sửa lồng map hợp lệ.' unless %w[shell faces].include?(strategy)
        count = 0
        if strategy == 'shell'
          Geometry.each_face(model.selection.to_a, Geometry.selection_inherited(model)) do |face, effective|
            # Walk with the nearest shell rather than the face override.
            next unless effective
          end
          visit = lambda do |entities, inherited, depth|
            raise 'Cấu trúc quá sâu.' if depth > 64
            entities.each do |e|
              next unless e.valid? && !e.hidden?
              next if e.respond_to?(:locked?) && e.locked?
              if e.is_a?(Sketchup::Face)
                if inherited && e.material != inherited
                  e.material = inherited
                  count += 1
                end
              elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
                visit.call(e.definition.entities.to_a, e.material || inherited, depth + 1)
              end
            end
          end
          visit.call(model.selection.to_a, Geometry.selection_inherited(model), 0)
        else
          # Materialize appearance on all faces before clearing shell materials.
          Geometry.each_face(model.selection.to_a, Geometry.selection_inherited(model)) do |face, effective|
            if effective && !face.material
              face.material = effective
              count += 1
            end
            face.back_material = effective if effective && !face.back_material
          end
          Geometry.clear_shells(model.selection.to_a)
        end
        "Đã sửa lồng vật liệu (#{count} mặt cập nhật). Ctrl+Z để hoàn tác."
      end

      def self.swap_material(model, source, target, scope)
        raise 'Vật liệu nguồn và đích phải khác nhau.' unless source && target && source != target
        raise 'Phạm vi thay không hợp lệ.' unless %w[selection model].include?(scope)
        if scope == 'selection'
          raise 'Chọn đối tượng cần thay.' if model.selection.empty?
          roots = model.selection.to_a
          Geometry.each_face(roots) { |_face, _| } # isolate selected definitions
        else
          raise 'Đóng chế độ sửa trước khi thay trong toàn model.' if model.active_path
          roots = model.entities.to_a
          # Isolate unlocked routes so editing a child definition cannot also
          # change the geometry/materials inside an unvisited locked instance.
          Geometry.each_face(roots) { |_face, _| }
        end
        count = 0
        visited = {}
        visit = lambda do |entities, depth|
          raise 'Cấu trúc quá sâu.' if depth > 64
          entities.each do |e|
            next unless e.valid? && !e.hidden?
            next if e.respond_to?(:locked?) && e.locked?
            if e.respond_to?(:material) && e.material == source
              e.material = target
              count += 1
            end
            if e.is_a?(Sketchup::Face) && e.back_material == source
              e.back_material = target
              count += 1
            elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
              next if visited[e.definition.object_id]
              visited[e.definition.object_id] = true
              visit.call(e.definition.entities.to_a, depth + 1)
            end
          end
        end
        visit.call(roots, 0)
        raise 'Không thấy vật liệu nguồn trong phạm vi thay.' if count.zero?
        "Đã thay #{count} vị trí dùng vật liệu. Ctrl+Z để hoàn tác."
      end

      def self.flow(model)
        raise 'Chọn các mặt hoặc group/ống/phào đã tô map.' if model.selection.empty?
        faces = {}
        Geometry.each_face(model.selection.to_a, Geometry.selection_inherited(model)) do |face, material|
          faces[face] = material if material && material.texture
        end
        raise 'Không có mặt có ảnh trong vùng chọn.' if faces.empty?
        raise 'Chọn ít hơn 10000 mặt mỗi lần chạy Flowmap.' if faces.size > 10_000
        mappings = {}
        faces.each do |seed, material|
          next if mappings[seed]
          edge = seed.outer_loop.edges.max_by(&:length)
          origin = edge.start.position
          axis_x = (edge.end.position - origin).normalize
          axis_y = seed.normal.cross(axis_x).normalize
          mappings[seed] = seed.outer_loop.vertices.to_h do |vertex|
            delta = vertex.position - origin
            [vertex, [delta.dot(axis_x), delta.dot(axis_y)]]
          end
          queue = [seed]
          index = 0
          while index < queue.size
            face = queue[index]
            index += 1
            face.outer_loop.edges.each do |shared|
              shared.faces.each do |neighbor|
                next if mappings[neighbor] || faces[neighbor] != material
                mappings[neighbor] = unfold(face, neighbor, shared, mappings[face])
                queue << neighbor
              end
            end
          end
        end
        mappings.each do |face, coords|
          material = faces[face]
          face.material = material unless face.material
          mapping = Geometry.points(face).flat_map do |p|
            vertex = face.outer_loop.vertices.find { |v| v.position == p }
            u, v = coords.fetch(vertex)
            [p, Geom::Point3d.new(u / material.texture.width.to_f, v / material.texture.height.to_f, 1)]
          end
          face.clear_texture_projection(true)
          raise 'Không đặt được Flowmap.' unless face.position_material(material, mapping, true)
        end
        "Flowmap: đã trải vân nối qua #{mappings.size} mặt. Vòng kín có một đường cắt UV."
      end

      def self.unfold(previous, face, edge, previous_uv)
        a, b = edge.start, edge.end
        origin = a.position
        x_axis = (b.position - origin).normalize
        y_axis = face.normal.cross(x_axis).normalize
        uv_a, uv_b = previous_uv.fetch(a), previous_uv.fetch(b)
        dx, dy = uv_b[0] - uv_a[0], uv_b[1] - uv_a[1]
        length = Math.hypot(dx, dy)
        raise 'Cạnh quá nhỏ để trải vân.' if length < 1.0e-8
        ux, uy = dx / length, dy / length
        px, py = -uy, ux
        old_side = previous_uv.values.sum { |u, v| (u - uv_a[0]) * px + (v - uv_a[1]) * py }
        new_side = face.outer_loop.vertices.sum { |v| (v.position - origin).dot(y_axis) }
        sign = old_side * new_side > 0 ? -1 : 1
        face.outer_loop.vertices.to_h do |vertex|
          delta = vertex.position - origin
          x, y = delta.dot(x_axis), delta.dot(y_axis) * sign
          [vertex, [uv_a[0] + ux * x + px * y, uv_a[1] + uy * x + py * y]]
        end
      end

      def self.export_auxiliary(model, args)
        materials = texture_materials(model)
        raise 'Chọn mặt có ảnh hoặc vật liệu hiện tại trước khi xuất ảnh phụ.' if materials.empty?
        directory = UI.select_directory(title: 'Chọn nơi lưu Normal / Displacement / Specular / AO')
        return 'Đã hủy xuất ảnh phụ.' unless directory
        size = Integer(args.fetch('resolution', 1024))
        raise 'Độ phân giải phải là 256, 512, 1024 hoặc 2048.' unless [256, 512, 1024, 2048].include?(size)
        successes, failures = 0, []
        materials.each_with_index do |material, index|
          begin
            Sketchup.status_text = "VGD: tạo ảnh phụ #{index + 1}/#{materials.size} — #{material.display_name}"
            image = Pixels.from_rep(material.texture.image_rep(true), size)
            maps = Pixels.auxiliary(image, args.fetch('kind', 'wood'), args.fetch('strength', 2))
            stem = Storage.safe_name(material.display_name) + '_' + Digest::SHA256.hexdigest(material.name)[0, 6]
            folder = File.join(directory, stem)
            FileUtils.mkdir_p(folder)
            maps.each do |name, pixels|
              Pixels.to_rep(pixels).save_file(File.join(folder, "#{stem}_#{name}.png"))
            end
            successes += 1
          rescue StandardError => e
            failures << "#{material.display_name}: #{e.message}"
          end
        end
        raise "Không xuất được: #{failures.join('; ')}" if successes.zero?
        "Đã xuất 5 ảnh phụ cho #{successes} vật liệu#{failures.empty? ? '' : "; lỗi: #{failures.join('; ')}"}. #{directory}"
      end

      def self.trace(model, args)
        image = model.selection.grep(Sketchup::Image).first
        raise 'Chọn một ảnh đã Import vào SketchUp để Convert line.' unless image
        pixels = Pixels.from_uv(image.image_rep, Integer(args.fetch('trace_resolution', 256)).clamp(32, 512))
        loops = Pixels.contours(pixels, args.fetch('colors', 4), args.fetch('tolerance', 0.75), args.fetch('remove_background', true))
        raise 'Không tìm thấy đường viền. Thử tắt bỏ nền hoặc tăng số màu.' if loops.empty?
        raise 'Quá nhiều điểm. Giảm độ phân giải/số màu.' if loops.sum { |loop| loop[:points].size } > 100_000
        group = model.active_entities.add_group
        group.name = 'VGD Convert line'
        x_axis, y_axis = image.transformation.xaxis.normalize, image.transformation.yaxis.normalize
        group.transformation = Geom::Transformation.axes(image.origin, x_axis, y_axis, x_axis.cross(y_axis).normalize)
        scale_x, scale_y = image.width.to_f / pixels.width, image.height.to_f / pixels.height
        area = lambda { |points| points.each_cons(2).sum { |a, b| a[0] * b[1] - b[0] * a[1] } / 2.0 }
        ordered = loops.sort_by { |loop| signed = area.call(loop[:points]); [-signed.abs, signed < 0 ? 0 : 1] }
        # Build at larger coordinates to avoid SketchUp's tiny-edge tolerance.
        magnify = [1.0, 0.04 / [scale_x, scale_y].min].max
        face_count = 0
        ordered.each do |loop|
          points = loop[:points][0...-1].map { |x, y| Geom::Point3d.new(x * scale_x * magnify, y * scale_y * magnify, 0) }
          face = group.entities.add_face(points)
          next unless face
          if area.call(loop[:points]) < 0
            face.erase!
          else
            face.material = Sketchup::Color.new(*loop[:color])
            face.back_material = face.material
            face_count += 1
          end
        end
        group.transformation = group.transformation * Geom::Transformation.scaling(1.0 / magnify)
        raise 'Không dựng được mặt từ đường viền; thử giảm độ đơn giản hóa.' if face_count.zero?
        image.hidden = true if args.fetch('hide_original', true)
        model.selection.clear
        model.selection.add(group)
        "Convert line: #{loops.size} đường kín, #{face_count} mặt màu. Ảnh gốc đã được giữ lại."
      end
    end
  end
end
