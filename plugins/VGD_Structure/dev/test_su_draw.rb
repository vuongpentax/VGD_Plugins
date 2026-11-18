# Test vẽ trực tiếp trong SketchUp (phần Ruby): phím Enter / Backspace và ô giá trị chuyển về cửa sổ, xem trước vẽ trong khung nhìn, dựng chỉ loại đã đổi,
# nạp lại cửa sổ khi Hoàn tác / Làm lại đổi dữ liệu, menu "Vẽ trong SketchUp". SketchUp giả lập: phần chạy thật chưa xác minh trong SketchUp.
# Chạy: ruby dev/test_su_draw.rb
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

$model = Sketchup::Model.new
panel = S::Panel.new
dlg = panel.instance_variable_get(:@dialog)
panel.show

# ---- Phím và ô giá trị trong SketchUp ----
call(dlg, 'su_pick_start')
tool = $model.tool
view = Sketchup::FakeView.new
ok('Enter trong SketchUp: gửi su_key Enter, báo đã xử lý (true)', tool.onKeyDown(13, 0, 0, view) == true && last_ev(dlg, 'su_key') == {'key' => 'Enter'})
ok('Backspace trong SketchUp: gửi su_key Backspace', tool.onKeyDown(8, 0, 0, view) == true && last_ev(dlg, 'su_key') == {'key' => 'Backspace'})
n = count_ev(dlg, 'su_key')
ok('phím khác (chữ A): bỏ qua cho SketchUp xử lý, không gửi gì', tool.onKeyDown(65, 0, 0, view) == false && count_ev(dlg, 'su_key') == n)
tool.onUserText('1500', view)
ok('gõ số vào ô giá trị của SketchUp + Enter: gửi su_text nguyên văn', last_ev(dlg, 'su_text') == {'text' => '1500'} && view.invalidated > 0)
tool.onCancel(0, view)
ok('Esc: gửi su_key Escape', last_ev(dlg, 'su_key') == {'key' => 'Escape'})

# ---- Xem trước vẽ trong khung nhìn ----
payload = {'z' => 3600, 'items' => [{'t' => 'line', 'pts' => [[0, 0], [1000, 0]]}, {'t' => 'poly', 'pts' => [[0, 0], [1000, 0], [1000, 500]]}, {'t' => 'dot', 'pts' => [[500, 500]]}]}
call(dlg, 'su_ghost', payload)
ok('xem trước nhận từ cửa sổ: giữ đủ 3 mục, cao độ 3600, làm mới khung nhìn', panel.ghost_items.size == 3 && panel.ghost_z == 3600.0)
tool.draw(view)
kinds = view.draw_calls.map(&:first)
ok('vẽ: đường = 1 polyline 2 điểm, đa giác khép kín (thêm điểm đầu cuối), chấm = points', kinds == %i[polyline polyline points] && view.draw_calls[0][1].size == 2 && view.draw_calls[1][1].size == 4 && view.draw_calls[1][1].first.x == view.draw_calls[1][1].last.x)
ok('điểm xem trước nằm ở cao độ tầng 3600 mm (inch × 25,4) và tọa độ mm đổi đúng', (view.draw_calls[0][1][1].z * 25.4 - 3600).abs < 1e-6 && (view.draw_calls[0][1][1].x * 25.4 - 1000).abs < 1e-6)
call(dlg, 'su_ghost', {'z' => 0, 'items' => [{'t' => 'blob', 'pts' => [[0, 0]]}, {'t' => 'line', 'pts' => 'x'}, {'t' => 'line', 'pts' => [[0, 'a'], [1, 1]]}, 5, {'t' => 'line', 'pts' => [[0, 0], [5, 5]]}]})
ok('mục xem trước sai (loại lạ, điểm không phải số, không phải đối tượng) bị bỏ, mục đúng giữ', panel.ghost_items.size == 1)
call(dlg, 'su_ghost', {'z' => 'x', 'items' => 'x'})
ok('dữ liệu xem trước sai hoàn toàn: rỗng, cao độ về 0, không lỗi', panel.ghost_items.empty? && panel.ghost_z == 0.0)
call(dlg, 'su_ghost', {'z' => 0, 'items' => Array.new(S::Panel::MAX_GHOST + 50) { {'t' => 'line', 'pts' => [[0, 0], [1, 1]]} }})
ok('quá nhiều mục xem trước: cắt còn tối đa giới hạn', panel.ghost_items.size == S::Panel::MAX_GHOST)
view2 = Sketchup::FakeView.new; panel2_empty = panel.ghost_items.size
call(dlg, 'su_pick_stop')
ok('dừng công cụ: xóa xem trước', panel.ghost_items.empty?)

