# encoding: UTF-8
# Test VGD Center chạy ngoài SketchUp (dùng stub trong dev/stub).
# Chạy từ thư mục plugins/VGD_Center:  ruby dev/test_center.rb
require 'json'
require 'tmpdir'
require 'fileutils'
require 'zlib'

$LOAD_PATH.unshift(File.join(__dir__, 'stub'))
require_relative '../VGD_Center/main'

CENTER = VGD::Center
PASSED = []
FAILED = []

def check(name, condition, detail = nil)
  (condition ? PASSED : FAILED) << name
  puts "#{condition ? 'OK  ' : 'LỖI'} #{name}#{detail && !condition ? " — #{detail}" : ''}"
end

def warning
  CENTER.instance_variable_get(:@catalog_warning)
end

def product(id, overrides = {})
  base = {
    'id' => id, 'name' => 'VGD Demo Tool', 'extension_name' => 'VGD Demo Tool',
    'version' => '1.0.0-beta.1', 'release_channel' => 'beta', 'description' => 'Plugin thử',
    'icon' => id, 'minimum_sketchup' => '22.0.0',
    'download' => {
      'filename' => 'VGD_DemoTool_1.0.0-beta.1.rbz',
      'url' => 'https://github.com/vuongpentax/VGD_Plugins/releases/download/vgd-demo-v1.0.0-beta.1/VGD_DemoTool_1.0.0-beta.1.rbz',
      'size' => 1000, 'sha256' => 'a' * 64
    },
    'allowed_paths' => ['VGD_DemoTool.rb', 'VGD_DemoTool/']
  }
  base.merge(overrides)
end

def validate(*products)
  CENTER.validate_catalog('schema_version' => 1, 'channel' => 'latest', 'products' => products)['products']
end

def ids_of(products)
  products.map { |item| item['id'] }
end

# ---------- 1. Catalog thật trong repo ----------
real = JSON.parse(File.read(File.expand_path('../../../../shared/vgd-center/catalog.json', __FILE__), encoding: 'UTF-8'))
accepted = CENTER.validate_catalog(real)['products']
released = real['products'].reject { |item| item['lifecycle'] == 'in_development' }
check 'catalog thật: mọi plugin đã phát hành đều được nhận', ids_of(accepted) == ids_of(released), "nhận #{ids_of(accepted)}"
check 'catalog thật: không có cảnh báo', warning.nil?, warning
check 'catalog thật: có VGD Plugin Manager', ids_of(accepted).include?('plugin_manager')

# ---------- 2. Plugin mới theo quy tắc chung ----------
result = validate(product('demo_tool'))
check 'plugin mới hợp lệ được nhận mà không cần sửa Center', ids_of(result) == ['demo_tool'], warning
check 'plugin mới hợp lệ: không cảnh báo', warning.nil?
check 'loader viết thường vgd_*.rb được nhận (như plugin cũ)',
      ids_of(validate(product('demo_tool', 'allowed_paths' => ['vgd_demo.rb', 'VGD_Demo/']))) == ['demo_tool'], warning

# ---------- 3. Các trường hợp bị từ chối ----------
def rejected(name, item)
  result = validate(item)
  check "từ chối: #{name}", result.empty? && !warning.nil?, "kết quả #{ids_of(result)} / #{warning.inspect}"
end

rejected 'id là center', product('center')
rejected 'id viết hoa', product('Demo')
rejected 'id có ký tự lạ', product('demo-tool')
rejected 'tên extension không bắt đầu bằng "VGD "', product('demo_tool', 'extension_name' => 'Demo Tool')
rejected 'tên extension trùng plugin có sẵn', product('demo_tool', 'extension_name' => 'VGD Dim')
rejected 'đường dẫn trùng plugin có sẵn', product('demo_tool', 'allowed_paths' => ['vgd_dim.rb', 'VGD_Dim/'])
rejected 'đường dẫn trùng plugin có sẵn khác hoa thường', product('demo_tool', 'allowed_paths' => ['VGD_DIM.rb', 'vgd_dim/'])
rejected 'trùng đường dẫn của Center', product('demo_tool', 'allowed_paths' => ['VGD_Center.rb', 'VGD_Center/'])
rejected 'thư mục không khớp loader', product('demo_tool', 'allowed_paths' => ['VGD_A.rb', 'VGD_B/'])
rejected 'loader không bắt đầu bằng VGD_/vgd_', product('demo_tool', 'allowed_paths' => ['evil.rb', 'evil/'])
rejected 'ba đường dẫn', product('demo_tool', 'allowed_paths' => ['VGD_DemoTool.rb', 'VGD_DemoTool/', 'Other/'])
rejected 'một đường dẫn', product('demo_tool', 'allowed_paths' => ['VGD_DemoTool.rb'])
rejected 'đường dẫn tuyệt đối', product('demo_tool', 'allowed_paths' => ['/VGD_DemoTool.rb', 'VGD_DemoTool/'])
rejected 'đường dẫn có ..', product('demo_tool', 'allowed_paths' => ['VGD_DemoTool.rb', 'VGD_DemoTool/../x/'])
rejected 'đường dẫn có dấu \\', product('demo_tool', 'allowed_paths' => ['VGD_DemoTool.rb', 'VGD_DemoTool\\'])
rejected 'thư mục có hai dấu /', product('demo_tool', 'allowed_paths' => ['VGD_DemoTool.rb', 'VGD_DemoTool//'])
rejected 'loader có dấu /', product('demo_tool', 'allowed_paths' => ['VGD_DemoTool.rb/', 'VGD_DemoTool/'])
rejected 'allowed_paths không phải mảng', product('demo_tool', 'allowed_paths' => 'VGD_DemoTool.rb')
rejected 'nguồn tải không phải GitHub của VGD',
         product('demo_tool', 'download' => product('demo_tool')['download'].merge('url' => 'https://evil.example/VGD_DemoTool_1.0.0-beta.1.rbz'))
