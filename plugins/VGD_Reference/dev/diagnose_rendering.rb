# encoding: UTF-8
# Run from SketchUp's Ruby Console. This probe uses RAM overlays only.
require 'json'
require 'fileutils'

module VGDReferenceDiagnostics
  OVERLAY_ID = 'vgd.reference.render.diagnostics'.freeze unless const_defined?(:OVERLAY_ID, false)
  VARIANTS = [
    ['quads-vector-z0', :quads, :vector, 0],
    ['quads-array-z0', :quads, :array, 0],
    ['quads-vector-z1', :quads, :vector, 1],
    ['quads-array-z1', :quads, :array, 1],
    ['triangles-vector-z0', :triangles, :vector, 0],
    ['triangles-array-z0', :triangles, :array, 0],
    ['strip-vector-z0', :strip, :vector, 0],
    ['quads-reversed-z0', :reversed, :vector, 0]
  ].freeze unless const_defined?(:VARIANTS, false)

  module_function

  def run
    cleanup
    @model = Sketchup.active_model
    raise 'Cần SketchUp 2023 trở lên.' unless Sketchup.version.to_i >= 23
    raise 'Không có model đang mở.' unless @model
    @view = @model.active_view
    @output = File.expand_path("../outputs/render-diagnostics/#{Time.now.strftime('%Y%m%d-%H%M%S')}", __dir__)
    FileUtils.mkdir_p(@output)
    @report = {
      sketchup_version: Sketchup.version,
      ruby_version: RUBY_VERSION,
      graphics_engine: @view.respond_to?(:graphics_engine) ? @view.graphics_engine : 'unavailable',
      plugin_version: defined?(VGD::Reference::VERSION) ? VGD::Reference::VERSION : 'not loaded',
      viewport: [@view.vpwidth, @view.vpheight],
      rendering_options: @model.rendering_options.to_a.select { |key, _value| %w[RenderMode Texture DisplayColorByLayer MaterialTransparency ModelTransparency].include?(key) }.to_h,
      methods: %i[draw draw2d load_texture].to_h { |name| [name, method_info(@view.method(name))] },
      before: model_state,
      errors: []
    }
    if defined?(VGD::Reference::ReferenceOverlay)
      @report[:plugin_draw_method] = method_info(VGD::Reference::ReferenceOverlay.instance_method(:draw))
    end
    inspect_references
    @pattern = make_pattern
    @pattern.save_file(File.join(@output, 'expected-pattern.png'))
    @probe = Probe.new(@pattern)
    @model.overlays.add(@probe)
    @probe.enabled = true
    @probe.start
    @view.invalidate
    @timer = UI.start_timer(1.0, false) { capture_and_finish }
    puts "[VGD] Đang thử texture trực tiếp trong SketchUp..."
    @output
  rescue StandardError => error
    record_error(error)
    finish
    nil
  end

  def method_info(method)
    { owner: method.owner.to_s, source_location: method.source_location, parameters: method.parameters }
  end

  def model_state
    { entity_count: @model.entities.length, modified: @model.modified? }
  end

  def inspect_references
    @report[:references] = []
    return unless defined?(VGD::Reference::Session) && VGD::Reference::Session.store
    entries = VGD::Reference::TextureCache.entries
    VGD::Reference::Session.store.items.each_with_index do |item, index|
      entry = entries[item.id]
      rep = entry && (entry[:active_rep] || entry[:base_rep])
      info = {
        name: File.basename(item.source_path), source_exists: File.file?(item.source_path),
        dimensions: [item.image_width, item.image_height],
        frame: [item.x, item.y, item.width, item.height],
        uv_window: [item.view_u0, item.view_v0, item.view_u1, item.view_v1],
        opacity: item.opacity, texture_id: item.texture_id,
        cache_id: entry && entry[:texture_id], same_view: entry && entry[:view] == @view
      }
      if rep
        info[:decoded_image] = { width: rep.width, height: rep.height, bpp: rep.bits_per_pixel, padding: rep.row_padding, bytes: rep.data.bytesize }
        info[:decoded_samples] = [0.2, 0.5, 0.8].product([0.2, 0.5, 0.8]).map { |u, v| sample_rgb(rep, (u * (rep.width - 1)).round, (v * (rep.height - 1)).round) }
        if index.zero?
          rep.save_file(File.join(@output, 'cached-source.png'))
          info[:saved_decode] = 'cached-source.png'
        end
      end
      @report[:references] << info
    rescue StandardError => error
      @report[:references] << { name: File.basename(item.source_path), error: error.message }
    end
  end

  def make_pattern
    palette = [[240, 20, 20, 255], [20, 220, 20, 255], [20, 40, 240, 255], [240, 220, 20, 255]]
    palette.map! { |rgba| rgba.values_at(2, 1, 0, 3) } if Sketchup.platform == :platform_win
    data = ''.b
    64.times do |y|
      64.times { |x| data << palette[(y / 32) * 2 + x / 32].pack('C*') }
    end
    Sketchup::ImageRep.new.set_data(64, 64, 32, 0, data)
  end

  def sample_rgb(rep, x, y)
    bytes = rep.bits_per_pixel.to_i / 8
    raise 'Unsupported export pixel format.' unless [3, 4].include?(bytes)
    x = [[x.to_i, 0].max, rep.width - 1].min
    y = [[y.to_i, 0].max, rep.height - 1].min
    offset = y * (rep.width * bytes + rep.row_padding) + x * bytes
    rgb = rep.data.byteslice(offset, 3).bytes
    Sketchup.platform == :platform_win ? rgb.reverse : rgb
  end

  def capture_and_finish
    @timer = nil
    @view.refresh
    path = File.join(@output, 'viewport-probe.png')
    result = @view.write_image(filename: path, width: @view.vpwidth, height: @view.vpheight, antialias: false, transparent: false)
    @report[:export_success] = result
    @report[:draw_count] = @probe.draw_count
    @report[:probe_texture_id] = @probe.texture_id
    @report[:draw_errors] = @probe.errors
    if result && File.file?(path)
      rep = Sketchup::ImageRep.new(path)
      # Some SketchUp exporters omit Ruby drawing. A magenta marker makes an
      # omitted overlay an explicit inconclusive result, never a false failure.
      direct = sample_rgb(rep, 12, 12)
      flipped = sample_rgb(rep, 12, rep.height - 1 - 12)
      marker = ->(rgb) { rgb[0] > 200 && rgb[1] < 60 && rgb[2] > 200 }
      flip = !marker.call(direct) && marker.call(flipped)
      included = marker.call(direct) || marker.call(flipped)
      @report[:export_includes_overlay] = included
      @report[:export_marker_samples] = [direct, flipped]
      @report[:panels] = @probe.panels.map do |panel|
        x, y, size = panel[:rect]
        samples = [0.25, 0.75].product([0.25, 0.75]).map do |u, v|
          sy = (y + size * v).round
          sy = rep.height - 1 - sy if flip
          sample_rgb(rep, (x + size * u).round, sy)
        end
        distinct = samples.each_with_object([]) do |rgb, colors|
          colors << rgb unless colors.any? { |other| rgb.zip(other).all? { |a, b| (a - b).abs < 40 } }
        end.length
        panel.merge(samples: samples, distinct_colors: distinct, result: !included ? 'inconclusive-export-omits-overlay' : distinct >= 3 ? 'texture-visible' : 'flat-or-missing')
      end
    end
  rescue StandardError => error
    record_error(error)
  ensure
    finish(remove_probe: false)
  end

  def record_error(error)
    @report ||= { errors: [] }
    @report[:errors] << { type: error.class.to_s, message: error.message, backtrace: error.backtrace&.first(8) }
    puts "[VGD] #{error.class}: #{error.message}"
  end

  def finish(remove_probe: true)
    cleanup if remove_probe
    return unless @output && @report
    @report[:after] = model_state if @model
    File.write(File.join(@output, 'report.json'), JSON.pretty_generate(@report), mode: 'w', encoding: 'UTF-8')
    puts "[VGD] Hoàn tất chẩn đoán: #{@output}"
    puts "[VGD] #{JSON.generate(@report.slice(:graphics_engine, :plugin_version, :rendering_options, :export_includes_overlay, :panels, :errors))}"
    puts '[VGD] Chụp màn hình các ô thử. Gỡ phép thử bằng VGDReferenceDiagnostics.cleanup' unless remove_probe
  end

  def cleanup
    UI.stop_timer(@timer) if @timer
    @timer = nil
    if @probe && @model
      @probe.stop(@view)
      @model.overlays.remove(@probe) if @probe.valid?
      @probe = nil
      @view.invalidate if @view
    end
  end

  class Probe < Sketchup::Overlay
    attr_reader :errors, :panels, :draw_count, :texture_id

    def initialize(rep)
      super(OVERLAY_ID, 'VGD — Kiểm tra texture')
      @rep = rep
      @errors = {}
      @panels = []
      @draw_count = 0
      @texture_id = nil
    end

    def start
      return if @texture_id
      @view = Sketchup.active_model.active_view
      @texture_id = @view.load_texture(@rep)
    rescue StandardError => error
      @errors['load_texture'] = "#{error.class}: #{error.message}"
    end

    def stop(view = nil)
      target = @view || view
      target.release_texture(@texture_id) if @texture_id && target
      @texture_id = nil
    end

    def getExtents
      Sketchup.active_model.bounds
    end

    def draw(view)
      @draw_count += 1
      view.drawing_color = 'magenta'
      view.draw2d(GL_QUADS, [[4, 4, 0], [20, 4, 0], [20, 20, 0], [4, 20, 0]])
      return unless @texture_id
      size = [[(view.vpwidth - 64) / 4.0 - 12, (view.vpheight - 100) / 2.0 - 26, 140].min, 24].max
      @panels = []
      VARIANTS.each_with_index do |(name, topology, type, z), index|
        x = 24 + (index % 4) * (size + 12)
        y = 48 + (index / 4) * (size + 38)
        @panels << { name: name, rect: [x, y, size] }
        view.drawing_color = 'white'
        points = [[x, y, 0], [x + size, y, 0], [x + size, y + size, 0], [x, y + size, 0]]
        uv = [[0, 1, z], [1, 1, z], [1, 0, z], [0, 0, z]]
        uv.map! { |values| Geom::Vector3d.new(*values) } if type == :vector
        indices, primitive = case topology
                             when :triangles then [[0, 1, 2, 0, 2, 3], GL_TRIANGLES]
                             when :strip then [[0, 1, 3, 2], GL_TRIANGLE_STRIP]
                             when :reversed then [[0, 3, 2, 1], GL_QUADS]
                             else [[0, 1, 2, 3], GL_QUADS]
                             end
        begin
          view.draw2d(primitive, points.values_at(*indices), texture: @texture_id, uvs: uv.values_at(*indices))
        rescue StandardError => error
          @errors[name] = "#{error.class}: #{error.message}"
        end
        view.drawing_color = 'black'
        view.draw_text([x, y - 18, 0], name, size: 9)
      end
    ensure
      view.drawing_color = 'white'
    end
  end
end

VGDReferenceDiagnostics.run
