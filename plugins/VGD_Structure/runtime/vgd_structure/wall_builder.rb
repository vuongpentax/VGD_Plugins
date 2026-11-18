module VGD
  module Structure
    # Dựng tường vào model theo kế hoạch (WallPlan): mỗi tầng một Group "Tường - <tên tầng>" trên tag A. WALL chứa các ComponentInstance dùng chung
    # định nghĩa theo (phương, dày, cao, dài). Một bước hoàn tác; dựng lại thì thay nhóm cũ của tầng đó. Chưa xác minh trong SketchUp thật.
    module WallBuilder
      GROUP_KIND = 'walls'.freeze
      MAX_WALLS = 8000
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)

      # Kiểm tra dữ liệu và lập kế hoạch TRƯỚC khi đụng model (không đổi model). raw_state: dữ liệu CHƯA kiểm tra (từ giao diện).
      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise WallPlan::Error, 'Hãy chọn ít nhất một tầng để dựng tường.' unless level_ids.is_a?(Array) && !level_ids.empty?
        plans = level_ids.uniq.map { |id| WallPlan.plan(state['grid'], state['types'], state['beam_types'], state['wall_types'], state['levels'], id, state['opening_types']) }
        raise WallPlan::Error, 'Các tầng đã chọn chưa có tường nào được chọn.' if plans.all? { |plan| plan[:items].empty? }
        total = plans.sum { |plan| plan[:items].size }
        raise WallPlan::Error, "Quá nhiều tường (#{total}); tối đa #{MAX_WALLS} mỗi lần dựng." if total > MAX_WALLS
        locked = plans.map { |plan| find(model, plan[:level]['id']) }.compact.find(&:locked?)
        raise WallPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        {state: state, plans: plans, total: total}
      end

      # Dựng theo kế hoạch đã chuẩn bị. KHÔNG mở thao tác hoàn tác (người gọi lo, để gộp nhiều loại vào một bước).
      def self.apply(model, ctx)
        state = ctx[:state]
        plans = ctx[:plans]
        layer = TagStore.ensure(model, Schema::TAGS['wall'])
        definitions = {}
        plans.each do |plan|
          old = find(model, plan[:level]['id'])
          kept = IdKeeper.harvest(old)
          old.erase! if old
          next if plan[:items].empty?
          draw_level(model, plan, layer, definitions, kept)
        end
        orphans = remove_orphans(model, state['levels'].map { |l| l['id'] })
        Result.new(plans.map { |plan| {name: plan[:level]['name'], count: plan[:items].size, top: plan[:z_slab]} }, ctx[:total], orphans[:removed], orphans[:locked], plans.flat_map { |plan| plan[:issues] })
      end

      # Dựng và lưu dữ liệu nguồn trong MỘT bước hoàn tác; lỗi thì hủy cả thao tác.
      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng tường', true)
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
        found = groups(model).select { |g| level_id.nil? || g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
        return 0 if found.empty?
        raise WallPlan::Error, "Nhóm “#{found.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi xóa." if found.any?(&:locked?)
        model.start_operation('VGD Structure · Xóa tường', true)
        begin
          found.each(&:erase!)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        found.size
      end

      def self.groups(model)
        model.entities.grep(Sketchup::Group).select { |g| g.valid? && g.get_attribute(Schema::DICTIONARY, 'kind') == GROUP_KIND }
      end

      def self.find(model, level_id)
        groups(model).find { |g| g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
      end

      def self.remove_orphans(model, valid_ids)
        orphans = groups(model).reject { |g| valid_ids.include?(g.get_attribute(Schema::DICTIONARY, 'level')) }
        locked, free = orphans.partition(&:locked?)
        free.each(&:erase!)
        {removed: free.size, locked: locked.size}
      end

      def self.draw_level(model, plan, layer, definitions, kept = {})
        group = model.entities.add_group
        group.name = "Tường - #{plan[:level]['name']}"
        group.layer = layer
        group.set_attribute(Schema::DICTIONARY, 'kind', GROUP_KIND)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          definition = definition_for(model, item, definitions)
          origin = item[:dir] == 'o' ? item[:a] : item[:dir] == 'x' ? [item[:start], item[:center]] : [item[:center], item[:start]]
          instance = group.entities.add_instance(definition, Placement.transformation(item, origin[0], origin[1], item[:z_bottom]))
          instance.name = "Tường #{item[:ref]} (#{plan[:level]['name']})"
          instance.layer = layer
          tag_instance(instance, plan, item)
          IdKeeper.assign(instance, instance.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
        end
      end

      # Dữ liệu trên tường để VGD BIM đọc (SPEC mục 2).
      def self.tag_instance(instance, plan, item)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        instance.set_attribute('VGD_BIM_SOURCE', 'kind', 'wall')
        instance.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}")
        instance.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        instance.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        instance.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        instance.set_attribute(Schema::DICTIONARY, 'fp', ModelSync.fingerprint('wall', item))
        instance.set_attribute(Schema::DICTIONARY, 'type', item[:type_name])
        instance.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('thickness' => item[:t], 'height' => item[:height], 'length' => item[:length], 'under_beam' => item[:under_beam], 'openings' => item[:openings].size, 'openings_area' => item[:openings_area], **layer_dims(item)))
        instance.set_attribute(Schema::DICTIONARY, 'placement', JSON.generate('position' => item[:placement], 'p' => item[:mode], 'dir' => item[:dir]))
      end

      # Khối lượng từng lớp (VGD BIM đọc để bóc): diện tích mặt trừ lỗ cửa (m²) và thể tích (m³) = diện tích x bề dày lớp.
      def self.layer_dims(item)
        return {} unless item[:layers]
        area = [item[:length] * item[:height] / 1_000_000.0 - item[:openings_area].to_f, 0.0].max
        {'layers' => item[:layers].each_with_index.map do |l, i|
          {'index' => i + 1, 'fn' => l[:fn], 'material' => l[:material], 'thickness' => l[:t], 'area' => area.round(4), 'volume' => (area * l[:t] / 1000.0).round(4)}
        end}
      end

      # Định nghĩa dùng chung cho mọi tường cùng phương, dày, cao, dài, lỗ và lớp: lăng trụ có mặt đáy tại z = 0, dài theo +X (tường X) hoặc +Y (tường Y),
      # gốc ở tâm đầu tường. Tường nhiều lớp: mỗi lớp là một Group con (kèm chức năng, vật liệu, màu), xếp từ phía -Y (tường X) / -X (tường Y).
      def self.definition_for(model, item, definitions)
        item = item.merge(dir: Placement.frame_dir(item)) # tường xiên dùng định nghĩa tường X rồi xoay
        holes = item[:openings].map { |o| [o[:x0], o[:x1], o[:z0], o[:z1]] }
        layers = item[:layers]
        key = [item[:dir], item[:t], item[:height], item[:length], holes, layers]
        definitions[key] ||= begin
          name = "VGD Tường #{item[:dir].upcase} #{fmt(item[:t])}x#{fmt(item[:height])}x#{fmt(item[:length])}#{holes.empty? ? '' : " lỗ #{holes.flatten.map { |v| fmt(v) }.join('_')}"}"
          name += " lớp #{layers.map { |l| fmt(l[:t]) }.join('_')} #{Digest::SHA1.hexdigest(JSON.generate(layers))[0, 8]}" if layers
          name = "VGD Tường #{item[:dir].upcase} #{Digest::SHA1.hexdigest(name)[0, 12]}" if name.length > 90
          existing = model.definitions[name]
          existing && existing.valid? ? existing : make_definition(model, name, item)
        end
      end

      def self.make_definition(model, name, item)
        definition = model.definitions.add(name)
        half = item[:t] / 2.0
        if item[:layers]
          from = -half
          item[:layers].each_with_index do |layer, i|
            group = definition.entities.add_group
            group.name = "Lớp #{i + 1} - #{WallTypes::FUNCTIONS[layer[:fn]]}#{layer[:material].empty? ? '' : " (#{layer[:material]})"}"
            group.set_attribute(Schema::DICTIONARY, 'layer', JSON.generate('index' => i + 1, 'fn' => layer[:fn], 'thickness' => layer[:t], 'material' => layer[:material]))
            group.material = layer_material(model, layer)
            fill(group.entities, item, from, from + layer[:t])
            from += layer[:t]
          end
        else
          fill(definition.entities, item, -half, half)
        end
        definition.set_attribute(Schema::DICTIONARY, 'kind', 'wall_definition')
        definition
      end

      # Vật liệu của lớp theo màu (dùng lại nếu đã có).
      def self.layer_material(model, layer)
        name = "VGD Tường #{layer[:fn]} #{layer[:color]}"
        material = model.materials[name]
        return material if material
        material = model.materials.add(name)
        hex = layer[:color].delete('#').scan(/../).map { |h| h.to_i(16) }
        material.color = Sketchup::Color.new(*hex)
        material
      end

      # Khối lăng trụ giữa hai mặt song song theo bề dày (lo..hi, tính từ tim tường), có khoét lỗ cửa nếu có.
      def self.fill(entities, item, lo, hi)
        item[:openings].empty? ? fill_solid(entities, item, lo, hi) : fill_with_holes(entities, item, lo, hi)
      end

      def self.fill_solid(entities, item, lo, hi)
        long = item[:length].mm
        a = lo.mm
        b = hi.mm
        points = if item[:dir] == 'x'
                   [Geom::Point3d.new(0, a, 0), Geom::Point3d.new(long, a, 0), Geom::Point3d.new(long, b, 0), Geom::Point3d.new(0, b, 0)]
                 else
                   [Geom::Point3d.new(a, 0, 0), Geom::Point3d.new(b, 0, 0), Geom::Point3d.new(b, long, 0), Geom::Point3d.new(a, long, 0)]
                 end
        face = entities.add_face(points)
        face.reverse! if face.normal.z < 0
        face.pushpull(item[:height].mm)
      end

      # Tường có lỗ cửa: mặt đứng (dài x cao) có các lỗ chữ nhật rồi đùn theo bề dày; lỗ tạo bằng cách thêm mặt nhỏ bên trong rồi xóa mặt đó.
      # Chưa xác minh trong SketchUp thật (đùn mặt có lỗ).
      def self.fill_with_holes(entities, item, lo, hi)
        plane = ->(u, z) { item[:dir] == 'x' ? Geom::Point3d.new(u.mm, lo.mm, z.mm) : Geom::Point3d.new(lo.mm, u.mm, z.mm) }
        rect = ->(u0, u1, z0, z1) { [plane.call(u0, z0), plane.call(u1, z0), plane.call(u1, z1), plane.call(u0, z1)] }
        face = entities.add_face(rect.call(0, item[:length], 0, item[:height]))
        item[:openings].each do |o|
          inner = entities.add_face(rect.call(o[:x0], o[:x1], o[:z0], o[:z1]))
          inner.erase! if inner
        end
        axis = item[:dir] == 'x' ? :y : :x
        face.reverse! if face.normal.send(axis) < 0
        face.pushpull((hi - lo).mm)
      end

      def self.fmt(value)
        value == value.round ? value.round.to_s : value.to_s
      end
    end
  end
end
