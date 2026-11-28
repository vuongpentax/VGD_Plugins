# Cửa sổ Đổi tên độc lập: core/rename_list.rb (kiểm tra tên gửi lên, mẫu tên trên máy) và ui/rename_window.rb (theo vùng chọn, áp dụng một bước
# hoàn tác, ẩn món đã đổi tên). Chạy bằng Ruby thường với SketchUp giả lập: ruby dev/test_rename_window.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_rename') # không ghi vào thư mục dữ liệu thật khi chạy riêng
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Sketchup
  class SelectionObserver; end
  class AppObserver; end
  class Group; end
  class ComponentInstance; end
  class Selection < Array
    attr_reader :observers
    def initialize(*); super; @observers = []; end
    def add_observer(o); @observers << o; end
    def remove_observer(o); @observers.delete(o); end
    def remove(list); list.each { |e| delete(e) }; changed; end
    def changed; @observers.each { |o| o.onSelectionBulkChange(self) }; end
  end
  class Model
    attr_accessor :selection, :active_path
    def initialize; @selection = Selection.new; @active_path = nil; end
  end
  @observers = []
  class << self
    attr_accessor :active_model
    attr_reader :observers
    def add_observer(o); @observers << o; end
    def remove_observer(o); @observers.delete(o); end
  end
end
Definition = Struct.new(:name, :entityID)
class FakeEntity < Sketchup::Group
  attr_accessor :name, :hidden, :locked, :valid
  attr_reader :entityID, :definition
  def initialize(id, name, definition, locked: false); @entityID = id; @name = name; @definition = definition; @locked = locked; @valid = true; @hidden = false; end
  def locked?; @locked; end
  def valid?; @valid; end
end
module UI
  @timers = {}
  @timer_id = 0
  def self.start_timer(_time, _repeat, &block); @timer_id += 1; @timers[@timer_id] = block; @timer_id; end
  def self.stop_timer(id); @timers.delete(id); end
  def self.run_timers; list = @timers.values; @timers.clear; list.each(&:call); end
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :options, :scripts, :file
    def initialize(options); @options = options; @callbacks = {}; @scripts = []; @visible = false; end
    def set_file(path); @file = path; end
    def add_action_callback(name, &block); @callbacks[name] = block; end
    def set_on_closed(&block); @on_closed = block; end
    def visible?; @visible; end
    def show; @visible = true; end
    def bring_to_front; @visible = true; end
    def close; @visible = false; @on_closed.call; end
    def execute_script(script); @scripts << script; end
    def trigger(name, *args); @callbacks.fetch(name).call(nil, *args); end
  end
end
module VGD
  module BIM
    VERSION = '9.9.9-test'.freeze
    ROOT = ::ROOT
    $logs = []
    $names_changed = 0
    $transactions = []
    def self.log(message); $logs << message; end
    def self.names_changed; $names_changed += 1; end
    module Settings; def self.read; {'language' => 'vi'}; end; end
    module Data
      def self.supported?(e); e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance); end
      def self.transaction(_model, name); $transactions << name; yield; end
    end
    module UI
      class SelectionObserver < Sketchup::SelectionObserver
        def initialize(panel); @panel = panel; end
        def onSelectionBulkChange(_selection); @panel.selection_changed; end
      end
    end
  end
end
%w[core/storage core/rename core/rename_list ui/rename_window].each { |file| require File.join(ROOT, file) }
L = VGD::BIM::RenameList

# ---- Kiểm tra tên gửi lên ----
known = {1 => :a, 2 => :b}
ok('đổi tên hợp lệ: cắt khoảng trắng hai đầu', L.changes!({'changes' => [{'id' => 1, 'name' => '  Tủ bếp 01 '}]}, known) == [[1, 'Tủ bếp 01']])
bad = lambda do |payload, text|
  L.changes!(payload, known)
  false
rescue ArgumentError => error
  error.message.include?(text)
