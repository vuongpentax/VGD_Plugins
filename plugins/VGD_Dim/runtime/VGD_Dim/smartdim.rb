# encoding: UTF-8
module VGD
  module Dim
    # Smart Dim: chọn tủ (Group/Component) → tạo 2 cấp dim trên một mặt:
    #   cấp 1 = dim nối tiếp (hồi, cánh, đợt...), cấp 2 = dim tổng.
    # Mặt có thể là X/Y (mặt đứng), Z (mặt bằng) hoặc mặt cắt đang bật.
    # Dim được gom vào một Group tên 000_DIM_X / 000_DIM_Y / 000_DIM_Z (đồng thời là Tag).
    module SmartDim
      X = Geom::Vector3d.new(1, 0, 0) unless const_defined?(:X, false)
      Y = Geom::Vector3d.new(0, 1, 0) unless const_defined?(:Y, false)
      Z = Geom::Vector3d.new(0, 0, 1) unless const_defined?(:Z, false)
      SIDES = { '-y' => [0, -1, 0], '+y' => [0, 1, 0], '-x' => [-1, 0, 0], '+x' => [1, 0, 0],
                '+z' => [0, 0, 1], '-z' => [0, 0, -1] }.freeze unless const_defined?(:SIDES, false)
      VERTICAL = %w[-y +y -x +x].freeze unless const_defined?(:VERTICAL, false)
      DEFAULTS = {
        'face' => 'camera', 'use_section' => true, 'scene_only' => true, 'do_h' => true, 'do_v' => true,
        'h_side' => 'top', 'v_side' => 'left',
        'off1' => 150, 'off2' => 300,
        'min_seg' => 5, 'min_part' => 300, 'depth' => 100
      }.freeze unless const_defined?(:DEFAULTS, false)

      def self.saved
        data = Store.read('smartlast', nil)
        data = {'opts'=>Store.read('smartdim',{}), 'settings'=>{}} unless data.is_a?(Hash)
        {'opts'=>validate(data.fetch('opts',{})), 'settings'=>Core.validate_settings(data.fetch('settings',{}))}
      rescue ArgumentError, TypeError
        {'opts'=>DEFAULTS.dup, 'settings'=>Core.validate_settings({})}
      end
      def self.execute(opts, style)
        options = validate(opts)
        settings = Core.validate_settings(style)
        result = run(options, settings)
        begin
          Store.write('smartlast',{'opts'=>options,'settings'=>settings})
        rescue StandardError => error
          result['warnings'] << "Dim đã tạo nhưng chưa lưu được thiết lập: #{error.message}"
        end
        result
      end

      def self.validate(opts)
        raise ArgumentError, 'Thông số Smart Dim không hợp lệ.' unless opts.is_a?(Hash)
        o = DEFAULTS.merge(opts.select { |key, _| DEFAULTS.key?(key) })
        raise ArgumentError, 'Mặt không hợp lệ.' unless (%w[camera axis] + SIDES.keys).include?(o['face'])
        raise ArgumentError, 'Vị trí Dim không hợp lệ.' unless %w[top bottom].include?(o['h_side']) && %w[left right].include?(o['v_side'])
        %w[do_h do_v use_section scene_only].each { |key| raise ArgumentError, 'Lựa chọn Smart Dim không hợp lệ.' unless [true, false].include?(o[key]) }
        raise ArgumentError, 'Hãy bật Dim ngang hoặc Dim đứng.' unless o['do_h'] || o['do_v']
        %w[off1 off2 min_seg min_part depth].each do |key|
          value = Float(o[key]) rescue nil
          raise ArgumentError, "#{key}: cần số mm không âm." unless value && value.finite? && value >= 0
          o[key] = value
        end
        raise ArgumentError, 'Cấp 1 phải > 0; cấp 2 phải lớn hơn cấp 1; chiều sâu phải > 0.' unless o['off1'] > 0 && o['off2'] > o['off1'] && o['depth'] > 0
        o
      end

      def self.run(opts, style)
        model = Sketchup.active_model
        raise 'APPLY đang chạy; đợi hoàn tất trước khi tạo Dim.' if NativeStyle.running?
        o = validate(opts || {})
        config = Core.validate_settings(style || {})
        Engine.check_context(model)
        sel = model.selection.to_a.select { |e| e.valid? && visible_entity?(e) && !Managed.owned?(e) && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) }
        raise 'Chưa chọn tủ. Hãy chọn Group/Component của tủ rồi bấm Smart Dim.' if sel.empty?

        page = Managed.page(model, o['scene_only'])
        basis = cabinet_axes(sel.first.transformation)
        sel.each { |e| cabinet_axes(e.transformation); check_axes(e.transformation, basis) }
        parts = []
        planes = []
        ctx_planes = context_sections(model)
        collect(sel, Geom::Transformation.new, parts, [], planes, basis)
        raise 'Không tìm thấy chi tiết trong tủ đã chọn (bỏ qua đối tượng ẩn, khóa hoặc tag tắt).' if parts.empty?
        if Regions.active_bounds(model)
          Regions.root_context!(model)
          region = Regions.active_bounds(model)
          parts.select! { |corners| Regions.contains_part?(region, corners) }
          raise 'Không có chi tiết nào nằm trọn trong Boundary/Detail Region đang chọn.' if parts.empty?
        end

        candidates = ctx_planes.empty? ? planes : ctx_planes
        raise 'Có nhiều mặt cắt đang bật trong phạm vi. Chỉ bật một mặt cắt hoặc bỏ tùy chọn đo mặt cắt.' if o['use_section'] && model.rendering_options['DisplaySectionCuts'] && candidates.size > 1
        section = o['use_section'] && model.rendering_options['DisplaySectionCuts'] ? candidates.first : nil
        bb = Geom::BoundingBox.new
        parts.each { |cs| cs.each { |c| bb.add(c) } }
        face = section ? section_face(model, section, basis) : pick_face(model, bb, o['face'], basis, parts.flatten)
        n, rv, uv = frame(face, basis)

        rows = parts.map do |cs|
          rs = cs.map { |c| dot(c, rv) }
          us = cs.map { |c| dot(c, uv) }
          fs = cs.map { |c| dot(c, n) }
          { rmin: rs.min, rmax: rs.max, umin: us.min, umax: us.max, fmin: fs.min, fmax: fs.max }
        end
        big = rows.select { |p| [p[:rmax] - p[:rmin], p[:umax] - p[:umin]].max >= o['min_part'].to_f.mm }
        raise 'Mọi chi tiết đều nhỏ hơn ngưỡng "bỏ chi tiết nhỏ". Hãy giảm ngưỡng này.' if big.empty?

        if section
          f0 = dot(section[:point], n)             # dim nằm đúng trên mặt phẳng cắt
          tol = 0.1.mm
          use = big.select { |p| p[:fmin] + tol < f0 && f0 < p[:fmax] - tol }
          raise 'Mặt cắt đang bật không cắt qua chi tiết nào của tủ đã chọn.' if use.empty?
        else
          f0  = big.map { |p| p[:fmax] }.max      # dim nằm trên mặt trước
          use = big.select { |p| p[:fmax] >= f0 - o['depth'].to_f.mm }
          use = use.reject { |p| covered?(p, big) }       # bỏ chi tiết bị che sau cánh, hậu, đợt phía trước
          raise 'Không còn chi tiết nhìn thấy trên mặt này; thử tăng "Sâu tối đa".' if use.empty?
        end

        rmin = use.map { |p| p[:rmin] }.min
        rmax = use.map { |p| p[:rmax] }.max
        umin = use.map { |p| p[:umin] }.min
        umax = use.map { |p| p[:umax] }.max
        minseg = o['min_seg'].to_f.mm
        hb = breaks(use.flat_map { |p| [p[:rmin], p[:rmax]] }, minseg)
        vb = breaks(use.flat_map { |p| [p[:umin], p[:umax]] }, minseg)

        pt = lambda do |r, u|
          Geom::Point3d.new(rv.x * r + uv.x * u + n.x * f0,
                            rv.y * r + uv.y * u + n.y * f0,
                            rv.z * r + uv.z * u + n.z * f0)
        end
        vec = lambda { |v, k| Geom::Vector3d.new(v.x * k, v.y * k, v.z * k) }
        off1 = o['off1'].to_f.mm
        off2 = o['off2'].to_f.mm
        count = (o['do_h'] ? hb.size - 1 + (hb.size > 2 ? 1 : 0) : 0) + (o['do_v'] ? vb.size - 1 + (vb.size > 2 ? 1 : 0) : 0)
        raise 'Không có đoạn đo khác 0 trên mặt này.' if count <= 0
        raise 'Quá nhiều đoạn đo (>2000); hãy tăng ngưỡng lọc hoặc chọn ít tủ hơn.' if count > 2000

        axis = face[1].upcase
        name = section ? "000_DIM_SECTION_#{axis}_#{section[:id]}" : "000_DIM_#{axis}_#{face[0] == '+' ? 'PLUS' : 'MINUS'}"
        name += "_S#{page.persistent_id}" if page
        key = Managed.key(sel, page, section ? face[1] : face, section)
        previous = Managed.matches(model.active_entities, key)
        raise 'Bộ Dim cũ đang khóa; mở khóa Group trước khi cập nhật.' if previous.any?(&:locked?)
        if previous.any? { |g| g.entities.any? { |e| !e.is_a?(Sketchup::Dimension) || !Managed.owned?(e) } }
          raise 'Group Dim cũ có đối tượng được thêm thủ công. Tách các đối tượng đó ra trước khi cập nhật bộ Dim.'
        end
        created = []
        group = nil; tag = nil; visibility = []; scene_count = 0
        AutoStyle.suspend do
          model.start_operation('VGD Dim — Smart Dim', true)
          begin
            group = model.active_entities.add_group
            group.name = name
            group.set_attribute(Managed::DICT, 'owner', 'VGD Dim')
            group.set_attribute(Managed::DICT, 'key', key)
            group.set_attribute(Managed::DICT, 'sources', sel.map(&:persistent_id))
            group.set_attribute(Managed::DICT, 'section', section ? section[:id] : '')
            tag = Managed.tag(model, name, page)
            group.layer = tag
            ents = group.entities
            if o['do_h']
              hs = o['h_side'] == 'bottom' ? -1 : 1
              uref = hs > 0 ? umax : umin
              (0...hb.size - 1).each { |i| created << make(ents, pt.call(hb[i], uref), pt.call(hb[i + 1], uref), vec.call(uv, hs * off1), n) }
              created << make(ents, pt.call(hb.first, uref), pt.call(hb.last, uref), vec.call(uv, hs * off2), n) if hb.size > 2
            end
            if o['do_v']
              vs = o['v_side'] == 'right' ? 1 : -1
              rref = vs > 0 ? rmax : rmin
              (0...vb.size - 1).each { |i| created << make(ents, pt.call(rref, vb[i]), pt.call(rref, vb[i + 1]), vec.call(rv, vs * off1), n) }
              created << make(ents, pt.call(rref, vb.first), pt.call(rref, vb.last), vec.call(rv, vs * off2), n) if vb.size > 2
            end
            # Tag do Group quyết định (000_DIM_X/Y/Z), nên Dim bên trong không gán Tag riêng.
            created.each do |dimension|
              dimension.set_attribute(Managed::DICT, 'owner', 'VGD Dim')
              dimension.layer = model.layers[0]
              Core.style_dim(dimension, config['dim'], {}, false)
            end
            visibility = Managed.visibility_snapshot(model, tag) if page
            scene_count = Managed.bind_scene(model, tag, page)
            # Construct/style/bind successfully before removing only our matching sets.
            previous.each(&:erase!)
            model.commit_operation
          rescue StandardError => e
            model.abort_operation
            errors = tag && tag.valid? ? Managed.restore_visibility(visibility, tag) : []
            group.erase! if group && group.valid?
            raise "#{e.message} Không trả được hiển thị Scene: #{errors.join('; ')}" unless errors.empty?
            raise e
          end
        end
        model.active_view.invalidate

        { 'face' => face, 'section' => !section.nil?, 'group' => group.name, 'tag' => tag.name, 'total' => created.size,
          'replaced' => previous.size, 'scenes' => scene_count, 'scene' => page && page.name,
          'axis_mode' => 'cabinet', 'warnings' => (page ? [] : ['Bộ Dim chưa gắn Scene; Tag hiển thị dùng chung.']),
          'h' => o['do_h'] ? seg_mm(hb) : [], 'v' => o['do_v'] ? seg_mm(vb) : [], 'parts' => use.size }
      end

      # ---- hình học ----
      # Trả về [pháp tuyến hướng ra người nhìn, trục "phải", trục "lên"] của mặt.
      def self.frame(face, basis=[X,Y,Z])
        n = basis['xyz'.index(face[1])]
        n = n.reverse if face[0] == '-'
        case face
        when '+z' then [n, basis[0], n.cross(basis[0])]
        when '-z' then [n, basis[0], n.cross(basis[0])]
        else [n, Z.cross(n).normalize, Z]
        end
      end

      def self.cabinet_axes(tr, upright=true)
        axes = [X,Y,Z].map { |a| a.transform(tr) }
        raise 'Tủ có trục co về 0; không thể đo.' if axes.any? { |a| a.length < 1e-8 }
        axes.map!(&:normalize)
        raise 'Tủ bị shear (trục không vuông góc); chưa hỗ trợ Smart Dim.' if axes.combination(2).any? { |a,b| a.dot(b).abs > 1e-6 }
        raise 'Tủ xoay nghiêng quanh X/Y; chỉ hỗ trợ tủ thẳng đứng xoay quanh Z.' if upright && axes[2].dot(Z) < 1.0 - 1e-6
        axes
      end
      def self.check_axes(tr, basis)
        axes = cabinet_axes(tr, false)
        unless axes.all? { |a| basis.any? { |b| a.dot(b).abs > 1.0 - 1e-6 } }
          raise 'Các khối không cùng hệ trục tủ. Đo từng tủ/hướng riêng; không dùng kích thước hình chiếu.'
        end
      end

      # Chi tiết p có bị các chi tiết nằm phía trước che kín (theo hình chiếu trên mặt) không?
      def self.covered?(p, all)
        eps = 0.5.mm
        fronts = all.select do |q|
          q[:fmax] > p[:fmax] + eps && q[:rmin] < p[:rmax] && q[:rmax] > p[:rmin] && q[:umin] < p[:umax] && q[:umax] > p[:umin]
        end
        return false if fronts.empty?
        rs = [p[:rmin], p[:rmax]]
        us = [p[:umin], p[:umax]]
        fronts.each do |q|
          rs.concat([q[:rmin], q[:rmax]].select { |v| v > p[:rmin] && v < p[:rmax] })
          us.concat([q[:umin], q[:umax]].select { |v| v > p[:umin] && v < p[:umax] })
        end
        rs = rs.sort.uniq
        us = us.sort.uniq
        raise 'Phép lọc che khuất quá phức tạp; hãy chọn nhóm tủ nhỏ hơn.' if (rs.size - 1) * (us.size - 1) * fronts.size > 1_000_000
        rs.each_cons(2) do |r0, r1|
          next if r1 - r0 < eps
          rc = (r0 + r1) / 2
          us.each_cons(2) do |u0, u1|
            next if u1 - u0 < eps
            uc = (u0 + u1) / 2
            return false unless fronts.any? { |q| q[:rmin] <= rc && rc <= q[:rmax] && q[:umin] <= uc && uc <= q[:umax] }
          end
        end
        true
      end

      def self.dot(c, v)
        c.x * v.x + c.y * v.y + c.z * v.z
      end

      def self.make(ents, s, e, off, n)
        s, e = e, s if (e - s).cross(off).dot(n) < 0   # để chữ đọc được từ phía người nhìn
        ents.add_dimension_linear(s, e, off)
      end

      def self.seg_mm(b)
        b.each_cons(2).map { |a, c| ((c - a) / 1.mm).round(1) }
      end

      # Gom mốc, bỏ đoạn nhỏ hơn minseg; đầu cuối luôn giữ để dim tổng khớp.
      def self.breaks(vals, minseg)
        eps = 0.5.mm
        cl = []
        vals.sort.each { |x| cl << x if cl.empty? || x - cl.last > eps }
        return cl if cl.size < 2
        out = [cl.first]
        cl[1..-1].each { |x| out << x if x - out.last >= minseg }
        if out.last != cl.last
          out.size == 1 ? out << cl.last : out[-1] = cl.last
        end
        out
      end

      def self.camera_look(model)
        model.active_view.camera.direction.transform(model.edit_transform.inverse)
      end

      def self.pick_face(model, bb, mode, basis=[X,Y,Z], corners=nil)
        return mode if SIDES[mode]
        look = camera_look(model)
        keys = SIDES.keys
        if mode == 'axis'
          keys = VERTICAL
          corners ||= (0..7).map { |i| bb.corner(i) }
          dist = VERTICAL.each_with_object({}) { |k,h| h[k] = corners.map { |c| dot(c, frame(k,basis)[0]) }.max.abs }
          best = dist.values.min
          keys = keys.select { |k| dist[k] - best < 1.mm }
        end
        keys.max_by { |k| -look.dot(frame(k,basis)[0]) }
      end

      # ---- mặt cắt đang bật (tọa độ của context đang mở) ----
      def self.section_plane_of(entities, tr, path=[])
        return nil unless entities.respond_to?(:active_section_plane)
        sp = entities.active_section_plane
        return nil unless sp
        a, b, c, d = sp.get_plane
        len2 = a * a + b * b + c * c
        return nil if len2 < 1e-12
        len = Math.sqrt(len2)
        point = Geom::Point3d.new(-a * d / len2, -b * d / len2, -c * d / len2)
        normal = Geom::Vector3d.new(a / len, b / len, c / len)
        # Transform normals as plane covectors, including mirror/nonuniform scale.
        tangent = normal.cross(normal.x.abs < 0.9 ? X : Y).normalize
        other = normal.cross(tangent).normalize
        transformed = tangent.transform(tr).cross(other.transform(tr)).normalize
        transformed = transformed.reverse if transformed.dot(normal.transform(tr)) < 0
        {point:point.transform(tr), normal:transformed, id:(path + [sp.persistent_id]).join('_')}
      end

      def self.context_sections(model)
        entities = model.entities; tr = Geom::Transformation.new; path = []
        planes = []
        inverse = model.edit_transform.inverse
        chain = Array(model.active_path)
        (chain + [nil]).each do |instance|
          plane = section_plane_of(entities, inverse * tr, path)
          planes << plane if plane
          break unless instance
          path << instance.persistent_id; tr = tr * instance.transformation; entities = instance.definition.entities
        end
        planes
      end
      def self.section_face(model, section, basis=[X,Y,Z])
        nrm = section[:normal]
        index = (0..2).max_by { |i| nrm.dot(basis[i]).abs }
        raise 'Mặt cắt xiên so với trục tủ; chưa hỗ trợ đo giao tuyến xiên.' if nrm.dot(basis[index]).abs < 1.0 - 1e-6
        axis = 'xyz'[index]
        plus = basis[index]
        camera_look(model).dot(plus) < 0 ? "+#{axis}" : "-#{axis}"   # mặt hướng về camera
      end

      # ---- thu thập chi tiết (bbox 8 góc, tọa độ của context đang mở) ----
      def self.corners(bb, t)
        (0..7).map { |i| t * bb.corner(i) }
      end

      def self.visible_entity?(e)
        return false if e.hidden? || (e.respond_to?(:locked?) && e.locked?)
        layer = e.layer
        return false if layer && layer.respond_to?(:visible?) && !layer.visible?
        folder = layer.folder if layer && layer.respond_to?(:folder)
        while folder
          return false unless folder.visible?
          folder = folder.respond_to?(:folder) ? folder.folder : nil
        end
        true
      end

      def self.collect(list, tr, parts, path, planes, basis, ids=[])
        raise 'Tủ lồng quá sâu; hãy chọn một nhóm con.' if path.size > 64
        list.each do |e|
          next unless e.valid?
          next unless visible_entity?(e)
          next if Managed.owned?(e)
          case e
          when Sketchup::Group, Sketchup::ComponentInstance
            t = tr * e.transformation
            defn = e.definition
            raise 'Component lồng vòng; không thể đo.' if path.include?(defn)
            check_axes(t, basis)
            plane = section_plane_of(defn.entities, t, ids + [e.persistent_id])
            planes << plane if plane
            kids = defn.entities.select { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }
            faces = defn.entities.grep(Sketchup::Face).reject { |f| !visible_entity?(f) }
            if !faces.empty?
              bb = Geom::BoundingBox.new
              faces.each { |f| bb.add(f.bounds) }
              parts << corners(bb, t)
            elsif kids.empty? && defn.entities.grep(Sketchup::Face).empty?
              edges = defn.entities.grep(Sketchup::Edge).reject { |edge| !visible_entity?(edge) }
              unless edges.empty?
                bb = Geom::BoundingBox.new
                edges.each { |edge| bb.add(edge.bounds) }
                parts << corners(bb, t)
              end
            end
            raise 'Quá nhiều chi tiết (>500); chọn từng tủ để đo.' if parts.size > 500
            collect(kids, t, parts, path + [defn], planes, basis, ids + [e.persistent_id])
          when Sketchup::Face
            parts << corners(e.bounds, tr)
          end
        end
      end
    end
  end
end
