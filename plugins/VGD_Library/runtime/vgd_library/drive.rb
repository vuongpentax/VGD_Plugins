# encoding: UTF-8
module VGD
  module Library
    module Drive
      def self.source
        JSON.parse(File.read(File.join(Library::ROOT, 'drive_source.json'), encoding: 'UTF-8'))
      end

      def self.folder_id(url)
        uri = URI.parse(url.to_s)
        return nil unless uri.host.to_s.downcase == 'drive.google.com'
        match = uri.path.match(%r{/folders/([A-Za-z0-9_-]+)(?:/|\z)})
        return match[1] if match
        return nil unless %w[/open /folderview].include?(uri.path)
        URI.decode_www_form(uri.query.to_s).to_h['id']
      rescue URI::InvalidURIError, ArgumentError
        nil
      end

      def self.local_path
        source.fetch('local_candidates', []).find { |candidate| File.directory?(candidate) }
      end

      # Earlier versions accepted the folder web page as a JSON source. Recover
      # that exact configured folder through desktop sync without opening UI.
      def self.migrate_sources
        list = Online.sources
        return unless list.any? { |entry| !entry['local'] && folder_id(entry['url']) }
        known_id = folder_id(source.fetch('url'))
        mistaken = list.select { |entry| !entry['local'] && folder_id(entry['url']) == known_id }
        return if mistaken.empty?
        path = local_path
        return unless path
        canonical = File.realpath(path)
        Catalog.add_folder(path) unless Catalog.roots.any? { |root| File.directory?(root) && File.realpath(root) == canonical }
        Catalog.save('online_sources', list - mistaken)
      end

      # Private Drive folders are read through the user's existing desktop sync.
      # SketchUp never receives the connector's account tokens.
      def self.connect
        info = source
        path = local_path
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
