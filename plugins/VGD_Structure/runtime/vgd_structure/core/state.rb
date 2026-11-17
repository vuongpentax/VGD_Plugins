module VGD
  module Structure
    # Toàn bộ dữ liệu nguồn của plugin (SPEC mục 1): lưới, thiết lập ký hiệu, loại cột, tầng. Kiểm tra gộp một chỗ.
    module State
      def self.default
        {'grid' => Grid.default, 'symbol' => AxisSymbol.options!(nil), 'types' => ColumnTypes.default, 'beam_types' => BeamTypes.default, 'wall_types' => WallTypes.default, 'opening_types' => OpeningTypes.default, 'levels' => Levels.default}
      end

      # raw: dữ liệu chưa kiểm tra (từ giao diện hoặc từ model). Thiếu loại cột / tầng (dữ liệu cột mốc 1) thì dùng mặc định.
      # Trả về trạng thái sạch kèm 'removed' (số lựa chọn cột bị bỏ vì giao điểm không còn trên lưới). Sai thì raise (Grid::Error, AxisSymbol::Error,
      # ColumnTypes::Error hoặc Levels::Error, đều là ArgumentError).
      def self.normalize!(raw)
        raise Grid::Error, 'Dữ liệu không hợp lệ.' unless raw.is_a?(Hash)
        grid = Grid.normalize!(raw['grid'])
        symbol = AxisSymbol.options!(raw['symbol'])
        types = raw['types'].nil? ? ColumnTypes.default : ColumnTypes.normalize!(raw['types'])
        beam_types = raw['beam_types'].nil? ? BeamTypes.default : BeamTypes.normalize!(raw['beam_types'])
        wall_types = raw['wall_types'].nil? ? WallTypes.default : WallTypes.normalize!(raw['wall_types'])
        opening_types = raw['opening_types'].nil? ? OpeningTypes.default : OpeningTypes.normalize!(raw['opening_types'])
        levels, removed = Levels.normalize!(raw['levels'].nil? ? Levels.default : raw['levels'], grid, types, beam_types, wall_types, opening_types)
        {'grid' => grid, 'symbol' => symbol, 'types' => types, 'beam_types' => beam_types, 'wall_types' => wall_types, 'opening_types' => opening_types, 'levels' => levels, 'removed' => removed}
      end
    end
  end
end
