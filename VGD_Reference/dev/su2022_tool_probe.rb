# encoding: UTF-8
# Isolated SU2022 investigation. Loading defines the probe; it does not start it.
# Run VGDReferenceSU2022Probe.run in Ruby Console on a disposable model.
# This is a Tool experiment, not the production passive overlay backend.
require 'json'
require 'fileutils'

module VGDReferenceSU2022Probe
  class Tool
    def initialize(report_path)
      @report_path = report_path
      @report = {
        sketchup: Sketchup.version, ruby: RUBY_VERSION,
        cef: defined?(UI::HtmlDialog::CEF_VERSION) ? UI::HtmlDialog::CEF_VERSION : nil,
        overlay_class: !!defined?(Sketchup::Overlay),
        model_overlays: Sketchup.active_model.respond_to?(:overlays),
        entities_before: Sketchup.active_model.entities.length,
        modified_before: Sketchup.active_model.modified?, events: []
      }
    end

    def activate
      view = Sketchup.active_model.active_view
      colors = [[255, 0, 0, 255], [0, 220, 0, 255], [0, 0, 255, 255], [255, 220, 0, 255]]
      bytes = []
      32.times { |y| 32.times { |x| bytes.concat(colors[(y >= 16 ? 2 : 0) + (x >= 16 ? 1 : 0)]) } }
      @image = Sketchup::ImageRep.new
      @image.set_data(32, 32, 32, 0, bytes.pack('C*'))
      @texture = view.load_texture(@image)
      @report[:events] << { event: 'activate', texture_id: @texture }
      view.invalidate
      save_report
      puts '[VGD SU2022 probe] Kiểm tra ô bốn màu. Chọn Line/Select để kiểm tra ảnh khi đổi tool; Esc kết thúc.'
    rescue StandardError => error
      record_error('activate', error)
    end

    def draw(view)
      return unless @texture
      points = [[30, 30, 0], [230, 30, 0], [230, 230, 0], [30, 230, 0]]
      uvs = [[0.0, 1.0, 0.0], [1.0, 1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
      view.drawing_color = Sketchup::Color.new(255, 255, 255, 255)
      view.draw2d(GL_QUADS, points, texture: @texture, uvs: uvs)
      @report[:draw_called] = true
    rescue StandardError => error
      record_error('draw', error)
    end

    def suspend(view)
      @report[:events] << { event: 'suspend' }
      save_report
      view.invalidate
    end

    def resume(view)
      @report[:events] << { event: 'resume' }
      save_report
      view.invalidate
    end

    def deactivate(view)
      view.release_texture(@texture) if @texture
      @texture = nil
      @image = nil
      @report[:events] << { event: 'deactivate' }
      @report[:entities_after] = Sketchup.active_model.entities.length
      @report[:modified_after] = Sketchup.active_model.modified?
      save_report
      view.invalidate
    rescue StandardError => error
      record_error('deactivate', error)
    end

    def onCancel(_reason, _view)
      Sketchup.active_model.select_tool(nil)
    end

    private

    def record_error(event, error)
      @report[:events] << { event: event, error: error.class.name, message: error.message }
      save_report
      puts "[VGD SU2022 probe] #{event}: #{error.message}"
    end

    def save_report
      FileUtils.mkdir_p(File.dirname(@report_path))
      File.write(@report_path, JSON.pretty_generate(@report))
    end
  end

  def self.run
    path = File.expand_path('../outputs/su2022-probe/report.json', __dir__)
    Sketchup.active_model.select_tool(Tool.new(path))
    puts "[VGD SU2022 probe] Báo cáo: #{path}"
  end
end
