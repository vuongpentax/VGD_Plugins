require 'json'

module VGD
  module BIM
    module UI
      # Phần của cửa sổ BIM lo cho "Gắn tag tự động theo từ khóa tên" (xem TagRules): thu thập group / component (đang chọn hoặc cả model,
      # tùy chọn đi vào bên trong), xem trước kế hoạch, áp dụng trong MỘT bước hoàn tác; lưu / đặt lại / nhập / xuất bộ luật.
      # Chỉ đổi tag (entity.layer) của group / component, không đổi hình học. Trộn vào UI::Dialog (dùng @model, emit, tag_state...).
      module TagAuto
        MAX_ITEMS = 20_000 # số group / component tối đa cho một lần gắn
        UNTAGGED = %w[Untagged Layer0].freeze

        def register_tag_auto_callbacks
          @dialog.add_action_callback('tag_rules_save') { |_ctx, payload| safely { tag_rules_save(JSON.parse(payload)) } }
          @dialog.add_action_callback('tag_rules_reset') { |_ctx, _payload| safely { tag_rules_reset } }
          @dialog.add_action_callback('tag_rules_export') { |_ctx, payload| safely { tag_rules_export(JSON.parse(payload)) } }
          @dialog.add_action_callback('tag_rules_import') { |_ctx, _payload| safely { tag_rules_import } }
          @dialog.add_action_callback('tag_auto_preview') { |_ctx, payload| safely { tag_auto_preview(JSON.parse(payload)) } }
          @dialog.add_action_callback('tag_auto_apply') { |_ctx, payload| safely { tag_auto_apply(JSON.parse(payload)) } }
          @dialog.add_action_callback('tag_catalog_import') { |_ctx, payload| safely { tag_catalog_import(JSON.parse(payload)) } }
        end

        # ---- Bộ luật: lưu làm mặc định, đặt lại, nhập xuất (bộ luật đang sửa nằm ở giao diện, gửi kèm mỗi lệnh) ----
        def tag_rules_save(payload)
          clean = TagRules.save(payload['rules'])
          emit('tag_rules', {rules: clean})
          emit('message', {text: 'Đã lưu bộ luật gắn tag tự động làm mặc định.'})
        end

        def tag_rules_reset
          return unless ::UI.messagebox('Đặt lại bộ luật về mặc định? Bộ luật đã lưu trên máy này sẽ bị xóa.', MB_YESNO) == IDYES
          emit('tag_rules', {rules: TagRules.reset})
          emit('message', {text: 'Đã đặt lại bộ luật về mặc định.'})
        end

        def tag_rules_export(payload)
          clean = TagRules.sanitize(payload['rules'])
          path = ::UI.savepanel('Xuất bộ luật gắn tag tự động (JSON)', '', 'VGD_luat_gan_tag.json')
          return unless path
          path += '.json' unless File.extname(path).downcase == '.json'
          File.open(path, 'wb') { |file| file.write(TagRules.to_json(clean)) }
          emit('message', {text: "Đã xuất #{clean.size} luật: #{path}"})
        end

        def tag_rules_import
          path = ::UI.openpanel('Nhập bộ luật gắn tag tự động (JSON, kể cả file của 5D Auto Tag)', '', 'JSON|*.json||')
          return unless path
          rules = TagRules.from_json(File.read(path, encoding: 'bom|utf-8'))
          emit('tag_rules', {rules: rules, imported: true})
          emit('message', {text: "Đã nhập #{rules.size} luật từ file. Bộ luật chưa lưu làm mặc định."})
        end

        # ---- Thư viện tag mẫu (xem TagCatalog): payload {'groups' => [tên cụm đã tick]} ----
        # Thêm tag của các cụm vào bộ tag của BIM (tag trùng tên lấy từ thư viện) và tạo sẵn trong model đang mở trong MỘT bước hoàn tác.
        # Chỉ tạo tên tag (chưa có màu, nét đứt, thư mục tag), không đổi đối tượng nào.
        def tag_catalog_import(payload)
          check_model!
          groups = payload['groups']
          incoming = TagCatalog.tags_for(groups)
          Tags.save(Tags.merge(Tags.load, incoming))
          created = 0
          Data.transaction(@model, 'VGD BIM · Nhập tag mẫu') do
            incoming.each do |tag|
              next if Tags.find_layer(@model, tag['name'])
              Tags.layer_for(@model, tag['name'])
              created += 1
            end
          end
          emit('tags', tag_state)
          emit('message', {text: "Đã nhập #{incoming.size} tag từ #{groups.uniq.size} cụm vào bộ tag (#{created} tag mới tạo trong model)."})
        end

        # ---- Xem trước và áp dụng ----
        # payload: {'rules' => [...], 'based_on' => 'both' | 'instance' | 'definition', 'scope' => 'selection' | 'model',
        #           'nested' => true / false, 'overwrite' => true / false}
        def tag_auto_preview(payload)
          check_model!
          plan, = tag_auto_plan(payload)
          emit('tag_auto_plan', tag_auto_summary(plan))
        end

        # Tính lại kế hoạch ngay lúc áp dụng (không tin bản xem trước cũ); một thao tác duy nhất nên Ctrl+Z hoàn tác cả đợt.
        def tag_auto_apply(payload)
          check_model!
          plan, compiled = tag_auto_plan(payload)
          raise 'Không có đối tượng nào cần gắn tag. Bấm Xem trước để biết lý do.' if plan[:assign].empty?
          hidden = []
          Data.transaction(@model, 'VGD BIM · Gắn tag tự động') do
            layers = {}
            plan[:assign].each do |item, index|
              name = compiled[index][:tag]
              layer = (layers[name] ||= Tags.layer_for(@model, name))
              hidden << layer.name if !layer.visible? && !hidden.include?(layer.name)
              item[:entity].layer = layer
            end
          end
          emit('tag_auto_plan', {cleared: true}) # xóa bản xem trước cũ ở giao diện
          emit('tags', tag_state)
          emit('message', {text: tag_auto_text(plan, hidden)})
        end

        def tag_auto_text(plan, hidden)
          text = "Đã gắn tag tự động cho #{plan[:assign].size} đối tượng (#{plan[:rules].size} tag)."
          text += " Đã đúng tag sẵn: #{plan[:same]}." if plan[:same].positive?
          text += " Giữ nguyên #{plan[:kept]} đối tượng đã có tag khác." if plan[:kept].positive?
          text += " Bỏ qua #{plan[:locked]} đối tượng bị khóa." if plan[:locked].positive?
          text += " Tag đang tắt hiển thị nên đối tượng gắn vào sẽ bị ẩn: #{hidden.first(3).join(', ')}." if hidden.any?
          text
        end

        def tag_auto_summary(plan)
          {total: plan[:total], assign: plan[:assign].size, same: plan[:same], kept: plan[:kept], unmatched: plan[:unmatched], locked: plan[:locked],
           rules: plan[:rules].map { |rule| rule.slice(:tag, :count, :samples) }}
        end

        private

        # [kế hoạch, luật đã biên dịch]: kiểm tra mọi dữ liệu giao diện gửi lên trước khi đụng vào model.
        def tag_auto_plan(payload)
          options = tag_auto_options(payload)
          rules = TagRules.sanitize(payload['rules'])
          raise 'Chưa có luật nào. Hãy thêm ít nhất một luật.' if rules.empty?
          compiled = TagRules.compile(rules)
          [TagRules.plan(tag_auto_items(options), compiled, overwrite: options[:overwrite]), compiled]
        end

        def tag_auto_options(payload)
          based_on = payload['based_on'].to_s
          raise 'Tùy chọn "Dựa theo" không hợp lệ.' unless TagRules::BASED_ON.include?(based_on)
          scope = payload['scope'].to_s
          raise 'Tùy chọn "Phạm vi" không hợp lệ.' unless %w[selection model].include?(scope)
          {based_on: based_on, scope: scope, nested: payload['nested'] == true, overwrite: payload['overwrite'] == true}
        end

        # Các group / component cần xét. Định nghĩa dùng chung chỉ duyệt một lần (đổi tag bên trong là đổi cho mọi bản sao).
        def tag_auto_items(options)
          roots = (options[:scope] == 'model' ? @model.entities.to_a : @model.selection.to_a).select { |entity| Data.supported?(entity) && entity.valid? }
          raise 'Hãy chọn group hoặc component trong SketchUp trước, hoặc bật "Cả model".' if roots.empty?
          context_locked = (@model.active_path || []).any? { |entity| entity.respond_to?(:locked?) && entity.locked? }
          items = []
          seen = {}
          visit = lambda do |entities, locked|
            entities.each do |entity|
              next unless Data.supported?(entity) && entity.valid?
              raise "Quá nhiều đối tượng (tối đa #{MAX_ITEMS}). Hãy chọn ít hơn." if items.size >= MAX_ITEMS
              items << tag_auto_item(entity, options[:based_on], locked)
              next unless options[:nested]
              definition = Geometry.definition(entity)
              next if seen[definition]
              seen[definition] = true
              visit.call(definition.entities, locked || entity.locked?)
            end
          end
          visit.call(roots, context_locked)
          items
        end

        def tag_auto_item(entity, based_on, locked)
          instance = entity.name.to_s
          definition = entity.is_a?(Sketchup::Group) ? '' : Geometry.definition(entity).name.to_s # group không có tên component riêng
          names = case based_on
                  when 'instance' then [instance]
                  when 'definition' then [definition.empty? ? instance : definition]
                  else [instance, definition]
                  end
          label = [instance, definition].find { |name| !name.strip.empty? } || '(chưa đặt tên)'
          layer = entity.layer
          tag = layer && !UNTAGGED.include?(layer.name.to_s) ? layer.name.to_s : ''
          {entity: entity, label: label, names: names, tag: tag, locked: locked || entity.locked?}
        end
      end
    end
  end
end
