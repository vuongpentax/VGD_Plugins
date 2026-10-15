# encoding: UTF-8
# Reload the reviewed fix into the running plugin without restarting SketchUp.
# Existing references and model geometry are preserved.
raise 'VGD Reference chưa được nạp.' unless defined?(VGD::Reference::Session)

VGDReferenceDiagnostics.cleanup if defined?(VGDReferenceDiagnostics)
root = File.expand_path('../runtime/vgd_reference', __dir__)
%w[viewport/reference_overlay.rb tools/interaction_tool.rb core/session.rb].each do |file|
  load File.join(root, file)
end
VGD::Reference::Session.redraw
Sketchup.active_model.active_view.refresh
puts '[VGD Reference] Đã nạp bản sửa UV dạng mảng và cập nhật viewport. Kiểm tra ảnh đang mở.'
