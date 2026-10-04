# encoding: UTF-8
require 'fileutils'
require 'tmpdir'
require 'zlib'

module VGD
  module Library
    module Storage
      def self.dir(name)
        base = if RUBY_PLATFORM =~ /darwin/
                 File.join(Dir.home, 'Library', 'Application Support')
               else
                 ENV['LOCALAPPDATA'] || ENV['APPDATA'] || Dir.tmpdir
               end
        target = File.join(base, 'VGD_Library', name)
        FileUtils.mkdir_p(target)
        target
      end

      def self.safe_name(name)
        text = name.to_s.gsub(/[<>:"\/\\|?*\x00-\x1f]/, '_').strip.sub(/[. ]+\z/, '')[0, 55]
        text = 'VGD' if text.empty?
        text += '_' if text =~ /\A(con|prn|aux|nul|com\d|lpt\d)\z/i
        text
      end

      # Read only the thumbnail from a SKM ZIP. No extraction of source code.
      def self.skm_thumbnail(path)
        File.open(path, 'rb') do |file|
          size = file.size
          file.seek([0, size - 65_557].max)
          tail = file.read
          end_at = tail.rindex("PK\x05\x06".b)
          return nil unless end_at && end_at + 22 <= tail.bytesize
          fields = tail.byteslice(end_at, 22).unpack('VvvvvVVv')
          count, offset = fields[4], fields[6]
          return nil if count > 5000 || offset >= size
          file.seek(offset)
          count.times do
            header = file.read(46)
            return nil unless header && header.bytesize == 46 && header.start_with?("PK\x01\x02".b)
            values = header.unpack('VvvvvvvVVVvvvvvVV')
            method, compressed, uncompressed = values[4], values[8], values[9]
            name_length, extra_length, comment_length, local_offset = values[10], values[11], values[12], values[16]
            name = file.read(name_length)
            file.seek(extra_length + comment_length, IO::SEEK_CUR)
            next unless name && name.downcase.match?(/(?:^|\/)thumbnail\.(png|jpe?g)\z/)
            return nil if compressed > 8_000_000 || uncompressed > 8_000_000
            file.seek(local_offset)
            local = file.read(30)
            return nil unless local && local.start_with?("PK\x03\x04".b)
            name_size, extra_size = local.byteslice(26, 4).unpack('vv')
            file.seek(name_size + extra_size, IO::SEEK_CUR)
            data = file.read(compressed)
            return nil unless data && data.bytesize == compressed
            if method == 8
              inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
              begin
                decoded = ''.b
                data.bytes.each_slice(8192) do |bytes|
                  decoded << inflater.inflate(bytes.pack('C*'))
                  return nil if decoded.bytesize > 8_000_000
                end
                data = decoded + inflater.finish
              ensure
                inflater.close
              end
            elsif method != 0
              return nil
            end
            return nil unless data.bytesize == uncompressed && Zlib.crc32(data) == values[7]
            return [data, File.extname(name).downcase]
          end
        end
        nil
      rescue StandardError
        nil
      end

      def self.thumbnail(item)
        return item[:preview] if item[:preview]
        path = item[:path]
        return nil unless path && File.file?(path)
        key = Digest::SHA256.hexdigest("#{path}|#{File.size(path)}|#{File.mtime(path).to_f}")
        base = File.join(dir('thumbnails'), key)
        if item[:kind] == 'model'
          output = base + '.png'
          Sketchup.save_thumbnail(path, output) unless File.file?(output)
        elsif item[:format] == 'SKM'
          content = skm_thumbnail(path)
          return nil unless content
          output = base + content[1]
          File.binwrite(output, content[0]) unless File.file?(output)
        else
          return nil
        end
        File.file?(output) ? Catalog.file_url(output) : nil
      end
    end
  end
end
