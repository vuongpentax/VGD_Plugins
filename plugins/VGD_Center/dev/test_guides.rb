# encoding: UTF-8
# Test VGD Center (chạy từ plugins/VGD_Center: ruby dev/test_guides.rb).
# Hướng dẫn tải từ GitHub: Center lấy trang mới nhất khi bấm Hướng dẫn, kiểm tra nội dung, lưu vào thư mục guides
# và mở; lỗi mạng hoặc trang không hợp lệ thì dùng bản đang có. Hướng dẫn mới không cần phát hành Center mới.
require 'json'
require 'tmpdir'
require 'fileutils'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))
require 'sketchup.rb'

# Yêu cầu HTTP giả: ghi lại URL, trả về phản hồi do test đặt trước
module Sketchup
  module Http
    class Request
      class << self
        attr_accessor :responses, :urls, :start_result
      end
      Response = Struct.new(:status_code, :body)
      def initialize(url); @url = url; (self.class.urls ||= []) << url; end
      def start(&block)
        return false if self.class.start_result == false
        reply = (self.class.responses ||= {})[@url]
        block.call(self, reply) unless reply == :never
        true
      end
    end
  end
end
# Cửa sổ giả
module UI
  class HtmlDialog
    class << self; attr_accessor :opened, :urls, :callbacks; end
    def initialize(**options); @options = options; end
    def set_file(path); (self.class.opened ||= []) << path; end
    def set_url(url); (self.class.urls ||= []) << url; end
    def add_action_callback(name, &_block); (self.class.callbacks ||= []) << name; end
    def set_on_closed(&_block); end
    def visible?; false; end
    def bring_to_front; end
    def center; end
    def show; end
    STYLE_DIALOG = 1 unless const_defined?(:STYLE_DIALOG)
  end
  @timers = []
  def self.timers; @timers; end
  def self.start_timer(seconds, _repeat, &block); @timers << [seconds, block]; 1; end
end

require_relative '../vgd_center/main'
CENTER = VGD::Center
GUIDES = File.expand_path('../vgd_center/guides', __dir__)
SHARED = File.expand_path('../../../shared/vgd-center/guides', __dir__)

def check(label, cond, detail = nil)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}#{detail && !cond ? " — #{detail}" : ''}"
  $fail = true unless cond
end

GOOD = <<~HTML
  <!doctype html><html lang="vi"><head><meta charset="utf-8"><title>Hướng dẫn · VGD Thử</title><link rel="stylesheet" href="../vgd-theme/vgd-theme.css"><style>body{margin:0}</style></head><body><header><img src="../icon.svg" alt="VGD"><button onclick="print()">In</button></header><main><h1>VGD Thử</h1><p>Nội dung hướng dẫn đủ dài để qua kiểm tra kích thước tối thiểu của trang.</p><nav><a href="center.html">Center</a><a href="#top">Đầu trang</a></nav></main></body></html>
HTML
valid = ->(html) { CENTER.valid_guide_html?(html) }

# ---------- A. Kiểm tra nội dung trang ----------
check 'trang mẫu hợp lệ', valid.call(GOOD)
bad = {
  'thiếu doctype' => GOOD.sub('<!doctype html>', ''),
  'thiếu thẻ đóng html' => GOOD.sub('</html>', ''),
  'có <script>' => GOOD.sub('<main>', '<main><script>alert(1)</script>'),
  'có <script src>' => GOOD.sub('<main>', '<main><script src="x.js"></script>'),
  'có iframe' => GOOD.sub('<main>', '<main><iframe src="x.html"></iframe>'),
  'có object/embed' => GOOD.sub('<main>', '<main><embed src="x.swf">'),
  'có form' => GOOD.sub('<main>', '<main><form action="x"></form>'),
  'có thẻ base' => GOOD.sub('<head>', '<head><base href="https://evil.example/">'),
  'có meta refresh' => GOOD.sub('<head>', '<head><meta http-equiv="refresh" content="0;url=https://evil.example">'),
  'ảnh từ web' => GOOD.sub('../icon.svg', 'https://evil.example/i.svg'),
  'ảnh // (cùng giao thức)' => GOOD.sub('../icon.svg', '//evil.example/i.svg'),
  'ảnh data:' => GOOD.sub('../icon.svg', 'data:image/svg+xml;base64,AAAA'),
  'css từ web' => GOOD.sub('../vgd-theme/vgd-theme.css', 'https://evil.example/a.css'),
  'url() từ web' => GOOD.sub('body{margin:0}', 'body{background:url(https://evil.example/a.png)}'),
  '@import' => GOOD.sub('body{margin:0}', '@import "a.css";'),
  'liên kết ra web' => GOOD.sub('center.html', 'https://evil.example/'),
  'liên kết javascript:' => GOOD.sub('center.html', 'javascript:alert(1)'),
  'quá nhỏ' => '<!doctype html><html></html>',
  'quá lớn' => GOOD.sub('</main>', ('x' * (CENTER::MAX_GUIDE_BYTES + 10)) + '</main>'),
  'không phải chuỗi' => nil
}
bad.each { |label, html| check "từ chối trang: #{label}", !valid.call(html) }
check 'từ chối chuỗi không phải UTF-8', !valid.call(GOOD.b + "\xFF".b)
check 'nhận cả chuỗi nhị phân UTF-8 (phản hồi mạng)', valid.call(GOOD.dup.force_encoding(Encoding::BINARY))

