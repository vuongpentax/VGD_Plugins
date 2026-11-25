# Test nối với VGD BIM (cột mốc 7): VGD ID giữ khi dựng lại và xin từ BIM qua cầu nối, dữ liệu tầng trên phần tử, đăng ký cầu nối và lệnh edit từ BIM.
# Chạy: ruby dev/test_bridge.rb (SketchUp giả lập; phần dựng thật chưa xác minh trong SketchUp)
require 'json'
require 'securerandom'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
module UI
  class HtmlDialog
    STYLE_DIALOG = 1
    attr_reader :scripts, :callbacks
    def initialize(**); @callbacks = {}; @scripts = []; @visible = false; end
    def set_file(*); end
    def add_action_callback(name, &b); @callbacks[name] = b; end
    def execute_script(js); @scripts << js; end
    def show; @visible = true; end
    def visible?; @visible; end
    def bring_to_front; end
    def close; @visible = false; end
  end
  def self.messagebox(*); 6; end
end
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; ROOT = File.expand_path('../runtime/vgd_structure', __dir__); end; end
$LOAD_PATH.unshift File.expand_path('stubs', __dir__)
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/room_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/sketchup_import core/state core/preview model_sync edit_sync su_scan model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
def deep(x); Marshal.load(Marshal.dump(x)); end
def state_with(columns)
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => columns.each_with_object({}) { |r, h| h[r] = {} }, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}}
  st
end
def instances(m, prefix); m.entities.grep(Sketchup::Group).find { |g| g.name.start_with?(prefix) }.entities.grep(Sketchup::Instance); end
REFS = %w[1-A 2-A 2-B 3-B]

# Không có BIM: không có ID
VGD::Bridge.providers.clear
m0 = Sketchup::Model.new
S::ColumnBuilder.build(m0, state_with(REFS), ['sl_00000001'])
ok('chưa cài VGD BIM: phần tử không có VGD ID (plugin không tự sinh ID)', instances(m0, 'Cột').all? { |i| i.get_attribute('VGD_BIM_ID', 'guid').nil? })

