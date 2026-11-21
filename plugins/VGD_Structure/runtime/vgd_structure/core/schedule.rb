module VGD
  module Structure
    # Bảng thống kê (Schedule như Revit): gom phần tử theo tầng và loại, tính số lượng, kích thước, chiều dài, diện tích, thể tích. Logic thuần: dùng đúng các kế hoạch
    # (`Checker.plan_for`) mà bbản dựng dùng nên số khớp hình dựng; không đụng model. Kế hoạch lỗi thì phần đó rỗng kèm lời báo.
    #   Schedule.build(state) => {sections: [{kind:, label:, columns: [{id:, label:, unit:, sum: bool}], rows: [{level:, level_name:, type:, count:, values: {...}}], total: {...}}], issues: []}
    module Schedule
      KINDS = %w[columns beams walls openings slabs ceilings].freeze
      LABELS = Checker::KIND_LABELS

      COLUMNS = {
        'columns' => [['size', 'Tiết diện (mm)', '', false], ['height', 'Cao (mm)', '', false], ['volume', 'Thể tích', 'm³', true]],
        'beams' => [['size', 'Tiết diện (mm)', '', false], ['length', 'Tổng dài', 'm', true], ['volume', 'Thể tích', 'm³', true]],
        'walls' => [['thickness', 'Dày (mm)', '', false], ['length', 'Tổng dài', 'm', true], ['area', 'Diện tích (trừ cửa)', 'm²', true], ['volume', 'Thể tích', 'm³', true]],
        'openings' => [['kind', 'Loại cửa', '', false], ['size', 'Rộng × cao (mm)', '', false], ['area', 'Diện tích', 'm²', true]],
        'slabs' => [['thickness', 'Dày (mm)', '', false], ['area', 'Diện tích', 'm²', true], ['volume', 'Thể tích (kết cấu)', 'm³', true]],
        'ceilings' => [['thickness', 'Dày (mm)', '', false], ['area', 'Diện tích', 'm²', true], ['volume', 'Thể tích', 'm³', true]]
      }.freeze

      def self.build(state)
        issues = []
        sections = KINDS.map do |kind|
          groups = {}
          state['levels'].each do |level|
            next if level['picks'][kind].empty?
            plan = begin
              Checker.plan_for(kind, state, level['id'])
            rescue ArgumentError => error
              issues << "#{LABELS[kind]} #{level['name']}: #{error.message}"
              next
            end
            plan[:items].each do |item|
              key, type, cells = describe(kind, item, plan)
              group = groups[[level['id'], key]] ||= {level: level['id'], level_name: level['name'], type: type, count: 0, values: Hash.new(0.0), fixed: cells}
              group[:count] += 1
              measures(kind, item, plan).each { |name, v| group[:values][name] += v }
            end
          end
          rows = groups.values.map { |g| {level: g[:level], level_name: g[:level_name], type: g[:type], count: g[:count], values: g[:fixed].merge(g[:values].transform_values { |v| v.round(3) })} }
          cols = COLUMNS[kind].map { |id, label, unit, sum| {id: id, label: label, unit: unit, sum: sum} }
          total = {count: rows.sum { |r| r[:count] }}
          cols.select { |c| c[:sum] }.each { |c| total[c[:id]] = rows.sum { |r| r[:values][c[:id]].to_f }.round(3) }
          {kind: kind, label: LABELS[kind], columns: cols, rows: rows, total: total}
        end
        {sections: sections, issues: issues}
      end

      # [khóa gom nhóm, tên loại, các ô cố định (không cộng dồn)].
      def self.describe(kind, item, plan)
        case kind
        when 'columns' then ["#{item[:type_id]}|#{item[:w]}|#{item[:d]}|#{item[:height]}", item[:type_name], {'size' => "#{fmt(item[:w])} × #{fmt(item[:d])}", 'height' => fmt(item[:height])}]
        when 'beams' then ["#{item[:type_id]}|#{item[:w]}|#{item[:h]}", item[:type_name], {'size' => "#{fmt(item[:w])} × #{fmt(item[:h])}"}]
        when 'walls' then ["#{item[:type_id]}|#{item[:t]}", item[:type_name], {'thickness' => fmt(item[:t])}]
        when 'openings' then ["#{item[:type_id]}", item[:type_name], {'kind' => item[:kind] == 'door' ? 'Cửa đi' : 'Cửa sổ', 'size' => "#{fmt(item[:w])} × #{fmt(item[:h])}"}]
        when 'slabs' then ["#{item[:thickness]}", 'Sàn', {'thickness' => fmt(item[:thickness])}]
        else ["#{item[:thickness]}", 'Trần', {'thickness' => fmt(item[:thickness])}]
        end
      end

      # Số đo cộng dồn của một phần tử.
      def self.measures(kind, item, plan)
        case kind
        when 'columns'
          area = item[:poly] ? Geometry.area(item[:poly]) : item[:w] * item[:d]
          {'volume' => area * item[:height] / 1e9}
        when 'beams'
          {'length' => item[:length] / 1000.0, 'volume' => item[:w] * item[:h] * item[:length] / 1e9}
        when 'walls'
          area = [item[:length] * item[:height] / 1e6 - item[:openings_area].to_f, 0.0].max
          {'length' => item[:length] / 1000.0, 'area' => area, 'volume' => area * item[:t] / 1000.0}
        when 'openings'
          {'area' => item[:w] * item[:h] / 1e6}
        when 'slabs', 'ceilings'
          {'area' => item[:area].to_f, 'volume' => item[:area].to_f * item[:thickness] / 1000.0}
        end
      end

      def self.fmt(value)
        value == value.round ? value.round.to_s : value.to_s
      end
    end
  end
end
