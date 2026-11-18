# Test bảng thống kê (Schedule): gom theo tầng và loại, số lượng, dài, diện tích, thể tích khớp kế hoạch dựng. Logic thuần, không cần SketchUp.
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
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/schedule core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
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

def sched_state(cols: {}, beams: {}, walls: {}, opens: {}, slabs: {}, ceilings: {}, floor: nil)
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => cols, 'beams' => beams, 'walls' => walls, 'openings' => opens, 'slabs' => slabs, 'ceilings' => ceilings}
  st['levels'][0]['floor_layers'] = floor if floor
  S::State.normalize!(st)
end
sec = ->(res, kind) { res[:sections].find { |s| s[:kind] == kind } }
door = S::OpeningTypes.default.find { |t| t['kind'] == 'door' }
win = S::OpeningTypes.default.find { |t| t['kind'] == 'window' }

empty = S::Schedule.build(sched_state)
ok('không chọn gì: đủ 6 mục, mọi bảng rỗng, tổng 0', empty[:sections].map { |s| s[:kind] } == S::Schedule::KINDS && empty[:sections].all? { |s| s[:rows].empty? && s[:total][:count] == 0 } && empty[:issues].empty?)

st = sched_state(cols: {'1-A' => {}, '2-A' => {}, '1-B' => {}}, beams: {'x:A:1-2' => {}}, walls: {'x:B:1-2' => {}}, opens: {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => door['id'], 'pos' => 1000}, 'op_00000002' => {'wall' => 'x:B:1-2', 'type' => win['id'], 'pos' => 2800}}, slabs: {'1-2/A-B' => {}}, ceilings: {'1-2/A-B' => {}})
res = S::Schedule.build(st)
cols = sec.call(res, 'columns')
ok('cột: 3 cột cùng loại gom thành MỘT dòng, đếm 3, kèm tên tầng và tiết diện', cols[:rows].size == 1 && cols[:rows][0][:count] == 3 && cols[:rows][0][:level_name] == 'Tầng 1' && cols[:rows][0][:values]['size'] == '300 × 300')
ok('cột: thể tích = 3 x 0.3 x 0.3 x cao (m³), tổng khớp', (cols[:rows][0][:values]['volume'] - 3 * 0.3 * 0.3 * cols[:rows][0][:values]['height'].to_f / 1000.0).abs < 1e-3 && cols[:total]['volume'] == cols[:rows][0][:values]['volume'])
plan_cols = S::ColumnPlan.plan(st['grid'], st['types'], st['levels'], LV)
ok('chiều cao cột trong bảng = chiều cao kế hoạch dựng', cols[:rows][0][:values]['height'] == (plan_cols[:height] == plan_cols[:height].round ? plan_cols[:height].round.to_s : plan_cols[:height].to_s))
beams = sec.call(res, 'beams')
bp = S::BeamPlan.plan(st['grid'], st['types'], st['beam_types'], st['levels'], LV)[:items][0]
ok('dầm: tổng dài (m) và thể tích khớp kế hoạch dựng', beams[:rows].size == 1 && (beams[:rows][0][:values]['length'] - bp[:length] / 1000.0).abs < 1e-3 && (beams[:rows][0][:values]['volume'] - bp[:w] * bp[:h] * bp[:length] / 1e9).abs < 1e-3)
walls = sec.call(res, 'walls')
wp = S::WallPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], LV, st['opening_types'])[:items][0]
ok('tường: diện tích = dài x cao TRỪ diện tích cửa', (walls[:rows][0][:values]['area'] - (wp[:length] * wp[:height] / 1e6 - wp[:openings_area])).abs < 1e-3 && walls[:rows][0][:values]['area'] < wp[:length] * wp[:height] / 1e6)
ok('tường: thể tích = diện tích x bề dày', (walls[:rows][0][:values]['volume'] - walls[:rows][0][:values]['area'] * wp[:t] / 1000.0).abs < 1e-3)
ops = sec.call(res, 'openings')
ok('cửa: 2 dòng (cửa đi, cửa sổ) mỗi dòng 1, kèm loại và kích thước', ops[:rows].size == 2 && ops[:rows].map { |r| r[:count] } == [1, 1] && ops[:rows].map { |r| r[:values]['kind'] }.sort == ['Cửa sổ', 'Cửa đi'].sort && ops[:total][:count] == 2)
slabs = sec.call(res, 'slabs')
sp = S::SlabPlan.plan(st['grid'], st['levels'], LV, st['types'], st['beam_types'])[:items][0]
ok('sàn: diện tích lấy theo hình ĐÃ lùi theo dầm, cột (không phải cả ô)', (slabs[:rows][0][:values]['area'] - sp[:area]).abs < 1e-3 && slabs[:total]['area'] == slabs[:rows][0][:values]['area'])
ok('trần: có diện tích và thể tích', sec.call(res, 'ceilings')[:rows][0][:values]['area'] > 0 && sec.call(res, 'ceilings')[:rows][0][:values]['volume'] > 0)