rejected 'SHA-256 sai định dạng', product('demo_tool', 'download' => product('demo_tool')['download'].merge('sha256' => 'xyz'))
rejected 'kênh không khớp phiên bản', product('demo_tool', 'release_channel' => 'stable')
rejected 'plugin có sẵn nhưng đường dẫn sai', product('dim', 'name' => 'VGD Dim', 'extension_name' => 'VGD Dim',
                                                       'download' => { 'filename' => 'VGD_Dim_1.0.0-beta.1.rbz',
                                                                       'url' => 'https://github.com/vuongpentax/VGD_Plugins/releases/download/x/VGD_Dim_1.0.0-beta.1.rbz',
                                                                       'size' => 1, 'sha256' => 'b' * 64 },
                                                       'allowed_paths' => ['vgd_dim.rb', 'Other/'])

two = validate(product('demo_tool'), product('other_tool', 'name' => 'VGD Other', 'extension_name' => 'VGD Other'))
check 'hai plugin mới trùng đường dẫn: chỉ nhận cái đầu', ids_of(two) == ['demo_tool'], warning
check 'plugin mới không phá plugin có sẵn khi đứng cạnh nhau',
      ids_of(validate(product('demo_tool'), real['products'].find { |item| item['id'] == 'dim' })) == %w[demo_tool dim], warning
check 'mục đang phát triển bị bỏ qua không cảnh báo',
      validate(product('demo_tool', 'lifecycle' => 'in_development')).empty? && warning.nil?

# ---------- 4. Ghi chú gỡ cài đặt ----------
note = validate(product('demo_tool', 'uninstall_note' => "  Sao lưu dữ liệu trước.\u0007\n"))[0]['uninstall_note']
check 'uninstall_note: bỏ ký tự điều khiển và khoảng trắng đầu/cuối', note == 'Sao lưu dữ liệu trước.', note.inspect
check 'uninstall_note: quá dài bị bỏ', !validate(product('demo_tool', 'uninstall_note' => 'x' * 401))[0].key?('uninstall_note')
check 'uninstall_note: không phải chuỗi bị bỏ', !validate(product('demo_tool', 'uninstall_note' => 5))[0].key?('uninstall_note')
check 'uninstall_note: chuỗi rỗng bị bỏ', !validate(product('demo_tool', 'uninstall_note' => ' '))[0].key?('uninstall_note')

# ---------- 5. Danh sách hiển thị: cờ guide ----------
CENTER.instance_variable_set(:@catalog, 'schema_version' => 1, 'channel' => 'latest',
                                         'products' => validate(product('demo_tool'), real['products'].find { |item| item['id'] == 'dim' }))
shown = CENTER.current_products
by_id = shown.each_with_object({}) { |item, memo| memo[item[:id]] = item }
check 'dim có trang hướng dẫn trong Center', by_id['dim'][:guide] == true
check 'plugin mới không có trang hướng dẫn (nút sẽ ẩn)', by_id['demo_tool'][:guide] == false
check 'plugin mới hiện là "cài đặt"', by_id['demo_tool'][:action] == 'install' && by_id['demo_tool'][:installed] == false
check 'mọi plugin bundle đều có trang hướng dẫn thật',
      (accepted.map { |item| item['id'] } - %w[]).all? { |id| File.file?(File.join(__dir__, '..', 'VGD_Center', 'guides', "#{id}.html")) }

# ---------- 6. Hướng dẫn ----------
$stub_messages.clear
CENTER.open_guide('demo_tool')
check 'mở hướng dẫn plugin mới: báo chưa có, không lỗi', $stub_messages.last.to_s.include?('chưa có'), $stub_messages.last.inspect
$stub_messages.clear
CENTER.open_guide('../main')
check 'mở hướng dẫn với id có ../ bị chặn', $stub_messages.last.to_s.include?('Không tìm thấy hướng dẫn'), $stub_messages.last.inspect

