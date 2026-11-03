# encoding: UTF-8
require 'zlib'

module VGD
  module PluginManager
    # Ghi file zip (.rbz) thuần Ruby, không cần thư viện ngoài.
    module ZipWriter
      def self.dos_datetime(t)
        time = (t.hour << 11) | (t.min << 5) | (t.sec / 2)
        date = (([t.year, 1980].max - 1980) << 9) | (t.month << 5) | t.day
        [time, date]
      end

      # entries: mảng [tên_trong_zip, dữ_liệu_nhị_phân, thời_gian_sửa]
      # Trả về số file đã ghi.
      def self.write(zip_path, entries)
        central = []
        offset  = 0
        File.open(zip_path, 'wb') do |out|
          entries.each do |name, data, mtime|
            name_b = name.to_s.tr('\\', '/').encode('UTF-8').b
            data   = data.b
            crc    = Zlib.crc32(data)
            z      = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS)
            comp   = z.deflate(data, Zlib::FINISH)
            z.close
            method = 8
            if comp.bytesize >= data.bytesize
              comp   = data
              method = 0
            end
            dt, dd = dos_datetime(mtime || Time.now)
            flags  = 0x0800 # tên file UTF-8
            local = [0x04034b50, 20, flags, method, dt, dd, crc,
                     comp.bytesize, data.bytesize, name_b.bytesize, 0].pack('VvvvvvVVVvv') + name_b
            out.write(local)
            out.write(comp)
            central << [name_b, crc, comp.bytesize, data.bytesize, method, dt, dd, flags, offset]
            offset += local.bytesize + comp.bytesize
          end

          cd_start = offset
          cd_size  = 0
          central.each do |name_b, crc, cs, us, method, dt, dd, flags, off|
            rec = [0x02014b50, 20, 20, flags, method, dt, dd, crc, cs, us,
                   name_b.bytesize, 0, 0, 0, 0, 0, off].pack('VvvvvvvVVVvvvvvVV') + name_b
            out.write(rec)
            cd_size += rec.bytesize
          end

          n = central.size
          out.write([0x06054b50, 0, 0, n, n, cd_size, cd_start, 0].pack('VvvvvVVv'))
        end
        central.size
      end
    end
  end
end
