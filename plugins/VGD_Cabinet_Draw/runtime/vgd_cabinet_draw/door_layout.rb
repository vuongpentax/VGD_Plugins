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

    # Vị trí chia cánh theo các vách (hồi) giữa. spans = [[x0, x1], ...] là bề rộng mặt trước của từng vách, cùng đơn vị với
    # lo, hi (hai mép vùng cánh), gap_tolerance và min_cell. Mỗi vách chia cánh ở TIM mặt trước của nó. Các vách liền kề nhau
    # (khe giữa không quá gap_tolerance) gộp thành một cụm và cánh chia ở GIỮA cả cụm. Bỏ vị trí quá sát mép hoặc quá sát nhau.
    def self.partition_splits(spans, lo, hi, gap_tolerance = 2.0, min_cell = MIN_CELL_MM)
      splits = partition_clusters(spans, gap_tolerance).map { |a, b| ((a + b) / 2.0).round(6) }
      keep_cuts(splits, lo, hi, min_cell)
    end

    # Cụm vách: các vách liền kề (khe giữa không quá gap_tolerance) gộp thành một cụm [x0, x1].
    def self.partition_clusters(spans, gap_tolerance)
      clusters = []
      spans.map { |a, b| [a.to_f, b.to_f] }.sort.each do |a, b|
        last = clusters.last
        if last && a - last[1] <= gap_tolerance
          last[1] = [last[1], b].max
        else
          clusters << [a, b]
        end
      end
      clusters
    end

    # Bỏ vị trí quá sát mép (lo, hi) hoặc quá sát nhau.
    def self.keep_cuts(cuts, lo, hi, min_cell)
      cuts = cuts.select { |x| x - lo >= min_cell - 1e-6 && hi - x >= min_cell - 1e-6 }.sort
      cuts.each_with_object([]) { |x, kept| kept << x if kept.empty? || x - kept.last >= min_cell - 1e-6 }
    end

    # Vị trí chia cánh tự động theo khoang. Cánh luôn chia ở tim mặt trước các vách (như partition_splits); ngoài ra
    # khoang trống (giữa hai vách liền kề hoặc giữa hông và vách, đo giữa hai mặt ván) rộng HƠN threshold thì chia đôi
    # ở giữa khoang, không hơn thì giữ một cánh. threshold <= 0: không chia đôi khoang.
    # inner_lo, inner_hi: hai mặt trong của hai hông; lo, hi: hai mép vùng cánh (cùng đơn vị với spans).
    def self.bay_splits(spans, inner_lo, inner_hi, lo, hi, threshold, gap_tolerance = 2.0, min_cell = MIN_CELL_MM)
      clusters = partition_clusters(spans, gap_tolerance)
      cuts = clusters.map { |a, b| ((a + b) / 2.0).round(6) }
      if threshold.to_f > 0
        edge = inner_lo.to_f
        bays = clusters.map do |a, b|
          bay = [edge, a]
          edge = b
          bay
        end
        bays << [edge, inner_hi.to_f]
        bays.each { |a, b| cuts << ((a + b) / 2.0).round(6) if b - a > threshold.to_f + 1e-6 }
      end
      keep_cuts(cuts, lo, hi, min_cell)
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
        @auto = false
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
        layout.mark_auto! if data['auto']
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
        data = { 'schema' => SCHEMA, 'regions' => sorted.map(&:dup) }
        data['auto'] = true if @auto
        data
      end

      # Bố cục do chức năng cánh tự động tạo ra: tủ đổi kích thước thì được tính lại theo vách. Chia/gộp tay sẽ bỏ cờ này.
      def auto?
        @auto ? true : false
      end

      def mark_auto!
        @auto = true
      end

      def set_size(width_mm, height_mm)
        @width_mm = width_mm.to_f
        @height_mm = height_mm.to_f
        self
      end

      def ids
        @regions.map { |r| r['id'] }
      end

      # Mọi vùng đều đã xóa cánh (không còn cánh nào).
      def clear_history
        @history = []
      end

      def all_empty?
        @regions.all? { |r| r['empty'] }
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
      # marks: các vị trí hút phụ (0..1), ví dụ tim vách giữa; hút khi cách con trỏ không quá mark_snap_mm (ưu tiên hơn đường chia).
      def propose(id, axis, coordinate, marks = [], mark_snap_mm = SNAP_MM)
        region = find(id)
        return nil unless region
        low, high = range_of(region, axis)
        span = span_mm(axis)
        mm = coordinate * span
        inside = ->(e) { e > low + EPS && e < high - EPS }
        near = marks.map { |m| m.round(9) }.select { |e| inside.call(e) && (e * span - mm).abs <= mark_snap_mm }.min_by { |e| (e * span - mm).abs }
        near ||= edges(axis).select { |e| inside.call(e) && (e * span - mm).abs <= SNAP_MM }.min_by { |e| (e * span - mm).abs }
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
        # Vùng mới do người dùng chia ra luôn có cánh, kể cả khi vùng gốc đã xóa cánh (trống).
        a.delete('empty')
        b.delete('empty')
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
          r.delete('empty')
          a = (low + (high - low) * i / n).round(9)
          b = i == n - 1 ? high : (low + (high - low) * (i + 1) / n).round(9)
          axis.to_s == 'horizontal' ? r.merge!('v0' => a, 'v1' => b) : r.merge!('u0' => a, 'u1' => b)
          r
        end
        @regions.concat(made)
        made
      end

      # Bỏ hết bố cục, chia toàn mặt tủ tại các vị trí cuts (0..1) theo trục axis. Vị trí sát mép hoặc sát nhau quá
      # MIN_CELL_MM bị bỏ. Trả về các vùng mới.
      # keep: true (tính lại bố cục tự động sau khi tủ đổi kích thước) giữ id, hướng mở và vùng trống của vùng cũ chồng lên nhiều nhất.
      def reset_at(axis, cuts, keep: false)
        span = span_mm(axis)
        kept = []
        cuts.map { |c| c.to_f.round(9) }.select { |c| c > EPS && c < 1 - EPS }.sort.each do |c|
          kept << c if (c - (kept.last || 0.0)) * span >= MIN_CELL_MM - 1e-6 && (1.0 - c) * span >= MIN_CELL_MM - 1e-6
        end
        remember
        old = @regions
        edges = [0.0] + kept + [1.0]
        @regions = edges.each_cons(2).map do |a, b|
          axis.to_s == 'horizontal' ? new_region(0.0, 1.0, a, b) : new_region(a, b, 0.0, 1.0)
        end
        inherit_from(old, axis) if keep
        @regions
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
        # Một vùng trống được chọn riêng: "gộp" nghĩa là tạo lại cánh cho vùng đó.
        only = list.length == 1 ? find(list.first) : nil
        if only && only['empty']
          remember(false)
          only.delete('empty')
          return only
        end
        raise ArgumentError, 'Chọn ít nhất 2 vùng để gộp (hoặc 1 vùng trống để tạo lại cánh).' if list.length < 2
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
        remember(false)
        region['opening_type'] = DoorLayout.opening_type(type)
        region
      end

      # Cánh bản lề trái/phải phải có mép bản lề (mép trái hoặc mép phải) nằm ở một tấm đứng: mép tủ (0, 1) hoặc tim hồi giữa.
      # panel_us: các vị trí u (0..1) đó. Cánh có mép bản lề không nằm ở tấm nào mà mép còn lại thì có thì đổi sang mép còn lại.
      # Trả về số cánh đã đổi.
      def fix_hinges(panel_us, eps = 1e-6)
        at_panel = ->(u) { panel_us.any? { |p| (p - u).abs <= eps } }
        changed = 0
        @regions.each do |r|
          type = r['opening_type']
          next unless %w[left right].include?(type)
          hinge_u, other_u, other = type == 'left' ? [r['u0'], r['u1'], 'right'] : [r['u1'], r['u0'], 'left']
          next if at_panel.call(hinge_u) || !at_panel.call(other_u)
          r['opening_type'] = other
          changed += 1
        end
        changed
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
        @auto = snap[:auto] ? true : false
        true
      end

      def can_undo?
        !@history.empty?
      end

      # Các ô chữ nhật theo đơn vị bất kỳ (truyền width, height cùng đơn vị với gap).
      # Khe gap chỉ nằm GIỮA hai vùng liền kề (mỗi bên gap/2); mép ngoài sát mặt tủ.
      # Trả về [{ id:, index:, region:, x0:, x1:, z0:, z1: }] với toạ độ tính từ góc dưới-trái.
      # gap: khe trái–phải (giữa các vùng xếp cạnh nhau); gap_z: khe trên–dưới (mặc định bằng gap).
      def rects(width, height, gap = 0.0, gap_z = nil)
        half = gap.to_f / 2
        half_z = (gap_z.nil? ? gap : gap_z).to_f / 2
        out = []
        sorted.each_with_index do |r, index|
          next if r['empty']
          x0 = r['u0'] * width + (r['u0'] > EPS ? half : 0.0)
          x1 = r['u1'] * width - (r['u1'] < 1 - EPS ? half : 0.0)
          z0 = r['v0'] * height + (r['v0'] > EPS ? half_z : 0.0)
          z1 = r['v1'] * height - (r['v1'] < 1 - EPS ? half_z : 0.0)
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

      # Vùng mới nhận id, hướng mở và trạng thái trống của vùng cũ chồng lên nó nhiều nhất (mỗi vùng cũ chỉ cho một vùng mới).
      def inherit_from(old, axis)
        key = axis.to_s == 'horizontal' ? %w[v0 v1] : %w[u0 u1]
        used = []
        @regions.each do |region|
          best = old.reject { |o| used.include?(o['id']) }.max_by { |o| [region[key[1]], o[key[1]]].min - [region[key[0]], o[key[0]]].max }
          next unless best && [region[key[1]], best[key[1]]].min - [region[key[0]], best[key[0]]].max > EPS
          used << best['id']
          region['id'] = best['id']
          region['opening_type'] = best['opening_type']
          region['empty'] = true if best['empty']
        end
        ids = @regions.map { |r| r['id'] }
        # Vùng không thừa kế được id cũ (vùng thêm mới) lấy id mới không trùng.
        seen = []
        @regions.each do |region|
          region['id'] = (@next_id += 1) - 1 if seen.include?(region['id'])
          seen << region['id']
        end
        @next_id = [@next_id, ids.max.to_i + 1, *@regions.map { |r| r['id'] + 1 }].max
      end

      def range_of(region, axis)
        axis.to_s == 'horizontal' ? [region['v0'], region['v1']] : [region['u0'], region['u1']]
      end

      # Ghi bước hoàn tác. structural: thay đổi cấu trúc vùng (chia, gộp...) thì bố cục không còn là tự động.
      def remember(structural = true)
        unless @batch
          @history << { regions: @regions.map(&:dup), next_id: @next_id, auto: @auto }
          @history.shift if @history.length > 100
        end
        @auto = false if structural
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
