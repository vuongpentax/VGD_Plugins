# Test native icon selection with the documented Command file-path API.
# The toolbar icon is fixed (it does not follow the manager light/dark theme).
module VGD
  module Reference
    path = Icons.toolbar_path
    raise 'Toolbar icon must be vgd_reference.svg.' unless File.basename(path) == 'vgd_reference.svg'
    raise 'Packaged icon path does not exist.' unless File.file?(path)
    raise 'Toolbar icon must not depend on a theme argument.' unless Icons.method(:toolbar_path).arity.zero?
    begin
      command = Struct.new(:small_icon, :large_icon).new
      Icons.bind(command)
      raise 'Command icon is wrong.' unless command.small_icon == path && command.large_icon == path
    ensure
      Icons.instance_variable_set(:@command, nil)
    end
    puts 'PASS: manifest path, fixed toolbar icon, and Command icon binding.'
  end
end
