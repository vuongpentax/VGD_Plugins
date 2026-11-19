# Test lớp hoàn thiện sàn, trần (kiểu Revit): dữ liệu lớp của tầng, tổng đè lên cán nền / dày trần, kế hoạch, dựng từng lớp xếp chồng, khối lượng, vân tay. SketchUp giả lập: chưa xác minh trong SketchUp thật.
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
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/sketchup_import core/state core/preview model_sync edit_sync su_scan model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
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

LL = S::LayerList
FLOOR = [{'fn' => 'finish', 't' => 10, 'material' => 'Gạch lát', 'color' => '#C9C2B6'}, {'fn' => 'substrate', 't' => 30, 'material' => 'Vữa cán'}].freeze
CEIL = [{'fn' => 'finish', 't' => 9, 'material' => 'Thạch cao'}, {'fn' => 'insulation', 't' => 15}].freeze
def lerr; yield; nil; rescue S::Levels::Error => e; e.message; end

# ---- Danh sách lớp ----
ok('rỗng hoặc nil: []', LL.normalize!(nil, 'sàn', S::Levels::SCREED_RANGE) == [] && LL.normalize!([], 'sàn', S::Levels::SCREED_RANGE) == [])
good = LL.normalize!(deep(FLOOR), 'sàn', S::Levels::SCREED_RANGE)
ok('2 lớp hợp lệ: tổng 40, màu thường, lớp không màu không có khóa color', LL.total(good) == 40.0 && good[0]['color'] == '#c9c2b6' && !good[1].key?('color'))
bad = ->(layers, range = S::Levels::SCREED_RANGE) { lerr { LL.normalize!(layers, 'sàn', range) } }
ok('chức năng kết cấu hoặc lạ không được dùng ở lớp hoàn thiện', bad.call([{'fn' => 'structure', 't' => 10}]).to_s.include?('chức năng') && bad.call([{'fn' => 'x', 't' => 10}]).to_s.include?('chức năng'))
ok('quá 5 lớp: từ chối', bad.call(Array.new(6) { {'fn' => 'finish', 't' => 5} }).to_s.include?('1 đến 5'))
ok('bề dày lớp sai (0, âm, chữ, nil, > 1000): từ chối', [0, -1, 'x', nil, 1001].all? { |t| bad.call([{'fn' => 'finish', 't' => t}]).to_s.include?('lớp 1') })
ok('màu sai và vật liệu sai: từ chối', bad.call([{'fn' => 'finish', 't' => 10, 'color' => 'red'}]).to_s.include?('#rrggbb') && bad.call([{'fn' => 'finish', 't' => 10, 'material' => 'x' * 25}]).to_s.include?('vật liệu'))
ok('tổng ngoài khoảng cán nền (0..300) hoặc dày trần (5..100): từ chối', bad.call([{'fn' => 'finish', 't' => 200}, {'fn' => 'finish', 't' => 200}]).to_s.include?('tổng bề dày') && lerr { LL.normalize!([{'fn' => 'finish', 't' => 2}], 'trần', S::Levels::CEILING_THICKNESS_RANGE) }.to_s.include?('tổng bề dày'))

# ---- Tầng ----
def lv_state(floor: nil, ceiling: nil, slabs: {'1-2/A-B' => {}}, ceilings: {'1-2/A-B' => {}})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'openings' => {}, 'slabs' => slabs, 'ceilings' => ceilings}
  st['levels'][0]['floor_layers'] = deep(floor) if floor
  st['levels'][0]['ceiling_layers'] = deep(ceiling) if ceiling
  S::State.normalize!(st)
end
plain = lv_state
ok('tầng không có lớp: không có khóa floor_layers / ceiling_layers, screed và dày trần giữ nguyên', !plain['levels'][0].key?('floor_layers') && !plain['levels'][0].key?('ceiling_layers') && plain['levels'][0]['screed'] == 50.0 && plain['levels'][0]['ceiling_thickness'] == 9.0)
st = lv_state(floor: FLOOR, ceiling: CEIL)
l0 = st['levels'][0]
ok('có lớp: tổng ĐÈ lên cán nền (40) và dày trần (24); lớp được giữ', l0['screed'] == 40.0 && l0['ceiling_thickness'] == 24.0 && l0['floor_layers'].size == 2 && l0['ceiling_layers'].size == 2)
st_override = S::State.default; st_override['levels'][0]['screed'] = 'rác'; st_override['levels'][0]['floor_layers'] = deep(FLOOR)
ok('số cán nền cũ sai không làm hỏng khi đã có lớp (tổng đè lên)', error_of { S::State.normalize!(st_override) }.nil?)
ok('lỗi lớp báo kèm tên tầng', error_of { S::State.normalize!(S::State.default.tap { |s| s['levels'][0]['floor_layers'] = [{'fn' => 'finish', 't' => 'x'}] }) }.to_s.start_with?('Tầng “Tầng 1”'))

