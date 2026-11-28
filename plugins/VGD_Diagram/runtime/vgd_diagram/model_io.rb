# encoding: UTF-8
# Đọc và ghi model SketchUp. Chỉ đọc cấu trúc Group/Component; chỉ ghi thuộc tính thứ tự lắp.
module VGD
  module Diagram
    module ModelIO
      extend self

      DICT = 'VGD_Diagram'.freeze
      KEY_ORDER = 'order'.freeze

      def read_tree(model)
        read_entities(model.entities)
      end

      # Cây của một danh sách thực thể (phạm vi đã chọn trong model).
      def read_entities(entities)
        Tree.build(raw_level(entities))
      end

      # Vị trí [z thấp nhất, x, y] của từng nhóm (hợp các bản của nhóm), để đề xuất thứ tự từ dưới lên.
      def node_positions(model, nodes, positions = {})
        nodes.each do |node|
          box = Geom::BoundingBox.new
          node['ids'].each do |id|
            entity = model.find_entity_by_id(id)
            box.add(entity.bounds) if entity
          end
          positions[node['key']] = [box.min.z, box.min.x, box.min.y] unless box.empty?
          node_positions(model, node['children'], positions)
        end
        positions
      end

      def raw_level(entities)
        entities.select { |entity| instance?(entity) && visible?(entity) }.map { |entity| raw_node(entity) }
      end

      # Đối tượng đang thấy trong SketchUp: không bị ẩn (Edit > Hide), tag đang bật, và các thư mục chứa tag đều đang bật.
      # Sơ đồ chỉ gồm những gì đang thấy; muốn đưa đối tượng ẩn vào thì hiện lại rồi bấm Làm mới.
      def visible?(entity)
        return false if entity.hidden?
        layer = entity.layer
        return true unless layer
        return false unless layer.visible?
        folder = layer.folder
        while folder
          return false unless folder.visible?
          folder = folder.folder
        end
        true
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
      # Bản bị khóa không bị ghi. Trả về {saved: số bản đã ghi, skipped: số bản khóa bị bỏ qua}.
      def apply_orders(model, tree, changes)
        saved = 0
        skipped = 0
        model.start_operation('VGD Diagram: thứ tự lắp', true)
        changes.each do |key, order|
          Tree.find(tree, key)['ids'].each do |id|
            entity = model.find_entity_by_id(id)
            next unless entity # cấu kiện đã bị xóa sau khi đọc cây
            if entity.locked?
              skipped += 1
              next
            end
            if order
              entity.set_attribute(DICT, KEY_ORDER, order)
            else
              entity.delete_attribute(DICT, KEY_ORDER)
            end
            saved += 1
          end
        end
        model.commit_operation
        { saved: saved, skipped: skipped }
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
