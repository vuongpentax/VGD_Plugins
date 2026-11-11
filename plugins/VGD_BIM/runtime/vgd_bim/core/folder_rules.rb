require 'json'
require_relative 'storage'
require_relative 'tags'
require_relative 'tag_rules'

module VGD
  module BIM
    # Luật xếp tag vào thư mục tag của SketchUp (kiểu bảng luật thứ hai của 5D Auto Tag): mỗi luật là "tên thư mục <- từ khóa trong TÊN TAG".
    # Dùng lại cách khớp của TagRules (không phân biệt hoa thường và dấu, tên chứa từ khóa, luật trên thắng) và lập kế hoạch của TagRules.plan
    # (ở đó "tag" là tag của model và "thư mục hiện tại" nằm ở chỗ "tag hiện có"). Logic thuần, không gọi SketchUp; việc tạo thư mục nằm ở UI::TagAuto.
    module FolderRules
      FILE = 'tag_folder_rules'.freeze
      FORMAT = 'vgd-bim-tag-folder-rules'.freeze
      MAX_FOLDER_NAME = 60

      # 18 luật mặc định theo tiền tố tag của 5D Auto Tag, thư mục dùng đúng 18 tên nhóm của bộ tag. "# MATERIALS" đứng trước "# BASIC" vì tag vật
      # liệu (ví dụ m_brick#1) có chứa "#"; từ khóa tiền tố có dấu chấm ("A.") chỉ khớp phần tiền tố vì tên tag không có dấu chấm nào khác.
      DEFAULT = [
        {'folder' => '! INFORMATION', 'keywords' => '!'},
        {'folder' => '# MATERIALS', 'keywords' => 'm_'},
        {'folder' => '# BASIC', 'keywords' => '#, edge, face'},
        {'folder' => '@ STATUS', 'keywords' => '@'},
        {'folder' => '@ REFERENCES', 'keywords' => 'reference'},
        {'folder' => '1. CONTEXT', 'keywords' => '1.'},
        {'folder' => '2. SITE', 'keywords' => '2.'},
        {'folder' => '3. BUILDING STORIES', 'keywords' => '3.'},
        {'folder' => 'A. ARCHITECTURAL', 'keywords' => 'A.'},
        {'folder' => 'I. INTERIOR', 'keywords' => 'I.'},
        {'folder' => 'E. ELECTRICAL', 'keywords' => 'E.'},
        {'folder' => 'F. FIRE PROTECTION', 'keywords' => 'F.'},
        {'folder' => 'M. MECHANICAL', 'keywords' => 'M.'},
        {'folder' => 'P. PLUMBING', 'keywords' => 'P.'},
        {'folder' => 'L. LANDSCAPE', 'keywords' => 'L.'},
        {'folder' => 'Q. EQUIPMENT', 'keywords' => 'Q.'},
        {'folder' => 'S. STRUCTURAL', 'keywords' => 'S.'},
        {'folder' => 'C. CIVIL', 'keywords' => 'C.'}
      ].freeze

      def self.default
        DEFAULT.map(&:dup)
      end

      # Kiểm tra dữ liệu người dùng / file gửi vào. Trả về [{'folder', 'keywords'}], ném ArgumentError (nêu số dòng) nếu sai.
      def self.sanitize(list)
        raise ArgumentError, 'Danh sách luật phải là một danh sách.' unless list.is_a?(Array)
        raise ArgumentError, "Tối đa #{TagRules::MAX_RULES} luật." if list.size > TagRules::MAX_RULES
        list.each_with_index.map do |item, index|
          begin
            raise ArgumentError, 'Mỗi luật phải là một mục hợp lệ.' unless item.is_a?(Hash)
            raw = item['folder'].to_s
            raise ArgumentError, 'Tên thư mục không hợp lệ.' if raw.match?(/[[:cntrl:]]/) # xuống dòng, tab, ký tự điều khiển
            folder = raw.gsub(/[[:space:]]+/, ' ').strip
            raise ArgumentError, 'Hãy nhập tên thư mục.' if folder.empty?
            raise ArgumentError, "Tên thư mục quá dài (tối đa #{MAX_FOLDER_NAME} ký tự): #{folder}" if folder.length > MAX_FOLDER_NAME
            words = TagRules.keywords(item['keywords'], min: 1)
            raise ArgumentError, 'Cần ít nhất một từ khóa.' if words.empty?
            {'folder' => folder, 'keywords' => words.join(', ')}
          rescue ArgumentError => error
            raise ArgumentError, "Dòng #{index + 1}: #{error.message}"
          end
        end
      end

      # Dạng dùng để khớp và lập kế hoạch: [{tag: tên thư mục, words: [...]}] (khóa :tag là cách gọi chung của TagRules).
      def self.compile(rules)
        TagRules.compile(rules.map { |rule| {'tag' => rule['folder'], 'keywords' => rule['keywords']} }, min: 1)
      end

      def self.match(compiled, names)
        TagRules.match(compiled, names)
      end

      # items: [{label:, names: [tên tag], tag: tên thư mục hiện tại ('' = chưa trong thư mục nào), locked: false}] (xem TagRules.plan)
      def self.plan(items, compiled, overwrite:)
        TagRules.plan(items, compiled, overwrite: overwrite)
      end

      # ---- Lưu trên máy (một bộ mặc định), đặt lại, nhập xuất ----
      def self.load
        raw = Storage.read(FILE)
        return default if raw.nil?
        sanitize(raw.is_a?(Hash) ? raw['rules'] : raw)
      rescue ArgumentError => error
        BIM.log("Tag folder rules invalid, using defaults: #{error.message}")
        default
      end

      def self.save(list)
        clean = sanitize(list)
        Storage.write(FILE, {'format' => FORMAT, 'version' => 1, 'rules' => clean})
        clean
      end

      def self.reset
        file = Storage.path(FILE)
        File.delete(file) if File.exist?(file)
        default
      end

      def self.to_json(list)
        JSON.pretty_generate({'format' => FORMAT, 'version' => 1, 'rules' => list.map { |rule| {'folder' => rule['folder'], 'keywords' => rule['keywords']} }})
      end

      # Nhận định dạng riêng, mảng luật trần, hoặc file luật xuất từ 5D Auto Tag ({"folders": [{"tên thư mục": ["từ khóa", ...]}], "names": ...}).
      def self.from_json(text)
        data = JSON.parse(text)
        raise ArgumentError, 'File luật không đúng định dạng.' unless data.is_a?(Hash) || data.is_a?(Array)
        list = if data.is_a?(Array) then data
               elsif data['rules'].is_a?(Array) then data['rules']
               elsif data['folders'].is_a?(Array) then data['folders'].flat_map { |entry| entry.is_a?(Hash) ? entry.map { |folder, words| {'folder' => folder, 'keywords' => words.is_a?(Array) ? words.join(', ') : words.to_s} } : [] }
               else []
               end
        raise ArgumentError, 'File không có luật nào.' if list.empty?
        sanitize(list)
      rescue JSON::ParserError
        raise ArgumentError, 'File JSON không đúng định dạng.'
      end
    end
  end
end