end
ok('không phải danh sách: báo dữ liệu sai', bad.call({'changes' => 'x'}, 'không hợp lệ'))
ok('danh sách rỗng: báo không có món cần đổi', bad.call({'changes' => []}, 'Không có món'))
ok('mã món không có trong danh sách: báo danh sách cũ', bad.call({'changes' => [{'id' => 9, 'name' => 'A'}]}, 'Danh sách đã cũ'))
ok('mã món là chữ: báo dữ liệu sai', bad.call({'changes' => [{'id' => '1', 'name' => 'A'}]}, 'không hợp lệ'))
ok('một món gửi hai lần: báo dữ liệu sai', bad.call({'changes' => [{'id' => 1, 'name' => 'A'}, {'id' => 1, 'name' => 'B'}]}, 'không hợp lệ'))
ok('tên trống: báo lỗi', bad.call({'changes' => [{'id' => 1, 'name' => '   '}]}, 'không được để trống'))
ok('tên dài quá 200 ký tự: báo lỗi', bad.call({'changes' => [{'id' => 1, 'name' => 'a' * 201}]}, 'dài quá 200'))
ok('tên có ký tự điều khiển: báo lỗi', bad.call({'changes' => [{'id' => 1, 'name' => "A\tB"}]}, 'ký tự điều khiển'))
ok('quá số món tối đa: báo dữ liệu sai', bad.call({'changes' => Array.new(L::MAX_ITEMS + 1) { |i| {'id' => i, 'name' => 'A'} }}, 'không hợp lệ'))

# ---- Mẫu tên trên máy ----
cleaned = L.clean_templates({'prefix' => ['PK', ' PK ', '', 5, "a\nb", 'x' * 101], 'name' => 'không phải danh sách', 'other' => ['bỏ']})
ok('làm sạch mẫu: bỏ trùng, trống, không phải chữ, có xuống dòng, quá dài; thiếu cột thì rỗng', cleaned == {'prefix' => ['PK'], 'name' => [], 'suffix' => []})
ok('chưa có file mẫu: ba cột rỗng', L.templates == {'prefix' => [], 'name' => [], 'suffix' => []})
L.save_templates({'prefix' => ['PK'], 'name' => ['Tủ bếp trên', 'Bàn ăn'], 'suffix' => ['gỗ sồi']})
ok('lưu rồi đọc lại mẫu tên có dấu tiếng Việt', L.templates == {'prefix' => ['PK'], 'name' => ['Tủ bếp trên', 'Bàn ăn'], 'suffix' => ['gỗ sồi']})
ok('mẫu tên lưu ở thư mục dữ liệu trên máy (dùng chung mọi file)', File.file?(File.join(ENV['VGD_BIM_DATA_DIR'], 'rename_templates.json')))

# ---- Cửa sổ ----
def events(dialog, name)
  dialog.scripts.select { |s| s.start_with?("window.VGD.receive(#{JSON.generate(name)},") }.map { |s| JSON.parse(s[/, (.*)\)\z/m, 1]) }
end
cabinet = Definition.new('Tủ bếp', 100)
door = Definition.new('Cửa', 200)
a = FakeEntity.new(1, '', cabinet)
b = FakeEntity.new(2, '', cabinet)
c = FakeEntity.new(3, 'Cửa D1', door, locked: true)
model = Sketchup::Model.new
model.selection.replace([a, b, c, :face])
Sketchup.active_model = model
window = VGD::BIM::UI::RenameWindow.new
dialog = window.instance_variable_get(:@dialog)
ok('cửa sổ riêng: tiêu đề, file rename.html, có nhớ vị trí riêng', dialog.options[:dialog_title] == 'VGD BIM · Đổi tên' && dialog.file.end_with?('html/rename.html') && dialog.options[:preferences_key] == 'VGD_BIM_Rename')
window.show
dialog.trigger('ready')
config = events(dialog, 'config').last
ok('ready: gửi ngôn ngữ và mẫu tên đã lưu', config['language'] == 'vi' && config['templates']['name'] == ['Tủ bếp trên', 'Bàn ăn'])
items = events(dialog, 'items').last
ok('ready: gửi các group / component đang chọn (bỏ mặt), kèm định nghĩa và trạng thái khóa',
   items['total'] == 3 && items['items'].map { |i| [i['id'], i['definition'], i['def_id'], i['locked']] } == [[1, 'Tủ bếp', 100, false], [2, 'Tủ bếp', 100, false], [3, 'Cửa', 200, true]])
ok('theo dõi vùng chọn và đổi file', model.selection.observers.size == 1 && Sketchup.observers.size == 1)
model.selection.replace([b])
model.selection.changed
before = events(dialog, 'items').size
UI.run_timers
ok('chọn lại trong SketchUp: danh sách tự cập nhật', events(dialog, 'items').size == before + 1 && events(dialog, 'items').last['items'].map { |i| i['id'] } == [2])
model.selection.replace([a, b, c])
model.selection.changed
UI.run_timers
model.active_path = [FakeEntity.new(9, 'Nhóm cha', cabinet, locked: true)]
model.selection.changed
UI.run_timers
ok('đang mở trong group bị khóa: mọi món báo khóa', events(dialog, 'items').last['items'].all? { |i| i['locked'] })
model.active_path = nil
model.selection.changed
UI.run_timers

