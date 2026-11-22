require 'json'

module VGD
  module BIM
    # Đối tượng do plugin VGD Structure dựng (cột, dầm, tường, sàn, trần): BIM ĐỌC kích thước chính xác plugin ghi trên đối tượng để lập bảng khối lượng đúng,
    # thay vì đoán từ khối bao (tường chạy theo trục Y hay trần mỏng sẽ ra diện tích sai nếu chỉ dùng khối bao). Chỉ đọc, không sửa dữ liệu của plugin.
    # Hợp đồng dữ liệu: docs/vgd_structure/SPEC.md mục 2 và docs/vgd_bim/BRIDGE.md.
    module StructureSource
      SOURCE_DICTIONARY = 'VGD_BIM_SOURCE'.freeze
      STRUCT_DICTIONARY = 'VGD_STRUCT'.freeze
      PLUGIN = 'vgd_structure'.freeze
      KINDS = %w[column beam wall slab ceiling door window footing roof].freeze
      # Nhóm chứa các phần tử (mỗi tầng một nhóm theo loại) và nhóm lưới trục: không phải món, không tính khối lượng.
      CONTAINER_KINDS = %w[columns beams walls slabs ceilings footings roofs grid].freeze
      MAX_VALUE = 1.0e9
      # Cách tính khi món không có tag cho biết (tag S. COLUMN, A. WALL... đã có cách tính theo từ khóa của tên tag).
      DEFAULT_METHOD = {'column' => 'volume', 'beam' => 'volume', 'wall' => 'area', 'slab' => 'volume', 'ceiling' => 'area', 'door' => 'count', 'window' => 'count', 'footing' => 'volume', 'roof' => 'area'}.freeze

      def self.element?(entity)
        entity.respond_to?(:get_attribute) && entity.get_attribute(SOURCE_DICTIONARY, 'plugin') == PLUGIN && KINDS.include?(entity.get_attribute(SOURCE_DICTIONARY, 'kind'))
      end

      def self.container?(entity)
        entity.respond_to?(:get_attribute) && entity.respond_to?(:entities) && CONTAINER_KINDS.include?(entity.get_attribute(STRUCT_DICTIONARY, 'kind'))
      end

      # Nhóm lưới trục (và các ký hiệu bên trong): chỉ là bản vẽ, không phải món.
      def self.grid?(entity)
        entity.respond_to?(:get_attribute) && entity.get_attribute(STRUCT_DICTIONARY, 'kind') == 'grid'
      end

      # Các trường thêm cho dòng của bảng; {} nếu không phải phần tử của plugin. Số liệu: diện tích m², thể tích m³, chiều dài m.
      def self.row_fields(entity)
        return {} unless element?(entity)
        kind = entity.get_attribute(SOURCE_DICTIONARY, 'kind')
        dims = dims(entity)
        area, volume, length = quantities(kind, dims)
        {struct_kind: kind, struct_ref: entity.get_attribute(SOURCE_DICTIONARY, 'ref').to_s, struct_type: entity.get_attribute(STRUCT_DICTIONARY, 'type').to_s,
         struct_level: entity.get_attribute(STRUCT_DICTIONARY, 'level_name').to_s, struct_level_id: entity.get_attribute(STRUCT_DICTIONARY, 'level').to_s,
         struct_area: area, struct_volume: volume, struct_length: length}
      end

      def self.dims(entity)
        raw = entity.get_attribute(STRUCT_DICTIONARY, 'dims')
        parsed = raw.is_a?(String) && raw.bytesize <= 4096 ? JSON.parse(raw) : nil
        parsed.is_a?(Hash) ? parsed : {}
      rescue JSON::ParserError
        {}
      end

      # [diện tích m², thể tích m³, chiều dài m] theo loại; thiếu hoặc sai số liệu thì nil.
      # Cột: tiết diện x cao; dầm: rộng x cao x dài; tường: diện tích mặt = dài x cao TRỪ lỗ cửa (openings_area), bề dày; cửa: diện tích lỗ = rộng x cao (đếm theo cái);
      # sàn / trần: diện tích mặt bằng, bề dày.
      def self.quantities(kind, dims)
        n = ->(key) { v = dims[key]; v.is_a?(Numeric) && v.to_f.finite? && v.to_f.positive? && v.to_f < MAX_VALUE ? v.to_f : nil }
        case kind
        when 'column', 'footing' # đế móng ghi dims cùng khóa với cột (VGD Structure FootingBuilder)
          w, d, h = n.call('w'), n.call('d'), n.call('height')
          [w && d ? round(w * d / 1.0e6) : nil, w && d && h ? round(w * d * h / 1.0e9) : nil, h ? round(h / 1000.0) : nil]
        when 'beam'
          w, h, l = n.call('w'), n.call('h'), n.call('length')
          [w && l ? round(w * l / 1.0e6) : nil, w && h && l ? round(w * h * l / 1.0e9) : nil, l ? round(l / 1000.0) : nil]
        when 'wall'
          t, h, l = n.call('thickness'), n.call('height'), n.call('length')
          open_area = dims['openings_area'].is_a?(Numeric) && dims['openings_area'].to_f.finite? && dims['openings_area'].to_f >= 0 ? dims['openings_area'].to_f : 0.0 # lỗ cửa: trừ khỏi diện tích và thể tích tường
          gross = h && l ? h * l / 1.0e6 : nil
          net = gross && gross > open_area ? gross - open_area : gross
          [net ? round(net) : nil, t && net ? round(t * net / 1000.0) : nil, l ? round(l / 1000.0) : nil]
        when 'door', 'window'
          w, h = n.call('w'), n.call('h')
          [w && h ? round(w * h / 1.0e6) : nil, nil, w ? round(w / 1000.0) : nil]
        else
          t, a = n.call('thickness'), n.call('area')
          [a ? round(a) : nil, t && a ? round(t * a / 1000.0) : nil, nil]
        end
      end

      def self.round(value)
        value.round(4)
      end

      # Cách tính theo loại cho món chưa có tag cho biết.
      def self.default_method(kind)
        DEFAULT_METHOD[kind]
      end
    end
  end
end
