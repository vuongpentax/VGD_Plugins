# Measuring each scene of a set through VGD Dim. Dim is replaced by a stub that records every call.
module VGD
  module Dim
    module SmartDim
      @calls = []
      @fail_on = nil
      class << self
        attr_reader :calls
        attr_accessor :fail_on

        def saved
          { 'opts' => { 'face' => 'camera', 'use_section' => false, 'scene_only' => false, 'do_h' => true, 'do_v' => true,
                        'h_side' => 'top', 'v_side' => 'left', 'off1' => 150.0, 'off2' => 300.0, 'min_seg' => 5.0, 'min_part' => 300.0, 'depth' => 100.0 },
            'settings' => { 'dim' => { 'arrow' => 'dot' } } }
        end

        def run(opts, style)
          model = Sketchup.active_model
          page = model.pages.selected_page
          @calls << { page: page.name, opts: opts, style: style, transition: model.options['PageOptions']['ShowTransition'] }
          raise 'Simulated Dim failure' if @fail_on && page.name.include?(@fail_on)
        end
      end
    end
  end
end

s = VGD::Scenes
sets = s::SectionSet
dim = VGD::Dim::SmartDim
bridge = s::DimBridge
assert(bridge.available?, 'The Dim stub should count as available')

def wardrobe_model(width = 1000.0)
  m = Sketchup::Model.new; Sketchup.active_model = m
  m.selection.add(product(m, width / 25.4, 600.0 / 25.4, 800.0 / 25.4, 'Tủ quần áo'))
  m.options['PageOptions']['ShowTransition'] = true
  m
end
wardrobe = { 'preset' => 'wardrobe', 'views' => %w[FRONT RIGHT TOP ISO],
             'sections' => [{ 'name' => 'A-A', 'axis' => 'Y', 'percent' => 50 }, { 'name' => 'B-B', 'axis' => 'X', 'percent' => 50 },
                            { 'name' => 'C-C', 'axis' => 'Z', 'percent' => 50 }],
             'options' => { 'paper' => 'A3_L', 'scale_mode' => 'auto' } }

# --- Normal run: every scene except ISO is measured, each with its scene open.
m = wardrobe_model
dim.calls.clear
result = sets.apply(m, wardrobe.merge('dimension' => true))
calls = dim.calls
assert(calls.length == 6, "Expected 6 measured scenes, got #{calls.length}")
assert(calls.map { |call| call[:page][/FRONT|RIGHT|TOP|ISO|SEC_[A-Z]-[A-Z]/] } == %w[FRONT RIGHT TOP SEC_A-A SEC_B-B SEC_C-C], 'Scenes must be measured in set order, ISO skipped')
faces = calls.first(3).map { |call| [call[:opts]['face'], call[:opts]['use_section']] }
assert(faces == [['-y', false], ['+x', false], ['+z', false]], "Views must measure their own face: #{faces}")
assert(calls.last(3).all? { |call| call[:opts]['use_section'] && call[:opts]['face'] == 'camera' }, 'Sections must measure along their cut')
assert(calls.all? { |call| call[:opts]['scene_only'] && call[:opts]['off1'] == 150.0 && call[:opts]['min_part'] == 300.0 && call[:style] == { 'dim' => { 'arrow' => 'dot' } } },
       "Saved Dim options must be kept and Scene-only turned on: #{calls.first}")
assert(calls.all? { |call| call[:transition] == false }, 'Scene transitions must be off while Dim reads the camera')
assert(m.options['PageOptions']['ShowTransition'] == true, 'Scene transition setting was not restored')
assert(m.pages.selected_page.name.include?('FRONT'), 'The first scene of the set must be open at the end')
assert(result[:success] && result[:dimensions]['measured'] == 6 && result[:dimensions]['skipped'] == 1, "Unexpected counts: #{result[:dimensions]}")
assert(result[:message].include?('kích thước cho 6 scene') && result[:warnings].empty?, "Message/warnings wrong: #{result[:message]}")

# --- Not requested: Dim is not called and the result carries no dimension data.
dim.calls.clear
plain = sets.apply(m, wardrobe)
assert(dim.calls.empty? && plain[:dimensions].nil?, 'Dim must not run unless requested')

# --- One scene fails: the others are still measured and the set is kept.
dim.calls.clear; dim.fail_on = 'RIGHT'
partial = sets.apply(m, wardrobe.merge('dimension' => true))
dim.fail_on = nil
assert(partial[:success] && partial[:dimensions]['measured'] == 5, 'A failing scene must not stop the others')
assert(partial[:warnings].length == 1 && partial[:warnings].first.include?('RIGHT') && partial[:warnings].first.include?('Simulated Dim failure'), "Failure not reported: #{partial[:warnings]}")
assert(m.options['PageOptions']['ShowTransition'] == true, 'Transition setting must be restored after a failure')

# --- Dim is not installed: scenes are still created, with a clear warning.
saved_module = VGD::Dim.send(:remove_const, :SmartDim)
begin
  assert(!bridge.available?, 'Removing Dim should make the bridge unavailable')
  m2 = wardrobe_model
  without = sets.apply(m2, wardrobe.merge('dimension' => true))
  assert(without[:success] && m2.pages.length == 7, 'Scenes must still be created without Dim')
  assert(without[:dimensions]['measured'] == 0 && without[:warnings].any? { |warning| warning.include?('VGD Dim') }, 'Missing Dim must be reported')
ensure
  VGD::Dim.const_set(:SmartDim, saved_module)
end
assert(bridge.available?, 'Dim stub was not restored')

# --- The flag comes from the dialog as a plain boolean.
assert(sets.normalize(wardrobe.merge('dimension' => true))['dimension'] == true, 'dimension flag lost')
assert(sets.normalize(wardrobe.merge('dimension' => 'yes'))['dimension'] == false, 'Only a real true may switch Dim on')
puts 'PASS: Dim bridge — per-scene faces and sections, saved options kept, transitions restored, failure isolation, missing Dim warning'
