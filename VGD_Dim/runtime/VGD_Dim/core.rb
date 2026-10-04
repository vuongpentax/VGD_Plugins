# encoding: UTF-8
module VGD
  module Dim
    module Core
      extend self
      STYLE = {
        'dim'=>{'setcolor'=>false,'color'=>'#000000','arrow'=>'keep','textorient'=>'keep','align'=>'keep'},
        'text'=>{'setcolor'=>false,'color'=>'#000000'},
        'label'=>{'setcolor'=>false,'color'=>'#000000','arrow'=>'keep','leader'=>'keep'},
        'units'=>{'enabled'=>false,'unit'=>'2','precision'=>'0','show_unit'=>false}
      }.freeze unless const_defined?(:STYLE, false)
      SCAN = {'scope'=>'selected','nested'=>true,'components'=>true,'hidden'=>false,'locked'=>false}.freeze unless const_defined?(:SCAN, false)

      def validate_settings(settings)
        raise ArgumentError, 'Style không hợp lệ.' unless settings.is_a?(Hash)
        config = {}
        STYLE.each do |kind, defaults|
          values = settings.fetch(kind, {})
          raise ArgumentError, "#{kind}: dữ liệu không hợp lệ." unless values.is_a?(Hash)
          config[kind] = defaults.merge(values.select { |key, _| defaults.key?(key) })
        end
        %w[dim text label].each do |kind|
          row = config[kind]
          raise ArgumentError, 'Đổi màu phải là bật/tắt.' unless [true,false].include?(row['setcolor'])
          raise ArgumentError, 'Màu không hợp lệ.' unless /\A#[0-9a-fA-F]{6}\z/.match?(row['color'].to_s)
        end
        %w[dim label].each { |kind| raise ArgumentError, 'Endpoint không hợp lệ.' unless Engine::ENDPOINTS.include?(config[kind]['arrow']) }
        raise ArgumentError, 'Hướng chữ không hợp lệ.' unless %w[keep aligned screen].include?(config['dim']['textorient'])
        raise ArgumentError, 'Vị trí chữ không hợp lệ.' unless %w[keep above center outside].include?(config['dim']['align'])
        raise ArgumentError, 'Kiểu leader không hợp lệ.' unless %w[keep view pushpin].include?(config['label']['leader'])
        if config['dim']['textorient']=='screen' && config['dim']['align']!='keep'
          raise ArgumentError, 'Above/Center/Outside cần chọn hướng chữ song song đường Dim.'
        end
        units = config['units']
        %w[enabled show_unit].each { |key| raise ArgumentError, 'Thông số đơn vị phải là bật/tắt.' unless [true,false].include?(units[key]) }
        if units['enabled']
          raise ArgumentError, 'Đơn vị không hợp lệ.' unless %w[0 1 2 3 4].include?(units['unit'].to_s)
          raise ArgumentError, 'Số lẻ phải từ 0 đến 8.' unless /\A[0-8]\z/.match?(units['precision'].to_s)
        end
        config
      end
      def validate_opts(opts)
        raise ArgumentError, 'Phạm vi không hợp lệ.' unless opts.is_a?(Hash)
        o = SCAN.merge(opts.select { |key, _| SCAN.key?(key) })
        raise ArgumentError, 'Phạm vi không hợp lệ.' unless %w[selected context model].include?(o['scope'])
        %w[nested components hidden locked].each { |key| raise ArgumentError, 'Bộ lọc không hợp lệ.' unless [true,false].include?(o[key]) }
        o
      end
      def skip_hidden?(entity, opts)
        !opts['hidden'] && (entity.hidden? || (entity.layer && entity.layer.respond_to?(:visible?) && !entity.layer.visible?))
      end
      def kind(entity)
        return 'dim' if entity.is_a?(Sketchup::Dimension)
        return entity.has_leader? ? 'label' : 'text' if entity.is_a?(Sketchup::Text)
        nil
      end
      def scan(model, opts)
        o = validate_opts(opts || {})
        out = {'dim'=>[], 'text'=>[], 'label'=>[]}
        roots = case o['scope']
                when 'model' then model.entities.to_a
                when 'context' then model.active_entities.to_a
                else model.selection.to_a
                end
        if o['scope']!='model' && Array(model.active_path).any? { |e| skip_hidden?(e,o) || (!o['locked'] && e.locked?) }
          return out
        end
        container = o['scope']=='model' ? model.entities : model.active_entities
        walk(roots, o, out, {}, {}, 0, container)
        out
      end
      def walk(list, opts, out, seen_defs, seen_entities, depth, container)
        raise 'Nhóm lồng quá sâu (>64).' if depth>64
        list.each do |entity|
          next unless entity.valid?
          next if skip_hidden?(entity,opts)
          next if !opts['locked'] && entity.respond_to?(:locked?) && entity.locked?
          type = kind(entity)
          if type
            next if seen_entities[entity.object_id]
            seen_entities[entity.object_id] = true
            out[type] << {entity:entity, entities:container, nested:depth>0}
          elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
            next if depth>0 && !opts['nested']
            next if !entity.is_a?(Sketchup::Group) && !opts['components']
            definition = entity.definition
            next if seen_defs[definition.object_id]
            seen_defs[definition.object_id] = true
            walk(definition.entities.to_a, opts, out, seen_defs, seen_entities, depth+1, definition.entities)
          end
        end
      end
      def summary(acc)
        {'dim'=>acc['dim'].size, 'text'=>acc['text'].size, 'label'=>acc['label'].size,
         'nested'=>acc.values.flatten.count { |entry| entry[:nested] }}
      end
      def color(entity, settings, prefix)
        entity.material = Engine.get_material(entity.model, prefix, settings['color']) if settings['setcolor']
      end
      def style_dim(entity, settings, report={})
        color(entity,settings,'VGD_DIM_COLOR')
        Engine.set_endpoint(entity,settings['arrow'])
        entity.has_aligned_text = (settings['textorient']=='aligned') unless settings['textorient']=='keep'
        if entity.is_a?(Sketchup::DimensionLinear) && settings['align']!='keep'
          entity.has_aligned_text = true
          entity.aligned_text_position = {'above'=>Sketchup::DimensionLinear::ALIGNED_TEXT_ABOVE,
            'center'=>Sketchup::DimensionLinear::ALIGNED_TEXT_CENTER, 'outside'=>Sketchup::DimensionLinear::ALIGNED_TEXT_OUTSIDE}.fetch(settings['align'])
        elsif settings['align']!='keep'
          (report['dim.align'] ||= {'unsupported'=>0})['unsupported'] += 1
        end
        entity.layer = entity.model.layers['000 DIM'] || entity.model.layers.add('000 DIM')
      end
      def style_text(entity, settings, type)
        color(entity,settings,'VGD_TEXT_COLOR')
        if type=='label'
          Engine.set_endpoint(entity,settings['arrow'])
          entity.leader_type = (settings['leader']=='view' ? ALeaderView : ALeaderModel) unless settings['leader']=='keep'
        end
        entity.layer = entity.model.layers['000 TEXT'] || entity.model.layers.add('000 TEXT')
      end
      def apply_units(model, settings)
        return unless settings['enabled']
        provider = model.options['UnitsOptions']
        provider['LengthFormat'] = 0
        provider['LengthUnit'] = settings['unit'].to_i
        provider['LengthPrecision'] = settings['precision'].to_i
        provider['SuppressUnitsDisplay'] = !settings['show_unit']
      end
      def tag_selected(model)
        model.start_operation('VGD Dim — Gán tag vùng chọn',true)
        begin
          Engine.selected(model).each do |entity|
            name=entity.is_a?(Sketchup::Dimension) ? '000 DIM' : '000 TEXT'
            entity.layer=model.layers[name] || model.layers.add(name)
          end
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
      end
      def run(kinds, settings, opts)
        raise 'APPLY đang chạy.' if NativeStyle.running?
        raise ArgumentError, 'Loại đối tượng không hợp lệ.' unless kinds.is_a?(Array) && !kinds.empty? && kinds.all? { |k| %w[dim text label].include?(k.to_s) }
        config = validate_settings(settings)
        model = Sketchup.active_model
        acc = scan(model,opts)
        chosen = kinds.map(&:to_s).uniq
        raise 'Không tìm thấy đối tượng trong phạm vi/bộ lọc đã chọn.' if chosen.all? { |k| acc[k].empty? } && !config['units']['enabled']
        report = {}; counts = {'dim'=>0,'text'=>0,'label'=>0}
        AutoStyle.suspend do
          model.start_operation('VGD Dim — Áp style',true)
          begin
            chosen.each do |type|
              acc[type].each do |entry|
                type=='dim' ? style_dim(entry[:entity],config[type],report) : style_text(entry[:entity],config[type],type)
                counts[type]+=1
              end
            end
            apply_units(model,config['units'])
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
        end
        model.active_view.invalidate
        {'count'=>counts,'report'=>report}
      end

      def endpoint(dim, side)
        entity, point = dim.public_send(side)
        getter="#{side}_attached_to"
        attached=dim.public_send(getter) if dim.respond_to?(getter)
        # Restore complete instance paths after creation; their point coordinate
        # convention differs from add_dimension_linear's reference arguments.
        return point if attached && attached[0]
        return entity if entity && entity.respond_to?(:position) # Vertex / ConstructionPoint
        entity ? [entity,point] : point
      end
      def rebuild_dims(opts)
        raise 'APPLY đang chạy.' if NativeStyle.running?
        model=Sketchup.active_model
        entries=scan(model,opts)['dim']
        raise 'Không tìm thấy Dimension trong phạm vi đã chọn.' if entries.empty?
        selected=model.selection.to_a; replacements={}
        result={'rebuilt'=>0,'custom'=>0,'skipped'=>0,'failed'=>0}
        AutoStyle.suspend do
          model.start_operation('VGD Dim — Làm mới font/size',true)
          begin
            entries.each do |entry|
              old=entry[:entity]
              unless old.is_a?(Sketchup::DimensionLinear)
                result['skipped']+=1; next
              end
              new_dim=nil
              begin
                # Create with current Model Info font defaults; preserve native links.
                new_dim=entry[:entities].add_dimension_linear(endpoint(old,:start), endpoint(old,:end), old.offset_vector)
                %i[start end].each do |side|
                  getter="#{side}_attached_to"
                  attached=old.public_send(getter) if old.respond_to?(getter)
                  new_dim.public_send("#{getter}=",attached) if attached && attached[0]
                end
                custom_text=old.text
                new_dim.text=custom_text
                new_dim.material=old.material; new_dim.layer=old.layer; new_dim.hidden=old.hidden?
                new_dim.arrow_type=old.arrow_type; new_dim.has_aligned_text=old.has_aligned_text?
                position=old.aligned_text_position
                new_dim.aligned_text_position=position unless position.nil?
                new_dim.text_position=old.text_position if old.respond_to?(:text_position)
                %i[casts_shadows? receives_shadows?].each do |method|
                  setter=method.to_s.sub('?','=')
                  new_dim.public_send(setter,old.public_send(method)) if old.respond_to?(method) && new_dim.respond_to?(setter)
                end
                if old.respond_to?(:attribute_dictionaries) && old.attribute_dictionaries
                  old.attribute_dictionaries.each { |dict| dict.each_pair { |key,value| new_dim.set_attribute(dict.name,key,value) } }
                end
                old.erase! # Remove only after every preservation step succeeds.
                replacements[old]=new_dim
                result['rebuilt']+=1
                result['custom']+=1 unless custom_text.to_s.empty?
              rescue StandardError
                new_dim.erase! if new_dim && new_dim.valid?
                result['failed']+=1
              end
            end
            model.selection.clear
            model.selection.add(selected.map { |e| replacements.fetch(e,e) }.select(&:valid?))
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
        end
        model.active_view.invalidate
        result
      end
    end
  end
end
