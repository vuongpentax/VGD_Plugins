require 'json'
require 'securerandom'
require 'time'

module VGD
  module BIM
    # Mốc phiên bản (Snapshot) của Bảng khối lượng: chụp lại các giá trị chính của từng món rồi so với bảng hiện tại để biết món nào
    # thêm / xóa / đổi. Lưu trong file SketchUp (dictionary VGD_BIM_MODEL, khóa `snapshots`, JSON), CHỈ ĐỌC bảng, không đổi gì trong model.
    # Món được nhận diện bằng VGD ID (nếu có), không thì mã bền `pid:<persistent_id>`. Xem docs/vgd_bim/ROADMAP.md cột mốc 5.
    module Snapshots
      DICTIONARY = 'VGD_BIM_MODEL'.freeze
      KEY = 'snapshots'.freeze
      MAX_SNAPSHOTS = 5
      MAX_ITEMS = 5000
      MAX_NAME = 60
      MAX_TEXT = 120
      ID_PATTERN = /\Asn_[0-9a-f]{8}\z/
      CONTROL = /[\u0000-\u001f\u007f]/
      TEXT_FIELDS = %w[name code level room material].freeze
      NUMBER_FIELDS = %w[lenX lenY lenZ calc_qty].freeze
      FIELDS = (TEXT_FIELDS + NUMBER_FIELDS).freeze

      def self.clean_text(value, limit)
        string = value.to_s.strip
        string.length > limit || string.match?(CONTROL) ? string.gsub(CONTROL, ' ')[0, limit] : string
      end

      def self.clean_number(value)
        value.is_a?(Numeric) && value.finite? ? value.round(1).to_f : nil
      end

      # Khóa nhận diện của một dòng bảng, rỗng nếu không nhận diện được.
      def self.key_for(row)
        id = row[:vgd_id].to_s
        return id unless id.empty?
        pid = row[:pid]
        pid.is_a?(Integer) && pid.positive? ? "pid:#{pid}" : ''
      end

      # Các giá trị cần nhớ của một dòng bảng (đã làm sạch, số làm tròn 0,1).
      def self.item_for(row)
        item = {'key' => key_for(row)}
        item['name'] = clean_text(row[:name].to_s.empty? ? row[:definition] : row[:name], MAX_TEXT)
        (TEXT_FIELDS - ['name']).each { |field| item[field] = clean_text(row[field.to_sym], MAX_TEXT) }
        NUMBER_FIELDS.each { |field| item[field] = clean_number(row[field.to_sym]) }
        item
      end

      # Mốc mới từ các dòng của bảng hiện tại. Dòng không nhận diện được bị bỏ; trùng khóa thì giữ dòng đầu.
      def self.capture(name, rows, now = Time.now)
        title = clean_text(name, MAX_NAME)
        raise ArgumentError, 'Hãy nhập tên mốc.' if title.empty?
        items = rows.map { |row| item_for(row) }.reject { |item| item['key'].empty? }.uniq { |item| item['key'] }
        raise ArgumentError, 'Bảng chưa có món nào để chụp mốc.' if items.empty?
        raise ArgumentError, "Bảng có quá #{MAX_ITEMS} món, không chụp mốc được." if items.size > MAX_ITEMS
        {'id' => "sn_#{SecureRandom.hex(4)}", 'name' => title, 'created' => now.utc.iso8601, 'items' => items}
      end

      # Kiểm tra danh sách mốc đọc từ model; dữ liệu không đúng thì ném lỗi (read bắt lại và coi như chưa có).
      def self.sanitize!(list)
        raise ArgumentError, 'Danh sách mốc không hợp lệ.' unless list.is_a?(Array) && list.size <= MAX_SNAPSHOTS
        list.map do |snap|
          raise ArgumentError, 'Mốc không hợp lệ.' unless snap.is_a?(Hash) && snap['id'].to_s.match?(ID_PATTERN) && snap['items'].is_a?(Array) && snap['items'].size <= MAX_ITEMS
          items = snap['items'].map do |item|
            raise ArgumentError, 'Mốc không hợp lệ.' unless item.is_a?(Hash) && item['key'].is_a?(String) && !item['key'].empty?
            clean = {'key' => clean_text(item['key'], MAX_TEXT)}
            TEXT_FIELDS.each { |field| clean[field] = clean_text(item[field], MAX_TEXT) }
            NUMBER_FIELDS.each { |field| clean[field] = clean_number(item[field]) }
            clean
          end
          {'id' => snap['id'], 'name' => clean_text(snap['name'], MAX_NAME), 'created' => clean_text(snap['created'], 40), 'items' => items}
        end
      end

      def self.read(model)
        return [] unless model.respond_to?(:get_attribute)
        raw = model.get_attribute(DICTIONARY, KEY).to_s
        return [] if raw.empty?
        sanitize!(JSON.parse(raw))
      rescue JSON::ParserError, ArgumentError
        []
      end

      # Ghi cả danh sách trong thao tác trong suốt (gộp vào bước hoàn tác trước).
      def self.write(model, list)
        return false unless model.respond_to?(:set_attribute) && model.respond_to?(:start_operation)
        clean = sanitize!(list)
        return true if clean == read(model)
        model.start_operation('VGD_BIM · Mốc phiên bản', true, false, true)
        begin
          model.set_attribute(DICTIONARY, KEY, JSON.generate(clean))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        true
      end

      # Thêm mốc mới; quá số mốc tối đa thì bỏ mốc cũ nhất.
      def self.add(list, snapshot)
        (list + [snapshot]).last(MAX_SNAPSHOTS)
      end

      # Danh sách gọn gửi giao diện (không kèm từng món).
      def self.summary(list)
        list.map { |snap| {'id' => snap['id'], 'name' => snap['name'], 'created' => snap['created'], 'count' => snap['items'].size} }
      end

      # So mốc với các dòng hiện tại: món mới (added), món không còn (removed), món đổi giá trị (changed, kèm từng trường đổi).
      def self.compare(snapshot, rows)
        old = snapshot['items'].to_h { |item| [item['key'], item] }
        current = rows.map { |row| [item_for(row), row[:index]] }.reject { |item, _| item['key'].empty? }.uniq { |item, _| item['key'] }
        seen = {}
        added = []
        changed = []
        current.each do |item, index|
          seen[item['key']] = true
          before = old[item['key']]
          if before.nil?
            added << {'key' => item['key'], 'name' => item['name'], 'index' => index}
            next
          end
          diffs = FIELDS.reject { |field| before[field] == item[field] }.map { |field| {'field' => field, 'old' => before[field], 'new' => item[field]} }
          changed << {'key' => item['key'], 'name' => item['name'], 'index' => index, 'diffs' => diffs} unless diffs.empty?
        end
        removed = snapshot['items'].reject { |item| seen[item['key']] }.map { |item| {'key' => item['key'], 'name' => item['name']} }
        {'added' => added, 'removed' => removed, 'changed' => changed, 'unchanged' => current.size - added.size - changed.size}
      end
    end
  end
end
