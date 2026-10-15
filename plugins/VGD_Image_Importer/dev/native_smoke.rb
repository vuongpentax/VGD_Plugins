# encoding: UTF-8
# Run ONLY as -RubyStartup in a newly created, isolated SketchUp process.
require 'sketchup.rb'
require 'json'
require 'fileutils'
module VGDImageImporterSmoke
  ROOT = File.expand_path('..', __dir__)
  OUTPUT = File.join(ROOT, 'outputs')
  REPORT = File.join(OUTPUT, "native_SU22_#{Process.pid}.json")
  extend self
  def record
    File.write(REPORT, JSON.pretty_generate(@report))
  end
  def finish(success, error = nil)
    @report[:success] = success
    @report[:error] = error if error
    @report[:finished] = Time.now.to_s
    record
    return unless @owns_model
    VGD_ImageImporter.instance_variable_get(:@dialog).close if VGD_ImageImporter.instance_variable_get(:@dialog)
    # This file is a fixture authored only in this new, empty test process.
    Sketchup.active_model.save(File.join(OUTPUT, "native_model_#{Process.pid}.skp"))
    UI.start_timer(0.2, false) { Sketchup.quit }
  end
  def start
    @report = { pid: Process.pid, sketchup: Sketchup.version, ruby: RUBY_VERSION, tests: [], started: Time.now.to_s }
    record
    model = Sketchup.active_model
    fixture = File.join(OUTPUT, 'empty_native.skp')
    allowed_path = model.path.empty? || File.expand_path(model.path).tr('\\','/').downcase == File.expand_path(fixture).tr('\\','/').downcase
    raise 'Refuse to test a non-empty/user model' unless allowed_path && model.entities.empty? && model.pages.empty?
    @owns_model = true
    %w[engine file_picker conversion main].each { |name| load File.join(ROOT, 'runtime', 'vgd_image_importer', name + '.rb') }
    @plugin = VGD_ImageImporter
    formats = File.join(OUTPUT, 'formats')
    png = File.join(formats, 'Ảnh người #1.png')
    image = Sketchup::ImageRep.new
    @report[:load_file_return] = image.load_file(png).inspect
    raise 'Pixel dimensions wrong' unless image.width == 16 && image.height == 12
    %w[png jpg bmp tif tga].each do |extension|
      result = @plugin.process_import({'itemsPerRow'=>2,'spacing'=>0}, [File.join(formats, "Ảnh người #1.#{extension}")])
      raise "#{extension}: #{result.inspect}" unless result['imported'] == 1 && result['failed'] == 0
      instance = model.entities.grep(Sketchup::ComponentInstance).last
      raise 'Standing component behavior missing' unless instance.definition.behavior.always_face_camera?
      raise 'Imported ratio wrong' unless (instance.definition.entities.grep(Sketchup::Image).first.width - 32.0.mm).abs < 0.0001
      before = model.entities.length
      Sketchup.undo
      raise 'Undo did not remove the import' unless model.entities.length == before - 1
      @report[:tests] << "#{extension}: Unicode source path, actual geometry, scale and single Undo"
    end
    result = @plugin.process_import({'importType'=>'flat'}, [png])
    raise result.inspect unless result['imported'] == 1
    instance = model.entities.grep(Sketchup::ComponentInstance).last
    raise 'Flat component not on XY plane' unless instance.bounds.depth < 0.0001
    Sketchup.undo
    existing = model.materials.add('VGD_Ảnh người #1')
    existing.texture = png
    result = @plugin.process_import({'importType'=>'texture_only'}, [png])
    raise result.inspect unless result['imported'] == 1 && model.materials.count == 2
    @report[:tests] << 'flat XY image and non-overwriting scaled material'
    single = "C:\\Ảnh người\\cây xanh.webp\0\0".encode('UTF-16LE')
    raise 'Unicode picker parsing failed' unless @plugin::FilePicker.parse_result(single).length == 1
    @report[:tests] << '64-bit Fiddle loaded and native picker Unicode result parsing'
    require 'fiddle'
    raise 'Wrong native ABI' unless Fiddle::SIZEOF_VOIDP == 8
    # Instrument only result/ready delivery, leaving native callbacks, decoder,
    # PNG staging and import engine intact. Run through SketchUp's own Chromium.
    singleton = class << @plugin; self; end
    singleton.alias_method(:smoke_send_ui, :send_ui)
    singleton.define_method(:send_ui) do |event, data|
      smoke_send_ui(event, data)
      VGDImageImporterSmoke.on_event(event, data)
    end
    @plugin.instance_variable_set(:@files, %w[webp gif avif ico svg jfif].map { |ext| File.join(formats, "Ảnh người #1.#{ext}") })
    @plugin.show_dialog
    @report[:waiting_for] = 'CEF conversion and native imports'
    record
    UI.start_timer(60, false) { finish(false, 'CEF integration test timed out') unless @report[:finished] }
  rescue Exception => error
    finish(false, { message: error.message, backtrace: error.backtrace })
  end
  def on_event(event, data)
    if event == 'files' && !@triggered
      @triggered = true
      UI.start_timer(0.2, false) do
        @plugin.instance_variable_get(:@dialog).execute_script('VGDImporter.startImport();')
      end
    elsif event == 'result'
      @report[:converted_result] = data
      raise "Converted imports failed: #{data.inspect}" unless data['imported'] == 6 && data['failed'] == 0
      webp = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).find { |instance| instance.definition.get_attribute('VGD_ImageImporter','source').to_s.end_with?('.webp') }
      pixels = webp.definition.entities.grep(Sketchup::Image).first.image_rep
      raise 'WebP dimensions changed' unless pixels.width == 16 && pixels.height == 12
      @report[:webp_bpp] = pixels.bits_per_pixel
      raise 'WebP lost alpha channel' unless pixels.bits_per_pixel == 32
      @report[:tests] << 'WebP/GIF/AVIF/ICO/SVG/JFIF converted in SU22 CEF and imported as actual components; alpha preserved'
      finish(true)
    elsif event == 'status' && data['error']
      finish(false, data['message'])
    end
  rescue Exception => error
    finish(false, { message: error.message, backtrace: error.backtrace })
  end
end
UI.start_timer(2, false) { VGDImageImporterSmoke.start }
