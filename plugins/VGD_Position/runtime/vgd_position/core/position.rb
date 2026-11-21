module VGD
  # VGD Position: dời món (group / component) tới tọa độ X, Y, Z (mm) hoặc dời tương đối.
  # Phần này là logic thuần (không gọi SketchUp): đọc ô nhập, tính độ dời, bỏ món khóa. Phần gọi SketchUp ở core/move.rb.
  module Position
    MM_PER_INCH = 25.4          # SketchUp tính nội bộ bằng inch
    LIMIT_MM = 1_000_000.0      # tọa độ ngoài ±1 km (mm) là nhập nhầm
    TOLERANCE_MM = 0.05         # lệch dưới 0,05 mm coi là đã đúng vị trí
    NUMBER = /\A[+-]?(\d+\.?\d*|\.\d+)\z/.freeze
    MODES = %w[absolute relative].freeze
    AXES = %w[x y z].freeze

    module_function

    # Ô nhập (mm). Trống hoặc nil: nil (nghĩa là không nhập trục đó). Sai định dạng hoặc vượt giới hạn thì báo lỗi.
    def parse_mm(text)
      return nil if text.nil?
      raw = text.to_s.strip.tr(',', '.')
      return nil if raw.empty?
      raise ArgumentError, "Tọa độ \"#{text}\" không phải số." unless raw.match?(NUMBER)
      value = Float(raw)
      raise ArgumentError, "Tọa độ vượt giới hạn ±#{LIMIT_MM.to_i} mm." if value.abs > LIMIT_MM
      value
    end

    # items: [{index:, name:, origin: [x, y, z] mm hoặc nil, locked: true/false}]
    # mode: 'absolute' (đặt điểm gốc tới X, Y, Z; trục để trống thì giữ nguyên; chỉ một món) hoặc 'relative' (dời ΔX, ΔY, ΔZ; trống là 0).
    # values: {'x' => '...', 'y' => '...', 'z' => '...'}.
    # Trả về {moves: [{index:, delta: [dx, dy, dz] mm}], skipped: [{index:, name:, reason:}]}.
    def plan(items, mode, values)
      raise ArgumentError, 'Chế độ dời không hợp lệ.' unless MODES.include?(mode)
      raise ArgumentError, 'Chưa chọn món nào.' if items.empty?
      typed = AXES.map { |axis| parse_mm(values[axis]) }
      raise ArgumentError, 'Hãy nhập ít nhất một tọa độ (X, Y hoặc Z).' if typed.all?(&:nil?)
      if mode == 'absolute' && items.size > 1
        raise ArgumentError, 'Chế độ đặt tọa độ chỉ dùng khi chọn đúng một món. Chọn một món, hoặc dùng chế độ dời tương đối.'
      end
      moves = []
      skipped = []
      items.each do |item|
        next skipped << skip(item, 'đang khóa') if item[:locked]
        origin = item[:origin]
        next skipped << skip(item, 'không đo được vị trí') if origin.nil?
        delta = if mode == 'absolute'
                  typed.each_with_index.map { |value, i| value.nil? ? 0.0 : value - origin[i] }
                else
                  typed.map { |value| value || 0.0 }
                end
        next skipped << skip(item, 'đã ở vị trí đó') if delta.all? { |d| d.abs < TOLERANCE_MM }
        moves << {index: item[:index], delta: delta}
      end
      raise ArgumentError, 'Không có món nào cần dời (đã ở vị trí đó, hoặc bị khóa / không đo được vị trí).' if moves.empty?
      {moves: moves, skipped: skipped}
    end

    def skip(item, reason)
      {index: item[:index], name: item[:name], reason: reason}
    end
  end
end
