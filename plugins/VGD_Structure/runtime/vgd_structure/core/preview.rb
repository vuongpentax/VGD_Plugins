module VGD
  module Structure
    # Dữ liệu xem trước cho giao diện: kế hoạch ký hiệu trục, tóm tắt lưới, và (nếu có) loại cột, tầng, cột của tầng đang xem.
    # Giao diện chỉ vẽ lại kết quả này; mọi kiểm tra và tính toán ở Ruby (một nguồn). Logic thuần.
    module Preview
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
        return {} unless payload.key?('levels') || payload.key?('types')
        types = payload['types'].nil? ? ColumnTypes.default : ColumnTypes.normalize!(payload['types'])
        levels, removed = Levels.normalize!(payload['levels'].nil? ? Levels.default : payload['levels'], grid, types)
        out = {levels_ok: true, removed: removed}
        begin
          plan = ColumnPlan.plan(grid, types, levels, payload['level'] || levels.first['id'])
          out[:columns] = {level: plan[:level]['id'], level_name: plan[:level]['name'], height: plan[:height], z0: plan[:z0], z1: plan[:z1], issues: plan[:issues], count: plan[:items].size,
                           items: plan[:items].map { |i| i.slice(:ref, :center, :w, :d, :type_name, :modes, :placement) }}
        rescue ColumnPlan::Error => error
          out[:columns_error] = error.message
        end
        out
      rescue ColumnTypes::Error, Levels::Error => error
        {levels_ok: false, levels_error: error.message}
      end
    end
  end
end
