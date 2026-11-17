# Test cửa sổ Lưới trục (panel.rb): callback của giao diện, xem trước do Ruby tính, vẽ / xóa lưới, kiểm tra lại dữ liệu từ giao diện.
# HtmlDialog giả lập; phần HTML / JS kiểm ở test_ui.cjs. Chạy: ruby dev/test_panel.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
require_relative 'fake_sketchup'
module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    attr_reader :callbacks, :scripts, :file
    def initialize(**opts); @opts = opts; @callbacks = {}; @scripts = []; @visible = false; end
    def set_file(f); @file = f; end
    def add_action_callback(name, &b); @callbacks[name] = b; end
    def execute_script(js); @scripts << js; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; @brought = true; end
    def close; @visible = false; end
  end
  def self.messagebox(text, *); ($boxes ||= []) << text; $answer || IDYES; end
end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[core/schema core/grid core/axis_symbol core/column_types core/levels core/column_plan core/state core/preview model_store tag_store grid_tag grid_builder column_builder panel].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
$model = Sketchup::Model.new
panel = S::Panel.new
dlg = panel.instance_variable_get(:@dialog)
ok('cửa sổ nạp html/index.html', dlg.file == File.join(ROOT, 'html', 'index.html') && File.exist?(dlg.file))
def events(dlg); dlg.scripts.map { |s| s[/receive\((.*?), (\{.*\})\)\z/m, 1].then { |n| [JSON.parse(n), JSON.parse(s[/receive\(.*?, (\{.*\})\)\z/m, 1])] } }; end
def last_event(dlg, name); events(dlg).reverse.find { |n, _| n == name }&.last; end
def call(dlg, name, data = nil); dlg.callbacks.fetch(name).call(nil, data.nil? ? '' : JSON.generate(data)); end

call(dlg, 'ready')
st = last_event(dlg, 'state')
ok('ready: gửi trạng thái mặc định (model chưa có lưới), drawn = false, kèm phiên bản', st && st['grid']['x_axes'].size == 4 && st['saved'] == false && st['drawn'] == false && st['version'] == '9.9.9')
pv = last_event(dlg, 'preview')
ok('ready: gửi luôn xem trước kèm tóm tắt 12 giao điểm, 17 nhịp, 6 ô, khung 12600 x 7200', pv && pv['ok'] && pv['summary'] == {'x_axes' => 4, 'y_axes' => 3, 'intersections' => 12, 'spans' => 17, 'cells' => 6, 'width' => 12_600.0, 'depth' => 7200.0} && pv['axes'].size == 7)

payload = {'grid' => st['grid'], 'symbol' => st['symbol']}
call(dlg, 'grid_preview', payload.merge('symbol' => {'scale' => 50, 'both_ends' => true}))
pv = last_event(dlg, 'preview')
ok('xem trước đổi tỉ lệ 1:50 hai đầu: 2 vòng mỗi trục, bán kính 250', pv['ok'] && pv['axes'].all? { |a| a['bubbles'].size == 2 && a['bubbles'][0]['radius'] == 250.0 })
call(dlg, 'grid_preview', payload.merge('grid' => st['grid'].merge('x_axes' => [{'name' => '1', 'offset' => 0}])))
pv = last_event(dlg, 'preview')
ok('xem trước với lưới sai: báo lỗi tiếng Việt, không có kế hoạch vẽ', pv['ok'] == false && pv['error'].include?('trục đứng') && !pv.key?('axes'))
call(dlg, 'grid_preview', payload.merge('symbol' => {'scale' => 'x'}))
ok('xem trước với tỉ lệ sai: báo lỗi', last_event(dlg, 'preview')['ok'] == false)

call(dlg, 'grid_build', payload)
b = last_event(dlg, 'built')
ok('vẽ lưới: một nhóm trong model, báo 7 trục 7 ký hiệu và ghi chú nét, drawn = true', b && b['drawn'] == true && b['message'].include?('7 trục, 7 ký hiệu') && b['message'].include?('Dash Dot') && $model.entities.grep(Sketchup::Group).size == 1)
call(dlg, 'ready')
ok('mở lại: đọc lưới đã lưu trong model, drawn = true, saved = true', (s = last_event(dlg, 'state')) && s['saved'] == true && s['drawn'] == true && s['grid'] == st['grid'])
call(dlg, 'grid_build', {'grid' => {'origin' => [0, 0]}, 'symbol' => {}})
m = last_event(dlg, 'message')
ok('vẽ với dữ liệu giao diện sai: báo lỗi, model giữ lưới cũ', m && m['error'] == true && $model.entities.grep(Sketchup::Group).size == 1)
call(dlg, 'grid_build', {'grid' => st['grid'].merge('x_axes' => [{'name' => 'A', 'offset' => 0}, {'name' => '2', 'offset' => 4200}]), 'symbol' => {}})
ok('tên trục trùng giữa hai phương bị từ chối khi vẽ', last_event(dlg, 'message')['text'].include?('trùng'))

