# Test tường nhiều lớp (Compound Structure kiểu Revit): kiểm tra dữ liệu lớp, kế hoạch, dựng từng lớp, khối lượng, vân tay. SketchUp giả lập: chưa xác minh trong SketchUp thật.
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

WT = S::WallTypes
def wtype(id, name, layers); {'id' => id, 'name' => name, 'layers' => layers}; end
L3 = [{'fn' => 'finish', 't' => 15, 'material' => 'Vữa trát', 'color' => '#F0EBDD'}, {'fn' => 'structure', 't' => 170, 'material' => 'Gạch'}, {'fn' => 'finish', 't' => 15}].freeze
T3 = 'wt_00000003'

# ---- Dữ liệu lớp ----
old = WT.normalize!([{'id' => 'wt_00000001', 'name' => 'T200', 't' => 200}])
ok('dữ liệu cũ (chỉ có t): thành một lớp kết cấu, t giữ nguyên', old[0]['layers'] == [{'fn' => 'structure', 't' => 200.0, 'material' => ''}] && old[0]['t'] == 200.0)
good = WT.normalize!([wtype(T3, 'T200 trát', deep(L3))])
ok('3 lớp: t = tổng 200, màu viết hoa đổi thường, màu không chọn thì không ghi', good[0]['t'] == 200.0 && good[0]['layers'][0]['color'] == '#f0ebdd' && !good[0]['layers'][1].key?('color'))
ok('layers gửi cùng t sai: t tính lại theo tổng lớp', WT.normalize!([wtype(T3, 'A', deep(L3)).merge('t' => 999)])[0]['t'] == 200.0)
bad = ->(layers) { error_of { WT.normalize!([wtype(T3, 'A', layers)]) } }
ok('không có lớp kết cấu: từ chối', bad.call([{'fn' => 'finish', 't' => 100}]).to_s.include?('lớp kết cấu'))
ok('quá 5 lớp: từ chối', bad.call(Array.new(6) { {'fn' => 'structure', 't' => 50} }).to_s.include?('1 đến 5'))
ok('lớp rỗng: từ chối', bad.call([]).to_s.include?('1 đến 5'))
ok('chức năng lạ: từ chối', bad.call([{'fn' => 'blob', 't' => 100}]).to_s.include?('chức năng'))
ok('bề dày lớp 0, âm, chữ: từ chối', [0, -5, 'x', nil, 1001].all? { |t| bad.call([{'fn' => 'structure', 't' => t}]).to_s.include?('lớp 1') })
ok('màu sai dạng: từ chối', bad.call([{'fn' => 'structure', 't' => 100, 'color' => 'red'}]).to_s.include?('#rrggbb'))
ok('tên vật liệu quá dài hoặc có ký tự điều khiển: từ chối', bad.call([{'fn' => 'structure', 't' => 100, 'material' => 'x' * 25}]).to_s.include?('vật liệu') && bad.call([{'fn' => 'structure', 't' => 100, 'material' => "a\nb"}]).to_s.include?('vật liệu'))
ok('tổng bề dày ngoài 50..1000: từ chối', bad.call([{'fn' => 'structure', 't' => 30}]).to_s.include?('tổng bề dày') && bad.call([{'fn' => 'structure', 't' => 600}, {'fn' => 'finish', 't' => 600}]).to_s.include?('tổng bề dày'))
ok('layers không phải mảng: từ chối', error_of { WT.normalize!([{'id' => T3, 'name' => 'A', 'layers' => 'x'}]) }.to_s.include?('1 đến 5'))
ok('layers_for: tường đặc đơn giản là nil, nhiều lớp hoặc có vật liệu thì có', WT.layers_for(old[0]).nil? && WT.layers_for(good[0]).size == 3 && !WT.layers_for(WT.normalize!([wtype(T3, 'B', [{'fn' => 'structure', 't' => 200, 'material' => 'BT'}])])[0]).nil?)
ok('lớp không chọn màu lấy màu mặc định theo chức năng', WT.layers_for(good[0])[1][:color] == WT::DEFAULT_COLORS['structure'] && WT.layers_for(good[0])[0][:color] == '#f0ebdd')

# ---- Kế hoạch và dựng ----
def layered_state(layers = L3, walls: {'x:B:1-2' => {'type' => T3}}, opens: {})
  st = S::State.default
  st['wall_types'] = [S::WallTypes.default[0], wtype(T3, 'T200 trát', deep(layers))]
  st['levels'][0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => walls, 'openings' => opens, 'slabs' => {}, 'ceilings' => {}}
  S::State.normalize!(st)
end
st = layered_state
plan = S::WallPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], LV, st['opening_types'])
item = plan[:items][0]
ok('kế hoạch: tường nhiều lớp mang layers (3 lớp, tổng 200) và t = 200', item[:layers].size == 3 && item[:t] == 200.0 && item[:layers].sum { |l| l[:t] } == 200.0)
plain = layered_state(walls: {'x:B:1-2' => {}})
pitem = S::WallPlan.plan(plain['grid'], plain['types'], plain['beam_types'], plain['wall_types'], plain['levels'], LV, plain['opening_types'])[:items][0]
ok('kế hoạch: tường đặc đơn giản không có khóa layers', !pitem.key?(:layers))
fp = ->(i) { S::ModelSync.fingerprint('wall', i) }
ok('vân tay đổi khi đổi bề dày lớp, vật liệu hoặc màu; không đổi nếu dữ liệu y nguyên', fp.call(item) == fp.call(item.dup) && fp.call(item) != fp.call(item.merge(layers: item[:layers].map { |l| l.merge(t: l[:t] + 1) })) && fp.call(item) != fp.call(item.merge(layers: item[:layers].map { |l| l.merge(material: 'x') })) && fp.call(item) != fp.call(item.merge(layers: item[:layers].map { |l| l.merge(color: '#000000') })))
ok('vân tay tường đặc đơn giản không đổi so với trước khi có lớp (không có layers trong vân tay)', fp.call(pitem) == S::ModelSync.fingerprint('wall', pitem.reject { |k, _| k == :layers }))

