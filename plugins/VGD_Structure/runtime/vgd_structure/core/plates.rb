module VGD
  module Structure
    # Phần dùng chung của sàn và trần ĐA GIÁC tự do (P4b-3): mục kế hoạch từ dữ liệu `free`, kiểm tra chồng nhau. Logic thuần.
    module Plates
      MAX_COMPARE = 400 # số mục tối đa để so chồng từng cặp (vượt thì bỏ qua so cặp, không lỗi)

      # free: {'poly' => vòng ngoài, 'holes' => [vòng lỗ]} đã chuẩn hóa. Trả về mục kế hoạch có polygon, holes, min, max, area (m2, đã trừ lỗ), placement 'free'.
      def self.free_item(ref, free, extra)
        poly = free['poly']
        holes = free['holes'] || []
        min, max = Geometry.bounds(poly)
        area = (Geometry.area(poly) - holes.sum { |h| Geometry.area(h) }) / 1_000_000.0
        {ref: ref, polygon: poly, holes: holes, min: min, max: max, area: area.round(3), placement: 'free'}.merge(extra)
      end

      def self.ring_of(item)
        item[:polygon] || [[item[:min][0], item[:min][1]], [item[:max][0], item[:min][1]], [item[:max][0], item[:max][1]], [item[:min][0], item[:max][1]]]
      end

      # Cảnh báo cặp chồng nhau mà ít nhất một bên là đa giác tự do.
      def self.overlap_issues(items, label)
        return [] if items.size > MAX_COMPARE
        issues = []
        items.each_with_index do |a, i|
          items[(i + 1)..].each do |b|
            next unless a[:placement] == 'free' || b[:placement] == 'free'
            next unless a[:min][0] < b[:max][0] && b[:min][0] < a[:max][0] && a[:min][1] < b[:max][1] && b[:min][1] < a[:max][1]
            issues << "#{label} #{a[:ref]} và #{b[:ref]} chồng lên nhau." if Geometry.regions_overlap?(ring_of(a), a[:holes] || [], ring_of(b), b[:holes] || [])
          end
        end
        issues
      end
    end
  end
end
