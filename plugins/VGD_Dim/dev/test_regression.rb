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
  # R3: changing a colour reuses one material instead of adding "#1" copies.
  m = Sketchup::FakeModel.new; Sketchup.active_model = m
  first = VGD::Dim::Engine.get_material(m, 'VGD_DIM_COLOR', '#112233')
  again = VGD::Dim::Engine.get_material(m, 'VGD_DIM_COLOR', '#112233')
  check.call(first.equal?(again) && m.materials.items.length == 1, 'same colour created a second material')
  other = VGD::Dim::Engine.get_material(m, 'VGD_DIM_COLOR', '#445566')
  check.call(!other.equal?(first) && m.materials.items.length == 2, 'new colour did not create its own material')
  # A material whose colour was edited by hand is corrected, not duplicated.
  first.color = Sketchup::Color.new(1, 2, 3)
  fixed = VGD::Dim::Engine.get_material(m, 'VGD_DIM_COLOR', '#112233')
  check.call(fixed.equal?(first) && m.materials.items.length == 2 && first.color.red == 0x11, 'edited material duplicated instead of corrected')

  # R4: a selected group explains why Model Info has no target.
  m = Sketchup::FakeModel.new; Sketchup.active_model = m
  group = Sketchup::Group.new(Sketchup::Definition.new(m))
  m.entities << group; m.selection.add(group)
  check.call(VGD::Dim::Engine.no_target_message(m).include?('group'), 'group selection gave no hint')
  m.selection.clear
  check.call(VGD::Dim::Engine.no_target_message(m).include?('trực tiếp'), 'empty selection message changed')

  puts 'PASS: regression — region errors do not abort unstarted operations; Auto-Style binds after a closed model'
end