# ---------- B. Mọi trang hướng dẫn trong repo hợp lệ và đồng bộ ----------
shared_files = Dir.children(SHARED).select { |f| f.end_with?('.html') }.sort
plugin_files = Dir.children(GUIDES).select { |f| f.end_with?('.html') }.sort
check 'shared/vgd-center/guides và VGD_Center/guides có cùng danh sách trang', shared_files == plugin_files, "#{shared_files} vs #{plugin_files}"
check 'mỗi trang trong shared giống hệt bản trong gói Center', shared_files.all? { |f| File.binread(File.join(SHARED, f)) == File.binread(File.join(GUIDES, f)) }
check 'mọi trang hướng dẫn trong repo qua kiểm tra nội dung', shared_files.all? { |f| valid.call(File.binread(File.join(SHARED, f))) }, shared_files.reject { |f| valid.call(File.binread(File.join(SHARED, f))) }.inspect
check 'liên kết giữa các trang đều tồn tại', shared_files.all? { |f| File.read(File.join(SHARED, f), encoding: 'UTF-8').scan(/href="([^"#]+\.html)"/).flatten.all? { |t| shared_files.include?(t) } }

# ---------- C. Mở hướng dẫn: tải, lưu, dự phòng ----------
# Dùng bản sao thư mục guides để không đụng file thật
work = Dir.mktmpdir('guides_work')
FileUtils.cp_r(Dir.glob(File.join(GUIDES, '*')), work)
CENTER.define_singleton_method(:guide_path) { |id| id.to_s.match?(CENTER::PLUGIN_ID_PATTERN) ? File.join(work, "#{id}.html") : nil }
HTTP = Sketchup::Http::Request
URL = ->(id) { "https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/main/shared/vgd-center/guides/#{id}.html" }
reset = lambda do
  HTTP.responses = {}; HTTP.urls = []; HTTP.start_result = nil
  UI::HtmlDialog.opened = []; UI::HtmlDialog.urls = []; UI::HtmlDialog.callbacks = []; $stub_messages.clear; UI.timers.clear
  CENTER.instance_variable_set(:@guide_dialogs, {}); CENTER.instance_variable_set(:@guide_requests, {})
end
ok = ->(body) { Sketchup::Http::Request::Response.new(200, body) }

reset.call
HTTP.responses[URL.call('dim')] = ok.call(GOOD)
CENTER.open_guide('dim')
check 'mở hướng dẫn: gọi đúng địa chỉ raw trong kho VGD', HTTP.urls == [URL.call('dim')], HTTP.urls.inspect
check 'trang tải về hợp lệ được lưu vào thư mục guides', File.binread(File.join(work, 'dim.html')) == GOOD.b
check 'rồi mở đúng file đó', UI::HtmlDialog.opened == [File.join(work, 'dim.html')]
check 'không để lại file tạm', Dir.glob(File.join(work, '*.tmp')).empty?

reset.call
before = File.binread(File.join(work, 'library.html'))
HTTP.responses[URL.call('library')] = ok.call(GOOD.sub('<main>', '<main><script>alert(1)</script>'))
CENTER.open_guide('library')
check 'trang không hợp lệ: không ghi đè, vẫn mở bản đang có', File.binread(File.join(work, 'library.html')) == before && UI::HtmlDialog.opened == [File.join(work, 'library.html')]

reset.call
before = File.binread(File.join(work, 'scenes.html'))
HTTP.responses[URL.call('scenes')] = Sketchup::Http::Request::Response.new(404, 'Not Found')
CENTER.open_guide('scenes')
check 'tải lỗi 404: dùng bản đang có', File.binread(File.join(work, 'scenes.html')) == before && UI::HtmlDialog.opened == [File.join(work, 'scenes.html')]

reset.call
HTTP.responses[URL.call('reference')] = nil
CENTER.open_guide('reference')
check 'không có phản hồi (mất mạng): dùng bản đang có', UI::HtmlDialog.opened == [File.join(work, 'reference.html')]

reset.call
HTTP.start_result = false
CENTER.open_guide('bim')
check 'không bắt đầu được yêu cầu: dùng bản đang có', UI::HtmlDialog.opened == [File.join(work, 'bim.html')]

reset.call
HTTP.responses[URL.call('plugin_moi')] = ok.call(GOOD)
CENTER.open_guide('plugin_moi')
check 'plugin mới (chưa có trong gói Center): tải về, lưu và mở', File.file?(File.join(work, 'plugin_moi.html')) && UI::HtmlDialog.opened == [File.join(work, 'plugin_moi.html')]

reset.call
HTTP.responses[URL.call('khong_co')] = Sketchup::Http::Request::Response.new(404, '')
CENTER.open_guide('khong_co')
check 'không có ở cả hai nơi: báo chưa có, không mở cửa sổ', UI::HtmlDialog.opened.empty? && $stub_messages.last.to_s.include?('chưa có'), $stub_messages.inspect

reset.call
HTTP.responses[URL.call('cabinet')] = :never
CENTER.open_guide('cabinet')
check 'mạng chậm: chưa mở ngay, đợi phản hồi hoặc hết giờ', UI::HtmlDialog.opened.empty? && UI.timers.size == 1
CENTER.open_guide('cabinet')
check 'bấm lần nữa khi đang tải: không gửi yêu cầu thứ hai', HTTP.urls.size == 1
UI.timers.first[1].call
check 'hết giờ chờ: mở bản đang có', UI::HtmlDialog.opened == [File.join(work, 'cabinet.html')]
UI.timers.first[1].call
check 'hết giờ gọi lại không mở lần hai', UI::HtmlDialog.opened.size == 1

reset.call
CENTER.open_guide('../main')
CENTER.open_guide('Dim')
CENTER.open_guide('')
check 'id lạ (../, chữ hoa, rỗng): chặn, không gửi yêu cầu', HTTP.urls.empty? && UI::HtmlDialog.opened.empty?

# ---------- D. Cờ guide trong danh sách ----------
# Plugin chưa có trang trong thư mục guides vẫn hiện nút nếu catalog khai báo "guide": true
real = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'shared', 'vgd-center', 'catalog.json'), encoding: 'UTF-8'))
dim = real['products'].find { |item| item['id'] == 'dim' }
extra = lambda do |id, flag|
  name = id.split('_').map(&:capitalize).join
  { 'id' => id, 'name' => "VGD #{name}", 'extension_name' => "VGD #{name}", 'version' => '1.0.0', 'release_channel' => 'stable',
    'description' => 'Thử', 'icon' => 'dim', 'minimum_sketchup' => '22.0.0',
    'download' => { 'filename' => "VGD_#{name}_1.0.0.rbz", 'size' => 1000, 'sha256' => 'a' * 64,
                    'url' => "https://github.com/vuongpentax/VGD_Plugins/releases/download/vgd-#{id}-v1.0.0/VGD_#{name}_1.0.0.rbz" },
    'allowed_paths' => ["VGD_#{name}.rb", "VGD_#{name}/"] }.merge(flag.nil? ? {} : { 'guide' => flag })
