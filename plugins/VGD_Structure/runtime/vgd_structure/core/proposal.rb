module VGD
  module Structure
    # Đề xuất bán tự động (đã chốt 17/11/2026): với một tầng, chọn sẵn cột ở mọi giao điểm, dầm ở mọi nhịp, tường ở các nhịp BIÊN, sàn và trần ở mọi ô.
    # Tầng trên cùng chỉ đề xuất sàn; tầng móng (có `footing`) chỉ đề xuất cột và dầm (cổ cột, giằng móng). KHÔNG phá dữ liệu: chỉ THÊM phần còn thiếu, giữ nguyên lựa chọn đã có (kể cả loại và kiểu đặt riêng).
    # Logic thuần; người dùng bỏ hoặc thêm từng cái ở các tab sau đó rồi mới dựng.
    module Proposal
      KINDS = %w[columns beams walls slabs ceilings].freeze

      # Trả về [danh sách tầng mới (chưa kiểm tra lại), số mục được thêm theo loại]. level_ids: các tầng cần đề xuất.
      def self.propose(grid, levels, level_ids)
        raise Levels::Error, 'Hãy chọn ít nhất một tầng để đề xuất.' unless level_ids.is_a?(Array) && !level_ids.empty?
        level_ids.each { |id| Levels.find(levels, id) or raise Levels::Error, 'Tầng không tồn tại.' }
        refs = {'columns' => Grid.intersections(grid).map { |i| i[:ref] }, 'beams' => Grid.spans(grid).map { |s| s[:ref] },
                'walls' => Grid.spans(grid).select { |s| s[:placement] == 'edge' }.map { |s| s[:ref] }, 'slabs' => Grid.cells(grid).map { |c| c[:ref] },
                'ceilings' => Grid.cells(grid).map { |c| c[:ref] }}
        added = Hash.new(0)
        out = Marshal.load(Marshal.dump(levels))
        last = out.last['id']
        level_ids.uniq.each do |id|
          level = Levels.find(out, id)
          # Tầng móng (có khai báo `footing`): chỉ cổ cột và giằng móng (dầm), không tường, sàn, trần.
          kinds = if id == last then %w[slabs] elsif level['footing'] then %w[columns beams] else KINDS end
          kinds.each do |kind|
            picks = (level['picks'][kind] ||= {})
            refs[kind].each do |ref|
              next if picks.key?(ref)
              picks[ref] = {}
              added[kind] += 1
            end
          end
        end
        [out, KINDS.each_with_object({}) { |k, h| h[k] = added[k] }]
      end
    end
  end
end
