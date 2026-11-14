# frozen_string_literal: true
require 'securerandom'
require 'digest'

module VGD_Cabinet
  # Additive identity layer for editable cabinets and future VGD BIM/Quantity
  # extraction. Existing params_json dictionaries remain the compatibility
  # source while schema v2 identities are introduced without rebuilding geometry.
  module ModelData
    remove_const(:DICTIONARY) if const_defined?(:DICTIONARY, false)
    remove_const(:SCHEMA_VERSION) if const_defined?(:SCHEMA_VERSION, false)
    DICTIONARY = 'VGD_CabinetV2'.freeze
    SCHEMA_VERSION = 2
    module_function

    def cabinet_id(entity)
      return nil unless entity
      entity.get_attribute(DICTIONARY, 'cabinet_id', nil) ||
        %w[VGD_Cabinet TPlus_Cabinet].map { |dict| entity.get_attribute(dict, 'cabinet_id', nil) }.compact.first
    rescue
      nil
    end

    def assign_root(entity, id)
      entity.set_attribute(DICTIONARY, 'schema_version', SCHEMA_VERSION)
      entity.set_attribute(DICTIONARY, 'cabinet_id', id)
      entity.set_attribute(DICTIONARY, 'role', 'cabinet')
      entity
    end

    def stable_id(*tokens)
      Digest::SHA256.hexdigest(tokens.join('|'))[0, 32]
    end

    def assign_parts(entities, id, module_id = nil, parent_path = 'root')
      occurrences = Hash.new(0)
      entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        name = entity.name.to_s
        name = entity.definition.name.to_s if name.empty?
        role = entity.definition.get_attribute('VGD_CabinetPart', 'role', nil) || ComponentSharing.role(name)
        ordinal = occurrences[role]
        occurrences[role] += 1
        path = [parent_path, role, ordinal].join('/')
        current_module = name.start_with?('Module ') ? stable_id(id, path) : module_id
        entity.set_attribute(DICTIONARY, 'schema_version', SCHEMA_VERSION)
        entity.set_attribute(DICTIONARY, 'cabinet_id', id)
        entity.set_attribute(DICTIONARY, 'part_id', stable_id(id, path))
        entity.set_attribute(DICTIONARY, 'role', role)
        entity.set_attribute(DICTIONARY, 'module_id', current_module) if current_module
        apply_opening_metadata(entity, name)
        assign_parts(entity.definition.entities, id, current_module, path)
      end
    end

    def apply_opening_metadata(entity, name)
      label = name.to_s
      if label.match?(/\ACánh Trái/)
        entity.set_attribute(DICTIONARY, 'opening_kind', 'hinged')
        entity.set_attribute(DICTIONARY, 'opening_side', 'left')
        entity.set_attribute(DICTIONARY, 'open_angle', -85.0)
      elsif label.match?(/\ACánh Phải/)
        entity.set_attribute(DICTIONARY, 'opening_kind', 'hinged')
        entity.set_attribute(DICTIONARY, 'opening_side', 'right')
        entity.set_attribute(DICTIONARY, 'open_angle', 85.0)
      elsif label.match?(/\AMặt Ngăn Kéo/)
        entity.set_attribute(DICTIONARY, 'opening_kind', 'drawer')
        entity.set_attribute(DICTIONARY, 'opening_side', 'front')
        entity.set_attribute(DICTIONARY, 'open_distance', 400.0)
      end
    rescue
      nil
    end

    def stamp(entity, id = nil)
      id ||= cabinet_id(entity) || SecureRandom.uuid
      assign_root(entity, id)
      assign_parts(entity.definition.entities, id) if entity.respond_to?(:definition)
      id
    end
  end
end
