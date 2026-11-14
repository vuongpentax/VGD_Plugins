module VGD
  module BIM
    # Preset của bảng khối lượng: danh sách cột hiện, tiêu đề cột tự đặt và thiết lập (đơn vị, số lẻ, dấu thập phân, tiền tệ,
    # cỡ / góc nhìn / kiểu của ảnh). Có thể nhập preset từ định dạng của plugin tham khảo và xuất / nhập định dạng riêng.
    # Module này không phụ thuộc Table: danh sách cột hợp lệ và nhóm hạng mục do nơi gọi truyền vào.
    module Preset
      LENGTH_UNITS = %w[mm cm m in ft].freeze
      AREA_UNITS = %w[m2 cm2 ft2].freeze
      VOLUME_UNITS = %w[m3 cm3 ft3].freeze
      SEPARATORS = %w[. ,].freeze
      CURRENCIES = %w[VND USD EUR GBP].freeze
      IMAGE_VIEWS = %w[current isometric front].freeze     # current: chụp đúng khung nhìn; iso / front: cô lập món đồ rồi chụp từ góc đó
      IMAGE_STYLES = %w[color current].freeze              # color: hiển thị màu có texture; current: giữ kiểu đang dùng
      BACKGROUNDS = %w[transparent white].freeze
      DIGITS = (0..4).freeze
      IMAGE_SIZE = (128..4096).freeze
      IMAGE_LOCATION_SCALE = (1..20).freeze # ảnh vị trí: vùng nhìn rộng gấp bao nhiêu lần kích thước món (4 = gấp 4 lần)
      IMAGE_MARGIN = (0..100).freeze # lề chừa quanh món khi chụp ảnh, tính theo % (20 = chừa 20%)
      IMAGE_YAW = (-90..90).freeze   # Chính diện: góc lệch ngang (độ), dương = camera sang bên phải của người nhìn, âm = sang trái
      IMAGE_PITCH = (-30..80).freeze # Chính diện: góc cao (độ), 0 = nhìn ngang, dương = nhìn từ trên xuống
      MAX_NAME = 40
      MAX_HEADER = 60
      MAX_PRESETS = 100
      FORMAT = 'VGD_BIM_PRESETS'.freeze

      DEFAULT_SETTINGS = {
        'length_unit' => 'mm', 'length_digits' => 0,
        'area_unit' => 'm2', 'area_digits' => 2,
        'volume_unit' => 'm3', 'volume_digits' => 3,
        'decimal_separator' => ',', 'currency' => 'VND',
        'image_width' => 512, 'image_height' => 512,
        'image_view' => 'isometric', 'image_style' => 'color', 'image_background' => 'transparent',
        'image_margin' => 20, 'image_location_scale' => 4, 'image_yaw' => 0, 'image_pitch' => 0,
        # Ảnh vị trí (cột Ảnh vị trí) có bộ thiết lập riêng cùng loại với ảnh chính; góc nhìn mặc định Iso như trước.
        'loc_width' => 512, 'loc_height' => 512, 'loc_view' => 'isometric', 'loc_style' => 'color', 'loc_background' => 'transparent',
        'loc_margin' => 20, 'loc_yaw' => 0, 'loc_pitch' => 0,
        # Ảnh phụ (cột Ảnh 3, Ảnh 4): chụp thêm góc khác của cùng món, cùng cách chụp với ảnh chính, mỗi ảnh một bộ thiết lập riêng.
        'x1_width' => 512, 'x1_height' => 512, 'x1_view' => 'front', 'x1_style' => 'color', 'x1_background' => 'transparent',
        'x1_margin' => 20, 'x1_yaw' => 0, 'x1_pitch' => 0,
        'x2_width' => 512, 'x2_height' => 512, 'x2_view' => 'isometric', 'x2_style' => 'color', 'x2_background' => 'transparent',
        'x2_margin' => 20, 'x2_yaw' => 0, 'x2_pitch' => 0
      }.freeze

      # Preset cũ chưa có thiết lập ảnh vị trí: lấy theo thiết lập của ảnh chính để ảnh vị trí không đổi cỡ / kiểu / nền / lề sau khi cập nhật plugin.
      LOCATION_FOLLOWS = {'loc_width' => 'image_width', 'loc_height' => 'image_height', 'loc_style' => 'image_style',
                          'loc_background' => 'image_background', 'loc_margin' => 'image_margin',
                          'x1_width' => 'image_width', 'x1_height' => 'image_height', 'x1_style' => 'image_style',
                          'x1_background' => 'image_background', 'x1_margin' => 'image_margin',
                          'x2_width' => 'image_width', 'x2_height' => 'image_height', 'x2_style' => 'image_style',
                          'x2_background' => 'image_background', 'x2_margin' => 'image_margin'}.freeze

      ENUMS = {
        'length_unit' => [LENGTH_UNITS, 'Đơn vị chiều dài không hợp lệ.'],
        'area_unit' => [AREA_UNITS, 'Đơn vị diện tích không hợp lệ.'],
        'volume_unit' => [VOLUME_UNITS, 'Đơn vị thể tích không hợp lệ.'],
        'decimal_separator' => [SEPARATORS, 'Dấu thập phân không hợp lệ.'],
        'currency' => [CURRENCIES, 'Tiền tệ không hợp lệ.'],
        'image_view' => [IMAGE_VIEWS, 'Góc nhìn của ảnh không hợp lệ.'],
        'image_style' => [IMAGE_STYLES, 'Kiểu hiển thị của ảnh không hợp lệ.'],
        'image_background' => [BACKGROUNDS, 'Nền ảnh không hợp lệ.'],
        'loc_view' => [IMAGE_VIEWS, 'Góc nhìn của ảnh vị trí không hợp lệ.'],
        'loc_style' => [IMAGE_STYLES, 'Kiểu hiển thị của ảnh vị trí không hợp lệ.'],
        'loc_background' => [BACKGROUNDS, 'Nền ảnh vị trí không hợp lệ.'],
        'x1_view' => [IMAGE_VIEWS, 'Góc nhìn của ảnh 3 không hợp lệ.'],
        'x1_style' => [IMAGE_STYLES, 'Kiểu hiển thị của ảnh 3 không hợp lệ.'],
        'x1_background' => [BACKGROUNDS, 'Nền ảnh 3 không hợp lệ.'],
        'x2_view' => [IMAGE_VIEWS, 'Góc nhìn của ảnh 4 không hợp lệ.'],
        'x2_style' => [IMAGE_STYLES, 'Kiểu hiển thị của ảnh 4 không hợp lệ.'],
        'x2_background' => [BACKGROUNDS, 'Nền ảnh 4 không hợp lệ.']
      }.freeze

      # Các lựa chọn của thiết lập preset, gửi cho giao diện để không phải chép lại ở JavaScript.
      def self.choices
        {'length_units' => LENGTH_UNITS, 'area_units' => AREA_UNITS, 'volume_units' => VOLUME_UNITS, 'separators' => SEPARATORS,
         'currencies' => CURRENCIES, 'views' => IMAGE_VIEWS, 'styles' => IMAGE_STYLES, 'backgrounds' => BACKGROUNDS,
         'digits' => DIGITS.to_a, 'sizes' => [256, 512, 768, 1024, 1536, 2048]}
      end

      # ---- Thiết lập ----
      # Bản chặt (dữ liệu người dùng nhập): giá trị sai thì báo lỗi. Mục thiếu lấy mặc định, mục lạ bị bỏ.
      def self.settings!(raw)
        raise ArgumentError, 'Thiết lập của preset không hợp lệ.' unless raw.is_a?(Hash)
        DEFAULT_SETTINGS.each_with_object({}) do |(key, default), out|
          out[key] = raw.key?(key) ? clean_setting(key, raw[key]) : missing_default(key, default, out)
        end
      end

      # Bản dễ tính (đọc file đã lưu, nhập từ plugin khác): mục sai về mặc định, không báo lỗi.
      def self.settings(raw)
        return DEFAULT_SETTINGS.dup unless raw.is_a?(Hash)
        DEFAULT_SETTINGS.each_with_object({}) do |(key, default), out|
          out[key] = raw.key?(key) ? (clean_setting(key, raw[key]) rescue missing_default(key, default, out)) : missing_default(key, default, out)
        end
      end

      # Mục thiếu (hoặc sai ở bản dễ tính): mục ảnh vị trí theo ảnh chính (đã xử lý trước trong DEFAULT_SETTINGS), còn lại là mặc định.
      def self.missing_default(key, default, done)
        LOCATION_FOLLOWS.key?(key) ? done.fetch(LOCATION_FOLLOWS.fetch(key), default) : default
      end

      def self.clean_setting(key, value)
        if ENUMS.key?(key)
          allowed, message = ENUMS.fetch(key)
          raise ArgumentError, message unless allowed.include?(value.to_s)
          value.to_s
        elsif key.end_with?('_digits')
          number = integer(value)
          raise ArgumentError, "Số chữ số lẻ phải từ #{DIGITS.first} đến #{DIGITS.last}." unless number && DIGITS.cover?(number)
          number
        elsif key == 'image_location_scale'
          number = integer(value)
          raise ArgumentError, "Vùng nhìn của ảnh vị trí phải từ #{IMAGE_LOCATION_SCALE.first} đến #{IMAGE_LOCATION_SCALE.last} lần kích thước món." unless number && IMAGE_LOCATION_SCALE.cover?(number)
          number
        elsif key.end_with?('_yaw')
          number = integer(value)
          raise ArgumentError, "Góc lệch trái / phải phải từ #{IMAGE_YAW.first} đến #{IMAGE_YAW.last} độ." unless number && IMAGE_YAW.cover?(number)
          number
        elsif key.end_with?('_pitch')
          number = integer(value)
          raise ArgumentError, "Góc cao phải từ #{IMAGE_PITCH.first} đến #{IMAGE_PITCH.last} độ." unless number && IMAGE_PITCH.cover?(number)
          number
        elsif key.end_with?('_margin')
          number = integer(value)
          raise ArgumentError, "Lề ảnh phải từ #{IMAGE_MARGIN.first} đến #{IMAGE_MARGIN.last} (%)." unless number && IMAGE_MARGIN.cover?(number)
          number
        else # image_width, image_height, loc_*, x1_*, x2_* (rộng, cao)
          number = integer(value)
          raise ArgumentError, "Cỡ ảnh phải từ #{IMAGE_SIZE.first} đến #{IMAGE_SIZE.last} điểm ảnh." unless number && IMAGE_SIZE.cover?(number)
          number
        end
      end

      def self.integer(value)
        value.is_a?(Integer) ? value : (Integer(value.to_s, 10) rescue nil)
      end

      # ---- Tiêu đề cột tự đặt (cột => chữ). Rỗng nghĩa là dùng tên gốc, nên không lưu. ----
      def self.headers!(raw, column_keys)
        return {} if raw.nil?
        raise ArgumentError, 'Tiêu đề cột không hợp lệ.' unless raw.is_a?(Hash)
        raw.each_with_object({}) do |(key, value), out|
          next unless column_keys.include?(key.to_s)
          raise ArgumentError, 'Tiêu đề cột phải là chữ.' unless value.is_a?(String)
          text = value.gsub(/[\u0000-\u001f\u007f]/, '').strip
          raise ArgumentError, "Tiêu đề cột tối đa #{MAX_HEADER} ký tự." if text.length > MAX_HEADER
          out[key.to_s] = text unless text.empty?
        end
      end

      def self.headers(raw, column_keys)
        return {} unless raw.is_a?(Hash)
        raw.each_with_object({}) do |(key, value), out|
          next unless column_keys.include?(key.to_s) && value.is_a?(String)
          text = value.gsub(/[\u0000-\u001f\u007f]/, '').strip
          out[key.to_s] = text unless text.empty? || text.length > MAX_HEADER
        end
      end

      # ---- Một preset (định dạng riêng) ----
      def self.clean_name(value)
        value.to_s.strip.gsub(/\s+/, ' ')
      end

      def self.sanitize(item, column_keys, groups)
        raise ArgumentError, 'Preset không hợp lệ.' unless item.is_a?(Hash)
        name = clean_name(item['name'])
        raise ArgumentError, 'Tên preset không được để trống.' if name.empty?
        raise ArgumentError, "Tên preset quá dài (tối đa #{MAX_NAME} ký tự)." if name.length > MAX_NAME
        group = item['group'].to_s
        raise ArgumentError, "Nhóm hạng mục không hợp lệ: #{group}" unless group.empty? || groups.include?(group)
        # Giữ đúng thứ tự cột người dùng đã sắp xếp; bỏ cột lạ và cột trùng.
        columns = Array(item['columns']).map(&:to_s).uniq.select { |key| column_keys.include?(key) }
        raise ArgumentError, 'Preset phải có ít nhất một cột.' if columns.empty?
        {'name' => name, 'group' => group, 'columns' => columns,
         'headers' => headers!(item['headers'], column_keys), 'settings' => settings!(item.fetch('settings', {}))}
      end

      # ---- Preset có sẵn: 4 của BIM, rồi 7 chuyển từ bộ preset mẫu của plugin tham khảo (tên và tiêu đề đã Việt hóa) ----
      def self.builtin(name, group, columns, headers = {}, overrides = {})
        {'name' => name, 'group' => group, 'columns' => columns.freeze, 'headers' => headers.freeze,
         'settings' => DEFAULT_SETTINGS.merge(overrides).freeze}.freeze
      end

      METERS = {'length_unit' => 'm', 'length_digits' => 2, 'area_digits' => 2, 'volume_digits' => 2}.freeze
      MILLIMETERS = {'length_unit' => 'mm', 'length_digits' => 0, 'area_digits' => 2, 'volume_digits' => 2}.freeze
      SMALL_IMAGES = {'image_width' => 256, 'image_height' => 256}.freeze
      LIST_HEADERS = {'ordinal' => 'STT', 'image' => 'Ảnh', 'definition' => 'Mã hạng mục', 'instance' => 'Loại', 'quantity' => 'Số lượng'}.freeze

      BUILT_IN = [
        builtin('Tất cả', '', %w[ordinal image entity definition instance description material tag status quantity]),
        builtin('Phần thô', 'S. STRUCTURAL', %w[ordinal entity instance lenX lenY lenZ areaFace volume tag material quantity]),
        builtin('Hoàn thiện', 'A. ARCHITECTURAL', %w[ordinal entity instance description lenX lenY lenZ areaXZ areaXY areaFace tag material status quantity]),
        builtin('Đồ rời', 'I. INTERIOR', %w[ordinal entity definition instance description lenX lenY lenZ tag material status quantity]),
        builtin('Mặc định', '', %w[ordinal entity definition instance description tag material], {}, METERS.merge(SMALL_IMAGES)),
        builtin('Phòng & Khu vực', '', %w[ordinal image definition instance lenX lenY areaProjected],
                {'ordinal' => 'STT', 'image' => 'Ảnh', 'definition' => 'Mã phòng', 'instance' => 'Tên phòng', 'lenX' => 'Rộng', 'lenY' => 'Dài', 'areaProjected' => 'Diện tích phòng'},
                METERS.merge(SMALL_IMAGES).merge('image_view' => 'current')),
        builtin('Cửa & Cửa sổ', '', %w[ordinal image definition instance description lenXZ areaXZ quantity],
                LIST_HEADERS.merge('description' => 'Hoàn thiện & phụ kiện', 'lenXZ' => 'Rộng x Cao', 'areaXZ' => 'Diện tích (R x C)'),
                METERS.merge(SMALL_IMAGES).merge('image_view' => 'front')),
        builtin('Nội thất', '', %w[ordinal image definition instance description lenXYZ owner quantity],
                LIST_HEADERS.merge('description' => 'Mô tả', 'lenXYZ' => 'Kích thước (R x S x C)', 'owner' => 'Thương hiệu'), MILLIMETERS.merge(SMALL_IMAGES)),
        builtin('Tủ', 'I. INTERIOR', %w[ordinal image definition instance description lenXYZ material level room quantity],
                LIST_HEADERS.merge('description' => 'Mô tả', 'lenXYZ' => 'Kích thước (R x S x C)', 'material' => 'Vật liệu', 'level' => 'Tầng', 'room' => 'Phòng'), MILLIMETERS.merge(SMALL_IMAGES).merge('image_view' => 'front')),
        builtin('Thiết bị & Phụ kiện', '', %w[ordinal image definition instance description lenXYZ owner quantity],
                LIST_HEADERS.merge('description' => 'Thông số', 'lenXYZ' => 'Kích thước (R x S x C)', 'owner' => 'Thương hiệu'), MILLIMETERS.merge(SMALL_IMAGES)),
        builtin('Chiếu sáng', '', %w[ordinal image definition instance description lenXYZ owner quantity],
                LIST_HEADERS.merge('description' => 'Thông số', 'lenXYZ' => 'Kích thước (R x S x C)', 'owner' => 'Thương hiệu'), MILLIMETERS.merge(SMALL_IMAGES)),
        builtin('Vật liệu', '', %w[ordinal image material areaFace],
                {'ordinal' => 'STT', 'image' => 'Ảnh vật liệu', 'material' => 'Tên vật liệu', 'areaFace' => 'Diện tích mặt'}, METERS.merge(SMALL_IMAGES).merge('image_view' => 'current'))
      ].freeze

      # ---- Nhập / xuất ----
      # Nhận: định dạng riêng ({format, version, presets: [...]}) hoặc định dạng của plugin tham khảo ({tên preset => {columns, headers, order, settings, ...}}).
      # Trả về danh sách preset (định dạng riêng). Preset trùng tên preset có sẵn được thêm "(nhập)".
      def self.import(obj, column_keys, groups = [], builtin_names = BUILT_IN.map { |p| p['name'] })
        raise ArgumentError, 'Tệp preset không đúng định dạng.' unless obj.is_a?(Hash)
        list = if obj['format'] == FORMAT
                 raise ArgumentError, 'Phiên bản tệp preset chưa được hỗ trợ.' unless obj['version'] == 1
                 raise ArgumentError, 'Tệp preset không đúng định dạng.' unless obj['presets'].is_a?(Array)
                 raise ArgumentError, "Quá nhiều preset (tối đa #{MAX_PRESETS})." if obj['presets'].size > MAX_PRESETS
                 obj['presets'].map { |item| sanitize(item, column_keys, groups) }
               else
                 raise ArgumentError, "Quá nhiều preset (tối đa #{MAX_PRESETS})." if obj.size > MAX_PRESETS
                 obj.map { |name, entry| from_reference(name, entry, column_keys) }.compact
               end
        raise ArgumentError, 'Tệp không có preset hợp lệ nào.' if list.empty?
        list.map { |preset| builtin_names.include?(preset['name']) ? preset.merge('name' => "#{preset['name']} (nhập)"[0, MAX_NAME]) : preset }
      end

      def self.export(presets)
        {'format' => FORMAT, 'version' => 1,
         'presets' => presets.map { |p| p.slice('name', 'group', 'columns', 'headers', 'settings') }}
      end

      LENGTH_FACTORS = {1 => 'm', 1000 => 'mm', 100 => 'cm'}.freeze
      AREA_FACTORS = {1 => 'm2', 10_000 => 'cm2'}.freeze
      VOLUME_FACTORS = {1 => 'm3', 1_000_000 => 'cm3'}.freeze
      REFERENCE_VIEWS = {'Isometric view' => 'isometric', 'Front view' => 'front'}.freeze

      # Chuyển một preset của plugin tham khảo. Giá trị không hiểu được thì dùng mặc định. Không đọc sắp xếp vì chưa rõ chiều.
      def self.from_reference(name, entry, column_keys)
        return nil unless entry.is_a?(Hash)
        shown = entry['columns'].is_a?(Hash) ? entry['columns'] : {}
        order = Array(entry['order']).map(&:to_s)
        wanted = column_keys.select { |key| shown[key] == true }
        columns = (order & wanted) + (wanted - order)
        return nil if columns.empty?
        raw = entry['settings'].is_a?(Hash) ? entry['settings'] : {}
        converted = {
          'length_unit' => LENGTH_FACTORS[number(raw['formatLength'])], 'length_digits' => raw['roundLength'],
          'area_unit' => AREA_FACTORS[number(raw['formatArea'])], 'area_digits' => raw['roundArea'],
          'volume_unit' => VOLUME_FACTORS[number(raw['formatVolume'])], 'volume_digits' => raw['roundVolume'],
          'decimal_separator' => raw['decimalSeparator'], 'currency' => entry['currency'],
          'image_width' => raw['imageWidth'], 'image_height' => raw['imageHeight'],
          'image_view' => REFERENCE_VIEWS.fetch(raw['imageView'].to_s, 'current'), 'image_style' => raw['imageStyle'].to_s == 'Color style' ? 'color' : 'current'
        }.reject { |_, value| value.nil? }
        preset_name = clean_name(name)[0, MAX_NAME]
        return nil if preset_name.empty?
        {'name' => preset_name, 'group' => '', 'columns' => columns, 'headers' => headers(entry['headers'], column_keys), 'settings' => settings(converted)}
      end

      def self.number(value)
        value.is_a?(Numeric) && value == value.to_i ? value.to_i : nil
      end
    end
  end
end
