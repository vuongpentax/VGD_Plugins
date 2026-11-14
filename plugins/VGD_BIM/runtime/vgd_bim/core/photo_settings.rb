require_relative 'images'

module VGD
  module BIM
    # Thông số chụp ảnh riêng của từng món (nút ⚙ trên ô ảnh): góc nhìn, bên Iso, góc lệch, góc cao, lề, vùng nhìn. Món không đặt thì dùng thiết lập của preset.
    # Lưu trong dictionary VGD_BIM_TABLE của chính đối tượng (cùng chỗ với Link / Cỡ / Đơn giá, ngoài schema dùng chung), mỗi loại ảnh một khóa JSON
    # (photo_full: ảnh chính, photo_location: ảnh vị trí). Chỉ lưu các mục người dùng đã đặt; mục trống nghĩa là theo preset.
    module PhotoSettings
      DICTIONARY = 'VGD_BIM_TABLE'.freeze
      KEYS = {full: 'photo_full', location: 'photo_location', extra1: 'photo_extra1', extra2: 'photo_extra2'}.freeze
      COMMON = %w[view side yaw pitch margin].freeze

      # Dữ liệu từ giao diện: khóa lạ hoặc giá trị sai thì báo lỗi; giá trị rỗng / nil bỏ đi (nghĩa là theo preset). Trả về Hash chữ => giá trị đã làm sạch.
      def self.sanitize!(raw, kind)
        raise ArgumentError, 'Thông số ảnh không hợp lệ.' unless raw.is_a?(Hash)
        allowed = kind == :location ? COMMON + %w[scale] : COMMON
        raw.each_with_object({}) do |(key, value), out|
          key = key.to_s
          raise ArgumentError, "Thông số ảnh không có mục #{key}." unless allowed.include?(key)
          next if value.nil? || value.to_s.strip.empty?
          out[key] = clean(key, value)
        end
      end

      def self.clean(key, value)
        case key
        when 'view' then Preset.clean_setting('image_view', value)
        when 'side'
          raise ArgumentError, 'Bên của góc Iso không hợp lệ.' unless %w[right left].include?(value.to_s)
          value.to_s
        when 'yaw' then Preset.clean_setting('image_yaw', value)
        when 'pitch' then Preset.clean_setting('image_pitch', value)
        when 'margin' then Preset.clean_setting('image_margin', value)
        else Preset.clean_setting('image_location_scale', value) # scale
        end
      end

      # Đọc thông số riêng của món; không có, hỏng hoặc có giá trị sai thì coi như chưa đặt (không đoán, không báo lỗi).
      def self.read(entity, kind)
        return {} unless entity.respond_to?(:get_attribute)
        raw = entity.get_attribute(DICTIONARY, KEYS.fetch(kind)).to_s
        return {} if raw.empty?
        sanitize!(JSON.parse(raw), kind)
      rescue JSON::ParserError, ArgumentError
        {}
      end

      # Hash rỗng nghĩa là bỏ thông số riêng (về theo preset). Gọi trong một thao tác của model để có một bước hoàn tác.
      def self.write(entity, kind, raw)
        raise ArgumentError, 'Đối tượng đang bị khóa nên không lưu được thông số ảnh.' if entity.locked?
        clean = sanitize!(raw, kind)
        if clean.empty? then entity.delete_attribute(DICTIONARY, KEYS.fetch(kind))
        else entity.set_attribute(DICTIONARY, KEYS.fetch(kind), JSON.generate(clean))
        end
        clean
      end

      # Ghép thông số riêng vào thiết lập của preset: trả về [thiết lập mới, bên Iso hoặc nil]. Không sửa thiết lập gốc.
      # force_view: người dùng bấm nút chụp một lần (Khung nhìn hiện tại, Iso trái / phải) nên bỏ qua góc nhìn và bên Iso riêng của món.
      def self.apply(settings, overrides, kind, force_view: false)
        prefix = Images::PREFIX.fetch(kind)
        names = {'view' => "#{prefix}_view", 'yaw' => "#{prefix}_yaw", 'pitch' => "#{prefix}_pitch", 'margin' => "#{prefix}_margin", 'scale' => 'image_location_scale'}
        merged = settings.dup
        overrides.each do |key, value|
          next if key == 'side' || (force_view && key == 'view')
          merged[names.fetch(key)] = value
        end
        [merged, force_view ? nil : overrides['side']]
      end
    end
  end
end
