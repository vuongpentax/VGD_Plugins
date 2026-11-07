require 'fileutils'
require_relative '../core/storage'

module VGD
  module BIM
    module UI
      # Chụp ảnh một món đồ (group / component) bằng View#write_image. Chỉ chạy khi người dùng bấm nút chụp ảnh.
      # Thiết lập lấy từ preset đang dùng (Preset::DEFAULT_SETTINGS): cỡ ảnh, góc nhìn, kiểu hiển thị, nền.
      #
      # Góc nhìn isometric / front: cô lập món đồ (ẩn phần còn lại của model), đặt camera nhìn vào tâm món đồ từ góc đó rồi zoom
      #   cho vừa. Mọi thay đổi trong model nằm trong một thao tác mở rồi HỦY (abort_operation), nên không để lại bước undo
      #   và trạng thái ẩn / hiện tự trở lại như cũ ngay cả khi lỗi giữa chừng.
      # Góc nhìn current: chụp đúng khung nhìn đang thấy, không đổi camera hay model.
      # Cả hai bỏ chọn tạm thời (để khung chọn không lọt vào ảnh) rồi trả lại; camera và tuỳ chọn hiển thị luôn được trả lại.
      module Capture
        THUMB_SIZE = 128 # cạnh dài của ảnh nhỏ hiện trong bảng
        ISOLATING_VIEWS = %w[isometric front].freeze
        # Hướng từ tâm món đồ tới camera, theo trục thế giới: iso nhìn từ phía trước (-Y), bên phải (+X), phía trên; front nhìn thẳng từ phía -Y.
        DIRECTIONS = {'isometric' => [1, -1, 0.8], 'front' => [0, -1, 0]}.freeze
        COLOR_STYLE = {'RenderMode' => 3, 'DisplayColorByLayer' => false}.freeze # shaded có texture, không tô màu theo tag
        WHITE_BACKGROUND = {'DrawGround' => false, 'DrawHorizon' => false}.freeze # cùng với màu nền trắng

        # record: một phần tử của Table.build (có :entity và :path). settings: thiết lập ảnh của preset.
        # Trả về {pid:, stamp:} và thêm :note khi phải chụp bằng cách thay thế (xem write).
        def self.shoot(model, record, settings)
          settings = Preset.settings!(settings)
          entity = record[:entity]
          raise ArgumentError, 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless entity.respond_to?(:valid?) && entity.valid?
          pid = Images.id!(entity.persistent_id)
          view = model.active_view
          isolate = ISOLATING_VIEWS.include?(settings['image_view'])
          saved = {camera: copy_camera(view.camera), selection: model.selection.to_a, options: nil}
          ensure_writable(Images.dir(model))
          operation = false
          notes = []
          begin
            model.selection.clear
            if isolate
              model.start_operation('VGD_BIM · Chụp ảnh', true)
              operation = true
              Table.isolate(model, record[:path])
            end
            saved[:options] = tweak_options(model, settings)
            if isolate
              aim(view, entity, settings['image_view'])
              view.zoom(entity)
            end
            view.refresh
            size = [settings['image_width'], settings['image_height']]
            notes << write(view, Images.temp_path(model, pid, :full), size, settings)
            write(view, Images.temp_path(model, pid, :thumb), thumb_size(*size), settings)
            Images.commit(model, pid, :full)
            Images.commit(model, pid, :thumb)
          rescue StandardError => error
            log("#{error.class}: #{error.message} | đối tượng #{pid} | #{settings.inspect} | #{error.backtrace.to_a.first(4).join(' <- ')}")
            raise
          ensure
            restore(model, view, saved, operation, pid)
          end
          result = Images.info(model, pid).merge(pid: pid).reject { |key, _| key == :has }
          note = notes.compact.first
          note ? result.merge(note: note) : result
        end

        # Mỗi bước khôi phục chạy độc lập: một bước lỗi không được làm hỏng các bước sau, cũng không được biến lần chụp
        # đã thành công thành thất bại (lỗi khôi phục chỉ ghi vào capture.log).
        def self.restore(model, view, saved, operation, pid)
          steps = {
            'hủy thao tác' => -> { model.abort_operation if operation },
            'trả tuỳ chọn hiển thị' => -> { restore_options(model, saved[:options]) },
            'trả camera' => -> { view.camera = saved[:camera] },
            'trả lựa chọn' => -> { restore_selection(model, saved[:selection]) },
            'dọn file tạm' => -> { Images::KINDS.each_key { |kind| FileUtils.rm_f(Images.temp_path(model, pid, kind)) } }
          }
          steps.each do |name, step|
            begin
              step.call
            rescue StandardError => error
              log("Khôi phục (#{name}) lỗi: #{error.class}: #{error.message}")
            end
          end
        end

        # SketchUp báo lỗi khi gọi Selection#add mà không có đối tượng nào, nên chỉ thêm khi có.
        def self.restore_selection(model, entities)
          model.selection.clear
          valid = entities.select(&:valid?)
          model.selection.add(*valid) unless valid.empty?
        end

        # Thư mục ảnh phải tạo được và ghi được (thử ghi một file rỗng); nếu không thì báo rõ trước khi chụp.
        def self.ensure_writable(dir)
          FileUtils.mkdir_p(dir)
          probe = File.join(dir, '.vgd_probe')
          File.write(probe, '')
          File.delete(probe)
        rescue SystemCallError => error
          log("Thư mục ảnh không ghi được: #{dir} (#{error.class}: #{error.message})")
          raise "Không ghi được vào thư mục ảnh #{dir}. Hãy chọn thư mục khác trong bảng Preset."
        end

        # Các cách gọi write_image, thử lần lượt đến khi được: đúng như xin trước, rồi bỏ nền trong suốt, rồi bỏ cả khử răng cưa.
        # Trả về ghi chú nếu phải dùng cách thay thế (nil nếu chụp đúng như xin).
        def self.write(view, file, size, settings)
          transparent = settings['image_background'] == 'transparent'
          attempts = []
          attempts << {transparent: true, antialias: true} if transparent
          attempts << {transparent: false, antialias: true}
          attempts << {transparent: false, antialias: false}
          failures = []
          attempts.each do |extra|
            begin
              ok = view.write_image({filename: native_path(file), width: size[0], height: size[1]}.merge(extra))
              return fallback_note(transparent, extra) if ok
              failures << "#{extra.inspect} -> write_image trả false"
            rescue StandardError => error
              failures << "#{extra.inspect} -> #{error.class}: #{error.message}"
            end
          end
          log("write_image thất bại: #{file} #{size.inspect} | #{failures.join(' | ')} | SketchUp #{Sketchup.respond_to?(:version) ? Sketchup.version : '?'}")
          raise "SketchUp không chụp được ảnh (đã thử #{attempts.size} cách). File: #{file}, cỡ #{size[0]} x #{size[1]}. Kiểm tra thư mục lưu ảnh và quyền ghi."
        end

        def self.fallback_note(transparent, extra)
          lost = []
          lost << 'nền trong suốt' if transparent && !extra[:transparent]
          lost << 'khử răng cưa' unless extra[:antialias]
          lost.empty? ? nil : "#{lost.join(' và ')} không dùng được trên máy này nên ảnh dùng cách thay thế"
        end

        # SketchUp trên Windows nhận đường dẫn dùng \ ; File.join trộn / và \ nên đổi về một kiểu.
        def self.native_path(path)
          File::ALT_SEPARATOR ? path.tr('/', File::ALT_SEPARATOR) : path
        end

        # Ghi chẩn đoán vào capture.log trong thư mục dữ liệu của plugin (để người dùng gửi khi chụp lỗi). Không bao giờ gây lỗi.
        def self.log(text)
          file = File.join(Storage.dir, 'capture.log')
          FileUtils.mkdir_p(Storage.dir)
          File.delete(file) if File.exist?(file) && File.size(file) > 200_000
          File.open(file, 'a:UTF-8') { |f| f.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  #{text}") }
        rescue StandardError
          nil
        end

        # Ảnh nhỏ giữ tỉ lệ của ảnh đầy đủ, cạnh dài là THUMB_SIZE.
        def self.thumb_size(width, height)
          return [THUMB_SIZE, [(THUMB_SIZE * height.to_f / width).round, 1].max] if width >= height
          [[(THUMB_SIZE * width.to_f / height).round, 1].max, THUMB_SIZE]
        end

        # Đặt camera nhìn vào tâm món đồ từ góc đã chọn, đủ xa để không nằm trong món đồ; View#zoom sau đó chỉnh cho vừa khung.
        def self.aim(view, entity, name)
          box = entity.bounds
          center = box.center
          direction = Geom::Vector3d.new(*DIRECTIONS.fetch(name)).normalize
          eye = center.offset(direction, [box.diagonal.to_f, 1.0].max * 2.0)
          camera = Sketchup::Camera.new(eye, center, Geom::Vector3d.new(0, 0, 1))
          current = view.camera
          camera.perspective = current.perspective?
          camera.height = current.height unless current.perspective?
          view.camera = camera
        end

        def self.copy_camera(camera)
          copy = Sketchup::Camera.new(camera.eye, camera.target, camera.up)
          copy.perspective = camera.perspective?
          if camera.perspective? then copy.fov = camera.fov else copy.height = camera.height end
          copy
        end

        # Đổi tạm tuỳ chọn hiển thị theo kiểu và nền của preset (chỉ đụng các khóa có trong bản SketchUp này). Trả về giá trị cũ để trả lại.
        def self.tweak_options(model, settings)
          changes = {}
          changes.merge!(COLOR_STYLE) if settings['image_style'] == 'color'
          changes.merge!(WHITE_BACKGROUND).merge!('BackgroundColor' => Sketchup::Color.new(255, 255, 255)) if settings['image_background'] == 'white'
          return nil if changes.empty?
          options = model.rendering_options
          known = []
          options.each_key { |key| known << key } # SketchUp chỉ chạy each_key khi có khối
          saved = {}
          changes.each do |key, value|
            next unless known.include?(key)
            saved[key] = options[key]
            options[key] = value
          end
          saved
        end

        def self.restore_options(model, saved)
          return unless saved
          saved.each { |key, value| model.rendering_options[key] = value }
        end
      end
    end
  end
end
