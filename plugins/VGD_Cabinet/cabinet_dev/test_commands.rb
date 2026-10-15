def assert(value, message); raise message unless value; end
extensions = UI.menus.fetch('Extensions')
menu = extensions.items.last
toolbar = UI.toolbars.last
assert(extensions.items.size == 2, 'Cabinet should expose only its modeling command and submenu')
assert(menu.name == 'VGD Cabinet' && menu.items.size == 1, 'Cabinet submenu should only contain Reload')
assert(menu.items[0].name.include?('Reload'), 'Reload command missing')
assert(toolbar.items.size == 1, 'Cabinet toolbar should only contain the modeling command')
command = extensions.items[0]
assert(command.name.include?('Dựng hình'), 'Cabinet command missing')
assert(command.small_icon.end_with?('cabinet.svg') && command.large_icon.end_with?('cabinet.svg'), 'Wrong Cabinet command icon')
assert(!defined?(VGDExplode) && !defined?(VGDUntag), 'Legacy utility modules must not load with Cabinet')
VGD_Cabinet.install_commands
assert(UI.toolbars.size == 1 && toolbar.items.size == 1, 'Duplicate toolbar after reinstall')
assert(extensions.items.size == 2 && menu.items.size == 1 && UI.context_handlers.size == 1, 'Duplicate menus or context handlers')
puts 'PASS clean commands: Cabinet toolbar, Reload submenu, no legacy utility commands, no duplicate UI'
