# encoding: UTF-8
# Read-only diagnostic for the Ruby Console; no popup or model mutation.
module VGD
  module Dim
    module Probe
      def self.run
        puts JSON.pretty_generate({'name'=>'VGD Dim','version'=>VGD::Dim::VERSION,
          'ruby'=>RUBY_VERSION,'platform'=>Sketchup.platform.to_s,
          'animation'=>Animation.read(Sketchup.active_model),
          'selected'=>Core.summary(Core.scan(Sketchup.active_model,{}))})
      end
    end
  end
end
