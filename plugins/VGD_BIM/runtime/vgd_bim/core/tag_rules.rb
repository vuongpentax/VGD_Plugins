require 'json'
require_relative 'storage'
require_relative 'tags'
require_relative 'measure'

module VGD
  module BIM
    # Luật gắn tag tự động theo từ khóa trong tên group / component (kiểu 5D Auto Tag): mỗi luật là "tên tag <- các từ khóa".
    # Luật đứng trước thắng. Khớp không phân biệt hoa thường và dấu tiếng Việt, theo kiểu "tên chứa từ khóa".
    # Phần này là logic thuần (không gọi SketchUp); phần duyệt và gắn tag nằm ở UI::TagAuto.
    module TagRules
      FILE = 'tag_rules'.freeze
      FORMAT = 'vgd-bim-tag-rules'.freeze
      MAX_RULES = 100
      MAX_KEYWORDS = 30     # từ khóa mỗi luật
      MIN_KEYWORD = 2       # từ khóa 1 ký tự khớp gần như mọi tên
      MAX_KEYWORD = 40
      BASED_ON = %w[both instance definition].freeze # tên bản sao, tên component, hoặc cả hai
      SAMPLES = 3

      # Bộ luật mẫu ban đầu: 5 luật mặc định của 5D Auto Tag (tên tag, từ khóa tiếng Anh) kèm từ khóa tiếng Việt để model Việt vẫn khớp.
      # "Window" đứng trước "Door" (khác thứ tự của Auto Tag) vì từ khóa tiếng Việt "cửa" cũng nằm trong "cửa sổ".
      DEFAULT = [
        {'tag' => 'A. WALL', 'keywords' => 'wall, tường'},
        {'tag' => 'A. WINDOW', 'keywords' => 'window, cửa sổ'},
        {'tag' => 'A. DOOR', 'keywords' => 'door, cửa'},
        {'tag' => 'A. RAILING', 'keywords' => 'railing, lan can'},
        {'tag' => 'A. STAIR', 'keywords' => 'stair, cầu thang'}
      ].freeze

      def self.default
        DEFAULT.map(&:dup)
      end

      # Chữ người dùng gõ -> danh sách từ khóa (giữ nguyên cách viết, bỏ rỗng và trùng không phân biệt hoa thường / dấu).
      # min: số ký tự tối thiểu của một từ khóa (luật gắn tag cần 2; luật thư mục cho phép 1 vì tiền tố Auto Tag như "!", "#", "@").
      def self.keywords(text, min: MIN_KEYWORD)
        words = text.to_s.split(/[,;\n]/).map(&:strip).reject(&:empty?).uniq { |word| Measure.normalize(word) }
        raise ArgumentError, "Mỗi luật tối đa #{MAX_KEYWORDS} từ khóa, mỗi từ khóa không quá #{MAX_KEYWORD} ký tự." if words.size > MAX_KEYWORDS || words.any? { |word| word.length > MAX_KEYWORD }
        raise ArgumentError, "Từ khóa phải có ít nhất #{min} ký tự." if words.any? { |word| word.length < min }
        words
      end

      # Kiểm tra dữ liệu người dùng / file gửi vào. Trả về danh sách sạch [{'tag', 'keywords'}], ném ArgumentError (nêu số dòng) nếu sai.
      def self.sanitize(list)
        raise ArgumentError, 'Danh sách luật phải là một danh sách.' unless list.is_a?(Array)
        raise ArgumentError, "Tối đa #{MAX_RULES} luật." if list.size > MAX_RULES
        list.each_with_index.map do |item, index|
          begin
            raise ArgumentError, 'Mỗi luật phải là một mục hợp lệ.' unless item.is_a?(Hash)
            tag = Tags.normalize_name(item['tag'])
            raise ArgumentError, "Tên tag quá dài (tối đa #{Tags::MAX_NAME} ký tự): #{tag}" if tag.length > Tags::MAX_NAME
            words = keywords(item['keywords'])
            raise ArgumentError, 'Cần ít nhất một từ khóa.' if words.empty?
            {'tag' => tag, 'keywords' => words.join(', ')}
          rescue ArgumentError => error
            raise ArgumentError, "Dòng #{index + 1}: #{error.message}"
          end
        end
      end

      # Luật đã kiểm tra -> dạng dùng để khớp: [{tag:, words: [từ khóa đã chuẩn hóa]}] (giữ thứ tự = độ ưu tiên).
      def self.compile(rules, min: MIN_KEYWORD)
        rules.map { |rule| {tag: rule['tag'], words: keywords(rule['keywords'], min: min).map { |word| Measure.normalize(word) }} }
      end

      # Vị trí của luật đầu tiên có từ khóa nằm trong một trong các tên, hoặc nil.
      def self.match(compiled, names)
        texts = Array(names).map { |name| Measure.normalize(name) }.reject(&:empty?)
        return nil if texts.empty?
        compiled.index { |rule| rule[:words].any? { |word| texts.any? { |text| text.include?(word) } } }
      end

      # items: [{label:, names: [tên bản sao, tên component], tag: tên tag hiện có ('' = chưa có), locked: bool}].
      # Trả về {assign: [[item, vị trí luật]], rules: [{index:, tag:, count:, samples:}], same:, kept:, unmatched:, locked:, total:}.
      # Đã bị khóa: không bao giờ gắn. Không khớp luật nào: unmatched. Đã đúng tag: same. Đã có tag khác mà không ghi đè: kept.
      def self.plan(items, compiled, overwrite:)
        result = {assign: [], same: 0, kept: 0, unmatched: 0, locked: 0, total: items.size}
        items.each do |item|
          if item[:locked]
            result[:locked] += 1
            next
          end
          index = match(compiled, item[:names])
          if index.nil?
            result[:unmatched] += 1
          elsif Tags.key(item[:tag]) == Tags.key(compiled[index][:tag])
            result[:same] += 1
          elsif !item[:tag].to_s.empty? && !overwrite
            result[:kept] += 1
          else
            result[:assign] << [item, index]
          end
        end
        grouped = result[:assign].group_by(&:last)
        result[:rules] = grouped.keys.sort.map do |index|
          entries = grouped[index]
          {index: index, tag: compiled[index][:tag], count: entries.size, samples: entries.first(SAMPLES).map { |entry, _| entry[:label] }}
        end
        result
      end

      # ---- Lưu trên máy (một bộ mặc định, như Auto Tag), đặt lại, nhập xuất ----
      def self.load
        raw = Storage.read(FILE)
        return default if raw.nil?
        sanitize(raw.is_a?(Hash) ? raw['rules'] : raw)
      rescue ArgumentError => error
        BIM.log("Tag rules invalid, using defaults: #{error.message}")
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
        JSON.pretty_generate({'format' => FORMAT, 'version' => 1, 'rules' => list.map { |rule| {'tag' => rule['tag'], 'keywords' => rule['keywords']} }})
      end

      # Nhận định dạng riêng, mảng luật trần, hoặc file luật xuất từ 5D Auto Tag ({"names": [{"tên tag": ["từ khóa", ...]}], "folders": ...}).
      def self.from_json(text)
        data = JSON.parse(text)
        raise ArgumentError, 'File luật không đúng định dạng.' unless data.is_a?(Hash) || data.is_a?(Array)
        list = if data.is_a?(Array) then data
               elsif data['rules'].is_a?(Array) then data['rules']
               elsif data['names'].is_a?(Array) then data['names'].flat_map { |entry| entry.is_a?(Hash) ? entry.map { |tag, words| {'tag' => tag, 'keywords' => words.is_a?(Array) ? words.join(', ') : words.to_s} } : [] }
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
