module VGD
  module Structure
    # Danh sách lớp hoàn thiện của sàn, trần (như lớp của sàn / trần trong Revit): mỗi lớp {fn, t (mm), material, color?}. Dùng chung chức năng, màu mặc định
    # và quy tắc với lớp tường (`WallTypes`); khác tường: không bắt buộc có lớp kết cấu (kết cấu sàn là `slab_thickness`, trần là tấm trần).
    # Logic thuần, không đụng model.
    module LayerList
      MAX_LAYERS = WallTypes::MAX_LAYERS
      FUNCTIONS = %w[substrate insulation finish].freeze # không có 'structure'
      DEFAULT_COLORS = WallTypes::DEFAULT_COLORS

      # raw nil hoặc rỗng: []. label: 'sàn' / 'trần' (để báo lỗi). total: khoảng cho phép của tổng bề dày. Ném `Levels::Error` (tầng gọi bọc tên tầng).
      def self.normalize!(raw, label, total)
        return [] if raw.nil? || raw == []
        raise Levels::Error, "Lớp hoàn thiện #{label}: cần từ 1 đến #{MAX_LAYERS} lớp." unless raw.is_a?(Array) && raw.size <= MAX_LAYERS
        layers = raw.each_with_index.map do |l, i|
          at = "Lớp hoàn thiện #{label}, lớp #{i + 1}"
          raise Levels::Error, "#{at}: dữ liệu không hợp lệ." unless l.is_a?(Hash)
          raise Levels::Error, "#{at}: chức năng không hợp lệ." unless FUNCTIONS.include?(l['fn'])
          t = l['t']
          raise Levels::Error, "#{at}: bề dày phải từ #{WallTypes::LAYER_T.min.to_i} đến #{WallTypes::LAYER_T.max.to_i} mm." unless t.is_a?(Numeric) && t.to_f.finite? && WallTypes::LAYER_T.cover?(t.to_f)
          material = l['material'].nil? ? '' : l['material']
          raise Levels::Error, "#{at}: tên vật liệu tối đa #{WallTypes::MAX_MATERIAL} ký tự, không có ký tự điều khiển." unless material.is_a?(String) && material.strip.length <= WallTypes::MAX_MATERIAL && !material.match?(WallTypes::CONTROL)
          layer = {'fn' => l['fn'], 't' => t.to_f.round(1), 'material' => material.strip}
          if l['color']
            raise Levels::Error, "#{at}: màu phải có dạng #rrggbb." unless l['color'].is_a?(String) && l['color'].downcase.match?(WallTypes::COLOR)
            layer['color'] = l['color'].downcase
          end
          layer
        end
        sum = layers.sum { |l| l['t'] }.round(1)
        raise Levels::Error, "Lớp hoàn thiện #{label}: tổng bề dày #{sum} mm phải từ #{total.min.to_i} đến #{total.max.to_i} mm." unless total.cover?(sum)
        layers
      end

      def self.total(layers)
        layers.sum { |l| l['t'] }.round(1)
      end

      # Lớp để lập kế hoạch dựng (khóa ký hiệu, màu đã có mặc định).
      def self.for_plan(layers)
        layers.map { |l| {fn: l['fn'], t: l['t'], material: l['material'].to_s, color: l['color'] || DEFAULT_COLORS[l['fn']]} }
      end
    end
  end
end
