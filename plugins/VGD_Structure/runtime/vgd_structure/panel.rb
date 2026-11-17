require 'json'

module VGD
  module Structure
    # Cửa sổ "Lưới trục" (HtmlDialog). Giao diện chỉ gửi dữ liệu thô; Ruby kiểm tra lại mọi thứ (Grid.normalize!, AxisSymbol.options!)
    # trước khi vẽ. Xem trước (preview) cũng do Ruby tính để giao diện và model dùng cùng một nguồn.
    class Panel
      TITLE = 'VGD Structure'.freeze
      CONFIRM_COLUMNS = 500 # dựng nhiều hơn số này thì hỏi xác nhận

      def initialize
        @dialog = ::UI::HtmlDialog.new(dialog_title: TITLE, preferences_key: 'vgd_structure_panel', scrollable: true, resizable: true,
                                       width: 1040, height: 700, min_width: 760, min_height: 520, style: ::UI::HtmlDialog::STYLE_DIALOG)
        @dialog.set_file(File.join(ROOT, 'html', 'index.html'))
        @dialog.add_action_callback('ready') { |_ctx| safely { send_state } }
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
        @dialog.add_action_callback('plates_build') { |_ctx, payload| safely { plates_build(JSON.parse(payload)) } }
        @dialog.add_action_callback('plates_remove') { |_ctx, payload| safely { plates_remove(JSON.parse(payload)) } }
        @dialog.add_action_callback('propose') { |_ctx, payload| safely { propose(JSON.parse(payload)) } }
        @dialog.add_action_callback('check') { |_ctx, payload| safely { check(JSON.parse(payload)) } }
        @dialog.add_action_callback('build_all') { |_ctx, payload| safely { build_all(JSON.parse(payload)) } }
        @dialog.add_action_callback('picks_copy') { |_ctx, payload| safely { picks_copy(JSON.parse(payload)) } }
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
        state = reset ? State.default.merge('saved' => false, 'removed' => 0) : ModelStore.read(model)
        emit('state', {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], levels: state['levels'], saved: state['saved'],
                       drawn: !GridBuilder.find(model).nil?, drawn_levels: drawn_levels(model), drawn_beam_levels: drawn_beam_levels(model), drawn_wall_levels: drawn_wall_levels(model), drawn_slab_levels: drawn_plate_levels(model, 'slabs'), drawn_ceiling_levels: drawn_plate_levels(model, 'ceilings'), version: VERSION})
        grid_preview(state.merge('level' => state['levels'].first['id']))
      end

      def grid_preview(payload)
        emit('preview', Preview.build(payload))
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
        levels, = Levels.normalize!(payload['levels'], grid, types, beam_types, wall_types)
        ids = payload['scope'] == 'all' ? levels.map { |l| l['id'] } : [payload['level']]
        proposed, added = Proposal.propose(grid, levels, ids)
        clean, = Levels.normalize!(proposed, grid, types, beam_types, wall_types)
        parts = Checker::KIND_LABELS.map { |kind, label| "#{added[kind]} #{label.downcase}" }.join(', ')
        emit('levels', {levels: clean, message: "Đã đề xuất cho #{ids.size} tầng: thêm #{parts}. Hãy xem lại từng tab, bỏ bớt hoặc thêm rồi dựng.", proposed: added})
      rescue Grid::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error => error
        emit('message', {text: error.message, error: true})
      end

      # Kiểm tra kết cấu mọi tầng (chỉ đọc): lỗi và cảnh báo của các kế hoạch.
      def check(payload)
        emit('check', Checker.run(State.normalize!(payload)))
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error => error
        emit('message', {text: error.message, error: true})
      end

      def drawn_all(model)
        {columns: drawn_levels(model), beams: drawn_beam_levels(model), walls: drawn_wall_levels(model), slabs: drawn_plate_levels(model, 'slabs'), ceilings: drawn_plate_levels(model, 'ceilings')}
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
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error, SlabPlan::Error, CeilingPlan::Error, ArgumentError => error
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
      rescue Grid::Error, AxisSymbol::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error, ColumnPlan::Error, BeamPlan::Error, WallPlan::Error, SlabPlan::Error, CeilingPlan::Error, ArgumentError => error
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
        levels, = Levels.normalize!(payload['levels'], grid, types, beam_types, wall_types)
        kind = %w[beams walls slabs ceilings].include?(payload['kind']) ? payload['kind'] : 'columns'
        copied = Levels.copy_picks(levels, payload['from'], payload['to'], grid, types, kind, beam_types, wall_types)
        from = Levels.find(levels, payload['from'])['name']
        to = Levels.find(levels, payload['to'])['name']
        emit('levels', {levels: copied, message: "Đã sao chép lựa chọn #{{'beams' => 'dầm', 'walls' => 'tường', 'slabs' => 'sàn', 'ceilings' => 'trần'}.fetch(kind, 'cột')} từ “#{from}” sang “#{to}”."})
      rescue Grid::Error, ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, Levels::Error => error
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
