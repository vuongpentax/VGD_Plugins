module VGD_Cabinet_Draw
  # Hai công cụ nhỏ cho khâu chuẩn bị sản xuất (beta.18):
  #   1. Tìm tấm bị trùng: hai chi tiết chiếm gần như cùng một khối (hộp bao chồng lên nhau ≥ 90% thể tích tấm nhỏ hơn).
  #      Hậu ngậm vào rãnh của hông/nóc/đáy KHÔNG tính là trùng (chỉ chồng một phần nhỏ).
  #   2. Chuẩn hóa tên ván: chỉ theo vai trò + số thứ tự (Hông Trái, Đợt 1, Đợt 2, Vách 1…). Không đụng tới cánh và ngăn kéo
  #      (tên 'Cánh Draw…' được dùng để nhận diện cánh).
  module PanelTools
    extend self

    DUPLICATE_RATIO = 0.9
    # Vai trò có nhiều chiếc trong một tủ: đánh số theo vị trí (đợt: từ dưới lên, vách: từ trái sang, còn lại: trên xuống/trái sang).
    NUMBERED = { 'shelf' => ['Đợt', 2], 'partition' => ['Vách', 0], 'board' => ['Ván', 0], 'blocker' => ['Xà chặn', 2] }.freeze

    # ---------- Tìm tấm trùng ----------

    # Các chi tiết của một tủ cùng hệ trục thùng tủ: [entity, nhãn, hộp bao].
    def parts_of(root)
      shell = Geometry.shell_for(root)
      return [] unless shell
      list = []
      Interior.containers(shell).each do |entity|
        role = Interior.role_of(entity)
        list << [entity, entity.name.to_s, Interior.box_of(entity)] if role
      end
      root.definition.entities.to_a.each do |group|
        next unless group.respond_to?(:name) && group.valid?
        next unless ['Chân & phào', Operations::DOOR_CONTAINER, Operations::DRAWER_CONTAINER].include?(group.name)
        group.definition.entities.to_a.each do |child|
          next unless (child.is_a?(Sketchup::Group) || child.is_a?(Sketchup::ComponentInstance)) && child.valid?
          next if child.name.to_s == Operations::HANDLE_NAME
          list << [child, "#{group.name} › #{child.name}", Interior.box_of(child)]
        end
      end
      list
    end

    def volume_of(box)
      [box[3] - box[0], 0.0].max * [box[4] - box[1], 0.0].max * [box[5] - box[2], 0.0].max
    end

    def overlap_ratio(a, b)
      dx = [a[3], b[3]].min - [a[0], b[0]].max
      dy = [a[4], b[4]].min - [a[1], b[1]].max
      dz = [a[5], b[5]].min - [a[2], b[2]].max
      return 0.0 if dx <= 1e-6 || dy <= 1e-6 || dz <= 1e-6
      smaller = [volume_of(a), volume_of(b)].min
      smaller <= 0 ? 0.0 : dx * dy * dz / smaller
    end

    # Trả về mảng [{ root:, keep:, duplicate:, keep_label:, duplicate_label: }].
    def find_duplicates(roots)
      found = []
      roots.each do |root|
        next unless root.valid?
        list = parts_of(root)
        list.each_with_index do |(a, a_label, a_box), i|
          list[(i + 1)..-1].each do |b, b_label, b_box|
            next if overlap_ratio(a_box, b_box) < DUPLICATE_RATIO
            found << { root: root, keep: a, duplicate: b, keep_label: a_label, duplicate_label: b_label }
          end
        end
      end
      found
    end

    # Chọn các tấm trùng (bản thứ hai của mỗi cặp) và báo kết quả.
    def select_duplicates(roots)
      found = find_duplicates(roots)
      model = Sketchup.active_model
      model.selection.clear
      found.each { |item| model.selection.add(item[:duplicate]) }
      text = if found.empty?
               'Không có tấm nào bị trùng.'
             else
               names = found.first(12).map { |item| "• #{item[:duplicate_label]} (trùng với #{item[:keep_label]})" }
               "Có #{found.length} tấm bị trùng — đã chọn sẵn các tấm này:\n#{names.join("\n")}#{found.length > 12 ? "\n• …" : ''}"
             end
      Dialog.set_status(text.lines.first.strip)
      UI.messagebox(text)
      found
    end

    # ---------- Chuẩn hóa tên ----------

    # Trả về số chi tiết đã đổi tên.
    def normalize_names(roots)
      renamed = 0
      roots.each do |root|
        next unless root.valid?
        shell = Geometry.shell_for(root)
        next unless shell
        entries = Interior.containers(shell).map { |e| [e, Interior.role_of(e)] }.select { |_e, role| role }
        trim = root.definition.entities.to_a.find { |e| e.respond_to?(:name) && e.valid? && e.name == 'Chân & phào' }
        if trim
          entries += trim.definition.entities.to_a.select { |e| e.is_a?(Sketchup::Group) && e.valid? }.map { |e| [e, Interior.role_of(e)] }.select { |_e, role| role }
        end
        NUMBERED.each do |role, (label, axis)|
          group = entries.select { |_e, r| r == role }.map(&:first).sort_by { |e| Interior.box_of(e)[axis] }
          group.each_with_index { |entity, i| renamed += rename(entity, "#{label} #{i + 1}") }
        end
        entries.each do |entity, role|
          name = PanelModel::NAMES[role]
          renamed += rename(entity, name) if name
        end
      end
      renamed
    end

    def rename(entity, name)
      return 0 if entity.name.to_s == name
      entity.name = name
      1
    end

    def normalize_names_command(roots)
      count = 0
      model = Sketchup.active_model
      model.start_operation('VGD Cabinet Draw — Chuẩn hóa tên ván', true)
      begin
        count = normalize_names(roots)
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end
      Dialog.set_status(count.zero? ? 'Tên ván đã chuẩn, không cần đổi.' : "Đã chuẩn hóa tên #{count} ván.")
      count
    end
  end
end
