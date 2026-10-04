# frozen_string_literal: true
module VGD
  module Scenes
    module SceneStore
      def self.owned?(page)
        page.get_attribute(DICT, 'owner') == 'VGD Scenes'
      end

      def self.metadata(page)
        JSON.parse(page.get_attribute(DICT, 'source', '{}'))
      end

      def self.find(model, id)
        page = model.pages.find { |p| p.persistent_id.to_s == id.to_s }
        raise ArgumentError, 'Scene không còn tồn tại. Làm mới danh sách.' unless page
        page
      end

      def self.list(model)
        ordered(model).map do |page|
          source = owned?(page) ? metadata(page) : {}
          { id: page.persistent_id.to_s, name: page.name, owned: owned?(page), imported: !page.get_attribute(DICT, 'transfer_origin').nil?,
            frame: SceneFrame.read(page, Scenes.settings(model)), group: group_name(model, page, source),
            kind: source['kind'], selected: page == model.pages.selected_page }
        end
      end

      def self.group_name(model, page, source)
        if source['paths'].is_a?(Array) && !source['paths'].empty?
          leaf = Geometry.resolve(model, source['paths'].first)[0].last
          name = leaf.name.to_s.strip
          name = leaf.definition.name.to_s.strip if name.empty?
          return name unless name.empty?
        end
        page.name.sub(/_(?:ISO|TOP|FRONT|RIGHT|BACK|LEFT|BOTTOM|SEC.*?)(?:_\d+)?\z/i, '')
      rescue ArgumentError
        page.name.sub(/_(?:ISO|TOP|FRONT|RIGHT|BACK|LEFT|BOTTOM|SEC.*?)(?:_\d+)?\z/i, '')
      end

      def self.ordered(model)
        pages = model.pages.to_a
        saved = JSON.parse(model.get_attribute(DICT, 'scene_order', '[]'))
        return pages unless saved.is_a?(Array) && saved.all? { |id| id.is_a?(String) } && saved.uniq.length == saved.length
        ranks = {}; saved.each_with_index { |id, i| ranks[id] = i }
        pages.each_with_index.sort_by { |page, i| [ranks.fetch(page.persistent_id.to_s, saved.length + i), i] }.map(&:first)
      rescue JSON::ParserError, TypeError
        pages
      end

      def self.reorder(model, id, before_id, expected_ids)
        raise 'Đóng edit Group/Component trước khi sắp xếp scene.' if model.active_path
        original = ordered(model)
        ids = original.map { |page| page.persistent_id.to_s }
        raise ArgumentError, 'Thứ tự scene đã đổi. Làm mới rồi kéo lại.' unless Array(expected_ids).map(&:to_s) == ids
        moving_ids = Array(id).map(&:to_s).uniq
        raise ArgumentError, 'Chọn scene cần di chuyển.' if moving_ids.empty?
        moving = moving_ids.map { |pid| find(model, pid) }
        raise ArgumentError, 'Vị trí thả scene không hợp lệ.' if before_id && !ids.include?(before_id.to_s)
        return { success: true, message: 'Thứ tự scene giữ nguyên.' } if moving_ids.include?(before_id.to_s)
        moving = original.select { |item| moving.include?(item) }
        target = original.reject { |item| moving.include?(item) }
        index = before_id.nil? ? target.length : target.index { |item| item.persistent_id.to_s == before_id.to_s }
        target.insert(index, *moving)
        return { success: true, message: 'Thứ tự scene giữ nguyên.' } if target == original
        previous = model.get_attribute(DICT, 'scene_order')
        Scenes.operation(model, 'Sắp xếp bảng scene VGD') do
          begin
            model.set_attribute(DICT, 'scene_order', target.map { |item| item.persistent_id.to_s }.to_json)
            raise 'Chưa lưu được thứ tự scene.' unless ordered(model) == target
          rescue StandardError => error
            previous.nil? ? model.delete_attribute(DICT, 'scene_order') : model.set_attribute(DICT, 'scene_order', previous)
            raise error
          end
        end
        { success: true, message: 'Đã sắp xếp bảng. Bấm Đồng bộ thứ tự SketchUp khi đã xếp xong.' }
      end

      def self.sync_order(model, expected_ids)
        raise 'Đóng edit Group/Component trước khi sắp xếp scene.' if model.active_path
        raise 'SU2022 chưa có API đổi thứ tự scene gốc. Dùng Move Left / Move Right trên thanh scene; đồng bộ tự động hỗ trợ SU2025 trở lên.' unless model.pages.respond_to?(:reorder)
        original = model.pages.to_a
        target = ordered(model)
        raise ArgumentError, 'Danh sách scene đã đổi. Làm mới rồi đồng bộ lại.' unless Array(expected_ids).map(&:to_s) == target.map { |p| p.persistent_id.to_s }
        live = Scenes.camera_copy(model.active_view.camera)
        current = model.pages.selected_page
        Scenes.operation(model, 'Đồng bộ thứ tự scene SketchUp') do
          begin
            target.each_with_index { |page, index| model.pages.reorder(page, index) unless model.pages.to_a[index] == page }
            raise 'SketchUp chưa nhận đủ thứ tự scene.' unless model.pages.to_a == target
          rescue StandardError
            original.each_with_index { |page, index| model.pages.reorder(page, index) unless model.pages.to_a[index] == page }
            raise
          ensure
            model.pages.selected_page = current if current && current.valid? && model.pages.selected_page != current
            model.active_view.camera = live
          end
        end
        { success: true, message: 'Đã đồng bộ thứ tự lên thanh scene SketchUp.' }
      end

      def self.rename_many(model, raw)
        ids = Array(raw['ids']).map(&:to_s).uniq
        pages = ordered(model).select { |page| ids.include?(page.persistent_id.to_s) }
        raise ArgumentError, 'Danh sách scene đã đổi. Chọn lại.' if pages.empty? || pages.length != ids.length
        parts = %w[prefix base suffix separator].map do |key|
          text = raw[key].to_s
          raise ArgumentError, 'Tên chứa ký tự không hợp lệ hoặc quá dài.' if text.length > 180 || text.match?(/[\x00-\x1f]/)
          text.strip
        end
        prefix, base, suffix, separator = parts
        mode = raw['sequence'].to_s
        raise ArgumentError, 'Kiểu đánh số không hợp lệ.' unless %w[none number letter].include?(mode)
        start = raw.fetch('start', 1)
        raise ArgumentError, 'Số bắt đầu cần là số nguyên từ 1 tới 999999.' unless start.is_a?(Integer) && start.between?(1, 999999)
        names = pages.each_with_index.map do |page, index|
          number = start + index
          token = if mode == 'number'
                    format('%02d', number)
                  elsif mode == 'letter'
                    text = +''; while number > 0; number -= 1; text.prepend((65 + number % 26).chr); number /= 26; end; text
                  end
          [prefix, base.empty? ? page.name : base, token, suffix].compact.reject(&:empty?).join(separator)
        end
        raise ArgumentError, 'Tên scene cần có 1–180 ký tự.' if names.any? { |name| name.empty? || name.length > 180 }
        foreign_names = (model.pages.to_a - pages).map(&:name)
        raise ArgumentError, 'Tên bị trùng. Thêm STT/chữ cái hoặc đổi tiền tố, hậu tố.' if names.uniq.length != names.length || (names & foreign_names).any?
        previous = pages.map(&:name)
        Scenes.operation(model, 'Đổi tên hàng loạt scene') do
          begin
            pages.each_with_index { |page, index| page.name = unique_name(model, "__VGD_RENAME_#{page.persistent_id}_#{index}__", page) }
            pages.zip(names).each { |page, name| page.name = name; raise 'SketchUp không nhận tên scene.' unless page.name == name }
          rescue StandardError
            pages.each { |page| page.name = unique_name(model, "__VGD_RESTORE_#{page.persistent_id}__", page) }
            pages.zip(previous).each { |page, name| page.name = name }
            raise
          end
        end
        { success: true, message: "Đã đổi tên #{pages.length} scene." }
      end

      def self.name(options, target, kind, index)
        values = { 'PROJECT' => options['project'], 'OBJECT' => target[:name], 'VIEW' => kind, 'INDEX' => format('%02d', index) }
        text = options['template'].gsub(/<([A-Z]+)>|\{([A-Z]+)\}/i) { |token| values[($1 || $2).upcase] || token }
        text = text.gsub(/[\x00-\x1f]/, ' ').strip[0, 180]
        raise ArgumentError, 'Tên scene rỗng sau khi áp dụng mẫu.' if text.empty?
        text
      end

      def self.unique_name(model, proposed, except = nil)
        text = proposed
        index = 2
        while model.pages.any? { |page| page != except && page.name == text }
          text = "#{proposed} (#{index})"; index += 1
        end
        text
      end

      def self.prepare_page(page)
        page.use_camera = true
        page.use_rendering_options = true
        page.use_style = false
        page.use_hidden_geometry = true
        page.use_hidden_objects = true
        page.use_hidden_layers = true
        page.use_section_planes = true
      end

      def self.flags
        PAGE_USE_CAMERA | PAGE_USE_RENDERING_OPTIONS | PAGE_USE_HIDDEN_GEOMETRY |
          PAGE_USE_HIDDEN_OBJECTS | PAGE_USE_LAYER_VISIBILITY | PAGE_USE_SECTION_PLANES
      end

      def self.isolate(page, model, target)
        keep = target[:resolved].flat_map { |path, _t, _entities| path }
        model.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Drawingelement)
          page.set_drawingelement_visibility(entity, keep.include?(entity))
        end
        # Nested instance siblings are page overrides only; definitions are never edited.
        target[:resolved].each do |path, _t, _entities|
          path.each_with_index do |parent, index|
            next if index == path.length - 1
            parent.definition.entities.each do |sibling|
              next unless Geometry.instance?(sibling) || sibling.is_a?(Sketchup::Image)
              page.set_drawingelement_visibility(sibling, keep.include?(sibling))
            end
          end
        end
        keep.each do |entity|
          page.set_drawingelement_visibility(entity, true)
          page.set_visibility(entity.layer, true)
          folder = entity.layer.respond_to?(:folder) ? entity.layer.folder : nil
          while folder
            page.set_visibility(folder, true)
            folder = folder.respond_to?(:folder) ? folder.folder : nil
          end
        end
      end

      def self.entity_contexts(model)
        contexts = []; pending = [model.entities]; seen = {}
        until pending.empty?
          entities = pending.pop
          next if seen[entities.object_id]
          seen[entities.object_id] = true
          contexts << entities
          entities.each { |e| pending << e.definition.entities if Geometry.instance?(e) }
        end
        contexts
      end

      def self.planes_for(model, page)
        entity_contexts(model).flat_map do |entities|
          entities.select { |e| e.is_a?(Sketchup::SectionPlane) && e.get_attribute(DICT, 'scene_pid').to_s == page.persistent_id.to_s && e.get_attribute(DICT, 'owner') == 'VGD Scenes' }
        end
      end

      def self.rename_from_target(model, page, target, kind, opts, index = nil)
        index ||= metadata(page)['name_index'] || model.pages.to_a.index(page) + 1
        label_kind = kind == 'SECTION' ? "SEC_#{opts['section_name']}" : kind
        page.name = unique_name(model, name(opts, target, label_kind, index), page)
        index
      end

      def self.write(model, page, target, kind, opts, index = nil)
        stored_frame = page.get_attribute(DICT, 'frame')
        opts = opts.merge(SceneFrame.read(page, opts)) if stored_frame
        normal = nil
        planes = []
        # Clear previous VGD cuts in all contexts before capturing this scene.
        # Root cuts from 1.0.0 are retained for old scenes, but not activated here.
        entity_contexts(model).each do |entities|
          active = entities.active_section_plane
          entities.active_section_plane = nil if entities == model.entities || (active && active.get_attribute(DICT, 'owner') == 'VGD Scenes')
        end
        if kind == 'SECTION'
          point, normal = Geometry.section(target, opts)
          target[:resolved].each do |_path, transform, entities|
            local = Geometry.local_plane(transform, point, normal)
            plane = entities.find { |e| e.is_a?(Sketchup::SectionPlane) && e.get_attribute(DICT, 'owner') == 'VGD Scenes' && e.get_attribute(DICT, 'scene_pid').to_s == page.persistent_id.to_s }
            if plane
              plane.set_plane(local)
            else
              plane = entities.add_section_plane(local)
              raise 'SketchUp không tạo được mặt cắt.' unless plane
              plane.layer = model.layers[0]
              plane.set_attribute(DICT, 'owner', 'VGD Scenes')
              plane.set_attribute(DICT, 'scene_pid', page.persistent_id.to_s)
            end
            plane.name = "VGD · #{opts['section_name']}"
            plane.hidden = true
            entities.active_section_plane = plane
            planes << plane
          end
        end
        # The cut is selected BEFORE the page is captured.
        model.rendering_options['DisplaySectionCuts'] = !planes.empty?
        model.rendering_options['DisplaySectionPlanes'] = false
        Geometry.fit(model, target, kind, opts, normal)
        prepare_page(page)
        raise 'SketchUp không lưu được trạng thái scene.' unless page.update(flags)
        isolate(page, model, target) if opts['isolate']
        page.set_attribute(DICT, 'owner', 'VGD Scenes')
        index = rename_from_target(model, page, target, kind, opts, index)
        page.set_attribute(DICT, 'source', { 'paths' => target[:paths], 'kind' => kind, 'options' => opts, 'name_index' => index }.to_json)
        SceneFrame.store(page, opts)
        page
      end

      def self.generate(model, raw, section_only = false)
        opts = Scenes.options(raw)
        kinds = section_only ? ['SECTION'] : opts['views']
        raise ArgumentError, 'Chọn ít nhất một góc nhìn.' if kinds.empty?
        paths = Geometry.selection_paths(model)
        sets = opts['grouping'] == 'individual' ? paths.map { |path| [path] } : [paths]
        raise ArgumentError, 'Tối đa 100 scene mỗi lượt. Giảm đối tượng hoặc góc nhìn.' if sets.length * kinds.length > 100
        targets = sets.map { |set| Geometry.target(model, set, opts['axis_mode']) }
        targets.each { |target| Geometry.section(target, opts) } if section_only
        targets.each { |target| Geometry.validate_section_target(target) } if section_only
        snapshot = ViewState.new(model)
        generated = []
        Scenes.operation(model, section_only ? 'Tạo mặt cắt' : 'Tạo góc nhìn') do
          begin
            targets.each do |target|
              target = Geometry.unique_section_target(model, target, opts, snapshot) if section_only
              kinds.each do |kind|
                existing = model.pages.find do |page|
                  next false unless owned?(page)
                  source = metadata(page)
                  source['paths'] == target[:paths] && source['kind'] == kind &&
                    (kind != 'SECTION' || source.dig('options', 'section_name') == opts['section_name'])
                end
                label_kind = kind == 'SECTION' ? "SEC_#{opts['section_name']}" : kind
                page = existing || model.pages.add(unique_name(model, name(opts, target, label_kind, generated.length + 1)))
                write(model, page, target, kind, opts, existing ? nil : generated.length + 1)
                generated << page
              end
              # A view refresh also renames unrequested views and section scenes
              # belonging to this exact source set, using their stored template.
              model.pages.each do |page|
                next unless owned?(page) && !generated.include?(page)
                source = metadata(page)
                next unless source['paths'] == target[:paths]
                rename_from_target(model, page, target, source['kind'], Scenes.options(source['options']))
              end
            end
            model.set_attribute(DICT, 'settings', opts.to_json)
          ensure
            snapshot.restore
          end
        end
        model.pages.selected_page = generated.first unless model.active_path
        { success: true, message: "Đã tạo/cập nhật #{generated.length} scene.", ids: generated.map { |p| p.persistent_id.to_s } }
      end

      def self.update_sources(model, ids)
        pages = Array(ids).map { |id| find(model, id) }
        raise ArgumentError, 'Chọn scene VGD cần cập nhật.' if pages.empty?
        raise ArgumentError, 'Cập nhật từ nguồn chỉ áp dụng scene VGD. Scene khác dùng nút lưu góc nhìn.' unless pages.all? { |p| owned?(p) }
        plans = pages.map do |page|
          data = metadata(page); opts = Scenes.options(data.fetch('options'))
          target = Geometry.target(model, data.fetch('paths'), opts['axis_mode'])
          Geometry.validate_section_target(target) if data['kind'] == 'SECTION'
          [page, target, data.fetch('kind'), opts]
        end
        snapshot = ViewState.new(model)
        Scenes.operation(model, 'Cập nhật từ đối tượng') do
          begin
            plans.each do |page, target, kind, opts|
              target = Geometry.unique_section_target(model, target, opts, snapshot) if kind == 'SECTION'
              write(model, page, target, kind, opts)
            end
          ensure
            snapshot.restore
          end
        end
        { success: true, message: "Đã cập nhật #{pages.length} scene theo đối tượng nguồn." }
      end

      def self.rename(model, id, raw_name)
        page = find(model, id)
        label = raw_name.to_s.gsub(/[\x00-\x1f]/, ' ').strip[0, 180]
        raise ArgumentError, 'Tên scene không được trống.' if label.empty?
        raise ArgumentError, 'Tên scene đã tồn tại.' if model.pages.any? { |p| p != page && p.name == label }
        Scenes.operation(model, 'Đổi tên scene') { page.name = label }
        { success: true, message: "Đã đổi tên: #{label}" }
      end

      def self.capture(model, id)
        page = find(model, id)
        Scenes.operation(model, 'Lưu góc nhìn vào scene') do
          page.use_camera = true
          page.use_rendering_options = true
          page.use_hidden_geometry = true
          page.use_hidden_objects = true
          page.use_hidden_layers = true
          page.use_section_planes = true
          raise 'Không lưu được scene.' unless page.update(flags)
          base = Scenes.settings(model)
          working = if model.pages.selected_page == page && Scenes.live_frame(model)
                      Scenes.live_frame(model)
                    elsif model.pages.selected_page == page && page.get_attribute(DICT, 'frame')
                      SceneFrame.read(page, base)
                    else
                      JSON.parse(model.get_attribute(DICT, 'working_frame', '{}'))
                    end
          SceneFrame.store(page, SceneFrame.from_camera(model.active_view.camera, base.merge(working)))
          # Refit-from-source would overwrite a manually composed camera.
          page.set_attribute(DICT, 'camera_custom', true) if owned?(page)
        end
        { success: true, message: "Đã lưu góc nhìn hiện tại vào #{page.name}." }
      end

      def self.delete(model, ids)
        pages = Array(ids).uniq.map { |id| find(model, id) }
        raise ArgumentError, 'Chọn scene cần xóa.' if pages.empty?
        Scenes.operation(model, 'Xóa scene đã chọn') do
          pages.each do |page|
            # Keep a plane if another scene refers to it; never erase foreign planes.
            planes = owned?(page) ? planes_for(model, page) : []
            model.pages.erase(page)
            planes.each do |plane|
              next unless plane.valid?
              # Other pages can capture the same native section: retain geometry conservatively.
              plane.set_attribute(DICT, 'orphan', true)
            end
          end
        end
        { success: true, message: "Đã xóa #{pages.length} scene." }
      end
    end

    module SectionPreview
      def self.clear_if_stale(model)
        clear if @session && (!@session[:model].equal?(model) || @session[:page] != model.pages.selected_page)
      end

      def self.clear
        session = @session
        @session = nil
        return unless session && session[:model].valid?
        model = session[:model]
        current_page = model.pages.selected_page
        selection = model.selection.to_a
        current_camera = Scenes.camera_copy(model.active_view.camera) if current_page != session[:page]
        model.start_operation('Kết thúc xem trước mặt cắt', true, false, true)
        begin
          session[:planes].each { |plane| plane.erase! if plane.valid? }
          session[:snapshot].restore
          if current_page != session[:page]
            model.pages.selected_page = current_page if current_page && current_page.valid?
            model.active_view.camera = current_camera
          end
          model.selection.clear
          model.selection.add(selection.select(&:valid?))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
      end

      def self.update(model, raw)
        raise 'Đóng edit Group/Component trước khi xem mặt cắt.' if model.active_path
        opts = Scenes.options(raw.merge('section_offset' => 0))
        raise ArgumentError, 'Chọn trục X, Y hoặc Z.' unless %w[X Y Z].include?(opts['section_axis'])
        paths = Geometry.selection_paths(model)
        key = [model.object_id, paths, opts['axis_mode']]
        clear if @session && @session[:key] != key
        unless @session
          target = Geometry.target(model, paths, opts['axis_mode'])
          Geometry.validate_section_target(target)
          snapshot = ViewState.new(model)
          planes = []
          Scenes.operation(model, 'Xem trước mặt cắt') do
            begin
              target = Geometry.unique_section_target(model, target, opts, snapshot)
              point, normal = Geometry.section(target, opts)
              target[:resolved].each do |_path, transform, entities|
                plane = entities.add_section_plane(Geometry.local_plane(transform, point, normal))
                raise 'Không tạo được mặt cắt xem trước.' unless plane
                planes << plane
                plane.set_attribute(DICT, 'preview', true)
                plane.name = 'VGD · Xem trước'
                plane.layer = model.layers[0]
              end
              @session = { key: key, model: model, page: model.pages.selected_page, snapshot: snapshot, target: target, planes: planes, axis: nil }
            rescue StandardError
              planes.each { |plane| plane.erase! if plane.valid? }
              snapshot.restore
              raise
            end
          end
        end
        session = @session
        point, normal = Geometry.section(session[:target], opts)
        model.start_operation('Di chuyển mặt cắt xem trước', true, false, true)
        begin
          session[:target][:resolved].zip(session[:planes]).each do |(_path, transform, entities), plane|
            raise 'Mặt cắt xem trước đã bị xóa. Chọn lại đối tượng.' unless plane.valid?
            plane.set_plane(Geometry.local_plane(transform, point, normal))
            entities.active_section_plane = plane
          end
          model.rendering_options['DisplaySectionCuts'] = true
          model.rendering_options['DisplaySectionPlanes'] = true
          axis = [opts['section_axis'], opts['section_flip']]
          Geometry.fit(model, session[:target], 'SECTION', opts, normal) if session[:axis] != axis
          session[:axis] = axis
          model.active_view.invalidate
          model.commit_operation
        rescue StandardError
          model.abort_operation
          clear
          raise
        end
        { success: true, message: "Mặt cắt: #{opts['section_percent']}% · xem trước, chưa tạo scene." }
      end
    end
  end
end