# ---- Kế hoạch ----
slab_item = ->(s) { S::SlabPlan.plan(s['grid'], s['levels'], LV, s['types'], s['beam_types'])[:items][0] }
si = slab_item.call(st)
ok('sàn có lớp: kết cấu (dưới) rồi hoàn thiện xếp lên (Vữa cán 30 rồi Gạch lát 10 phía trên cùng)', si[:layers].map { |l| [l[:fn], l[:t]] } == [['structure', 120.0], ['substrate', 30.0], ['finish', 10.0]])
ok('cốt: mặt trên sàn kết cấu = cao độ tầng - tổng lớp hoàn thiện (0 - 40)', si[:z_top] == -40.0 && si[:z_bottom] == -160.0)
ok('sàn không lớp: không có khóa layers', !slab_item.call(plain).key?(:layers))
ci = S::CeilingPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], LV, st['opening_types'])[:items][0]
ok('trần có lớp: giữ thứ tự từ mặt dưới lên, dày = tổng 24', ci[:layers].map { |l| [l[:fn], l[:t]] } == [['finish', 9.0], ['insulation', 15.0]] && ci[:thickness] == 24.0 && (ci[:z_top] - ci[:z_bottom]).round(1) == 24.0)
fp = ->(kind, i) { S::ModelSync.fingerprint(kind, i) }
ok('vân tay sàn đổi khi đổi lớp; sàn không lớp giữ vân tay cũ', fp.call('slab', si) != fp.call('slab', si.merge(layers: si[:layers].map { |l| l.merge(material: 'x') })) && fp.call('slab', slab_item.call(plain)) == fp.call('slab', slab_item.call(plain).reject { |k, _| k == :layers }))

# ---- Dựng ----
m = Sketchup::Model.new
S::PlateBuilder.build(m, st, [LV], 'slabs')
inst = m.entities.grep(Sketchup::Group)[0].entities.to_a[0]
parts = inst.definition.entities.grep(Sketchup::Group)
ok('dựng sàn có lớp: 3 nhóm con xếp chồng, tên ghi chức năng và vật liệu', parts.size == 3 && parts[0].name.include?('Kết cấu') && parts[1].name.include?('Lớp nền') && parts[2].name.include?('Gạch lát'))
zs = parts.map { |g| zz = g.entities.grep(Sketchup::Face)[0].points.map { |pt| pt.z * 25.4 }.min.round(1); [zz, (g.entities.grep(Sketchup::Face)[0].height * 25.4).round(1)] }
ok('mỗi lớp bắt đầu đúng độ cao cộng dồn (0, 120, 150) và đùn đúng bề dày (120, 30, 10)', zs == [[0.0, 120.0], [120.0, 30.0], [150.0, 10.0]])
ok('mỗi lớp có vật liệu màu; lớp gạch lát đúng màu chọn', parts.all?(&:material) && parts[2].material.color.rgb == [201, 194, 182])
dims = JSON.parse(inst.get_attribute(D, 'dims'))
ok('dims có khối lượng từng lớp: thể tích = diện tích x bề dày', dims['layers'].size == 3 && dims['layers'].all? { |l| (l['volume'] - l['area'] * l['thickness'] / 1000.0).abs < 1e-3 } && dims['layers'][2]['material'] == 'Gạch lát')
mp = Sketchup::Model.new; S::PlateBuilder.build(mp, plain, [LV], 'slabs')
ip = mp.entities.grep(Sketchup::Group)[0].entities.to_a[0]
ok('sàn không lớp: không có nhóm con, dims không có layers', ip.definition.entities.grep(Sketchup::Group).empty? && !JSON.parse(ip.get_attribute(D, 'dims')).key?('layers'))
mc = Sketchup::Model.new; S::PlateBuilder.build(mc, st, [LV], 'ceilings')
ic = mc.entities.grep(Sketchup::Group)[0].entities.to_a[0]
cparts = ic.definition.entities.grep(Sketchup::Group)
ok('dựng trần có lớp: 2 nhóm con xếp chồng từ mặt dưới (0 rồi 9 mm)', cparts.size == 2 && cparts.map { |g| g.entities.grep(Sketchup::Face)[0].points.map { |pt| (pt.z * 25.4).round(1) }.min } == [0.0, 9.0])
ok('trạng thái model khớp dữ liệu khi lớp y nguyên, lệch khi đổi lớp', S::ModelSync.status(m, st, LV)[:items]['slab|1-2/A-B'] == 'ok' && S::ModelSync.status(m, lv_state(floor: [{'fn' => 'finish', 't' => 10}, {'fn' => 'substrate', 't' => 30}]), LV)[:items]['slab|1-2/A-B'] == 'stale')

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
