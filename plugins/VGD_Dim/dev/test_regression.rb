# Regression checks for defects found in review. Simulation only; not SketchUp evidence.
class RegressionBrokenModel
  def remove_observer(_observer); raise 'Model đã đóng'; end
  def definitions; raise 'Model đã đóng'; end
end
# SketchUp raises TypeError on any call except valid? once an entity is erased.
class RegressionErasedGroup < Sketchup::Group
  def valid?; false; end
  def definition; raise TypeError, 'reference to deleted Group'; end
end
class RegressionErasedDefinition < Sketchup::Definition
  def erase!; @erased = true; end
  def valid?; !@erased; end
  def entities; @erased ? raise(TypeError, 'reference to deleted ComponentDefinition') : super; end
end
# The fixture's Entities is an Array, so empty ones compare equal; real collections compare by identity.
class RegressionIdentityEntities < Sketchup::Entities
  def ==(other); equal?(other); end
end
class RegressionErasedOwnerEntities < RegressionIdentityEntities
  def parent; raise TypeError, 'reference to deleted ComponentDefinition'; end
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
  # R5: another command (for example an offset tool) adds and erases a group in one operation;
  # SketchUp reports it afterwards, so Auto-Style must not touch the deleted group or definition.
  as = VGD::Dim::AutoStyle
  m = Sketchup::FakeModel.new; Sketchup.active_model = m
  as.save(true, {})
  erased_group = RegressionErasedGroup.new(Sketchup::Definition.new(m))
  as.added(erased_group)
  erased_definition = RegressionErasedDefinition.new(m); erased_definition.erase!
  as.watch_definition(erased_definition)
  check.call(as.instance_variable_get(:@queue).to_a.empty?, 'Auto-Style queued an erased group')

  # R6: saving the form again must not rebind (re-walking every definition) on the same model.
  observer = as.instance_variable_get(:@entity_observer)
  as.save(true, {'dim' => {'arrow' => 'dot'}})
  check.call(as.instance_variable_get(:@entity_observer).equal?(observer), 'Auto-Style rebound on an unchanged model')
  other_model = Sketchup::FakeModel.new; Sketchup.active_model = other_model
  as.save(true, {})
  check.call(as.instance_variable_get(:@model).equal?(other_model), 'Auto-Style did not follow the new active model')

  # R7: turning Auto-Style off works even when the form holds a value that fails validation.
  as.save(false, {'dim' => {'arrow' => 'bogus'}})
  check.call(!as.load['enabled'] && as.instance_variable_get(:@model).nil?, 'Auto-Style could not be turned off with invalid settings')
  begin
    as.save(true, {'dim' => {'arrow' => 'bogus'}})
    raise 'Auto-Style turned on with invalid settings'
  rescue ArgumentError
    check.call(!as.load['enabled'], 'Invalid settings were saved while turning Auto-Style on')
  end

  # R8: the watched list prunes erased owners only after growing, and drops them without raising.
  m = Sketchup::FakeModel.new; Sketchup.active_model = m
  as.save(true, {})
  live = RegressionIdentityEntities.new(m)
  dead = RegressionErasedOwnerEntities.new(m)
  as.instance_variable_set(:@watched, [dead] + Array.new(VGD::Dim::AutoStyle::PRUNE_MIN) { RegressionIdentityEntities.new(m) })
  as.watch(live)
  watched = as.instance_variable_get(:@watched)
  check.call(!watched.include?(dead) && watched.include?(live), 'Erased watched collection was not pruned')
  as.save(false, {})

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

  puts 'PASS: regression — region errors do not abort unstarted operations; Auto-Style binds after a closed model, ignores erased entities, does not rebind needlessly and can always be turned off'
end
