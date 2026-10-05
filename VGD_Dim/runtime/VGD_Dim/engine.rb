# encoding: UTF-8
module VGD
  module Dim
    module Engine
      extend self
      ENDPOINTS = %w[keep none slash dot closed open].freeze unless const_defined?(:ENDPOINTS, false)
      def selected(model)
        model.selection.to_a.select do |entity|
          entity.valid? && (entity.is_a?(Sketchup::Dimension) || entity.is_a?(Sketchup::Text))
        end
      end
      def check_context(model)
        Array(model.active_path).each do |instance|
          raise ArgumentError, 'Nhóm đang khóa; hãy mở khóa trước khi chỉnh.' if instance.locked?
          if instance.definition.instances.count { |copy| copy.valid? } > 1
            raise ArgumentError, 'Đang sửa component dùng chung. Hãy Make Unique bản cần sửa rồi chọn lại Dim/Text để giữ nguyên các bản khác.'
          end
        end
      end
      def get_material(model, name, hex)
        rgb = hex.delete('#').scan(/../).map { |part| part.to_i(16) }
        name = "#{name}_#{hex.delete('#').upcase}"
        material = model.materials[name]
        if material && [material.color.red, material.color.green, material.color.blue] == rgb
          return material
        end
        material = model.materials.add(name)
        material.color = Sketchup::Color.new(*rgb)
        material
      end
      def set_endpoint(entity, style)
        return if style == 'keep'
        types = {
          'none' => Sketchup::Dimension::ARROW_NONE,
          'slash' => Sketchup::Dimension::ARROW_SLASH,
          'dot' => Sketchup::Dimension::ARROW_DOT,
          'closed' => Sketchup::Dimension::ARROW_CLOSED,
          'open' => Sketchup::Dimension::ARROW_OPEN
        }
        entity.arrow_type = types.fetch(style)
      end
    end
  end
end
