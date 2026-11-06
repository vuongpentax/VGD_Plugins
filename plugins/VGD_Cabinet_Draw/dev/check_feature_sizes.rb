# Kiểm tra chi tiết trong tấm VGD_Cabinet_Draw có giữ nguyên kích thước sau khi scale tủ. Chỉ đọc, không sửa model.
#
# Cách dùng trong Ruby Console:
#   load 'đường/dẫn/tới/check_feature_sizes.rb'
#   VGD_Check_Features.snapshot   # TRƯỚC khi scale (chọn tủ, hoặc không chọn gì để ghi cả model)
#   ... kéo Scale tủ, đợi tự cập nhật xong ...
#   VGD_Check_Features.compare    # SAU khi scale
#
# Mỗi tấm in một dòng:
#   cạnh đổi   : số cạnh đổi chiều dài (cạnh dài ở nhịp trống lớn đổi là đúng)
#   nhỏ bị đổi : số cạnh ngắn (dưới 150 mm, như mộng, lỗ, khấu, dấu tiết diện) bị đổi dài. Phải bằng 0.
#   mất / mới  : cạnh không còn / cạnh mới (dựng lại hình thay vì dời đỉnh)
module VGD_Check_Features
  DICT = 'VGD_Cabinet_Draw'.freeze
  SMALL_MM = 150.0
  TOLERANCE_MM = 0.05

  @saved = {}

  class << self
    def snapshot
      @saved = {}
      parts_in_scope.each { |part| @saved[part.entityID] = [part, part.name, edge_lengths(part)] }
      puts "Đã ghi #{@saved.length} tấm. Giờ scale tủ rồi gọi VGD_Check_Features.compare."
      nil
    end

    def compare
      if @saved.empty?
        puts 'Chưa có dữ liệu trước khi scale. Gọi VGD_Check_Features.snapshot trước.'
        return nil
      end
      bad = 0
      @saved.each_value do |part, name, before|
        unless part.valid?
          puts format('%-22s đã bị xóa hoặc dựng lại (không so được)', name)
          bad += 1
          next
        end
        info = diff(before, edge_lengths(part))
        bad += 1 if info[:small_changed].any?
        puts format('%-22s cạnh đổi=%-3d nhỏ bị đổi=%-3d mất=%-3d mới=%-3d', name, info[:changed].length, info[:small_changed].length,
                    info[:missing], info[:added])
        info[:small_changed].first(5).each { |old, new| puts format('    chi tiết nhỏ: %.2f mm -> %.2f mm', old, new) }
      end
      puts "== Xong: #{@saved.length - bad} tấm giữ nguyên chi tiết nhỏ, #{bad} tấm có vấn đề =="
      nil
    end

    private

    def parts_in_scope
      model = Sketchup.active_model
      roots = model.selection.to_a
      roots = [model] if roots.empty?
      roots.flat_map { |root| parts_in(contents_of(root)) }
    end

    def contents_of(object)
      case object
      when Sketchup::Group, Sketchup::Model then object.entities
      when Sketchup::ComponentInstance then object.definition.entities
      else []
      end
    end

    def parts_in(entities, out = [])
      entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        if entity.get_attribute(DICT, 'kind') == 'part'
          out << entity
        else
          parts_in(contents_of(entity), out)
        end
      end
      out
    end

    # { mã cạnh => chiều dài mm }
    def edge_lengths(part)
      contents_of(part).grep(Sketchup::Edge).to_h { |edge| [edge.entityID, edge.length.to_mm] }
    end

    def diff(before, after)
      common = before.keys & after.keys
      changed = common.select { |id| (before[id] - after[id]).abs > TOLERANCE_MM }
      small_changed = changed.select { |id| before[id] < SMALL_MM || after[id] < SMALL_MM }.map { |id| [before[id], after[id]] }
      { changed: changed, small_changed: small_changed, missing: (before.keys - after.keys).length, added: (after.keys - before.keys).length }
    end
  end
end
