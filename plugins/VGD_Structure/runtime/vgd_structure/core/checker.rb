module VGD
  module Structure
    # Kiểm tra kết cấu (trước khi dựng): gom lỗi và cảnh báo của mọi kế hoạch của từng tầng và thêm các kiểm tra chung: dầm có đầu không gối lên cột,
    # tầng thiếu dữ liệu. Chỉ ĐỌC dữ liệu, không đổi gì. Logic thuần.
    module Checker
      KIND_LABELS = {'columns' => 'Cột', 'beams' => 'Dầm', 'walls' => 'Tường', 'openings' => 'Cửa', 'slabs' => 'Sàn', 'ceilings' => 'Trần'}.freeze

      # state đã chuẩn hóa. Trả về {levels: [{id, name, top, counts: {loại => số}, errors: [...], warnings: [...]}], errors: số, warnings: số}.
      def self.run(state)
        grid = state['grid']
        spans = Grid.spans(grid).each_with_object({}) { |s, h| h[s[:ref]] = s }
        rows = state['levels'].each_with_index.map do |level, i|
          top = i == state['levels'].size - 1
          row = {id: level['id'], name: level['name'], top: top, counts: KIND_LABELS.keys.each_with_object({}) { |k, h| h[k] = level['picks'][k].size }, errors: [], warnings: []}
          plan = lambda do |kind, label|
            plan_for(kind, state, level['id'])
          rescue ArgumentError => error
            row[:errors] << "#{label}: #{error.message}"
            nil
          end
          if top
            row[:warnings].concat(level['picks'].select { |k, v| k != 'slabs' && !v.empty? }.map { |k, v| "Tầng trên cùng chỉ có sàn: #{v.size} #{KIND_LABELS[k].downcase} đã chọn sẽ bị bỏ qua." })
            slab = plan.call('slabs', 'Sàn')
            row[:warnings].concat(slab[:issues].map { |m| "Sàn: #{m}" }) if slab
            next row
          end
          if level['picks'].values.all?(&:empty?)
            row[:warnings] << 'Tầng chưa chọn cột, dầm, tường, sàn hay trần nào.'
            next row
          end
          columns = plan.call('columns', 'Cột')
          beams = plan.call('beams', 'Dầm')
          walls = plan.call('walls', 'Tường')
          openings = plan.call('openings', 'Cửa')
          slabs = plan.call('slabs', 'Sàn')
          ceilings = plan.call('ceilings', 'Trần')
          { 'Cột' => columns, 'Dầm' => beams, 'Tường' => walls, 'Cửa' => openings, 'Sàn' => slabs, 'Trần' => ceilings }.each { |label, p| row[:warnings].concat(p[:issues].map { |m| "#{label}: #{m}" }) if p }
          if beams
            column_refs = level['picks']['columns']
            beams[:items].each do |b|
              span = spans[b[:ref]]
              missing = [span[:from_ref], span[:to_ref]].reject { |node| column_refs.key?(node) }
              row[:warnings] << "Dầm #{b[:ref]}: đầu dầm tại #{missing.join(', ')} không có cột để gối." unless missing.empty?
            end
          end
          row
        end
        {levels: rows, errors: rows.sum { |r| r[:errors].size }, warnings: rows.sum { |r| r[:warnings].size }}
      end

      def self.plan_for(kind, state, level_id)
        case kind
        when 'columns' then ColumnPlan.plan(state['grid'], state['types'], state['levels'], level_id)
        when 'beams' then BeamPlan.plan(state['grid'], state['types'], state['beam_types'], state['levels'], level_id)
        when 'walls' then WallPlan.plan(state['grid'], state['types'], state['beam_types'], state['wall_types'], state['levels'], level_id, state['opening_types'])
        when 'openings' then OpeningPlan.plan(state['grid'], state['types'], state['beam_types'], state['wall_types'], state['opening_types'], state['levels'], level_id)
        when 'slabs' then SlabPlan.plan(state['grid'], state['levels'], level_id, state['types'], state['beam_types'])
        else CeilingPlan.plan(state['grid'], state['types'], state['beam_types'], state['wall_types'], state['levels'], level_id, state['opening_types'])
        end
      end
    end
  end
end