# Loại cột, tầng và cột
call(dlg, 'ready')
st = last_event(dlg, 'state')
ok('trạng thái có loại cột mặc định C30x30 và hai tầng, chưa dựng cột nào', st['types'].map { |t| t['name'] } == ['C30x30'] && st['levels'].map { |l| l['name'] } == ['Tầng 1', 'Tầng 2'] && st['drawn_levels'] == [])
pv = last_event(dlg, 'preview')
ok('xem trước mở cửa sổ có phần cột: tầng 1 chưa chọn cột nào, cao 3480', pv['levels_ok'] && pv['columns']['level_name'] == 'Tầng 1' && pv['columns']['count'] == 0 && pv['columns']['height'] == 3480.0)
refs = S::Grid.intersections(S::Grid.normalize!(st['grid'])).map { |i| i[:ref] }
levels = st['levels'].map(&:dup)
levels[0] = levels[0].merge('picks' => {'columns' => refs.each_with_object({}) { |r, h| h[r] = {} }})
full = {'grid' => st['grid'], 'symbol' => st['symbol'], 'types' => st['types'], 'levels' => levels, 'level' => levels[0]['id']}
call(dlg, 'grid_preview', full)
pv = last_event(dlg, 'preview')
ok('chọn cả 12 giao điểm: xem trước có 12 cột, đủ trường để vẽ, không cảnh báo', pv['columns']['count'] == 12 && pv['columns']['items'].first.keys.sort == %w[center d modes placement ref type_name w] && pv['columns']['issues'].empty?)
call(dlg, 'grid_preview', full.merge('level' => levels[1]['id']))
pv = last_event(dlg, 'preview')
ok('xem tầng trên cùng: báo "chỉ có sàn", lưới vẫn xem trước được', pv['ok'] && pv['columns_error'].include?('tầng trên cùng') && !pv.key?('columns') && pv['axes'].size == 7)
call(dlg, 'grid_preview', full.merge('types' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 5, 'd' => 300}]))
pv = last_event(dlg, 'preview')
ok('loại cột sai: báo lỗi riêng, lưới vẫn xem trước (không chặn nút vẽ lưới)', pv['ok'] == true && pv['levels_ok'] == false && pv['levels_error'].include?('rộng') && pv['axes'].size == 7)
call(dlg, 'grid_preview', full.merge('levels' => [levels[0].merge('elevation' => 'x')]))
ok('tầng sai: báo lỗi riêng', last_event(dlg, 'preview')['levels_ok'] == false)
call(dlg, 'grid_preview', {'grid' => st['grid'], 'symbol' => st['symbol']})
ok('gửi không có loại cột / tầng (như cột mốc 1): chỉ có phần lưới', !last_event(dlg, 'preview').key?('levels_ok'))

