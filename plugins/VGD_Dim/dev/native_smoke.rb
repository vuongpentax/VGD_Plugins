# encoding: UTF-8
# Optional: load into an EMPTY test model, then VGDDimNativeSmoke.run.
# Automated checks compile this script without executing it.
module VGDDimNativeSmoke
  def self.run
    model = Sketchup.active_model
    raise 'Use an empty test model.' unless model.entities.empty?
    model.start_operation('VGD test annotations', true)
    begin
      dim = model.entities.add_dimension_linear([0,0,0], [100.mm,0,0], [0,20.mm,0])
      text = model.entities.add_text('VGD native test', [0,30.mm,0])
      outside = model.entities.add_dimension_linear([0,0,0], [200.mm,0,0], [0,40.mm,0])
      model.commit_operation
    rescue StandardError
      model.abort_operation
      raise
    end
    model.selection.clear
    model.selection.add([dim,text])
    before = [outside.material,outside.layer,outside.arrow_type]
    units = model.options['UnitsOptions'].to_a
    VGD::Dim::NativeStyle.apply(model, {'dim_color'=>'#112233','text_color'=>'#AABBCC',
                                       'dim_endpoint'=>'dot','label_endpoint'=>'closed'}) do |error|
      raise error if error
      raise 'Tag wrong' unless dim.layer.name == '000 DIM' && text.layer.name == '000 TEXT'
      raise 'Unselected dimension changed' unless before == [outside.material,outside.layer,outside.arrow_type]
      raise 'Global units changed' unless model.options['UnitsOptions'].to_a == units
      puts 'Native commands/setters dispatched. Visually verify Model Info font/Height, unselected font, Undo and save/reopen. SU2022 Ruby cannot read font for this assertion.'
    end
  end
end
