# Dữ liệu thật từ Ruby cho test giao diện (trạng thái, xem trước lưới / cột, kết quả tạo trục từ nhịp). In JSON ra stdout.
require 'json'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[core/schema core/grid core/axis_symbol core/column_types core/beam_types core/levels core/column_plan core/beam_plan core/state core/preview].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
state = S::State.default
refs = S::Grid.intersections(state['grid']).map { |i| i[:ref] }
two = {'1-A' => {}, '2-B' => {'x' => 'center'}}
spans = S::Grid.spans(state['grid']).map { |sp| sp[:ref] }
beams_two = {'x:B:1-2' => {}, 'y:2:A-B' => {'p' => 'center'}}
all_beams = spans.each_with_object({}) { |r, h| h[r] = {} }
all = refs.each_with_object({}) { |r, h| h[r] = {} }
with = ->(picks, level, beams = beams_two) { state.merge('levels' => state['levels'].each_with_index.map { |l, i| i.zero? ? l.merge('picks' => {'columns' => picks, 'beams' => beams}) : l }, 'level' => level) }
state_two = with.call(two, 'sl_00000001')
puts JSON.generate(
  state: {grid: state['grid'], symbol: state['symbol'], types: state['types'], beam_types: state['beam_types'], levels: state_two['levels'], saved: false, drawn: false, drawn_levels: [], drawn_beam_levels: [], version: '0.4.0-beta.1'},
  preview: S::Preview.build(state_two),
  preview_all: S::Preview.build(with.call(all, 'sl_00000001')),
  preview_all_beams: S::Preview.build(with.call(all, 'sl_00000001', all_beams)),
  preview_top: S::Preview.build(state_two.merge('level' => 'sl_00000002')),
  preview_bad_types: S::Preview.build(state_two.merge('types' => [{'id' => 'ct_00000001', 'name' => 'A', 'w' => 5, 'd' => 300}])),
  quick_x: S::Grid.axes_from_spacings('4200, 3600*2', :number), quick_y: S::Grid.axes_from_spacings('5000', :letter),
  error: {ok: false, error: 'Trục “2” phải cách trục trước ít nhất 100 mm (vị trí tăng dần).'}
)
