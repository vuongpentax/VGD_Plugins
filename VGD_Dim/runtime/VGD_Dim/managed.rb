# encoding: UTF-8
module VGD
  module Dim
    # Identity is metadata, never a display name. Foreign groups/tags are untouched.
    module Managed
      DICT = 'VGD_Dim_Smart'.freeze unless const_defined?(:DICT, false)
      def self.owned?(entity)
        entity.respond_to?(:get_attribute) && entity.get_attribute(DICT, 'owner') == 'VGD Dim'
      end
      def self.page(model, enabled)
        page = enabled ? model.pages.selected_page : nil
        if page && !page.use_hidden_layers?
          raise 'Scene hiện tại chưa lưu Tags. Bật Tags trong Scene, hoặc bỏ “Gắn bộ Dim vào Scene hiện tại”.'
        end
        page
      end
      def self.key(sources, page, face, section)
        JSON.generate([sources.map(&:persistent_id).sort, page && page.persistent_id, face, section && section[:id]])
      end
      def self.matches(entities, key)
        entities.grep(Sketchup::Group).select { |g| g.valid? && owned?(g) && g.get_attribute(DICT, 'key') == key }
      end
      def self.tag(model, name, page)
        base = name; index = 2
        list = model.layers.respond_to?(:values) ? model.layers.values : model.layers.to_a
        layer = list.find { |t| owned?(t) && t.get_attribute(DICT, 'slot') == base }
        unless layer
          while (layer = model.layers[name]) && !owned?(layer)
            name = "#{base}_VGD#{index}"; index += 1
          end
        end
        created = layer.nil?
        layer ||= model.layers.add(name)
        layer.set_attribute(DICT, 'owner', 'VGD Dim')
        layer.set_attribute(DICT, 'scene', page ? page.persistent_id : 0)
        layer.set_attribute(DICT, 'slot', base)
        layer.visible = true
        # New scenes hide scene-bound annotation tags by default.
        layer.page_behavior = 0x0020 if created && page && layer.respond_to?(:page_behavior=)
        layer
      end
      def self.visibility_snapshot(model, tag)
        model.pages.select(&:use_hidden_layers?).map do |p|
          default = (tag.page_behavior & 0x0001) == 0
          [p, p.layers.include?(tag) ? !default : default]
        end
      end
      def self.bind_scene(model, tag, page)
        return 0 unless page
        count = 0
        model.pages.each do |p|
          next unless p.use_hidden_layers?
          p.set_visibility(tag, p == page)
          count += 1
        end
        count
      end
      def self.restore_visibility(snapshot, tag)
        errors = []
        snapshot.each do |p, visible|
          begin
            p.set_visibility(tag, visible) if p.valid? && tag.valid?
          rescue StandardError => e
            errors << "#{p.name}: #{e.message}"
          end
        end
        errors
      end
    end
  end
end
