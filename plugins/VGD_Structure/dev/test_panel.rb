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
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/sketchup_import core/state core/preview model_sync edit_sync su_scan model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
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
ok('xem trước mở cửa sổ có phần cột: tầng 1 chưa chọn cột nào, cao 3600', pv['levels_ok'] && pv['columns']['level_name'] == 'Tầng 1' && pv['columns']['count'] == 0 && pv['columns']['height'] == 3600.0)
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
ok('dựng cột tầng 1: 12 cột, thông báo có chiều cao, drawn_levels có tầng 1, nhóm trong model', b['message'].include?('12 cột') && b['message'].include?('3600') && b['drawn_levels'] == [levels[0]['id']] && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Cột - Tầng 1' })
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

# Dầm (bắt đầu từ lưới mặc định, vì các thử nghiệm trước đã lưu lưới lớn vào model)
call(dlg, 'grid_reset')
st = last_event(dlg, 'state')
ok('trạng thái có loại dầm mặc định D20x40 và danh sách tầng dầm đã dựng rỗng', st['beam_types'].map { |t| t['name'] } == ['D20x40'] && st['drawn_beam_levels'] == [] && st['levels'][0].key?('beam_type') && st['levels'][0]['picks'].key?('beams'))
spans = S::Grid.spans(S::Grid.normalize!(st['grid'])).map { |sp| sp[:ref] }
blevels = st['levels'].map { |l| JSON.parse(JSON.generate(l)) }
blevels[0]['picks'] = {'columns' => refs.each_with_object({}) { |r, h| h[r] = {} }, 'beams' => spans.each_with_object({}) { |r, h| h[r] = {} }}
bfull = {'grid' => st['grid'], 'symbol' => st['symbol'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'levels' => blevels, 'level' => blevels[0]['id']}
call(dlg, 'grid_preview', bfull)
pv = last_event(dlg, 'preview')
ok('xem trước có phần dầm: 17 dầm, đỉnh 3550, đủ trường để vẽ, không cảnh báo', pv['beams']['count'] == 17 && pv['beams']['z_top'] == 3550.0 && pv['beams']['items'].first.keys.sort == %w[dir h length max min mode placement ref type_name w z_bottom z_top] && pv['beams']['issues'].empty?)
call(dlg, 'grid_preview', bfull.merge('level' => blevels[1]['id']))
pv = last_event(dlg, 'preview')
ok('tầng trên cùng: báo không có dầm, lưới vẫn xem trước', pv['beams_error'].include?('tầng trên cùng') && !pv.key?('beams') && pv['axes'].size == 7)
call(dlg, 'grid_preview', bfull.merge('beam_types' => [{'id' => 'bt_00000001', 'name' => 'X', 'w' => 5, 'h' => 400}]))
pv = last_event(dlg, 'preview')
ok('loại dầm sai: báo lỗi riêng, lưới vẫn xem trước', pv['ok'] && pv['levels_ok'] == false && pv['levels_error'].include?('rộng'))
call(dlg, 'beams_build', {'state' => bfull, 'levels' => [blevels[0]['id']]})
bb = last_event(dlg, 'beams_built')
ok('dựng dầm tầng 1: 17 dầm, drawn_beam_levels có tầng 1, nhóm trong model', bb['message'].include?('17 dầm') && bb['drawn_beam_levels'] == [blevels[0]['id']] && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Dầm - Tầng 1' })
call(dlg, 'ready')
ok('mở lại: đọc lựa chọn dầm và tầng đã dựng dầm từ model', (s2 = last_event(dlg, 'state')) && s2['levels'][0]['picks']['beams'].size == 17 && s2['drawn_beam_levels'] == [blevels[0]['id']])
call(dlg, 'beams_build', {'state' => bfull, 'levels' => [blevels[1]['id']]})
ok('dựng dầm tầng trên cùng: báo lỗi, không đụng model', last_event(dlg, 'message')['error'] == true)
call(dlg, 'beams_build', {'state' => 'x', 'levels' => ['sl_00000001']})
ok('dữ liệu dựng dầm sai kiểu: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
three_b = blevels + [blevels[1].merge('id' => 'sl_00000003', 'name' => 'Tầng 3', 'elevation' => 7200.0)]
call(dlg, 'picks_copy', {'grid' => st['grid'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'levels' => three_b, 'from' => blevels[0]['id'], 'to' => blevels[1]['id'], 'kind' => 'beams'})
cp = last_event(dlg, 'levels')
ok('sao chép lựa chọn dầm: tầng đích có 17 dầm, thông báo ghi "dầm"', cp['levels'][1]['picks']['beams'].size == 17 && cp['levels'][1]['picks']['columns'].empty? && cp['message'].include?('dầm'))
call(dlg, 'beams_remove', {'level' => blevels[0]['id']})
ok('xóa dầm tầng 1: drawn_beam_levels rỗng, nhóm biến mất', last_event(dlg, 'beams_built')['drawn_beam_levels'] == [] && $model.entities.grep(Sketchup::Group).none? { |g| g.name == 'Dầm - Tầng 1' })
call(dlg, 'beams_remove', {'level' => blevels[0]['id']})
ok('xóa dầm khi chưa có: báo, không lỗi', last_event(dlg, 'beams_built')['error'] == true)

# Tường
call(dlg, 'grid_reset')
st = last_event(dlg, 'state')
ok('trạng thái có loại tường mặc định T200, chưa dựng tường nào, tầng có wall_type và picks.walls', st['wall_types'].map { |t| t['name'] } == ['T200'] && st['drawn_wall_levels'] == [] && st['levels'][0].key?('wall_type') && st['levels'][0]['picks'].key?('walls'))
wspans = S::Grid.spans(S::Grid.normalize!(st['grid'])).map { |sp| sp[:ref] }
wlevels = st['levels'].map { |l| JSON.parse(JSON.generate(l)) }
wlevels[0]['picks'] = {'columns' => refs.each_with_object({}) { |r, h| h[r] = {} }, 'beams' => {}, 'walls' => wspans.each_with_object({}) { |r, h| h[r] = {} }}
wfull = {'grid' => st['grid'], 'symbol' => st['symbol'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'wall_types' => st['wall_types'], 'levels' => wlevels, 'level' => wlevels[0]['id']}
call(dlg, 'grid_preview', wfull)
pv = last_event(dlg, 'preview')
ok('xem trước có phần tường: 17 tường, cao 3480, đủ trường để vẽ, không cảnh báo', pv['walls']['count'] == 17 && pv['walls']['z_slab'] == 3430.0 && pv['walls']['items'].first.keys.sort == %w[center dir finish height join length max min mode openings openings_area placement ref start t type_name under_beam z_bottom z_top] && pv['walls']['issues'].empty?)
call(dlg, 'grid_preview', wfull.merge('level' => wlevels[1]['id']))
ok('tầng trên cùng: báo không có tường, lưới vẫn xem trước', last_event(dlg, 'preview')['walls_error'].include?('tầng trên cùng') && last_event(dlg, 'preview')['axes'].size == 7)
call(dlg, 'grid_preview', wfull.merge('wall_types' => [{'id' => 'wt_00000001', 'name' => 'X', 't' => 5}]))
ok('loại tường sai: báo lỗi riêng, lưới vẫn xem trước', last_event(dlg, 'preview')['ok'] && last_event(dlg, 'preview')['levels_ok'] == false)
call(dlg, 'walls_build', {'state' => wfull, 'levels' => [wlevels[0]['id']]})
wb = last_event(dlg, 'walls_built')
ok('dựng tường tầng 1: 17 tường, drawn_wall_levels có tầng 1, nhóm trong model', wb['message'].include?('17 tường') && wb['drawn_wall_levels'] == [wlevels[0]['id']] && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Tường - Tầng 1' })
call(dlg, 'ready')
ok('mở lại: đọc lựa chọn tường và tầng đã dựng tường từ model', (s2 = last_event(dlg, 'state')) && s2['levels'][0]['picks']['walls'].size == 17 && s2['drawn_wall_levels'] == [wlevels[0]['id']])
call(dlg, 'walls_build', {'state' => wfull, 'levels' => [wlevels[1]['id']]})
ok('dựng tường tầng trên cùng: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'walls_build', {'state' => 'x', 'levels' => ['sl_00000001']})
ok('dữ liệu dựng tường sai kiểu: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
call(dlg, 'picks_copy', {'grid' => st['grid'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'wall_types' => st['wall_types'], 'levels' => wlevels + [wlevels[1].merge('id' => 'sl_00000003', 'name' => 'Tầng 3', 'elevation' => 7200.0)], 'from' => wlevels[0]['id'], 'to' => wlevels[1]['id'], 'kind' => 'walls'})
cp = last_event(dlg, 'levels')
ok('sao chép lựa chọn tường: tầng đích có 17 tường, thông báo ghi "tường"', cp['levels'][1]['picks']['walls'].size == 17 && cp['message'].include?('tường'))
call(dlg, 'walls_remove', {'level' => wlevels[0]['id']})
ok('xóa tường tầng 1: drawn_wall_levels rỗng, nhóm biến mất', last_event(dlg, 'walls_built')['drawn_wall_levels'] == [] && $model.entities.grep(Sketchup::Group).none? { |g| g.name == 'Tường - Tầng 1' })
call(dlg, 'walls_remove', {'level' => wlevels[0]['id']})
ok('xóa tường khi chưa có: báo, không lỗi', last_event(dlg, 'walls_built')['error'] == true)

# Sàn và trần
call(dlg, 'grid_reset')
st = last_event(dlg, 'state')
cells = S::Grid.cells(S::Grid.normalize!(st['grid'])).map { |c| c[:ref] }
ok('trạng thái có cao trần, dày trần, picks.slabs / ceilings, chưa dựng sàn và trần', st['levels'][0]['ceiling_height'] == 2800.0 && st['levels'][0]['ceiling_thickness'] == 9.0 && st['levels'][0]['picks'].key?('slabs') && st['drawn_slab_levels'] == [] && st['drawn_ceiling_levels'] == [])
plv = st['levels'].map { |l| JSON.parse(JSON.generate(l)) }
plv[0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => cells.each_with_object({}) { |r, h| h[r] = {} }, 'ceilings' => cells.each_with_object({}) { |r, h| h[r] = {} }}
pfull = {'grid' => st['grid'], 'symbol' => st['symbol'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'wall_types' => st['wall_types'], 'levels' => plv, 'level' => plv[0]['id']}
call(dlg, 'grid_preview', pfull)
pv = last_event(dlg, 'preview')
ok('xem trước có phần sàn: 6 sàn, mặt trên -50, dày 120, đủ trường để vẽ', pv['slabs']['count'] == 6 && pv['slabs']['z_top'] == -50.0 && pv['slabs']['items'].first.keys.sort == %w[area max min polygon thickness z_bottom z_top ref].sort)
ok('xem trước có phần trần: 6 trần, mặt dưới 2800, mỗi trần có đa giác', pv['ceilings']['count'] == 6 && pv['ceilings']['z_bottom'] == 2800.0 && pv['ceilings']['items'].all? { |i| i['polygon'].size >= 4 })
call(dlg, 'grid_preview', pfull.merge('level' => plv[1]['id']))
pv = last_event(dlg, 'preview')
ok('tầng trên cùng: có sàn (xem trước), không có trần (báo lỗi riêng)', pv['slabs']['count'] == 0 && pv['ceilings_error'].include?('tầng trên cùng') && !pv.key?('ceilings'))
call(dlg, 'plates_build', {'kind' => 'slabs', 'state' => pfull, 'levels' => [plv[0]['id']]})
pb = last_event(dlg, 'plates_built')
ok('dựng sàn tầng 1: 6 sàn, drawn_levels có tầng 1, nhóm trong model', pb['kind'] == 'slabs' && pb['message'].include?('6 sàn') && pb['drawn_levels'] == [plv[0]['id']] && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Sàn - Tầng 1' })
call(dlg, 'plates_build', {'kind' => 'ceilings', 'state' => pfull, 'levels' => [plv[0]['id']]})
pb = last_event(dlg, 'plates_built')
ok('dựng trần tầng 1: 6 trần, nhóm riêng', pb['kind'] == 'ceilings' && pb['message'].include?('6 trần') && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Trần - Tầng 1' } && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Sàn - Tầng 1' })
call(dlg, 'ready')
ok('mở lại: đọc lựa chọn và tầng đã dựng sàn / trần từ model', (s2 = last_event(dlg, 'state')) && s2['drawn_slab_levels'] == [plv[0]['id']] && s2['drawn_ceiling_levels'] == [plv[0]['id']] && s2['levels'][0]['picks']['slabs'].size == 6)
call(dlg, 'plates_build', {'kind' => 'ceilings', 'state' => pfull, 'levels' => [plv[1]['id']]})
ok('dựng trần tầng trên cùng: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'plates_build', {'kind' => 'floors', 'state' => pfull, 'levels' => [plv[0]['id']]})
ok('loại tấm lạ: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
call(dlg, 'plates_build', {'kind' => 'slabs', 'state' => 'x', 'levels' => ['sl_00000001']})
ok('dữ liệu dựng sàn sai kiểu: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'picks_copy', {'grid' => st['grid'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'wall_types' => st['wall_types'], 'levels' => plv + [plv[1].merge('id' => 'sl_00000003', 'name' => 'Tầng 3', 'elevation' => 7200.0)], 'from' => plv[0]['id'], 'to' => plv[1]['id'], 'kind' => 'slabs'})
cp = last_event(dlg, 'levels')
ok('sao chép lựa chọn sàn: tầng đích có 6 sàn, thông báo ghi "sàn"', cp['levels'][1]['picks']['slabs'].size == 6 && cp['message'].include?('sàn'))
call(dlg, 'plates_remove', {'kind' => 'slabs', 'level' => plv[0]['id']})
ok('xóa sàn: drawn_levels rỗng, trần còn nguyên', last_event(dlg, 'plates_built')['drawn_levels'] == [] && $model.entities.grep(Sketchup::Group).none? { |g| g.name == 'Sàn - Tầng 1' } && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Trần - Tầng 1' })
call(dlg, 'plates_remove', {'kind' => 'ceilings', 'level' => plv[0]['id']})
call(dlg, 'plates_remove', {'kind' => 'ceilings', 'level' => plv[0]['id']})
ok('xóa khi chưa có: báo, không lỗi', last_event(dlg, 'plates_built')['error'] == true)

# Đề xuất, kiểm tra, dựng tất cả
call(dlg, 'grid_reset')
st = last_event(dlg, 'state')
base = {'grid' => st['grid'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'wall_types' => st['wall_types'], 'levels' => st['levels']}
call(dlg, 'propose', base.merge('scope' => 'level', 'level' => 'sl_00000001'))
pr = last_event(dlg, 'levels')
ok('đề xuất tầng 1: trả danh sách tầng mới (12 cột, 17 dầm, 10 tường, 6 sàn, 6 trần), thông báo nêu số lượng', pr['levels'][0]['picks']['columns'].size == 12 && pr['levels'][0]['picks']['walls'].size == 10 && pr['levels'][1]['picks']['columns'].empty? && pr['message'].include?('12 cột') && pr['proposed']['beams'] == 17)
call(dlg, 'propose', base.merge('scope' => 'all'))
pa = last_event(dlg, 'levels')
ok('đề xuất mọi tầng: tầng 2 là tầng trên cùng (chỉ sàn)', pa['levels'][0]['picks']['columns'].size == 12 && pa['levels'][1]['picks']['columns'].empty? && pa['levels'][1]['picks']['slabs'].size == 6)
call(dlg, 'propose', base.merge('scope' => 'level', 'level' => 'sl_deadbeef'))
ok('đề xuất tầng không tồn tại: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'propose', base.merge('types' => []))
ok('đề xuất với dữ liệu sai: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
full_state = base.merge('levels' => pr['levels'], 'symbol' => st['symbol'])
call(dlg, 'check', full_state)
ck = last_event(dlg, 'check')
ok('kiểm tra kết cấu: trả báo cáo từng tầng với số lượng và không lỗi', ck['errors'] == 0 && ck['levels'].map { |l| l['name'] } == ['Tầng 1', 'Tầng 2'] && ck['levels'][0]['counts']['columns'] == 12 && ck['levels'][1]['top'] == true)
call(dlg, 'check', {'grid' => 5})
ok('kiểm tra với dữ liệu sai: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'build_all', {'state' => full_state, 'levels' => ['sl_00000001', 'sl_00000002']})
ba = last_event(dlg, 'all_built')
names = $model.entities.grep(Sketchup::Group).map(&:name)
ok('dựng tất cả: thông báo một bước hoàn tác, đủ nhóm cột / dầm / tường / sàn / trần tầng 1, danh sách đã dựng', ba['message'].include?('một bước hoàn tác') && ba['message'].include?('12 cột') && ba['drawn']['columns'] == ['sl_00000001'] && ba['drawn']['slabs'].sort == ['sl_00000001'] && ['Cột - Tầng 1', 'Dầm - Tầng 1', 'Tường - Tầng 1', 'Sàn - Tầng 1', 'Trần - Tầng 1'].all? { |n| names.include?(n) })
call(dlg, 'build_all', {'state' => full_state, 'levels' => []})
ok('dựng tất cả không chọn tầng: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'build_all', {'state' => 'x', 'levels' => ['sl_00000001']})
ok('dựng tất cả dữ liệu sai kiểu: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
big = full_state.merge('grid' => S::Grid.normalize!('origin' => [0, 0], 'x_axes' => S::Grid.axes_from_spacings('4000*29', :number), 'y_axes' => S::Grid.axes_from_spacings('4000*29', :letter)))
bigl = S::Proposal.propose(big['grid'], big['levels'], ['sl_00000001']).first
$answer = 7
call(dlg, 'build_all', {'state' => big.merge('levels' => bigl), 'levels' => ['sl_00000001']})
ok('dựng tất cả hơn 500 đối tượng: hỏi xác nhận, chọn Không thì hủy', last_event(dlg, 'message')['text'].include?('chưa dựng gì') && $boxes.last.include?('đối tượng'))
$answer = IDYES
[S::ColumnBuilder, S::BeamBuilder, S::WallBuilder].each { |b| b.remove($model) }
%w[slabs ceilings].each { |k| S::PlateBuilder.remove($model, k) }

# Cửa
call(dlg, 'grid_reset')
st = last_event(dlg, 'state')
ok('trạng thái có loại cửa mặc định (cửa đi D900x2100, cửa sổ W1200x1200), picks.openings rỗng, chưa dựng cửa', st['opening_types'].map { |t| t['name'] } == ['D900x2100', 'W1200x1200'] && st['drawn_opening_levels'] == [] && st['levels'][0]['picks']['openings'] == {} && st['levels'][0]['picks']['walls'] == {})
olv = st['levels'].map { |l| JSON.parse(JSON.generate(l)) }
ocols = S::Grid.intersections(S::Grid.normalize!(st['grid'])).each_with_object({}) { |i, h| h[i[:ref]] = {} }
olv[0]['picks'] = {'columns' => ocols, 'beams' => {}, 'walls' => {'x:B:2-3' => {}}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {'op_00000001' => {'wall' => 'x:B:2-3', 'type' => 'ot_00000001', 'pos' => 1950, 'flip' => false}, 'op_00000002' => {'wall' => 'x:B:2-3', 'type' => 'ot_00000002', 'pos' => 3200, 'flip' => false}}}
ofull = {'grid' => st['grid'], 'symbol' => st['symbol'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'wall_types' => st['wall_types'], 'opening_types' => st['opening_types'], 'levels' => olv, 'level' => olv[0]['id']}
call(dlg, 'grid_preview', ofull)
pv = last_event(dlg, 'preview')
ok('xem trước: tường có 2 cửa (danh sách lỗ trong tường) và phần cửa có 2 cửa đủ trường để vẽ', pv['walls']['items'][0]['openings'].size == 2 && pv['walls']['items'][0]['openings_area'] == 3.33 && pv['openings']['count'] == 2 && pv['openings']['items'].first.keys.sort == %w[dir flip h kind max min pos ref sill type_name w wall z_bottom z_top])
call(dlg, 'grid_preview', ofull.merge('level' => olv[1]['id']))
ok('tầng trên cùng: báo không có cửa, lưới vẫn xem trước', last_event(dlg, 'preview')['openings_error'].include?('tầng trên cùng') && last_event(dlg, 'preview')['axes'].size == 7)
call(dlg, 'grid_preview', ofull.merge('opening_types' => [{'id' => 'ot_00000001', 'name' => 'X', 'kind' => 'door', 'w' => 10, 'h' => 2100, 'sill' => 0}]))
ok('loại cửa sai: báo lỗi riêng, lưới vẫn xem trước', last_event(dlg, 'preview')['ok'] && last_event(dlg, 'preview')['levels_ok'] == false)
call(dlg, 'openings_build', {'state' => ofull, 'levels' => [olv[0]['id']]})
ob = last_event(dlg, 'openings_built')
ok('dựng cửa tầng 1: 2 cửa, nhắc dựng lại tường, drawn_opening_levels có tầng 1, nhóm trong model', ob['message'].include?('2 cửa') && ob['message'].include?('dựng lại tường') && ob['drawn_opening_levels'] == [olv[0]['id']] && $model.entities.grep(Sketchup::Group).any? { |g| g.name == 'Cửa - Tầng 1' })
call(dlg, 'ready')
ok('mở lại: đọc cửa đã đặt và loại cửa từ model, tầng đã dựng cửa', (s2 = last_event(dlg, 'state')) && s2['levels'][0]['picks']['openings'].size == 2 && s2['drawn_opening_levels'] == [olv[0]['id']])
call(dlg, 'openings_build', {'state' => ofull, 'levels' => [olv[1]['id']]})
ok('dựng cửa tầng trên cùng: báo lỗi', last_event(dlg, 'message')['error'] == true)
call(dlg, 'openings_build', {'state' => 'x', 'levels' => ['sl_00000001']})
ok('dữ liệu dựng cửa sai kiểu: báo lỗi, không văng', last_event(dlg, 'message')['error'] == true)
call(dlg, 'picks_copy', {'grid' => st['grid'], 'types' => st['types'], 'beam_types' => st['beam_types'], 'wall_types' => st['wall_types'], 'opening_types' => st['opening_types'], 'levels' => olv + [olv[1].merge('id' => 'sl_00000003', 'name' => 'Tầng 3', 'elevation' => 7200.0)], 'from' => olv[0]['id'], 'to' => olv[1]['id'], 'kind' => 'openings'})
ok('sao chép cửa: tầng đích có 2 cửa với mã mới, thông báo ghi "cửa"', last_event(dlg, 'levels')['levels'][1]['picks']['openings'].size == 2 && !last_event(dlg, 'levels')['levels'][1]['picks']['openings'].key?('op_00000001') && last_event(dlg, 'levels')['message'].include?('cửa'))
call(dlg, 'openings_remove', {'level' => olv[0]['id']})
ok('xóa cửa: drawn_opening_levels rỗng, nhóm biến mất', last_event(dlg, 'openings_built')['drawn_opening_levels'] == [] && $model.entities.grep(Sketchup::Group).none? { |g| g.name == 'Cửa - Tầng 1' })
call(dlg, 'openings_remove', {'level' => olv[0]['id']})
ok('xóa cửa khi chưa có: báo, không lỗi', last_event(dlg, 'openings_built')['error'] == true)
call(dlg, 'build_all', {'state' => ofull, 'levels' => [olv[0]['id']]})
ba = last_event(dlg, 'all_built')
ok('dựng tất cả gồm cả cửa: danh sách đã dựng có cửa tầng 1', ba['drawn']['openings'] == [olv[0]['id']] && ba['message'].include?('cửa'))
call(dlg, 'check', ofull.merge('levels' => olv))
ok('kiểm tra kết cấu đếm cửa', last_event(dlg, 'check')['levels'][0]['counts']['openings'] == 2)
[S::ColumnBuilder, S::BeamBuilder, S::WallBuilder, S::OpeningBuilder].each { |b| b.remove($model) }
%w[slabs ceilings].each { |k| S::PlateBuilder.remove($model, k) }

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
