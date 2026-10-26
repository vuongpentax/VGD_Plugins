# Bố cục cánh theo "vùng". KHÔNG gọi SketchUp API nên test được ngoài SketchUp.
# Mặt trước thân tủ là hình vuông đơn vị: u chạy trái -> phải (0..1), v chạy dưới -> trên (0..1).
# Mọi vùng là hình chữ nhật, ghép lại đúng bằng hình vuông đơn vị (không hở, không chồng).
#   axis 'vertical'   = đường chia thẳng đứng  -> các vùng xếp CẠNH nhau (chia theo u)
#   axis 'horizontal' = đường chia nằm ngang   -> các vùng xếp CHỒNG lên nhau (chia theo v)
# Mỗi vùng: { 'id', 'u0', 'u1', 'v0', 'v1', 'opening_type' }.
module VGD_Cabinet_Draw
  module DoorLayout
    SCHEMA = 2
    EPS = 1e-9
    MIN_CELL_MM = 20.0 # vùng nhỏ nhất cho phép (mm)
    SNAP_MM = 6.0      # hút vào đường chia sẵn có khi gần hơn khoảng này
    OPENING_TYPES = %w[none left right top bottom drawer].freeze
    HINGED_TYPES = %w[left right top bottom].freeze

    def self.opening_type(value)
      OPENING_TYPES.include?(value.to_s) ? value.to_s : 'none'
    end

    class Layout
      attr_reader :regions, :width_mm, :height_mm

      def initialize(width_mm = 1000.0, height_mm = 1000.0)
        @width_mm = width_mm.to_f
        @height_mm = height_mm.to_f
        @next_id = 1
        @regions = [new_region(0.0, 1.0, 0.0, 1.0)]
        @history = []
        @batch = false
      end

      def initialize_copy(source)
        super
        @regions = source.regions.map(&:dup)
        @history = []
        @batch = false
      end

      # Đọc từ dữ liệu đã lưu. Schema 1 (danh sách đường chia theo một trục) được đổi sang vùng.
      def self.from_h(data, width_mm = 1000.0, height_mm = 1000.0)
        layout = new(width_mm, height_mm)
        return layout unless data.is_a?(Hash) && data['regions'].is_a?(Array) && !data['regions'].empty?
        list = data['regions']
        if data['schema'].to_i >= 2
          regions = list.map do |item|
            region = { 'id' => item['id'].to_i, 'u0' => item['u0'].to_f, 'u1' => item['u1'].to_f, 'v0' => item['v0'].to_f, 'v1' => item['v1'].to_f,
                       'opening_type' => DoorLayout.opening_type(item['opening_type']) }
            # Vùng trống: vẫn là một ô của bố cục nhưng không có cánh (đã xóa cánh, không gộp vào cánh bên cạnh).
            region['empty'] = true if item['empty']
            region
          end
        else
          regions = list.each_with_index.map do |item, index|
            low = item['u0'].to_f
            high = item['u1'].to_f
            if item['axis'].to_s == 'horizontal'
              { 'id' => index + 1, 'u0' => 0.0, 'u1' => 1.0, 'v0' => low, 'v1' => high, 'opening_type' => 'none' }
            else
              { 'id' => index + 1, 'u0' => low, 'u1' => high, 'v0' => 0.0, 'v1' => 1.0, 'opening_type' => 'none' }
            end
          end
        end
        layout.replace!(regions)
        layout
      end

      # Thay toàn bộ vùng sau khi kiểm tra các vùng ghép đúng hình vuông đơn vị. Sai thì giữ nguyên bố cục đơn.
      def replace!(regions)
        regions = regions.map { |r| r.dup }
        ids = regions.map { |r| r['id'] }
        return false if ids.uniq.length != ids.length || ids.any? { |id| id.to_i <= 0 }
        return false unless valid_tiling?(regions)
        @regions = regions
        @next_id = ids.max + 1
        true
      end

      def to_h
        { 'schema' => SCHEMA, 'regions' => sorted.map(&:dup) }
      end

      def set_size(width_mm, height_mm)
        @width_mm = width_mm.to_f
        @height_mm = height_mm.to_f
        self
      end

      def ids
        @regions.map { |r| r['id'] }
      end

      def find(id)
        @regions.find { |r| r['id'] == id }
      end

      # Thứ tự số cánh: trái -> phải, rồi dưới -> trên.
      def sorted
        @regions.sort_by { |r| [r['u0'].round(6), r['v0'].round(6)] }
      end

      def span_mm(axis)
        axis.to_s == 'horizontal' ? @height_mm : @width_mm
      end

      # Vùng chứa điểm (u, v); điểm nằm trên đường biên thì lấy vùng có tâm gần nhất.
      def region_at(u, v)
        hits = @regions.select { |r| u >= r['u0'] - EPS && u <= r['u1'] + EPS && v >= r['v0'] - EPS && v <= r['v1'] + EPS }
        hits.min_by { |r| ((r['u0'] + r['u1']) / 2 - u)**2 + ((r['v0'] + r['v1']) / 2 - v)**2 }
      end

      def edges(axis)
        keys = axis.to_s == 'horizontal' ? %w[v0 v1] : %w[u0 u1]
        @regions.flat_map { |r| keys.map { |k| r[k] } }.map { |e| e.round(9) }.uniq.sort
      end

      # Vị trí chia gợi ý trong vùng id theo trục axis từ toạ độ con trỏ (0..1 trên toàn mặt tủ).
      # Hút vào đường chia sẵn có nếu gần, ngược lại làm tròn tới 1 mm. nil nếu mỗi bên < MIN_CELL_MM.
      def propose(id, axis, coordinate)
        region = find(id)
        return nil unless region
        low, high = range_of(region, axis)
        span = span_mm(axis)
        mm = coordinate * span
        near = edges(axis).select { |e| e > low + EPS && e < high - EPS && (e * span - mm).abs <= SNAP_MM }.min_by { |e| (e * span - mm).abs }
        mm = near ? near * span : mm.round.to_f
        c = mm / span
        return nil unless (c - low) * span >= MIN_CELL_MM - 1e-6 && (high - c) * span >= MIN_CELL_MM - 1e-6
        c.round(9)
      end

      # Chia vùng id làm hai tại toạ độ c (0..1 trên toàn mặt tủ). Trả về [vùng thấp, vùng cao].
      def split(id, axis, c)
        region = find(id) or raise ArgumentError, 'Không tìm thấy vùng cần chia.'
        low, high = range_of(region, axis)
        span = span_mm(axis)
        unless (c - low) * span >= MIN_CELL_MM - 1e-6 && (high - c) * span >= MIN_CELL_MM - 1e-6
          raise ArgumentError, "Mỗi vùng sau khi chia phải rộng ít nhất #{MIN_CELL_MM.to_i} mm."
        end
        remember
        @regions.delete(region)
        a = region.dup
        b = region.dup
        a['id'] = take_id
        b['id'] = take_id
        a['opening_type'] = 'none'
        b['opening_type'] = 'none'
        if axis.to_s == 'horizontal'
          a['v1'] = c
          b['v0'] = c
        else
          a['u1'] = c
          b['u0'] = c
        end
        @regions.push(a, b)
        [a, b]
      end

      # Chia theo khoảng cách (mm) tính từ mép thấp (:low) hoặc mép cao (:high) của vùng.
      def split_mm(id, axis, mm, from = :low)
        region = find(id) or raise ArgumentError, 'Không tìm thấy vùng cần chia.'
        raise ArgumentError, 'Khoảng cách phải lớn hơn 0.' unless mm.to_f > 0
        low, high = range_of(region, axis)
        span = span_mm(axis)
        c = from == :high ? high - mm.to_f / span : low + mm.to_f / span
        split(id, axis, c.round(9))
      end

      # Chia đều vùng id thành n phần. Trả về các vùng mới.
      def split_even(id, axis, n)
        region = find(id) or raise ArgumentError, 'Không tìm thấy vùng cần chia.'
        n = n.to_i
        raise ArgumentError, 'Số phần chia phải từ 2 trở lên.' if n < 2
        low, high = range_of(region, axis)
        span = span_mm(axis)
        if (high - low) * span / n < MIN_CELL_MM - 1e-6
          raise ArgumentError, "Chia #{n} phần thì mỗi vùng nhỏ hơn #{MIN_CELL_MM.to_i} mm."
        end
        remember
        @regions.delete(region)
        made = (0...n).map do |i|
          r = region.dup
          r['id'] = take_id
          r['opening_type'] = 'none'
          a = (low + (high - low) * i / n).round(9)
          b = i == n - 1 ? high : (low + (high - low) * (i + 1) / n).round(9)
          axis.to_s == 'horizontal' ? r.merge!('v0' => a, 'v1' => b) : r.merge!('u0' => a, 'u1' => b)
          r
        end
        @regions.concat(made)
        made
      end

      # Bỏ hết bố cục, chia đều toàn mặt tủ thành n vùng (n >= 1).
      def reset_even(axis, n)
        n = n.to_i
        raise ArgumentError, 'Số phần chia phải từ 1 trở lên.' if n < 1
        span = span_mm(axis)
        raise ArgumentError, "Chia #{n} phần thì mỗi vùng nhỏ hơn #{MIN_CELL_MM.to_i} mm." if span / n < MIN_CELL_MM - 1e-6
        remember
        @regions = (0...n).map do |i|
          a = (i.to_f / n).round(9)
          b = i == n - 1 ? 1.0 : ((i + 1).to_f / n).round(9)
          axis.to_s == 'horizontal' ? new_region(0.0, 1.0, a, b) : new_region(a, b, 0.0, 1.0)
        end
        @regions
      end

      # Gộp các vùng thành một. Các vùng phải ghép thành hình chữ nhật. Trả về vùng mới.
      def merge(list)
        list = list.uniq
        raise ArgumentError, 'Chọn ít nhất 2 vùng để gộp.' if list.length < 2
        chosen = list.map { |id| find(id) or raise ArgumentError, 'Có vùng đã chọn không còn tồn tại.' }
        u0 = chosen.map { |r| r['u0'] }.min
        u1 = chosen.map { |r| r['u1'] }.max
        v0 = chosen.map { |r| r['v0'] }.min
        v1 = chosen.map { |r| r['v1'] }.max
        area = chosen.sum { |r| (r['u1'] - r['u0']) * (r['v1'] - r['v0']) }
        unless (area - (u1 - u0) * (v1 - v0)).abs < 1e-7
          raise ArgumentError, 'Các vùng chọn không ghép thành hình chữ nhật nên không gộp được.'
        end
        remember
        types = chosen.map { |r| r['opening_type'] }.uniq
        @regions -= chosen
        region = { 'id' => take_id, 'u0' => u0, 'u1' => u1, 'v0' => v0, 'v1' => v1, 'opening_type' => types.length == 1 ? types.first : 'none' }
        @regions << region
        region
      end

      def set_opening(id, type)
        region = find(id) or raise ArgumentError, 'Không tìm thấy vùng.'
        remember
        region['opening_type'] = DoorLayout.opening_type(type)
        region
      end

      # Gom nhiều thao tác thành một bước hoàn tác.
      def batch
        remember
        @batch = true
        yield
      ensure
        @batch = false
      end

      def undo
        snap = @history.pop
        return false unless snap
        @regions = snap[:regions]
        @next_id = snap[:next_id]
        true
      end

      def can_undo?
        !@history.empty?
      end

      # Các ô chữ nhật theo đơn vị bất kỳ (truyền width, height cùng đơn vị với gap).
      # Khe gap chỉ nằm GIỮA hai vùng liền kề (mỗi bên gap/2); mép ngoài sát mặt tủ.
      # Trả về [{ id:, index:, region:, x0:, x1:, z0:, z1: }] với toạ độ tính từ góc dưới-trái.
      def rects(width, height, gap = 0.0)
        half = gap.to_f / 2
        out = []
        sorted.each_with_index do |r, index|
          next if r['empty']
          x0 = r['u0'] * width + (r['u0'] > EPS ? half : 0.0)
          x1 = r['u1'] * width - (r['u1'] < 1 - EPS ? half : 0.0)
          z0 = r['v0'] * height + (r['v0'] > EPS ? half : 0.0)
          z1 = r['v1'] * height - (r['v1'] < 1 - EPS ? half : 0.0)
          next if x1 <= x0 || z1 <= z0
          out << { id: r['id'], index: index, region: r, x0: x0, x1: x1, z0: z0, z1: z1 }
        end
        out
      end

      private

      def new_region(u0, u1, v0, v1)
        { 'id' => take_id, 'u0' => u0, 'u1' => u1, 'v0' => v0, 'v1' => v1, 'opening_type' => 'none' }
      end

      def take_id
        id = @next_id
        @next_id += 1
        id
      end

      def range_of(region, axis)
        axis.to_s == 'horizontal' ? [region['v0'], region['v1']] : [region['u0'], region['u1']]
      end

      def remember
        return if @batch
        @history << { regions: @regions.map(&:dup), next_id: @next_id }
        @history.shift if @history.length > 100
      end

      # Các vùng phải nằm trong hình vuông đơn vị, không chồng nhau, tổng diện tích bằng 1.
      def valid_tiling?(regions)
        return false if regions.empty?
        total = 0.0
        regions.each do |r|
          return false unless r['u0'] >= -EPS && r['v0'] >= -EPS && r['u1'] <= 1 + EPS && r['v1'] <= 1 + EPS
          return false unless r['u1'] - r['u0'] > EPS && r['v1'] - r['v0'] > EPS
          total += (r['u1'] - r['u0']) * (r['v1'] - r['v0'])
        end
        return false unless (total - 1.0).abs < 1e-6
        regions.combination(2).none? do |a, b|
          [a['u1'], b['u1']].min - [a['u0'], b['u0']].max > 1e-9 && [a['v1'], b['v1']].min - [a['v0'], b['v0']].max > 1e-9
        end
      end
    end
  end
end
