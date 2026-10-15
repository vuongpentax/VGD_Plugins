# Load this file from the Ruby Console in a disposable SketchUp 2024 model.
# It draws one source image over the viewport and exposes alpha/RMB observations.
module VGDReferenceSpike
  class OverlayProbe < Sketchup::Overlay
    attr_accessor :alpha

    def initialize(image_rep)
      super('vgd.reference.spike.overlay', 'VGD Reference Overlay Spike')
      @image_rep = image_rep
      @texture_id = nil
      @alpha = 128
    end

    def start
      @texture_id = Sketchup.active_model.active_view.load_texture(@image_rep)
    end

    def stop(view = nil)
      view ||= Sketchup.active_model.active_view
      view.release_texture(@texture_id) if @texture_id && view
      @texture_id = nil
    end

    def getExtents
      Sketchup.active_model.bounds
    end

    def draw(view)
      return unless @texture_id
      width = view.vpwidth * 0.35
      height = width * @image_rep.height.to_f / @image_rep.width
      x = (view.vpwidth - width) / 2.0
      y = (view.vpheight - height) / 2.0
      points = [
        Geom::Point3d.new(x, y, 0), Geom::Point3d.new(x + width, y, 0),
        Geom::Point3d.new(x + width, y + height, 0), Geom::Point3d.new(x, y + height, 0)
      ]
      uvs = [
        [0.0, 1.0, 0.0], [1.0, 1.0, 0.0],
        [1.0, 0.0, 0.0], [0.0, 0.0, 0.0]
      ]
      view.drawing_color = Sketchup::Color.new(255, 255, 255, @alpha)
      draw_options = { texture: @texture_id, uvs: uvs }
      view.draw2d(GL_QUADS, points, **draw_options)
      view.drawing_color = Sketchup::Color.new(255, 255, 255, 255)
    end

    def onMouseMove(flags, x, y, _view)
      return if (flags.to_i & 2).zero?
      puts("[VGD Reference spike] RMB held; overlay received x=#{x}, y=#{y}, flags=#{flags}")
    end
  end

  module_function

  def run
    return UI.messagebox('Run this spike in SketchUp 2023 or newer.') if Sketchup.version.to_i < 23
    path = UI.openpanel('Choose a JPG or PNG for the overlay spike', '', 'Images|*.jpg;*.jpeg;*.png||')
    return unless path
    image = Sketchup::ImageRep.new
    image.load_file(path)
    raise 'Unable to load selected image.' unless image.width.to_i.positive? && image.height.to_i.positive?
    @probe = OverlayProbe.new(image)
    Sketchup.active_model.overlays.add(@probe)
    @probe.enabled = true
    UI.messagebox("Overlay probe added. Adjust alpha in Ruby Console with VGDReferenceSpike.alpha = 64.\nRun VGDReferenceSpike.cleanup when finished.")
  rescue StandardError => error
    UI.messagebox("Overlay spike failed: #{error.message}")
  end

  def alpha=(value)
    return unless @probe
    @probe.alpha = [[value.to_i, 0].max, 255].min
    Sketchup.active_model.active_view.invalidate
  end

  def cleanup
    return unless @probe
    model = Sketchup.active_model
    @probe.stop(model.active_view)
    model.overlays.remove(@probe) if @probe.valid?
    @probe = nil
  rescue StandardError => error
    puts("[VGD Reference spike] cleanup failed: #{error.message}")
  end
end
