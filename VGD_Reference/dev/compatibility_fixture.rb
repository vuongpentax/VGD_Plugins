module VGD
  module Reference
    original_version = Sketchup.method(:version)
    model_with_overlays = Object.new
    def model_with_overlays.overlays; []; end
    begin
      Sketchup.define_singleton_method(:version) { '22.0.354' }
      raise 'SU2022 must not be advertised as supported.' if Compatibility.supported?(model_with_overlays)
      Sketchup.define_singleton_method(:version) { '24.0.484' }
      raise 'SU2024 with Overlay was rejected.' unless Compatibility.supported?(model_with_overlays)
      raise 'Missing Model#overlays was not guarded.' if Compatibility.supported?(Object.new)
      raise 'Minimum version incorrectly lowered.' unless MIN_SKETCHUP_VERSION == 23
    ensure
      Sketchup.define_singleton_method(:version, original_version)
    end
    puts 'PASS: SU2022 stays unsupported; SU2024 Overlay capability and minimum version are checked.'
  end
end
