require 'json'

module VGD
  module Structure
    # Cửa sổ "Lưới trục" (HtmlDialog). Giao diện chỉ gửi dữ liệu thô; Ruby kiểm tra lại mọi thứ (Grid.normalize!, AxisSymbol.options!)
    # trước khi vẽ. Xem trước (preview) cũng do Ruby tính để giao diện và model dùng cùng một nguồn.
    class Panel
      TITLE = 'VGD Structure'.freeze
      CONFIRM_COLUMNS = 500 # dựng nhiều hơn số này thì hỏi xác nhận
      SELECTION_DELAY = 0.12     # giây: gom các sự kiện đổi vùng chọn của SketchUp thành một lần gửi
      SELECTION_ECHO = 0.6       # giây: sau khi tự chọn phần tử trong SketchUp theo yêu cầu của cửa sổ thì bỏ qua sự kiện do chính việc đó gây ra
      MAX_SELECT_ITEMS = 5000
      SELECT_KINDS = %w[column beam wall opening slab ceiling].freeze

      def initialize
        @dialog = ::UI::HtmlDialog.new(dialog_title: TITLE, preferences_key: 'vgd_structure_panel', scrollable: true, resizable: true,
                                       width: 1040, height: 700, min_width: 760, min_height: 520, style: ::UI::HtmlDialog::STYLE_DIALOG)
        @dialog.set_file(File.join(ROOT, 'html', 'index.html'))
        @dialog.add_action_callback('ready') { |_ctx| safely { @ready = true; send_state; flush_focus } }
        @dialog.add_action_callback('grid_preview') { |_ctx, payload| safely { grid_preview(JSON.parse(payload)) } }
        @dialog.add_action_callback('grid_build') { |_ctx, payload| safely { grid_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('grid_remove') { |_ctx| safely { grid_remove } }
        @dialog.add_action_callback('grid_axes') { |_ctx, payload| safely { grid_axes(JSON.parse(payload)) } }
        @dialog.add_action_callback('columns_build') { |_ctx, payload| safely { columns_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('columns_remove') { |_ctx, payload| safely { columns_remove(JSON.parse(payload)) } }
        @dialog.add_action_callback('beams_build') { |_ctx, payload| safely { beams_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('beams_remove') { |_ctx, payload| safely { beams_remove(JSON.parse(payload)) } }
        @dialog.add_action_callback('walls_build') { |_ctx, payload| safely { walls_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('walls_remove') { |_ctx, payload| safely { walls_remove(JSON.parse(payload)) } }
        @dialog.add_action_callback('openings_build') { |_ctx, payload| safely { openings_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('openings_remove') { |_ctx, payload| safely { openings_remove(JSON.parse(payload)) } }
        @dialog.add_action_callback('plates_build') { |_ctx, payload| safely { plates_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('plates_remove') { |_ctx, payload| safely { plates_remove(JSON.parse(payload)) } }
        @dialog.add_action_callback('propose') { |_ctx, payload| safely { propose(JSON.parse(payload)) } }
        @dialog.add_action_callback('check') { |_ctx, payload| safely { check(JSON.parse(payload)) } }
        @dialog.add_action_callback('build_all') { |_ctx, payload| safely { build_all(JSON.parse(payload)) } }
        @dialog.add_action_callback('picks_copy') { |_ctx, payload| safely { picks_copy(JSON.parse(payload)) } }
        @dialog.add_action_callback('grid_reset') { |_ctx| safely { send_state(reset: true) } }
        @dialog.add_action_callback('plan_select') { |_ctx, payload| safely { plan_select(JSON.parse(payload)) } }
        @dialog.add_action_callback('su_pick_start') { |_ctx| safely { su_pick_start } }
        @dialog.add_action_callback('su_pick_stop') { |_ctx| safely { su_pick_stop } }
        @dialog.set_on_closed { detach_observer; su_pick_stop } if @dialog.respond_to?(:set_on_closed)
      end

      # ---- Liên kết với SketchUp (cột mốc P6) ----

      # Theo dõi vùng chọn của SketchUp để cửa sổ sáng đúng phần tử (chỉ khi cửa sổ đang mở).
      def attach_observer
        model = Sketchup.active_model
        return if @watcher && @observed_model.equal?(model)
        detach_observer
        @watcher = SelectionWatcher.new(self)
        model.selection.add_observer(@watcher)
        @observed_model = model
      rescue StandardError => error # không theo dõi được vùng chọn thì cửa sổ vẫn dùng bình thường
        puts "[VGD Structure] không gắn được theo dõi vùng chọn: #{error.message}"
        @watcher = nil
        @observed_model = nil
      end

      def detach_observer
        @observed_model.selection.remove_observer(@watcher) if @watcher && @observed_model
      rescue StandardError
        nil
      ensure
        @watcher = nil
        @observed_model = nil
      end

      # Gọi từ SelectionWatcher mỗi khi vùng chọn trong SketchUp đổi (có thể rất dồn dập): gom lại rồi gửi một lần.
      def model_selection_changed
        return unless @ready
        return if @ignore_selection_until && Time.now.to_f < @ignore_selection_until
        return if @selection_timer
        @selection_timer = ::UI.start_timer(SELECTION_DELAY, false) { @selection_timer = nil; send_model_selection }
      end

      def send_model_selection
        return if @ignore_selection_until && Time.now.to_f < @ignore_selection_until
        emit('model_selection', ModelSync.selection_items(Sketchup.active_model))
      rescue StandardError => error
        puts "[VGD Structure] model_selection: #{error.message}"
      end

      # Cửa sổ chọn phần tử: chọn tương ứng trong SketchUp. payload {level:, items: [{kind:, ref:}]}; items rỗng thì bỏ chọn.
      def plan_select(payload)
        level = payload['level']
        items = payload['items']
        raise ArgumentError, 'Dữ liệu chọn không hợp lệ.' unless level.is_a?(String) && items.is_a?(Array) && items.size <= MAX_SELECT_ITEMS
        clean = items.map do |it|
          raise ArgumentError, 'Dữ liệu chọn không hợp lệ.' unless it.is_a?(Hash) && it['ref'].is_a?(String) && SELECT_KINDS.include?(it['kind'])
          {'kind' => it['kind'], 'ref' => it['ref']}
        end
        model = Sketchup.active_model
        @ignore_selection_until = Time.now.to_f + SELECTION_ECHO
        if clean.empty?
          model.selection.clear
          return
        end
        emit('select_result', ModelSync.select(model, level, clean).merge(requested: clean.size))
      end

      # Công cụ chọn điểm trong khung nhìn SketchUp: mỗi lần bấm gửi tọa độ (mm) về cửa sổ ('su_point'), rê chuột gửi 'su_move'.
      def su_pick_start
        model = Sketchup.active_model
        su_pick_stop if @pick_tool
        @pick_tool = PickTool.new(self)
        model.select_tool(@pick_tool)
        emit('su_pick_state', {active: true})
      end

      def su_pick_stop
        return unless @pick_tool
        @pick_tool = nil
        Sketchup.active_model.select_tool(nil)
        emit('su_pick_state', {active: false})
      end

      def pick_point(point)
        emit('su_point', {x: point[0], y: point[1]})
      end

      def pick_move(point)
        emit('su_move', {x: point[0], y: point[1]})
      end

      # Công cụ kết thúc không do cửa sổ (Esc, hoặc người dùng chọn công cụ khác của SketchUp).
      def pick_ended(tool)
        return unless @pick_tool.equal?(tool)
        @pick_tool = nil
        emit('su_pick_state', {active: false})
      end


      # Chuyển tới phần tử (do VGD_BIM yêu cầu sửa): gửi sự kiện focus khi cửa sổ đã sẵn sàng, chưa sẵn sàng thì giữ lại gửi sau.
      def focus(kind, level_id, ref)
        @pending_focus = {kind: kind, level: level_id, ref: ref}
        flush_focus if @ready
      end

      def flush_focus
        return unless @pending_focus
        emit('focus', @pending_focus)
        @pending_focus = nil
      end

      def show
        @dialog.visible? ? @dialog.bring_to_front : @dialog.show
        attach_observer
      end

      def visible?
        @dialog.visible?
      end

      def close
        detach_observer
        su_pick_stop
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
        state = reset ? State.default.merge('saved' => false, 'removed' => 0) : ModelStore.read(model)
        emit('state', {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], opening_types: state['opening_types'], levels: state['levels'], saved: state['saved'],
                       drawn: !GridBuilder.find(model).nil?, drawn_levels: drawn_levels(model), drawn_beam_levels: drawn_beam_levels(model), drawn_wall_levels: drawn_wall_levels(model), drawn_opening_levels: drawn_opening_levels(model), drawn_slab_levels: drawn_plate_levels(model, 'slabs'), drawn_ceiling_levels: drawn_plate_levels(model, 'ceilings'), version: VERSION})
        grid_preview(state.merge('level' => state['levels'].first['id'], 'status' => true))
      end

      # Xem trước do Ruby tính; nếu giao diện bật "trạng thái model" (payload['status']) thì gửi kèm so khớp với model của tầng đang xem.
      def grid_preview(payload)
        preview = Preview.build(payload)
        emit('preview', preview)
        emit_status(payload) if payload['status'] && preview[:ok] && preview[:levels_ok] != false
      end

      def emit_status(payload)
        state = State.normalize!(payload)
        level = payload['level'] || state['levels'].first['id']
        emit('model_status', ModelSync.status(Sketchup.active_model, state, level))
      rescue ArgumentError
        nil # dữ liệu đang sai: xem trước đã báo lỗi, không so khớp
      end

      def drawn_levels(model)
        ColumnBuilder.groups(model).map { |g| g.get_attribute(Schema::DICTIONARY, 'level') }
      end

      def drawn_beam_levels(model)
        BeamBuilder.groups(model).map { |g| g.get_attribute(Schema::DICTIONARY, 'level') }
      end

      def drawn_wall_levels(model)
        WallBuilder.groups(model).map { |g| g.get_attribute(Schema::DICTIONARY, 'level') }
      end

      # Đề xuất bán tự động cho một tầng (scope 'level', mã trong 'level') hoặc mọi tầng (scope 'all'): chỉ THÊM phần còn thiếu, giữ lựa chọn đã có.
      def propose(payload)
        grid = Grid.normalize!(payload['grid'])
        types = ColumnTypes.normalize!(payload['types'])
        beam_types = BeamTypes.normalize!(payload['beam_types'])
        wall_types = WallTypes.normalize!(payload['wall_types'])
        opening_types = payload['opening_types'].nil? ? OpeningTypes.default : OpeningTypes.normalize!(payload['opening_types'])
        levels, = Levels.normalize!(payload['levels'], grid, types, beam_types, wall_types, opening_types)
        ids = payload['scope'] == 'all' ? levels.map { |l| l['id'] } : [payload['level']]
        proposed, added = Proposal.propose(grid, levels, ids)
        clean, = Levels.normalize!(proposed, grid, types, beam_types, wall_types, opening_types)
        parts = Checker::KIND_LABELS.map { |kind, label| "#{added[kind]} #{label.downcase}" }.join(', ')
        emit('levels', {levels: clean, message: "Đã đề xuất cho #{ids.size} tầng: thêm #{parts}. Hãy xem lại từng tab, bỏ bớt hoặc thêm rồi dựng.", proposed: added})
      rescue Grid::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, OpeningTypes::Error, Levels::Error => error
        emit('message', {text: error.message, error: true})
      end

      # Kiểm tra kết cấu mọi tầng (chỉ đọc): lỗi và cảnh báo của các kế hoạch.
      def check(payload)
        emit('check', Checker.run(State.normalize!(payload)))
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, OpeningTypes::Error, Levels::Error => error
        emit('message', {text: error.message, error: true})
      end

      def drawn_all(model)
        {columns: drawn_levels(model), beams: drawn_beam_levels(model), walls: drawn_wall_levels(model), openings: drawn_opening_levels(model), slabs: drawn_plate_levels(model, 'slabs'), ceilings: drawn_plate_levels(model, 'ceilings')}
      end

      # Dựng tất cả (cột, dầm, tường, sàn, trần) của các tầng đã chọn trong MỘT bước hoàn tác; có lỗi thì không dựng gì cả.
      def build_all(payload)
        model = Sketchup.active_model
        ids = payload['levels']
        state = payload['state']
        if ids.is_a?(Array) && state.is_a?(Hash)
          clean = State.normalize!(state)
          total = AllBuilder.targets(clean, ids).sum { |kind, level_ids| level_ids.sum { |id| Levels.find(clean['levels'], id)['picks'][kind].size } }
          if total > CONFIRM_COLUMNS && ::UI.messagebox("Sẽ dựng khoảng #{total} đối tượng (cột, dầm, tường, sàn, trần). Tiếp tục?", MB_YESNO) != IDYES
            return emit('message', {text: 'Đã hủy, chưa dựng gì.'})
          end
        end
        result = AllBuilder.build(model, state, ids)
        parts = result[:kinds].map { |kind, r| "#{r.total} #{Checker::KIND_LABELS[kind].downcase}" }.join(', ')
        note = result[:issues].empty? ? '' : " Có #{result[:issues].size} cảnh báo: #{result[:issues].first(3).join(' ')}"
        emit('all_built', {message: "Đã dựng #{result[:total]} đối tượng trong một bước hoàn tác: #{parts}.#{note}", drawn: drawn_all(model)})
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, OpeningTypes::Error, Levels::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error, SlabPlan::Error, CeilingPlan::Error, ArgumentError => error
        emit('message', {text: error.message, error: true})
      end

      def drawn_opening_levels(model)
        OpeningBuilder.groups(model).map { |g| g.get_attribute(Schema::DICTIONARY, 'level') }
      end

      # Dựng cửa các tầng đã chọn (xem columns_build). Tường được khoét lỗ khi dựng tường (cùng dữ liệu cửa), nên nên dựng lại tường sau khi đặt hoặc sửa cửa.
      def openings_build(payload)
        model = Sketchup.active_model
        ids = payload['levels']
        state = payload['state']
        result = OpeningBuilder.build(model, state, ids)
        names = result.levels.map { |l| "#{l[:name]} (#{l[:count]} cửa)" }.join(', ')
        note = result.issues.empty? ? '' : " Có #{result.issues.size} cảnh báo: #{result.issues.first(3).join(' ')}"
        note += ' Nhớ dựng lại tường để tường có lỗ cửa.'
        emit('openings_built', {message: "Đã dựng #{result.total} cửa: #{names}.#{note}", drawn_opening_levels: drawn_opening_levels(model)})
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, OpeningTypes::Error, Levels::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error, OpeningPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      def openings_remove(payload)
        model = Sketchup.active_model
        id = payload['level']
        count = OpeningBuilder.remove(model, id.is_a?(String) ? id : nil)
        message = count.zero? ? 'Model chưa có cửa do VGD Structure dựng.' : 'Đã xóa cửa khỏi model. Dữ liệu cửa đã đặt vẫn được giữ; dựng lại tường để bỏ lỗ cửa nếu cần.'
        emit('openings_built', {message: message, drawn_opening_levels: drawn_opening_levels(model), error: count.zero?})
      rescue OpeningPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      def drawn_plate_levels(model, kind)
        PlateBuilder.groups(model, kind).map { |g| g.get_attribute(Schema::DICTIONARY, 'level') }
      end

      PLATE_LABELS = {'slabs' => 'sàn', 'ceilings' => 'trần'}.freeze

      # Dựng sàn hoặc trần các tầng đã chọn (payload['kind'] = slabs | ceilings; xem columns_build).
      def plates_build(payload)
        kind = payload['kind']
        label = PLATE_LABELS.fetch(kind) { raise ArgumentError, 'Loại tấm không hợp lệ.' }
        model = Sketchup.active_model
        ids = payload['levels']
        state = payload['state']
        if ids.is_a?(Array) && state.is_a?(Hash)
          clean = State.normalize!(state)
          total = ids.uniq.sum { |id| (level = Levels.find(clean['levels'], id)) ? level['picks'][kind].size : 0 }
          if total > CONFIRM_COLUMNS && ::UI.messagebox("Sẽ dựng #{total} #{label}. Tiếp tục?", MB_YESNO) != IDYES
            return emit('message', {text: "Đã hủy, chưa dựng #{label}."})
          end
        end
        result = PlateBuilder.build(model, state, ids, kind)
        names = result.levels.map { |l| "#{l[:name]} (#{l[:count]} #{label})" }.join(', ')
        note = result.issues.empty? ? '' : " Có #{result.issues.size} cảnh báo: #{result.issues.first(3).join(' ')}"
        note += " Đã dọn #{result.removed_orphans} nhóm #{label} của tầng không còn." if result.removed_orphans.positive?
        emit('plates_built', {kind: kind, message: "Đã dựng #{result.total} #{label}: #{names}.#{note}", drawn_levels: drawn_plate_levels(model, kind)})
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, OpeningTypes::Error, Levels::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error, SlabPlan::Error, CeilingPlan::Error, ArgumentError => error
        emit('message', {text: error.message, error: true})
      end

      def plates_remove(payload)
        kind = payload['kind']
        label = PLATE_LABELS.fetch(kind) { raise ArgumentError, 'Loại tấm không hợp lệ.' }
        model = Sketchup.active_model
        id = payload['level']
        count = PlateBuilder.remove(model, kind, id.is_a?(String) ? id : nil)
        message = count.zero? ? "Model chưa có #{label} do VGD Structure dựng." : "Đã xóa #{label} khỏi model. Dữ liệu #{label} đã chọn vẫn được giữ."
        emit('plates_built', {kind: kind, message: message, drawn_levels: drawn_plate_levels(model, kind), error: count.zero?})
      rescue ArgumentError => error
        emit('message', {text: error.message, error: true})
      end

      # Dựng tường các tầng đã chọn (xem columns_build).
      def walls_build(payload)
        model = Sketchup.active_model
        ids = payload['levels']
        state = payload['state']
        if ids.is_a?(Array) && state.is_a?(Hash)
          clean = State.normalize!(state)
          total = ids.uniq.sum { |id| (level = Levels.find(clean['levels'], id)) ? level['picks']['walls'].size : 0 }
          if total > CONFIRM_COLUMNS && ::UI.messagebox("Sẽ dựng #{total} tường. Tiếp tục?", MB_YESNO) != IDYES
            return emit('message', {text: 'Đã hủy, chưa dựng tường.'})
          end
        end
        result = WallBuilder.build(model, state, ids)
        names = result.levels.map { |l| "#{l[:name]} (#{l[:count]} tường)" }.join(', ')
        note = result.issues.empty? ? '' : " Có #{result.issues.size} cảnh báo: #{result.issues.first(3).join(' ')}"
        note += " Đã dọn #{result.removed_orphans} nhóm tường của tầng không còn." if result.removed_orphans.positive?
        emit('walls_built', {message: "Đã dựng #{result.total} tường: #{names}.#{note}", drawn_wall_levels: drawn_wall_levels(model)})
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      def walls_remove(payload)
        model = Sketchup.active_model
        id = payload['level']
        count = WallBuilder.remove(model, id.is_a?(String) ? id : nil)
        message = count.zero? ? 'Model chưa có tường do VGD Structure dựng.' : 'Đã xóa tường khỏi model. Dữ liệu tường đã chọn vẫn được giữ.'
        emit('walls_built', {message: message, drawn_wall_levels: drawn_wall_levels(model), error: count.zero?})
      rescue WallPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      # Dựng dầm các tầng đã chọn (xem columns_build).
      def beams_build(payload)
        model = Sketchup.active_model
        ids = payload['levels']
        state = payload['state']
        if ids.is_a?(Array) && state.is_a?(Hash)
          clean = State.normalize!(state)
          total = ids.uniq.sum { |id| (level = Levels.find(clean['levels'], id)) ? level['picks']['beams'].size : 0 }
          if total > CONFIRM_COLUMNS && ::UI.messagebox("Sẽ dựng #{total} dầm. Tiếp tục?", MB_YESNO) != IDYES
            return emit('message', {text: 'Đã hủy, chưa dựng dầm.'})
          end
        end
        result = BeamBuilder.build(model, state, ids)
        names = result.levels.map { |l| "#{l[:name]} (#{l[:count]} dầm)" }.join(', ')
        note = result.issues.empty? ? '' : " Có #{result.issues.size} cảnh báo: #{result.issues.first(3).join(' ')}"
        note += " Đã dọn #{result.removed_orphans} nhóm dầm của tầng không còn." if result.removed_orphans.positive?
        emit('beams_built', {message: "Đã dựng #{result.total} dầm: #{names}.#{note}", drawn_beam_levels: drawn_beam_levels(model)})
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      def beams_remove(payload)
        model = Sketchup.active_model
        id = payload['level']
        count = BeamBuilder.remove(model, id.is_a?(String) ? id : nil)
        message = count.zero? ? 'Model chưa có dầm do VGD Structure dựng.' : 'Đã xóa dầm khỏi model. Dữ liệu dầm đã chọn vẫn được giữ.'
        emit('beams_built', {message: message, drawn_beam_levels: drawn_beam_levels(model), error: count.zero?})
      rescue BeamPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      # Dựng cột các tầng đã chọn (ids) từ trạng thái giao diện gửi lên; Ruby kiểm tra lại và lập kế hoạch trước khi đụng model.
      def columns_build(payload)
        model = Sketchup.active_model
        ids = payload['levels']
        state = payload['state']
        if ids.is_a?(Array) && state.is_a?(Hash)
          clean = State.normalize!(state)
          total = ids.uniq.sum { |id| (level = Levels.find(clean['levels'], id)) ? level['picks']['columns'].size : 0 }
          if total > CONFIRM_COLUMNS && ::UI.messagebox("Sẽ dựng #{total} cột. Tiếp tục?", MB_YESNO) != IDYES
            return emit('message', {text: 'Đã hủy, chưa dựng cột.'})
          end
        end
        result = ColumnBuilder.build(model, state, ids)
        names = result.levels.map { |l| "#{l[:name]} (#{l[:count]} cột, cao #{l[:height].round}mm)" }.join(', ')
        note = result.issues.empty? ? '' : " Có #{result.issues.size} cảnh báo: #{result.issues.first(3).join(' ')}"
        note += " Đã dọn #{result.removed_orphans} nhóm cột của tầng không còn." if result.removed_orphans.positive?
        emit('columns_built', {message: "Đã dựng #{result.total} cột: #{names}.#{note}", drawn_levels: drawn_levels(model)})
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error, ColumnPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      def columns_remove(payload)
        model = Sketchup.active_model
        id = payload['level']
        count = ColumnBuilder.remove(model, id.is_a?(String) ? id : nil)
        message = count.zero? ? 'Model chưa có cột do VGD Structure dựng.' : 'Đã xóa cột khỏi model. Dữ liệu cột đã chọn vẫn được giữ.'
        emit('columns_built', {message: message, drawn_levels: drawn_levels(model), error: count.zero?})
      rescue ColumnPlan::Error => error
        emit('message', {text: error.message, error: true})
      end

      # Sao chép lựa chọn cột từ tầng này sang tầng khác (thay lựa chọn của tầng đích); gửi lại danh sách tầng mới cho giao diện.
      def picks_copy(payload)
        grid = Grid.normalize!(payload['grid'])
        types = ColumnTypes.normalize!(payload['types'])
        beam_types = payload['beam_types'].nil? ? BeamTypes.default : BeamTypes.normalize!(payload['beam_types'])
        wall_types = payload['wall_types'].nil? ? WallTypes.default : WallTypes.normalize!(payload['wall_types'])
        opening_types = payload['opening_types'].nil? ? OpeningTypes.default : OpeningTypes.normalize!(payload['opening_types'])
        levels, = Levels.normalize!(payload['levels'], grid, types, beam_types, wall_types, opening_types)
        kind = %w[beams walls openings slabs ceilings].include?(payload['kind']) ? payload['kind'] : 'columns'
        copied = Levels.copy_picks(levels, payload['from'], payload['to'], grid, types, kind, beam_types, wall_types, opening_types)
        from = Levels.find(levels, payload['from'])['name']
        to = Levels.find(levels, payload['to'])['name']
        emit('levels', {levels: copied, message: "Đã sao chép lựa chọn #{{'beams' => 'dầm', 'walls' => 'tường', 'openings' => 'cửa', 'slabs' => 'sàn', 'ceilings' => 'trần'}.fetch(kind, 'cột')} từ “#{from}” sang “#{to}”."})
      rescue Grid::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, OpeningTypes::Error, Levels::Error => error
        emit('message', {text: error.message, error: true})
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

      def safely
        yield
      rescue StandardError, ScriptError => error
        puts "[VGD Structure] #{error.class}: #{error.message}"
        emit('message', {text: "Lỗi: #{error.message}", error: true})
      end
    end
  end
end
