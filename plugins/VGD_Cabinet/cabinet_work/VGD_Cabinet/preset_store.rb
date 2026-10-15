# frozen_string_literal: true
require 'json'
require 'fileutils'
require 'securerandom'
module VGD_Cabinet
  # User data lives outside the installation so reinstall/reload cannot erase it.
  class PresetStore
    def initialize(path, defaults:, legacy:)
      @path=path; @defaults=defaults; @legacy=legacy
    end
    def name!(value)
      name=value.to_s.strip
      raise ModelingRules::Invalid,'Tên mẫu cần 1–80 ký tự, không có ký tự điều khiển.' if name.empty? || name.length>80 || name.match?(/[\x00-\x1f\x7f]/)
      name
    end
    def document(text)
      doc=JSON.parse(text)
      raise 'File mẫu sai định dạng.' unless doc.is_a?(Hash) && [1,2].include?(doc['schema']) && doc['presets'].is_a?(Hash)
      values=doc['presets']
      values.each { |name,params| name!(name); raise 'Thông số mẫu sai định dạng.' unless params.is_a?(Hash) }
      folded=values.keys.map(&:downcase)
      raise 'File mẫu chứa tên trùng.' unless folded.uniq.size==folded.size
      groups=doc['schema']==2 ? doc.fetch('groups',[]) : []
      raise 'Danh sách nhóm sai định dạng.' unless groups.is_a?(Array) && groups.all? { |group| group_name!(group) }
      raise 'Tên nhóm bị trùng.' unless groups.map(&:downcase).uniq.size==groups.size
      mapping=doc['schema']==2 ? doc.fetch('preset_groups',{}) : {}
      raise 'Gán nhóm sai định dạng.' unless mapping.is_a?(Hash) && (mapping.keys-values.keys).empty?
      mapping.each do |preset,group|
        raise 'Nhóm được gán chưa tồn tại.' unless groups.any? { |item| item==group }
      end
      {'schema'=>doc['schema'],'presets'=>values,'groups'=>groups,'preset_groups'=>mapping}
    end
    def group_name!(value)
      name=name!(value)
      raise ModelingRules::Invalid,'Tên nhóm không được để trống.' if name.empty?
      name
    end
    def decode(text)
      document(text)['presets']
    end
    def same_json_value?(left,right)
      JSON.generate(left)==JSON.generate(right)
    end
    def read_current
      doc=document(File.read(@path,encoding:'UTF-8'))
      @groups=doc['groups'].dup
      @preset_groups=doc['preset_groups'].dup
      @source_schema=doc['schema']
      doc['presets']
    rescue StandardError => error
      raise "Không đọc được mẫu: #{error.message}. Giữ nguyên file tại #{@path}." unless File.file?(@path+'.bak')
      backup=document(File.read(@path+'.bak',encoding:'UTF-8'))
      @groups=backup['groups'].dup
      @preset_groups=backup['preset_groups'].dup
      @source_schema=backup['schema']
      values=backup['presets']
      puts "VGD_Cabinet: khôi phục mẫu từ backup; file chính lỗi: #{error.message}"
      values
    end
    def initial_values
      values=@defaults.call
      @legacy.call.each do |name,params|
        next unless params.is_a?(Hash)
        key=name!(name)
        existing=values.keys.find { |n| n.downcase==key.downcase }
        values.delete(existing) if existing
        values[key]=params
      end
      @groups=['Chưa phân nhóm']
      @preset_groups={}
      values
    end
    def values_for_change
      if File.file?(@path)
        read_current
      elsif File.file?(@path+'.bak')
        backup=document(File.read(@path+'.bak',encoding:'UTF-8'))
        @groups=backup['groups'].dup
        @preset_groups=backup['preset_groups'].dup
        @source_schema=backup['schema']
        backup['presets']
      else
        initial_values
      end
    end
    def locked
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path+'.lock','a') do |lock|
        raise 'Không khóa được file mẫu.' unless lock.flock(File::LOCK_EX)
        begin
          yield
        ensure
          lock.flock(File::LOCK_UN)
        end
      end
    end
    def persist(values, groups=@groups || ['Chưa phân nhóm'], mapping=@preset_groups || {})
      groups=groups.dup
      groups=['Chưa phân nhóm'] if groups.empty?
      groups << 'Chưa phân nhóm' unless groups.include?('Chưa phân nhóm')
      mapping=mapping.select { |name,_| values.key?(name) }
      mapping.each { |name,group| raise ModelingRules::Invalid,'Nhóm preset không còn tồn tại.' unless groups.include?(group) && values.key?(name) }
      text=JSON.generate('schema'=>2,'groups'=>groups,'preset_groups'=>mapping,'presets'=>values)
      document(text)
      temporary=@path+'.'+SecureRandom.hex(8)+'.tmp'
      begin
        File.open(temporary,'wb') { |f| f.write(text); f.flush; f.fsync }
        written=File.read(temporary,encoding:'UTF-8')
        raise 'Kiểm tra file mẫu không khớp.' unless written==text && same_json_value?(decode(written),values)
        if File.file?(@path)
          begin
            decode(File.read(@path,encoding:'UTF-8'))
            FileUtils.copy_file(@path,@path+'.bak')
          rescue JSON::ParserError, RuntimeError, ModelingRules::Invalid
            # Keep the last good backup when the current file was damaged.
          end
        end
        File.rename(temporary,@path)
        raise 'Không xác nhận được mẫu đã lưu.' unless same_json_value?(read_current,values)
        @source_schema=2
      ensure
        File.delete(temporary) if File.file?(temporary)
      end
    end
    def load
      locked do
        if File.file?(@path)
          values=read_current
          persist(values) if @source_schema==1
          return values
        end
        # Recover a deleted main file before considering first-time migration.
        if File.file?(@path+'.bak')
          backup=document(File.read(@path+'.bak',encoding:'UTF-8'))
          @groups=backup['groups'].dup
          @preset_groups=backup['preset_groups'].dup
          @source_schema=backup['schema']
          values=backup['presets']
        else
          values=initial_values
        end
        persist(values)
        values
      end
    end
    def groups; load; @groups.dup; end
    def preset_groups; load; @preset_groups.dup; end
    def change(action, name, source=nil, params=nil, group=nil)
      locked do
        values=values_for_change
        name=name!(name)
        source=name!(source) unless source.nil?
        collision=values.keys.find { |key| key.downcase==name.downcase }
        case action
        when 'create'
          raise ModelingRules::Invalid,'Tên mẫu đã tồn tại. Chọn Cập nhật hoặc nhập tên khác.' if collision
          raise ModelingRules::Invalid,'Chọn nhóm preset còn tồn tại.' if group && !@groups.include?(group)
          values[name]=params
          @preset_groups[name]=group && @groups.include?(group) ? group : 'Chưa phân nhóm'
        when 'update'
          raise ModelingRules::Invalid,'Chọn mẫu còn tồn tại để cập nhật.' unless values.key?(source)
          raise ModelingRules::Invalid,'Cập nhật chỉ đổi thông số. Dùng Đổi tên để sửa tên mẫu.' unless name==source
          values[source]=params
          @preset_groups[source]=group if group && @groups.include?(group)
        when 'rename'
          raise ModelingRules::Invalid,'Chọn mẫu còn tồn tại để đổi tên.' unless values.key?(source)
          raise ModelingRules::Invalid,'Tên mới trùng một mẫu khác.' if collision && collision!=source
          values[name]=values.delete(source)
          old_group=@preset_groups.delete(source)
          @preset_groups[name]=old_group if old_group
        when 'delete'
          raise ModelingRules::Invalid,'Mẫu không còn tồn tại.' unless values.key?(name)
          values.delete(name)
        else
          raise ModelingRules::Invalid,'Lệnh lưu mẫu không hợp lệ.'
        end
        persist(values)
        values
      end
    end
    def change_group(action,name,source=nil)
      locked do
        values=values_for_change
        name=group_name!(name)
        source=group_name!(source) unless source.nil?
        collision=@groups.find { |group| group.downcase==name.downcase }
        case action
        when 'create'
          raise ModelingRules::Invalid,'Tên nhóm đã tồn tại.' if collision
          @groups << name
        when 'rename'
          raise ModelingRules::Invalid,'Chọn nhóm còn tồn tại để đổi tên.' unless @groups.include?(source)
          raise ModelingRules::Invalid,'Tên nhóm mới đã tồn tại.' if collision && collision!=source
          @groups[@groups.index(source)]=name
          @preset_groups.transform_values! { |group| group==source ? name : group }
        when 'delete'
          raise ModelingRules::Invalid,'Chọn nhóm còn tồn tại để xóa.' unless @groups.include?(name)
          raise ModelingRules::Invalid,'Không thể xóa nhóm Chưa phân nhóm.' if name=='Chưa phân nhóm'
          @groups.delete(name)
          @preset_groups.transform_values! { |group| group==name ? 'Chưa phân nhóm' : group }
        else
          raise ModelingRules::Invalid,'Lệnh nhóm preset không hợp lệ.'
        end
        persist(values)
        values
      end
    end
    def assign_group(preset_name,group)
      locked do
        values=values_for_change
        raise ModelingRules::Invalid,'Mẫu không còn tồn tại.' unless values.key?(preset_name)
        raise ModelingRules::Invalid,'Chọn nhóm còn tồn tại.' unless @groups.include?(group)
        @preset_groups[preset_name]=group
        persist(values)
        values
      end
    end
  end
end