m = Sketchup::Model.new
S::WallBuilder.build(m, st, [LV])
inst = m.entities.grep(Sketchup::Group)[0].entities.to_a[0]
parts = inst.definition.entities.grep(Sketchup::Group)
ok('dựng: định nghĩa tường có 3 nhóm con, mỗi lớp một nhóm, tên ghi chức năng và vật liệu', parts.size == 3 && parts[0].name.include?('Hoàn thiện') && parts[0].name.include?('Vữa trát') && parts[1].name.include?('Kết cấu'))
spans = parts.map { |g| ys = g.entities.grep(Sketchup::Face)[0].points.map { |pt| pt.y * 25.4 }; [ys.min.round(1), ys.max.round(1)] }
ok('dựng: mỗi lớp nằm đúng chỗ theo bề dày, nối liền từ -100 đến +100 (15, 170, 15 mm)', spans == [[-100.0, -85.0], [-85.0, 85.0], [85.0, 100.0]])
ok('dựng: mỗi lớp có vật liệu màu riêng, lớp 1 đúng màu chọn (#f0ebdd = 240, 235, 221)', parts.map(&:material).none?(&:nil?) && parts[0].material.color.rgb == [240, 235, 221] && parts[1].material.color.rgb != parts[0].material.color.rgb)
ok('dựng: lớp có màu mặc định riêng (kết cấu, hoàn thiện) tạo vật liệu riêng, dựng thêm tường cùng loại không nhân vật liệu', m.materials.to_a.size == 3 && begin; n0 = m.materials.to_a.size; S::WallBuilder.build(m, st, [LV]); m.materials.to_a.size == n0; end)
dims = JSON.parse(inst.get_attribute(D, 'dims'))
ok('dims có khối lượng từng lớp: diện tích = dài x cao, thể tích = diện tích x bề dày', dims['layers'].size == 3 && dims['layers'][1]['thickness'] == 170.0 && (dims['layers'][1]['area'] - item[:length] * item[:height] / 1e6).abs < 1e-3 && (dims['layers'][1]['volume'] - dims['layers'][1]['area'] * 0.17).abs < 1e-3 && dims['layers'][0]['material'] == 'Vữa trát')
ok('dims tường đặc đơn giản: không có khóa layers (BIM đọc như cũ)', !JSON.parse(begin; mp = Sketchup::Model.new; S::WallBuilder.build(mp, plain, [LV]); mp.entities.grep(Sketchup::Group)[0].entities.to_a[0].get_attribute(D, 'dims'); end).key?('layers'))
ok('dựng: tường đặc đơn giản vẫn không có nhóm con (như trước)', begin; mp2 = Sketchup::Model.new; S::WallBuilder.build(mp2, plain, [LV]); mp2.entities.grep(Sketchup::Group)[0].entities.to_a[0].definition.entities.grep(Sketchup::Group).empty?; end)

# ---- Tường nhiều lớp có cửa ----
ot = S::OpeningTypes.default
sto = layered_state(opens: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => ot.find { |t| t['kind'] == 'door' }['id'], 'pos' => 1500}})
mo = Sketchup::Model.new
S::WallBuilder.build(mo, sto, [LV])
io = mo.entities.grep(Sketchup::Group)[0].entities.to_a[0]
ok('tường nhiều lớp có cửa: mỗi lớp đều bị khoét lỗ (mỗi nhóm lớp có mặt nhỏ bị xóa)', io.definition.entities.grep(Sketchup::Group).all? { |g| g.entities.grep(Sketchup::Face).size >= 2 })
dimso = JSON.parse(io.get_attribute(D, 'dims'))
ok('khối lượng lớp trừ diện tích cửa', dimso['layers'][1]['area'] < dims['layers'][1]['area'] && dimso['openings'] == 1)

# ---- Dựng lại khi đổi lớp ----
st2 = layered_state([{'fn' => 'finish', 't' => 20}, {'fn' => 'structure', 't' => 160}, {'fn' => 'finish', 't' => 20}])
ok('đổi bề dày lớp (tổng vẫn 200): vân tay phần tử trong model báo lệch', S::ModelSync.status(m, st2, LV)[:items]['wall|x:B:1-2'] == 'stale')
ok('dữ liệu y nguyên: báo khớp', S::ModelSync.status(m, st, LV)[:items]['wall|x:B:1-2'] == 'ok')

# ---- Tường xiên nhiều lớp ----
sto2 = layered_state(walls: {'fw_00000001' => {'type' => T3, 'free' => {'a' => [0, 0], 'b' => [3000, 2000]}}})
mx = Sketchup::Model.new
S::WallBuilder.build(mx, sto2, [LV])
ix = mx.entities.grep(Sketchup::Group)[0].entities.to_a[0]
ok('tường xiên nhiều lớp: dựng được, dùng định nghĩa nhiều lớp và xoay', ix.definition.entities.grep(Sketchup::Group).size == 3 && ix.transformation.angle.abs > 0.1)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
