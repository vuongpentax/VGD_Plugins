# encoding: UTF-8
require 'set'

module VGD
  module PluginManager
    # Gom các file và thư mục trong Plugins thành từng plugin.
    #
    # Cách cơ bản: `abc.rb`, `abc.rbe` và thư mục `abc` cùng tên (bỏ đuôi) là một plugin. Nhiều plugin có file
    # khai báo (loader) khác tên thư mục chứa mã, nên ngoài tên còn đọc nội dung các loader `.rb`: nếu loader
    # nhắc tên một mục khác (ví dụ `SketchupExtension.new('Tên', 'JHS/main')` hay `require 'fixSolid'`) thì
    # mục đó được gộp vào plugin của loader, để bật/tắt/chuyển một lần là đủ cả hai nửa.
    #
    # Để không gộp nhầm, chỉ gộp mục đích X vào loader L khi:
    #   1. X không có loader `.rb` đọc được của riêng nó (không gộp hai plugin độc lập với nhau),
    #   2. tên X không chứa "lib" (thư viện nền như TT_Lib2, Fredo6_!LibFredo6 luôn đứng riêng),
    #   3. đúng một loader nhắc tới X (thư viện dùng chung bởi nhiều loader luôn đứng riêng).
    # Loader mã hóa (`.rbe`, `.rbs`) không đọc được nên chỉ nhóm theo tên.
    module Linker
      LOADABLE  = /\.(rb|rbe|rbs)\z/i
      READABLE  = /\.rb\z/i
      LIB_NAME  = /lib/i
      MAX_READ  = 100 * 1024
      QUOTED    = /'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)"/

      # Tập tên (viết thường, không đuôi) xuất hiện trong các chuỗi trích dẫn của văn bản, tách theo / và \
      def self.tokens(text)
        out = Set.new
        text.scan(QUOTED) do |single, double|
          (single || double).split(%r{[/\\]+}).each do |seg|
            name = seg.sub(LOADABLE, '').strip.downcase
            out << name unless name.empty? || name.size > 100
          end
        end
        out
      end

      def self.read_text(path)
        data = File.open(path, 'rb') { |f| f.read(MAX_READ) }.to_s
        data.force_encoding('UTF-8').scrub('')
      rescue StandardError
        ''
      end

      # Các file .rb đọc được của một nhóm tên
      def self.readable_files(dir, entries)
        entries.select { |e| e =~ READABLE && File.file?(File.join(dir, e)) }
      end

      # Trả về { khóa => { items: [...], members: [khóa nhóm tên gộp vào] } }, items và members đã sắp xếp.
      # skip: các tên bỏ qua (mục hệ thống, chính plugin này).
      def self.group(dir, skip)
        return {} unless File.directory?(dir)
        entries = (Dir.children(dir) - skip).reject { |e| e.start_with?('.') }
        base = {}
        entries.each { |e| (base[e.sub(LOADABLE, '')] ||= []) << e }

        by_lower = {}
        base.each_key { |k| (by_lower[k.downcase] ||= []) << k }
        loaders = {}   # khóa => các file .rb đọc được
        base.each { |k, es| (rf = readable_files(dir, es)).empty? || loaders[k] = rf }

        referencers = Hash.new { |h, k| h[k] = Set.new }
        loaders.each do |key, files|
          toks = files.each_with_object(Set.new) { |f, s| s.merge(tokens(read_text(File.join(dir, f)))) }
          toks.each do |t|
            (by_lower[t] || []).each { |target| referencers[target] << key unless target == key }
          end
        end

        merged = {}   # khóa đích => khóa loader
        referencers.each do |target, loader_keys|
          next unless loader_keys.size == 1
          next if loaders.key?(target) || target =~ LIB_NAME
          merged[target] = loader_keys.first
        end

        groups = {}
        base.each do |k, es|
          next if merged.key?(k)
          groups[k] = { items: es.dup, members: [k] }
        end
        merged.each do |target, root|
          groups[root][:items].concat(base[target])
          groups[root][:members] << target
        end
        groups.each_value do |g|
          g[:items].sort!
          g[:members].sort_by!(&:downcase)
        end
        groups
      end
    end
  end
end
