model = Sketchup.active_model
model.selection = Sketchup::Selection.new
model.active_path = nil
VGD::BIM.open_panel('information')
first = UI::HtmlDialog.instances.last
VGD::BIM.open_panel('scan') # Navigation may happen before HTML has sent ready.
assert(UI::HtmlDialog.instances.size == 1 && first.scripts.empty?, 'Navigation spawned a window or emitted before ready')
first.trigger('ready')
assert(first.scripts.any? { |s| s.include?('"mode":"scan"') }, 'Pending navigation before ready lost')
panel = VGD::BIM.instance_variable_get(:@panel)
scan_token = panel.instance_variable_get(:@generation)
%w[mapping validate_model export rules information convert_selection validate_selection information].each { |mode| VGD::BIM.open_panel(mode) }
assert(UI::HtmlDialog.instances.size == 1, 'Menu navigation created multiple dialogs')
assert(panel.instance_variable_get(:@generation) > scan_token, 'Switch did not cancel old scan generation')
assert(model.selection.observers.size == 1, 'Selection observer leaked across page switches')
first.trigger('open_panel', 'rules')
assert(UI::HtmlDialog.instances.size == 1 && model.selection.observers.empty?, 'In-window navigation opened a dialog or kept selection observer')
first.close
assert(panel.closed?, 'Closed panel not marked closed')
VGD::BIM.open_panel('information')
second = UI::HtmlDialog.instances.last
assert(UI::HtmlDialog.instances.size == 2 && second != first && second.callbacks.key?('ready'), 'Reopen reused cleared callbacks')
second.trigger('ready')
assert(model.selection.observers.size == 1, 'Observer missing after reopening')
second.close
assert(model.selection.observers.empty?, 'Observer retained after closing')
puts 'PASS: one window across menus and in-window navigation, navigation-before-ready, scan cancellation, observer cleanup, close/reopen callbacks'
# Cửa sổ Soạn tag riêng: mở từ menu / thanh công cụ / lệnh cũ open_panel('tags'), không chiếm cửa sổ chính.
VGD::BIM.open_panel('information')
main_dialog = UI::HtmlDialog.instances.last
main_dialog.trigger('ready')
main = VGD::BIM.instance_variable_get(:@panel)
before = UI::HtmlDialog.instances.size
main_dialog.trigger('open_panel', 'tags')
tags = VGD::BIM.instance_variable_get(:@tags)
assert(UI::HtmlDialog.instances.size == before + 1 && tags && tags.instance_variable_get(:@kind) == :tags && tags.instance_variable_get(:@mode) == 'tags', 'Soạn tag không mở thành cửa sổ riêng')
assert(main.instance_variable_get(:@mode) == 'information', 'Cửa sổ chính bị chuyển sang Soạn tag')
VGD::BIM.open_panel('tags')
assert(UI::HtmlDialog.instances.size == before + 1, 'Mở Soạn tag lần hai tạo thêm cửa sổ')
tags_dialog = UI::HtmlDialog.instances.last
tags_dialog.trigger('open_panel', 'table')
assert(tags.instance_variable_get(:@mode) == 'tags', 'Cửa sổ Soạn tag chuyển sang chức năng khác')
# Cửa sổ Soạn tag không bao giờ dựng Bảng khối lượng (beta.57: sheet khóa làm bảng hiện đè lên Soạn tag).
count = tags_dialog.scripts.size
tags.table_build
assert(tags_dialog.scripts.size == count, 'Cửa sổ Soạn tag vẫn dựng Bảng khối lượng')
# Cửa sổ Soạn tag ghi vào model: Bảng khối lượng ở cửa sổ chính đọc lại (gom lại bằng hẹn giờ).
reloaded = 0
main.define_singleton_method(:reload_table) { reloaded += 1 }
tags.send(:safely) { VGD::BIM::Data.transaction(Sketchup.active_model, 'thử') { nil } }
tags.send(:safely) { VGD::BIM::Data.transaction(Sketchup.active_model, 'thử') { nil } }
timers = UI.instance_variable_get(:@timers)
timers.values.each(&:call)
timers.clear
assert(reloaded == 1, 'Ghi ở cửa sổ Soạn tag không làm bảng đọc lại đúng một lần')
reloaded = 0
main.send(:safely) { VGD::BIM::Data.transaction(Sketchup.active_model, 'thử') { nil } }
timers.values.each(&:call)
assert(reloaded == 0, 'Cửa sổ chính tự báo đọc lại chính nó')
tags_dialog.close
main_dialog.close
puts 'PASS: cửa sổ Soạn tag riêng (mở từ lệnh cũ, không chuyển cửa sổ chính, chỉ Soạn tag), ghi ở Soạn tag làm bảng đọc lại'
