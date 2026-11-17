require 'json'

module VGD
  module Structure
    # Cửa sổ "Lưới trục" (HtmlDialog). Giao diện chỉ gửi dữ liệu thô; Ruby kiểm tra lại mọi thứ (Grid.normalize!, AxisSymbol.options!)
    # trước khi vẽ. Xem trước (preview) cũng do Ruby tính để giao diện và model dùng cùng một nguồn.
    class Panel
      TITLE = 'VGD Structure · Lưới trục'.freeze

      def initialize
        @dialog = ::UI::HtmlDialog.new(dialog_title: TITLE, preferences_key: 'vgd_structure_panel', scrollable: true, resizable: true,
                                       width: 1040, height: 700, min_width: 760, min_height: 520, style: ::UI::HtmlDialog::STYLE_DIALOG)
        @dialog.set_file(File.join(ROOT, 'html', 'index.html'))
        @dialog.add_action_callback('ready') { |_ctx| safely { send_state } }
        @dialog.add_action_callback('grid_preview') { |_ctx, payload| safely { grid_preview(JSON.parse(payload)) } }
        @dialog.add_action_callback('grid_build') { |_ctx, payload| safely { grid_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('grid_remove') { |_ctx| safely { grid_remove } }
        @dialog.add_action_callback('grid_axes') { |_ctx, payload| safely { grid_axes(JSON.parse(payload)) } }
        @dialog.add_action_callback('grid_reset') { |_ctx| safely { send_state(reset: true) } }
      end

      def show
        @dialog.visible? ? @dialog.bring_to_front : @dialog.show
      end

      def visible?
        @dialog.visible?
      end

      def close
        @dialog.close
      end

      def closed?
        !@dialog.visible?
      end

      def emit(event, data)
        @dialog.execute_script("window.VGDS && window.VGDS.receive(#{event.to_json}, #{data.to_json})")
      end

      # Trạng thái ban đầu: lưới và thiết lập đã lưu trong model (hoặc mặc định), và model đã có lưới vẽ chưa.
      def send_state(reset: false)
        model = Sketchup.active_model
        state = reset ? {'grid' => Grid.default, 'symbol' => AxisSymbol.options!(nil), 'saved' => false} : ModelStore.read(model)
        emit('state', {grid: state['grid'], symbol: state['symbol'], saved: state['saved'], drawn: !GridBuilder.find(model).nil?, version: VERSION})
        grid_preview(state)
      end

      def grid_preview(payload)
        grid = Grid.normalize!(payload['grid'])
        options = AxisSymbol.options!(payload['symbol'])
        emit('preview', {ok: true, summary: summary(grid), bounds: Grid.bounds(grid), axes: AxisSymbol.plan(grid, options)})
      rescue Grid::Error, AxisSymbol::Error => error
        emit('preview', {ok: false, error: error.message})
      end

      # Tạo danh sách trục từ chuỗi nhịp ("4200, 3600*2"); tên mặc định số (trục đứng) hoặc chữ (trục ngang).
      def grid_axes(payload)
        dir = payload['dir'] == 'y' ? 'y' : 'x'
        emit('axes', {dir: dir, axes: Grid.axes_from_spacings(payload['text'], dir == 'x' ? :number : :letter)})
      rescue Grid::Error => error
        emit('message', {text: error.message, error: true})
      end

      def grid_build(payload)
        model = Sketchup.active_model
        result = GridBuilder.build(model, payload['grid'], payload['symbol'])
        emit('built', {message: "Đã vẽ lưới trục: #{result.axes} trục, #{result.symbols} ký hiệu. #{result.style_note}", drawn: true})
      rescue Grid::Error, AxisSymbol::Error => error
        emit('message', {text: error.message, error: true})
      end

      def grid_remove
        model = Sketchup.active_model
        return emit('message', {text: 'Model chưa có lưới trục do VGD Structure vẽ.', error: true}) unless GridBuilder.find(model)
        return emit('message', {text: 'Đã hủy, chưa xóa gì.'}) unless ::UI.messagebox('Xóa lưới trục khỏi model? Dữ liệu lưới vẫn được giữ để vẽ lại.', MB_YESNO) == IDYES
        GridBuilder.remove(model)
        emit('built', {message: 'Đã xóa lưới trục khỏi model. Dữ liệu lưới vẫn được giữ.', drawn: false})
      rescue Grid::Error => error
        emit('message', {text: error.message, error: true})
      end

      def summary(grid)
        x0, y0, x1, y1 = Grid.bounds(grid)
        {x_axes: grid['x_axes'].size, y_axes: grid['y_axes'].size, intersections: Grid.intersections(grid).size, spans: Grid.spans(grid).size,
         cells: Grid.cells(grid).size, width: (x1 - x0).round(1), depth: (y1 - y0).round(1)}
      end

      def safely
        yield
      rescue StandardError, ScriptError => error
        puts "[VGD Structure] #{error.class}: #{error.message}"
        emit('message', {text: "Lỗi: #{error.message}", error: true})
      end
    end
  end
end
