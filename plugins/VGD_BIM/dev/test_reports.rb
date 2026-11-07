model = Sketchup.active_model
entities = Sketchup::Entities.new
definition = Sketchup::Definition.new('O_CAM_DOI', Geom::Box.new(120.0/25.4,30.0/25.4,80.0/25.4), entities)
entities.parent = definition
entity = Sketchup::ComponentInstance.new(model, definition)
entity.name = '=HYPERLINK("https://example.invalid")'
VGD::BIM::Data.update(entity, category: 'electrical', item_type: 'socket', description: "Ổ cắm; phòng ngủ\nTầng 1", unit: 'pcs', quantity_method: 'count', zone: 'Phòng ngủ', floor: 'Tầng 1')
records = [{entity: entity, path: [entity], transform: Geom::Transformation.new, locked: false}]
report = VGD::BIM::ReportExporter.build('bim', records, model)
assert(report[:headers].include?('Mô tả tiếng Việt'), 'Vietnamese export headers missing')
assert(report[:rows].first.include?('Điện') && report[:rows].first.include?('Ổ cắm'), 'Export leaked internal classifications')
assert(VGD::BIM::Data.get(entity, :category) == 'electrical', 'Translation mutated stored schema')
path = '/tmp/bim_report.csv'
count = VGD::BIM::ReportExporter.write(path, 'bim', records, model)
bytes = File.binread(path)
assert(count == 1 && bytes.bytes[0,3] == [239,187,191], 'CSV row count or UTF-8 BOM wrong')
parsed = CSV.parse(bytes.byteslice(3..-1).force_encoding('UTF-8'), col_sep: ';')
assert(parsed.size == 2 && parsed[1].include?("Ổ cắm; phòng ngủ\nTầng 1"), 'CSV broke Unicode/semicolon/multiline text')
assert(parsed[1].any? { |v| v && v.start_with?("'=HYPERLINK") }, 'Spreadsheet formula injection not escaped')
assert(parsed[1].include?('120,0'), 'Vietnamese decimal format missing')
assert(VGD::BIM::ReportExporter.build('validation', records, model)[:rows].all? { |row| !row.join.include?('Missing') }, 'Validation report in English')
assert(VGD::BIM::ReportExporter.build('components', records, model)[:rows].first[2] == 1, 'Component occurrence export wrong')
face = Sketchup::Face.new
face.material = Struct.new(:display_name).new('SON TUONG')
face_record = {entity: face, path: [face], transform: Geom::Transformation.scaling(2,1,1), material: face.material, locked: false}
assert((VGD::BIM::ReportExporter.build('materials', [face_record], model)[:rows].first[1] - 4.0).abs < 1e-6, 'Material export dropped transform')
assert(VGD::BIM::ReportExporter.cell('  +cmd') == "'  +cmd", 'Whitespace formula escaped incorrectly')
assert(VGD::BIM::ReportExporter.cell(-3.5) == '-3,5', 'Numeric value escaped as text')
begin
  VGD::BIM::ReportExporter.build('pricing', records, model)
  raise 'Unexpected pricing report added'
rescue ArgumentError
end
puts 'PASS: Vietnamese report headers/values, stored schema unchanged, CSV BOM/decimal/quoting, formula-safe text, validation export'
