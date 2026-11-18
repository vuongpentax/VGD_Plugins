# Test liên kết với SketchUp (cột mốc P6): dấu vân tay, so khớp dữ liệu với model (ok / lệch / thiếu / chưa dựng / thừa), đọc và chọn phần tử trong SketchUp,
# theo dõi vùng chọn, công cụ chọn điểm. SketchUp giả lập (observer, InputPoint, select_tool): phần chạy thật chưa xác minh trong SketchUp.
# Chạy: ruby dev/test_su_link.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
require_relative 'fake_sketchup'
module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    attr_reader :callbacks, :scripts
    def initialize(**opts); @callbacks = {}; @scripts = []; @visible = false; end
    def set_file(f); end
    def add_action_callback(name, &b); @callbacks[name] = b; end
    def set_on_closed(&b); @on_closed = b; end
    def fire_closed; @on_closed&.call; end
    def execute_script(js); @scripts << js; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; end
    def close; @visible = false; fire_closed; end
  end
  # Hẹn giờ giả lập: giữ lại để test tự "đến giờ" (chạy khối ngay khi gọi fire_timers).
  def self.start_timer(delay, repeat, &block); ($timers ||= []) << [delay, repeat, block]; $timers.size; end
  def self.fire_timers; t = ($timers || []).dup; $timers = []; t.each { |_d, _r, b| b.call }; t.size; end
  def self.messagebox(text, *); IDYES; end
end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview model_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
MS = S::ModelSync
D = S::Schema::DICTIONARY
ot = S::OpeningTypes.default
def deep(x); Marshal.load(Marshal.dump(x)); end
def state_with(cols: {'1-A' => {}, '2-B' => {}}, beams: {'x:B:1-2' => {}}, walls: {'x:B:1-2' => {}}, openings: {}, slabs: {'1-2/A-B' => {}}, ceilings: {'1-2/A-B' => {}})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'openings' => openings, 'slabs' => slabs, 'ceilings' => ceilings}
  S::State.normalize!(st)
end
LV = 'sl_00000001'

# ---- Dấu vân tay ----
item = {center: [100.0, 200.04], w: 300, d: 300, z0: 0.0, z1: 3480.0, type_id: 'ct_00000001', type_name: 'C30x30', ref: '1-A'}
fp = MS.fingerprint('column', item)
ok('dấu vân tay: 12 ký tự 16, ổn định với cùng dữ liệu, bỏ qua trường không ảnh hưởng hình (tên, mã)', fp.match?(/\A[0-9a-f]{12}\z/) && fp == MS.fingerprint('column', item.merge(type_name: 'khác', ref: 'x')))
ok('dấu vân tay đổi khi tâm, kích thước, cao độ hoặc loại đổi', [item.merge(center: [100.0, 300.0]), item.merge(w: 400), item.merge(z1: 3000.0), item.merge(type_id: 'ct_00000002')].all? { |i| MS.fingerprint('column', i) != fp })
ok('dấu vân tay làm tròn 0,1 mm: sai số số học không làm đổi', MS.fingerprint('column', item.merge(center: [100.00001, 200.04])) == fp)

# ---- Builder ghi dấu vân tay ----
st = state_with(openings: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}})
model = Sketchup::Model.new
$model = model
S::AllBuilder.build(model, st, [LV])
elements, groups = MS.scan(model)
ok('scan: tìm đủ phần tử đã dựng (2 cột, 1 dầm, 1 tường, 1 cửa, 1 sàn, 1 trần) và 6 nhóm', elements.size == 7 && groups.size == 6 && elements.keys.map(&:first).tally == {'column' => 2, 'beam' => 1, 'wall' => 1, 'opening' => 1, 'slab' => 1, 'ceiling' => 1})
ok('mọi phần tử dựng ra có dấu vân tay (VGD_STRUCT.fp)', elements.values.all? { |e| e.get_attribute(D, 'fp').to_s.match?(/\A[0-9a-f]{12}\z/) })
col_plan = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], LV)
c1 = col_plan[:items].find { |i| i[:ref] == '1-A' }
ok('dấu vân tay trên cột đúng bằng dấu của mục kế hoạch hiện tại', elements[['column', LV, '1-A']].get_attribute(D, 'fp') == MS.fingerprint('column', c1))

