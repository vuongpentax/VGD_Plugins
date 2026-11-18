module VGD
  module Structure
    # Dựng cửa đi và cửa sổ (khung và cánh đơn giản theo tham số) vào lỗ đã khoét trên tường: mỗi tầng một Group "Cửa - <tên tầng>" chứa các ComponentInstance dùng chung
    # định nghĩa theo (loại, phương tường, rộng, cao, bề dày tường, mặt cánh). Cửa đi: khung chữ U (không ngưỡng) và cánh đặc; cửa sổ: khung vòng kín và kính.
    # Chỉ dựng cửa; lỗ trên tường do WallBuilder khoét theo cùng dữ liệu. Một bước hoàn tác; dựng lại thay nhóm cũ. Chưa xác minh trong SketchUp thật.
    module OpeningBuilder
      GROUP_KIND = 'openings'.freeze
      MAX_OPENINGS = 8000
      FRAME_WIDTH = 50.0    # bề rộng thanh khung (mm)
      LEAF_THICKNESS = 40.0 # bề dày cánh cửa đi (mm)
      GLASS_THICKNESS = 6.0 # bề dày kính cửa sổ (mm)
      LEAF_GAP = 5.0        # khe giữa cánh và khung (mm)
      LEAF_RECESS = 20.0    # cánh thụt vào so với mặt tường (mm)
      HANDLE_OFFSET = 90.0  # tay nắm cách mép cánh phía tự do (mm)
      HANDLE_WIDTH = 60.0   # kích thước tay nắm (mm)
      HANDLE_HEIGHT = 120.0
      HANDLE_DEPTH = 30.0   # tay nắm nhô khỏi mặt cánh (mm)
      HANDLE_Z = 950.0      # chân tay nắm tính từ đáy cửa (mm)
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)

      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise OpeningPlan::Error, 'Hãy chọn ít nhất một tầng để dựng cửa.' unless level_ids.is_a?(Array) && !level_ids.empty?
        plans = level_ids.uniq.map { |id| OpeningPlan.plan(state['grid'], state['types'], state['beam_types'], state['wall_types'], state['opening_types'], state['levels'], id) }
        raise OpeningPlan::Error, 'Các tầng đã chọn chưa có cửa nào được đặt (hoặc cửa bị bỏ qua).' if plans.all? { |plan| plan[:items].empty? }
        total = plans.sum { |plan| plan[:items].size }
        raise OpeningPlan::Error, "Quá nhiều cửa (#{total}); tối đa #{MAX_OPENINGS} mỗi lần dựng." if total > MAX_OPENINGS
        locked = plans.map { |plan| find(model, plan[:level]['id']) }.compact.find(&:locked?)
        raise OpeningPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        {state: state, plans: plans, total: total}
      end

      def self.apply(model, ctx)
        layers = {'door' => TagStore.ensure(model, Schema::TAGS['door']), 'window' => TagStore.ensure(model, Schema::TAGS['window'])}
        definitions = {}
        ctx[:plans].each do |plan|
          old = find(model, plan[:level]['id'])
          kept = IdKeeper.harvest(old)
          old.erase! if old
          next if plan[:items].empty?
          draw_level(model, plan, layers, definitions, kept)
        end
        orphans = remove_orphans(model, ctx[:state]['levels'].map { |l| l['id'] })
        Result.new(ctx[:plans].map { |plan| {name: plan[:level]['name'], count: plan[:items].size} }, ctx[:total], orphans[:removed], orphans[:locked], ctx[:plans].flat_map { |plan| plan[:issues] })
      end

      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng cửa', true)
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
        raise OpeningPlan::Error, "Nhóm “#{found.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi xóa." if found.any?(&:locked?)
        model.start_operation('VGD Structure · Xóa cửa', true)
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

      def self.draw_level(model, plan, layers, definitions, kept)
        group = model.entities.add_group
        group.name = "Cửa - #{plan[:level]['name']}"
        group.layer = layers['door']
        group.set_attribute(Schema::DICTIONARY, 'kind', GROUP_KIND)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          definition = definition_for(model, item, definitions)
          origin = item[:dir] == 'o' ? item[:origin] : item[:dir] == 'x' ? [item[:along], item[:center]] : [item[:center], item[:along]]
          instance = group.entities.add_instance(definition, Placement.transformation(item, origin[0], origin[1], item[:z_bottom]))
          instance.name = "#{item[:kind] == 'door' ? 'Cửa đi' : 'Cửa sổ'} #{item[:type_name]} (#{plan[:level]['name']})"
          instance.layer = layers[item[:kind]]
          tag_instance(instance, plan, item)
          IdKeeper.assign(instance, instance.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
        end
      end

      # Dữ liệu trên cửa để VGD BIM đọc (SPEC mục 2): đếm theo loại; diện tích lỗ trừ vào tường do BIM đọc từ tường.
      def self.tag_instance(instance, plan, item)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        instance.set_attribute('VGD_BIM_SOURCE', 'kind', item[:kind])
        instance.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}")
        instance.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        instance.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        instance.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        instance.set_attribute(Schema::DICTIONARY, 'fp', ModelSync.fingerprint('opening', item))
        instance.set_attribute(Schema::DICTIONARY, 'type', item[:type_name])
        instance.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('w' => item[:w], 'h' => item[:h], 'sill' => item[:sill], 'thickness' => item[:thickness], 'wall' => item[:wall]))
        instance.set_attribute(Schema::DICTIONARY, 'placement', JSON.generate({'dir' => item[:dir], 'pos' => item[:pos], 'flip' => item[:flip]}.merge(item[:mirror] ? {'mirror' => true} : {})))
      end

      def self.definition_for(model, item, definitions)
        item = item.merge(dir: Placement.frame_dir(item)) # cửa trên tường xiên dùng định nghĩa cửa X rồi xoay
        key = [item[:kind], item[:dir], item[:w], item[:h], item[:thickness], item[:flip], item[:mirror]]
        definitions[key] ||= begin
          name = "VGD #{item[:kind] == 'door' ? 'Cửa đi' : 'Cửa sổ'} #{item[:dir].upcase} #{fmt(item[:w])}x#{fmt(item[:h])}x#{fmt(item[:thickness])}#{item[:flip] ? ' lật' : ''}#{item[:mirror] && item[:kind] == 'door' ? ' bản lề cuối' : ''}"
          existing = model.definitions[name]
          existing && existing.valid? ? existing : make_definition(model, name, item)
        end
      end

      # Hệ tọa độ của định nghĩa giống tường: dọc theo cửa là +X (tường X) hoặc +Y (tường Y), gốc ở đầu cửa, tâm bề dày tường, đáy cửa tại z = 0.
      def self.make_definition(model, name, item)
        definition = model.definitions.add(name)
        w, h, t = item.values_at(:w, :h, :thickness)
        f = FRAME_WIDTH
        if item[:kind] == 'door'
          extrude(definition, [[0, 0], [f, 0], [f, h - f], [w - f, h - f], [w - f, 0], [w, 0], [w, h], [0, h]], -t / 2.0, t, item[:dir])
          recess = item[:flip] ? t / 2.0 - LEAF_RECESS - LEAF_THICKNESS : -t / 2.0 + LEAF_RECESS
          g = LEAF_GAP
          extrude(definition, rect(f + g, w - f - g, g, h - f - g), recess, LEAF_THICKNESS, item[:dir])
          # Tay nắm ở đầu tự do của cánh, nhô ra mặt cánh phía cánh mở (đối diện bản lề): nhìn trong 3D biết bản lề bên nào và cánh mở về phía nào.
          u0 = item[:mirror] ? f + g + HANDLE_OFFSET : w - f - g - HANDLE_OFFSET - HANDLE_WIDTH
          depth_from = item[:flip] ? recess - HANDLE_DEPTH : recess + LEAF_THICKNESS
          extrude(definition, rect(u0, u0 + HANDLE_WIDTH, HANDLE_Z, HANDLE_Z + HANDLE_HEIGHT), depth_from, HANDLE_DEPTH, item[:dir])
        else
          extrude(definition, rect(0, w, 0, h), -t / 2.0, t, item[:dir], holes: [rect(f, w - f, f, h - f)])
          extrude(definition, rect(f, w - f, f, h - f), -GLASS_THICKNESS / 2.0, GLASS_THICKNESS, item[:dir])
        end
        definition.set_attribute(Schema::DICTIONARY, 'kind', "#{item[:kind]}_definition")
        definition
      end

      def self.rect(u0, u1, z0, z1)
        [[u0, z0], [u1, z0], [u1, z1], [u0, z1]]
      end

      # Đùn một đa giác (u, z) nằm trong mặt đứng tại độ lệch `offset` (mm, vuông góc tường) theo bề dày `depth`; holes là các lỗ trong đa giác.
      def self.extrude(definition, polygon, offset, depth, dir, holes: [])
        point = ->((u, z)) { dir == 'x' ? Geom::Point3d.new(u.mm, offset.mm, z.mm) : Geom::Point3d.new(offset.mm, u.mm, z.mm) }
        face = definition.entities.add_face(polygon.map(&point))
        holes.each do |hole|
          inner = definition.entities.add_face(hole.map(&point))
          inner.erase! if inner
        end
        axis = dir == 'x' ? :y : :x
        face.reverse! if face.normal.send(axis) < 0
        face.pushpull(depth.mm)
        face
      end

      def self.fmt(value)
        value == value.round ? value.round.to_s : value.to_s
      end
    end
  end
end
