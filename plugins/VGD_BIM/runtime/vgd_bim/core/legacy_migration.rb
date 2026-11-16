require 'json'
require 'fileutils'
require_relative 'settings'
require_relative 'model_settings'
require_relative 'images'

module VGD
  module BIM
    # Chuyển dữ liệu theo cách cũ sang thư mục cạnh file SketchUp (ModelSettings.folder), khi người dùng đồng ý:
    #   cũ: cài đặt riêng trong dictionary VGD_BIM_MODEL của file SketchUp, ảnh trong thư mục ảnh chung của máy (<thư mục ảnh>/<mã model>/...)
    #   mới: <thư mục cạnh file SketchUp>/settings.json và <thư mục cạnh file SketchUp>/<mã model>/...
    # Ảnh cũ chỉ được sao chép, không xóa. Dữ liệu cũ trong file SketchUp được gỡ sau khi chuyển xong (để không hỏi lại).
    module LegacyMigration
      DICTIONARY = 'VGD_BIM_MODEL'.freeze
      KEY = 'settings'.freeze
      OLD_KEYS = %w[exclude_words exclude_tags table_view].freeze

      # Cài đặt riêng theo cách cũ trong file SketchUp ({} nếu không có hoặc hỏng).
      def self.old_settings(model)
        return {} unless model.respond_to?(:get_attribute)
        raw = model.get_attribute(DICTIONARY, KEY).to_s
        return {} if raw.empty?
        data = JSON.parse(raw)
        data.is_a?(Hash) ? data : {}
      rescue JSON::ParserError
        {}
      end

      # Thư mục ảnh cũ của model (có ảnh), theo cài đặt riêng của file hoặc thư mục ảnh chung của máy.
      def self.old_image_dirs(model)
        own = old_settings(model)['image_dir'].to_s
        root = own.empty? ? Settings.image_dir : own
        [Images.model_key(model), Images.legacy_key(model)].uniq.map { |key| File.join(root, key) }.select { |dir| png_files(dir).any? }
      end

      def self.png_files(dir)
        File.directory?(dir) ? Dir.children(dir).select { |name| name.end_with?('.png') && !name.start_with?('.') && !name.include?('.tmp.') } : []
      end

      # nil nếu không có gì để chuyển (file chưa lưu, đã có settings.json, hoặc không có dữ liệu cũ).
      def self.plan(model)
        return nil unless ModelSettings.saved?(model)
        return nil if File.file?(ModelSettings.file(model))
        settings = old_settings(model)
        images = old_image_dirs(model)
        return nil if settings.empty? && images.empty?
        {settings: settings, images: images, folder: ModelSettings.folder(model)}
      end

      # Trả về {images: số ảnh đã sao chép}. Lỗi ghi file thì báo (ArgumentError / SystemCallError), dữ liệu cũ vẫn còn nguyên.
      def self.run(model, plan)
        data = plan[:settings].select { |key, _| OLD_KEYS.include?(key) }
        copied = 0
        plan[:images].each do |source|
          target = File.join(plan[:folder], File.basename(source))
          FileUtils.mkdir_p(target)
          png_files(source).each do |name|
            destination = File.join(target, name)
            next if File.exist?(destination)
            FileUtils.cp(File.join(source, name), destination)
            copied += 1
          end
        end
        ModelSettings.save_json(ModelSettings.file(model), ModelSettings.clean_data(data)) # luôn tạo settings.json để lần sau không hỏi lại
        clear_old(model)
        {images: copied}
      end

      # Gỡ cài đặt cũ trong file SketchUp (một thao tác trong suốt). Không gỡ được thì thôi: settings.json đã có nên không hỏi lại.
      def self.clear_old(model)
        return unless model.respond_to?(:delete_attribute) && model.respond_to?(:start_operation)
        model.start_operation('VGD_BIM · Chuyển cài đặt', true, false, true)
        begin
          model.delete_attribute(DICTIONARY, KEY)
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
      rescue StandardError => error
        BIM.log("Không gỡ được cài đặt cũ trong file SketchUp: #{error.message}")
      end
    end
  end
end
