# Test dựng cầu thang (stair_builder.rb) bằng SketchUp giả lập: nhóm theo tầng, mỗi cầu thang một nhóm bậc (tag A. STAIR) và một nhóm lan can (tag A. RAILING),
# dữ liệu nguồn VGD_BIM_SOURCE, không dựng khi đâm vào tường, dựng lại thay nhóm cũ, dọn nhóm khi bỏ tầng. Chạy: ruby dev/test_stair_builder.rb
require 'json'
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end
def error_of; yield; nil; rescue StandardError => e; e.message; end
require_relative 'fake_sketchup'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
module VGD; module Structure; VERSION = '9.9.9'; end; end
%w[bridge_registry id_keeper core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/stair_types core/stair_plan core/stair_place core/layer_list core/levels core/column_plan core/beam_plan core/wall_joins core/wall_plan core/opening_plan core/plates core/room_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/model_edit core/section_geometry core/elevation_geometry core/sketchup_import core/state core/preview model_sync edit_sync su_scan su_section model_store tag_store grid_tag grid_builder column_builder beam_builder wall_builder opening_builder plate_builder stair_builder all_builder su_tools panel].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
D = S::Schema::DICTIONARY
SB = S::StairBuilder
ST = S::StairTypes.default
GRID = S::Grid.default
COLS = S::Grid.intersections(GRID).each_with_object({}) { |i, h| h[i[:ref]] = {} }

def state_with(stairs, walls: {}, beams: {})
  st = S::State.default
  st['levels'][0]['picks'] = {'columns' => COLS, 'beams' => beams, 'walls' => walls, 'slabs' => {}, 'ceilings' => {}, 'openings' => {}, 'stairs' => stairs}
  S::State.normalize!(st)
end
def stair_pick(a, b, id = 'st_00000001')
  {id => {'type' => ST[0]['id'], 'free' => {'a' => a, 'b' => b}}}
end
def groups(m); m.entities.grep(Sketchup::Group).select { |g| g.get_attribute(D, 'kind') == 'stairs' }; end
def children(g); g.entities.grep(Sketchup::Group); end

m = Sketchup::Model.new
st = state_with(stair_pick([6000, 300], [6000, 5800]))
SB.build(m, st, ['sl_00000001'])
gs = groups(m)
ok('dựng tầng 1: một nhóm "Cầu thang - Tầng 1" có kind stairs và mã tầng', gs.size == 1 && gs[0].name == 'Cầu thang - Tầng 1' && gs[0].get_attribute(D, 'level') == 'sl_00000001')
kids = children(gs[0])
stair = kids.find { |g| g.name.start_with?('Cầu thang st_') }
rails = kids.find { |g| g.name.start_with?('Lan can st_') }
ok('trong nhóm tầng: một nhóm bậc và một nhóm lan can cho cầu thang st_00000001', stair && rails && kids.size == 2)
ok('nhóm bậc: nguồn VGD_BIM_SOURCE kind stair, ref tầng:mã, plugin Structure', stair.get_attribute('VGD_BIM_SOURCE', 'kind') == 'stair' && stair.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:st_00000001' && stair.get_attribute('VGD_BIM_SOURCE', 'plugin') == S::Schema::PLUGIN_ID)
ok('nhóm lan can: nguồn kind railing, cùng mã cầu thang', rails.get_attribute('VGD_BIM_SOURCE', 'kind') == 'railing' && rails.get_attribute('VGD_BIM_SOURCE', 'ref') == 'sl_00000001:st_00000001')
ok('nhóm bậc có khối bậc (≥ 21 mặt đứng bậc đã đùn)', stair.entities.grep(Sketchup::Face).size >= 21)
ok('nhóm bậc có dữ liệu kích thước (rộng 1000, 21 bậc) và vân tay', stair.get_attribute(D, 'dims').is_a?(String) && JSON.parse(stair.get_attribute(D, 'dims'))['count'] == 21 && stair.get_attribute(D, 'fp').to_s.size == 12)
ok('tag: bậc A. STAIR, lan can A. RAILING', stair.layer.name == 'A. STAIR' && rails.layer.name == 'A. RAILING')
ok('lan can tạm chưa làm: nhóm lan can có mặt rỗng (không tay vịn, không cột)', rails.entities.grep(Sketchup::Edge).empty? && rails.entities.grep(Sketchup::Face).empty?)

SB.build(m, st, ['sl_00000001'])
ok('dựng lại: thay nhóm cũ, không nhân đôi', groups(m).size == 1 && children(groups(m)[0]).size == 2)

m2 = Sketchup::Model.new
bad = state_with(stair_pick([500, 300], [500, 5800]), walls: {'x:B:1-2' => {}})
msg = error_of { SB.build(m2, bad, ['sl_00000001']) }
ok('có cầu thang đâm vào tường: không dựng, báo lỗi, model không có nhóm cầu thang', msg.to_s.include?('đâm vào') && groups(m2).empty?)

m3 = Sketchup::Model.new
ok('không có cầu thang trong các tầng chọn: báo lỗi rõ', !error_of { SB.build(m3, state_with({}), ['sl_00000001']) }.nil?)

m4 = Sketchup::Model.new
SB.build(m4, state_with(stair_pick([6000, 300], [6000, 5800])), ['sl_00000001'])
ok('không có cầu thang để dựng: không xóa nhóm cũ khi dựng (báo lỗi)', !error_of { SB.build(m4, state_with({}), ['sl_00000001']) }.nil? && groups(m4).size == 1)
SB.remove(m4, 'sl_00000001')
ok('gỡ cầu thang của tầng: nhóm bị xóa', groups(m4).empty?)

puts($fails.zero? ? 'TẤT CẢ ĐẠT' : "#{$fails} LỖI")
exit($fails.zero? ? 0 : 1)
