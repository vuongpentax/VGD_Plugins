# frozen_string_literal: true

require 'fileutils'

module VGD
  module Scenes
    # Builds a LayOut document from a SheetLayout plan: one LayOut page per sheet, an optional title-block
    # image behind the viewports, one viewport per scene at the planned scale and position.
    module SheetBuilder
      PAPER_MM = { 'A4_L' => [297.0, 210.0], 'A4_P' => [210.0, 297.0], 'A3_L' => [420.0, 297.0], 'A3_P' => [297.0, 420.0],
                   'A2_L' => [594.0, 420.0], 'A2_P' => [420.0, 594.0], 'A1_L' => [841.0, 594.0], 'A1_P' => [594.0, 841.0] }.freeze
      LABEL_HEIGHT_MM = 6.0

      def self.available?
        defined?(::Layout::Document) && ::Layout::Document.instance_methods.include?(:export)
      end

      def self.inches(mm)
        mm.to_f / 25.4
      end

      def self.safe_name(text)
        text.to_s.gsub(/[\\\/:*?"<>|]/, '_').strip[0, 80]
      end

      CLEAN_KEYS = { 'DrawGround' => false, 'DrawHorizon' => false, 'DisplaySky' => false }.freeze

      # Sky, ground and horizon would print as coloured bands behind every view. They are switched off
      # only while the copy for LayOut is saved; rendering options are not undoable, so each value is restored by hand.
      def self.save_clean_copy(model, path)
        saved = []
        begin
          ([model] + model.pages.to_a).each do |holder|
            options = holder.rendering_options
            keys = []
            options.each_key { |key| keys << key }
            changes = CLEAN_KEYS.select { |key, _| keys.include?(key) }
            changes = changes.merge('BackgroundColor' => ::Sketchup::Color.new(255, 255, 255)) if keys.include?('BackgroundColor')
            saved << [options, changes.keys.map { |key| [key, options[key]] }]
            changes.each { |key, value| options[key] = value }
          end
          model.save_copy(path)
        ensure
          saved.each { |options, values| values.each { |key, value| options[key] = value } }
        end
      end

      # plan: result of SheetLayout.plan. folder: where the .skp copy, .layout and .pdf are written.
      # options: 'name' (file base name), 'title_block' (TitleBlock.import result or nil), 'pdf' (export a PDF), 'render' ('vector' default, or 'hybrid').
      # Returns { 'layout', 'pdf', 'skp', 'sheets', 'warnings' }.
      def self.build(model, plan, folder, options = {})
        raise 'SketchUp này không có LayOut API.' unless available?
        raise ArgumentError, 'Không có trang nào để dựng.' if Array(plan['sheets']).empty?
        paper = PAPER_MM[plan['paper']] or raise ArgumentError, 'Khổ giấy không hợp lệ.'
        FileUtils.mkdir_p(folder)
        base = safe_name(options['name']).empty? ? 'VGD_Sheets' : safe_name(options['name'])
        skp = File.join(folder, "#{base}.skp")
        raise 'Không lưu được bản sao model cho LayOut.' unless save_clean_copy(model, skp)
        scene_names = ['Last saved SketchUp View'] + model.pages.map(&:name)
        warnings = []
        title = options['title_block']
        if title && title['paper'] && title['paper'] != plan['paper']
          warnings << "Khung tên là khổ #{title['paper']} nhưng bộ đang dàn ở #{plan['paper']}; ảnh khung tên bị co giãn theo trang."
        end

        doc = ::Layout::Document.new
        info = doc.page_info
        info.width = inches(paper[0])
        info.height = inches(paper[1])
        info.top_margin = info.bottom_margin = info.left_margin = info.right_margin = 0
        layer = doc.layers.first
        render = options['render'] == 'hybrid' ? ::Layout::SketchUpModel::HYBRID_RENDER : ::Layout::SketchUpModel::VECTOR_RENDER

        plan['sheets'].each_with_index do |entries, index|
          page = index.zero? ? doc.pages.first : doc.pages.add("Sheet #{index + 1}")
          page.name = "Sheet #{index + 1}" if page.respond_to?(:name=)
          if title
            image = ::Layout::Image.new(title['png'], ::Geom::Bounds2d.new(0, 0, inches(paper[0]), inches(paper[1])))
            doc.add_entity(image, layer, page)
          end
          entries.each { |entry| add_viewport(doc, layer, page, skp, scene_names, entry, paper, render, warnings) }
        end

        layout_path = File.join(folder, "#{base}.layout")
        doc.save(layout_path)
        result = { 'layout' => layout_path, 'skp' => skp, 'sheets' => plan['sheets'].length, 'warnings' => warnings }
        if options['pdf']
          pdf_path = File.join(folder, "#{base}.pdf")
          doc.export(pdf_path)
          raise 'LayOut không xuất được PDF.' unless File.file?(pdf_path) && File.size(pdf_path) > 0
          result['pdf'] = pdf_path
        end
        result
      end

      def self.add_viewport(doc, layer, page, skp, scene_names, entry, paper, render, warnings)
        index = scene_names.index(entry['name'])
        unless index
          warnings << "#{entry['name']}: không thấy scene trong model nên bỏ qua."
          return
        end
        bounds = ::Geom::Bounds2d.new(inches(entry['x']), inches(entry['y']), inches(entry['w']), inches(entry['h']))
        viewport = ::Layout::SketchUpModel.new(skp, bounds)
        doc.add_entity(viewport, layer, page)
        viewport.current_scene = index
        viewport.perspective = false
        viewport.scale = 1.0 / entry['scale'].to_f
        viewport.render_mode = render
        viewport.render if viewport.render_needed?
        caption = "#{entry['label']}  1:#{SheetLayout.format_scale(entry['scale'])}"
        top = [inches(entry['y'] + entry['h'] + 1.0), inches(paper[1] - LABEL_HEIGHT_MM)].min
        text = ::Layout::FormattedText.new(caption, ::Geom::Point2d.new(inches(entry['x']), top), ::Layout::FormattedText::ANCHOR_TYPE_TOP_LEFT)
        doc.add_entity(text, layer, page)
      end
    end
  end
end
