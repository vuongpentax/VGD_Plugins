# Dữ liệu thật từ Ruby cho test giao diện (trạng thái, xem trước lưới / cột, kết quả tạo trục từ nhịp). In JSON ra stdout.
require 'json'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_plan core/opening_plan core/plates core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
state = S::State.default
refs = S::Grid.intersections(state['grid']).map { |i| i[:ref] }
two = {'1-A' => {}, '2-B' => {'x' => 'center'}}
spans = S::Grid.spans(state['grid']).map { |sp| sp[:ref] }
beams_two = {'x:B:1-2' => {}, 'y:2:A-B' => {'p' => 'center'}}
all_beams = spans.each_with_object({}) { |r, h| h[r] = {} }
walls_two = {'x:B:1-2' => {}, 'y:2:A-B' => {'p' => 'center'}}
cells = S::Grid.cells(state['grid']).map { |c| c[:ref] }
cells_two = {'1-2/A-B' => {}, '2-3/B-C' => {}}
all_cells = cells.each_with_object({}) { |r, h| h[r] = {} }
openings_two = {'op_00000001' => {'wall' => 'x:B:1-2', 'type' => 'ot_00000001', 'pos' => 1000, 'flip' => false}, 'op_00000002' => {'wall' => 'x:B:1-2', 'type' => 'ot_00000002', 'pos' => 2800, 'flip' => false}}
all = refs.each_with_object({}) { |r, h| h[r] = {} }
with = ->(picks, level, beams = beams_two, walls = walls_two, slabs = cells_two, ceilings = cells_two, openings = openings_two) { state.merge('levels' => state['levels'].each_with_index.map { |l, i| i.zero? ? l.merge('picks' => {'columns' => picks, 'beams' => beams, 'walls' => walls, 'slabs' => slabs, 'ceilings' => ceilings, 'openings' => openings}) : l }, 'level' => level) }
state_two = with.call(two, 'sl_00000001')
# Phần tử xiên (P4b-2): cột xoay 30°, dầm và tường xiên 3-4-5 (dài 5000) từ (1000, 1000) tới (4000, 5000), cửa trên tường xiên.
obl_cols = {'fc_00000001' => {'free' => {'x' => 8000, 'y' => 8000, 'rot' => 30}}}
obl_beams = {'fb_00000001' => {'free' => {'a' => [1000, 1000], 'b' => [4000, 5000]}}}
obl_walls = {'fw_00000001' => {'free' => {'a' => [6000, 1000], 'b' => [9000, 5000]}}}
obl_openings = {'op_00000001' => {'wall' => 'fw_00000001', 'type' => 'ot_00000001', 'pos' => 2500, 'flip' => false}}
# Sàn, trần đa giác (P4b-3): sàn hình chữ nhật có một lỗ, trần đa giác và một sàn theo ô.
poly_slabs = {'fs_00000001' => {'free' => {'poly' => [[13000, 0], [15500, 0], [15500, 4000], [13000, 4000]], 'holes' => [[[13500, 1000], [14200, 1000], [14200, 2000], [13500, 2000]]]}}, '3-4/B-C' => {}}
poly_ceilings = {'fk_00000001' => {'free' => {'poly' => [[13000, 6000], [15500, 6000], [15500, 8000], [13000, 8000]], 'holes' => []}}}
# Ghi chú 2D (P5b): nét, đa tuyến, tròn, cung, chữ, kích thước, cốt cao độ trên tầng đầu tiên.
obl_notes = {
  'an_00000001' => {'t' => 'line', 'a' => [1000, 1000], 'b' => [3000, 2000]},
  'an_00000002' => {'t' => 'poly', 'pts' => [[5000, 1000], [6000, 2500], [7000, 1000]], 'closed' => false},
  'an_00000003' => {'t' => 'circle', 'c' => [10000, 1800], 'r' => 800},
  'an_00000004' => {'t' => 'arc', 'c' => [2000, 5500], 'r' => 1000, 'a0' => 0, 'a1' => 90},
  'an_00000005' => {'t' => 'text', 'p' => [5000, 5000], 'text' => 'Ghi chú A', 'h' => 250},
  'an_00000006' => {'t' => 'dim', 'a' => [1000, 6500], 'b' => [3000, 6500], 'off' => 400},
  'an_00000007' => {'t' => 'mark', 'p' => [10000, 5000], 'z' => 3600}
}
notes_levels = S::State.normalize!(state.merge('levels' => state['levels'].each_with_index.map { |l, i| i.zero? ? l.merge('notes' => obl_notes) : l }))['levels']
puts JSON.generate(
  state: {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], opening_types: state['opening_types'], levels: state_two['levels'], saved: false, drawn: false, drawn_levels: [], drawn_beam_levels: [], drawn_wall_levels: [], drawn_slab_levels: [], drawn_ceiling_levels: [], drawn_opening_levels: [], version: '0.15.0-beta.1'},
  preview: S::Preview.build(state_two),
  preview_all: S::Preview.build(with.call(all, 'sl_00000001')),
  preview_all_beams: S::Preview.build(with.call(all, 'sl_00000001', all_beams)),
  preview_all_walls: S::Preview.build(with.call(all, 'sl_00000001', beams_two, all_beams)),
  state_c: {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], opening_types: state['opening_types'], levels: with.call(two, 'sl_00000001', beams_two, {'x:C:1-2' => {}, 'y:2:A-B' => {}}, cells_two, cells_two, {'op_00000001' => {'wall' => 'x:C:1-2', 'type' => 'ot_00000001', 'pos' => 1000, 'flip' => false}, 'op_00000002' => {'wall' => 'x:C:1-2', 'type' => 'ot_00000002', 'pos' => 2800, 'flip' => false}})['levels'], saved: false, drawn: false, drawn_levels: [], drawn_beam_levels: [], drawn_wall_levels: [], drawn_slab_levels: [], drawn_ceiling_levels: [], drawn_opening_levels: [], version: '0.15.0-beta.1'},
  preview_c: S::Preview.build(with.call(two, 'sl_00000001', beams_two, {'x:C:1-2' => {}, 'y:2:A-B' => {}}, cells_two, cells_two, {'op_00000001' => {'wall' => 'x:C:1-2', 'type' => 'ot_00000001', 'pos' => 1000, 'flip' => false}, 'op_00000002' => {'wall' => 'x:C:1-2', 'type' => 'ot_00000002', 'pos' => 2800, 'flip' => false}})),
  state_free: {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], opening_types: state['opening_types'], saved: false, drawn: false, drawn_levels: [], drawn_beam_levels: [], drawn_wall_levels: [], drawn_slab_levels: [], drawn_ceiling_levels: [], drawn_opening_levels: [], version: '0.15.0-beta.1',
                levels: with.call({'1-A' => {}, 'fc_00000001' => {'free' => {'x' => 2000, 'y' => 5000, 'rot' => 0}}}, 'sl_00000001', {'fb_00000001' => {'free' => {'a' => [1000, 6000], 'b' => [3000, 6000]}}}, {'x:B:1-2' => {}, 'fw_00000001' => {'free' => {'a' => [5000, 2000], 'b' => [8000, 2000]}}, 'fw_00000002' => {'free' => {'a' => [9000, 1000], 'b' => [9000, 3500]}}}, {'1-2/A-B' => {}}, {'1-2/A-B' => {}}, {'op_00000001' => {'wall' => 'fw_00000001', 'type' => 'ot_00000001', 'pos' => 1000, 'flip' => false}})['levels']},
  preview_free: S::Preview.build(with.call({'1-A' => {}, 'fc_00000001' => {'free' => {'x' => 2000, 'y' => 5000, 'rot' => 0}}}, 'sl_00000001', {'fb_00000001' => {'free' => {'a' => [1000, 6000], 'b' => [3000, 6000]}}}, {'x:B:1-2' => {}, 'fw_00000001' => {'free' => {'a' => [5000, 2000], 'b' => [8000, 2000]}}, 'fw_00000002' => {'free' => {'a' => [9000, 1000], 'b' => [9000, 3500]}}}, {'1-2/A-B' => {}}, {'1-2/A-B' => {}}, {'op_00000001' => {'wall' => 'fw_00000001', 'type' => 'ot_00000001', 'pos' => 1000, 'flip' => false}})),
  state_obl: {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], opening_types: state['opening_types'], saved: false, drawn: false, drawn_levels: [], drawn_beam_levels: [], drawn_wall_levels: [], drawn_slab_levels: [], drawn_ceiling_levels: [], drawn_opening_levels: [], version: '0.15.0-beta.1',
              levels: with.call(obl_cols, 'sl_00000001', obl_beams, obl_walls, {}, {}, obl_openings)['levels']},
  preview_obl: S::Preview.build(with.call(obl_cols, 'sl_00000001', obl_beams, obl_walls, {}, {}, obl_openings)),
  state_poly: {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], opening_types: state['opening_types'], saved: false, drawn: false, drawn_levels: [], drawn_beam_levels: [], drawn_wall_levels: [], drawn_slab_levels: [], drawn_ceiling_levels: [], drawn_opening_levels: [], version: '0.15.0-beta.1',
               levels: with.call({}, 'sl_00000001', {}, {}, poly_slabs, poly_ceilings, {})['levels']},
  preview_poly: S::Preview.build(with.call({}, 'sl_00000001', {}, {}, poly_slabs, poly_ceilings, {})),
  state_notes: {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], wall_types: state['wall_types'], opening_types: state['opening_types'], saved: false, drawn: false, drawn_levels: [], drawn_beam_levels: [], drawn_wall_levels: [], drawn_slab_levels: [], drawn_ceiling_levels: [], drawn_opening_levels: [], version: '0.15.0-beta.1',
                levels: notes_levels},
  preview_notes: S::Preview.build(state.merge('levels' => notes_levels)),
  preview_all_cells: S::Preview.build(with.call(all, 'sl_00000001', beams_two, walls_two, all_cells, all_cells)),
  check_ok: S::Checker.run(S::State.normalize!(with.call(all, 'sl_00000001', all_beams, walls_two, all_cells, all_cells))),
  check_warn: S::Checker.run(S::State.normalize!(with.call(all.reject { |k, _| k == '2-B' }, 'sl_00000001', all_beams, walls_two, all_cells, all_cells))),
  preview_top: S::Preview.build(state_two.merge('level' => 'sl_00000002')),
  preview_bad_types: S::Preview.build(state_two.merge('types' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 5, 'd' => 300}])),
  quick_x: S::Grid.axes_from_spacings('4200, 3600*2', :number), quick_y: S::Grid.axes_from_spacings('5000', :letter),
  error: {ok: false, error: 'Trục “2” phải cách trục trước ít nhất 100 mm (vị trí tăng dần).'}
)
