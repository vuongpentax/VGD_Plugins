require 'json'
require 'digest'

module VGD
  module Structure
    # Đồng bộ giữa dữ liệu của cửa sổ và model SketchUp (cột mốc P6): dấu vân tay của từng phần tử đã dựng, so khớp dữ liệu với model
    # (đã dựng đúng / lệch / thiếu / chưa dựng / thừa), đọc phần tử đang chọn trong SketchUp, chọn phần tử trong SketchUp theo dữ liệu.
    module ModelSync
      # Trường quyết định hình dạng của từng loại phần tử: đổi một trường thì phần tử trong model không còn khớp dữ liệu.
      FP_FIELDS = {
        'column' => %i[center w d z0 z1 type_id], 'beam' => %i[dir min max z_top z_bottom type_id], 'wall' => %i[dir min max z_bottom z_top type_id openings],
        'opening' => %i[kind min max z_bottom z_top type_id flip], 'slab' => %i[min max thickness z_top z_bottom], 'ceiling' => %i[polygon min max thickness z_bottom z_top],
        'stair' => %i[polygon z0 z1 type rails],
        'footing' => %i[center w d h z0],
        'roof' => %i[top tv],
        'purlin' => %i[start finish w h]
      }.freeze
      # Trường chỉ tính khi mục kế hoạch có (phần tử xiên / xoay, P4b-2): mục cũ không có thì vân tay giữ nguyên như bản trước.
      FP_OPTIONAL = %i[a b rot origin angle polygon holes layers mirror].freeze
      # Loại nhóm trong model <-> kế hoạch (Checker.plan_for) <-> loại trong giao diện (cột, dầm, tường, cửa gộp thành 'opening', sàn, trần).
      PLAN_KINDS = {'columns' => 'column', 'beams' => 'beam', 'walls' => 'wall', 'openings' => 'opening', 'slabs' => 'slab', 'ceilings' => 'ceiling'}.freeze
      UI_KIND = {'column' => 'column', 'beam' => 'beam', 'wall' => 'wall', 'door' => 'opening', 'window' => 'opening', 'slab' => 'slab', 'ceiling' => 'ceiling'}.freeze
      BIM_KINDS = {'column' => %w[column], 'beam' => %w[beam], 'wall' => %w[wall], 'opening' => %w[door window], 'slab' => %w[slab], 'ceiling' => %w[ceiling]}.freeze
      INCH_TO_MM = 25.4

      # Dấu vân tay (12 ký tự 16) của một mục kế hoạch; builder ghi vào từng phần tử dựng ra (VGD_STRUCT.fp), so khớp dữ liệu hiện tại với model.
      def self.fingerprint(kind, item)
        fields = (FP_FIELDS.fetch(kind) + FP_OPTIONAL.select { |key| item.key?(key) }).uniq.map { |key| [key, normalize(item[key])] }
        Digest::SHA1.hexdigest(JSON.generate(fields))[0, 12]
      end

      def self.normalize(value)
        case value
        when Float then value.round(1)
        when Array then value.map { |v| normalize(v) }
        when Hash then value.sort_by { |k, _| k.to_s }.map { |k, v| [k.to_s, normalize(v)] }
        else value
        end
      end

      # Các phần tử do plugin dựng trong model: {[loại giao diện, mã tầng, mã]=> entity}. Cũng trả về các nhóm đã dựng: {[loại kế hoạch, mã tầng] => group}.
      def self.scan(model)
        elements = {}
        groups = {}
        model.entities.grep(Sketchup::Group).each do |g|
          next unless g.valid?
          kind = g.get_attribute(Schema::DICTIONARY, 'kind')
          next unless PLAN_KINDS.key?(kind)
          level = g.get_attribute(Schema::DICTIONARY, 'level')
          groups[[kind, level]] = g
          g.entities.to_a.each do |e|
            next unless e.respond_to?(:get_attribute) && !e.is_a?(Sketchup::Group)
            next unless e.get_attribute('VGD_BIM_SOURCE', 'plugin') == Schema::PLUGIN_ID
            ui = UI_KIND[e.get_attribute('VGD_BIM_SOURCE', 'kind').to_s] or next
            level_id, ref = e.get_attribute('VGD_BIM_SOURCE', 'ref').to_s.split(':', 2)
            elements[[ui, level_id, ref]] = e
          end
        end
        [elements, groups]
      end

      # So khớp dữ liệu (đã chuẩn hóa) của một tầng với model. Trả về {level:, items: {"loại|mã" => 'ok' | 'stale' | 'missing' | 'unbuilt'}, extras: [{kind, ref}], counts: {...}}.
      # unbuilt: loại phần tử này chưa dựng ở tầng; missing: đã dựng nhưng thiếu phần tử này; stale: có nhưng khác dữ liệu hiện tại; extra: còn trong model nhưng dữ liệu không còn.
      def self.status(model, state, level_id)
        elements, groups = scan(model)
        items = {}
        counts = Hash.new(0)
        PLAN_KINDS.each do |plan_kind, ui|
          plan = begin
            Checker.plan_for(plan_kind, state, level_id)
          rescue ArgumentError
            next # kế hoạch lỗi (hoặc tầng không có loại này): không đánh giá
          end
          built = groups.key?([plan_kind, level_id])
          wanted = plan[:items].each_with_object({}) { |item, h| h[item[:ref]] = item }
          wanted.each do |ref, item|
            fp = fingerprint(ui, item)
            entity = elements[[ui, level_id, ref]]
            state_of = if !built then 'unbuilt' elsif entity.nil? then 'missing' elsif entity.get_attribute(Schema::DICTIONARY, 'fp') == fp then 'ok' else 'stale' end
            items["#{ui}|#{ref}"] = state_of
            counts[state_of] += 1
          end
        end
        extras = elements.keys.select { |ui, lv, ref| lv == level_id && !items.key?("#{ui}|#{ref}") && planned_kind?(state, ui, level_id) }.map { |ui, _lv, ref| {kind: ui, ref: ref} }
        counts['extra'] = extras.size
        {level: level_id, items: items, extras: extras, counts: %w[ok stale missing unbuilt extra].each_with_object({}) { |k, h| h[k] = counts[k] }}
      end

      # Loại này có kế hoạch hợp lệ ở tầng không (để không gọi phần tử là "thừa" khi kế hoạch đang lỗi).
      def self.planned_kind?(state, ui, level_id)
        plan_kind = PLAN_KINDS.key(ui)
        Checker.plan_for(plan_kind, state, level_id)
        true
      rescue ArgumentError
        false
      end

      # Phần tử đang được chọn trong SketchUp thuộc plugin: {items: [{level, kind, ref}], groups: [{level, kind}]}. groups: nhóm (cột, dầm...) được chọn nguyên.
      def self.selection_items(model)
        items = []
        groups = []
        model.selection.each do |e|
          next unless e.respond_to?(:get_attribute)
          if e.is_a?(Sketchup::Group)
            kind = e.get_attribute(Schema::DICTIONARY, 'kind')
            level = e.get_attribute(Schema::DICTIONARY, 'level')
            groups << {level: level, kind: PLAN_KINDS[kind]} if PLAN_KINDS.key?(kind) && level
            next
          end
          next unless e.get_attribute('VGD_BIM_SOURCE', 'plugin') == Schema::PLUGIN_ID
          ui = UI_KIND[e.get_attribute('VGD_BIM_SOURCE', 'kind').to_s] or next
          level_id, ref = e.get_attribute('VGD_BIM_SOURCE', 'ref').to_s.split(':', 2)
          items << {level: level_id, kind: ui, ref: ref} if level_id && ref
        end
        {items: items, groups: groups}
      end

      # Chọn trong SketchUp các phần tử theo dữ liệu {level, items: [{kind, ref}]}. Cùng một nhóm: mở nhóm đó (active_path) rồi chọn từng phần tử;
      # nhiều nhóm hoặc không mở được nhóm: chọn nguyên các nhóm. Trả về {found:, missing: [...], mode: 'elements' | 'groups' | 'none'}.
      def self.select(model, level_id, items)
        elements, groups = scan(model)
        found = []
        missing = []
        items.each do |it|
          e = elements[[it['kind'] || it[:kind], level_id, it['ref'] || it[:ref]]]
          e ? found << e : missing << {kind: it['kind'] || it[:kind], ref: it['ref'] || it[:ref]}
        end
        model.selection.clear
        return {found: 0, missing: missing, mode: 'none'} if found.empty?
        owners = found.map { |e| groups.values.find { |g| g.entities.to_a.include?(e) } }.uniq
        if owners.size == 1 && owners.first && model.respond_to?(:active_path=)
          begin
            model.active_path = [owners.first]
            found.each { |e| model.selection.add(e) }
            return {found: found.size, missing: missing, mode: 'elements'}
          rescue StandardError
            model.selection.clear
          end
        end
        owners.compact.each { |g| model.selection.add(g) }
        {found: found.size, missing: missing, mode: 'groups'}
      end

      def self.to_mm(length)
        length.to_f * INCH_TO_MM
      end
    end
  end
end
