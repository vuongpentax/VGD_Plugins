# Regression checks for defects found in review. Simulation only; not SketchUp evidence.
class RegressionBrokenModel
  def remove_observer(_observer); raise 'Model đã đóng'; end
  def definitions; raise 'Model đã đóng'; end
end

def run_regression_tests
  check = ->(ok, message) { raise message unless ok }

  # R1: a rejected detail-region request must not abort an operation it never started.
  m = Sketchup::FakeModel.new; Sketchup.active_model = m
  begin
    VGD::Dim::Regions.delete_detail(m, 'missing')
    raise 'delete_detail accepted a missing region'
  rescue ArgumentError => error
    check.call(error.message == 'Chọn Detail Region cần xóa.' && m.aborts == 0,
               'delete_detail aborted without a started operation or hid its error')
  end
  begin
    VGD::Dim::Regions.set_active(m, 'missing')
    raise 'set_active accepted a missing region'
  rescue ArgumentError => error
    check.call(error.message == 'Detail Region không tồn tại.' && m.aborts == 0,
               'set_active aborted without a started operation or hid its error')
  end

  # R2: Auto-Style must still bind to the new model when the previous model is gone.
  as = VGD::Dim::AutoStyle
  as.instance_variable_set(:@model, RegressionBrokenModel.new)
  as.instance_variable_set(:@model_observer, Object.new)
  as.instance_variable_set(:@definition_observer, Object.new)
  as.instance_variable_set(:@config, {'enabled' => true, 'settings' => VGD::Dim::Core.validate_settings({})})
  fresh = Sketchup::FakeModel.new
  as.bind(fresh)
  check.call(as.instance_variable_get(:@model).equal?(fresh),
             'Auto-Style did not bind to the new model after the previous model was closed')
  puts 'PASS: regression — region errors do not abort unstarted operations; Auto-Style binds after a closed model'
end
