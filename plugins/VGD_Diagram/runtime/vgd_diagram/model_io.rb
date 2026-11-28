# encoding: UTF-8
# Đọc và ghi model SketchUp. Chỉ đọc cấu trúc Group/Component; chỉ ghi thuộc tính thứ tự lắp.
module VGD
  module Diagram
    module ModelIO
      extend self

      DICT = 'VGD_Diagram'.freeze
      KEY_ORDER = 'order'.freeze

      def read_tree(model)
        Tree.build(raw_level(model.entities))
      end

      def raw_level(entities)
        entities.select { |entity| instance?(entity) }.map { |entity| raw_node(entity) }
      end

      def raw_node(entity)
        {
          'id' => entity.entityID,
          'name' => label(entity),
          'order' => entity.get_attribute(DICT, KEY_ORDER),
          'children' => raw_level(children_entities(entity))
        }
      end

      def instance?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      def children_entities(entity)
        entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      end

      def label(entity)
        name = entity.name.to_s.strip
        return name unless name.empty?
        entity.is_a?(Sketchup::ComponentInstance) ? entity.definition.name.to_s : '(không tên)'
      end

      # tree: cây vừa đọc, dùng để tìm các bản của từng nhóm. changes: {key => số thứ tự hoặc nil}.
      # Gọi Tree.plan trước để kiểm tra; hàm này ghi trong một thao tác để Undo được.
      def apply_orders(model, tree, changes)
        model.start_operation('VGD Diagram: thứ tự lắp', true)
        changes.each do |key, order|
          Tree.find(tree, key)['ids'].each do |id|
            entity = model.find_entity_by_id(id)
            next unless entity # cấu kiện đã bị xóa sau khi đọc cây
            if order
              entity.set_attribute(DICT, KEY_ORDER, order)
            else
              entity.delete_attribute(DICT, KEY_ORDER)
            end
          end
        end
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end

      # Chọn các bản của một nhóm trong model. Trả về số bản chọn được.
      def select(model, ids)
        entities = ids.map { |id| model.find_entity_by_id(id) }.compact
        model.selection.clear
        model.selection.add(entities)
        entities.size
      end
    end
  end
end