# Áp dụng
dialog.trigger('rename_apply', JSON.generate({'changes' => [{'id' => 3, 'name' => 'Cửa mới'}], 'hide' => false}))
ok('món bị khóa: báo lỗi, không đổi tên', events(dialog, 'message').last['error'].include?('bị khóa') && c.name == 'Cửa D1' && $transactions.empty?)
dialog.trigger('rename_apply', JSON.generate({'changes' => [{'id' => 77, 'name' => 'X'}]}))
ok('mã món lạ: báo danh sách cũ, không đổi gì', events(dialog, 'message').last['error'].include?('Danh sách đã cũ') && $transactions.empty?)
b.valid = false
dialog.trigger('rename_apply', JSON.generate({'changes' => [{'id' => 1, 'name' => 'A'}, {'id' => 2, 'name' => 'B'}]}))
ok('món đã bị xóa: báo lỗi, không đổi món còn lại', events(dialog, 'message').last['error'].include?('không còn trong model') && a.name == '' && $transactions.empty?)
b.valid = true
dialog.trigger('rename_apply', JSON.generate({'changes' => [{'id' => 1, 'name' => 'Tủ bếp trên 01'}, {'id' => 2, 'name' => 'Tủ bếp trên 02'}], 'hide' => false}))
ok('áp dụng: đổi tên các món, một bước hoàn tác', a.name == 'Tủ bếp trên 01' && b.name == 'Tủ bếp trên 02' && $transactions == ['VGD_BIM · Đổi tên'])
ok('không bật Ẩn: món vẫn hiện, vẫn được chọn', !a.hidden && model.selection.include?(a))
ok('áp dụng xong: gửi lại danh sách với tên mới, báo kết quả, Bảng khối lượng đọc lại',
   events(dialog, 'items').last['items'].first['name'] == 'Tủ bếp trên 01' && events(dialog, 'applied').last['text'].start_with?('Đã đổi tên 2 món.') && $names_changed == 1)
dialog.trigger('rename_apply', JSON.generate({'changes' => [{'id' => 1, 'name' => 'Tủ A'}], 'hide' => true}))
UI.run_timers
ok('bật Ẩn: món vừa đổi tên bị ẩn và rời vùng chọn, danh sách còn món chưa đổi',
   a.name == 'Tủ A' && a.hidden && !model.selection.include?(a) && events(dialog, 'items').last['items'].map { |i| i['id'] } == [2, 3] && $transactions.size == 2)
ok('bật Ẩn: thông báo cách hiện lại', events(dialog, 'applied').last['text'].include?('Edit > Unhide'))
# Mẫu tên lưu từ giao diện
dialog.trigger('rename_templates', JSON.generate({'prefix' => ['T1'], 'name' => ['Kệ'], 'suffix' => [' gỗ ', 'gỗ']}))
ok('lưu mẫu tên từ giao diện: làm sạch, ghi file, gửi lại', L.templates == {'prefix' => ['T1'], 'name' => ['Kệ'], 'suffix' => ['gỗ']} && events(dialog, 'templates').last['suffix'] == ['gỗ'])
# Sang file khác
other = Sketchup::Model.new
other.selection.replace([FakeEntity.new(50, 'Ghế', Definition.new('Ghế', 300))])
Sketchup.active_model = other
dialog.trigger('rename_apply', JSON.generate({'changes' => [{'id' => 2, 'name' => 'X'}]}))
ok('file khác đang mở: không ghi vào file mới, báo chọn lại', events(dialog, 'message').last['error'].include?('file SketchUp khác') && $transactions.size == 2)
Sketchup.observers.first.onOpenModel(other)
ok('mở file khác: gắn vào vùng chọn của file mới và gửi danh sách mới',
   model.selection.observers.empty? && other.selection.observers.size == 1 && events(dialog, 'items').last['items'].map { |i| i['id'] } == [50])
# Đóng cửa sổ
dialog.close
ok('đóng cửa sổ: bỏ mọi observer', other.selection.observers.empty? && Sketchup.observers.empty? && window.closed?)
count = dialog.scripts.size
window.selection_changed
UI.run_timers
ok('đã đóng: không gửi gì thêm', dialog.scripts.size == count)

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
