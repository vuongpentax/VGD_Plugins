# Test nhận đối tượng SketchUp thường về làm dữ liệu Structure: quét theo tag BIM, nhận diện loại, bản vá dữ liệu tự do, loại mới, cửa vào tường chủ, xóa đối tượng gốc và giữ VGD ID khi dựng lại, gán tag. SketchUp giả lập: chưa xác minh trong SketchUp thật.
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
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/sketchup_import core/state core/preview model_sync edit_sync su_scan model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
MS = S::ModelSync
D = S::Schema::DICTIONARY
ot = S::OpeningTypes.default
def deep(x); Marshal.load(Marshal.dump(x)); end
def error_of; yield; nil; rescue StandardError => e; e.message; end
LV = 'sl_00000001'
def state_with(cols: {'1-A' => {}, '2-B' => {}}, beams: {'x:B:1-2' => {}}, walls: {'x:B:1-2' => {}}, slabs: {'1-2/A-B' => {}}, ceilings: {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'openings' => {}, 'slabs' => slabs, 'ceilings' => ceilings}
  S::State.normalize!(st)
end
def evs(dlg); dlg.scripts.map { |s| m = s.match(/receive\((.*?), (\{.*\})\)\z/m); [JSON.parse(m[1]), JSON.parse(m[2])] }; end
def last_ev(dlg, name); evs(dlg).reverse.find { |n, _| n == name }&.last; end
def count_ev(dlg, name); evs(dlg).count { |n, _| n == name }; end
def call(dlg, name, data = nil); dlg.callbacks.fetch(name).call(nil, data.nil? ? '' : JSON.generate(data)); end
kinds_of = ->(model) { model.entities.grep(Sketchup::Group).map { |g| g.get_attribute(D, 'kind') }.sort }

SI = S::SketchupImport
def desc(kind, id, center, size, angle: 0.0, z0: 0.0, z1: nil)
  {'id' => id, 'kind' => kind, 'name' => "đối tượng #{id}", 'center' => center, 'size' => size, 'angle' => angle, 'z0' => z0, 'z1' => z1 || z0 + size[2]}
end
base = S::State.normalize!(S::State.default)
l1 = base['levels'][0]
top1 = S::Levels.structure_top(l1)          # cốt sàn kết cấu tầng 1 = -50
top2 = S::Levels.structure_top(base['levels'][1])

# ---- Cột ----
r = SI.plan(base, [desc('column', 1, [1000, 2000], [300, 300, 3550], z0: top1, z1: top2)])
pk = r[:patches][0]['set']['columns'].values.first
ok('cột 300x300: thành cột TỰ DO đúng tâm, trùng loại có sẵn (không thêm loại)', r[:patches].size == 1 && pk['free'] == {'x' => 1000.0, 'y' => 2000.0, 'rot' => 0} && pk['type'] == base['types'][0]['id'] && r[:types].empty?)
ok('mã cột tự do có dạng fc_xxxxxxxx; ghi lại đối tượng gốc đã nhận (để xóa khi dựng)', r[:patches][0]['set']['columns'].keys[0].match?(/\Afc_[0-9a-f]{8}\z/) && r[:adopted] == [{'su_id' => 1, 'level' => 'sl_00000001', 'box' => 'columns', 'ref' => r[:patches][0]['set']['columns'].keys[0]}])
r = SI.plan(base, [desc('column', 2, [0, 0], [400, 250, 3550], angle: 30.0, z0: top1, z1: top2)])
pk = r[:patches][0]['set']['columns'].values.first
ok('cột 400x250 xoay 30 độ: tạo loại mới "NHẬN 400x250", giữ góc xoay', r[:types]['types'].size == 1 && r[:types]['types'][0]['name'] == 'NHẬN 400x250' && r[:types]['types'][0]['w'] == 400.0 && pk['free']['rot'] == 30 && pk['type'] == r[:types]['types'][0]['id'])
ok('loại mới có mã ct_xxxxxxxx và hợp lệ với ColumnTypes', r[:types]['types'][0]['id'].match?(/\Act_[0-9a-f]{8}\z/) && error_of { S::ColumnTypes.normalize!(base['types'] + r[:types]['types']) }.nil?)
r = SI.plan(base, [desc('column', 3, [0, 0], [300, 300, 3550], z0: top1 + 20, z1: top2), desc('column', 4, [500, 0], [300.5, 299.5, 3550], z0: top1, z1: top2)])
ok('kích thước sai không quá 1 mm: dùng loại có sẵn, không thêm loại', r[:types].empty? && r[:patches][0]['set']['columns'].size == 2)
r = SI.plan(base, [desc('column', 5, [0, 0], [300, 300, 3550], z0: 9000.0, z1: 12550.0)])
ok('cột lệch cao độ mọi tầng quá 600 mm: bỏ qua, báo lý do', r[:patches].empty? && r[:adopted].empty? && r[:skipped][0].include?('cao độ không khớp'))

# ---- Dầm, tường ----
r = SI.plan(base, [desc('beam', 10, [2000, 3000], [4000, 200, 400], z0: top2 - 400, z1: top2)])
pk = r[:patches][0]['set']['beams'].values.first
ok('dầm 4000x200x400: trục dọc theo X từ (0,3000) tới (4000,3000), loại mới D200x400 trùng loại mặc định', pk['free'] == {'a' => [0.0, 3000.0], 'b' => [4000.0, 3000.0]} && r[:types].empty? && pk['type'] == base['beam_types'][0]['id'])
r = SI.plan(base, [desc('beam', 11, [1000, 1000], [200, 3000, 500], angle: 0.0, z0: top2 - 500, z1: top2)])
pk = r[:patches][0]['set']['beams'].values.first
ok('dầm dài theo trục Y cục bộ: trục chuyển sang hướng +Y, loại mới cao 500', pk['free']['a'][0] == 1000.0 && pk['free']['b'][1] == 2500.0 && r[:types]['beam_types'][0]['h'] == 500.0)
r = SI.plan(base, [desc('beam', 12, [0, 0], [50, 40, 300], z0: top2 - 300, z1: top2)])
ok('dầm quá ngắn (< 100 mm): bỏ qua', r[:adopted].empty? && r[:skipped][0].include?('dài chỉ'))
r = SI.plan(base, [desc('wall', 13, [1000, 0], [2000, 200, 3200], angle: 90.0, z0: top1, z1: top1 + 3200)])
pk = r[:patches][0]['set']['walls'].values.first
ok('tường xoay 90 độ: trục từ (1000,-1000) tới (1000,1000); loại tường mặc định 200 có sẵn', pk['free']['a'][1] == -1000.0 && pk['free']['b'][1] == 1000.0 && pk['free']['a'][0] == 1000.0 && r[:types].empty?)
r = SI.plan(base, [desc('wall', 14, [0, 0], [3000, 150, 3200], z0: top1, z1: top1 + 3200)])
ok('tường dày 150: loại tường mới có lớp kết cấu 150 và hợp lệ với WallTypes', r[:types]['wall_types'][0]['t'] == 150.0 && error_of { S::WallTypes.normalize!(base['wall_types'] + r[:types]['wall_types']) }.nil?)

# ---- Sàn, trần ----
r = SI.plan(base, [desc('slab', 20, [2000, 1500], [4000, 3000, 120], z0: top1 - 120, z1: top1)])
pk = r[:patches][0]['set']['slabs'].values.first
ok('sàn: đa giác chữ nhật ngược chiều kim đồng hồ đúng hình bao, không lỗ', pk['free']['poly'] == [[0.0, 0.0], [4000.0, 0.0], [4000.0, 3000.0], [0.0, 3000.0]] && pk['free']['holes'] == [] && r[:patches][0]['set']['slabs'].keys[0].start_with?('fs_'))
r = SI.plan(base, [desc('slab', 21, [0, 0], [1000, 1000, 200], z0: top1 - 200, z1: top1)])
ok('sàn dày 200 khác dày sàn tầng (120): nhận nhưng báo lưu ý dựng lại dùng dày của tầng', r[:adopted].size == 1 && r[:skipped][0].include?('dày'))
r = SI.plan(base, [desc('ceiling', 22, [2000, 1500], [3000, 2000, 9], z0: l1['elevation'] + l1['ceiling_height'])])
ok('trần ở cao 2800: vào tầng 1, mã fk_', r[:patches][0]['set']['ceilings'].keys[0].start_with?('fk_') && r[:patches][0]['level'] == 'sl_00000001')
ok('đa giác sàn nhận về được Ruby chấp nhận khi chuẩn hóa lại', begin; st = deep(base); r = SI.plan(base, [desc('slab', 23, [2000, 1500], [4000, 3000, 120], angle: 25.0, z0: top1 - 120, z1: top1)]); st['levels'][0]['picks']['slabs'].merge!(r[:patches][0]['set']['slabs']); error_of { S::State.normalize!(st) }.nil?; end)

# ---- Cửa ----
objs = [desc('wall', 30, [2000, 1000], [4000, 200, 3200], z0: top1, z1: top1 + 3200), desc('door', 31, [1000, 1000], [900, 120, 2100], z0: 0.0, z1: 2100.0), desc('window', 32, [3000, 1000], [1200, 120, 1200], z0: 900.0, z1: 2100.0)]
r = SI.plan(base, objs)
ops = r[:patches][0]['set']['openings']
wall_ref = r[:patches][0]['set']['walls'].keys[0]
ok('cửa đi và cửa sổ nằm trong tường vừa nhận: gắn vào đúng tường chủ', ops.size == 2 && ops.values.all? { |o| o['wall'] == wall_ref })
door_pick = ops.values.find { |o| o['pos'] == 1000.0 } || ops.values.min_by { |o| o['pos'] }
ok('vị trí cửa = khoảng cách từ đầu tường (tâm cửa x=1000 thì cách đầu tường x=0 là 1000; cửa sổ x=3000 thì 3000)', ops.values.map { |o| o['pos'] }.sort == [1000.0, 3000.0])
ok('cửa 900x2100 ngưỡng 0 và cửa sổ 1200x1200 ngưỡng 900 (tính từ cốt hoàn thiện) trùng loại mặc định: không thêm loại', r[:types].empty? && ops.values.map { |o| o['type'] }.sort == %w[ot_00000001 ot_00000002])
r2 = SI.plan(base, [desc('wall', 34, [2000, 1000], [4000, 200, 3200], z0: top1, z1: top1 + 3200), desc('door', 35, [1000, 1000], [1000, 120, 2200], z0: 100.0, z1: 2300.0)])
ok('cửa kích thước khác (1000x2200, ngưỡng 100 - 0): thêm loại cửa mới kind door đúng kích thước', r2[:types]['opening_types'].size == 1 && r2[:types]['opening_types'][0].values_at('kind', 'w', 'h') == ['door', 1000.0, 2200.0] && r2[:types]['opening_types'][0]['sill'] == 100.0 + 50.0 - 50.0)
st_after = deep(base); st_after['levels'][0]['picks']['walls'].merge!(r[:patches][0]['set']['walls']); st_after['levels'][0]['picks']['openings'].merge!(ops)
st_after['opening_types'] += (r[:types]['opening_types'] || []); st_after['wall_types'] += (r[:types]['wall_types'] || [])
ok('dữ liệu sau khi nhận (tường + cửa + loại mới) được Ruby chuẩn hóa không lỗi', error_of { S::State.normalize!(st_after) }.nil?)
r = SI.plan(base, [desc('door', 33, [1000, 1000], [900, 120, 2100], z0: 0.0, z1: 2100.0)])
ok('cửa không nằm trong tường nào: bỏ qua, báo cần nhận tường trước', r[:adopted].empty? && r[:skipped][0].include?('không nằm trong tường'))

r = SI.plan(base, [desc('wall', 36, [2000, 1000], [4000, 200, 3200], z0: top1, z1: top1 + 3200), desc('door', 37, [1000, 1500], [900, 120, 2100], z0: 0.0, z1: 2100.0)])
ok('cửa cách tim tường 500 mm (xa hơn nửa bề dày + dung sai): không coi là nằm trong tường', r[:adopted].size == 1 && r[:skipped].any? { |m| m.include?('không nằm trong tường') })
r = SI.plan(base, [desc('wall', 38, [2000, 1000], [4000, 200, 3200], z0: top1, z1: top1 + 3200), desc('door', 39, [5000, 1000], [900, 120, 2100], z0: 0.0, z1: 2100.0)])
ok('cửa nằm ngoài chiều dài tường (x = 5000 > 4000): không gắn vào tường', r[:adopted].size == 1 && r[:skipped].any? { |m| m.include?('không nằm trong tường') })

# ---- Quét model (SuScan) ----
$model = Sketchup::Model.new
mk = lambda do |tag, size, center, angle = 0.0, name = nil|
  d = Sketchup::ComponentDefinition.new('d')
  d.fake_bounds = Sketchup::FakeBounds.new(size[0].mm, size[1].mm, size[2].mm, Geom::Point3d.new(0, 0, 0))
  t = Geom::Transformation.new(Geom::Vector3d.new(center[0].mm, center[1].mm, center[2].mm), angle * Math::PI / 180.0)
  i = $model.entities.add_instance(d, t)
  i.name = name if name
  i.layer = $model.layers[tag] || $model.layers.add(tag) if tag
  i
end
c1 = mk.call('S. COLUMN', [300, 300, 3600], [1000, 2000, top1 + 1800], 0.0, 'Cột A')
b1 = mk.call('s. beam', [4000, 200, 400], [2000, 3000, top2 - 200], 90.0)
n1 = mk.call(nil, [100, 100, 100], [0, 0, 0])
w1 = mk.call('A. WALL', [2000, 200, 3200], [0, 0, top1 + 1600], 0.0)
tilt = mk.call('A. WALL', [2000, 200, 3200], [0, 0, 0]); tilt.transformation.with_tilt(45)
res = S::SuScan.scan($model)
ok('quét: nhận diện theo tag (không phân biệt hoa thường) và đếm đối tượng chưa có tag', res[:objects].map { |o| o['kind'] }.sort == %w[beam column wall] && res[:untagged] == 1)
ok('đối tượng nghiêng: không nhận, báo lý do', res[:skipped].size == 1 && res[:skipped][0].include?('nghiêng'))
oc = res[:objects].find { |o| o['kind'] == 'column' }
ok('mô tả cột: tâm (1000, 2000), kích thước 300 x 300 x 3600, đáy và đỉnh đúng cốt', oc['center'] == [1000.0, 2000.0] && oc['size'] == [300.0, 300.0, 3600.0] && (oc['z0'] - top1).abs < 0.2 && (oc['z1'] - top2).abs < 0.2 && oc['name'] == 'Cột A' && oc['id'] == c1.entityID)
ob = res[:objects].find { |o| o['kind'] == 'beam' }
ok('mô tả dầm xoay 90 độ: góc 90, kích thước theo trục cục bộ giữ nguyên', ob['angle'] == 90.0 && ob['size'] == [4000.0, 200.0, 400.0])
ok('nhận dầm xoay 90 độ từ mô tả quét: trục dọc theo Y quanh x=2000', begin; r = SI.plan(base, [ob]); a = r[:patches][0]['set']['beams'].values[0]['free']; a['a'][0].round == 2000 && a['b'][0].round == 2000 && (a['b'][1] - a['a'][1]).abs == 4000.0; end)
plugin_made = mk.call('S. COLUMN', [300, 300, 3000], [5000, 5000, 1500]); plugin_made.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_structure')
ok('đối tượng do plugin dựng (VGD_BIM_SOURCE.plugin) không bị quét lại', S::SuScan.scan($model)[:objects].none? { |o| o['id'] == plugin_made.entityID })

# ---- Callback của cửa sổ: quét, nhận, gán tag ----
panel = S::Panel.new; dlg = panel.instance_variable_get(:@dialog); panel.show; call(dlg, 'ready')
call(dlg, 'su_scan', base)
ev = last_ev(dlg, 'su_objects')
ok('callback su_scan: gửi danh sách đối tượng kèm tầng đoán được và hình chiếu 4 đỉnh', ev && ev['objects'].size == 3 && ev['untagged'] == 1 && ev['objects'].find { |o| o['kind'] == 'column' }['level'] == 'sl_00000001' && ev['objects'][0]['footprint'].size == 4)
call(dlg, 'su_adopt', {'state' => base, 'ids' => [c1.entityID, w1.entityID]})
imp = last_ev(dlg, 'su_import')
ok('callback su_adopt: gửi bản vá, loại mới, danh sách đã nhận cho cửa sổ (sau khi người dùng đồng ý)', imp && imp['adopted'].size == 2 && imp['patches'][0]['set']['columns'].size == 1 && imp['patches'][0]['set']['walls'].size == 1)
call(dlg, 'su_adopt', {'state' => base, 'ids' => []})
ok('su_adopt rỗng / sai kiểu: báo lỗi, không gửi bản vá', last_ev(dlg, 'message')['error'] && count_ev(dlg, 'su_import') == 1)
call(dlg, 'su_adopt', {'state' => base, 'ids' => ['x']})
ok('su_adopt id không phải số nguyên: từ chối', last_ev(dlg, 'message')['error'] && count_ev(dlg, 'su_import') == 1)
$model.selection.clear; $model.selection.add(n1)
call(dlg, 'su_tag', {'kind' => 'beam'})
ok('gán tag dầm cho đối tượng đang chọn: đối tượng có tag S. BEAM, tag tạo theo bộ mẫu BIM (màu, thư mục)', n1.layer && n1.layer.name == 'S. BEAM' && $model.operations.include?([:start, 'VGD Structure · Gán tag']))
ok('sau khi gán tag: quét lại nhận ra đối tượng là dầm', S::SuScan.scan($model)[:objects].count { |o| o['kind'] == 'beam' } == 2)
call(dlg, 'su_tag', {'kind' => 'blob'})
ok('loại tag lạ: báo lỗi, không đổi gì', last_ev(dlg, 'message')['error'])
$model.selection.clear
call(dlg, 'su_tag', {'kind' => 'beam'})
ok('chưa chọn gì trong SketchUp: báo rõ, không mở thao tác', last_ev(dlg, 'message')['error'] && $model.operations.count { |o| o == [:start, 'VGD Structure · Gán tag'] } == 1)
$model.selection.add(plugin_made)
call(dlg, 'su_tag', {'kind' => 'beam'})
ok('đối tượng do plugin dựng không gán tag được', plugin_made.layer.name == 'S. COLUMN' && last_ev(dlg, 'message')['error'])

# ---- Chọn qua lại giữa SketchUp và mặt bằng ----
$model.selection.clear; $model.selection.add(c1); $model.selection.add(b1)
ok('đối tượng SketchUp đang chọn (có tag nhận diện): báo cho mặt bằng dưới dạng suobj kèm id', S::SuScan.selection_items($model).map { |i| [i[:kind], i[:ref]] }.sort == [['suobj', c1.entityID.to_s], ['suobj', b1.entityID.to_s]].sort)
n2 = mk.call(nil, [100, 100, 100], [0, 0, 0]); $model.selection.clear; $model.selection.add(n2); $model.selection.add(plugin_made)
ok('đối tượng chưa có tag hoặc do plugin dựng: không báo là suobj', S::SuScan.selection_items($model).empty?)
call(dlg, 'plan_select', {'level' => LV, 'items' => [{'kind' => 'suobj', 'ref' => c1.entityID.to_s}, {'kind' => 'suobj', 'ref' => '999999'}]})
ok('mặt bằng chọn đối tượng SketchUp: chọn đúng đối tượng trong SketchUp, bỏ qua id không còn', $model.selection.to_a == [c1])
call(dlg, 'plan_select', {'level' => LV, 'items' => [{'kind' => 'blob', 'ref' => '1'}]})
ok('loại chọn lạ vẫn bị từ chối', last_ev(dlg, 'message')['error'])
$model.selection.clear

# ---- Dựng thay đối tượng gốc, giữ VGD ID ----
GUID = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
c1.set_attribute('VGD_BIM_ID', 'guid', GUID)
plan = SI.plan(base, [S::SuScan.scan($model)[:objects].find { |o| o['id'] == c1.entityID }])
st_new = deep(base); st_new['levels'][0]['picks']['columns'].merge!(plan[:patches][0]['set']['columns'])
new_ref = plan[:patches][0]['set']['columns'].keys[0]
ops_before = $model.operations.size
S::AllBuilder.build($model, st_new.merge('level' => LV), [LV], %w[columns], nil, {'erase' => [c1.entityID], 'refs' => {"#{LV}:#{new_ref}" => c1.entityID}})
built = $model.entities.grep(Sketchup::Group).flat_map { |g| g.entities.to_a }.find { |e| e.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{LV}:#{new_ref}" }
ok('dựng có adopt: đối tượng SketchUp gốc bị xóa', !c1.valid? && S::SuScan.find($model, c1.entityID).nil?)
ok('bản dựng chuẩn của cột đã nhận GIỮ VGD ID của đối tượng gốc', built && built.get_attribute('VGD_BIM_ID', 'guid') == GUID)
ok('xóa đối tượng gốc và dựng nằm trong MỘT thao tác hoàn tác', $model.operations[ops_before..].count { |o| o[0] == :start } == 1)
c2 = mk.call('S. COLUMN', [300, 300, 3550], [9000, 9000, top1 + 1775]); c2.instance_variable_set(:@locked, true); c2.define_singleton_method(:locked?) { true }
ok('đối tượng bị khóa không bị xóa', S::SuScan.take($model, [c2.entityID]).empty? && c2.valid?)
ok('adopt không hợp lệ (erase không phải mảng số): bị từ chối', begin; call(dlg, 'build_all', {'levels' => [LV], 'state' => st_new.merge('level' => LV), 'kinds' => %w[columns], 'adopt' => {'erase' => ['x']}}); last_ev(dlg, 'message')['error']; end)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
