# Test native icon selection with the documented Command file-path API.
module Sketchup
  def self.read_default(section, key, fallback)
    raise 'Unexpected icon preference key.' unless section == 'VGD.Reference' && key == 'ToolbarTheme'
    @reference_test_theme || fallback
  end
  def self.write_default(section, key, value)
    raise 'Unexpected icon preference key.' unless section == 'VGD.Reference' && key == 'ToolbarTheme'
    @reference_test_theme = value
  end
end

module VGD
  module Reference
    light = Icons.toolbar_path
    dark = Icons.toolbar_path('dark')
    raise 'Default icon must use the light toolbar.' unless File.basename(light) == 'vgd_reference.svg'
    raise 'Dark icon was not selected.' unless File.basename(dark) == 'vgd_reference_dark.svg'
    raise 'Invalid theme must fall back to light.' unless Icons.toolbar_path('invalid') == light
    raise 'Packaged icon paths do not exist.' unless File.file?(light) && File.file?(dark)
    begin
      command = Struct.new(:small_icon, :large_icon).new
      Icons.bind(command)
      raise 'Initial command icon is wrong.' unless command.small_icon == light && command.large_icon == light
      Icons.set_toolbar_theme('dark')
      raise 'Saved toolbar theme was ignored.' unless Icons.toolbar_path == dark
      raise 'Live command icon was not updated.' unless command.small_icon == dark && command.large_icon == dark
      begin
        Icons.set_toolbar_theme('invalid')
        raise 'Invalid setting should be rejected.'
      rescue ArgumentError
        raise 'Invalid setting overwrote the preference.' unless Icons.toolbar_theme == 'dark'
      end
    ensure
      Sketchup.remove_instance_variable(:@reference_test_theme)
      Icons.instance_variable_set(:@command, nil)
    end
    puts 'PASS: manifest paths, light/dark selection, saved setting, live Command icon update, and invalid-theme handling.'
  end
end