# Có BIM: nhận ID từ cầu nối
calls = 0
VGD::Bridge.register('vgd_bim', {bridge_version: 1, version: 'x', provides: ['vgd_id'], commands: {'generate' => -> { calls += 1; SecureRandom.uuid }}})
m = Sketchup::Model.new
S::ColumnBuilder.build(m, state_with(REFS), ['sl_00000001'])
inst = instances(m, 'Cột')
ids = inst.map { |i| i.get_attribute('VGD_BIM_ID', 'guid') }
ok('có VGD BIM: mỗi phần tử nhận VGD ID hợp lệ từ cầu nối, không trùng nhau', ids.all? { |x| x =~ UUID } && ids.uniq.size == 4 && calls == 4)
by_ref = inst.each_with_object({}) { |i, h| h[i.get_attribute('VGD_BIM_SOURCE', 'ref')] = i.get_attribute('VGD_BIM_ID', 'guid') }
# Dựng lại với một phần tử bị bỏ và một phần tử thêm
S::ColumnBuilder.build(m, state_with(%w[2-A 2-B 3-C]), ['sl_00000001'])
by_ref2 = instances(m, 'Cột').each_with_object({}) { |i, h| h[i.get_attribute('VGD_BIM_SOURCE', 'ref')] = i.get_attribute('VGD_BIM_ID', 'guid') }
ok('dựng lại: phần tử còn lại GIỮ ID cũ (cùng mã vị trí), phần tử mới (3-C) xin ID mới, phần tử bị bỏ mất ID', by_ref2['sl_00000001:2-A'] == by_ref['sl_00000001:2-A'] && by_ref2['sl_00000001:2-B'] == by_ref['sl_00000001:2-B'] && by_ref2['sl_00000001:3-C'] =~ UUID && !by_ref.values.include?(by_ref2['sl_00000001:3-C']) && !by_ref2.key?('sl_00000001:1-A') && calls == 5)
S::ColumnBuilder.build(m, state_with(%w[2-A 2-B 3-C]), ['sl_00000001'])
ok('dựng lại y nguyên: mọi ID giữ nguyên, không xin thêm ID', instances(m, 'Cột').all? { |i| by_ref2[i.get_attribute('VGD_BIM_SOURCE', 'ref')] == i.get_attribute('VGD_BIM_ID', 'guid') } && calls == 5)
# Không có BIM nhưng phần tử đã có ID: vẫn giữ
VGD::Bridge.providers.clear
S::ColumnBuilder.build(m, state_with(%w[2-A 2-B 3-C 4-C]), ['sl_00000001'])
ok('BIM bị gỡ giữa chừng: ID đã có vẫn giữ, phần tử mới không có ID, không lỗi', instances(m, 'Cột').find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref').end_with?('2-A') }.get_attribute('VGD_BIM_ID', 'guid') == by_ref2['sl_00000001:2-A'] && instances(m, 'Cột').find { |i| i.get_attribute('VGD_BIM_SOURCE', 'ref').end_with?('4-C') }.get_attribute('VGD_BIM_ID', 'guid').nil?)
# ID hỏng không được giữ; BIM trả giá trị hỏng thì bỏ
VGD::Bridge.register('vgd_bim', {bridge_version: 1, version: 'x', provides: ['vgd_id'], commands: {'generate' => -> { 'khong-hop-le' }}})
mb = Sketchup::Model.new
S::ColumnBuilder.build(mb, state_with(%w[1-A]), ['sl_00000001'])
ok('BIM trả ID sai định dạng: bỏ qua, không ghi ID hỏng', instances(mb, 'Cột').first.get_attribute('VGD_BIM_ID', 'guid').nil?)
VGD::Bridge.register('vgd_bim', {bridge_version: 1, version: 'x', provides: ['vgd_id'], commands: {'generate' => -> { raise 'BIM lỗi' }}})
ok('BIM lỗi khi cấp ID: không làm hỏng việc dựng (phần tử vẫn được dựng, không có ID)', error_of { S::ColumnBuilder.build(Sketchup::Model.new, state_with(%w[1-A]), ['sl_00000001']) }.nil?)
VGD::Bridge.providers.clear
kept = {'a' => '8a42f1aa-0000-4000-8000-000000000001', 'b' => 'hong'}
g = Sketchup::Group.new(Sketchup::FakeEntities.new)
i1 = Sketchup::Instance.new(nil, nil); i1.set_attribute('VGD_BIM_SOURCE', 'ref', 'a'); i1.set_attribute('VGD_BIM_ID', 'guid', kept['a'])
i2 = Sketchup::Instance.new(nil, nil); i2.set_attribute('VGD_BIM_SOURCE', 'ref', 'b'); i2.set_attribute('VGD_BIM_ID', 'guid', kept['b'])
g.entities.items.push(i1, i2)
ok('harvest chỉ lấy ID hợp lệ theo mã vị trí; nhóm rỗng hoặc nil thì {}', S::IdKeeper.harvest(g) == {'a' => kept['a']} && S::IdKeeper.harvest(nil) == {})
ok('assign dùng mỗi ID một lần (phần tử thứ hai cùng mã không nhận lại ID đó)', (h = {'a' => kept['a']}) && S::IdKeeper.assign(Sketchup::Instance.new(nil, nil), 'a', h) == kept['a'] && S::IdKeeper.assign(Sketchup::Instance.new(nil, nil), 'a', h).nil?)

# Dữ liệu tầng trên phần tử, cho cả năm loại
all = S::State.default
all['levels'].push(deep(all['levels'][1]).merge('id' => 'sl_00000003', 'name' => 'Mái', 'elevation' => 7200.0))
all['levels'] = S::Levels.normalize!(S::Proposal.propose(all['grid'], all['levels'], ['sl_00000001', 'sl_00000002', 'sl_00000003']).first, all['grid'], all['types'], all['beam_types'], all['wall_types']).first
all = S::State.normalize!(all)
ma = Sketchup::Model.new
S::AllBuilder.build(ma, all, %w[sl_00000001 sl_00000002 sl_00000003])
parts = ma.entities.grep(Sketchup::Group).flat_map { |g| g.entities.grep(Sketchup::Instance) }
ok('mọi phần tử của cả năm loại mang tên tầng và cao độ tầng (VGD_STRUCT.level_name, level_elevation) để BIM hiển thị', parts.size > 100 && parts.all? { |i| i.get_attribute('VGD_STRUCT', 'level_name').is_a?(String) && i.get_attribute('VGD_STRUCT', 'level_elevation').is_a?(Numeric) } && parts.map { |i| i.get_attribute('VGD_STRUCT', 'level_name') }.uniq.sort == ['Mái', 'Tầng 1', 'Tầng 2'])
ok('phần tử có đủ dữ liệu BIM đọc: plugin, kind, ref, dims, level', parts.all? { |i| i.get_attribute('VGD_BIM_SOURCE', 'plugin') == 'vgd_structure' && S::Schema::KINDS.include?(i.get_attribute('VGD_BIM_SOURCE', 'kind')) && i.get_attribute('VGD_BIM_SOURCE', 'ref').include?(':') && JSON.parse(i.get_attribute('VGD_STRUCT', 'dims')).is_a?(Hash) })
VGD::Bridge.register('vgd_bim', {bridge_version: 1, version: 'x', provides: ['vgd_id'], commands: {'generate' => -> { SecureRandom.uuid }}})
mi = Sketchup::Model.new
S::AllBuilder.build(mi, all, %w[sl_00000001 sl_00000002 sl_00000003])
parts2 = mi.entities.grep(Sketchup::Group).flat_map { |g| g.entities.grep(Sketchup::Instance) }
all_ids = parts2.map { |i| i.get_attribute('VGD_BIM_ID', 'guid') }
ok('dựng tất cả có BIM: mọi phần tử (cột, dầm, tường, sàn, trần) đều có ID hợp lệ và không trùng', all_ids.all? { |x| x =~ UUID } && all_ids.uniq.size == all_ids.size)
before = parts2.each_with_object({}) { |i, h| h[i.get_attribute('VGD_BIM_SOURCE', 'ref')] = i.get_attribute('VGD_BIM_ID', 'guid') }
S::AllBuilder.build(mi, all, %w[sl_00000001 sl_00000002 sl_00000003])
after = mi.entities.grep(Sketchup::Group).flat_map { |g| g.entities.grep(Sketchup::Instance) }.each_with_object({}) { |i, h| h[i.get_attribute('VGD_BIM_SOURCE', 'ref')] = i.get_attribute('VGD_BIM_ID', 'guid') }
ok('dựng tất cả lại: mọi ID giữ nguyên theo mã vị trí', after == before && after.size == before.size)

# Đăng ký cầu nối và lệnh edit
VGD::Bridge.providers.clear
module UI; class MenuNode; end; end unless defined?(UI::MenuNode)
class SketchupExtension; attr_accessor :description, :version, :creator; def initialize(n, p); end; end
module Sketchup; def self.register_extension(*); true; end; end
def file_loaded?(f); $lf ||= {}; $lf[f]; end
def file_loaded(f); ($lf ||= {})[f] = true; end
module UI
  class Toolbar; def initialize(*); end; def add_item(*); end; def restore; end; end
  class Command; attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon; def initialize(*, &b); end; end
  class MenuNode; def initialize(n); @n = n; @s = {}; end; def add_submenu(n); @s[n] ||= MenuNode.new(n); end; def add_item(*); end; end
  def self.menu(_n); @root ||= MenuNode.new('r'); end
end
load File.join(ROOT, 'loader.rb')
prov = VGD::Bridge.provider_for('structure_element')
ok('VGD Structure đăng ký cầu nối: loại structure_element, lệnh edit, đúng bridge_version', prov && prov[:id] == 'vgd_structure' && prov[:info][:commands].key?('edit') && prov[:info][:bridge_version] == 1 && prov[:info][:version] == '9.9.9')
load File.join(ROOT, 'loader.rb')
ok('nạp lại loader không nhân đôi mục đăng ký', VGD::Bridge.providers.keys.count('vgd_structure') == 1)
$model = Sketchup::Model.new
S::ColumnBuilder.build($model, state_with(%w[2-B]), ['sl_00000001'])
col = $model.entities.grep(Sketchup::Group).first.entities.grep(Sketchup::Instance).first
VGD::Bridge.call('structure_element', 'edit', $model, col)
pnl = S.instance_variable_get(:@panel)
ok('lệnh edit mở cửa sổ và giữ yêu cầu chuyển tới phần tử cho tới khi giao diện sẵn sàng', pnl && pnl.visible? && pnl.instance_variable_get(:@pending_focus) == {kind: 'column', level: 'sl_00000001', ref: '2-B'})
dlg = pnl.instance_variable_get(:@dialog)
dlg.callbacks['ready'].call(nil)
events = dlg.scripts.map { |js| js[/receive\("([a-z_]+)"/, 1] }
focus_js = dlg.scripts.find { |js| js.include?('"focus"') }
ok('giao diện sẵn sàng: gửi trạng thái TRƯỚC, rồi mới gửi focus với tab, tầng, mã đúng', events.index('state') && events.index('focus') && events.index('state') < events.index('focus') && focus_js.include?('"kind":"column"') && focus_js.include?('"ref":"2-B"') && pnl.instance_variable_get(:@pending_focus).nil?)
before_n = dlg.scripts.size
S.edit(col)
ok('cửa sổ đã sẵn sàng: edit gửi focus ngay (không đợi)', dlg.scripts.size > before_n && dlg.scripts.last.include?('"focus"'))
wall = Sketchup::Instance.new(nil, nil); wall.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_structure'); wall.set_attribute('VGD_BIM_SOURCE', 'kind', 'wall'); wall.set_attribute('VGD_BIM_SOURCE', 'ref', 'sl_00000002:y:2:A-B')
S.edit(wall)
ok('ref có dấu hai chấm (nhịp): tách đúng mã tầng và mã nhịp', dlg.scripts.last.include?('"ref":"y:2:A-B"') && dlg.scripts.last.include?('"level":"sl_00000002"'))
foreign = Sketchup::Instance.new(nil, nil); foreign.set_attribute('VGD_BIM_SOURCE', 'plugin', 'plugin_khac'); foreign.set_attribute('VGD_BIM_SOURCE', 'kind', 'column')
bad_kind = Sketchup::Instance.new(nil, nil); bad_kind.set_attribute('VGD_BIM_SOURCE', 'plugin', 'vgd_structure'); bad_kind.set_attribute('VGD_BIM_SOURCE', 'kind', 'room')
ok('đối tượng không do plugin dựng, loại lạ hoặc không phải đối tượng: từ chối', !error_of { S.edit(foreign) }.nil? && !error_of { S.edit(bad_kind) }.nil? && !error_of { S.edit(Object.new) }.nil?)
# Bản sao cầu nối giống BIM
bim = File.expand_path('../../VGD_BIM/runtime/vgd_bim/core/bridge.rb', __dir__)
ok('bridge_registry.rb GIỐNG HỆT bản của VGD_BIM trong repo', !File.exist?(bim) || File.read(bim) == File.read(File.join(ROOT, 'bridge_registry.rb')))
puts $fails.zero? ? "\nTẤT CẢ ĐẠT" : "\n#{$fails} LỖI"
exit($fails.zero? ? 0 : 1)
