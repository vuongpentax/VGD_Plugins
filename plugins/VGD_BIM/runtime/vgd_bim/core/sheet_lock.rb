module VGD
  module BIM
    # Khóa sheet của Bảng khối lượng: sheet đã khóa giữ đúng các đối tượng đã chọn lúc khóa, không đổi theo lựa chọn trong SketchUp.
    # Mỗi đối tượng lưu thành "chuỗi mã bền": mã bền (persistent_id) của mọi group / component từ gốc model tới món.
    # Dùng chuỗi thay vì một mã bền vì món lồng trong group dùng chung có thể trùng mã giữa các bản sao.
    # Chuỗi lưu trong settings.json của sheet (Table.clean_sheets); không ghi gì vào model.
    module SheetLock
      MAX_ITEMS = 2000
      MAX_DEPTH = 30
      ID_PATTERN = /\A\d{1,40}\z/.freeze

      module_function

      # Mã bền của một đường dẫn (mảng thực thể từ gốc tới món), dạng chuỗi.
      def chain(path)
        path.map { |entity| entity.persistent_id.to_s }
      end

      # Chuỗi các món đang bảng (scope) trong ngữ cảnh context_path (group đang mở). Mọi món phải có mã bền thật.
      def snapshot(scope, context_path)
        raise ArgumentError, 'Chưa có đối tượng nào để khóa. Chọn group hoặc component trong SketchUp rồi khóa sheet.' if scope.empty?
        raise ArgumentError, "Quá nhiều đối tượng để khóa (tối đa #{MAX_ITEMS})." if scope.size > MAX_ITEMS
        chains = scope.map { |entity| chain(context_path + [entity]) }
        raise ArgumentError, 'Có đối tượng chưa có mã bền. Hãy lưu file SketchUp rồi thử khóa lại.' if chains.any? { |items| items.any? { |id| !ID_PATTERN.match?(id) || id.to_i.zero? } }
        chains
      end

      # Tìm lại các món theo chuỗi đã lưu. Trả {paths: [đường dẫn từ gốc tới món], missing: số món không còn trong model}.
      # Chỉ đi vào group / component có tiền tố khớp một chuỗi đã lưu, nên không quét cả model khi không cần.
      def resolve(model, chains)
        wanted = chains.to_h { |items| [items.join('/'), items] }
        prefixes = {}
        chains.each { |items| (1...items.size).each { |size| prefixes[items.first(size).join('/')] = true } }
        found = {}
        walk = lambda do |entities, ids, path|
          entities.each do |entity|
            next unless entity.respond_to?(:definition)
            id_chain = ids + [entity.persistent_id.to_s]
            key = id_chain.join('/')
            found[key] = path + [entity] if wanted.key?(key)
            walk.call(entity.definition.entities, id_chain, path + [entity]) if prefixes.key?(key)
          end
        end
        walk.call(model.entities, [], [])
        paths = chains.filter_map { |items| found[items.join('/')] }
        {paths: paths, missing: chains.size - paths.size}
      end

      # Kiểm tra dữ liệu khóa do giao diện gửi hoặc đọc từ settings.json. Sai thì trả nil.
      def clean(raw)
        return nil unless raw.is_a?(Hash) && raw['items'].is_a?(Array)
        items = raw['items']
        return nil if items.empty? || items.size > MAX_ITEMS
        return nil unless items.all? { |chain| chain.is_a?(Array) && (1..MAX_DEPTH).cover?(chain.size) && chain.all? { |id| id.is_a?(String) && ID_PATTERN.match?(id) } }
        {'items' => items.map { |chain| chain.map(&:to_s) }}
      end
    end
  end
end
