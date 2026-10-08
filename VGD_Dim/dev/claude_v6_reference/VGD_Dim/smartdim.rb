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
        'face' => 'camera', 'use_section' => true, 'do_h' => true, 'do_v' => true,
        'h_side' => 'top', 'v_side' => 'left',
        'off1' => 150, 'off2' => 300,
        'min_seg' => 5, 'min_part' => 300, 'depth' => 100
      }.freeze unless const_defined?(:DEFAULTS, false)

      def self.validate(opts)
        raise ArgumentError, 'Thông số Smart Dim không hợp lệ.' unless opts.is_a?(Hash)
        o = DEFAULTS.merge(opts.select { |key, _| DEFAULTS.key?(key) })
        raise ArgumentError, 'Mặt không hợp lệ.' unless (%w[camera axis] + SIDES.keys).include?(o['face'])
        raise ArgumentError, 'Vị trí Dim không hợp lệ.' unless %w[top bottom].include?(o['h_side']) && %w[left right].include?(o['v_side'])
        %w[do_h do_v use_section].each { |key| raise ArgumentError, 'Lựa chọn Smart Dim không hợp lệ.' unless [true, false].include?(o[key]) }
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
        sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        raise 'Chưa chọn tủ. Hãy chọn Group/Component của tủ rồi bấm Smart Dim.' if sel.empty?

        parts = []
        planes = []
        ctx_plane = section_plane_of(model.active_entities, Geom::Transformation.new)
        planes << ctx_plane if ctx_plane
        collect(sel, Geom::Transformation.new, parts, [], planes)
        raise 'Không tìm thấy chi tiết trong tủ đã chọn (bỏ qua đối tượng ẩn, khóa hoặc tag tắt).' if parts.empty?

        section = o['use_section'] ? planes.first : nil
        bb = Geom::BoundingBox.new
        parts.each { |cs| cs.each { |c| bb.add(c) } }
        face = section ? section_face(model, section) : pick_face(model, bb, o['face'])
        n, rv, uv = frame(face)

        rows = parts.map do |cs|
          rs = cs.map { |c| dot(c, rv) }
          us = cs.map { |c| dot(c, uv) }
          fs = cs.map { |c| dot(c, n) }
          { rmin: rs.min, rmax: rs.max, umin: us.min, umax: us.max, fmin: fs.min, fmax: fs.max }
        end
        big = rows.select { |p| [p[:rmax] - p[:rmin], p[:umax] - p[:umin]].max >= o['min_part'].to_f.mm }
        raise 'Mọi chi tiết đều nhỏ hơn ngưỡng "bỏ chi tiết nhỏ". Hãy giảm ngưỡng này.' if big.empty?

        if section
          f0 = dot(section[0], n)                 # dim nằm đúng trên mặt phẳng cắt
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

        name = "000_DIM_#{face[1].upcase}"
        created = []
        AutoStyle.suspend do
          model.start_operation('VGD Dim — Smart Dim', true)
          begin
            group = model.active_entities.add_group
            group.name = name
            group.layer = model.layers[name] || model.layers.add(name)
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
            created.each { |dimension| Core.style_dim(dimension, config['dim'], {}, false) }
            model.commit_operation
          rescue StandardError => e
            model.abort_operation
            raise e
          end
        end
        model.active_view.invalidate

        { 'face' => face, 'section' => !section.nil?, 'group' => name, 'total' => created.size,
          'h' => o['do_h'] ? seg_mm(hb) : [], 'v' => o['do_v'] ? seg_mm(vb) : [], 'parts' => use.size }
      end

      # ---- hình học ----
      # Trả về [pháp tuyến hướng ra người nhìn, trục "phải", trục "lên"] của mặt.
      def self.frame(face)
        n = Geom::Vector3d.new(*SIDES[face])
        case face
        when '+z' then [n, X, Y]
        when '-z' then [n, X, Geom::Vector3d.new(0, -1, 0)]
        else [n, Z.cross(n), Z]
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

      def self.pick_face(model, bb, mode)
        return mode if SIDES[mode]
        look = camera_look(model)
        keys = SIDES.keys
        if mode == 'axis'
          keys = VERTICAL
          dist = { '-y' => bb.min.y.abs, '+y' => bb.max.y.abs, '-x' => bb.min.x.abs, '+x' => bb.max.x.abs }
          best = dist.values.min
          keys = keys.select { |k| dist[k] - best < 1.mm }
        end
        keys.max_by { |k| -look.dot(Geom::Vector3d.new(*SIDES[k])) }
      end

      # ---- mặt cắt đang bật (tọa độ của context đang mở) ----
      def self.section_plane_of(entities, tr)
        return nil unless entities.respond_to?(:active_section_plane)
        sp = entities.active_section_plane
        return nil unless sp
        a, b, c, d = sp.get_plane
        len2 = a * a + b * b + c * c
        return nil if len2 < 1e-12
        len = Math.sqrt(len2)
        point = Geom::Point3d.new(-a * d / len2, -b * d / len2, -c * d / len2)
        normal = Geom::Vector3d.new(a / len, b / len, c / len)
        [tr * point, (tr * normal).normalize]
      rescue StandardError
        nil
      end

      def self.section_face(model, section)
        nrm = section[1]
        axis, val = { 'x' => nrm.x, 'y' => nrm.y, 'z' => nrm.z }.max_by { |_, v| v.abs }
        raise 'Mặt cắt đang bật không song song trục X/Y/Z; Smart Dim chưa hỗ trợ mặt cắt xiên.' if val.abs < 0.9994
        plus = Geom::Vector3d.new(*SIDES["+#{axis}"])
        camera_look(model).dot(plus) < 0 ? "+#{axis}" : "-#{axis}"   # mặt hướng về camera
      end

      # ---- thu thập chi tiết (bbox 8 góc, tọa độ của context đang mở) ----
      def self.corners(bb, t)
        (0..7).map { |i| t * bb.corner(i) }
      end

      def self.visible_entity?(e)
        return false if e.hidden? || (e.respond_to?(:locked?) && e.locked?)
        !(e.layer && e.layer.respond_to?(:visible?) && !e.layer.visible?)
      end

      def self.collect(list, tr, parts, path, planes)
        raise 'Tủ lồng quá sâu; hãy chọn một nhóm con.' if path.size > 64
        list.each do |e|
          next unless e.valid?
          next unless visible_entity?(e)
          case e
          when Sketchup::Group, Sketchup::ComponentInstance
            t = tr * e.transformation
            defn = e.definition
            raise 'Component lồng vòng; không thể đo.' if path.include?(defn)
            plane = section_plane_of(defn.entities, t)
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
            collect(kids, t, parts, path + [defn], planes)
          when Sketchup::Face
            parts << corners(e.bounds, tr)
          end
        end
      end
    end
  end
end
