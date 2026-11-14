module VGD
  module BIM
    # Số đo thân của món: loại trừ theo từ khóa. Group / component / tag (của bản sao, định nghĩa, mặt, cạnh) có tên chứa một từ khóa
    # (ví dụ "tay nắm") không được tính vào khung bao, để Rộng / Dài / Cao của tủ không bị phình vì tay nắm lòi ra.
    # (Từng có tùy chọn tự cắt phần nhô theo hình học; đã bỏ vì tính lâu gây giật lag.)
    # Phần này là logic thuần (không gọi SketchUp); phần duyệt hình nằm ở MeasureProbe.
    module Measure
      MAX_WORDS = 12
      MAX_WORD_LENGTH = 40
      MAX_WORDS_TEXT = 200

      # Chữ thường, bỏ dấu tiếng Việt, đ -> d, gộp khoảng trắng: để "Tay Nắm" khớp với "tay nam".
      def self.normalize(text)
        text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').tr('đĐ', 'dd').downcase.gsub(/\s+/, ' ').strip
      end

      # "tay nắm, Handle; knob" -> ["tay nam", "handle", "knob"]. Ném lỗi nếu quá dài hoặc quá nhiều từ.
      def self.parse_words(text)
        raise ArgumentError, "Danh sách từ khóa tối đa #{MAX_WORDS_TEXT} ký tự." if text.to_s.length > MAX_WORDS_TEXT
        words = text.to_s.split(/[,;\n]/).map { |word| normalize(word) }.reject(&:empty?).uniq
        raise ArgumentError, "Tối đa #{MAX_WORDS} từ khóa, mỗi từ không quá #{MAX_WORD_LENGTH} ký tự." if words.size > MAX_WORDS || words.any? { |word| word.length > MAX_WORD_LENGTH }
        words
      end

      # Tên nào trong danh sách chứa một từ khóa (đã chuẩn hóa) thì khớp. Trả về từ khóa khớp hoặc nil.
      def self.match(words, *names)
        return nil if words.empty?
        texts = names.map { |name| normalize(name) }.reject(&:empty?)
        words.find { |word| texts.any? { |text| text.include?(word) } }
      end

      # Danh sách tag loại trừ (đúng tên tag, không phân biệt hoa thường) -> tập tên đã chuẩn hóa. Ném lỗi nếu quá nhiều hoặc tên quá dài.
      MAX_TAGS = 300
      MAX_TAG_LENGTH = 100
      def self.parse_tags(list)
        raise ArgumentError, 'Danh sách tag loại trừ không hợp lệ.' unless list.is_a?(Array) && list.all? { |name| name.is_a?(String) }
        raise ArgumentError, "Tối đa #{MAX_TAGS} tag loại trừ, mỗi tên không quá #{MAX_TAG_LENGTH} ký tự." if list.size > MAX_TAGS || list.any? { |name| name.length > MAX_TAG_LENGTH }
        list.map(&:strip).reject(&:empty?).uniq
      end

      # Tag của một phần nằm trong danh sách tag loại trừ (so đúng toàn bộ tên, không phân biệt hoa thường và dấu).
      def self.tag_excluded?(excluded_tags, tag_name)
        return false if excluded_tags.empty? || tag_name.to_s.empty?
        excluded_tags.include?(normalize(tag_name))
      end

      # Ghi chú cho cột "Ghi chú số đo": các phần đã loại theo từ khóa hoặc tag (tên không trùng, tối đa 3 tên).
      def self.note(excluded_names)
        return '' if excluded_names.empty?
        names = excluded_names.uniq
        "Bỏ #{excluded_names.size} phần theo từ khóa hoặc tag (#{names.first(3).join(', ')}#{names.size > 3 ? '…' : ''})"
      end
    end
  end
end
