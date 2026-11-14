# frozen_string_literal: true

module VGD
  module Pack
    module Adapters
      module SketchUpTexture
        module_function

        def scan(material)
          texture = material.texture if material.respond_to?(:texture)
          return [] unless texture
          [Asset.new(material_name: material.name, channel: 'diffuse', texture: texture,
                     source_type: 'sketchup')]
        rescue StandardError => e
          [Asset.new(material_name: material.respond_to?(:name) ? material.name : '(unknown)',
                     channel: 'diffuse', texture: nil, source_type: 'sketchup')].tap do |assets|
            assets.first.instance_variable_set(:@status, 'UNKNOWN')
            assets.first.instance_variable_set(:@error, e.message)
          end
        end
      end
    end
  end
end
