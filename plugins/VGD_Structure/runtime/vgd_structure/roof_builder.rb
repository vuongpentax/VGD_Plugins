module VGD
  module Structure
    # Dựng mái theo kế hoạch (RoofPlan): mỗi tầng có mái một Group "Mái - <tên tầng>" trên tag A. ROOF; mỗi tấm mái là một Group con gồm mặt trên,
    # mặt dưới (dời xuống tv theo phương đứng) và các mặt bên (bốn, hoặc ba với tấm tam giác của mái bốn dốc), dựng bằng add_face (không pushpull mặt nghiêng). Cùng mô hình prepare / apply.
    # Tường thu hồi (nếu bật): mỗi tường là một Group con của nhóm mái, tag A. WALL, kind wall trong VGD_BIM_SOURCE, dựng bằng add_face từ biên dạng (không pushpull).
    # Chưa xác minh trong SketchUp thật: chiều pháp tuyến các mặt, mặt nghiêng, khối tường thu hồi.
    module RoofBuilder
      GROUP_KIND = 'roofs'.freeze
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)

      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise RoofPlan::Error, 'Hãy chọn ít nhất một tầng để dựng mái.' unless level_ids.is_a?(Array) && !level_ids.empty?
        ids = level_ids.uniq.select { |id| (Levels.find(state['levels'], id) || {})['roof'] }
        raise RoofPlan::Error, 'Các tầng đã chọn chưa khai báo mái.' if ids.empty?
        plans = ids.map { |id| RoofPlan.plan(state['grid'], state['levels'], id, state['wall_types']) }
        locked = plans.map { |plan| find(model, plan[:level]['id']) }.compact.find(&:locked?)
        raise RoofPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        {state: state, plans: plans, total: plans.sum { |plan| plan[:items].size + plan[:gables].size }}
      end

      def self.apply(model, ctx)
        layer = TagStore.ensure(model, Schema::TAGS['roof'])
        ctx[:plans].each do |plan|
          old = find(model, plan[:level]['id'])
          kept = IdKeeper.harvest(old)
          old.erase! if old
          draw_level(model, plan, layer, kept)
        end
        valid = ctx[:state]['levels'].select { |l| l['roof'] }.map { |l| l['id'] }
        orphans = groups(model).reject { |g| valid.include?(g.get_attribute(Schema::DICTIONARY, 'level')) }
        locked, free = orphans.partition(&:locked?)
        free.each(&:erase!)
        Result.new(ctx[:plans].map { |plan| {name: plan[:level]['name'], count: plan[:items].size, gables: plan[:gables].size} }, ctx[:total], free.size, locked.size, ctx[:plans].flat_map { |plan| plan[:issues] })
      end

      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng mái', true)
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
        raise RoofPlan::Error, "Nhóm “#{list.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi xóa." if list.any?(&:locked?)
        model.start_operation('VGD Structure · Xóa mái', true)
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
        group.name = "Mái - #{plan[:level]['name']}"
        group.layer = layer
        group.set_attribute(Schema::DICTIONARY, 'kind', GROUP_KIND)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          plate = group.entities.add_group
          plate.name = "Mái #{item[:ref]} (#{plan[:level]['name']})"
          plate.layer = layer
          top = item[:top].map { |x, y, z| Geom::Point3d.new(x.mm, y.mm, z.mm) }
          bottom = item[:top].map { |x, y, z| Geom::Point3d.new(x.mm, y.mm, (z - item[:tv]).mm) }
          plate.entities.add_face(top)
          plate.entities.add_face(bottom.reverse)
          top.size.times { |i| j = (i + 1) % top.size; plate.entities.add_face([bottom[i], bottom[j], top[j], top[i]]) } # 3 (tam giác) hoặc 4 mặt bên
          tag_instance(plate, plan, item)
          IdKeeper.assign(plate, plate.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
        end
        draw_gables(model, group, plan, kept)
      end

      EDGE_NAMES = {'south' => 'nam', 'east' => 'đông', 'north' => 'bắc', 'west' => 'tây'}.freeze

      # Tường thu hồi: biên dạng (s, z) dọc cạnh biên, đùn vào trong khung theo bề dày loại tường. Đáy ở mặt sàn kết cấu; đỉnh theo đáy mái.
      def self.draw_gables(model, group, plan, kept)
        return if plan[:gables].empty?
        layer = TagStore.ensure(model, Schema::TAGS['wall'])
        plan[:gables].each do |gable|
          wall = group.entities.add_group
          wall.name = "Tường thu hồi #{EDGE_NAMES[gable[:edge]]} (#{plan[:level]['name']})"
          wall.layer = layer
          shape = gable_polygon(gable)
          point = lambda do |s, z, offset|
            f = s / gable[:length]
            x = gable[:a][0] + (gable[:b][0] - gable[:a][0]) * f + gable[:inward][0] * offset
            y = gable[:a][1] + (gable[:b][1] - gable[:a][1]) * f + gable[:inward][1] * offset
            Geom::Point3d.new(x.mm, y.mm, z.mm)
          end
          outer = shape.map { |s, z| point.call(s, z, 0.0) }
          inner = shape.map { |s, z| point.call(s, z, gable[:t]) }
          wall.entities.add_face(outer)
          wall.entities.add_face(inner.reverse)
          shape.size.times { |i| j = (i + 1) % shape.size; wall.entities.add_face([outer[i], outer[j], inner[j], inner[i]]) }
          tag_gable(wall, plan, gable)
          IdKeeper.assign(wall, wall.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
        end
      end

      # Đa giác biên dạng: đáy (hai góc dưới ở mặt sàn), rồi đáy mái từ cuối về đầu; bỏ đỉnh trùng khi đáy mái ngang mặt sàn.
      def self.gable_polygon(gable)
        floor = gable[:floor]
        points = [[0.0, floor], [gable[:length], floor]] + gable[:profile].reverse.map { |s, z| [s, [z, floor].max] }
        points.each_with_index.reject { |(s, z), i| (s - points[i - 1][0]).abs < 0.01 && (z - points[i - 1][1]).abs < 0.01 }.map(&:first)
      end

      # Dữ liệu cho VGD BIM: kind wall, dims thickness / height (trung bình) / length để BIM tính diện tích = dài x cao = diện tích biên dạng.
      def self.tag_gable(wall, plan, gable)
        wall.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        wall.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        wall.set_attribute('VGD_BIM_SOURCE', 'kind', 'wall')
        wall.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{gable[:ref]}")
        wall.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        wall.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        wall.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        wall.set_attribute(Schema::DICTIONARY, 'fp', ModelSync.fingerprint('roof', top: gable[:profile], tv: gable[:t]))
        wall.set_attribute(Schema::DICTIONARY, 'type', "Tường thu hồi (#{gable[:type_name]})")
        wall.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('thickness' => gable[:t], 'height' => gable[:height], 'length' => gable[:length], 'under_beam' => false, 'openings' => 0, 'openings_area' => 0))
        wall.set_attribute(Schema::DICTIONARY, 'placement', JSON.generate('position' => 'gable', 'edge' => gable[:edge]))
      end

      # Dữ liệu cho VGD BIM: dims thickness (mm, vuông góc mặt mái) và area (m², diện tích nghiêng) nên BIM tính thể tích = diện tích x dày.
      def self.tag_instance(plate, plan, item)
        plate.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        plate.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        plate.set_attribute('VGD_BIM_SOURCE', 'kind', 'roof')
        plate.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}")
        plate.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        plate.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        plate.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        plate.set_attribute(Schema::DICTIONARY, 'fp', ModelSync.fingerprint('roof', item))
        plate.set_attribute(Schema::DICTIONARY, 'type', "Mái #{{'flat' => 'bằng', 'shed' => 'một dốc', 'gable' => 'hai dốc', 'hip' => 'bốn dốc'}[item[:shape]]}")
        plate.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('thickness' => item[:thickness], 'area' => item[:area], 'slope' => item[:slope]))
      end
    end
  end
end
