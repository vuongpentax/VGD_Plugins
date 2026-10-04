# encoding: UTF-8
module VGD
  module Library
    module Drive
      def self.source
        JSON.parse(File.read(File.join(Library::ROOT, 'drive_source.json'), encoding: 'UTF-8'))
      end

      # Private Drive folders are read through the user's existing desktop sync.
      # SketchUp never receives the connector's account tokens.
      def self.connect
        info = source
        path = info.fetch('local_candidates', []).find { |candidate| File.directory?(candidate) }
        unless path
          Library.message('Chọn thư mục kho đã đồng bộ bằng Google Drive for desktop. RAR/ZIP cần giải nén trước khi sử dụng.')
          path = UI.select_directory(title: "Chọn thư mục Drive đồng bộ — #{info['name']}")
        end
        return false unless path
        Catalog.add_folder(path)
        true
      end

      def self.open
        UI.openURL(Online.https(source.fetch('url')))
      end
    end
  end
end
