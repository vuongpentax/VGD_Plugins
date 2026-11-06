# In cấu trúc của tấm (group/component) đang chọn để tái hiện lỗi scale với chi tiết do tool khác tạo (ví dụ mộng xương chó).
# Chỉ đọc, không sửa model.
#
# Cách dùng: chọn MỘT tấm (một group), mở Ruby Console và gõ:
#   load 'đường/dẫn/tới/dump_part_structure.rb'
# Chạy một lần TRƯỚC khi scale và một lần SAU khi scale (nếu có thể), rồi gửi toàn bộ kết quả.
module VGD_Dump_Part
  DICT = 'VGD_Cabinet_Draw'.freeze
  MAX_VERTICES = 120

  module_function

  # Chọn cả tủ hoặc một tấm: tìm mọi tấm VGD bên trong (kind = part); không có thì in chính vật đang chọn.
  def run
    selected = Sketchup.active_model.selection.to_a.select { |e| container?(e) }
    if selected.empty?
      puts 'Hãy chọn một tấm hoặc cả tủ rồi chạy lại.'
      return
    end
    parts = selected.flat_map { |e| parts_in(e) }
    parts = selected if parts.empty?
    puts "== #{parts.length} tấm =="
    parts.each { |part| puts dump(part) }
    nil
  end

  def parts_in(entity, out = [])
    if entity.get_attribute(DICT, 'kind') == 'part'
      out << entity
    else
      contents_of(entity).each { |child| parts_in(child, out) if container?(child) }
    end
    out
  end

  def container?(entity)
    entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
  end

  def contents_of(entity)
    entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
  end

  def mm(value)
    (value.to_f * 25.4).round(2)
  end

  def matrix(transformation)
    transformation.to_a.each_slice(4).map.with_index { |row, i| i == 3 ? row.first(3).map { |x| mm(x) } + [row[3]] : row.map { |x| x.round(4) } }
  end

  def box(points)
    (0..2).map { |i| values = points.map { |p| p[i] }; [values.min, values.max] }
  end

  def dump(part)
    entities = contents_of(part)
    edges = entities.grep(Sketchup::Edge)
    faces = entities.grep(Sketchup::Face)
    nested = entities.select { |e| container?(e) }
    lines = []
    lines << "== #{part.name.inspect} | #{part.class.name.split('::').last} | kind=#{part.get_attribute(DICT, 'kind').inspect} | geo_local=#{!part.get_attribute(DICT, 'geo_local').nil?} | geo_sig=#{!part.get_attribute(DICT, 'geo_sig').nil?}"
    lines << "   placement (mm cho tịnh tiến) = #{matrix(part.transformation).inspect}"
    lines << "   cạnh=#{edges.length} mặt=#{faces.length} nhóm con=#{nested.length} thể tích=#{part.respond_to?(:volume) ? part.volume : '?'} solid=#{part.respond_to?(:manifold?) ? part.manifold? : '?'}"
    comps = components(edges)
    # Tấm đơn giản (hộp chữ nhật, không nhóm con) chỉ cần dòng tóm tắt; tấm phức tạp in chi tiết đỉnh.
    complex = edges.length > 12 || nested.any? || comps.length > 1
    lines << '   (tấm đơn giản: không in chi tiết)' unless complex
    comps.each_with_index do |vertices, i|
      points = vertices.map { |v| v.position.to_a.map { |x| mm(x) } }
      lines << "   khối #{i}: #{vertices.length} đỉnh, hộp(mm)=#{box(points).inspect}"
      lines << "      đỉnh(mm)=#{points.sort.first(MAX_VERTICES).inspect}" if complex && vertices.length <= MAX_VERTICES * 2
    end
    nested.each do |child|
      bounds = child.bounds
      inner = contents_of(child)
      dicts = (child.attribute_dictionaries || []).map(&:name)
      lines << "   nhóm con #{child.name.inspect} #{child.class.name.split('::').last}: cạnh=#{inner.grep(Sketchup::Edge).length} mặt=#{inner.grep(Sketchup::Face).length} " \
               "hộp(mm)=#{box([bounds.min.to_a, bounds.max.to_a].map { |p| p.map { |x| mm(x) } }).inspect} dict=#{dicts.inspect}"
      lines << "      placement = #{matrix(child.transformation).inspect}"
    end
    lines.join("\n")
  end

  # Các khối rời (nhóm đỉnh nối nhau bằng cạnh).
  def components(edges)
    parent = {}
    vertices = {}
    find = lambda do |k|
      parent[k] = find.call(parent[k]) unless parent[k] == k
      parent[k]
    end
    edges.each do |edge|
      keys = edge.vertices.map do |v|
        vertices[v.entityID] = v
        parent[v.entityID] ||= v.entityID
      end
      parent[find.call(keys[0])] = find.call(keys[1])
    end
    vertices.keys.group_by { |k| find.call(k) }.values.map { |ks| ks.map { |k| vertices[k] } }
  end
end

VGD_Dump_Part.run