# ---- So khớp dữ liệu với model ----
stt = MS.status(model, st, LV)
ok('vừa dựng xong: mọi phần tử "ok", không thiếu, không thừa', stt[:counts] == {'ok' => 7, 'stale' => 0, 'missing' => 0, 'unbuilt' => 0, 'extra' => 0} && stt[:items].values.uniq == ['ok'] && stt[:level] == LV)
ok('khóa trạng thái dạng "loại|mã" (cửa là opening)', stt[:items].key?('column|1-A') && stt[:items].key?('opening|op_00000001') && stt[:items].key?('wall|x:B:1-2'))
moved = state_with(cols: {'1-A' => {'x' => 'center'}, '2-B' => {}}, openings: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}})
s2 = MS.status(model, moved, LV)
ok('đổi kiểu đặt cột 1-A: cột 1-A "stale", cột 2-B vẫn ok', s2[:items]['column|1-A'] == 'stale' && s2[:items]['column|2-B'] == 'ok')
ok('cột 1-A lệch kéo theo trần ô 1-2/A-B (khoét góc theo cột) stale; dầm, tường, cửa, sàn không liên quan vẫn ok', s2[:items]['ceiling|1-2/A-B'] == 'stale' && %w[beam|x:B:1-2 wall|x:B:1-2 opening|op_00000001 slab|1-2/A-B].all? { |k| s2[:items][k] == 'ok' } && s2[:counts]['stale'] == 2)
opmoved = state_with(openings: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => ot[0]['id'], 'pos' => 1500, 'flip' => false}})
s3 = MS.status(model, opmoved, LV)
ok('dời cửa: cửa "stale" VÀ tường (lỗ cửa) "stale"; phần còn lại ok', s3[:items]['opening|op_00000001'] == 'stale' && s3[:items]['wall|x:B:1-2'] == 'stale' && s3[:items]['column|1-A'] == 'ok' && s3[:counts]['stale'] == 2)
more = state_with(cols: {'1-A' => {}, '2-B' => {}, '3-C' => {}}, openings: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}})
s4 = MS.status(model, more, LV)
ok('thêm cột 3-C vào dữ liệu nhưng chưa dựng lại: cột đó "missing" (nhóm cột đã dựng nhưng thiếu cột này)', s4[:items]['column|3-C'] == 'missing' && s4[:counts]['missing'] == 1)
fewer = state_with(cols: {'1-A' => {}}, openings: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => ot[0]['id'], 'pos' => 1000, 'flip' => false}})
s5 = MS.status(model, fewer, LV)
ok('bỏ cột 2-B khỏi dữ liệu: cột còn trong model là "thừa" (extras), nằm ngoài danh sách trạng thái', s5[:extras] == [{kind: 'column', ref: '2-B'}] && s5[:counts]['extra'] == 1 && !s5[:items].key?('column|2-B'))
fresh = Sketchup::Model.new
s6 = MS.status(fresh, st, LV)
ok('model chưa dựng gì: mọi phần tử "unbuilt" (không báo "missing" hàng loạt)', s6[:counts]['unbuilt'] == 7 && s6[:counts]['missing'] == 0 && s6[:counts]['ok'] == 0)
partial = Sketchup::Model.new
S::ColumnBuilder.build(partial, st, [LV])
s7 = MS.status(partial, st, LV)
ok('chỉ dựng cột: cột ok, loại khác unbuilt', s7[:items]['column|1-A'] == 'ok' && s7[:items]['beam|x:B:1-2'] == 'unbuilt' && s7[:items]['slab|1-2/A-B'] == 'unbuilt')
free_st = state_with(cols: {'1-A' => {}, 'fc_0000000a' => {'free' => {'x' => 2000, 'y' => 5000, 'rot' => 0}}})
fm = Sketchup::Model.new; S::ColumnBuilder.build(fm, free_st, [LV])
free_moved = state_with(cols: {'1-A' => {}, 'fc_0000000a' => {'free' => {'x' => 2500, 'y' => 5000, 'rot' => 0}}})
s8 = MS.status(fm, free_moved, LV)
ok('cột tự do dời 500 mm: "stale" (dấu vân tay gồm tâm); cột theo lưới vẫn ok', s8[:items]['column|fc_0000000a'] == 'stale' && s8[:items]['column|1-A'] == 'ok')
top = MS.status(model, st, 'sl_00000002')
ok('tầng trên cùng (chỉ có sàn, chưa dựng): chỉ đánh giá sàn, không lỗi', top[:items].keys.all? { |k| k.start_with?('slab|') })
ok('tầng không tồn tại: không đánh giá, không thừa', (MS.status(model, st, 'sl_ffffffff') rescue :error) != :error && MS.status(model, st, 'sl_ffffffff')[:items].empty?)

