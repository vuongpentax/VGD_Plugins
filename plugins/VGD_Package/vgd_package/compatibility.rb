# frozen_string_literal: true

module VGD
  module Pack
    module Compatibility
      PBR_CHANNELS = %w[normal_texture roughness_texture ao_texture metallic_texture].freeze
      module_function

      def version
        Sketchup.version.to_s
      rescue StandardError
        'unknown'
      end

      def major_version
        value = version.to_i
        value < 100 ? value + 2000 : value
      end

      def year_version
        major_version
      end

      def supported?
        major_version >= 2022
      end

      def native_texture?
        defined?(Sketchup::Material) && Sketchup::Material.method_defined?(:texture) &&
          defined?(Sketchup::Texture) && Sketchup::Texture.method_defined?(:filename) &&
          Sketchup::Texture.method_defined?(:write)
      end

      # Detect the complete public PBR texture getter set at runtime. This avoids
      # referencing SU2025-only methods on SketchUp 2022-2024.
      def pbr_channels(material = nil)
        return [] unless material
        PBR_CHANNELS.select { |method_name| material.respond_to?(method_name) }
      rescue StandardError
        []
      end

      def pbr_texture_api?(materials = nil)
        !available_pbr_channels.empty?
      rescue StandardError
        false
      end

      def available_pbr_channels
        return [] unless defined?(Sketchup::Material)
        PBR_CHANNELS.select { |method_name| Sketchup::Material.method_defined?(method_name.to_sym) }
      rescue StandardError
        []
      end

      def capabilities(model = nil)
        materials = model && model.materials ? model.materials.to_a : []
        {
          'sketchup_version' => version,
          'sketchup_year' => year_version,
          'supported' => supported?,
          'native_texture' => native_texture?,
          'native_pbr_api' => pbr_texture_api?(materials),
          'pbr_channels' => available_pbr_channels,
          'enscape' => 'read_only_inspection'
        }
      rescue StandardError
        {
          'sketchup_version' => version,
          'sketchup_year' => year_version,
          'supported' => supported?,
          'native_texture' => native_texture?,
          'native_pbr_api' => false,
          'pbr_channels' => available_pbr_channels,
          'enscape' => 'read_only_inspection'
        }
      end
    end
  end
end
