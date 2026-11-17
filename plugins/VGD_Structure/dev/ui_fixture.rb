# Dữ liệu thật từ Ruby cho test giao diện (trạng thái mặc định, xem trước, kết quả tạo trục từ nhịp). In JSON ra stdout.
require 'json'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[core/grid core/axis_symbol].each { |f| require File.join(ROOT, f) }
G = VGD::Structure::Grid
S = VGD::Structure::AxisSymbol
def preview(grid, symbol)
  {ok: true, summary: {x_axes: grid['x_axes'].size, y_axes: grid['y_axes'].size, intersections: G.intersections(grid).size, spans: G.spans(grid).size, cells: G.cells(grid).size,
                       width: (G.bounds(grid)[2] - G.bounds(grid)[0]).round(1), depth: (G.bounds(grid)[3] - G.bounds(grid)[1]).round(1)}, bounds: G.bounds(grid), axes: S.plan(grid, symbol)}
end
grid = G.default
symbol = S.options!(nil)
puts JSON.generate(state: {grid: grid, symbol: symbol, saved: false, drawn: false, version: '0.2.0-beta.1'}, preview: preview(grid, symbol),
                   quick_x: G.axes_from_spacings('4200, 3600*2', :number), quick_y: G.axes_from_spacings('5000', :letter),
                   error: {ok: false, error: 'Trục “2” phải cách trục trước ít nhất 100 mm (vị trí tăng dần).'})
