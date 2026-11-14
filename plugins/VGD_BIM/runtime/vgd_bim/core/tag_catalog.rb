require 'json'
require_relative 'tags'

module VGD
  module BIM
    # Thư viện tag mẫu: 18 cụm, 201 tag theo bộ mặc định của 5D Auto Tag (config/tag_catalog.json). Người dùng tick các cụm cần dùng rồi bấm Nhập
    # (xem UI::TagAuto#tag_catalog_import): tag được thêm vào bộ tag của BIM và tạo sẵn trong model. Chỉ đọc dữ liệu, không gọi SketchUp.
    module TagCatalog
      FILE = File.expand_path('../config/tag_catalog.json', __dir__)

      # [{'group' => tên nhóm, 'label_vi' => nhãn tiếng Việt, 'tags' => [{'name' => , 'vi' => }]}]
      def self.clusters
        @clusters ||= JSON.parse(File.read(FILE, encoding: 'bom|utf-8')).freeze
      end

      # Tag của các cụm đã chọn, dạng bộ tag của BIM ({'name', 'group'}), theo thứ tự thư viện. Cụm phải có đúng tên trong thư viện.
      def self.tags_for(groups)
        raise ArgumentError, 'Hãy tick ít nhất một cụm.' unless groups.is_a?(Array) && !groups.empty?
        wanted = groups.map(&:to_s).uniq
        unknown = wanted - clusters.map { |cluster| cluster['group'] }
        raise ArgumentError, "Cụm không hợp lệ: #{unknown.first}" unless unknown.empty?
        clusters.select { |cluster| wanted.include?(cluster['group']) }.flat_map do |cluster|
          cluster['tags'].map { |tag| {'name' => tag['name'], 'group' => cluster['group']} }
        end
      end

      # Cho giao diện: [{group:, label_vi:, count:, tags: [tên]}]
      def self.summary
        clusters.map { |cluster| {group: cluster['group'], label_vi: cluster['label_vi'], count: cluster['tags'].size, tags: cluster['tags'].map { |tag| tag['name'] }} }
      end
    end
  end
end
