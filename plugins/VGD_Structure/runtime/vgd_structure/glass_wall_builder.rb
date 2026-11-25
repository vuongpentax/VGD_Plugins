module VGD
  module Structure
    # Dựng vách kính theo kế hoạch (GlassWallPlan): mỗi tầng một Group "Vách kính - <tên tầng>" (tag A. WINDOW); mỗi vách gồm HAI Group con tách vật liệu:
    # "Khung nhôm" (một mặt phẳng khung có lỗ ở chỗ tấm kính, đùn theo bề sâu khung) và "Kính" (các tấm kính, đùn theo bề dày kính). Hai nhóm có VGD ID và dữ liệu riêng
    # nên VGD BIM bóc khối lượng tách nhau: khung theo chiều dài thanh x tiết diện, kính theo diện tích x bề dày. Cùng mô hình prepare / apply / build như RoofBuilder.
    # Chưa xác minh trong SketchUp thật: đùn mặt có lỗ, chiều đùn theo phương vuông góc vách, vật liệu trong suốt; cách VGD BIM đọc kind window với part glass_frame / glass.
    module GlassWallBuilder
      GROUP_KIND = 'glass_walls'.freeze
      ALUMINIUM = {name: 'VGD Nhôm vách kính', color: [176, 180, 186]}.freeze
      GLASS = {name: 'VGD Kính vách kính', color: [150, 200, 230], alpha: 0.4}.freeze
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)

      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise GlassWallPlan::Error, 'Hãy chọn ít nhất một tầng để dựng vách kính.' unless level_ids.is_a?(Array) && !level_ids.empty?
        ids = level_ids.uniq.select { |id| !((Levels.find(state['levels'], id) || {})['glass_walls'] || {}).empty? }
        raise GlassWallPlan::Error, 'Các tầng đã chọn chưa khai báo vách kính.' if ids.empty?
        plans = ids.map { |id| GlassWallPlan.plan(state['grid'], state['levels'], id) }
        locked = plans.map { |plan| find(model, plan[:level]['id']) }.compact.find(&:locked?)
        raise GlassWallPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        {state: state, plans: plans, total: plans.sum { |plan| plan[:items].size * 2 }}
      end

      def self.apply(model, ctx)
        layer = TagStore.ensure(model, Schema::TAGS['window'])
        ctx[:plans].each do |plan|
          old = find(model, plan[:level]['id'])
          kept = IdKeeper.harvest(old)
          old.erase! if old
          draw_level(model, plan, layer, kept)
        end
        valid = ctx[:state]['levels'].reject { |l| (l['glass_walls'] || {}).empty? }.map { |l| l['id'] }
        orphans = groups(model).reject { |g| valid.include?(g.get_attribute(Schema::DICTIONARY, 'level')) }
        locked, free = orphans.partition(&:locked?)
        free.each(&:erase!)
        Result.new(ctx[:plans].map { |plan| {name: plan[:level]['name'], count: plan[:items].size} }, ctx[:total], free.size, locked.size, ctx[:plans].flat_map { |plan| plan[:issues] })
      end

      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng vách kính', true)
        begin
          result = apply(model, ctx)
          ModelStore.write(model, raw_state)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        result
      end

      def self.remove(model, level_id = nil)
        list = groups(model).select { |g| level_id.nil? || g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
        return 0 if list.empty?
        raise GlassWallPlan::Error, "Nhóm “#{list.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi xóa." if list.any?(&:locked?)
        model.start_operation('VGD Structure · Xóa vách kính', true)
        begin
          list.each(&:erase!)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        list.size
      end

      def self.groups(model)
        model.entities.grep(Sketchup::Group).select { |g| g.valid? && g.get_attribute(Schema::DICTIONARY, 'kind') == GROUP_KIND }
      end

      def self.find(model, level_id)
        groups(model).find { |g| g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
      end

      def self.draw_level(model, plan, layer, kept)
        group = model.entities.add_group
        group.name = "Vách kính - #{plan[:level]['name']}"
        group.layer = layer
        group.set_attribute(Schema::DICTIONARY, 'kind', GROUP_KIND)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          frame = group.entities.add_group
          frame.name = "Khung nhôm #{item[:ref]} (#{plan[:level]['name']})"
          frame.layer = layer
          frame.material = material(model, ALUMINIUM)
          extrude(frame.entities, item, [[0.0, item[:length], item[:z0], item[:z1]]], item[:panes], GlassWallPlan::FRAME_D)
          tag(frame, plan, item, 'frame')
          IdKeeper.assign(frame, frame.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
          glass = group.entities.add_group
          glass.name = "Kính #{item[:ref]} (#{plan[:level]['name']})"
          glass.layer = layer
          glass.material = material(model, GLASS)
          extrude(glass.entities, item, item[:panes], [], GlassWallPlan::GLASS_T)
          tag(glass, plan, item, 'glass')
          IdKeeper.assign(glass, glass.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
        end
      end

      def self.material(model, spec)
        model.materials[spec[:name]] || model.materials.add(spec[:name]).tap do |m|
          m.color = Sketchup::Color.new(*spec[:color])
          m.alpha = spec[:alpha] if spec[:alpha]
        end
      end

      # Các hình chữ nhật `rects` (s0, s1, za, zb) trong mặt phẳng vách đặt giữa bề sâu `depth` quanh tim nhịp; `holes` là các hình chữ nhật khoét khỏi mặt (tạo bằng cách thêm mặt nhỏ rồi xóa,
      # như PlateBuilder.extrude). Mặt quay về phía +t (vuông góc nhịp) rồi đùn `depth`. Lấy danh sách mặt trước khi đùn (đùn sinh thêm mặt bên).
      def self.extrude(entities, item, rects, holes, depth)
        sx = item[:b][0] - item[:a][0]
        sy = item[:b][1] - item[:a][1]
        len = Math.hypot(sx, sy)
        ux = sx / len
        uy = sy / len
        tx = -uy
        ty = ux
        half = depth / 2.0
        quad = lambda do |(s0, s1, za, zb)|
          [[s0, za], [s1, za], [s1, zb], [s0, zb]].map { |s, z| Geom::Point3d.new((item[:a][0] + ux * s - tx * half).mm, (item[:a][1] + uy * s - ty * half).mm, z.mm) }
        end
        rects.each { |r| entities.add_face(quad.call(r)) }
        holes.each { |r| (inner = entities.add_face(quad.call(r))) && inner.erase! }
        entities.grep(Sketchup::Face).each do |face|
          face.reverse! if face.normal.x * tx + face.normal.y * ty < 0
          face.pushpull(depth.mm)
        end
      end

      # Dữ liệu cho VGD BIM: kind window, part glass_frame / glass. Khung: w x h (tiết diện), length (tổng chiều dài thanh), volume (m3). Kính: thickness, area (m2), count, w x h từng tấm.
      def self.tag(entity, plan, item, part)
        frame = part == 'frame'
        entity.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        entity.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        entity.set_attribute('VGD_BIM_SOURCE', 'kind', 'window')
        entity.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}:#{part}")
        entity.set_attribute(Schema::DICTIONARY, 'part', frame ? 'glass_frame' : 'glass')
        entity.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        entity.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        entity.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        entity.set_attribute(Schema::DICTIONARY, 'fp', ModelSync.fingerprint('glass_wall', item))
        entity.set_attribute(Schema::DICTIONARY, 'type', frame ? "Khung nhôm vách kính #{GlassWallPlan::FRAME_W.to_i}×#{GlassWallPlan::FRAME_D.to_i}" : "Kính vách kính #{GlassWallPlan::GLASS_T.to_i} mm")
        dims = frame ? {'w' => GlassWallPlan::FRAME_W, 'h' => GlassWallPlan::FRAME_D, 'length' => item[:frame_length], 'volume' => item[:frame_volume]} :
                       {'thickness' => GlassWallPlan::GLASS_T, 'area' => item[:glass_area], 'count' => item[:count], 'w' => item[:pane_w], 'h' => item[:pane_h]}
        entity.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate(dims.merge('span' => item[:span], 'width' => item[:length], 'height' => item[:height])))
      end
    end
  end
end