# ---- Đọc vùng chọn SketchUp ----
model.selection.clear
model.selection.add(elements[['column', LV, '1-A']])
model.selection.add(elements[['opening', LV, 'op_00000001']])
sel = MS.selection_items(model)
ok('đọc vùng chọn: cột và cửa của plugin → {tầng, loại giao diện, mã}; cửa tính là "opening"', sel[:items] == [{level: LV, kind: 'column', ref: '1-A'}, {level: LV, kind: 'opening', ref: 'op_00000001'}] && sel[:groups].empty?)
model.selection.clear
model.selection.add(groups[['columns', LV]])
ok('chọn nguyên nhóm cột: báo ở "groups" (tầng, loại), không có phần tử riêng', MS.selection_items(model) == {items: [], groups: [{level: LV, kind: 'column'}]})
model.selection.clear
foreign = Sketchup::Instance.new(Sketchup::ComponentDefinition.new('x'), Geom::Transformation.new); foreign.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_room'); model.selection.add(foreign)
ok('phần tử của plugin khác hoặc không có dữ liệu: bỏ qua', MS.selection_items(model) == {items: [], groups: []})

# ---- Chọn trong SketchUp theo dữ liệu ----
r = MS.select(model, LV, [{'kind' => 'column', 'ref' => '1-A'}, {'kind' => 'column', 'ref' => '2-B'}])
ok('chọn hai cột cùng nhóm: mở nhóm cột (active_path) rồi chọn đúng hai phần tử', r[:mode] == 'elements' && r[:found] == 2 && model.active_path == [groups[['columns', LV]]] && model.selection.to_a.sort_by(&:object_id) == [elements[['column', LV, '1-A']], elements[['column', LV, '2-B']]].sort_by(&:object_id))
r = MS.select(model, LV, [{'kind' => 'column', 'ref' => '1-A'}, {'kind' => 'wall', 'ref' => 'x:B:1-2'}])
ok('chọn phần tử của hai nhóm khác nhau: chọn nguyên hai nhóm (không vào nhóm nào)', r[:mode] == 'groups' && r[:found] == 2 && model.selection.to_a.sort_by(&:object_id) == [groups[['columns', LV]], groups[['walls', LV]]].sort_by(&:object_id))
r = MS.select(model, LV, [{'kind' => 'column', 'ref' => '1-A'}, {'kind' => 'column', 'ref' => '9-Z'}])
ok('có phần tử chưa dựng (9-Z): chọn phần đã dựng và báo phần thiếu', r[:found] == 1 && r[:missing] == [{kind: 'column', ref: '9-Z'}])
r = MS.select(model, LV, [{'kind' => 'column', 'ref' => '9-Z'}])
ok('không phần tử nào đã dựng: bỏ chọn, mode none, báo thiếu', r[:mode] == 'none' && r[:found] == 0 && model.selection.to_a.empty? && r[:missing].size == 1)
model.define_singleton_method(:active_path=) { |_p| raise 'không đặt được' }
r = MS.select(model, LV, [{'kind' => 'column', 'ref' => '1-A'}])
ok('không mở được nhóm (active_path lỗi): lùi về chọn nguyên nhóm, không lỗi', r[:mode] == 'groups' && r[:found] == 1)

