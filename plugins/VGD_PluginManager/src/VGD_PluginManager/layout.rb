# encoding: UTF-8
require 'sketchup.rb'
require 'fileutils'
require 'json'
require 'digest'
require 'base64'
require 'securerandom'

module VGD
  module PluginManager
    # Lưu và áp dụng layout (thanh công cụ, dock) và phím tắt cho từng bộ plugin.
    #
    # SketchUp ghi đè các file này khi thoát, nên việc đọc/ghi thật được giao cho một script
    # PowerShell chạy nền (helper/apply_layout.ps1): nó chờ SketchUp đóng, thực hiện các bước
    # trong file job rồi mở lại SketchUp. Phần Ruby chỉ lập job, lưu/đọc snapshot và xuất/nhập.
    # Xem docs/NOI_LUU_CAI_DAT_SKETCHUP.md.
    module Layout
      PM = VGD::PluginManager

      HELPER         = File.join(File.dirname(__FILE__), 'helper', 'apply_layout.ps1')
      REG_FILES      = %w[Workspace RubyWorkspace].freeze
      MAX_BLOB_BYTES = 8 * 1024 * 1024   # chặn file nhập quá lớn
      PARTS          = %w[layout shortcuts].freeze
      # Chỉ những khóa này mới được lưu/áp (phải khớp với helper/apply_layout.ps1)
      MAIN_WINDOW_KEYS = %w[DockWidgetState ToolBarState].freeze

      class << self
        # Thay thế được trong test để không chạy PowerShell thật
        attr_writer :spawner
      end

      def self.windows?
        Sketchup.platform == :platform_win
      end

      def self.year
        (2000 + Sketchup.version.to_i).to_s
      end

      # ---- Vị trí dữ liệu (nằm cạnh sets.json) ----
      def self.layouts_dir
        File.join(Toggle.root_dir, 'layouts')
      end

      def self.jobs_dir
        File.join(Toggle.root_dir, 'jobs')
      end

      def self.job_file
        File.join(jobs_dir, 'job.json')
      end

      def self.result_file
        File.join(jobs_dir, 'result.txt')
      end

      def self.backup_dir
        File.join(Toggle.root_dir, 'backups')
      end

      # Tên thư mục an toàn cho tên bộ (kèm mã băm để hai tên gần giống không đè nhau)
      def self.preset_dir(name)
        safe = name.to_s.gsub(/[^\p{L}\p{N}_-]/, '_')[0, 30]
        File.join(layouts_dir, "#{safe}-#{Digest::SHA1.hexdigest(name.to_s)[0, 8]}")
      end

      def self.read_snapshot(dir)
        file = File.join(dir, 'layout.json')
        return nil unless File.exist?(file)
        data = JSON.parse(File.read(file, encoding: 'UTF-8'))
        return nil unless data.is_a?(Hash) && data['year'].to_s =~ /\A\d{4}\z/
        data
      rescue StandardError
        nil
      end

      def self.nonempty_hash?(h)
        h.is_a?(Hash) && !h.empty?
      end

      # Thông tin snapshot của một bộ, hoặc nil nếu chưa lưu
      def self.info(name)
        dir = preset_dir(name)
        data = read_snapshot(dir) or return nil
        has_reg = REG_FILES.any? { |n| File.exist?(File.join(dir, "#{n}.reg")) }
        { 'year' => data['year'], 'saved_at' => data['saved_at'].to_s,
          'layout' => (nonempty_hash?(data['blocks']) || nonempty_hash?(data['main_window']) || has_reg),
          'shortcuts' => nonempty_hash?(data['shortcuts']) }
      end

      def self.delete(name)
        FileUtils.rm_rf(preset_dir(name))
      end

      # ---- Lập job cho helper ----
      def self.clean_parts(parts)
        Array(parts).map(&:to_s) & PARTS
      end

      def self.build_job(steps, restart)
        { 'id' => SecureRandom.hex(8), 'sketchup_pid' => Process.pid, 'restart' => restart ? true : false,
          'log' => Log.path, 'result' => result_file, 'job_file' => job_file,
          'backup_dir' => backup_dir, 'steps' => steps }
      end

      def self.capture_step(year, dir, parts)
        { 'op' => 'capture', 'year' => year.to_s, 'dir' => dir, 'parts' => clean_parts(parts) }
      end

      def self.apply_step(year, dir, parts)
        { 'op' => 'apply', 'year' => year.to_s, 'dir' => dir, 'parts' => clean_parts(parts) }
      end

      def self.spawn_helper(job_path)
        args = ['powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                '-WindowStyle', 'Hidden', '-File', HELPER.tr('/', '\\'), '-Job', job_path.tr('/', '\\')]
        return @spawner.call(args) if @spawner
        pid = Process.spawn(*args, new_pgroup: true, out: File::NULL, err: File::NULL)
        Log.write("Đã chạy helper nền (pid #{pid}): #{args.join(' ')}")
        Process.detach(pid)
      end

      WAIT_NOTE = 'Hãy lưu model rồi đóng SketchUp bình thường (File > Exit). ' \
                  'Sau khi SketchUp đóng, plugin tự thực hiện trong vài giây. Đợi khoảng 10 giây rồi tự mở lại SketchUp.'

      # Ghi job và chạy helper chờ nền. Job mới thay job cũ (helper cũ tự thoát). Trả về thông báo.
      def self.schedule(steps, restart = false)
        return 'Tính năng này chỉ hỗ trợ Windows.' unless windows?
        return 'Không tìm thấy script helper của plugin, hãy cài lại gói.' unless File.exist?(HELPER)
        FileUtils.mkdir_p(jobs_dir)
        File.write(job_file, JSON.pretty_generate(build_job(steps, restart)), encoding: 'UTF-8')
        spawn_helper(job_file)
        WAIT_NOTE
      rescue => e
        PM.report_error('Không lập được việc cho SketchUp', e)
      end

      def self.schedule_capture(name, parts)
        return 'Hãy chọn ít nhất một mục để lưu.' if clean_parts(parts).empty?
        schedule([capture_step(year, preset_dir(name), parts)])
      end

      # Chỉ áp những phần mà snapshot có, và layout chỉ áp khi cùng phiên bản SketchUp
      def self.schedule_apply(name, parts)
        i = info(name)
        return 'Bộ này chưa lưu layout.' unless i
        want = clean_parts(parts)
        use = []
        use << 'layout' if want.include?('layout') && i['layout'] && i['year'] == year
        use << 'shortcuts' if want.include?('shortcuts') && i['shortcuts']
        if use.empty?
          return "Layout của bộ này lưu từ SketchUp #{i['year']}, không áp được cho bản #{year} " \
                 '(chỉ phím tắt dùng chung giữa các bản).' if want.include?('layout') && i['layout'] && i['year'] != year
          return 'Không có mục nào để áp (bộ này không lưu mục đã chọn).'
        end
        schedule([apply_step(year, preset_dir(name), use)])
      end

      # Chuyển phím tắt từ bản src sang bản dst: chụp từ src rồi áp vào dst (cả hai sau khi SketchUp đóng)
      def self.schedule_shortcuts_transfer(src_ver, dst_ver)
        tmp = File.join(jobs_dir, "shortcuts_#{src_ver}")
        schedule([capture_step(src_ver, tmp, ['shortcuts']), apply_step(dst_ver, tmp, ['shortcuts'])])
      end

      # Kết quả helper ghi lại, đọc một lần rồi xóa. nil nếu chưa có.
      def self.take_result
        return nil unless File.exist?(result_file)
        text = File.read(result_file, encoding: 'UTF-8').strip
        File.delete(result_file)
        text.empty? ? nil : text
      rescue StandardError
        nil
      end

      # ---- Lọc dữ liệu: chỉ giữ đúng các khóa layout và phím tắt ----
      # Khóa layout là văn bản thô giữa hai dấu nháy trong file (RubyWorkspace\\RubyToolBar-59648, hai dấu gạch chéo).
      # Phải khớp với Test-LayoutSection trong helper/apply_layout.ps1.
      def self.layout_section?(key)
        key =~ /\A(Qt)?RubyWorkspace\\\\/ || key =~ /\AWorkspace\\\\/ || key == 'ToolbarSettings' ? true : false
      end

      def self.shortcut_key?(key)
        key =~ /\A(Num_Shortcuts|Shortcut_\d+)\z/ ? true : false
      end

      # Một khối layout được lưu nguyên văn (các dòng của file, thụt lề 8 và 12, thuộc tính không có dấu phẩy).
      # Chỉ nhận khối phẳng đúng cấu trúc: không thể chèn thêm mục hay khóa nào khác ngoài đúng khối đó.
      BLOCK_KEY    = '"((?:[^"\\\\]|\\\\.)*)"'
      BLOCK_OPEN   = /\A {8}#{BLOCK_KEY}\s*:\s*\{\z/
      BLOCK_INNER  = /\A {12}"(?:[^"\\]|\\.)*"\s*:\s*(?:true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|"(?:[^"\\]|\\.)*")\z/
      BLOCK_CLOSE  = /\A {8}\}\z/
      MW_LINE      = /\A"(DockWidgetState|ToolBarState)"\s*:\s*"(?:[^"\\]|\\.)*"\z/
      MAX_BLOCKS      = 2000
      MAX_BLOCK_LINES = 400
      MAX_LINE_CHARS  = 200_000

      def self.valid_block?(key, lines)
        return false unless layout_section?(key) && lines.is_a?(Array) && lines.size.between?(2, MAX_BLOCK_LINES)
        return false unless lines.all? { |l| l.is_a?(String) && l.size <= MAX_LINE_CHARS }
        m = BLOCK_OPEN.match(lines.first)
        m && m[1] == key && lines.last =~ BLOCK_CLOSE && lines[1..-2].all? { |l| l =~ BLOCK_INNER } ? true : false
      end

      def self.clean_blocks(blocks)
        return {} unless blocks.is_a?(Hash) && blocks.size <= MAX_BLOCKS
        blocks.select { |k, v| k.is_a?(String) && valid_block?(k, v) }
      end

      def self.clean_main_window(mw)
        return {} unless mw.is_a?(Hash)
        mw.select do |k, v|
          m = v.is_a?(String) && v.size <= MAX_LINE_CHARS ? MW_LINE.match(v) : nil
          MAIN_WINDOW_KEYS.include?(k) && m && m[1] == k
        end
      end

      def self.clean_shortcuts(shortcuts)
        return {} unless shortcuts.is_a?(Hash)
        shortcuts.select { |k, v| shortcut_key?(k) && (v.is_a?(String) || v.is_a?(Integer)) }
      end

      # ---- Nhập phím tắt từ file .dat (nút Export phím tắt của SketchUp) ----
      DAT_MAX_BYTES   = 1024 * 1024
      DAT_MAX_ENTRIES = 1000
      DAT_LINE        = /\A([01]) ([01]) ([01]) (\S+) (\S.*)\z/

      # Mã hóa file .dat theo BOM (SketchUp ghi UTF-16 little-endian có BOM). Trả về chuỗi UTF-8 hoặc nil.
      def self.decode_dat(raw)
        raw = raw.dup.force_encoding('BINARY')
        text = if raw.start_with?("\xFF\xFE".b)
                 raw[2..-1].force_encoding('UTF-16LE').encode('UTF-8')
               elsif raw.start_with?("\xFE\xFF".b)
                 raw[2..-1].force_encoding('UTF-16BE').encode('UTF-8')
               else
                 raw.sub(/\A\xEF\xBB\xBF/n, '').force_encoding('UTF-8')
               end
        text.valid_encoding? ? text : nil
      rescue StandardError
        nil
      end

      # Chỉ đọc mục [Accelerator]; bỏ qua [File Locations] (đường dẫn riêng của máy khác).
      # Trả về [{ shortcuts:, skipped:, declared: }, lỗi]. shortcuts có dạng của SharedPreferences.json.
      def self.parse_dat(path)
        return [nil, 'Không tìm thấy file.'] unless File.file?(path)
        return [nil, 'File quá lớn, không phải file phím tắt của SketchUp.'] if File.size(path) > DAT_MAX_BYTES
        text = decode_dat(File.binread(path))
        return [nil, 'Không đọc được file (mã hóa lạ).'] unless text
        section = nil
        declared = nil
        entries = {}
        skipped = 0
        text.split(/\r?\n/).each do |line|
          if line =~ /\A\[(.+)\]\s*\z/
            section = $1
          elsif section == 'Accelerator'
            if line =~ /\ACount=(\d+)\s*\z/
              declared = $1.to_i
            elsif !line.strip.empty?
              m = DAT_LINE.match(line.rstrip)
              if m
                entries[m[1, 4].join(' ')] = line.rstrip   # trùng tổ hợp phím thì dòng sau thay dòng trước
              else
                skipped += 1
              end
            end
          end
        end
        return [nil, 'File không có mục [Accelerator], không phải file phím tắt của SketchUp.'] if declared.nil? && entries.empty?
        return [nil, 'File không có phím tắt hợp lệ nào.'] if entries.empty?
        return [nil, "File có quá nhiều phím tắt (hơn #{DAT_MAX_ENTRIES})."] if entries.size > DAT_MAX_ENTRIES
        shortcuts = { 'Num_Shortcuts' => entries.size }
        entries.values.each_with_index { |line, i| shortcuts["Shortcut_#{i + 1}"] = line }
        [{ shortcuts: shortcuts, skipped: skipped, declared: declared }, nil]
      end

      # Lập việc: thay toàn bộ phím tắt của SketchUp đang chạy bằng danh sách này khi SketchUp đóng
      def self.schedule_import(shortcuts)
        dir = File.join(jobs_dir, 'shortcuts_dat')
        FileUtils.rm_rf(dir)
        FileUtils.mkdir_p(dir)
        snapshot = { 'year' => year, 'saved_at' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
                     'format' => 2, 'blocks' => {}, 'main_window' => {}, 'shortcuts' => clean_shortcuts(shortcuts) }
        File.write(File.join(dir, 'layout.json'), JSON.pretty_generate(snapshot), encoding: 'UTF-8')
        schedule([apply_step(year, dir, ['shortcuts'])])
      end

      # ---- Xuất/nhập cùng bộ plugin ----
      def self.valid_registry_raw?(raw)
        raw.is_a?(String) && raw.bytesize <= MAX_BLOB_BYTES
      end

      # Dữ liệu layout của một bộ để đưa vào file xuất; nil nếu chưa lưu
      def self.export_blob(name)
        dir = preset_dir(name)
        data = read_snapshot(dir) or return nil
        registry = {}
        REG_FILES.each do |n|
          f = File.join(dir, "#{n}.reg")
          registry[n] = Base64.strict_encode64(File.binread(f)) if File.exist?(f)
        end
        { 'layout' => data, 'registry' => registry }
      end

      # Lưu dữ liệu nhập vào thư mục của bộ. Chỉ nhận cấu trúc đúng, trả về true/false.
      def self.import_blob(name, blob)
        return false unless blob.is_a?(Hash) && blob['layout'].is_a?(Hash)
        data = blob['layout']
        return false unless data['year'].to_s =~ /\A\d{4}\z/
        snapshot = { 'year' => data['year'].to_s, 'saved_at' => data['saved_at'].to_s,
                     'format' => 2, 'blocks' => clean_blocks(data['blocks']), 'main_window' => clean_main_window(data['main_window']),
                     'shortcuts' => clean_shortcuts(data['shortcuts']) }
        regs = {}
        (blob['registry'].is_a?(Hash) ? blob['registry'] : {}).each do |n, b64|
          next unless REG_FILES.include?(n) && b64.is_a?(String)
          raw = Base64.strict_decode64(b64)
          return false unless valid_registry_raw?(raw)
          regs[n] = raw
        end
        dir = preset_dir(name)
        FileUtils.rm_rf(dir)
        FileUtils.mkdir_p(dir)
        regs.each { |n, raw| File.binwrite(File.join(dir, "#{n}.reg"), raw) }
        File.write(File.join(dir, 'layout.json'), JSON.pretty_generate(snapshot), encoding: 'UTF-8')
        true
      rescue StandardError => e
        Log.write("Không nhập được layout của bộ #{name}", e)
        false
      end
    end
  end
end
