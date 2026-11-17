require 'securerandom'

module VGD
  module Structure
    # Tầng của plugin (danh sách riêng, mỗi tầng RIÊNG: cao độ, dày sàn, loại cột mặc định, cột được chọn).
    # Cao độ là mm tuyệt đối theo trục Z của model, mặt trên sàn tầng. Tầng trên cùng chỉ có sàn (không cột).
    module Levels
      MAX_LEVELS = 40
      MAX_NAME = 30
      MIN_GAP = 500.0           # tầng sau cao hơn tầng trước ít nhất 500 mm
      MAX_ELEVATION = 200_000.0
      SLAB_RANGE = (50.0..1000.0)
      DEFAULT_SLAB = 120.0
      DEFAULT_CEILING_HEIGHT = 2800.0
      CEILING_HEIGHT_RANGE = (1500.0..20_000.0)
      DEFAULT_CEILING_THICKNESS = 9.0
      CEILING_THICKNESS_RANGE = (5.0..100.0)
      MAX_OPENINGS = 2000
      MAX_POS = 100_000.0
      OPENING_ID = /\Aop_[0-9a-f]{8}\z/
      MIN_COLUMN_HEIGHT = 300.0 # chiều cao cột (đến đáy sàn tầng trên) tối thiểu
      ID_PATTERN = /\Asl_[0-9a-f]{8}\z/
      MODES = %w[auto center min max].freeze
      CONTROL = /[\u0000-\u001f\u007f]/

      Error = Class.new(ArgumentError)

      # Hai tầng mặc định: Tầng 1 (cao độ 0) và tầng trên cùng cao 3600 mm.
      def self.default
        [{'id' => 'sl_00000001', 'name' => 'Tầng 1', 'elevation' => 0.0, 'slab_thickness' => DEFAULT_SLAB, 'ceiling_height' => DEFAULT_CEILING_HEIGHT, 'ceiling_thickness' => DEFAULT_CEILING_THICKNESS, 'column_type' => nil, 'beam_type' => nil, 'wall_type' => nil,
         'picks' => {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {}}},
         {'id' => 'sl_00000002', 'name' => 'Tầng 2', 'elevation' => 3600.0, 'slab_thickness' => DEFAULT_SLAB, 'ceiling_height' => DEFAULT_CEILING_HEIGHT, 'ceiling_thickness' => DEFAULT_CEILING_THICKNESS, 'column_type' => nil, 'beam_type' => nil, 'wall_type' => nil,
         'picks' => {'columns' => {}, 'beams' => {}, 'walls' => {}, 'slabs' => {}, 'ceilings' => {}, 'openings' => {}}}]
      end

      # Kiểm tra danh sách tầng với lưới và loại cột. Trả về [danh sách sạch, số lựa chọn cột bị bỏ vì giao điểm không còn trên lưới].
      def self.normalize!(list, grid, types, beam_types = BeamTypes.default, wall_types = WallTypes.default, opening_types = OpeningTypes.default)
        raise Error, 'Danh sách tầng không hợp lệ.' unless list.is_a?(Array)
        raise Error, "Cần từ 1 đến #{MAX_LEVELS} tầng." unless list.size.between?(1, MAX_LEVELS)
        refs = Grid.intersections(grid).map { |i| i[:ref] }
        span_refs = Grid.spans(grid).map { |sp| sp[:ref] }
        cell_refs = Grid.cells(grid).map { |c| c[:ref] }
        removed = 0
        previous = nil
        out = list.each_with_index.map do |level, i|
          raise Error, "Tầng thứ #{i + 1} không hợp lệ." unless level.is_a?(Hash)
          id = level['id']
          raise Error, "Tầng thứ #{i + 1}: mã không hợp lệ." unless id.is_a?(String) && id.match?(ID_PATTERN)
          name = level['name'].is_a?(String) ? level['name'].strip : ''
          raise Error, "Tầng thứ #{i + 1}: tên từ 1 đến #{MAX_NAME} ký tự, không có ký tự điều khiển." if name.empty? || name.length > MAX_NAME || name.match?(CONTROL)
          elevation = level['elevation']
          raise Error, "Tầng “#{name}”: cao độ phải là số (mm), không quá #{MAX_ELEVATION.to_i}." unless number?(elevation) && elevation.abs <= MAX_ELEVATION
          elevation = elevation.to_f.round(1)
          raise Error, "Tầng “#{name}” phải cao hơn tầng dưới ít nhất #{MIN_GAP.to_i} mm (cao độ tăng dần)." if previous && elevation - previous < MIN_GAP
          previous = elevation
          slab = level.key?('slab_thickness') ? level['slab_thickness'] : DEFAULT_SLAB
          raise Error, "Tầng “#{name}”: dày sàn từ #{SLAB_RANGE.min.to_i} đến #{SLAB_RANGE.max.to_i} mm." unless number?(slab) && SLAB_RANGE.cover?(slab.to_f)
          ceiling_height = level.key?('ceiling_height') ? level['ceiling_height'] : DEFAULT_CEILING_HEIGHT
          raise Error, "Tầng “#{name}”: cao trần từ #{CEILING_HEIGHT_RANGE.min.to_i} đến #{CEILING_HEIGHT_RANGE.max.to_i} mm." unless number?(ceiling_height) && CEILING_HEIGHT_RANGE.cover?(ceiling_height.to_f)
          ceiling_thickness = level.key?('ceiling_thickness') ? level['ceiling_thickness'] : DEFAULT_CEILING_THICKNESS
          raise Error, "Tầng “#{name}”: dày trần từ #{CEILING_THICKNESS_RANGE.min.to_i} đến #{CEILING_THICKNESS_RANGE.max.to_i} mm." unless number?(ceiling_thickness) && CEILING_THICKNESS_RANGE.cover?(ceiling_thickness.to_f)
          type_id = level['column_type']
          raise Error, "Tầng “#{name}”: loại cột mặc định không tồn tại." unless type_id.nil? || ColumnTypes.find(types, type_id)
          beam_type = level['beam_type']
          raise Error, "Tầng “#{name}”: loại dầm mặc định không tồn tại." unless beam_type.nil? || BeamTypes.find(beam_types, beam_type)
          wall_type = level['wall_type']
          raise Error, "Tầng “#{name}”: loại tường mặc định không tồn tại." unless wall_type.nil? || WallTypes.find(wall_types, wall_type)
          raw = level['picks']
          raise Error, "Tầng “#{name}”: dữ liệu cột, dầm, tường, sàn, trần, cửa được chọn không hợp lệ." unless raw.nil? || (raw.is_a?(Hash) && %w[columns beams walls slabs ceilings openings].all? { |k| raw[k].nil? || raw[k].is_a?(Hash) })
          columns, dropped_c = picks!((raw || {})['columns'], refs, types, name, 'cột', ColumnTypes)
          beams, dropped_b = picks!((raw || {})['beams'], span_refs, beam_types, name, 'dầm', BeamTypes)
          walls, dropped_w = picks!((raw || {})['walls'], span_refs, wall_types, name, 'tường', WallTypes)
          slabs, dropped_s = cell_picks!((raw || {})['slabs'], cell_refs, name, 'sàn')
          ceilings, dropped_k = cell_picks!((raw || {})['ceilings'], cell_refs, name, 'trần')
          openings, dropped_o = openings!((raw || {})['openings'], span_refs, opening_types, name)
          removed += dropped_c + dropped_b + dropped_w + dropped_s + dropped_k + dropped_o
          {'id' => id, 'name' => name, 'elevation' => elevation, 'slab_thickness' => slab.to_f.round(1), 'ceiling_height' => ceiling_height.to_f.round(1), 'ceiling_thickness' => ceiling_thickness.to_f.round(1),
           'column_type' => type_id, 'beam_type' => beam_type, 'wall_type' => wall_type, 'picks' => {'columns' => columns, 'beams' => beams, 'walls' => walls, 'slabs' => slabs, 'ceilings' => ceilings, 'openings' => openings}}
        end
        names = out.map { |l| l['name'].downcase }
        dup = out.find { |l| names.count(l['name'].downcase) > 1 }
        raise Error, "Tên tầng “#{dup['name']}” bị trùng." if dup
        raise Error, 'Mã tầng bị trùng.' if out.map { |l| l['id'] }.uniq.size != out.size
        [out, removed]
      end

      def self.number?(value)
        value.is_a?(Numeric) && value.to_f.finite?
      end

      # picks.columns / picks.beams: {mã giao điểm hoặc nhịp => {type?, x? / y? hoặc p?}}; chỉ giữ giá trị khác mặc định.
      # Cột có kiểu đặt x, y; dầm có kiểu đặt p (theo phương vuông góc với dầm). Mã không còn trên lưới thì bỏ (đếm).
      def self.picks!(raw, refs, types, level_name, label, type_module)
        return [{}, 0] if raw.nil?
        axes = label == 'cột' ? %w[x y] : %w[p]
        picks = {}
        dropped = 0
        raw.each do |ref, pick|
          raise Error, "Tầng “#{level_name}”: #{label} #{ref} không hợp lệ." unless ref.is_a?(String) && pick.is_a?(Hash)
          unless refs.include?(ref)
            dropped += 1
            next
          end
          entry = {}
          type = pick['type']
          raise Error, "Tầng “#{level_name}”: #{label} #{ref} dùng loại #{label} không tồn tại." unless type.nil? || type_module.find(types, type)
          entry['type'] = type if type
          axes.each do |axis|
            mode = pick.key?(axis) ? pick[axis] : 'auto'
            raise Error, "Tầng “#{level_name}”: #{label} #{ref} có kiểu đặt #{axis.upcase} không hợp lệ." unless MODES.include?(mode)
            entry[axis] = mode unless mode == 'auto'
          end
          picks[ref] = entry
        end
        [picks, dropped]
      end

      # picks.slabs / picks.ceilings: {mã ô => {}} (chưa có thuộc tính riêng từng ô). Mã ô không còn trên lưới thì bỏ (đếm).
      def self.cell_picks!(raw, refs, level_name, label)
        return [{}, 0] if raw.nil?
        picks = {}
        dropped = 0
        raw.each do |ref, pick|
          raise Error, "Tầng “#{level_name}”: #{label} #{ref} không hợp lệ." unless ref.is_a?(String) && pick.is_a?(Hash)
          refs.include?(ref) ? picks[ref] = {} : dropped += 1
        end
        [picks, dropped]
      end

      # picks.openings: {mã cửa 'op_xxxxxxxx' => {wall: mã nhịp của tường, type: mã loại cửa, pos: vị trí TÂM cửa tính từ đầu tường (mm), flip: đổi mặt cánh}}.
      # Cửa trên tường không còn trên lưới thì bỏ (đếm); loại cửa không tồn tại là lỗi.
      def self.openings!(raw, wall_refs, opening_types, level_name)
        return [{}, 0] if raw.nil?
        raise Error, "Tầng “#{level_name}”: quá nhiều cửa (tối đa #{MAX_OPENINGS})." if raw.size > MAX_OPENINGS
        out = {}
        dropped = 0
        raw.each do |id, entry|
          raise Error, "Tầng “#{level_name}”: mã cửa không hợp lệ." unless id.is_a?(String) && id.match?(OPENING_ID) && entry.is_a?(Hash)
          unless wall_refs.include?(entry['wall'])
            dropped += 1
            next
          end
          raise Error, "Tầng “#{level_name}”: cửa #{id} dùng loại cửa không tồn tại." unless entry['type'].is_a?(String) && OpeningTypes.find(opening_types, entry['type'])
          pos = entry['pos']
          raise Error, "Tầng “#{level_name}”: vị trí cửa #{id} phải là số (mm) từ 0 đến #{MAX_POS.to_i}." unless number?(pos) && pos.to_f.between?(0, MAX_POS)
          flip = entry.key?('flip') ? entry['flip'] : false
          raise Error, "Tầng “#{level_name}”: mục đổi mặt cánh của cửa #{id} phải là Có hoặc Không." unless flip == true || flip == false
          out[id] = {'wall' => entry['wall'], 'type' => entry['type'], 'pos' => pos.to_f.round(1), 'flip' => flip}
        end
        [out, dropped]
      end

      def self.find(levels, id)
        levels.find { |l| l['id'] == id }
      end

      # Tầng kế trên (cao hơn) của tầng có id; nil nếu là tầng trên cùng.
      def self.next_of(levels, id)
        index = levels.index { |l| l['id'] == id }
        index && levels[index + 1]
      end

      # Sao chép lựa chọn (kind = 'columns', 'beams', 'walls', 'slabs' hoặc 'ceilings') từ tầng này sang tầng khác: thay hoàn toàn lựa chọn cùng loại của tầng đích; không đổi
      # loại mặc định, cao độ, dày sàn, lựa chọn loại kia. Mỗi tầng vẫn sửa riêng được sau đó. Trả về danh sách tầng mới (đã kiểm tra), không đổi dữ liệu vào.
      def self.copy_picks(levels, from_id, to_id, grid, types, kind = 'columns', beam_types = BeamTypes.default, wall_types = WallTypes.default, opening_types = OpeningTypes.default)
        raise Error, 'Hãy chọn hai tầng khác nhau.' if from_id == to_id
        raise Error, 'Loại lựa chọn không hợp lệ.' unless %w[columns beams walls slabs ceilings openings].include?(kind)
        from = find(levels, from_id) or raise Error, 'Tầng nguồn không tồn tại.'
        find(levels, to_id) or raise Error, 'Tầng đích không tồn tại.'
        copied = Marshal.load(Marshal.dump(levels))
        find(copied, to_id)['picks'][kind] = Marshal.load(Marshal.dump(from['picks'][kind]))
        if kind == 'openings' # cửa phải có mã riêng ở tầng đích (mã cửa là duy nhất theo tầng và gắn với VGD ID)
          find(copied, to_id)['picks'][kind] = from['picks'][kind].values.each_with_object({}) { |entry, h| h["op_#{SecureRandom.hex(4)}"] = Marshal.load(Marshal.dump(entry)) }
        end
        normalize!(copied, grid, types, beam_types, wall_types, opening_types).first
      end
    end
  end
end