end
catalog = CENTER.send(:validate_catalog, 'schema_version' => 1, 'channel' => 'latest',
                                         'products' => [dim, extra.call('thu_a', true), extra.call('thu_b', nil), extra.call('thu_c', 'true')])
CENTER.instance_variable_set(:@catalog, catalog)
flags = CENTER.current_products.each_with_object({}) { |item, memo| memo[item[:id]] = item[:guide] }
check 'plugin có trang trong gói: có nút', flags['dim'] == true, flags.inspect
check 'plugin mới khai báo guide: true: có nút dù chưa có trang trong gói', flags['thu_a'] == true, flags.inspect
check 'plugin mới không khai báo guide: ẩn nút', flags['thu_b'] == false, flags.inspect
check 'guide khác true (chuỗi "true"): ẩn nút', flags['thu_c'] == false, flags.inspect

# ---------- E. Hướng dẫn tương tác trên GitHub Pages (guide_url) ----------
# Plugin khai báo "guide_url" trong catalog (chỉ nhận đúng tên miền và thư mục guides/<id>/); Center kiểm tra trang còn tải
# được rồi mở bằng set_url trong cửa sổ không có callback Ruby. Lỗi, mạng chậm hoặc không có mạng: dùng trang chữ như cũ.
WEB = ->(id) { "https://vuongpentax.github.io/VGD_Plugins/guides/#{id}/" }
web_catalog = CENTER.send(:validate_catalog, 'schema_version' => 1, 'channel' => 'latest', 'products' => [
  dim.merge('guide_url' => WEB.call('dim')),
  extra.call('thu_web', true).merge('guide_url' => WEB.call('thu_web')),
  extra.call('thu_sai', true).merge('guide_url' => 'http://vuongpentax.github.io/VGD_Plugins/guides/thu_sai/'),
  extra.call('thu_chu', true).merge('guide_url' => WEB.call('khac')),
  real['products'].find { |item| item['id'] == 'library' }
])
CENTER.instance_variable_set(:@catalog, web_catalog)
check 'guide_url hợp lệ của plugin được nhận', CENTER.web_guide_url('dim') == WEB.call('dim')
check 'plugin mới khai báo guide_url hợp lệ được nhận', CENTER.web_guide_url('thu_web') == WEB.call('thu_web')
check 'Center có địa chỉ tương tác riêng', CENTER.web_guide_url('center') == WEB.call('center')
check 'plugin không khai báo guide_url: không có', CENTER.web_guide_url('library').nil?
check 'guide_url dùng http: bỏ', CENTER.web_guide_url('thu_sai').nil?
check 'guide_url trỏ sang thư mục của plugin khác: bỏ', CENTER.web_guide_url('thu_chu').nil?
bad_urls = {
  'tên miền khác' => 'https://evil.example/VGD_Plugins/guides/dim/',
  'tên miền giả giống (đuôi)' => 'https://vuongpentax.github.io.evil.example/VGD_Plugins/guides/dim/',
  'userinfo đánh lạc hướng' => 'https://vuongpentax.github.io@evil.example/VGD_Plugins/guides/dim/',
  'đường dẫn lên thư mục cha' => 'https://vuongpentax.github.io/VGD_Plugins/guides/../x/',
  'id chữ hoa' => 'https://vuongpentax.github.io/VGD_Plugins/guides/Dim/',
  'thêm đường dẫn sau id' => 'https://vuongpentax.github.io/VGD_Plugins/guides/dim/x.html',
  'tham số lạ' => 'https://vuongpentax.github.io/VGD_Plugins/guides/dim/?url=https://evil.example',
  'có fragment' => 'https://vuongpentax.github.io/VGD_Plugins/guides/dim/#x',
  'xuống dòng chèn thêm' => "https://vuongpentax.github.io/VGD_Plugins/guides/dim/\nhttps://evil.example",
  'không phải chuỗi' => 42
}
bad_urls.each do |label, url|
  CENTER.instance_variable_set(:@catalog, CENTER.send(:validate_catalog, 'schema_version' => 1, 'channel' => 'latest', 'products' => [dim.merge('guide_url' => url)]))
  check "từ chối guide_url: #{label}", CENTER.web_guide_url('dim').nil?