# Nhiều tầng, nhiều loại
st2 = S::State.default
st2['wall_types'] = [S::WallTypes.default[0], {'id' => 'wt_00000002', 'name' => 'T100', 'layers' => [{'fn' => 'structure', 't' => 100}]}]
st2['levels'][0]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {'x:B:1-2' => {}, 'y:1:A-B' => {'type' => 'wt_00000002'}}, 'openings' => {}, 'slabs' => {}, 'ceilings' => {}}
st2['levels'][1]['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'openings' => {}, 'slabs' => {'1-2/A-B' => {}}, 'ceilings' => {}}
r2 = S::Schedule.build(S::State.normalize!(st2))
ok('nhiều loại tường cùng tầng: tách dòng theo loại (T200, T100)', sec.call(r2, 'walls')[:rows].map { |r| r[:type] }.sort == %w[T100 T200])
ok('tầng trên cùng chỉ có sàn: sàn tầng 2 vào bảng, tên tầng đúng', sec.call(r2, 'slabs')[:rows].size == 1 && sec.call(r2, 'slabs')[:rows][0][:level_name] == 'Tầng 2')
ok('dòng theo tầng: mỗi tầng dùng mã tầng riêng', sec.call(r2, 'slabs')[:rows][0][:level] == 'sl_00000002')
# Kế hoạch lỗi không làm hỏng bảng
broken = deep(st); broken['levels'][1]['picks']['ceilings'] = {'1-2/A-B' => {}}
r3 = S::Schedule.build(broken)
ok('tầng trên cùng có trần đã chọn: bị báo trong issues, các bảng khác vẫn đủ', r3[:issues].size == 1 && r3[:issues][0].include?('Trần') && sec.call(r3, 'columns')[:rows].size == 1)
ok('lớp hoàn thiện sàn không làm đổi diện tích sàn trong bảng', (sec.call(S::Schedule.build(sched_state(slabs: {'1-2/A-B' => {}}, floor: [{'fn' => 'finish', 't' => 10}])), 'slabs')[:rows][0][:values]['area'] - sec.call(S::Schedule.build(sched_state(slabs: {'1-2/A-B' => {}})), 'slabs')[:rows][0][:values]['area']).abs < 1e-6)

ok('sàn: thể tích = diện tích x bề dày / 1000 (m³)', (slabs[:rows][0][:values]['volume'] - sp[:area] * sp[:thickness] / 1000.0).abs < 1e-3)
cp = S::CeilingPlan.plan(st['grid'], st['types'], st['beam_types'], st['wall_types'], st['levels'], LV, st['opening_types'])[:items][0]
ok('trần: thể tích = diện tích x bề dày / 1000 (m³)', (sec.call(res, 'ceilings')[:rows][0][:values]['volume'] - cp[:area] * cp[:thickness] / 1000.0).abs < 1e-3)
st_two = S::State.default
st_two['levels'].each { |l| l['picks'] = {'columns' => {}, 'beams' => {}, 'walls' => {}, 'openings' => {}, 'slabs' => {'1-2/A-B' => {}}, 'ceilings' => {}} }
r_two = sec.call(S::Schedule.build(S::State.normalize!(st_two)), 'slabs')
ok('cùng loại, hai tầng: tách thành 2 dòng theo tầng (không gộp qua tầng), tổng cộng cả hai', r_two[:rows].size == 2 && r_two[:rows].map { |r| r[:level] }.uniq.size == 2 && r_two[:total][:count] == 2)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