# ---- Dựng chỉ loại đã đổi ----
m = Sketchup::Model.new
st = state_with
S::AllBuilder.build(m, st, [LV], %w[walls])
ok('AllBuilder chỉ dựng loại yêu cầu (tường): model chỉ có nhóm tường', kinds_of.call(m) == %w[walls])
S::AllBuilder.build(m, st, [LV], %w[columns slabs])
ok('dựng thêm cột, sàn: tường vẫn còn, có thêm hai nhóm', kinds_of.call(m) == %w[columns slabs walls])
ok('loại không có lựa chọn thì không dựng dù được yêu cầu (dầm khi chưa chọn dầm nào: lỗi báo rõ)', error_of { S::AllBuilder.build(Sketchup::Model.new, state_with(beams: {}), [LV], %w[beams]) }.to_s.include?('chưa có'))
ok('AllBuilder.targets lọc theo loại', S::AllBuilder.targets(st, [LV], %w[walls]).keys == ['walls'] && S::AllBuilder.targets(st, [LV]).keys.size >= 4)
$model = Sketchup::Model.new
panel3 = S::Panel.new; d3 = panel3.instance_variable_get(:@dialog); panel3.show; call(d3, 'ready')
payload_b = {'levels' => [LV], 'state' => st.merge('level' => LV), 'kinds' => %w[columns]}
call(d3, 'build_all', payload_b)
ok('build_all với kinds: chỉ dựng cột, thông báo đủ, một thao tác hoàn tác', kinds_of.call($model) == %w[columns] && last_ev(d3, 'all_built')['message'].include?('2 cột') && $model.operations.count { |o| o[0] == :start } == 1)
call(d3, 'build_all', payload_b.merge('kinds' => %w[columns blob]))
ok('kinds chứa loại lạ: từ chối, báo lỗi, không dựng thêm', last_ev(d3, 'message')['error'] && kinds_of.call($model) == %w[columns])
call(d3, 'build_all', payload_b.merge('kinds' => 'columns'))
ok('kinds không phải mảng: từ chối', last_ev(d3, 'message')['error'])

# ---- Hoàn tác / Làm lại trong SketchUp ----
ok('mở cửa sổ gắn thêm theo dõi Hoàn tác (model observer)', $model.observers.size == 1 && $model.observers.first.is_a?(S::ModelWatcher))
n_state = count_ev(d3, 'state')
$model.fire_undo
ok('Hoàn tác khi dữ liệu plugin trong model KHÔNG đổi (hoàn tác một việc khác): không nạp lại, giữ phần sửa chưa lưu', count_ev(d3, 'state') == n_state)
old_json = $model.get_attribute(D, 'state')
S::ModelStore.write($model, state_with(cols: {'1-A' => {}}))
$model.fire_undo
ok('Hoàn tác làm dữ liệu plugin trong model đổi: cửa sổ nhận lại trạng thái (reload true) với dữ liệu mới', count_ev(d3, 'state') == n_state + 1 && last_ev(d3, 'state')['reload'] == true && last_ev(d3, 'state')['levels'][0]['picks']['columns'].keys == ['1-A'])
n_state = count_ev(d3, 'state'); $model.fire_redo
ok('Làm lại nhưng dữ liệu đã nạp rồi: không nạp lại lần nữa', count_ev(d3, 'state') == n_state)
$model.set_attribute(D, 'state', old_json); $model.fire_redo
ok('Làm lại đưa dữ liệu về bản khác: nạp lại', count_ev(d3, 'state') == n_state + 1 && last_ev(d3, 'state')['levels'][0]['picks']['columns'].keys.sort == %w[1-A 2-B])
call(d3, 'build_all', {'levels' => [LV], 'state' => st.merge('level' => LV, 'levels' => st['levels'].map { |l| l.merge('picks' => l['picks'].merge('columns' => {'1-A' => {}})) }), 'kinds' => %w[columns]})
n_state = count_ev(d3, 'state'); $model.fire_undo
ok('dựng xong (tự ghi dữ liệu) rồi hoàn tác nhưng dữ liệu chưa đổi so với lúc dựng: không nạp lại (nhớ dữ liệu sau mỗi lần dựng)', count_ev(d3, 'state') == n_state)
panel3.instance_variable_get(:@dialog).close
ok('đóng cửa sổ: gỡ theo dõi Hoàn tác', $model.observers.empty? && $model.selection.observers.empty?)
$model = Sketchup::Model.new
p4 = S::Panel.new; d4 = p4.instance_variable_get(:@dialog); p4.show
$model.set_attribute(D, 'state', 'x'); n4 = count_ev(d4, 'state'); $model.fire_undo
ok('chưa "ready": Hoàn tác không gửi gì cho cửa sổ', count_ev(d4, 'state') == n4)

# ---- Menu: bắt đầu công cụ vẽ ----
$model = Sketchup::Model.new
p5 = S::Panel.new; d5 = p5.instance_variable_get(:@dialog); p5.show
p5.start_tool('wall')
ok('mở từ menu khi cửa sổ chưa sẵn sàng: giữ lại, chưa gửi', count_ev(d5, 'start_tool') == 0)
call(d5, 'ready')
ok('cửa sổ sẵn sàng: gửi start_tool wall đúng một lần', count_ev(d5, 'start_tool') == 1 && last_ev(d5, 'start_tool') == {'tool' => 'wall'})
p5.start_tool('door')
ok('cửa sổ đã sẵn sàng: gửi ngay start_tool door', last_ev(d5, 'start_tool') == {'tool' => 'door'} && count_ev(d5, 'start_tool') == 2)
call(d5, 'ready')
ok('ready lần nữa không gửi lại công cụ đã giao', count_ev(d5, 'start_tool') == 2)
ok('công cụ không hợp lệ bị từ chối', error_of { p5.start_tool('blob') } && error_of { p5.start_tool("wall'); alert(1);//") } && S::Panel::DRAW_TOOLS == %w[column beam wall door window slab ceiling])
puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
