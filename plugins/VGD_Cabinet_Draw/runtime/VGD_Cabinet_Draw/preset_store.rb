require 'json'
require 'fileutils'

module VGD_Cabinet_Draw
  class PresetStore
    attr_reader :path

    def initialize(path = nil)
      root = path || File.join(ENV.fetch('APPDATA', Dir.home), 'VGD', 'SketchUp', 'VGD_Cabinet_Draw')
      @path = File.join(root, 'presets_v1.json')
    end

    def all
      return { 'schema' => 1, 'groups' => [], 'presets' => [] } unless File.file?(@path)
      data = JSON.parse(File.read(@path, encoding: 'UTF-8'))
      raise 'File preset không đúng cấu trúc.' unless data.is_a?(Hash) && data['presets'].is_a?(Array) && data['groups'].is_a?(Array)
      data
    rescue JSON::ParserError
      backup = @path + '.bak'
      return JSON.parse(File.read(backup, encoding: 'UTF-8')) if File.file?(backup)
      raise 'Không đọc được preset hoặc bản backup.'
    end

    def save(name, params, group = 'Chưa phân nhóm')
      name = clean_name(name)
      data = all
      collision!(data, name)
      data['presets'] << { 'id' => SecureRandom.uuid, 'name' => name, 'group' => group.to_s, 'params' => params }
      group_name=group.to_s.strip.empty? ? 'Chưa phân nhóm' : group.to_s.strip
      data['groups'] << group_name unless data['groups'].any? { |item| item.to_s.casecmp(group_name).zero? }
      write(data)
    end

    def rename(id, name)
      data = all
      preset = data['presets'].find { |item| item['id'] == id } or raise 'Không tìm thấy preset.'
      name = clean_name(name)
      collision!(data, name, id)
      preset['name'] = name
      write(data)
    end

    def update(id, params)
      data = all
      preset = data['presets'].find { |item| item['id'] == id } or raise 'Không tìm thấy preset.'
      preset['params'] = params
      write(data)
    end

    def delete(id)
      data = all
      data['presets'].reject! { |item| item['id'] == id }
      write(data)
    end

    def add_group(name)
      group=clean_name(name)
      data=all
      raise 'Tên nhóm đã tồn tại.' if data['groups'].any? { |item| item.to_s.casecmp(group).zero? }
      data['groups'] << group
      write(data)
    end

    private
    def clean_name(value)
      name = value.to_s.strip
      raise 'Tên preset không được để trống.' if name.empty?
      raise 'Tên preset tối đa 80 ký tự.' if name.length > 80
      name
    end
    def collision!(data, name, except_id = nil)
      duplicate = data['presets'].any? { |item| item['id'] != except_id && item['name'].to_s.downcase == name.downcase }
      raise 'Tên preset đã tồn tại.' if duplicate
    end
    def write(data)
      FileUtils.mkdir_p(File.dirname(@path))
      lock = File.open(@path + '.lock', 'w')
      lock.flock(File::LOCK_EX)
      temp = @path + ".#{Process.pid}.tmp"
      File.write(temp, JSON.pretty_generate(data), mode: 'w:UTF-8')
      if File.file?(@path)
        backup=@path+'.bak'
        File.delete(backup) if File.exist?(backup)
        File.rename(@path,backup)
      end
      begin
        File.rename(temp,@path)
      rescue StandardError
        File.rename(@path+'.bak',@path) if !File.exist?(@path) && File.exist?(@path+'.bak')
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
