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

  # R9: another tool replacing Manual Dim or the region picker must re-enable the dialog, once.
  sent = []
  dialog = VGD::Dim::Dialog
  dialog.define_singleton_method(:send_js) { |name, _data| sent << name }
  view = Object.new; def view.invalidate; end
  Sketchup.const_set(:InputPoint, Class.new) unless Sketchup.const_defined?(:InputPoint)
  manual = VGD::Dim::ManualDim::Tool.new(VGD::Dim::Core.validate_settings({}))
  manual.deactivate(view); manual.deactivate(view)
  check.call(sent == ['onManualStatus'], 'Manual Dim did not notify the dialog exactly once when replaced')
  sent.clear
  picker = VGD::Dim::Regions::PickTool.new('boundary', 'b')
  picker.deactivate(view); picker.deactivate(view)
  check.call(sent == ['onRegionCancelled'], 'Region picker did not notify the dialog exactly once when replaced')
  sent.clear
  cancelled = VGD::Dim::Regions::PickTool.new('detail', 'd')
  cancelled.onCancel(nil, view); cancelled.deactivate(view)
  check.call(sent == ['onRegionCancelled'], 'Region picker reported Esc and replacement twice')
  sent.clear
  saved = VGD::Dim::Regions::PickTool.new('boundary', 'b'); saved.instance_variable_set(:@finished, true)
  saved.deactivate(view)
  check.call(sent.empty?, 'Region picker reported a cancel after it saved the region')
  dialog.singleton_class.send(:remove_method, :send_js)

  # R10: the manual Dim is styled with the manual settings; Auto-Style must be suspended while it is created.
  m = Sketchup::FakeModel.new; Sketchup.active_model = m
  depths = []
  m.entities.define_singleton_method(:add_dimension_linear) do |*args|
    depths << VGD::Dim::AutoStyle.instance_variable_get(:@depth)
    super(*args)
  end
  manual.send(:create_dimension, Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(100.mm, 0, 0), Geom::Vector3d.new(0, 50.mm, 0))
  check.call(depths == [1] && VGD::Dim::AutoStyle.instance_variable_get(:@depth) == 0, 'Manual Dim ran without suspending Auto-Style')

  # R11: the SketchUp year comes from Sketchup.version ("22.0.354"), not from version_number.
  info = {'product_id' => 'vgd_dim', 'filename' => 'VGD_Dim_v9.9.9.rbz', 'version' => '9.9.9', 'channel' => 'stable',
          'min_sketchup_year' => '2022', 'bytes' => 10, 'sha256' => 'a' * 64,
          'download_url' => 'https://github.com/vuongpentax/VGD_Plugins/releases/download/vgd-dim-v9.9.9/VGD_Dim_v9.9.9.rbz'}
  fake_client = Object.new
  fake_client.define_singleton_method(:check) { |&callback| callback.call(200, JSON.generate(info)) }
  results = {}
  Sketchup.define_singleton_method(:platform) { :platform_win }
  ['22.0.354', '21.1.332'].each do |version|
    Sketchup.define_singleton_method(:version) { version }
    updater = VGD::Dim::UpdateCore::Updater.new
    updater.instance_variable_set(:@client, fake_client)
    updater.check { |status, _value| results[version] = status }
  end
  Sketchup.define_singleton_method(:platform) { :platform_other }
  check.call(results['22.0.354'] == :available, 'SketchUp 2022 was rejected by the minimum-year check')
  check.call(results['21.1.332'] == :error, 'SketchUp 2021 passed the minimum-year check')

  # R12: a refused second download must not free the running one, and a network error keeps its message.
  Sketchup.const_set(:Http, Module.new) unless Sketchup.const_defined?(:Http)
  Sketchup::Http.const_set(:GET, 'GET') unless Sketchup::Http.const_defined?(:GET)
  pending_requests = []
  http_request = Class.new do
    attr_accessor :headers
    define_method(:initialize) { |_url, _method| }
    define_method(:start) { |&block| pending_requests << block }
    define_method(:cancel) { }
  end
  Sketchup::Http.send(:remove_const, :Request) if Sketchup::Http.const_defined?(:Request, false)
  Sketchup::Http.const_set(:Request, http_request)
  client = VGD::Dim::UpdateCore::Client.new
  body = 'x' * 10
  package = {'download_url' => 'https://github.com/x/y', 'bytes' => 10, 'sha256' => Digest::SHA256.hexdigest(body)}
  outcomes = []
  client.download(package) { |status, value| outcomes << [status, value] }
  client.download(package) { |status, value| outcomes << [status, value] }
  check.call(outcomes == [[:error, 'Đang có yêu cầu cập nhật khác.']] && client.instance_variable_get(:@busy), 'Refused download cleared the busy flag')
  response = Struct.new(:status_code, :body, :headers).new(200, body, {})
  pending_requests.shift.call(nil, response)
  check.call(outcomes.last == [:ok, body] && !client.instance_variable_get(:@busy), 'Download did not complete')
  outcomes.clear
  client.download(package) { |status, value| outcomes << [status, value] }
  UI.drain
  check.call(outcomes == [[:error, 'Hết thời gian chờ kết nối.']] && !client.instance_variable_get(:@busy), 'Timeout message was lost')

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

  puts 'PASS: regression — region errors do not abort unstarted operations; Auto-Style binds after a closed model, ignores erased entities, does not rebind needlessly and can always be turned off; tools re-enable the dialog, manual Dim suspends Auto-Style, updater year/busy/timeout'
end