# Dựng cột
call(dlg, 'columns_build', {'state' => full, 'levels' => [levels[0]['id']]})
b = last_event(dlg, 'columns_built')
ok('dựng cột tầng 1: 12 cột, thông báo có chiều cao, drawn_levels có tầng 1, nhóm trong model', b['message'].include?('12 cột') && b['message'].include?('3480') && b['drawn_levels'] == [levels[0]['id']] && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Cột - Tầng 1' })
call(dlg, 'ready')
ok('mở lại cửa sổ: đọc tầng, cột đã chọn và tầng đã dựng từ model', (s2 = last_event(dlg, 'state')) && s2['saved'] == true && s2['levels'][0]['picks']['columns'].size == 12 && s2['drawn_levels'] == [levels[0]['id']])
call(dlg, 'columns_build', {'state' => full, 'levels' => [levels[1]['id']]})
ok('dựng tầng trên cùng: báo lỗi, không đụng model', last_event(dlg, 'message')['error'] == true && last_event(dlg, 'message')['text'].include?('tầng trên cùng'))
call(dlg, 'columns_build', {'state' => full, 'levels' => []})
ok('không chọn tầng: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'columns_build', {'state' => 'x', 'levels' => ['sl_00000001']})
ok('dữ liệu dựng sai kiểu: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
many = full.merge('grid' => S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('4000*29', :number), 'y_axes' => S::Grid.axes_from_spacings('4000*29', :letter)))
many['levels'] = [levels[0].merge('picks' => {'columns' => S::Grid.intersections(many['grid']).each_with_object({}) { |i, h| h[i[:ref]] = {} }}), levels[1]]
$answer = 7
call(dlg, 'columns_build', {'state' => many, 'levels' => [levels[0]['id']]})
ok('dựng hơn 500 cột: hỏi xác nhận, chọn Không thì hủy, không dựng', last_event(dlg, 'message')['text'].include?('chưa dựng') && $boxes.last.include?('900 cột'))
$answer = IDYES
count_before = $model.entities.grep(Sketchup::Group).size
call(dlg, 'columns_build', {'state' => many, 'levels' => [levels[0]['id']]})
ok('chọn Có thì dựng 900 cột', last_event(dlg, 'columns_built')['message'].include?('900 cột'))

# Sao chép lựa chọn giữa tầng
three = levels + [levels[1].merge('id' => 'sl_00000003', 'name' => 'Tầng 3', 'elevation' => 7200.0)]
call(dlg, 'picks_copy', {'grid' => st['grid'], 'types' => st['types'], 'levels' => three, 'from' => levels[0]['id'], 'to' => 'sl_00000003'})
cp = last_event(dlg, 'levels')
ok('sao chép lựa chọn: trả danh sách tầng mới, tầng đích có 12 cột, thông báo nêu tên hai tầng', cp['levels'].last['picks']['columns'].size == 12 && cp['message'].include?('Tầng 1') && cp['message'].include?('Tầng 3'))
call(dlg, 'picks_copy', {'grid' => st['grid'], 'types' => st['types'], 'levels' => three, 'from' => levels[0]['id'], 'to' => levels[0]['id']})
ok('sao chép sang chính tầng đó: báo lỗi', last_event(dlg, 'message')['error'] == true)

# Xóa cột
call(dlg, 'columns_remove', {'level' => levels[0]['id']})
ok('xóa cột tầng 1: drawn_levels rỗng, nhóm biến mất', last_event(dlg, 'columns_built')['drawn_levels'] == [] && $model.entities.grep(Sketchup::Group).none? { |g| g.name == 'Cột - Tầng 1' })
call(dlg, 'columns_remove', {'level' => levels[0]['id']})
ok('xóa khi chưa có: báo, không lỗi', last_event(dlg, 'columns_built')['error'] == true)

# Tạo trục từ chuỗi nhịp
call(dlg, 'grid_axes', {'dir' => 'x', 'text' => '4200, 3600*2'})
ax = last_event(dlg, 'axes')
ok('tạo trục đứng từ nhịp: 4 trục tên số', ax['dir'] == 'x' && ax['axes'].map { |a| a['name'] } == %w[1 2 3 4] && ax['axes'].map { |a| a['offset'] } == [0.0, 4200.0, 7800.0, 11_400.0])
call(dlg, 'grid_axes', {'dir' => 'y', 'text' => '5000'})
ok('tạo trục ngang từ nhịp: tên chữ A, B', last_event(dlg, 'axes')['axes'].map { |a| a['name'] } == %w[A B])
call(dlg, 'grid_axes', {'dir' => 'y', 'text' => 'abc'})
ok('nhịp sai: báo lỗi, không gửi trục', last_event(dlg, 'message')['error'] == true && last_event(dlg, 'axes')['dir'] == 'y' && last_event(dlg, 'axes')['axes'].size == 2)
call(dlg, 'grid_axes', {'dir' => 'z', 'text' => '4200'})
ok('hướng lạ coi là trục đứng, không gây lỗi', last_event(dlg, 'axes')['dir'] == 'x')

# Xóa
$answer = 7 # IDNO
call(dlg, 'grid_remove')
ok('xóa lưới: người dùng chọn Không thì không xóa', $model.entities.grep(Sketchup::Group).size == 1 && last_event(dlg, 'message')['text'].include?('chưa xóa'))
$answer = IDYES
call(dlg, 'grid_remove')
ok('xóa lưới: xác nhận Có thì xóa, drawn = false', last_event(dlg, 'built')['drawn'] == false && $model.entities.grep(Sketchup::Group).empty?)
call(dlg, 'grid_remove')
ok('xóa khi chưa có lưới: báo, không lỗi', last_event(dlg, 'message')['text'].include?('chưa có lưới') && last_event(dlg, 'message')['error'] == true)
call(dlg, 'grid_reset')
ok('đặt lại lưới mặc định: gửi trạng thái mặc định, saved = false', last_event(dlg, 'state')['saved'] == false && last_event(dlg, 'state')['grid'] == S::Grid.default)

# Lỗi bất ngờ trong callback không làm hỏng cửa sổ
dlg.callbacks['grid_preview'].call(nil, 'không phải json')
ok('JSON hỏng từ giao diện: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
panel.show
ok('show mở cửa sổ; gọi lại thì đưa lên trước', panel.visible? && (panel.show; dlg.instance_variable_get(:@brought) == true) && (panel.close; panel.closed?))
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
