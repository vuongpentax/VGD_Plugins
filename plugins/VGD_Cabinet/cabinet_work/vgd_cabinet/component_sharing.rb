# frozen_string_literal: true
require 'digest'
require 'json'
module VGD_Cabinet
  # Share only matching parts in this cabinet build. Dimensions, local geometry,
  # materials and hinge side are part of the key; names alone are not sufficient.
  module ComponentSharing
    module_function
    def role(name)
      name.to_s.sub(/_DC(?:#\d+)?$/, '').sub(/\s+\d+(?:\.\d+)*$/, '')
    end
    def coordinates(point)
      point.to_a.map { |n| n.to_f.round(7) }
    end
    def material_name(material)
      material && (material.respond_to?(:name) ? material.name : material.to_s)
    end
    def content_key(entities)
      entities.map do |entity|
        if entity.is_a?(Sketchup::Face)
          loops = if entity.respond_to?(:loops)
            entity.loops.map { |loop| loop.vertices.map { |v| coordinates(v.position) } }
          else
            [entity.vertices.map { |v| coordinates(v.position) }]
          end
          ['face', loops, material_name(entity.material), entity.respond_to?(:back_material) ? material_name(entity.back_material) : nil]
        elsif entity.is_a?(Sketchup::ConstructionLine)
          if entity.respond_to?(:start)
            ['guide', coordinates(entity.start), coordinates(entity.end)]
          else
            ['guide', *entity.ends.map { |p| coordinates(p) }]
          end
        elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          definition = entity.definition
          ['part', role(entity.name.empty? ? definition.name : entity.name), entity.transformation.to_a.map { |n| n.round(7) },
           material_name(entity.material), content_key(definition.entities)]
        elsif entity.is_a?(Sketchup::Edge)
          ['edge', coordinates(entity.start.position), coordinates(entity.end.position), entity.soft?, entity.smooth?]
        end
      end.compact.sort_by { |item| JSON.generate(item) }
    end
    def apply(entities, shared = {})
      entities.to_a.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        original_name = entity.name.to_s
        original_name = entity.definition.name.to_s if original_name.empty?
        apply(entity.definition.entities, shared)
        # Keep module containers and moving drawer assemblies independent.
        next if original_name.start_with?('Module ', 'Ngăn Kéo Khoang ', 'Bộ Ngăn Kéo ')
        part_role = role(original_name)
        next if part_role.empty?
        signature = Digest::SHA256.hexdigest(JSON.generate([part_role, material_name(entity.material), content_key(entity.definition.entities)]))
        component = entity.is_a?(Sketchup::Group) ? entity.to_component : entity
        component.name = original_name
        if shared.key?(signature)
          component.definition = shared[signature]
        else
          component.definition.name = part_role + (part_role.start_with?('Cánh') ? '_DC' : '')
          component.definition.set_attribute('VGD_CabinetPart', 'role', part_role)
          shared[signature] = component.definition
        end
      end
      shared
    end
  end
end
