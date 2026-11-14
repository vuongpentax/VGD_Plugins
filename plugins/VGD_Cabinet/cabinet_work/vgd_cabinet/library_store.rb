# frozen_string_literal: true
require 'json'
require 'fileutils'
require 'securerandom'
require 'base64'
require 'time'
module VGD_Cabinet
  class LibraryStore
    def initialize(root)
      @root=File.expand_path(root)
      @index=PresetStore.new(File.join(@root,'library_v1.json'),defaults: -> { {} },legacy: -> { {} })
    end
    def asset_path(entry,extension)
      id=entry.fetch('asset_id')
      raise ModelingRules::Invalid,'Mẫu thư viện có mã file không hợp lệ.' unless id.is_a?(String) && id.match?(/\A[0-9a-f]{32}\z/)
      File.join(@root,'assets',id+'.'+extension)
    end
    def entries; @index.load; end
    def entry(name)
      values=entries
      raise ModelingRules::Invalid,'Mẫu thư viện không còn tồn tại.' unless values.key?(name)
      values.fetch(name)
    end
    def save(name,definition,params,scale,version,replace=false)
      name=@index.name!(name)
      values=entries
      existing=values.keys.find { |key| key.downcase==name.downcase }
      raise ModelingRules::Invalid,'Tên thư viện đã có. Nhập tên khác hoặc chọn Cập nhật mẫu.' if existing && !replace
      raise ModelingRules::Invalid,'Chọn đúng tên mẫu còn tồn tại để cập nhật.' if replace && existing!=name
      item={'asset_id'=>SecureRandom.hex(16),'params'=>params,'scale'=>scale,'version'=>version,'saved_at'=>Time.now.utc.iso8601,
            'dimensions'=>%w[w d h].each_with_index.map { |key,i| (params[key]*scale[i].abs).round(1) }}
      FileUtils.mkdir_p(File.join(@root,'assets'))
      skp=asset_path(item,'skp'); tmp=skp+'.tmp.skp'; committed=false
      begin
        writer=definition.respond_to?(:save_copy) ? :save_copy : :save_as
        raise ModelingRules::Invalid,'SketchUp không ghi được mẫu tủ SKP.' unless definition.public_send(writer,tmp) && File.file?(tmp) && File.size(tmp)>0
        File.rename(tmp,skp)
        transform=Geom::Transformation.scaling(*scale)
        preview=PreviewMesh.from_definition(definition,transform).to_data
        File.open(asset_path(item,'preview.json'),'wb') { |f| f.write(JSON.generate(preview)); f.flush; f.fsync }
        thumbnail=asset_path(item,'png')
        definition.save_thumbnail(thumbnail) if definition.respond_to?(:save_thumbnail)
        @index.change(replace ? 'update' : 'create',name,replace ? name : nil,item)
        committed=true
      ensure
        File.delete(tmp) if File.file?(tmp)
        unless committed
          %w[skp preview.json png].each { |ext| path=asset_path(item,ext); File.delete(path) if File.file?(path) }
        end
      end
      entries
    end
    def rename(name,source); @index.change('rename',name,source); end
    def delete(name)
      # Keep asset files for the .bak index and recovery of accidentally deleted entries.
      @index.change('delete',name)
    end
    def preview(item)
      JSON.parse(File.read(asset_path(item,'preview.json'),encoding:'UTF-8'))
    end
    def thumbnail(item)
      path=asset_path(item,'png')
      File.file?(path) && File.size(path)<=1_000_000 ? 'data:image/png;base64,'+Base64.strict_encode64(File.binread(path)) : nil
    end
    def with_load_copy(item)
      source=asset_path(item,'skp')
      raise ModelingRules::Invalid,'File SKP của mẫu đã mất; kiểm tra thư mục thư viện.' unless File.file?(source)
      temporary=File.join(@root,'assets','.place-'+SecureRandom.hex(16)+'.skp')
      begin
        # Unique path prevents SketchUp 2022 from reusing a previously edited definition.
        FileUtils.copy_file(source,temporary)
        yield temporary
      ensure
        File.delete(temporary) if File.file?(temporary)
      end
    end
    def listing
      entries.map { |name,item| {'name'=>name,'dimensions'=>item['dimensions'],'version'=>item['version'],'saved_at'=>item['saved_at']} }
    end
  end
end
