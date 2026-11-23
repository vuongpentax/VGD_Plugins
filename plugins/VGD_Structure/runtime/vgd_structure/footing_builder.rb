module VGD
  module Structure
    # Dựng đế móng (đế đơn, bậc trên của móng giật cấp, đoạn móng băng) theo kế hoạch (FootingPlan): mỗi tầng móng một Group "Móng - <tên tầng>" trên tag S. FOOTING, chứa các ComponentInstance
    # dùng chung định nghĩa theo (dài x rộng x dày). Cùng mô hình prepare / apply với các builder khác (AllBuilder gộp một bước hoàn tác).
    # Chưa xác minh trong SketchUp thật: chỉ kiểm bằng giả lập.
    module FootingBuilder
      GROUP_KIND = 'footings'.freeze
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)

      # level_ids: tầng cần dựng; tầng không có `footing` bị bỏ qua (không lỗi) để "dựng tất cả" dùng được cho mọi tầng.
      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise FootingPlan::Error, 'Hãy chọn ít nhất một tầng để dựng móng.' unless level_ids.is_a?(Array) && !level_ids.empty?
        ids = level_ids.uniq.select { |id| (Levels.find(state['levels'], id) || {})['footing'] }
        raise FootingPlan::Error, 'Các tầng đã chọn chưa khai báo móng.' if ids.empty?
        plans = ids.map { |id| FootingPlan.plan(state['grid'], state['types'], state['levels'], id, state['beam_types'], state['wall_types'], state['opening_types']) }
        raise FootingPlan::Error, 'Tầng móng chưa có cột nào (hoặc tường khi bật móng băng): móng đặt dưới chân cột và dưới tường.' if plans.all? { |plan| plan[:items].empty? }
        locked = plans.map { |plan| find(model, plan[:level]['id']) }.compact.find(&:locked?)
        raise FootingPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        {state: state, plans: plans, total: plans.sum { |plan| plan[:items].size }}
      end

      def self.apply(model, ctx)
        layer = TagStore.ensure(model, Schema::TAGS['footing'])
        definitions = {}
        ctx[:plans].each do |plan|
          old = find(model, plan[:level]['id'])
          kept = IdKeeper.harvest(old)
          old.erase! if old
          draw_level(model, plan, layer, definitions, kept) unless plan[:items].empty?
        end
        # Nhóm móng của tầng không còn, hoặc tầng đã bỏ khai báo móng: dọn đi (bỏ qua nhóm bị khóa).
        valid = ctx[:state]['levels'].select { |l| l['footing'] }.map { |l| l['id'] }
        orphans = groups(model).reject { |g| valid.include?(g.get_attribute(Schema::DICTIONARY, 'level')) }
        locked, free = orphans.partition(&:locked?)
        free.each(&:erase!)
        Result.new(ctx[:plans].map { |plan| {name: plan[:level]['name'], count: plan[:items].size} }, ctx[:total], free.size, locked.size, ctx[:plans].flat_map { |plan| plan[:issues] })
      end

      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng móng', true)
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
        raise FootingPlan::Error, "Nhóm “#{list.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi xóa." if list.any?(&:locked?)
        model.start_operation('VGD Structure · Xóa móng', true)
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

      def self.draw_level(model, plan, layer, definitions, kept)
        group = model.entities.add_group
        group.name = "Móng - #{plan[:level]['name']}"
        group.layer = layer
        group.set_attribute(Schema::DICTIONARY, 'kind', GROUP_KIND)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          key = [item[:w], item[:d], item[:h]]
          definition = definitions[key] ||= begin
            name = "VGD Móng #{ColumnBuilder.fmt(item[:w])}x#{ColumnBuilder.fmt(item[:d])}x#{ColumnBuilder.fmt(item[:h])}"
            existing = model.definitions[name]
            existing && existing.valid? ? existing : make_definition(model, name, item)
          end
          instance = group.entities.add_instance(definition, Placement.transformation(item, item[:center][0], item[:center][1], item[:z0]))
          instance.name = "#{label(item)} (#{plan[:level]['name']})"
          instance.layer = layer
          tag_instance(instance, plan, item)
          IdKeeper.assign(instance, instance.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
        end
      end

      def self.label(item)
        case item[:kind]
        when 'step' then "Móng #{item[:column]} bậc trên"
        when 'strip' then "Móng băng #{item[:wall]}"
        else "Móng #{item[:ref]}"
        end
      end

      # Dữ liệu cho VGD BIM (SPEC mục 2): dims cùng khóa với cột (w, d, height) để BIM tính thể tích như cột.
      # Móng băng: w = bề rộng đế, d = chiều dài đoạn, height = dày (w x d x height vẫn là thể tích).
      def self.tag_instance(instance, plan, item)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        instance.set_attribute('VGD_BIM_SOURCE', 'kind', 'footing')
        instance.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}")
        instance.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        instance.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        instance.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        instance.set_attribute(Schema::DICTIONARY, 'fp', ModelSync.fingerprint('footing', item))
        if item[:kind] == 'strip'
          instance.set_attribute(Schema::DICTIONARY, 'type', "Móng băng #{ColumnBuilder.fmt(item[:width])}x#{ColumnBuilder.fmt(item[:h])}")
          instance.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('w' => item[:width], 'd' => item[:length], 'height' => item[:h]))
        else
          instance.set_attribute(Schema::DICTIONARY, 'type', item[:type_name] || "Móng #{ColumnBuilder.fmt(item[:w])}x#{ColumnBuilder.fmt(item[:d])}x#{ColumnBuilder.fmt(item[:h])}")
          instance.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('w' => item[:w], 'd' => item[:d], 'height' => item[:h]))
        end
      end

      def self.make_definition(model, name, item)
        definition = ColumnBuilder.make_definition(model, name, {w: item[:w], d: item[:d], height: item[:h]})
        definition.set_attribute(Schema::DICTIONARY, 'kind', 'footing_definition')
        definition
      end
    end
  end
end
