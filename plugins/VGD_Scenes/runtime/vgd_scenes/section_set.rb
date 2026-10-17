# frozen_string_literal: true

module VGD
  module Scenes
    # Chooses a standard drawing scale so a parallel view fits the paper.
    module ScalePlan
      PAPERS = { 'A4_L' => [297.0, 210.0], 'A4_P' => [210.0, 297.0],
                 'A3_L' => [420.0, 297.0], 'A3_P' => [297.0, 420.0] }.freeze
      STANDARD = [1, 2, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200].freeze
      MM_PER_INCH = 25.4
      # Pixels per millimetre of drawing area when a paper frame is stored.
      FRAME_PIXELS_PER_MM = 4

      # Printable area in mm after the paper margin on every side.
      def self.drawing_area(options)
        paper = PAPERS.fetch(options['paper'])
        area = paper.map { |side| side - 2 * options['paper_margin'] }
        raise ArgumentError, 'Lề giấy quá lớn so với khổ giấy.' if area.any? { |side| side < 50 }
        area
      end

      # Frame size in pixels for the printable area of the chosen paper.
      def self.frame_pixels(options)
        drawing_area(options).map { |side| (side * FRAME_PIXELS_PER_MM).round }
      end

      # width/height are the object's extents in the view plane, in inches.
      # Returns nil when scale does not apply (free mode, or an ISO view).
      def self.for(width, height, kind, options)
        return nil if options['scale_mode'] == 'free' || kind == 'ISO'
        area_w, area_h = drawing_area(options)
        need_w = width * MM_PER_INCH
        need_h = height * MM_PER_INCH
        if options['scale_mode'] == 'fixed'
          denominator = options['scale_denominator'].to_f
          fits = need_w / denominator <= area_w + 1e-6 && need_h / denominator <= area_h + 1e-6
        else
          denominator = STANDARD.find { |step| need_w / step <= area_w && need_h / step <= area_h }
          fits = !denominator.nil?
          # Larger than the biggest standard scale: use the needed ratio rounded up to a multiple of 50
          # and report that no standard scale fits, so the user can pick a bigger paper.
          denominator ||= ([need_w / area_w, need_h / area_h].max / 50.0).ceil * 50
        end
        { 'denominator' => denominator, 'fits' => fits, 'paper' => options['paper'],
          'camera_height' => area_h * denominator / MM_PER_INCH, 'aspect' => area_w / area_h }
      end
    end

    # A named set of views and virtual sections applied in one step.
    module SectionSet
      AXES = %w[X Y Z].freeze
      MAX_SECTIONS = 12
      OPTION_KEYS = %w[paper paper_margin scale_mode scale_denominator margin project template axis_mode isolate].freeze
      SHEET_KEY = 'sheet'

      # Cabinet axes: X = width, Y = depth, Z = height.
      PRESETS = {
        'wardrobe' => {
          'label' => 'Tủ quần áo',
          'views' => %w[FRONT RIGHT TOP ISO],
          'sections' => [
            { 'name' => 'A-A', 'axis' => 'Y', 'percent' => 50.0, 'flip' => false },
            { 'name' => 'B-B', 'axis' => 'X', 'percent' => 50.0, 'flip' => false },
            { 'name' => 'C-C', 'axis' => 'Z', 'percent' => 50.0, 'flip' => false }
          ]
        }
      }.freeze

      def self.presets
        PRESETS
      end

      def self.normalize(raw)
        raise ArgumentError, 'Bộ mặt cắt không hợp lệ.' unless raw.is_a?(Hash)
        views = Array(raw['views']).map(&:to_s).uniq
        raise ArgumentError, 'Góc nhìn không hợp lệ.' unless (views - VIEWS).empty?
        sections = Array(raw['sections']).map { |item| normalize_section(item) }
        raise ArgumentError, "Tối đa #{MAX_SECTIONS} mặt cắt mỗi bộ." if sections.length > MAX_SECTIONS
        names = sections.map { |item| item['name'].downcase }
        raise ArgumentError, 'Tên mặt cắt không được trùng nhau.' if names.uniq.length != names.length
        raise ArgumentError, 'Chọn ít nhất một góc nhìn hoặc một mặt cắt.' if views.empty? && sections.empty?
        { 'id' => raw['preset'].to_s, 'views' => views, 'sections' => sections, 'options' => build_options(raw['options']),
          'dimension' => raw['dimension'] == true }
      end

      def self.normalize_section(item)
        raise ArgumentError, 'Mặt cắt không hợp lệ.' unless item.is_a?(Hash)
        name = item['name'].to_s.strip
        raise ArgumentError, 'Tên mặt cắt không được trống (tối đa 40 ký tự).' if name.empty? || name.length > 40
        raise ArgumentError, 'Trục mặt cắt phải là X, Y hoặc Z.' unless AXES.include?(item['axis'].to_s)
        raise ArgumentError, 'Lật mặt cắt phải là bật/tắt.' unless [true, false, nil].include?(item['flip'])
        { 'name' => name, 'axis' => item['axis'].to_s, 'percent' => Scenes.number(item['percent'], 0, 100, 'Vị trí cắt (%)'),
          'flip' => item['flip'] == true }
      end

      # Frame size always follows the paper, so the stored frame and the scale agree.
      def self.build_options(raw)
        given = raw.is_a?(Hash) ? raw.select { |key, _| OPTION_KEYS.include?(key) } : {}
        base = Scenes.options(DEFAULTS.merge('scale_mode' => 'auto', 'views' => []).merge(given).merge('grouping' => 'combined'))
        width, height = ScalePlan.frame_pixels(base)
        Scenes.options(base.merge('width' => width, 'height' => height))
      end

      def self.apply(model, raw)
        set = normalize(raw)
        base = set['options']
        entries = []
        Scenes.operation(model, 'Tạo bộ mặt cắt') do
          unless set['views'].empty?
            result = SceneStore.generate(model, base.merge('views' => set['views']))
            set['views'].zip(result[:ids]).each { |kind, id| entries << { 'id' => id, 'role' => 'VIEW', 'name' => kind } }
          end
          set['sections'].each do |section|
            result = SceneStore.generate(model, base.merge('section_axis' => section['axis'], 'section_percent' => section['percent'],
                                                           'section_flip' => section['flip'], 'section_name' => section['name'],
                                                           'section_offset' => 0.0), true)
            entries << { 'id' => result[:ids].first, 'role' => 'SECTION', 'name' => section['name'] }
          end
          entries.each_with_index { |entry, index| tag_sheet(model, set, entry, index + 1) }
        end
        # Dimensions are added after the scenes exist, each with its own Undo step in Dim.
        dimensions = set['dimension'] ? DimBridge.apply(model, entries) : nil
        model.pages.selected_page = SceneStore.find(model, entries.first['id']) unless model.active_path
        report(model, entries, dimensions)
      end

      # Data other VGD plugins read: which set, role, order, and the scale used.
      def self.tag_sheet(model, set, entry, order)
        page = SceneStore.find(model, entry['id'])
        page.set_attribute(DICT, SHEET_KEY, { 'set' => set['id'], 'role' => entry['role'], 'name' => entry['name'], 'order' => order }.to_json)
      end

      def self.sheet(page)
        JSON.parse(page.get_attribute(DICT, SHEET_KEY, '{}')) rescue {}
      end

      def self.report(model, entries, dimensions = nil)
        warnings = []
        scenes = entries.map do |entry|
          page = SceneStore.find(model, entry['id'])
          scale = (JSON.parse(page.get_attribute(DICT, 'scale', '{}')) rescue {})
          label = scale['denominator'] ? "1:#{scale['denominator'].to_i}" : nil
          warnings << "#{page.name}: không vừa khổ giấy ở tỷ lệ chuẩn nào (đã dùng #{label}). Hãy chọn khổ giấy lớn hơn." if scale['denominator'] && scale['fits'] == false
          { id: entry['id'], name: page.name, role: entry['role'], scale: label }
        end
        views = entries.count { |entry| entry['role'] == 'VIEW' }
        summary = "Đã tạo/cập nhật #{entries.length} scene (#{views} góc nhìn, #{entries.length - views} mặt cắt)."
        if dimensions
          summary += " Đã ghi kích thước cho #{dimensions['measured']} scene."
          warnings.concat(dimensions['warnings'])
        end
        { success: true, ids: entries.map { |entry| entry['id'] }, scenes: scenes, warnings: warnings, dimensions: dimensions,
          message: warnings.empty? ? summary : ([summary] + warnings).join("\n") }
      end
    end
  end
end
