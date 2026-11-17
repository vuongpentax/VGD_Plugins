module VGD
  module Structure
    # Dựng tất cả (cột, dầm, tường, sàn, trần) của các tầng đã chọn trong MỘT bước hoàn tác duy nhất. Kiểm tra và lập kế hoạch cho mọi loại TRƯỚC khi đụng model:
    # có bất kỳ lỗi nào thì không dựng gì cả và báo rõ loại nào, tầng nào lỗi. Chưa xác minh trong SketchUp thật.
    module AllBuilder
      MAX_TOTAL = 20_000
      KINDS = %w[columns beams walls openings slabs ceilings].freeze
      LABELS = Checker::KIND_LABELS
      Error = Class.new(ArgumentError)

      # Mã tầng cần dựng của từng loại: tầng có lựa chọn loại đó; tầng trên cùng chỉ có sàn.
      def self.targets(state, level_ids)
        last = state['levels'].last['id']
        KINDS.each_with_object({}) do |kind, out|
          ids = state['levels'].select { |l| level_ids.include?(l['id']) && !l['picks'][kind].empty? && (kind == 'slabs' || l['id'] != last) }.map { |l| l['id'] }
          out[kind] = ids unless ids.empty?
        end
      end

      def self.prepare(model, raw_state, level_ids)
        state = State.normalize!(raw_state)
        raise Error, 'Hãy chọn ít nhất một tầng để dựng.' unless level_ids.is_a?(Array) && !level_ids.empty?
        targets = targets(state, level_ids)
        raise Error, 'Các tầng đã chọn chưa có cột, dầm, tường, sàn hay trần nào được chọn.' if targets.empty?
        contexts = targets.map do |kind, ids|
          [kind, case kind
                 when 'columns' then ColumnBuilder.prepare(model, raw_state, ids)
                 when 'beams' then BeamBuilder.prepare(model, raw_state, ids)
                 when 'walls' then WallBuilder.prepare(model, raw_state, ids)
                 when 'openings' then OpeningBuilder.prepare(model, raw_state, ids)
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
      def self.build(model, raw_state, level_ids)
        ctx = prepare(model, raw_state, level_ids)
        model.start_operation('VGD Structure · Dựng kết cấu', true)
        begin
          results = ctx[:contexts].each_with_object({}) do |(kind, c), out|
            out[kind] = case kind
                        when 'columns' then ColumnBuilder.apply(model, c)
                        when 'beams' then BeamBuilder.apply(model, c)
                        when 'walls' then WallBuilder.apply(model, c)
                        when 'openings' then OpeningBuilder.apply(model, c)
                        else PlateBuilder.apply(model, c)
                        end
          end
          ModelStore.write(model, raw_state)
          model.commit_operation
        rescue StandardError, ScriptError
          model.abort_operation
          raise
        end
        {kinds: results, total: ctx[:total], issues: results.flat_map { |kind, r| r.issues.map { |m| "#{LABELS[kind]}: #{m}" } }}
      end
    end
  end
end
