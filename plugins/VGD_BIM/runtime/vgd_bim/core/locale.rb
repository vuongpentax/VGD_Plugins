require 'json'
module VGD
  module BIM
    module Locale
      def self.dictionary
        @dictionary ||= JSON.parse(File.read(File.expand_path('../config/vi.json', __dir__.dup.force_encoding(Encoding::UTF_8)), encoding: 'UTF-8'))
      end
      # Từ điển hiển thị trên giao diện theo ngôn ngữ trong Cài đặt. Báo cáo CSV và thông báo kiểm tra vẫn dùng tiếng Việt (dictionary).
      def self.ui_dictionary(language)
        return dictionary unless language == 'en'
        @english ||= JSON.parse(File.read(File.expand_path('../config/en.json', __dir__.dup.force_encoding(Encoding::UTF_8)), encoding: 'UTF-8'))
      end
      # Bảng đối chiếu tên tiếng Việt -> tiếng Anh của các nhóm có tên xuất hiện trong thông báo (trường, đơn vị, cách đo),
      # để giao diện dịch được câu như "Thiếu mô tả". Lấy từ chính hai từ điển nên không lệch nhau.
      NAME_GROUPS = %w[fields unit quantity_method].freeze
      def self.vi_en_names
        english = ui_dictionary('en')
        NAME_GROUPS.each_with_object({}) do |group, result|
          result[group] = dictionary.fetch(group, {}).each_with_object({}) { |(key, vi), map| map[vi] = english.fetch(group, {}).fetch(key, vi) }
        end
      end
      def self.label(group, value)
        dictionary.fetch(group.to_s, {}).fetch(value.to_s, value.to_s)
      end
      def self.field(key); label('fields', key); end
      def self.value(key, value)
        return value ? 'Có' : 'Không' if value == true || value == false
        label(key, value)
      end
    end
  end
end
