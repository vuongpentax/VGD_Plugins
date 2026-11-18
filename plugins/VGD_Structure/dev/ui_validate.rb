# Kiểm tra dữ liệu giao diện gửi Ruby (đọc JSON từ stdin): chuẩn hóa như khi dựng thật, in {ok, error, free: số phần tử tự do, issues} ra stdout.
require 'json'
ROOT = File.expand_path('../runtime/vgd_structure', __dir__)
%w[core/schema core/grid core/axis_symbol core/geometry placement core/column_types core/beam_types core/wall_types core/opening_types core/levels core/column_plan core/beam_plan core/wall_plan core/opening_plan core/slab_plan core/ceiling_plan core/proposal core/checker core/state core/preview].each { |f| require File.join(ROOT, f) }
S = VGD::Structure
raw = JSON.parse($stdin.read)
begin
  state = S::State.normalize!(raw)
  preview = S::Preview.build(raw)
  free = state['levels'].sum { |l| %w[columns beams walls].sum { |k| l['picks'][k].count { |_r, v| v.key?('free') } } }
  issues = %w[columns beams walls openings].flat_map { |k| (preview[k.to_sym] && preview[k.to_sym][:issues]) || [] }
  puts JSON.generate(ok: preview[:ok] != false, error: preview[:error], free: free, removed: state['removed'], issues: issues, free_items: %w[columns beams walls].sum { |k| ((preview[k.to_sym] || {})[:items] || []).count { |i| i[:placement] == 'free' } })
rescue ArgumentError => e
  puts JSON.generate(ok: false, error: e.message)
end
