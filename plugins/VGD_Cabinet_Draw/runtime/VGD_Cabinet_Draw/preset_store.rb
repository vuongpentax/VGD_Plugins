require 'json'
require 'fileutils'
require 'securerandom'

module VGD_Cabinet_Draw
  # Kho preset lưu bằng JSON. Schema 2: preset có thể chứa mô hình tấm ván ('panels').
  # File schema 1 vẫn đọc được; lần ghi đầu tiên nâng lên schema 2 và giữ một bản sao lưu riêng.
  class PresetStore
    DEFAULT_GROUP = 'Chưa phân nhóm'.freeze
    SCHEMA = 2

    attr_reader :path

    def initialize(path = nil)
      root = path || File.join(ENV.fetch('APPDATA', Dir.home), 'VGD', 'SketchUp', 'VGD_Cabinet_Draw')
      @path = File.join(root, 'presets_v1.json')
    end

    def all
      return { 'schema' => SCHEMA, 'groups' => [DEFAULT_GROUP], 'presets' => [] } unless File.file?(@path)
      data = JSON.parse(File.read(@path, encoding: 'UTF-8'))
      raise 'File preset không đúng cấu trúc.' unless data.is_a?(Hash) && data['presets'].is_a?(Array) && data['groups'].is_a?(Array)
      data['schema'] = SCHEMA
      data['groups'] << DEFAULT_GROUP unless data['groups'].any? { |item| item.to_s.casecmp(DEFAULT_GROUP).zero? }
      data
    rescue JSON::ParserError
      backup = @path + '.bak'
      return JSON.parse(File.read(backup, encoding: 'UTF-8')) if File.file?(backup)
      raise 'Không đọc được preset hoặc bản backup.'
    end

    def save(name, params, group = DEFAULT_GROUP)
      name = clean_name(name)
      group_name = clean_group(group)
      data = all
      collision!(data, name)
      data['presets'] << { 'id' => SecureRandom.uuid, 'name' => name, 'group' => group_name, 'params' => params }
      data['groups'] << group_name unless data['groups'].any? { |item| item.to_s.casecmp(group_name).zero? }
      write(data)
    end

    def rename(id, name)
      data = all
      preset = find!(data, id)
      name = clean_name(name)
      collision!(data, name, id)
      preset['name'] = name
      write(data)
    end

    def update(id, params)
      data = all
      find!(data, id)['params'] = params
      write(data)
    end

    def delete(id)
      data = all
      data['presets'].reject! { |item| item['id'] == id }
      write(data)
    end

    # Chuyển một preset sang nhóm khác (tạo nhóm nếu chưa có).
    def move(id, group)
      data = all
      preset = find!(data, id)
      group_name = clean_group(group)
      preset['group'] = group_name
      data['groups'] << group_name unless data['groups'].any? { |item| item.to_s.casecmp(group_name).zero? }
      write(data)
    end

    def add_group(name)
      group = clean_name(name)
      data = all
      raise 'Tên nhóm đã tồn tại.' if data['groups'].any? { |item| item.to_s.casecmp(group).zero? }
      data['groups'] << group
      write(data)
    end

    # Xóa nhóm; các preset trong nhóm được chuyển về "Chưa phân nhóm". Không xóa được nhóm mặc định.
    def delete_group(name)
      group = clean_name(name)
      raise 'Không xóa được nhóm mặc định.' if group.casecmp(DEFAULT_GROUP).zero?
      data = all
      raise 'Không tìm thấy nhóm.' unless data['groups'].any? { |item| item.to_s.casecmp(group).zero? }
      data['presets'].each { |item| item['group'] = DEFAULT_GROUP if item['group'].to_s.casecmp(group).zero? }
      data['groups'].reject! { |item| item.to_s.casecmp(group).zero? }
      write(data)
    end

    private

    def find!(data, id)
      data['presets'].find { |item| item['id'] == id } or raise 'Không tìm thấy preset.'
    end

    def clean_name(value)
      name = value.to_s.strip
      raise 'Tên không được để trống.' if name.empty?
      raise 'Tên tối đa 80 ký tự.' if name.length > 80
      name
    end

    def clean_group(value)
      group = value.to_s.strip
      group.empty? ? DEFAULT_GROUP : clean_name(group)
    end

    def collision!(data, name, except_id = nil)
      duplicate = data['presets'].any? { |item| item['id'] != except_id && item['name'].to_s.downcase == name.downcase }
      raise 'Tên preset đã tồn tại.' if duplicate
    end

    # Trước lần ghi đầu tiên của file schema 1, giữ một bản sao lưu riêng để có thể quay lại.
    def backup_old_schema
      return unless File.file?(@path)
      legacy = @path + '.schema1.bak'
      return if File.exist?(legacy)
      raw = JSON.parse(File.read(@path, encoding: 'UTF-8'))
      FileUtils.cp(@path, legacy) if raw.is_a?(Hash) && raw['schema'].to_i < SCHEMA
    rescue StandardError
      nil
    end

    def write(data)
      FileUtils.mkdir_p(File.dirname(@path))
      lock = File.open(@path + '.lock', 'w')
      lock.flock(File::LOCK_EX)
      backup_old_schema
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
