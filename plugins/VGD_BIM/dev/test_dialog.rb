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
