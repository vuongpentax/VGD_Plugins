module VGD
  module Structure
    # Dựng cầu thang vào model theo kế hoạch (StairPlace): mỗi tầng một Group "Cầu thang - <tên tầng>" chứa, cho mỗi cầu thang, một nhóm
    # "Cầu thang <mã>" (tag A. STAIR, các bậc là khối đặc) và một nhóm "Lan can <mã>" (tag A. RAILING: tay vịn là đường, cột là khối nhỏ).
    # Không dựng nếu có cầu thang đâm vào cột, dầm, tường hoặc có lỗi kế hoạch. Một bước hoàn tác. Chưa xác minh trong SketchUp thật.
    module StairBuilder
      GROUP_KIND = 'stairs'.freeze
      MAX_STAIRS = 200
      POST_SIZE = 40.0 # mm: cạnh tiết diện cột lan can
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)

      # Kiểm tra và lập kế hoạch TRƯỚC khi đụng model (không đổi model).
      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise StairPlan::Error, 'Hãy chọn ít nhất một tầng để dựng cầu thang.' unless level_ids.is_a?(Array) && !level_ids.empty?
        plans = level_ids.uniq.map do |id|
          StairPlace.plan(state['grid'], state['types'], state['beam_types'], state['wall_types'], state['stair_types'], state['levels'], id, state['opening_types'])
        end
        issues = plans.flat_map { |plan| plan[:issues] }
        raise StairPlan::Error, "Không dựng cầu thang: #{issues.join(' ')}" unless issues.empty?
        raise StairPlan::Error, 'Các tầng đã chọn chưa có cầu thang nào.' if plans.all? { |plan| plan[:items].empty? }
        total = plans.sum { |plan| plan[:items].size }
        raise StairPlan::Error, "Quá nhiều cầu thang (#{total}); tối đa #{MAX_STAIRS} mỗi lần dựng." if total > MAX_STAIRS
        locked = plans.map { |plan| find(model, plan[:level]['id']) }.compact.find(&:locked?)
        raise StairPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        {state: state, plans: plans, total: total}
      end

      # Dựng theo kế hoạch đã chuẩn bị. KHÔNG mở thao tác hoàn tác (người gọi lo).
      def self.apply(model, ctx)
        state = ctx[:state]
        stair_layer = TagStore.ensure(model, Schema::TAGS['stair'])
        rail_layer = TagStore.ensure(model, Schema::TAGS['railing'])
        ctx[:plans].each do |plan|
          old = find(model, plan[:level]['id'])
          kept = IdKeeper.harvest(old)
          old.erase! if old
          next if plan[:items].empty?
          draw_level(model, plan, stair_layer, rail_layer, kept)
        end
        orphans = remove_orphans(model, state['levels'].map { |l| l['id'] })
        Result.new(ctx[:plans].map { |plan| {name: plan[:level]['name'], count: plan[:items].size, top: plan[:level]['elevation']} }, ctx[:total], orphans[:removed], orphans[:locked], [])
      end

      # Dựng và lưu dữ liệu nguồn trong MỘT bước hoàn tác; lỗi thì hủy cả thao tác.
      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng cầu thang', true)
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

      # Gỡ nhóm cầu thang của một tầng (hoặc mọi tầng nếu level_id nil) trong MỘT bước hoàn tác. Nhóm bị khóa thì không gỡ.
      def self.remove(model, level_id = nil)
        found = groups(model).select { |g| level_id.nil? || g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
        return 0 if found.empty?
        raise StairPlan::Error, "Nhóm “#{found.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi gỡ." if found.any?(&:locked?)
        model.start_operation('VGD Structure · Gỡ cầu thang', true)
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

      def self.draw_level(model, plan, stair_layer, rail_layer, kept = {})
        group = model.entities.add_group
        group.name = "Cầu thang - #{plan[:level]['name']}"
        group.set_attribute(Schema::DICTIONARY, 'kind', GROUP_KIND)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          stair = group.entities.add_group
          stair.name = "Cầu thang #{item[:ref]} (#{plan[:level]['name']})"
          stair.layer = stair_layer
          draw_steps(stair.entities, item)
          tag_stair(stair, plan, item, 'stair')
          IdKeeper.assign(stair, stair.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
          rails = group.entities.add_group
          rails.name = "Lan can #{item[:ref]} (#{plan[:level]['name']})"
          rails.layer = rail_layer
          draw_railings(rails.entities, item)
          tag_stair(rails, plan, item, 'railing')
        end
      end

      # Các bậc là khối đặc từ đáy sàn đến mặt bậc (mỗi bậc một khối, không chồng thể tích).
      def self.draw_steps(entities, item)
        item[:plan][:steps].each do |step|
          points = step[:poly].map { |x, y| Geom::Point3d.new(x.mm, y.mm, step[:z0].mm) }
          face = entities.add_face(points)
          face.reverse! if face.normal.z < 0
          face.pushpull((step[:z1] - step[:z0]).mm)
        end
      end

      # Tay vịn: đường nối hai đầu (cao độ đã tính); cột lan can: khối vuông nhỏ từ mặt bậc lên tay vịn.
      def self.draw_railings(entities, item)
        item[:plan][:rails].each do |rail|
          if rail[:kind] == 'handrail'
            entities.add_line(point(rail[:from]), point(rail[:to]))
          else
            x, y, z = rail[:from]
            half = POST_SIZE / 2.0
            corners = [[x - half, y - half], [x + half, y - half], [x + half, y + half], [x - half, y + half]].map { |px, py| Geom::Point3d.new(px.mm, py.mm, z.mm) }
            face = entities.add_face(corners)
            face.reverse! if face.normal.z < 0
            face.pushpull((rail[:to][2] - z).mm)
          end
        end
      end

      def self.point(xyz)
        Geom::Point3d.new(xyz[0].mm, xyz[1].mm, xyz[2].mm)
      end

      # Dữ liệu trên cầu thang / lan can để VGD BIM đọc (kiểu VGD_BIM_SOURCE 'stair' hoặc 'railing').
      def self.tag_stair(group, plan, item, kind)
        group.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        group.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        group.set_attribute('VGD_BIM_SOURCE', 'kind', kind)
        group.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}")
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        group.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        group.set_attribute(Schema::DICTIONARY, 'fp', ModelSync.fingerprint('stair', fingerprint_item(item)))
        group.set_attribute(Schema::DICTIONARY, 'type', item[:type_name])
        group.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('width' => item[:plan][:width], 'run' => item[:plan][:run], 'rise' => item[:plan][:rise], 'count' => item[:plan][:count], 'riser' => item[:plan][:riser], 'tread' => item[:plan][:tread]))
        group.set_attribute(Schema::DICTIONARY, 'part', kind)
      end

      def self.fingerprint_item(item)
        {polygon: item[:polygon], z0: item[:z0], z1: item[:z1], type: item[:type], rails: item[:plan][:rails]}
      end
    end
  end
end
