def assert(value, message); raise message unless value; end
extensions = UI.menus.fetch('Extensions')
vgd_menu = extensions.items.last
menu = vgd_menu.items.last
toolbar = UI.toolbars.last
assert(extensions.items.size == 1 && vgd_menu.name == 'VGD' && vgd_menu.items.size == 1, 'Cabinet should only add the VGD menu to Extensions')
assert(menu.name == 'VGD Cabinet' && menu.items.size == 2, 'Cabinet submenu should hold the modeling command and Reload')
assert(menu.items[1].name.include?('Reload'), 'Reload command missing')
assert(toolbar.items.size == 1, 'Cabinet toolbar should only contain the modeling command')
command = menu.items[0]
assert(command.name.include?('Dựng hình'), 'Cabinet command missing')
assert(command.small_icon.end_with?('cabinet.svg') && command.large_icon.end_with?('cabinet.svg'), 'Wrong Cabinet command icon')
assert(!defined?(VGDExplode) && !defined?(VGDUntag), 'Legacy utility modules must not load with Cabinet')
VGD_Cabinet.install_commands
assert(UI.toolbars.size == 1 && toolbar.items.size == 1, 'Duplicate toolbar after reinstall')
assert(extensions.items.size == 1 && vgd_menu.items.size == 1 && menu.items.size == 2 && UI.context_handlers.size == 1, 'Duplicate menus or context handlers')
puts 'PASS clean commands: Cabinet toolbar, Reload submenu, no legacy utility commands, no duplicate UI'