# ---------- 7. Cài đặt: gói của plugin mới chỉ được ghi đúng đường dẫn ----------
def build_zip(files)
  body = ''.b
  central = ''.b
  files.each do |name, data|
    n = name.b
    d = data.b
    crc = Zlib.crc32(d)
    central << [0x02014b50, 20, 20, 0, 0, 0, 0, crc, d.bytesize, d.bytesize, n.bytesize, 0, 0, 0, 0, 0, body.bytesize].pack('VvvvvvvVVVvvvvvVV') + n
    body << [0x04034b50, 20, 0, 0, 0, 0, crc, d.bytesize, d.bytesize, n.bytesize, 0].pack('VvvvvvVVVvv') + n + d
  end
  body + central + [0x06054b50, 0, 0, files.size, files.size, central.bytesize, body.bytesize, 0].pack('VvvvvVVv')
end

Dir.mktmpdir('vgd-center-test-') do |tmp|
  plugins = File.join(tmp, 'Plugins')
  FileUtils.mkdir_p(plugins)
  $stub_plugins_dir = plugins
  item = validate(product('demo_tool'))[0]

  good = File.join(tmp, 'good.rbz')
  File.binwrite(good, build_zip('VGD_DemoTool.rb' => '# loader', 'VGD_DemoTool/main.rb' => '# main'))
  $stub_installs.clear
  CENTER.install_verified_package(good, item)
  check 'gói đúng cấu trúc được cài', $stub_installs == [good]
  check 'phiên bản đã cài được ghi nhận', CENTER.installed_version_for('demo_tool') == '1.0.0-beta.1'

  [
    ['ghi đè plugin khác (VGD_Dim/)', { 'VGD_DemoTool.rb' => '#', 'VGD_Dim/evil.rb' => '#' }, 'không được phép'],
    ['ghi loader của plugin khác', { 'VGD_DemoTool.rb' => '#', 'vgd_dim.rb' => '#' }, 'không được phép'],
    ['ghi file lạ ở gốc Plugins', { 'VGD_DemoTool.rb' => '#', 'extra.rb' => '#' }, 'không được phép'],
    ['thiếu loader', { 'VGD_DemoTool/main.rb' => '#' }, 'loader'],
    ['đường dẫn thoát khỏi Plugins', { 'VGD_DemoTool.rb' => '#', '../x.rb' => '#' }, 'không an toàn']
  ].each do |name, files, expected|
    bad = File.join(tmp, "bad-#{name.hash.abs}.rbz")
    File.binwrite(bad, build_zip(files))
    $stub_installs.clear
    message = begin
      CENTER.install_verified_package(bad, item)
      nil
    rescue StandardError => error
      error.message
    end
    check "gói bị từ chối: #{name}", message.to_s.include?(expected) && $stub_installs.empty?, message.inspect
  end

  # ---------- 8. Gỡ cài đặt plugin mới ----------
  File.write(File.join(plugins, 'VGD_DemoTool.rb'), '# loader')
  FileUtils.mkdir_p(File.join(plugins, 'VGD_DemoTool'))
  File.write(File.join(plugins, 'VGD_DemoTool', 'main.rb'), '# main')
  FileUtils.mkdir_p(File.join(plugins, 'VGD_Dim'))
  File.write(File.join(plugins, 'vgd_dim.rb'), '# dim')
  File.write(File.join(plugins, 'VGD_Dim', 'main.rb'), '# dim main')
  with_note = validate(product('demo_tool', 'uninstall_note' => 'Sao lưu dữ liệu trước khi gỡ.'))[0]
  CENTER.instance_variable_set(:@catalog, 'schema_version' => 1, 'channel' => 'latest', 'products' => [with_note])
  $stub_messages.clear
  $stub_answer = IDYES
  CENTER.uninstall_plugin('demo_tool')
  check 'hộp thoại gỡ hiện uninstall_note', $stub_messages.first.to_s.include?('Sao lưu dữ liệu trước khi gỡ.'), $stub_messages.first.inspect
  check 'gỡ plugin mới: xóa loader và thư mục của nó',
        !File.exist?(File.join(plugins, 'VGD_DemoTool.rb')) && !File.exist?(File.join(plugins, 'VGD_DemoTool'))
  check 'gỡ plugin mới: không đụng plugin khác',
        File.file?(File.join(plugins, 'vgd_dim.rb')) && File.file?(File.join(plugins, 'VGD_Dim', 'main.rb'))

  # Plugin Manager: cảnh báo plugin đang tắt vẫn giữ nguyên
  disabled = File.join(plugins, 'VGD_PluginManager', 'data', 'disabled')
  FileUtils.mkdir_p(disabled)
  check 'Plugin Manager: thư mục disabled rỗng thì không cảnh báo', CENTER.uninstall_warning('plugin_manager', plugins).empty?
  FileUtils.mkdir_p(File.join(disabled, 'PluginA'))
  check 'Plugin Manager: có plugin đang tắt thì cảnh báo', CENTER.uninstall_warning('plugin_manager', plugins).include?('CẢNH BÁO')
  check 'plugin khác không bị cảnh báo của Plugin Manager', CENTER.uninstall_warning('dim', plugins).empty?
end

total = PASSED.length + FAILED.length
puts "\nĐạt: #{PASSED.length}   Không đạt: #{FAILED.length}   (tổng #{total})"
exit(FAILED.empty? ? 0 : 1)
