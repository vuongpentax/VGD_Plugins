module VGD
  module Structure
    # Dựng tất cả (cột, dầm, tường, sàn, trần) của các tầng đã chọn trong MỘT bước hoàn tác duy nhất. Kiểm tra và lập kế hoạch cho mọi loại TRƯỚC khi đụng model:
    # có bất kỳ lỗi nào thì không dựng gì cả và báo rõ loại nào, tầng nào lỗi. Chưa xác minh trong SketchUp thật.
    module AllBuilder
      MAX_TOTAL = 20_000
      KINDS = %w[columns footings beams walls openings slabs ceilings stairs roofs glass_walls].freeze
      LABELS = Checker::KIND_LABELS_ALL
      Error = Class.new(ArgumentError)

      # Mã tầng cần dựng của từng loại: tầng có lựa chọn loại đó; tầng trên cùng chỉ có sàn.
      # only: nếu có thì chỉ dựng các loại này (dựng nhanh khi vẽ trực tiếp trong SketchUp).
      def self.targets(state, level_ids, only = nil)
        last = state['levels'].last['id']
        KINDS.each_with_object({}) do |kind, out|
          next if only && !only.include?(kind)
          # Móng không có lựa chọn riêng: tầng có khai báo `footing` và có cột (đế đặt dưới chân cột), hoặc có móng băng và có tường.
          # Mái: tầng có khai báo `roof`, kể cả tầng trên cùng.
          picked = lambda do |l|
            case kind
            when 'footings' then !(l['free_footings'] || {}).empty? || (l['footing'] && (!l['picks']['columns'].empty? || (l['footing']['strip'] && !l['picks']['walls'].empty?)))
            when 'roofs' then l['roof']
            when 'glass_walls' then !(l['glass_walls'] || {}).empty?
            else !l['picks'][kind].empty?
            end
          end
          ids = state['levels'].select { |l| level_ids.include?(l['id']) && picked.call(l) && (%w[slabs roofs].include?(kind) || l['id'] != last) }.map { |l| l['id'] }
          out[kind] = ids unless ids.empty?
        end
      end

      def self.prepare(model, raw_state, level_ids, only = nil)
        state = State.normalize!(raw_state)
        raise Error, 'Hãy chọn ít nhất một tầng để dựng.' unless level_ids.is_a?(Array) && !level_ids.empty?
        targets = targets(state, level_ids, only)
        raise Error, 'Các tầng đã chọn chưa có cột, dầm, tường, sàn hay trần nào được chọn.' if targets.empty?
        contexts = targets.map do |kind, ids|
          [kind, case kind
                 when 'columns' then ColumnBuilder.prepare(model, raw_state, ids)
                 when 'beams' then BeamBuilder.prepare(model, raw_state, ids)
                 when 'walls' then WallBuilder.prepare(model, raw_state, ids)
                 when 'openings' then OpeningBuilder.prepare(model, raw_state, ids)
                 when 'stairs' then StairBuilder.prepare(model, raw_state, ids)
                 when 'footings' then FootingBuilder.prepare(model, raw_state, ids)
                 when 'roofs' then RoofBuilder.prepare(model, raw_state, ids)
                 when 'glass_walls' then GlassWallBuilder.prepare(model, raw_state, ids)
                 else PlateBuilder.prepare(model, raw_state, ids, kind)
                 end]
        rescue ArgumentError => error
          raise Error, "#{LABELS[kind]}: #{error.message}"
        end
        total = contexts.sum { |_kind, ctx| ctx[:total] }
        raise Error, "Quá nhiều đối tượng (#{total}); tối đa #{MAX_TOTAL} mỗi lần dựng." if total > MAX_TOTAL
        {state: state, contexts: contexts, total: total}
      end

      # Trả về {kinds: {loại => Result}, total:, issues: [...]}.
      # retag: {'mã tầng:mã cũ' => 'mã tầng:mã mới'} khi phần tử đổi mã do sửa trong SketchUp (giữ VGD ID).
      # adopt: {'erase' => [entityID đối tượng SketchUp đã nhận], 'refs' => {'mã tầng:mã' => entityID}}: xóa đối tượng gốc trong CÙNG thao tác và dựng bản chuẩn giữ VGD ID của nó.
      def self.build(model, raw_state, level_ids, only = nil, retag = nil, adopt = nil)
        ctx = prepare(model, raw_state, level_ids, only)
        model.start_operation('VGD Structure · Dựng kết cấu', true)
        begin
          taken = adopt ? SuScan.take(model, adopt['erase']) : {}
          adopted_ids = adopt ? (adopt['refs'] || {}).each_with_object({}) { |(ref, su_id), h| h[ref] = taken[su_id] } : {}
          results = IdKeeper.renaming(retag, adopted_ids) { apply_all(model, ctx) }
          ModelStore.write(model, raw_state)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        {kinds: results, total: ctx[:total], issues: results.flat_map { |kind, r| r.issues.map { |m| "#{LABELS[kind]}: #{m}" } }}
      end

      def self.apply_all(model, ctx)
        ctx[:contexts].each_with_object({}) do |(kind, c), out|
          out[kind] = case kind
                      when 'columns' then ColumnBuilder.apply(model, c)
                      when 'beams' then BeamBuilder.apply(model, c)
                      when 'walls' then WallBuilder.apply(model, c)
                      when 'openings' then OpeningBuilder.apply(model, c)
                      when 'stairs' then StairBuilder.apply(model, c)
                      when 'footings' then FootingBuilder.apply(model, c)
                      when 'roofs' then RoofBuilder.apply(model, c)
                      when 'glass_walls' then GlassWallBuilder.apply(model, c)
                      else PlateBuilder.apply(model, c)
                      end
        end
      end
    end
  end
end
