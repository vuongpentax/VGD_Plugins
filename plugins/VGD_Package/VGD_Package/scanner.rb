# frozen_string_literal: true

module VGD
  module Pack
    class Scanner
      def scan(model = Sketchup.active_model)
        assets = []
        model.materials.each do |material|
          assets.concat(Adapters::SketchUpTexture.scan(material))
          assets.concat(Adapters::SketchUpPBR.scan(material))
        end
        assets
      end

      def report(model = Sketchup.active_model)
        assets = scan(model)
        counts = assets.each_with_object(Hash.new(0)) { |asset, memo| memo[asset.status] += 1 }
        {
          'format' => 'VGD_PACK_SCAN',
          'plugin_version' => PLUGIN_VERSION,
          'created_at' => Time.now.iso8601,
          'model' => model_path(model),
          'capabilities' => Compatibility.capabilities(model),
          'summary' => counts,
          'assets' => assets.map(&:to_h)
        }
      end

      private

      def model_path(model)
        model.path.to_s
      rescue StandardError
        ''
      end
    end
  end
end
