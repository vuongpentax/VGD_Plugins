# frozen_string_literal: true

module VGD
  module Pack
    module Adapters
      module SketchUpPBR
        CHANNELS = {
          'normal_texture' => 'normal',
          'roughness_texture' => 'roughness',
          'ao_texture' => 'ao',
          'metallic_texture' => 'metallic'
        }.freeze
        module_function

        def supported?(material)
          !Compatibility.pbr_channels(material).empty?
        end

        def scan(material)
          CHANNELS.each_with_object([]) do |(getter, channel), assets|
            begin
              next unless material.respond_to?(getter)
              texture = material.public_send(getter)
              next unless texture
              assets << Asset.new(material_name: material.name, channel: channel,
                                  texture: texture, source_type: 'sketchup_pbr')
            rescue StandardError
              next
            end
          end
        end
      end
    end
  end
end