end
CENTER.instance_variable_set(:@catalog, CENTER.send(:validate_catalog, 'schema_version' => 1, 'channel' => 'latest', 'products' => [dim.merge('guide_url' => WEB.call('dim') + '?bai=3')]))
check 'nhận guide_url có ?bai=<số>', CENTER.web_guide_url('dim') == WEB.call('dim') + '?bai=3'
CENTER.instance_variable_set(:@catalog, web_catalog)

# Luồng mở
reset.call
HTTP.responses[WEB.call('dim')] = ok.call('<html></html>')
CENTER.open_guide('dim')
check 'trang tương tác còn tải được: mở bằng set_url', UI::HtmlDialog.urls == [WEB.call('dim')] && UI::HtmlDialog.opened.empty?, UI::HtmlDialog.urls.inspect
check 'chỉ gọi địa chỉ Pages, không tải trang chữ', HTTP.urls == [WEB.call('dim')], HTTP.urls.inspect
check 'cửa sổ trang tương tác không đăng ký callback Ruby', UI::HtmlDialog.callbacks.empty?, UI::HtmlDialog.callbacks.inspect

reset.call
HTTP.responses[WEB.call('dim')] = Sketchup::Http::Request::Response.new(404, '')
HTTP.responses[URL.call('dim')] = ok.call(GOOD)
CENTER.open_guide('dim')
check 'trang tương tác lỗi 404: quay về trang chữ', UI::HtmlDialog.urls.empty? && UI::HtmlDialog.opened == [File.join(work, 'dim.html')] && HTTP.urls == [WEB.call('dim'), URL.call('dim')], HTTP.urls.inspect

