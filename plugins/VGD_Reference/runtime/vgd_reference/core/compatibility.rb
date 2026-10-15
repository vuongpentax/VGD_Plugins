module VGD
  module Reference
    module Compatibility
      module_function

      def supported?(model = nil)
        return false if Sketchup.version.to_i < MIN_SKETCHUP_VERSION
        return false unless defined?(Sketchup::Overlay)
        !model || model.respond_to?(:overlays)
      end
    end
  end
end
