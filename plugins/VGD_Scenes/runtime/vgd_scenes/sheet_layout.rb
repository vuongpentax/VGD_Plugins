# frozen_string_literal: true

module VGD
  module Scenes
    # Arranges the scenes of a set on drawing sheets. Pure geometry: sizes in millimetres on paper,
    # positions measured from the top-left corner of the paper.
    module SheetLayout
      GAP_MM = 10.0
      # Room for dimension lines and their text around the object, in model millimetres per side.
      DIM_PAD_MODEL_MM = 450.0
      MIN_AREA_MM = 50.0

      # Reads the scenes' recorded sizes. Raises when a scene has no size (it was made by an older version).
      def self.items(model, ids)
        pages = ids.map { |id| SceneStore.find(model, id) }
        raise ArgumentError, 'Chọn ít nhất một scene để dàn trang.' if pages.empty?
        pages.map do |page|
          scale = (JSON.parse(page.get_attribute(DICT, 'scale', '{}')) rescue {})
          extent = scale['extent_mm']
          unless extent.is_a?(Array) && extent.length == 2 && extent.all? { |value| value.is_a?(Numeric) && value > 0 }
            raise ArgumentError, "#{page.name}: chưa có kích thước. Hãy tạo lại scene bằng bản VGD Scenes này."
          end
          sheet = SectionSet.sheet(page)
          { 'id' => page.persistent_id.to_s, 'name' => page.name, 'role' => sheet['role'] || 'VIEW', 'label' => sheet['name'] || page.name,
            'extent_mm' => extent }
        end
      end

      # Viewport size on paper for an item at 1:denominator.
      def self.size(item, denominator, pad)
        [(item['extent_mm'][0] + 2 * pad) / denominator, (item['extent_mm'][1] + 2 * pad) / denominator]
      end

      # Shelf packing: left to right, a new row when the width is used, a new page when the height is.
      def self.pack(entries, width, height)
        pages = [[]]
        x = 0.0
        y = 0.0
        row = 0.0
        entries.each do |entry|
          w, h = entry[:size]
          if x > 0 && x + w > width + 1e-6
            x = 0.0
            y += row + GAP_MM
            row = 0.0
          end
          if y > 0 && y + h > height + 1e-6
            pages << []
            x = 0.0
            y = 0.0
            row = 0.0
          end
          pages.last << entry.merge(x: x, y: y)
          x += w + GAP_MM
          row = [row, h].max
        end
        pages
      end

      # items: from .items (each may carry its own 'scale' denominator). options as in Scenes.options plus
      # 'reserve_bottom_mm' (kept free, e.g. for a title block) and 'pad_model_mm'.
      def self.plan(items, options)
        raise ArgumentError, 'Không có scene để dàn trang.' if items.empty?
        area_w, area_h = ScalePlan.drawing_area(options)
        reserve = options.fetch('reserve_bottom_mm', 0.0).to_f
        usable_h = area_h - reserve
        raise ArgumentError, 'Vùng khung tên quá cao so với khổ giấy.' if usable_h < MIN_AREA_MM
        pad = options.fetch('pad_model_mm', DIM_PAD_MODEL_MM).to_f
        free = items.reject { |item| item['scale'] }
        fits = lambda { |d| free.all? { |item| w, h = size(item, d, pad); w <= area_w + 1e-6 && h <= usable_h + 1e-6 } }
        if options['scale_mode'] == 'fixed'
          base = options['scale_denominator'].to_f
          raise ArgumentError, 'Tỷ lệ cố định cần mẫu số lớn hơn 0.' unless base > 0
        else
          smallest = ScalePlan::STANDARD.find { |d| fits.call(d) } || ScalePlan::STANDARD.last
          single_page = ScalePlan::STANDARD.select { |d| d >= smallest }.find do |d|
            pack(items.map { |item| { size: size(item, item['scale'] || d, pad) } }, area_w, usable_h).length == 1
          end
          base = (single_page || smallest).to_f
        end
        entries = items.map { |item| { item: item, denominator: (item['scale'] || base).to_f, size: size(item, (item['scale'] || base).to_f, pad) } }
        pages = pack(entries, area_w, usable_h)
        margin = options['paper_margin'].to_f
        warnings = []
        sheets = pages.each_with_index.map do |page, index|
          page.map do |entry|
            w, h = entry[:size]
            if w > area_w + 1e-6 || h > usable_h + 1e-6
              warnings << "#{entry[:item]['name']}: không vừa khổ giấy ở 1:#{format_scale(entry[:denominator])}. Hãy chọn khổ lớn hơn hoặc tỷ lệ nhỏ hơn."
            end
            { 'id' => entry[:item]['id'], 'name' => entry[:item]['name'], 'role' => entry[:item]['role'], 'label' => entry[:item]['label'],
              'scale' => entry[:denominator], 'x' => (margin + entry[:x]).round(2), 'y' => (margin + entry[:y]).round(2),
              'w' => w.round(2), 'h' => h.round(2), 'sheet' => index + 1, 'extent_mm' => entry[:item]['extent_mm'] }
          end
        end
        warnings << "Bộ này cần #{sheets.length} trang ở tỷ lệ 1:#{format_scale(base)}." if sheets.length > 1
        { 'paper' => options['paper'], 'denominator' => base, 'sheets' => sheets, 'warnings' => warnings,
          'area' => [margin, margin, area_w, usable_h], 'reserve_bottom_mm' => reserve, 'pad_model_mm' => pad }
      end

      MAX_SHEETS = 20
      MAX_ENTRIES = 60

      # Checks a plan that came back from the dialog (the user may have dragged boxes around) and rebuilds it
      # from trusted data: scene names come from the model, numbers must be finite and inside the paper.
      def self.sanitize(model, raw)
        raise ArgumentError, 'Bản dàn trang không hợp lệ.' unless raw.is_a?(Hash) && raw['sheets'].is_a?(Array)
        paper = SheetBuilder::PAPER_MM[raw['paper']] or raise ArgumentError, 'Khổ giấy không hợp lệ.'
        raise ArgumentError, 'Chưa có trang nào để xuất.' if raw['sheets'].empty?
        raise ArgumentError, "Tối đa #{MAX_SHEETS} trang." if raw['sheets'].length > MAX_SHEETS
        seen = {}
        sheets = raw['sheets'].each_with_index.map do |entries, index|
          raise ArgumentError, 'Bản dàn trang không hợp lệ.' unless entries.is_a?(Array)
          raise ArgumentError, "Trang #{index + 1} có quá nhiều view." if entries.length > MAX_ENTRIES
          entries.map do |entry|
            raise ArgumentError, 'Bản dàn trang không hợp lệ.' unless entry.is_a?(Hash)
            page = SceneStore.find(model, entry['id'].to_s)
            raise ArgumentError, "#{page.name}: xuất hiện hai lần trong bản dàn trang." if seen[page.persistent_id]
            seen[page.persistent_id] = true
            values = %w[scale x y w h].map { |key| Float(entry[key]) rescue raise(ArgumentError, "#{page.name}: #{key} không hợp lệ.") }
            scale, x, y, w, h = values
            raise ArgumentError, "#{page.name}: số liệu không hợp lệ." unless values.all?(&:finite?)
            raise ArgumentError, "#{page.name}: tỷ lệ cần nằm trong 1–1000." unless scale >= 1 && scale <= 1000
            raise ArgumentError, "#{page.name}: khung view phải lớn hơn 0." unless w > 0 && h > 0
            unless x >= -0.01 && y >= -0.01 && x + w <= paper[0] + 0.01 && y + h <= paper[1] + 0.01
              raise ArgumentError, "#{page.name}: nằm ngoài khổ giấy #{raw['paper']}."
            end
            sheet = SectionSet.sheet(page)
            { 'id' => page.persistent_id.to_s, 'name' => page.name, 'role' => sheet['role'] || 'VIEW', 'label' => sheet['name'] || page.name,
              'scale' => scale, 'x' => x.round(2), 'y' => y.round(2), 'w' => w.round(2), 'h' => h.round(2), 'sheet' => index + 1 }
          end
        end
        raise ArgumentError, 'Chưa có view nào trên bản dàn trang.' if sheets.all?(&:empty?)
        { 'paper' => raw['paper'], 'denominator' => raw['denominator'].to_f, 'sheets' => sheets, 'warnings' => [] }
      end

      def self.format_scale(value)
        value == value.to_i ? value.to_i.to_s : value.to_s
      end
    end
  end
end
