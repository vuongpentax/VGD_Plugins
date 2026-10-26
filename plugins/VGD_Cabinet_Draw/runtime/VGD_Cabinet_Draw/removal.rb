module VGD_Cabinet_Draw
  # Xóa tấm (đợt/vách), cánh và ngăn kéo / khoang / xà chặn / hộc tủ áo.
  # Mỗi lần xóa được GHI vào bước tạo của tủ, nên các lần dựng lại sau (Sửa tủ, Scale) không làm chúng hiện lại:
  #   - Đợt/vách: bước đợt có danh sách 'omit' (chỉ số tấm đã bỏ). Bước không còn tấm nào thì bị gỡ hẳn.
  #   - Cánh: vùng của cánh được đánh dấu 'empty' trong bố cục (không gộp vào cánh bên cạnh).
  #   - Ngăn kéo, khoang, xà chặn, hộc tủ áo: gỡ bước tạo của chúng.
  # Các hàm ở đây không mở operation; người gọi mở và đóng (commit/abort).
  module Removal
    extend self

    DICT = Schema::DICTIONARY
    DRAWER_KINDS = %w[drawer_front drawer_box].freeze

    # Các tấm còn lại của một bước đợt/vách, theo thứ tự vị trí tăng dần: mảng chỉ số nguồn.
    # Tấm thứ k (chỉ số 'index' của tấm) ứng với phần tử k của mảng này.
    def panel_sources(op)
      omit = Array(op['omit']).map(&:to_i)
      if op['mode'] == 'divide'
        # Chia đều thành 'count' ô thì có count - 1 tấm (xem Rebuild.divide_positions).
        (0...[op['count'].to_i - 1, 0].max).reject { |i| omit.include?(i) }
      else
        offsets = op['offsets'] || []
        (0...offsets.length).reject { |i| omit.include?(i) }.sort_by { |i| offsets[i].to_f }
      end
    end

    # Đổi các bước đợt/vách còn lại sang vị trí tuyệt đối (mm từ đáy hoặc mép trái lòng tủ). Vị trí đang có không đổi,
    # nhưng xóa một tấm thì các tấm khác không bị dời theo ô mới (đợt đặt theo ô sẽ dời khi ô đổi).
    def freeze_panel_steps(root)
      shell = Geometry.shell_for(root)
      list = Rebuild.ops(root)
      inner = Interior.inner(shell)
      members = Interior.containers(shell).select { |e| Rebuild::MEMBER_ROLES.include?(Interior.role_of(e)) }
      list.each do |op|
        next unless op['type'] == 'panel'
        mine = members.select { |m| ModelData.params(m)['op'] == op['op'] }
        next if mine.empty?
        vertical = op['axis'] == 'vertical'
        low = vertical ? inner.x0 : inner.z0
        positions = mine.map { |m| box = Interior.box_of(m); vertical ? box[0] : box[2] }.sort
        op['mode'] = 'free'
        op['offsets'] = positions.map { |p| (p - low).to_mm }
        op['limit'] = false
        op.delete('count')
        op.delete('omit')
      end
      Rebuild.save_ops(root, list)
    end

    # Xóa một hoặc nhiều đợt/vách. Tấm thuộc cùng một bước được xử lý cùng lúc, rồi dựng lại một lần.
    def remove_members(root, members)
      freeze_panel_steps(root)
      list = Rebuild.ops(root)
      op_ids = members.map { |m| ModelData.params(m)['op'] }.uniq
      op_ids.each do |op_id|
        op = list.find { |item| item['op'] == op_id }
        raise 'Tấm này thuộc bước tạo cũ, không xóa riêng được. Hãy dùng Sửa tủ.' unless op && op['type'] == 'panel'
        sources = panel_sources(op)
        removed = members.select { |m| ModelData.params(m)['op'] == op_id }
                         .map { |m| sources.fetch(ModelData.params(m)['index'].to_i) { raise 'Không xác định được tấm cần xóa.' } }
        if removed.length >= sources.length
          list.delete(op)
        else
          op['omit'] = (Array(op['omit']).map(&:to_i) + removed).uniq.sort
        end
      end
      Rebuild.save_ops(root, list)
      erase_members(root, op_ids)
      rebuild(root)
    end

    def erase_members(root, op_ids)
      Interior.containers(Geometry.shell_for(root)).each do |entity|
        next unless Rebuild::MEMBER_ROLES.include?(Interior.role_of(entity))
        entity.erase! if op_ids.include?(ModelData.params(entity)['op'])
      end
    end

    # Xóa cánh: đánh dấu vùng của cánh là trống (không gộp vào cánh khác), rồi dựng lại cánh từ bố cục.
    def remove_doors(root, doors)
      ids = doors.map { |door| door.get_attribute(DICT, 'region_id').to_s }
      data = JSON.parse(root.get_attribute(DICT, 'door_layout_json', '{}'))
      regions = data.is_a?(Hash) ? Array(data['regions']) : []
      raise 'Không tìm thấy bố cục cánh của tủ này.' if regions.empty?
      regions.each { |region| region['empty'] = true if ids.include?(region['id'].to_s) }
      root.set_attribute(DICT, 'door_layout_json', JSON.generate(data))
      rebuild(root)
    end

    # Xóa ngăn kéo (mặt + thùng), khoang, xà chặn hoặc hộc tủ áo theo số bước tạo của chúng.
    def remove_steps(root, op_ids)
      list = Rebuild.ops(root).reject { |item| op_ids.include?(item['op']) }
      container = root.definition.entities.to_a.find { |e| e.is_a?(Sketchup::Group) && e.valid? && e.name == Operations::DRAWER_CONTAINER }
      container.definition.entities.to_a.each do |child|
        child.erase! if child.valid? && DRAWER_KINDS.include?(child.get_attribute(DICT, 'kind')) && op_ids.include?(child.get_attribute(DICT, 'op'))
      end
      Interior.containers(Geometry.shell_for(root)).each do |entity|
        kind = entity.get_attribute(DICT, 'kind')
        entity.erase! if Rebuild::EXTRA_KINDS.include?(kind) && op_ids.include?(ModelData.params(entity)['op'])
      end
      Rebuild.save_ops(root, list)
      rebuild(root)
    end

    # Mã bước tạo của một ngăn kéo / khoang / xà chặn / hộc tủ áo (nil nếu không có).
    def step_of(entity)
      kind = entity.get_attribute(DICT, 'kind')
      return entity.get_attribute(DICT, 'op') if DRAWER_KINDS.include?(kind)
      return ModelData.params(entity)['op'] if Rebuild::EXTRA_KINDS.include?(kind)
      nil
    end

    # Tủ chứa một cấu kiện (quét từ gốc model, kể cả khi tủ nằm trong group khác).
    def cabinet_of(entity, entities = Sketchup.active_model.entities, depth = 0)
      return nil if depth > 8
      entities.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        return e if ModelData.cabinet?(e) && contains?(e, entity)
        found = cabinet_of(entity, e.definition.entities, depth + 1)
        return found if found
      end
      nil
    end

    def contains?(root, entity, depth = 0)
      return false if depth > 6
      root.definition.entities.to_a.any? do |e|
        e == entity || ((e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && contains?(e, entity, depth + 1))
      end
    end

    # Dựng lại tủ, giữ các tấm đang chỉnh tay (chúng không bị mất khi xóa tấm khác).
    def rebuild(root)
      keep = Rebuild.hand_edited(root).map { |item| item[:entity] }
      Rebuild.run(root, Rebuild.settings_of(root), Rebuild.dimensions_of(root), keep)
    end
  end
end
