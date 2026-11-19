# Test cửa đi: hướng mở (flip) và bản lề (mirror) kiểu Revit: dữ liệu, kế hoạch, vân tay, tay nắm trong 3D, đảo đầu tường. SketchUp giả lập: chưa xác minh trong SketchUp thật.
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

door_id = ot.find { |t| t['kind'] == 'door' }['id']
def hand_state(door_id, extra = {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {'x:B:1-2' => {}}, 'openings' => {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => door_id, 'pos' => 1500}.merge(extra)}, 'slabs' => {}, 'ceilings' => {}}
  S::State.normalize!(st)
end
def op_item(st)
  S::OpeningPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['opening_types'], st['levels'], LV)[:items][0]
end

# ---- Dữ liệu ----
ok('cửa cũ (không có mirror): không có khóa mirror trong dữ liệu chuẩn hóa và trong mục kế hoạch', !hand_state(door_id)['levels'][0]['picks']['openings']['op_00000001'].key?('mirror') && !op_item(hand_state(door_id)).key?(:mirror))
st_m = hand_state(door_id, 'mirror' => true)
ok('mirror true: giữ lại và đi vào mục kế hoạch', st_m['levels'][0]['picks']['openings']['op_00000001']['mirror'] == true && op_item(st_m)[:mirror] == true)
ok('mirror false: không lưu (dữ liệu cũ không đổi)', !hand_state(door_id, 'mirror' => false)['levels'][0]['picks']['openings']['op_00000001'].key?('mirror'))
ok('mirror không phải true / false: từ chối', ['x', 1, nil].all? { |v| error_of { hand_state(door_id, 'mirror' => v) }.to_s.include?('bản lề') })
fp = ->(i) { S::ModelSync.fingerprint('opening', i) }
ok('vân tay đổi khi đổi bản lề; cửa cũ giữ vân tay như trước', fp.call(op_item(st_m)) != fp.call(op_item(hand_state(door_id))) && fp.call(op_item(hand_state(door_id))) == S::ModelSync.fingerprint('opening', op_item(hand_state(door_id)).reject { |k, _| k == :mirror }))

# ---- Dựng: tay nắm ----
def built(st)
  m = Sketchup::Model.new
  S::OpeningBuilder.build(m, st, [LV])
  inst = m.entities.grep(Sketchup::Group)[0].entities.to_a[0]
  [m, inst]
end
def handle_box(inst) # mặt đùn 30 mm = tay nắm: [u nhỏ nhất, u lớn nhất, độ lệch y nhỏ nhất, lớn nhất] (mm)
  f = inst.definition.entities.grep(Sketchup::Face).find { |x| (x.height * 25.4).round(1) == 30.0 }
  pts = f.points.map { |p| [p.x * 25.4, p.y * 25.4] }
  [pts.map(&:first).min.round(1), pts.map(&:first).max.round(1), pts.map(&:last).min.round(1), pts.map(&:last).max.round(1)]
end
_, d_plain = built(hand_state(door_id))
_, d_mirror = built(st_m)
_, d_flip = built(hand_state(door_id, 'flip' => true))
w = ot.find { |t| t['kind'] == 'door' }['w']
hp = handle_box(d_plain); hm = handle_box(d_mirror); hf = handle_box(d_flip)
ok('tay nắm ở đầu cuối cánh khi bản lề ở đầu đầu (cách mép tự do 90 mm)', (w - 5 - 50 - 90 - 60 - hp[0]).abs <= 25 + 1e-6 && hp[1] - hp[0] == 60.0 && hp[0] > w / 2)
ok('mirror: tay nắm chuyển sang đầu đầu, đối xứng', hm[0] < w / 2 && (hm[0] + hm[1]) / 2 - (w - (hp[0] + hp[1]) / 2) < 1e-6 && (hm[0] - (w - hp[1])).abs < 1e-6)
ok('flip: tay nắm sang phía mặt kia của tường (cùng bên cánh mở)', (hf[2] + hf[3]) / 2 * (hp[2] + hp[3]) / 2 < 0)
leaf_y = ->(inst) { f = inst.definition.entities.grep(Sketchup::Face).find { |x| (x.height * 25.4).round(1) == 40.0 }; ys = f.points.map { |pt| pt.y * 25.4 }; [ys.min, ys.max] }
lp = leaf_y.call(d_plain); lf2 = leaf_y.call(d_flip)
ok('tay nắm nhô ra khỏi mặt cánh về phía cánh mở: không lật thì ở phía +Y của cánh, lật thì ở phía -Y', hp[2] >= lp[1] - 0.5 && hf[3] <= lf2[0] + 0.5)
ok('placement ghi mirror chỉ khi true', !JSON.parse(d_plain.get_attribute(D, 'placement')).key?('mirror') && JSON.parse(d_mirror.get_attribute(D, 'placement'))['mirror'] == true)
ok('hai cửa khác bản lề dùng hai định nghĩa khác nhau', d_plain.definition.name != d_mirror.definition.name && d_mirror.definition.name.include?('bản lề cuối'))

# ---- Đảo đầu tường (sửa trong SketchUp) ----
st_w = S::State.default
st_w['levels'][0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {'fw_00000001' => {'free' => {'a' => [0, 0], 'b' => [4000, 0]}}}, 'openings' => {'op_00000001' => {'wall' => 'fw_00000001', 'type' => door_id, 'pos' => 1000}}, 'slabs' => {}, 'ceilings' => {}}
st_w = S::State.normalize!(st_w)
patch = S::ModelEdit.move(st_w, {'kind' => 'wall', 'level' => LV, 'ref' => 'fw_00000001', 'from' => [0, 0], 'to' => [4000, 0], 'dangle' => 180.0})
moved = patch['set']['openings'].values.first
ok('tường xoay 180 độ (hai đầu đổi chỗ): cửa đổi vị trí, đổi mặt cánh và đổi bản lề', moved['mirror'] == true && moved['flip'] == true && moved['pos'] == 3000.0)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