# ---- Panel: callback, observer, công cụ chọn điểm ----
$model = Sketchup::Model.new
S::AllBuilder.build($model, st, [LV])
panel = S::Panel.new
dlg = panel.instance_variable_get(:@dialog)
def evs(dlg); dlg.scripts.map { |s| m = s.match(/receive\((.*?), (\{.*\})\)\z/m); [JSON.parse(m[1]), JSON.parse(m[2])] }; end
def last_ev(dlg, name); evs(dlg).reverse.find { |n, _| n == name }&.last; end
def count_ev(dlg, name); evs(dlg).count { |n, _| n == name }; end
def call(dlg, name, data = nil); dlg.callbacks.fetch(name).call(nil, data.nil? ? '' : JSON.generate(data)); end
panel.show
ok('mở cửa sổ: gắn theo dõi vùng chọn vào model đang mở (một lần)', $model.selection.observers.size == 1 && ($model.selection.observers.first.is_a?(S::SelectionWatcher)))
panel.show
ok('mở lại cửa sổ đang mở: không gắn thêm observer', $model.selection.observers.size == 1)
call(dlg, 'ready')
ok('ready: gửi kèm trạng thái model của tầng đầu (7 phần tử ok)', (ms = last_ev(dlg, 'model_status')) && ms['counts']['ok'] == 7 && ms['level'] == LV)
payload = last_ev(dlg, 'state')
st_payload = {'grid' => payload['grid'], 'symbol' => payload['symbol'], 'types' => payload['types'], 'beam_types' => payload['beam_types'], 'wall_types' => payload['wall_types'], 'opening_types' => payload['opening_types'], 'levels' => payload['levels'], 'level' => LV}
before = count_ev(dlg, 'model_status')
call(dlg, 'grid_preview', st_payload)
ok('xem trước không có cờ status: không gửi lại trạng thái model', count_ev(dlg, 'model_status') == before)
call(dlg, 'grid_preview', st_payload.merge('status' => true))
ok('xem trước kèm status: gửi trạng thái model của tầng đang xem', count_ev(dlg, 'model_status') == before + 1)
call(dlg, 'grid_preview', st_payload.merge('status' => true, 'level' => 'sl_00000002'))
ok('xem trước tầng khác: trạng thái theo tầng đó', last_ev(dlg, 'model_status')['level'] == 'sl_00000002')
bad = st_payload.merge('status' => true, 'grid' => payload['grid'].merge('x_axes' => [{'name' => '1', 'offset' => 0}]))
n = count_ev(dlg, 'model_status'); call(dlg, 'grid_preview', bad)
ok('dữ liệu sai: xem trước báo lỗi, không gửi trạng thái model', count_ev(dlg, 'model_status') == n && last_ev(dlg, 'preview')['ok'] == false)

# vùng chọn SketchUp -> cửa sổ (gom dồn dập thành một lần)
els, _gr = MS.scan($model)
$timers = []
n = count_ev(dlg, 'model_selection')
$model.selection.clear
$model.selection.add(els[['column', LV, '1-A']])
$model.selection.add(els[['column', LV, '2-B']])
ok('đổi vùng chọn dồn dập trong SketchUp: chỉ hẹn MỘT lần gửi', $timers.size == 1 && $timers[0][0] == S::Panel::SELECTION_DELAY)
UI.fire_timers
ev = last_ev(dlg, 'model_selection')
ok('đến giờ: gửi một sự kiện model_selection với hai cột đang chọn', count_ev(dlg, 'model_selection') == n + 1 && ev['items'].map { |i| [i['level'], i['kind'], i['ref']] } == [[LV, 'column', '1-A'], [LV, 'column', '2-B']])
# cửa sổ -> vùng chọn SketchUp, và không dội lại
n = count_ev(dlg, 'model_selection')
call(dlg, 'plan_select', {'level' => LV, 'items' => [{'kind' => 'wall', 'ref' => 'x:B:1-2'}]})
rs = last_ev(dlg, 'select_result')
ok('cửa sổ chọn tường: SketchUp chọn đúng tường đó (vào nhóm tường) và báo kết quả', rs['found'] == 1 && rs['mode'] == 'elements' && $model.selection.to_a == [els[['wall', LV, 'x:B:1-2']]] && rs['requested'] == 1)
$timers = []
$model.selection.clear; $model.selection.add(els[['wall', LV, 'x:B:1-2']])
ok('việc tự chọn vừa rồi không dội ngược về cửa sổ (bỏ qua sự kiện trong khoảng chờ)', $timers.empty? && count_ev(dlg, 'model_selection') == n)
call(dlg, 'plan_select', {'level' => LV, 'items' => []})
ok('cửa sổ bỏ chọn: SketchUp bỏ chọn', $model.selection.to_a.empty?)
call(dlg, 'plan_select', {'level' => LV, 'items' => [{'kind' => 'column', 'ref' => '9-Z'}]})
rs = last_ev(dlg, 'select_result')
ok('chọn phần tử chưa dựng: báo found 0 và danh sách thiếu để giao diện nhắc "chưa dựng"', rs['found'] == 0 && rs['missing'] == [{'kind' => 'column', 'ref' => '9-Z'}])
['x', {'level' => 1, 'items' => []}, {'level' => LV, 'items' => 'x'}, {'level' => LV, 'items' => [{'kind' => 'xyz', 'ref' => 'a'}]}, {'level' => LV, 'items' => [{'kind' => 'column', 'ref' => 5}]}].each do |bad_payload|
  n = dlg.scripts.size
  call(dlg, 'plan_select', bad_payload)
  ok("plan_select dữ liệu sai bị từ chối, báo lỗi, không đổi vùng chọn (#{bad_payload.inspect[0, 40]})", last_ev(dlg, 'message') && last_ev(dlg, 'message')['error'] && dlg.scripts.size > n)
