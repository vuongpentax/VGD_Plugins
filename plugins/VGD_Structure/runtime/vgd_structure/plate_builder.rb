module VGD
  module Structure
    # Dựng sàn và trần vào model (cùng cách, khác kế hoạch): mỗi tầng một Group "Sàn - <tên tầng>" (tag S. SLAB) hoặc "Trần - <tên tầng>" (tag A. FINISHING CEILING)
    # chứa các ComponentInstance dùng chung định nghĩa theo (đa giác tương đối, dày). Một bước hoàn tác; dựng lại thì thay nhóm cũ. Chưa xác minh trong SketchUp thật.
    module PlateBuilder
      MAX_ITEMS = 8000
      Result = Struct.new(:levels, :total, :removed_orphans, :locked_orphans, :issues)
      KINDS = {
        'slabs' => {name: 'Sàn', kind: 'slab', tag: 'slab', definition: 'Sàn', operation: 'Dựng sàn', remove_operation: 'Xóa sàn'},
        'ceilings' => {name: 'Trần', kind: 'ceiling', tag: 'ceiling', definition: 'Trần', operation: 'Dựng trần', remove_operation: 'Xóa trần'}
      }.freeze

      def self.spec(kind)
        KINDS.fetch(kind) { raise ArgumentError, 'Loại tấm không hợp lệ.' }
      end

      def self.plan_for(kind, state, id)
        case kind
        when 'slabs' then SlabPlan.plan(state['grid'], state['levels'], id)
        else CeilingPlan.plan(state['grid'], state['types'], state['beam_types'], state['wall_types'], state['levels'], id)
        end
      end

      # raw_state: dữ liệu CHƯA kiểm tra (từ giao diện); level_ids: mảng mã tầng. Kiểm tra lại và lập kế hoạch TRƯỚC khi đụng model.
      def self.build(model, raw_state, level_ids, kind)
        spec = spec(kind)
        state = State.normalize!(raw_state)
        raise SlabPlan::Error, "Hãy chọn ít nhất một tầng để dựng #{spec[:name].downcase}." unless level_ids.is_a?(Array) && !level_ids.empty?
        plans = level_ids.uniq.map { |id| plan_for(kind, state, id) }
        raise SlabPlan::Error, "Các tầng đã chọn chưa có ô #{spec[:name].downcase} nào được chọn (hoặc ô bị bỏ qua)." if plans.all? { |plan| plan[:items].empty? }
        total = plans.sum { |plan| plan[:items].size }
        raise SlabPlan::Error, "Quá nhiều ô (#{total}); tối đa #{MAX_ITEMS} mỗi lần dựng." if total > MAX_ITEMS
        locked = plans.map { |plan| find(model, kind, plan[:level]['id']) }.compact.find(&:locked?)
        raise SlabPlan::Error, "Nhóm “#{locked.name}” đang bị khóa. Hãy mở khóa rồi dựng lại." if locked
        model.start_operation("VGD Structure · #{spec[:operation]}", true)
        begin
          layer = TagStore.ensure(model, Schema::TAGS[spec[:tag]])
          definitions = {}
          plans.each do |plan|
            old = find(model, kind, plan[:level]['id'])
            old.erase! if old
            next if plan[:items].empty?
            draw_level(model, kind, plan, layer, definitions)
          end
          orphans = remove_orphans(model, kind, state['levels'].map { |l| l['id'] })
          ModelStore.write(model, raw_state)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        Result.new(plans.map { |plan| {name: plan[:level]['name'], count: plan[:items].size} }, total, orphans[:removed], orphans[:locked], plans.flat_map { |plan| plan[:issues] })
      end

      def self.remove(model, kind, level_id = nil)
        spec = spec(kind)
        found = groups(model, kind).select { |g| level_id.nil? || g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
        return 0 if found.empty?
        raise SlabPlan::Error, "Nhóm “#{found.find(&:locked?).name}” đang bị khóa. Hãy mở khóa rồi xóa." if found.any?(&:locked?)
        model.start_operation("VGD Structure · #{spec[:remove_operation]}", true)
        begin
          found.each(&:erase!)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        found.size
      end

      def self.groups(model, kind)
        model.entities.grep(Sketchup::Group).select { |g| g.valid? && g.get_attribute(Schema::DICTIONARY, 'kind') == kind }
      end

      def self.find(model, kind, level_id)
        groups(model, kind).find { |g| g.get_attribute(Schema::DICTIONARY, 'level') == level_id }
      end

      def self.remove_orphans(model, kind, valid_ids)
        orphans = groups(model, kind).reject { |g| valid_ids.include?(g.get_attribute(Schema::DICTIONARY, 'level')) }
        locked, free = orphans.partition(&:locked?)
        free.each(&:erase!)
        {removed: free.size, locked: locked.size}
      end

      def self.draw_level(model, kind, plan, layer, definitions)
        spec = spec(kind)
        group = model.entities.add_group
        group.name = "#{spec[:name]} - #{plan[:level]['name']}"
        group.layer = layer
        group.set_attribute(Schema::DICTIONARY, 'kind', kind)
        group.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        group.set_attribute(Schema::DICTIONARY, 'plugin_version', VERSION)
        plan[:items].each do |item|
          relative = relative_polygon(item)
          definition = definition_for(model, spec, relative, item[:thickness], definitions)
          instance = group.entities.add_instance(definition, Geom::Transformation.new(Geom::Point3d.new(item[:min][0].mm, item[:min][1].mm, item[:z_bottom].mm)))
          instance.name = "#{spec[:name]} #{item[:ref]} (#{plan[:level]['name']})"
          instance.layer = layer
          tag_instance(instance, spec, plan, item)
        end
      end

      # Đa giác của tấm tính từ góc nhỏ của hình chữ nhật bao (sàn: hình chữ nhật cả ô; trần: có thể khoét góc).
      def self.relative_polygon(item)
        points = item[:polygon] || [[item[:min][0], item[:min][1]], [item[:max][0], item[:min][1]], [item[:max][0], item[:max][1]], [item[:min][0], item[:max][1]]]
        points.map { |x, y| [(x - item[:min][0]).round(2), (y - item[:min][1]).round(2)] }
      end

      # Dữ liệu trên tấm để VGD BIM đọc (SPEC mục 2).
      def self.tag_instance(instance, spec, plan, item)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin', Schema::PLUGIN_ID)
        instance.set_attribute('VGD_BIM_SOURCE', 'plugin_version', VERSION)
        instance.set_attribute('VGD_BIM_SOURCE', 'kind', spec[:kind])
        instance.set_attribute('VGD_BIM_SOURCE', 'ref', "#{plan[:level]['id']}:#{item[:ref]}")
        instance.set_attribute(Schema::DICTIONARY, 'level', plan[:level]['id'])
        instance.set_attribute(Schema::DICTIONARY, 'dims', JSON.generate('thickness' => item[:thickness], 'area' => item[:area], 'z_top' => item[:z_top]))
      end

      def self.definition_for(model, spec, relative, thickness, definitions)
        key = [relative, thickness]
        definitions[key] ||= begin
          name = "VGD #{spec[:definition]} #{relative.flatten.map { |v| fmt(v) }.join('_')}x#{fmt(thickness)}"
          existing = model.definitions[name]
          existing && existing.valid? ? existing : make_definition(model, spec, name, relative, thickness)
        end
      end

      def self.make_definition(model, spec, name, relative, thickness)
        definition = model.definitions.add(name)
        face = definition.entities.add_face(relative.map { |x, y| Geom::Point3d.new(x.mm, y.mm, 0) })
        face.reverse! if face.normal.z < 0
        face.pushpull(thickness.mm)
        definition.set_attribute(Schema::DICTIONARY, 'kind', "#{spec[:kind]}_definition")
        definition
      end

      def self.fmt(value)
        value == value.round ? value.round.to_s : value.to_s
      end
    end
  end
end
