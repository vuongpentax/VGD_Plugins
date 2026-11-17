module VGD
  module Structure
    # Dựng cột vào model theo kế hoạch (ColumnPlan): mỗi tầng một Group "Cột - <tên tầng>" trên tag S. COLUMN, chứa các ComponentInstance
    # dùng chung định nghĩa theo (rộng x sâu x cao). Mỗi lần dựng là MỘT bước hoàn tác; dựng lại thì thay nhóm cũ của tầng đó.
    # Chưa xác minh trong SketchUp thật (xem README): chỉ kiểm bằng giả lập.
    module ColumnBuilder
      GROUP_KIND = 'columns'.freeze
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)

      # Kiểm tra dữ liệu và lập kế hoạch TRƯỚC khi đụng model (không đổi model). raw_state: dữ liệu CHƯA kiểm tra (từ giao diện).
      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise ColumnPlan::Error, 'Hãy chọn ít nhất một tầng để dựng cột.' unless level_ids.is_a?(Array) && !level_ids.empty?
        plans = level_ids.uniq.map { |id| ColumnPlan.plan(state['grid'], state['types'], state['levels'], id) }
        raise ColumnPlan::Error, 'Các tầng đã chọn chưa có cột nào được chọn.' if plans.all? { |plan| plan[:items].empty? }
        total = plans.sum { |plan| plan[:items].size }
        raise ColumnPlan::Error, "Quá nhiều cột (#{total}); tối đa #{ColumnPlan::MAX_COLUMNS} mỗi lần dựng." if total > ColumnPlan::MAX_COLUMNS
        locked = plans.map { |plan| find(model, plan[:level]['id']) }.compact.find(&:locked?)
        raise ColumnPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        {state: state, plans: plans, total: total}
      end

      # Dựng theo kế hoạch đã chuẩn bị. KHÔNG mở thao tác hoàn tác (người gọi lo, để gộp nhiều loại vào một bước).
      def self.apply(model, ctx)
        state = ctx[:state]
        plans = ctx[:plans]
        layer = TagStore.ensure(model, Schema::TAGS['column'])
        definitions = {}
        plans.each do |plan|
          old = find(model, plan[:level]['id'])
          kept = IdKeeper.harvest(old)
          old.erase! if old
          next if plan[:items].empty?
          draw_level(model, plan, layer, definitions, kept)
        end
        orphans = remove_orphans(model, state['levels'].map { |l| l['id'] })
        Result.new(plans.map { |plan| {name: plan[:level]['name'], count: plan[:items].size, height: plan[:height]} }, ctx[:total], orphans[:removed], orphans[:locked], plans.flat_map { |plan| plan[:issues] })
      end

      # Dựng và lưu dữ liệu nguồn trong MỘT bước hoàn tác; lỗi thì hủy cả thao tác.
      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng cột', true)
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

      # Xóa cột của một tầng (hoặc mọi tầng nếu level_id là nil). Trả về số nhóm đã xóa.
      def self.remove(model, level_id = nil)
        groups = groups(model).select { |g| level_id.nil? || g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
        return 0 if groups.empty?
        raise ColumnPlan::Error, "Nhóm “#{groups.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi xóa." if groups.any?(&:locked?)
        model.start_operation('VGD Structure · Xóa cột', true)
        begin
          groups.each(&:erase!)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        groups.size
      end

      def self.groups(model)
        model.entities.grep(Sketchup::Group).select { |g| g.valid? && g.get_attribute(Schema::DICTIONARY, 'kind') == GROUP_KIND }
      end

      def self.find(model, level_id)
        groups(model).find { |g| g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
      end

      # Nhóm cột của tầng đã bị xóa khỏi danh sách tầng: dọn đi (bỏ qua nhóm bị khóa, không đụng).
      def self.remove_orphans(model, valid_ids)
        orphans = groups(model).reject { |g| valid_ids.include?(g.get_attribute(Schema::DICTIONARY, 'level')) }
        locked, free = orphans.partition(&:locked?)
        free.each(&:erase!)
        {removed: free.size, locked: locked.size}
      end

      def self.draw_level(model, plan, layer, definitions, kept = {})
        group = model.entities.add_group
        group.name = "Cột - #{plan[:level]['name']}"
        group.layer = layer
        group.set_attribute(Schema::DICTIONARY, 'kind', GROUP_KIND)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          definition = definition_for(model, item, definitions)
          instance = group.entities.add_instance(definition, Geom::Transformation.new(Geom::Point3d.new(item[:center][0].mm, item[:center][1].mm, plan[:z0].mm)))
          instance.name = "Cột #{item[:ref]} (#{plan[:level]['name']})"
          instance.layer = layer
          tag_instance(instance, plan, item)
          IdKeeper.assign(instance, instance.get_attribute('VGD_BIM_SOURCE', 'ref'), kept)
        end
      end

      # Dữ liệu trên cột để VGD BIM đọc (SPEC mục 2): nguồn, loại, ref, kích thước.
      def self.tag_instance(instance, plan, item)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        instance.set_attribute('VGD_BIM_SOURCE', 'kind', 'column')
        instance.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}")
        instance.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        instance.set_attribute(Schema::DICTIONARY, 'level_name', plan[:level]['name'])
        instance.set_attribute(Schema::DICTIONARY, 'level_elevation', plan[:level]['elevation'])
        instance.set_attribute(Schema::DICTIONARY, 'type', item[:type_name])
        instance.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('w' => item[:w], 'd' => item[:d], 'height' => item[:height]))
        instance.set_attribute(Schema::DICTIONARY, 'placement', JSON.generate('position' => item[:placement], 'x' => item[:modes]['x'], 'y' => item[:modes]['y']))
      end

      # Định nghĩa dùng chung cho mọi cột cùng rộng x sâu x cao: lăng trụ có tâm đáy ở gốc, cao theo +Z.
      def self.definition_for(model, item, definitions)
        key = [item[:w], item[:d], item[:height]]
        definitions[key] ||= begin
          name = "VGD Cột #{fmt(item[:w])}x#{fmt(item[:d])}x#{fmt(item[:height])}"
          existing = model.definitions[name]
          existing && existing.valid? ? existing : make_definition(model, name, item)
        end
      end

      def self.make_definition(model, name, item)
        definition = model.definitions.add(name)
        hw = (item[:w] / 2.0).mm
        hd = (item[:d] / 2.0).mm
        face = definition.entities.add_face([Geom::Point3d.new(-hw, -hd, 0), Geom::Point3d.new(hw, -hd, 0), Geom::Point3d.new(hw, hd, 0), Geom::Point3d.new(-hw, hd, 0)])
        face.reverse! if face.normal.z < 0
        face.pushpull(item[:height].mm)
        definition.set_attribute(Schema::DICTIONARY, 'kind', 'column_definition')
        definition
      end

      def self.fmt(value)
        value == value.round ? value.round.to_s : value.to_s
      end
    end
  end
end
