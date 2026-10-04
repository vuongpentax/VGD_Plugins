# encoding: UTF-8
module VGD
  module Dim
    module Engine
      extend self
      ENDPOINTS = %w[keep none slash dot closed open].freeze unless const_defined?(:ENDPOINTS, false)
      def validate(settings)
        raise ArgumentError, 'Dữ liệu không hợp lệ.' unless settings.is_a?(Hash)
        config = DEFAULTS.merge(settings.select { |key, _| DEFAULTS.key?(key) })
        %w[dim_color text_color].each do |key|
          raise ArgumentError, 'Màu không hợp lệ.' unless /\A#[0-9a-fA-F]{6}\z/.match?(config[key].to_s)
        end
        %w[dim_endpoint label_endpoint].each do |key|
          raise ArgumentError, 'Endpoint không hợp lệ.' unless ENDPOINTS.include?(config[key])
        end
        {'dim_orientation'=>%w[keep aligned screen], 'dim_alignment'=>%w[keep above center outside], 'label_leader'=>%w[keep view pushpin]}.each do |key, choices|
          raise ArgumentError, "#{key}: lựa chọn không hợp lệ." unless choices.include?(config[key])
        end
        if config['dim_orientation'] == 'screen' && config['dim_alignment'] != 'keep'
          raise ArgumentError, 'Above/Center/Outside cần hướng chữ song song đường Dim.'
        end
        config
      end
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
      # Called inside an existing operation by SmartDim; never traverses groups.
      def style_targets(model, config, targets)
        dimensions = targets.select { |entity| entity.is_a?(Sketchup::Dimension) }
        texts = targets.select { |entity| entity.is_a?(Sketchup::Text) }
          unless dimensions.empty?
            tag = model.layers['000 DIM'] || model.layers.add('000 DIM')
            material = get_material(model, 'VGD_DIM_COLOR', config['dim_color'])
            dimensions.each do |entity|
              entity.material = material
              entity.layer = tag
              set_endpoint(entity, config['dim_endpoint'])
              entity.has_aligned_text = (config['dim_orientation'] == 'aligned') unless config['dim_orientation'] == 'keep'
              if entity.is_a?(Sketchup::DimensionLinear) && config['dim_alignment'] != 'keep'
                entity.has_aligned_text = true
                positions = {'above'=>Sketchup::DimensionLinear::ALIGNED_TEXT_ABOVE,
                             'center'=>Sketchup::DimensionLinear::ALIGNED_TEXT_CENTER,
                             'outside'=>Sketchup::DimensionLinear::ALIGNED_TEXT_OUTSIDE}
                entity.aligned_text_position = positions.fetch(config['dim_alignment'])
              end
            end
          end
          unless texts.empty?
            tag = model.layers['000 TEXT'] || model.layers.add('000 TEXT')
            material = get_material(model, 'VGD_TEXT_COLOR', config['text_color'])
            texts.each do |entity|
              entity.material = material
              entity.layer = tag
              if entity.has_leader?
                set_endpoint(entity, config['label_endpoint'])
                entity.leader_type = (config['label_leader'] == 'view' ? ALeaderView : ALeaderModel) unless config['label_leader'] == 'keep'
              end
            end
          end
        {dimensions: dimensions.length, texts: texts.length}
      end
      def apply(model, settings)
        config = validate(settings)
        targets = selected(model)
        raise ArgumentError, 'Hãy chọn trực tiếp Dim hoặc Text/Label trước khi APPLY.' if targets.empty?
        check_context(model)
        model.start_operation('VGD Dim — Vùng chọn', true)
        begin
          result = style_targets(model, config, targets)
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        model.active_view.invalidate
        result
      end
    end
  end
end
