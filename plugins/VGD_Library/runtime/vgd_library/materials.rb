# encoding: UTF-8
module VGD
  module Library
    module Materials
      def self.dimension(value)
        number = Float(value)
        raise 'Kích thước phải từ 1 đến 100000 mm.' unless number.finite? && number >= 1 && number <= 100_000
        number / 25.4
      end

      def self.load_item(model, item, width, height)
        path = item[:path]
        raise 'Không thấy tệp vật liệu. Hãy làm mới thư viện.' unless File.file?(path)
        stamp = "#{path}|#{File.size(path)}|#{File.mtime(path).to_f}"
        material = model.materials.find { |m| m.get_attribute(Catalog::SECTION, 'source') == stamp }
        return material if material
        if File.extname(path).downcase == '.skm'
          material = model.materials.load(path)
        else
          w, h = dimension(width), dimension(height)
          material = model.materials.add(item[:name])
          material.texture = [path, w, h]
        end
        raise 'SketchUp không đọc được vật liệu này.' unless material
        material.set_attribute(Catalog::SECTION, 'source', stamp)
        material
      end

      def self.remember(model, material)
        @last_model, @last_material = model, material
        model.materials.current = material
      end

      def self.last(model)
        return nil unless @last_model.equal?(model) && @last_material && @last_material.valid?
        @last_material
      end

      def self.current(model)
        model.materials.current || last(model)
      end

      def self.apply(model, material)
        if model.selection.empty?
          remember(model, material)
          Sketchup.send_action('selectPaintTool:')
          return 'Đã chọn vật liệu. Dùng xô sơn để tô trong model.'
        end
        count = 0
        Geometry.each_face(model.selection.to_a, Geometry.selection_inherited(model)) do |face, _inherited|
          face.material = material
          face.clear_texture_projection(true)
          face.clear_texture_position(true)
          count += 1
        end
        raise 'Vùng chọn không có mặt có thể tô (hoặc đang khóa/ẩn).' if count.zero?
        ShellSync.watch(model, model.selection.to_a)
        remember(model, material)
        "Đã tô #{count} mặt trước. Ctrl+Z để hoàn tác."
      end

      def self.resize(model, width, height)
        material = current(model)
        raise 'Chọn vật liệu có ảnh trước khi đổi kích thước.' unless material && material.texture
        material.texture.size = [dimension(width), dimension(height)]
        'Đã đổi kích thước vật liệu; mọi mặt dùng vật liệu này trong model sẽ cập nhật.'
      end
    end
  end
end
