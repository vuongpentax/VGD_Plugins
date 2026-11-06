# Kiểm tra khối (solid) của các tấm VGD_Cabinet_Draw. Chỉ đọc, không sửa model.
#
# Cách dùng: chọn một tủ (hoặc không chọn gì để kiểm tra cả model), mở Ruby Console và gõ:
#   load 'đường/dẫn/tới/check_parts_solid.rb'
#
# Mỗi tấm in một dòng:
#   solid     : SketchUp coi tấm là khối kín (true/false)
#   cạnh hở   : cạnh chỉ thuộc 1 mặt (khối bị hở)
#   cạnh 3+   : cạnh thuộc từ 3 mặt trở lên (khối bị chồng)
#   mặt lẻ    : mặt không dùng chung cạnh nào với mặt khác (mặt thừa)
#   thể tích  : tính được khi tấm là khối kín
module VGD_Check_Solid
  DICT = 'VGD_Cabinet_Draw'.freeze

  module_function

  def run
    model = Sketchup.active_model
    selected = model.selection.to_a
    roots = selected.empty? ? [model] : selected
    parts = roots.flat_map { |root| parts_in(contents_of(root)) }
    if parts.empty?
      puts 'Không có tấm VGD nào trong phạm vi kiểm tra.'
      return
    end
    puts "== Kiểm tra khối: #{parts.length} tấm =="
    results = parts.map { |part| [part, analyze(part)] }
    results.each { |part, info| puts format_line(part, info) }
    bad = results.count { |_part, info| !info[:solid] }
    puts "== Xong: #{parts.length - bad} tấm kín, #{bad} tấm không kín =="
    nil
  end

  # Các thực thể bên trong một group/component (hoặc model).
  def contents_of(object)
    case object
    when Sketchup::Group then object.entities
    when Sketchup::ComponentInstance then object.definition.entities
    when Sketchup::Model then object.entities
    else object.respond_to?(:entities) ? object.entities : []
    end
  end

  # Tìm các tấm (group có thuộc tính kind = part), kể cả lồng trong tủ và tủ quá khổ.
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

  def analyze(part)
    faces = contents_of(part).grep(Sketchup::Face)
    edges = faces.flat_map(&:edges).uniq
    counts = edges.map { |edge| edge.faces.length }
    {
      faces: faces.length,
      open_edges: counts.count { |n| n == 1 },
      overused_edges: counts.count { |n| n > 2 },
      loose_faces: faces.count { |face| face.edges.none? { |edge| edge.faces.length == 2 } },
      solid: solid?(part, counts),
      volume_mm3: volume_mm3(part)
    }
  end

  # SketchUp báo khối kín khi tấm là manifold; không có hàm này thì suy ra từ số cạnh.
  def solid?(part, counts)
    return part.manifold? if part.respond_to?(:manifold?)
    counts.all? { |n| n == 2 }
  end

  def volume_mm3(part)
    return nil unless part.respond_to?(:volume)
    v = part.volume
    v.nil? ? nil : (v.to_f * 25.4**3).round
  end

  def format_line(part, info)
    vol = info[:volume_mm3] ? format('%d', info[:volume_mm3]) : 'không tính được'
    format('%-22s solid=%-5s cạnh hở=%-3d cạnh 3+=%-3d mặt lẻ=%-3d mặt=%-3d thể tích=%s mm³',
           part.name, info[:solid], info[:open_edges], info[:overused_edges], info[:loose_faces], info[:faces], vol)
  end
end

VGD_Check_Solid.run