end
big = {'level' => LV, 'items' => Array.new(S::Panel::MAX_SELECT_ITEMS + 1) { |i| {'kind' => 'column', 'ref' => "r#{i}"} }}
call(dlg, 'plan_select', big)
ok('quá nhiều phần tử một lần: bị từ chối', last_ev(dlg, 'message')['error'])

# công cụ chọn điểm
call(dlg, 'su_pick_start')
ok('su_pick_start: SketchUp chuyển sang công cụ chọn điểm, cửa sổ nhận su_pick_state active', $model.tool.is_a?(S::PickTool) && last_ev(dlg, 'su_pick_state') == {'active' => true} && $status_text.to_s.include?('bấm điểm'))
tool = $model.tool
view = Sketchup::FakeView.new({[10, 10] => Geom::Point3d.new(100.0 / 25.4, 200.0 / 25.4, 0), [20, 20] => Geom::Point3d.new(300.0 / 25.4, 400.0 / 25.4, 0)})
tool.onLButtonDown(0, 10, 10, view)
ev = last_ev(dlg, 'su_point')
ok('bấm điểm trong SketchUp: gửi su_point với tọa độ mm (inch × 25,4, làm tròn 0,1)', ev == {'x' => 100.0, 'y' => 200.0} && view.invalidated > 0)
ok('bấm vào chỗ không bắt được điểm: không gửi gì', (n = count_ev(dlg, 'su_point')) && (tool.onLButtonDown(0, 99, 99, view) || true) && count_ev(dlg, 'su_point') == n)
tool.onMouseMove(0, 20, 20, view)
ev = last_ev(dlg, 'su_move')
ok('rê chuột: gửi su_move (xem trước) và hiện gợi ý bắt điểm của SketchUp', ev == {'x' => 300.0, 'y' => 400.0} && view.tooltip == 'Đầu mút')
n = count_ev(dlg, 'su_move'); tool.onMouseMove(0, 10, 10, view)
ok('rê chuột dồn dập: su_move không dày hơn khoảng giới hạn', count_ev(dlg, 'su_move') == n)
tool.draw(view)
ok('vẽ điểm nhập của SketchUp trên khung nhìn', view.drawn == true)
tool.onCancel(0, view)
ok('Esc trong SketchUp: chuyển cho cửa sổ quyết định (su_key Escape), công cụ vẫn đang chạy', last_ev(dlg, 'su_key') == {'key' => 'Escape'} && $model.tool.equal?(tool))
n_keys = count_ev(dlg, 'su_key'); tool.onCancel(1, view); tool.onCancel(2, view)
ok('onCancel do chọn lại công cụ / hoàn tác (lý do khác 0): bỏ qua, không gửi phím', count_ev(dlg, 'su_key') == n_keys)
$model.select_tool(nil)
ok('SketchUp chuyển sang công cụ khác: cửa sổ nhận su_pick_state inactive đúng MỘT lần', $model.tool.nil? && last_ev(dlg, 'su_pick_state') == {'active' => false} && evs(dlg).count { |nme, d| nme == 'su_pick_state' && d['active'] == false } == 1)
call(dlg, 'su_pick_start'); call(dlg, 'su_pick_stop')
ok('cửa sổ yêu cầu dừng (su_pick_stop): công cụ thoát, nhận inactive', $model.tool.nil? && last_ev(dlg, 'su_pick_state') == {'active' => false})
call(dlg, 'su_pick_start'); first = $model.tool; call(dlg, 'su_pick_start')
ok('bấm chọn điểm lần nữa: thay công cụ cũ bằng công cụ mới, không chồng', $model.tool.is_a?(S::PickTool) && !$model.tool.equal?(first))
call(dlg, 'su_pick_stop')
call(dlg, 'su_pick_start'); panel.close
ok('đóng cửa sổ: gỡ observer vùng chọn và thoát công cụ chọn điểm', $model.selection.observers.empty? && $model.tool.nil?)
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
