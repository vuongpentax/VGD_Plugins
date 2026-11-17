module VGD
  module Structure
    # Tạo tag theo bộ tag mẫu của VGD BIM (Schema::TAGS / GRID_TAG: tên, màu, thư mục). Tag đã có thì giữ nguyên màu và thư mục của người dùng.
    module TagStore
      def self.ensure(model, spec)
        layer = model.layers[spec[:name]]
        return layer if layer
        layer = model.layers.add(spec[:name])
        layer.color = Sketchup::Color.new(*spec[:color])
        place_in_folder(model, layer, spec[:folder])
        layer
      end

      def self.place_in_folder(model, layer, folder_name)
        return unless model.layers.respond_to?(:add_folder) && layer.respond_to?(:folder=)
        folder = model.layers.folders.find { |f| f.name == folder_name } || model.layers.add_folder(folder_name)
        layer.folder = folder
      rescue StandardError
        nil
      end
    end
  end
end