reset.call
HTTP.responses[WEB.call('dim')] = nil
CENTER.open_guide('dim')
check 'không có phản hồi (mất mạng): quay về trang chữ', UI::HtmlDialog.urls.empty? && UI::HtmlDialog.opened == [File.join(work, 'dim.html')]

reset.call
HTTP.start_result = false
CENTER.open_guide('dim')
check 'không bắt đầu được yêu cầu: quay về trang chữ', UI::HtmlDialog.urls.empty? && UI::HtmlDialog.opened == [File.join(work, 'dim.html')]

reset.call
HTTP.responses[WEB.call('dim')] = :never
CENTER.open_guide('dim')
check 'mạng chậm: chưa mở ngay, chờ phản hồi hoặc hết giờ', UI::HtmlDialog.urls.empty? && UI::HtmlDialog.opened.empty? && UI.timers.size == 1
CENTER.open_guide('dim')
check 'bấm lần nữa khi đang kiểm tra: không gửi yêu cầu thứ hai', HTTP.urls == [WEB.call('dim')], HTTP.urls.inspect
UI.timers.first[1].call
check 'hết giờ chờ: quay về trang chữ', UI::HtmlDialog.urls.empty? && UI::HtmlDialog.opened == [File.join(work, 'dim.html')]
UI.timers.first[1].call
check 'hết giờ gọi lại không mở lần hai', UI::HtmlDialog.opened.size == 1 && UI::HtmlDialog.urls.empty?

reset.call
HTTP.responses[WEB.call('thu_web')] = ok.call('<html></html>')
CENTER.open_guide('thu_web')
check 'plugin mới có guide_url: mở trang tương tác dù chưa có trang chữ nào', UI::HtmlDialog.urls == [WEB.call('thu_web')]

reset.call
HTTP.responses[URL.call('thu_sai')] = ok.call(GOOD)
CENTER.open_guide('thu_sai')
check 'guide_url sai: bỏ qua, chỉ dùng trang chữ', HTTP.urls == [URL.call('thu_sai')] && UI::HtmlDialog.urls.empty?, HTTP.urls.inspect

reset.call
HTTP.responses[URL.call('library')] = ok.call(GOOD)
CENTER.open_guide('library')
check 'plugin không có guide_url: hành vi cũ (trang chữ)', HTTP.urls == [URL.call('library')] && UI::HtmlDialog.urls.empty?

reset.call
HTTP.responses[WEB.call('center')] = ok.call('<html></html>')
CENTER.open_guide('center')
check 'nút Hướng dẫn của Center: mở trang tương tác của Center', UI::HtmlDialog.urls == [WEB.call('center')]
CENTER.instance_variable_set(:@catalog, nil)
FileUtils.rm_rf(work)

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
