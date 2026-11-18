# Test sửa TRONG SketchUp thì dữ liệu cập nhật theo (P7b, phần Ruby): chụp vị trí, phát hiện dời / xoay / xóa, bản vá gửi cửa sổ, dựng lại giữ VGD ID. SketchUp giả lập: chưa xác minh trong SketchUp thật.
# Chạy: ruby dev/test_su_edit.rb
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
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/state core/preview model_sync edit_sync model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
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

GUID = '11111111-2222-3333-4444-555555555555'
def instance_of(model, kind, ref)
  model.entities.grep(Sketchup::Group).flat_map { |g| g.entities.to_a }.find { |e| e.respond_to?(:get_attribute) && e.get_attribute('VGD_BIM_SOURCE', 'ref') == "#{LV}:#{ref}" && e.get_attribute('VGD_BIM_SOURCE', 'kind') == kind }
end
def group_of(model, kind); model.entities.grep(Sketchup::Group).find { |g| g.get_attribute(D, 'kind') == kind }; end

$model = Sketchup::Model.new
st = state_with
panel = S::Panel.new; dlg = panel.instance_variable_get(:@dialog); panel.show; call(dlg, 'ready')
call(dlg, 'grid_preview', st.merge('level' => LV))
call(dlg, 'build_all', {'levels' => [LV], 'state' => st.merge('level' => LV), 'kinds' => %w[columns walls]})
col = instance_of($model, 'column', '1-A')
col.set_attribute('VGD_BIM_ID', 'guid', GUID)
call(dlg, 'build_all', {'levels' => [LV], 'state' => st.merge('level' => LV), 'kinds' => %w[columns]}) # dựng lại để chụp lại sau khi gắn ID
col = instance_of($model, 'column', '1-A')
col.set_attribute('VGD_BIM_ID', 'guid', GUID)
panel.remember_edit_state
n0 = count_ev(dlg, 'su_edit')
$model.fire_commit
UI.fire_timers
ok('không sửa gì: commit không gửi cập nhật', count_ev(dlg, 'su_edit') == n0)

# ---- Dời một cột ----
col.fake_move(500, 0)
$model.fire_commit; UI.fire_timers
ev = last_ev(dlg, 'su_edit')
ok('dời cột 500 mm: gửi một bản vá, cột theo lưới thành cột tự do, mã cũ bị bỏ và đổi mã', ev && ev['patches'].size == 1 && ev['patches'][0]['remove']['columns'] == ['1-A'] && ev['patches'][0]['retag'].keys == ['1-A'] && ev['patches'][0]['set']['columns'].keys == [ev['patches'][0]['retag']['1-A']])
free = ev['patches'][0]['set']['columns'].values.first['free']
base = st['levels'][0]
x0 = 150.0 # tâm cột 1-A trước khi dời (cột góc tiếp giáp trục biên)
ok('cột tự do mới dời đúng +500 mm theo X', x0 && (free['x'] - (x0 + 500)).abs < 0.2)
ok('chụp lại sau cập nhật: commit tiếp theo không gửi lặp', ($model.fire_commit; UI.fire_timers; true) && count_ev(dlg, 'su_edit') == n0 + 1)

# ---- Dựng lại giữ VGD ID theo mã mới ----
new_ref = ev['patches'][0]['retag']['1-A']
st2 = deep(st)
lv = st2['levels'][0]
lv['picks']['columns'].delete('1-A')
lv['picks']['columns'][new_ref] = ev['patches'][0]['set']['columns'][new_ref]
call(dlg, 'build_all', {'levels' => [LV], 'state' => st2.merge('level' => LV), 'kinds' => %w[columns], 'retag' => {"#{LV}:1-A" => "#{LV}:#{new_ref}"}})
moved = instance_of($model, 'column', new_ref)
ok('dựng lại cột đã dời: phần tử mang mã mới và GIỮ VGD ID cũ', moved && moved.get_attribute('VGD_BIM_ID', 'guid') == GUID && instance_of($model, 'column', '1-A').nil?)
n1 = count_ev(dlg, 'su_edit')
$model.fire_commit; UI.fire_timers
ok('sau dựng lại (chụp lại vị trí): không có cập nhật thừa', count_ev(dlg, 'su_edit') == n1)

# ---- Xóa phần tử ----
col2 = instance_of($model, 'column', '2-B')
col2.erase!
$model.fire_commit; UI.fire_timers
ev = last_ev(dlg, 'su_edit')
ok('xóa cột trong SketchUp: bản vá bỏ cột khỏi dữ liệu', count_ev(dlg, 'su_edit') == n1 + 1 && ev['patches'][0]['remove'] == {'columns' => ['2-B']})

# ---- Dời cả nhóm: không phải sửa phần tử ----
n2 = count_ev(dlg, 'su_edit')
group_of($model, 'walls').transform!(Geom::Transformation.translation(Geom::Vector3d.new(1000.mm, 0, 0)))
$model.fire_commit; UI.fire_timers
ok('dời cả nhóm tường: không cập nhật dữ liệu', count_ev(dlg, 'su_edit') == n2)

# ---- Chỉ bật khi đồng bộ bật ----
call(dlg, 'su_sync_edit', false)
wall = instance_of($model, 'wall', 'x:B:1-2')
wall.fake_move(0, 300)
$model.fire_commit; UI.fire_timers
ok('tắt đồng bộ: dời tường không gửi cập nhật', count_ev(dlg, 'su_edit') == n2)
call(dlg, 'su_sync_edit', true)
wall.fake_move(0, 300)
$model.fire_commit; UI.fire_timers
ev = last_ev(dlg, 'su_edit')
ok('bật lại đồng bộ: dời tường gửi bản vá tường tự do', count_ev(dlg, 'su_edit') == n2 + 1 && ev['patches'][0]['set']['walls'].keys.first.start_with?('fw_'))

# ---- Hoàn tác: chụp lại, không coi là sửa ----
n3 = count_ev(dlg, 'su_edit')
wall.fake_move(0, -150)
$model.fire_undo
$model.fire_commit; UI.fire_timers
ok('Hoàn tác trong SketchUp: chụp lại vị trí, không gửi cập nhật cho việc hoàn tác', count_ev(dlg, 'su_edit') == n3)

# ---- Dữ liệu sai / chưa sẵn sàng ----
panel_late = S::Panel.new; panel_late.show
$model.fire_commit
ok('cửa sổ chưa sẵn sàng: bỏ qua, không lỗi', true)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
