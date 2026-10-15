# Run in the SketchUp Ruby Console after installing/loading VGD_Cabinet_Draw.
# Creates and removes a temporary test group in one operation and restores selection.
module VGD_Cabinet_DrawNativeSmoke
  extend self
  def run
    model = Sketchup.active_model
    original_selection = model.selection.to_a
    checks = []
    assert = ->(condition, message) { raise message unless condition; checks << "PASS #{message}" }
    assert.call(VGD_Cabinet_Draw::VERSION == '1.0.0-beta.1', 'extension loaded')
    assert.call(VGD_Cabinet_Draw::Schema::TOOLS.keys.sort == %w[blocker box cut door drawer handle notch opening panel round wardrobe].sort, 'all benchmark tool entry points registered')
    assert.call(VGD_Cabinet_Draw::Schema::DICTIONARY == 'VGD_Cabinet_Draw', 'isolated model dictionary')
    model.start_operation('VGD Cabinet Draw native smoke', true)
    box = model.active_entities.add_group
    box.name = 'native smoke box'
    face = box.entities.add_face([0,0,0],[800.mm,0,0],[800.mm,600.mm,0],[0,600.mm,0])
    face.pushpull(2400.mm)
    root = VGD_Cabinet_Draw::Geometry.cabinet_from_box(box, 'remove_source' => true)
    assert.call(root.valid? && VGD_Cabinet_Draw::ModelData.cabinet?(root), 'box converts and stamps model identity')
    shell = VGD_Cabinet_Draw::Geometry.shell_for(root)
    shell_parts = shell.definition.entities.to_a.select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
    assert.call(shell_parts.map(&:name).include?('Hông Trái') && shell_parts.map(&:name).include?('Hông Phải'), 'separate cabinet side panels are named')
    model.abort_operation
    model.selection.clear
    original_selection.each { |entity| model.selection.add(entity) if entity.valid? }
    { 'status' => 'PASS', 'checks' => checks, 'model_roots_preserved' => model.entities.count { |e| e.is_a?(Sketchup::Group) && e.name == 'native smoke box' } == 0 }
  rescue StandardError => e
    model.abort_operation if model
    { 'status' => 'FAIL', 'checks' => checks || [], 'error' => "#{e.class}: #{e.message}", 'backtrace' => e.backtrace.first(8) }
  end
end
puts "VGD_CABINET_DRAW_NATIVE #{JSON.generate(VGD_Cabinet_DrawNativeSmoke.run)}"
