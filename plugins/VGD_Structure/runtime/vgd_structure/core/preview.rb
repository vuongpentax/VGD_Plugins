module VGD
  module Structure
    # Dữ liệu xem trước cho giao diện: kế hoạch ký hiệu trục, tóm tắt lưới, và (nếu có) loại cột, tầng, cột của tầng đang xem.
    # Giao diện chỉ vẽ lại kết quả này; mọi kiểm tra và tính toán ở Ruby (một nguồn). Logic thuần.
    module Preview
      # Hình sàn / trần THỰC TẾ nếu thêm ô `ref` vào lựa chọn của tầng (lùi theo dầm, cột, tường như lúc dựng), để xem trước đúng hình sẽ dựng.
      # payload: {'state' => dữ liệu giao diện, 'level' =>, 'kind' => 'slabs' | 'ceilings', 'ref' =>}. Trả về {kind:, level:, ref:, polygon:, holes:} hoặc nil nếu ô không dựng được.
      def self.probe(payload)
        kind = payload['kind']
        ref = payload['ref']
        level_id = payload['level']
        raise ArgumentError, 'Dữ liệu xem trước ô không hợp lệ.' unless %w[slabs ceilings].include?(kind) && ref.is_a?(String) && level_id.is_a?(String) && payload['state'].is_a?(Hash)
        raw = JSON.parse(payload['state'].to_json)
        level = (raw['levels'] || []).find { |l| l['id'] == level_id }
        return nil unless level && level['picks'].is_a?(Hash)
        level['picks'][kind] = {} unless level['picks'][kind].is_a?(Hash)
        level['picks'][kind][ref] ||= {}
        state = State.normalize!(raw)
        item = Checker.plan_for(kind, state, level_id)[:items].find { |i| i[:ref] == ref }
        item && {kind: kind, level: level_id, ref: ref, polygon: item[:polygon], holes: item[:holes]}
      rescue ArgumentError, KeyError
        nil
      end

      def self.build(payload)
        grid = Grid.normalize!(payload['grid'])
        options = AxisSymbol.options!(payload['symbol'])
        {ok: true, summary: summary(grid), bounds: Grid.bounds(grid), axes: AxisSymbol.plan(grid, options)}.merge(columns(grid, payload))
      rescue Grid::Error, AxisSymbol::Error => error
        {ok: false, error: error.message}
      end

      def self.summary(grid)
        x0, y0, x1, y1 = Grid.bounds(grid)
        {x_axes: grid['x_axes'].size, y_axes: grid['y_axes'].size, intersections: Grid.intersections(grid).size, spans: Grid.spans(grid).size,
         cells: Grid.cells(grid).size, width: (x1 - x0).round(1), depth: (y1 - y0).round(1)}
      end

      # Phần xem trước loại cột, tầng và cột của tầng đang xem. Lỗi dữ liệu tầng / loại cột báo riêng, không chặn xem trước lưới.
      def self.columns(grid, payload)
        return {} unless payload.key?('levels') || payload.key?('types') || payload.key?('beam_types') || payload.key?('wall_types') || payload.key?('opening_types') || payload.key?('stair_types')
        types = payload['types'].nil? ? ColumnTypes.default : ColumnTypes.normalize!(payload['types'])
        beam_types = payload['beam_types'].nil? ? BeamTypes.default : BeamTypes.normalize!(payload['beam_types'])
        wall_types = payload['wall_types'].nil? ? WallTypes.default : WallTypes.normalize!(payload['wall_types'])
        opening_types = payload['opening_types'].nil? ? OpeningTypes.default : OpeningTypes.normalize!(payload['opening_types'])
        stair_types = payload['stair_types'].nil? ? StairTypes.default : StairTypes.normalize!(payload['stair_types'])
        levels, removed = Levels.normalize!(payload['levels'].nil? ? Levels.default : payload['levels'], grid, types, beam_types, wall_types, opening_types, stair_types)
        out = {levels_ok: true, removed: removed}
        begin
          plan = ColumnPlan.plan(grid, types, levels, payload['level'] || levels.first['id'])
          out[:columns] = {level: plan[:level]['id'], level_name: plan[:level]['name'], height: plan[:height], z0: plan[:z0], z1: plan[:z1], issues: plan[:issues], count: plan[:items].size,
                           items: plan[:items].map { |i| i.slice(:ref, :center, :w, :d, :type_name, :modes, :placement, :rot, :poly) }}
        rescue ColumnPlan::Error => error
          out[:columns_error] = error.message
        end
        begin
          plan = BeamPlan.plan(grid, types, beam_types, levels, payload['level'] || levels.first['id'])
          out[:beams] = {level: plan[:level]['id'], level_name: plan[:level]['name'], z_top: plan[:z_top], issues: plan[:issues], count: plan[:items].size,
                         items: plan[:items].map { |i| i.slice(:ref, :dir, :type_name, :w, :h, :length, :min, :max, :mode, :placement, :z_top, :z_bottom, :a, :b, :angle, :poly) }}
        rescue BeamPlan::Error, ColumnPlan::Error => error
          out[:beams_error] = error.message
        end
        begin
          plan = WallPlan.plan(grid, types, beam_types, wall_types, levels, payload['level'] || levels.first['id'], opening_types)
          out[:walls] = {level: plan[:level]['id'], level_name: plan[:level]['name'], z0: plan[:z0], z_slab: plan[:z_slab], issues: plan[:issues], count: plan[:items].size,
                         items: plan[:items].map { |i| i.slice(:ref, :dir, :type_name, :t, :layers, :length, :height, :min, :max, :mode, :placement, :z_bottom, :z_top, :under_beam, :start, :finish, :center, :openings, :openings_area, :a, :b, :angle, :poly, :join, :join_shift, :join_shift_end, :joined) }}
        rescue WallPlan::Error, BeamPlan::Error, ColumnPlan::Error => error
          out[:walls_error] = error.message
        end
        level_id = payload['level'] || levels.first['id']
        begin
          op = OpeningPlan.plan(grid, types, beam_types, wall_types, opening_types, levels, payload['level'] || levels.first['id'])
          out[:openings] = {level: op[:level]['id'], level_name: op[:level]['name'], count: op[:items].size, issues: op[:issues],
                            items: op[:items].map { |i| i.slice(:ref, :wall, :dir, :kind, :type_name, :w, :h, :sill, :pos, :flip, :mirror, :min, :max, :z_bottom, :z_top, :origin, :angle, :poly) }}
        rescue OpeningPlan::Error, WallPlan::Error, BeamPlan::Error, ColumnPlan::Error => error
          out[:openings_error] = error.message
        end
        begin
          stairs = StairPlace.plan(grid, types, beam_types, wall_types, stair_types, levels, payload['level'] || levels.first['id'], opening_types)
          out[:stairs] = {level: stairs[:level]['id'], level_name: stairs[:level]['name'], count: stairs[:items].size, issues: stairs[:issues],
                          items: stairs[:items].map { |i| i.slice(:ref, :type, :type_name, :a, :b, :polygon, :min, :max, :z0, :z1, :placement, :conflicts).merge(steps: i[:plan][:steps], rails: i[:plan][:rails], count: i[:plan][:count], riser: i[:plan][:riser], tread: i[:plan][:tread]) }}
        rescue StairPlace::Error, StairPlan::Error, WallPlan::Error, BeamPlan::Error, ColumnPlan::Error => error
          out[:stairs_error] = error.message
        end
        begin
          slab = SlabPlan.plan(grid, levels, level_id, types, beam_types, wall_types, opening_types)
          out[:slabs] = {level: slab[:level]['id'], level_name: slab[:level]['name'], z_top: slab[:z_top], thickness: slab[:thickness], count: slab[:items].size, issues: slab[:issues],
                         items: slab[:items].map { |i| i.slice(:ref, :min, :max, :thickness, :z_top, :z_bottom, :area, :polygon, :holes, :placement, :layers) }}
        rescue SlabPlan::Error => error
          out[:slabs_error] = error.message
        end
        begin
          plan = CeilingPlan.plan(grid, types, beam_types, wall_types, levels, level_id, opening_types)
          out[:ceilings] = {level: plan[:level]['id'], level_name: plan[:level]['name'], z_bottom: plan[:z_bottom], z_top: plan[:z_top], count: plan[:items].size, issues: plan[:issues],
                            items: plan[:items].map { |i| i.slice(:ref, :polygon, :min, :max, :thickness, :z_bottom, :z_top, :area, :holes, :placement, :layers) }}
        rescue CeilingPlan::Error, WallPlan::Error, BeamPlan::Error, ColumnPlan::Error => error
          out[:ceilings_error] = error.message
        end
        out
      rescue ColumnTypes::Error, BeamTypes::Error, WallTypes::Error, OpeningTypes::Error, StairTypes::Error, Levels::Error => error
        {levels_ok: false, levels_error: error.message}
      end
    end
  end
end
