module VGD
  module Structure
    # Tag của lưới trục theo bộ tag mẫu của VGD BIM (Schema::GRID_TAG) và kiểu nét gạch dài - chấm.
    module GridTag
      # Tên kiểu nét ưu tiên để chọn nét gạch dài - chấm trong model.line_styles (tên kiểu nét của SketchUp thay đổi theo bản và ngôn ngữ).
      def self.pick_style(names)
        norm = names.map { |n| [n, n.to_s.downcase.gsub(/[^a-z0-9]+/, ' ')] }
        both = norm.select { |_, n| n.include?('dash') && n.include?('dot') }
        (both.find { |_, n| n.include?('long') } || both.first || [])[0]
      end

      # Trả về [layer, ghi chú về kiểu nét]. Tag đã có thì giữ màu và thư mục; chỉ đặt nét gạch chấm khi tag đang là nét liền.
      def self.ensure(model)
        layer = TagStore.ensure(model, Schema::GRID_TAG)
        [layer, apply_style(model, layer)]
      end

      def self.apply_style(model, layer)
        return 'Bản SketchUp này không có kiểu nét theo tag (cần SketchUp 2021 trở lên): nét trục giữ như hiện tại.' unless layer.respond_to?(:line_style=) && model.respond_to?(:line_styles)
        current = layer.line_style
        current_name = current ? current.name.to_s.downcase : ''
        return 'Giữ kiểu nét bạn đã đặt cho tag !grid.' unless current.nil? || current_name.empty? || current_name.include?('solid')
        styles = model.line_styles.to_a
        picked = pick_style(styles.map(&:name))
        return 'Không tìm thấy kiểu nét gạch dài - chấm trong model: tag !grid để nét liền. Hãy chọn kiểu nét cho tag !grid trong khay Tags.' unless picked
        layer.line_style = styles.find { |style| style.name == picked }
        "Đã đặt nét #{picked} cho tag !grid."
      end

    end
  end
end
