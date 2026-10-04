# encoding: UTF-8
require 'sketchup.rb'
require_relative 'catalog'
require_relative 'materials'
require_relative 'geometry'
require_relative 'storage'
require_relative 'models'
require_relative 'pixels'
require_relative 'advanced'
require_relative 'tools'
require_relative 'seamless'
require_relative 'online'
require_relative 'drive'
require_relative 'shell_sync'

module VGD
  module Library
    ROOT = File.dirname(__FILE__).freeze
    ACTIONS = %w[rotate random_rotate shuffle fit auto_scale restore reset_uv clear reapply resize swap flow fix_nesting trace].freeze
    TOOL_ACTIONS = %w[rotate_face paint swap_pick replace_pick seamless audit aux save_model].freeze
    COMMANDS = [
      ['Thư viện vật liệu', 'library', 'Mở thư viện vật liệu VGD'],
      ['Thư viện model', 'models', 'Mở thư viện SKP trên máy và nguồn online'],
      ['Tô lại vật liệu', 'reapply', 'Tô vật liệu vừa dùng lên vùng chọn'],
      ['Xoay map 90°', 'rotate', 'Xoay vân trên các mặt được chọn'],
      ['Xoay map từng mặt', 'rotate_face', 'Bấm mặt trong group để xoay; Ctrl+bấm nhập góc'],
      ['Xoay ngẫu nhiên', 'random_rotate', 'Xoay vân theo góc 0/90/180/270°'],
      ['Dịch vân ngẫu nhiên', 'shuffle', 'Đổi đoạn vân, giữ hướng vân'],
      ['Thay nhanh vật liệu', 'swap_pick', 'Bấm vật liệu A muốn giữ rồi bấm B cần thay'],
      ['Thay nhanh đối tượng', 'replace_pick', 'Bấm A muốn giữ rồi B cần thay; giữ vị trí/kích thước/DC'],
      ['Xóa vật liệu', 'clear', 'Xóa vật liệu mặt trước và vỏ trong vùng chọn'],
      ['AUTO SCALE', 'auto_scale', 'Fit một ô ảnh theo khung mặt, dọc cạnh dài nhất'],
      ['Phục hồi map', 'restore', 'Trả map về cỡ thật, hướng vân dọc cạnh dài nhất'],
      ['Fix lồng map', 'audit', 'Kiểm tra vật liệu vỏ khác vật liệu mặt bên trong'],
      ['Flowmap', 'flow', 'Trải vân liên tục qua các mặt kề nhau của ống/phào'],
      ['Convert line', 'trace', 'Tách đường viền và mặt màu từ ảnh đã import'],
      ['Map seamless', 'seamless', 'Xem trước và xử lý map liền mạch'],
      ['Xuất ảnh phụ', 'aux', 'Tạo Displacement/Specular/Normal OpenGL/DirectX/AO'],
      ['Cập nhật danh mục', 'refresh', 'Quét lại nguồn local và nguồn online đã cấu hình']
    ].freeze

    def self.transaction(title)
      model = Sketchup.active_model
      raise 'Không có model đang mở.' unless model
      path = model.active_path || []
      if path.any? { |instance| instance.definition.instances.size > 1 }
        raise 'Đang sửa bên trong group/component dùng chung. Đóng chế độ sửa rồi chọn vỏ đối tượng để VGD tự tạo bản riêng.'
      end
      started = model.start_operation("VGD Library — #{title}", true)
      result = ShellSync.paused(model) do
        value = yield(model)
        model.commit_operation
        value
      end
      result
    rescue StandardError
      model.abort_operation if model && started
      ShellSync.reset(model) if model
      raise
    end

    def self.message(text, error = false)
      Sketchup.status_text = "VGD Library: #{text}"
      if @dialog
        @dialog.execute_script("window.VGD.feedback(#{JSON.generate(text)}, #{error});")
      elsif error
        UI.messagebox("VGD_Library\n\n#{text}")
      end
    end

    def self.safely
      yield
    rescue StandardError, SyntaxError => e
      puts "[VGD_Library] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      message(e.message, true)
    end

    # Native SU timers can fire again while a modal picker is open even with
    # repeat=false. Mark fired BEFORE running the callback and cancel the timer.
    def self.defer(&block)
      fired = false
      timer = nil
      timer = UI.start_timer(0, false) do
        next if fired
        fired = true
        UI.stop_timer(timer) if timer
        block.call
      end
      timer
    end

    def self.model_materials
      Sketchup.active_model.materials.map do |material|
        texture = material.texture
        { name: material.name, label: material.display_name,
          color: '#' + material.color.to_a.first(3).map { |v| '%02x' % v }.join,
          width: texture ? (texture.width.to_f * 25.4).round(1) : nil,
          height: texture ? (texture.height.to_f * 25.4).round(1) : nil }
      end
    end

    def self.send_model
      return unless @dialog
      current = Materials.current(Sketchup.active_model)
      @dialog.execute_script("window.VGD.model(#{JSON.generate({ materials: model_materials, current: current ? current.name : nil, model_id: Sketchup.active_model.object_id.to_s })});")
    end

    def self.stop_scan
      UI.stop_timer(@scan_timer) if @scan_timer
      @scan_timer = nil
    end

    def self.scan
      stop_scan
      @scan_generation = (@scan_generation || 0) + 1
      generation = @scan_generation
      @items = {}
      return unless @dialog
      has_online = !Online.sources.empty?
      online_roots = Online.sources.map { |source| { id: Online.root(source), label: source['label'] || URI.parse(source['url']).host || File.basename(source['local'].to_s) } }
      @dialog.execute_script("window.VGD.begin(#{JSON.generate({ roots: Catalog.roots, online_roots: online_roots, favorites: Catalog.favorites, version: VERSION, view: @requested_view })});")
      @requested_view = nil
      scanner = Catalog.scan
      warnings = []
      busy = false
      @scan_timer = UI.start_timer(0.02, true) do
        next if busy || @scan_generation != generation || !@dialog
        busy = true
        begin
          batch = []
          complete = false
          100.times do
            begin
              entry = scanner.next
            rescue StopIteration
              complete = true
              break
            end
            next unless entry
            if entry[:warning]
              warnings << entry[:warning]
            else
              @items[entry[:id]] = entry
              batch << entry.reject { |key, _| key == :path }
            end
          end
          if @dialog
            @dialog.execute_script("window.VGD.append(#{JSON.generate(batch)}, #{complete && !has_online}, #{JSON.generate(warnings)});")
          end
          stop_scan if complete || !@dialog
          if complete && @dialog && has_online
            Online.refresh do |items, online_warnings, done|
              next unless @dialog && @scan_generation == generation
              warnings.concat(online_warnings)
              items.each { |item| @items[item[:id]] = item }
              public_items = items.map { |item| item.reject { |key, _| %i[path url sha256].include?(key) } }
              @dialog.execute_script("window.VGD.append(#{JSON.generate(public_items)}, #{done}, #{JSON.generate(warnings)});")
            end
          end
        rescue StandardError, SyntaxError => e
          stop_scan
          @scan_generation += 1
          warnings << "Đã dừng quét thư viện: #{e.message}"
          @dialog.execute_script("window.VGD.append([], true, #{JSON.generate(warnings)});") if @dialog
          message(warnings.last, true)
        ensure
          busy = false
        end
      end
      send_model
      if @pending_audit
        @dialog.execute_script("window.VGD.audit(#{JSON.generate(@pending_audit)});") if @dialog
        @pending_audit = nil
      end
    end

    def self.run(action, args = {})
      return show if action == 'library'
      return show('models') if action == 'models'
      return show_and_refresh if action == 'refresh'
      return Online.check_update if action == 'check_updates'
      if TOOL_ACTIONS.include?(action)
        model = Sketchup.active_model
        case action
        when 'seamless' then Seamless.show
        when 'audit'
          rows = Advanced.audit(model)
          show
          @pending_audit = rows
          @dialog.execute_script("window.VGD.audit(#{JSON.generate(rows)});") if @dialog
          message("Fix lồng map: #{rows.size} mặt có vật liệu khác vỏ. Chọn kiểu sửa trong bảng công cụ.")
        when 'aux' then message(Advanced.export_auxiliary(model, args))
        when 'save_model' then message(Models.save_selected)
        else model.select_tool(Tools::ClickTool.new(action, args))
        end
        return
      end
      raise 'Lệnh không hợp lệ.' unless ACTIONS.include?(action)
      result = transaction(action) do |model|
        case action
        when 'reapply'
          material = Materials.last(model)
          raise 'Chưa dùng vật liệu nào trong model này.' unless material
          Materials.apply(model, material)
        when 'clear' then Geometry.clear(model)
        when 'resize' then Materials.resize(model, args['width'], args['height'])
        when 'swap'
          target = Materials.current(model)
          source = model.materials[args['source'].to_s]
          raise 'Chọn vật liệu nguồn và vật liệu đích khác nhau.' unless source && target && source != target
          Advanced.swap_material(model, source, target, args.fetch('scope', 'selection'))
        when 'flow' then Advanced.flow(model)
        when 'fix_nesting' then Advanced.fix_nesting(model, args.fetch('strategy', 'shell'))
        when 'trace' then Advanced.trace(model, args)
        else
          angle = Float(args.fetch('angle', 90))
          raise 'Góc xoay không hợp lệ.' unless angle.finite? && angle.abs <= 360_000
          Geometry.edit(model, action, angle)
        end
      end
      message(result)
      send_model
    end

    def self.dispatch(action, payload)
      args = JSON.parse(payload.to_s)
      raise 'Dữ liệu không hợp lệ.' unless args.is_a?(Hash)
      if (ACTIONS + TOOL_ACTIONS + %w[apply apply_model export insert]).include?(action) && args['model_id'] != Sketchup.active_model.object_id.to_s
        raise 'Model đang mở đã thay đổi. Bấm Làm mới trước khi dùng vật liệu hoặc chỉnh map.'
      end
      case action
      when 'ready', 'refresh' then scan
      when 'add_folder'
        path = UI.select_directory(title: 'Chọn thư mục ảnh / SKM / model SKP')
        if path
          Catalog.add_folder(path)
          scan
        end
      when 'remove_folder'
        args['root'].to_s.start_with?('online:') ? Online.remove(args['root']) : Catalog.remove_folder(args['root'])
        scan
      when 'add_online'
        answer = UI.inputbox(['URL HTTPS danh mục VGD (JSON)'], ['https://'], 'Thêm thư viện online VGD')
        if answer
          Online.add(answer[0])
          scan
        end
      when 'import_catalog'
        path = UI.openpanel('Chọn danh mục thư viện VGD (.json)', nil, '*.json')
        if path
          Online.import_catalog(path)
          scan
        end
      when 'connect_drive'
        scan if Drive.connect
      when 'open_drive'
        Drive.open
      when 'thumbnails'
        ids = args.fetch('ids', [])
        raise 'Yêu cầu thumbnail không hợp lệ.' unless ids.is_a?(Array) && ids.size <= 60
        ids.each do |id|
          item = @items && @items[id]
          next unless item && !item[:online]
          url = Storage.thumbnail(item)
          @dialog.execute_script("window.VGD.thumbnail(#{JSON.generate(id)},#{JSON.generate(url)});") if @dialog
        end
      when 'favorite'
        id = args['id'].to_s
        raise 'Mẫu không còn trong thư viện.' unless @items && @items[id]
        favorites = Catalog.favorites
        favorites.include?(id) ? favorites.delete(id) : favorites.push(id)
        Catalog.save('favorites', favorites)
        @dialog.execute_script("window.VGD.favorites(#{JSON.generate(favorites)});") if @dialog
      when 'apply', 'insert'
        item = @items && @items[args['id'].to_s]
        raise 'Mẫu không còn trong thư viện. Hãy làm mới.' unless item
        if item[:online]
          expected_model = Sketchup.active_model
          message('Đang tải mẫu online…')
          Online.obtain(item) do |downloaded, error|
            defer do
              safely do
                raise(error) if error
                raise 'Model đã đổi trong lúc tải. Chọn lại mẫu trong model mới.' unless Sketchup.active_model.equal?(expected_model)
                message(use_item(downloaded, args))
                send_model
              end
            end
          end
        else
          message(use_item(item, args))
          send_model
        end
      when 'apply_model'
        result = transaction('Tô vật liệu trong model') do |model|
          material = model.materials[args['name'].to_s]
          raise 'Vật liệu không còn trong model.' unless material
          Materials.apply(model, material)
        end
        message(result)
        send_model
      when 'model' then send_model
      when 'export'
        material = Materials.current(Sketchup.active_model)
        raise 'Chọn vật liệu trước khi lưu.' unless material
        name = material.display_name.gsub(/[<>:"\/\\|?*]/, '_')
        path = UI.savepanel('Lưu vật liệu SKM', Catalog.roots.first, "#{name}.skm")
        if path
          path += '.skm' unless File.extname(path).downcase == '.skm'
          raise 'Không lưu được vật liệu.' unless material.save_as(path)
          message("Đã lưu #{File.basename(path)}. Làm mới nếu lưu vào thư mục thư viện.")
        end
      else run(action, args)
      end
    end

    def self.use_item(item, args)
      return Models.insert(item) if item[:kind] == 'model'
      transaction('Tô vật liệu') do |model|
        material = Materials.load_item(model, item, item[:width] || args['width'], item[:height] || args['height'])
        Materials.apply(model, material)
      end
    end

    def self.show_and_refresh
      show
      scan
    end

    def self.show(view = nil)
      @requested_view = view if view
      if @dialog
        @dialog.show
        @dialog.bring_to_front
        @dialog.execute_script("window.VGD.setView(#{JSON.generate(view)});") if view
        return
      end
      @dialog = UI::HtmlDialog.new(dialog_title: 'VGD_Library', preferences_key: Catalog::SECTION,
        scrollable: false, resizable: true, width: 1120, height: 760, min_width: 720, min_height: 500,
        style: UI::HtmlDialog::STYLE_DIALOG)
      @dialog.add_action_callback('vgd') do |_context, action, payload|
        # Native file pickers / tool activation are deferred out of CEF callbacks.
        dialog = @dialog
        defer { safely { dispatch(action.to_s, payload) } if @dialog.equal?(dialog) }
      end
      @dialog.set_on_closed { stop_scan; @dialog = nil }
      @dialog.set_file(File.join(ROOT, 'dialog.html'))
      @dialog.show
      ShellSync.attach_saved(Sketchup.active_model, Sketchup.active_model.entities.to_a)
    end

    unless file_loaded?(__FILE__)
      if Sketchup.version.to_i < 22
        UI.messagebox('VGD_Library yêu cầu SketchUp 2022 trở lên.')
      else
        toolbar = UI::Toolbar.new('VGD_Library')
        menu = UI.menu('Plugins').add_submenu('VGD_Library')
        COMMANDS.each do |title, action, tip|
          command = UI::Command.new(title) { safely { run(action) } }
          command.tooltip = title
          command.status_bar_text = tip
          command.small_icon = command.large_icon = File.join(ROOT, "icon_#{action}.svg")
          toolbar.add_item(command)
          menu.add_item(command)
        end
        menu.add_separator
        menu.add_item('Lưu model vào thư viện…') { safely { run('save_model') } }
        menu.add_item('Thêm nguồn online…') { safely { dispatch('add_online', '{}') } }
        menu.add_item('Kết nối kho vật liệu Drive 03 MTL…') { safely { dispatch('connect_drive', '{}') } }
        menu.add_item('Mở kho Drive trong trình duyệt') { safely { Drive.open } }
        menu.add_item('Nhập danh mục online (.json)…') { safely { dispatch('import_catalog', '{}') } }
        menu.add_item('Kiểm tra cập nhật VGD…') { safely { Online.check_update } }
        menu.add_item('Giới thiệu') { UI.messagebox("VGD_Library #{VERSION}\nThư viện vật liệu / model và bộ công cụ map, phát triển độc lập bởi VGD.\nSketchUp 2022+ — Windows / macOS") }
        toolbar.get_last_state == TB_NEVER_SHOWN ? toolbar.show : toolbar.restore
        @toolbar = toolbar
        UI.add_context_menu_handler do |context|
          unless Sketchup.active_model.selection.empty?
            submenu = context.add_submenu('VGD_Library')
            COMMANDS.each { |title, action, _tip| submenu.add_item(title) { safely { run(action) } } }
          end
        end
      end
      file_loaded(__FILE__)
    end
  end
end
