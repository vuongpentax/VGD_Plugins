require 'json'
require 'fileutils'
require 'securerandom'

module VGD_Cabinet_Draw
  # Kho setting theo từng công cụ (schema 3).
  #   base  = thông số gốc dùng chung (dày ván, dày hậu)
  #   tools = { 'box' | 'panel' | 'door' | 'drawer' => { 'default_id' => id|nil, 'presets' => [{id, name, params}] } }
  # File preset cũ (presets_v1.json) KHÔNG bị sửa hay xóa; lần đầu chưa có file mới thì
  # toàn bộ preset cũ được nhập vào công cụ Box → Cabinet (giữ nguyên id).
  class ToolSettings
    SCHEMA = 3
    GROUPS = %w[box panel door drawer].freeze
    BASE_KEYS = %w[board_thickness back_thickness].freeze

    attr_reader :path

    def initialize(path = nil)
      @root = path || File.join(ENV.fetch('APPDATA', Dir.home), 'VGD', 'SketchUp', 'VGD_Cabinet_Draw')
      @path = File.join(@root, 'tool_settings_v1.json')
    end

    def all
      data = File.file?(@path) ? read_file : migrate_legacy
      normalize(data)
    end

    def presets(group)
      all['tools'][check_group!(group)]['presets']
    end

    def base
      all['base']
    end

    # Thông số hiệu lực: mặc định < gốc dùng chung < setting (id, hoặc setting mặc định nếu id = nil).
    def effective(group, id = nil)
      data = all
      tool = data['tools'][check_group!(group)]
      id ||= tool['default_id']
      preset = tool['presets'].find { |item| item['id'] == id }
      Schema.merge_settings(data['base'], preset ? preset['params'] : nil)
    end

    def save(group, name, params)
      data = all
      tool = data['tools'][check_group!(group)]
      name = clean_name(name)
      collision!(tool, name)
      preset = { 'id' => SecureRandom.uuid, 'name' => name, 'params' => clean_params(group, params) }
      tool['presets'] << preset
      write(data)
      preset
    end

    def update(group, id, params)
      data = all
      find!(data['tools'][check_group!(group)], id)['params'] = clean_params(group, params)
      write(data)
    end

    def rename(group, id, name)
      data = all
      tool = data['tools'][check_group!(group)]
      preset = find!(tool, id)
      name = clean_name(name)
      collision!(tool, name, id)
      preset['name'] = name
      write(data)
    end

    def delete(group, id)
      data = all
      tool = data['tools'][check_group!(group)]
      find!(tool, id)
      tool['presets'].reject! { |item| item['id'] == id }
      tool['default_id'] = nil if tool['default_id'] == id
      write(data)
    end

    # id = nil nghĩa là bỏ setting mặc định.
    def set_default(group, id)
      data = all
      tool = data['tools'][check_group!(group)]
      find!(tool, id) if id
      tool['default_id'] = id
      write(data)
    end

    def save_base(params)
      data = all
      incoming = Schema.deep_copy(params || {})
      BASE_KEYS.each do |key|
        value = incoming[key]
        next if value.nil?
        raise "Thông số gốc '#{key}' phải là số dương." unless value.is_a?(Numeric) && value.finite? && value > 0
        data['base'][key] = value.to_f
      end
      write(data)
    end

    # Xuất toàn bộ setting thành chuỗi JSON để sao lưu.
    def export_json
      JSON.pretty_generate(all)
    end

    # Nhập từ chuỗi JSON. Luôn GỘP (không ghi đè): setting nhập vào nhận id mới,
    # trùng tên thì thêm hậu tố " (nhập)". Trả về số setting đã nhập.
    def import_json(text)
      incoming = JSON.parse(text.to_s)
      raise 'File không đúng cấu trúc setting.' unless incoming.is_a?(Hash) && incoming['tools'].is_a?(Hash)
      data = all
      count = 0
      GROUPS.each do |group|
        source = incoming['tools'][group]
        next unless source.is_a?(Hash) && source['presets'].is_a?(Array)
        tool = data['tools'][group]
        source['presets'].each do |item|
          next unless item.is_a?(Hash) && item['params'].is_a?(Hash)
          name = item['name'].to_s.strip
          next if name.empty?
          name = name[0, 70]
          name += ' (nhập)' while tool['presets'].any? { |p| p['name'].downcase == name.downcase }
          tool['presets'] << { 'id' => SecureRandom.uuid, 'name' => name, 'params' => clean_params(group, item['params']) }
          count += 1
        end
      end
      write(data) if count.positive?
      count
    rescue JSON::ParserError
      raise 'File không phải JSON hợp lệ.'
    end

    private

    def check_group!(group)
      group = group.to_s
      raise "Công cụ '#{group}' không có kho setting." unless GROUPS.include?(group)
      group
    end

    def read_file
      JSON.parse(File.read(@path, encoding: 'UTF-8'))
    rescue JSON::ParserError
      backup = @path + '.bak'
      return JSON.parse(File.read(backup, encoding: 'UTF-8')) if File.file?(backup)
      raise 'Không đọc được file setting hoặc bản backup.'
    end

    def normalize(data)
      raise 'File setting không đúng cấu trúc.' unless data.is_a?(Hash)
      data['schema'] = SCHEMA
      data['base'] = {} unless data['base'].is_a?(Hash)
      data['tools'] = {} unless data['tools'].is_a?(Hash)
      GROUPS.each do |group|
        tool = data['tools'][group]
        tool = data['tools'][group] = {} unless tool.is_a?(Hash)
        tool['presets'] = [] unless tool['presets'].is_a?(Array)
        tool['default_id'] = nil unless tool['presets'].any? { |item| item['id'] == tool['default_id'] }
      end
      data
    end

    # Chưa có file mới: đọc file preset cũ (chỉ đọc), đưa vào công cụ Box.
    def migrate_legacy
      data = { 'schema' => SCHEMA, 'base' => {}, 'tools' => {} }
      old = File.join(@root, 'presets_v1.json')
      return data unless File.file?(old)
      legacy = JSON.parse(File.read(old, encoding: 'UTF-8'))
      return data unless legacy.is_a?(Hash) && legacy['presets'].is_a?(Array)
      list = []
      legacy['presets'].each do |item|
        next unless item.is_a?(Hash) && item['params'].is_a?(Hash)
        name = item['name'].to_s.strip
        name = 'Setting cũ' if name.empty?
        group = item['group'].to_s.strip
        name = "#{group} / #{name}" unless group.empty? || group == 'Chưa phân nhóm'
        name = name[0, 70]
        name += ' (cũ)' while list.any? { |p| p['name'].downcase == name.downcase }
        list << { 'id' => item['id'].to_s.empty? ? SecureRandom.uuid : item['id'].to_s, 'name' => name, 'params' => item['params'] }
      end
      data['tools']['box'] = { 'presets' => list }
      data
    rescue JSON::ParserError, SystemCallError
      { 'schema' => SCHEMA, 'base' => {}, 'tools' => {} }
    end

    def find!(tool, id)
      tool['presets'].find { |item| item['id'] == id } or raise 'Không tìm thấy setting.'
    end

    def clean_name(value)
      name = value.to_s.strip
      raise 'Tên không được để trống.' if name.empty?
      raise 'Tên tối đa 80 ký tự.' if name.length > 80
      name
    end

    def collision!(tool, name, except_id = nil)
      duplicate = tool['presets'].any? { |item| item['id'] != except_id && item['name'].to_s.downcase == name.downcase }
      raise 'Tên setting đã tồn tại trong công cụ này.' if duplicate
    end

    # Setting của một công cụ không chứa thông số gốc dùng chung (để sửa ở một chỗ, áp cho cả bốn).
    def clean_params(_group, params)
      raise 'Thông số phải là một bảng khóa-giá trị.' unless params.is_a?(Hash)
      copy = Schema.deep_copy(params)
      BASE_KEYS.each { |key| copy.delete(key) }
      copy
    end

    def write(data)
      FileUtils.mkdir_p(File.dirname(@path))
      lock = File.open(@path + '.lock', 'w')
      lock.flock(File::LOCK_EX)
      data['schema'] = SCHEMA
      temp = @path + ".#{Process.pid}.tmp"
      File.write(temp, JSON.pretty_generate(data), mode: 'w:UTF-8')
      if File.file?(@path)
        backup = @path + '.bak'
        File.delete(backup) if File.exist?(backup)
        File.rename(@path, backup)
      end
      begin
        File.rename(temp, @path)
      rescue StandardError
        File.rename(@path + '.bak', @path) if !File.exist?(@path) && File.exist?(@path + '.bak')
        raise
      end
      data
    ensure
      File.delete(temp) if temp && File.exist?(temp)
      lock.flock(File::LOCK_UN) if lock
      lock.close if lock
    end
  end
end
