module VGD
  # VGD Position: dời món (group / component) tới tọa độ X, Y, Z (mm) của điểm gốc món đầu tiên trong lựa chọn.
  # Phần này là logic thuần (không gọi SketchUp): đọc ô nhập, tính độ dời, chặn món khóa. Phần gọi SketchUp ở core/move.rb.
  module Position
    MM_PER_INCH = 25.4          # SketchUp tính nội bộ bằng inch
    LIMIT_MM = 1_000_000.0      # tọa độ ngoài ±1 km (mm) là nhập nhầm
    TOLERANCE_MM = 0.05         # lệch dưới 0,05 mm coi là đã đúng vị trí
    NUMBER = /\A[+-]?(\d+\.?\d*|\.\d+)\z/.freeze
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

    # items: [{index:, name:, origin: [x, y, z] mm hoặc nil, locked: true/false}], theo thứ tự chọn.
    # values: {'x' => '...', 'y' => '...', 'z' => '...'}; trục trống thì giữ nguyên.
    # Cả nhóm dời cùng một độ lệch, tính từ điểm gốc của món đầu tiên: độ lệch = tọa độ nhập - điểm gốc món đầu.
    # Một món thì đó chính là món đó. Có món khóa hoặc không đo được vị trí thì không dời gì (để nhóm không lệch nhau).
    # Trả về {moves: [{index:, delta: [dx, dy, dz] mm}]}.
    def plan(items, values)
      raise ArgumentError, 'Chưa chọn món nào.' if items.empty?
      typed = AXES.map { |axis| parse_mm(values[axis]) }
      raise ArgumentError, 'Hãy nhập ít nhất một tọa độ (X, Y hoặc Z).' if typed.all?(&:nil?)
      items.each do |item|
        raise ArgumentError, "#{item[:name]} đang khóa. Bỏ khóa hoặc bỏ chọn món đó rồi thử lại." if item[:locked]
        raise ArgumentError, "Không đo được vị trí của #{item[:name]}." if item[:origin].nil?
      end
      anchor = items.first[:origin]
      delta = typed.each_with_index.map { |value, i| value.nil? ? 0.0 : value - anchor[i] }
      raise ArgumentError, 'Món đầu tiên đã ở vị trí đó, không cần dời.' if delta.all? { |d| d.abs < TOLERANCE_MM }
      {moves: items.map { |item| {index: item[:index], delta: delta} }}
    end
  end
end
