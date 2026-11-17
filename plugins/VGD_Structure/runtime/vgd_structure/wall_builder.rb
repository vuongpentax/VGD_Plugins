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
          origin = item[:dir] == 'x' ? [item[:start], item[:center]] : [item[:center], item[:start]]
          instance = group.entities.add_instance(definition, Geom::Transformation.new(Geom::Point3d.new(origin[0].mm, origin[1].mm, item[:z_bottom].mm)))
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
        instance.set_attribute(Schema::DICTIONARY, 'type', item[:type_name])
        instance.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('thickness' => item[:t], 'height' => item[:height], 'length' => item[:length], 'under_beam' => item[:under_beam], 'openings' => item[:openings].size, 'openings_area' => item[:openings_area]))
        instance.set_attribute(Schema::DICTIONARY, 'placement', JSON.generate('position' => item[:placement], 'p' => item[:mode], 'dir' => item[:dir]))
      end

      # Định nghĩa dùng chung cho mọi tường cùng phương, dày, cao, dài: lăng trụ có mặt đáy tại z = 0, dài theo +X (tường X) hoặc +Y (tường Y),
      # gốc ở tâm đầu tường.
      def self.definition_for(model, item, definitions)
        holes = item[:openings].map { |o| [o[:x0], o[:x1], o[:z0], o[:z1]] }
        key = [item[:dir], item[:t], item[:height], item[:length], holes]
        definitions[key] ||= begin
          name = "VGD Tường #{item[:dir].upcase} #{fmt(item[:t])}x#{fmt(item[:height])}x#{fmt(item[:length])}#{holes.empty? ? '' : " lỗ #{holes.flatten.map { |v| fmt(v) }.join('_')}"}"
          existing = model.definitions[name]
          existing && existing.valid? ? existing : make_definition(model, name, item)
        end
      end

      def self.make_definition(model, name, item)
        return make_definition_with_holes(model, name, item) unless item[:openings].empty?
        definition = model.definitions.add(name)
        half = (item[:t] / 2.0).mm
        long = item[:length].mm
        points = if item[:dir] == 'x'
                   [Geom::Point3d.new(0, -half, 0), Geom::Point3d.new(long, -half, 0), Geom::Point3d.new(long, half, 0), Geom::Point3d.new(0, half, 0)]
                 else
                   [Geom::Point3d.new(-half, 0, 0), Geom::Point3d.new(half, 0, 0), Geom::Point3d.new(half, long, 0), Geom::Point3d.new(-half, long, 0)]
                 end
        face = definition.entities.add_face(points)
        face.reverse! if face.normal.z < 0
        face.pushpull(item[:height].mm)
        definition.set_attribute(Schema::DICTIONARY, 'kind', 'wall_definition')
        definition
      end

      # Tường có lỗ cửa: mặt đứng (dài x cao) có các lỗ chữ nhật rồi đùn theo bề dày; lỗ tạo bằng cách thêm mặt nhỏ bên trong rồi xóa mặt đó.
      # Chưa xác minh trong SketchUp thật (đùn mặt có lỗ).
      def self.make_definition_with_holes(model, name, item)
        definition = model.definitions.add(name)
        half = (item[:t] / 2.0).mm
        plane = ->(u, z) { item[:dir] == 'x' ? Geom::Point3d.new(u.mm, -half, z.mm) : Geom::Point3d.new(-half, u.mm, z.mm) }
        rect = ->(u0, u1, z0, z1) { [plane.call(u0, z0), plane.call(u1, z0), plane.call(u1, z1), plane.call(u0, z1)] }
        face = definition.entities.add_face(rect.call(0, item[:length], 0, item[:height]))
        item[:openings].each do |o|
          inner = definition.entities.add_face(rect.call(o[:x0], o[:x1], o[:z0], o[:z1]))
          inner.erase! if inner
        end
        axis = item[:dir] == 'x' ? :y : :x
        face.reverse! if face.normal.send(axis) < 0
        face.pushpull(item[:t].mm)
        definition.set_attribute(Schema::DICTIONARY, 'kind', 'wall_definition')
        definition
      end

      def self.fmt(value)
        value == value.round ? value.round.to_s : value.to_s
      end
    end
  end
end
