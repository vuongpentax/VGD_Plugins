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
      # Ảnh vị trí (kind: :location): đặt camera y như ảnh Iso (cùng hướng theo mặt trước của món, trái / phải) nhưng KHÔNG đổi gì trong model:
      #   không cô lập, không ẩn, không làm mờ, không đổi ngữ cảnh đang mở; chỉ lùi camera ra nhìn vùng quanh món rộng gấp image_location_scale lần
      #   kích thước món, để thấy món nằm đâu so với tường và nội thất khác đúng như đang hiện trong SketchUp (kể cả mặt cắt trần, trần đã ẩn).
      # Cả hai bỏ chọn tạm thời (để khung chọn không lọt vào ảnh) rồi trả lại; camera và tuỳ chọn hiển thị luôn được trả lại.
      module Capture
        ISOLATING_VIEWS = %w[isometric front].freeze
        # Hướng từ tâm món đồ tới camera theo trục thế giới, chỉ dùng khi món chưa có mặt trước (có thì xem Front.camera_direction): iso nhìn từ phía trước (-Y), bên phải (+X), phía trên; front nhìn thẳng từ phía -Y.
        DIRECTIONS = {'isometric' => [1, -1, 0.8], 'front' => [0, -1, 0]}.freeze
        COLOR_STYLE = {'RenderMode' => 3, 'DisplayColorByLayer' => false}.freeze # shaded có texture, không tô màu theo tag
        ISO_SIDES = %w[right left].freeze # Iso nhìn từ bên phải (mặc định) hoặc bên trái của mặt trước
        WHITE_BACKGROUND = {'DrawGround' => false, 'DrawHorizon' => false}.freeze # cùng với màu nền trắng
        # Ảnh vị trí có bộ thiết lập riêng (loc_*) cùng loại với ảnh chính; khi chụp ảnh vị trí, các mục image_* được thay bằng mục loc_* tương ứng
        # để mọi hàm chụp bên dưới dùng chung một cách đọc.
        LOCATION_SETTINGS = {'image_width' => 'loc_width', 'image_height' => 'loc_height', 'image_view' => 'loc_view', 'image_style' => 'loc_style',
                             'image_background' => 'loc_background', 'image_margin' => 'loc_margin', 'image_yaw' => 'loc_yaw', 'image_pitch' => 'loc_pitch'}.freeze

        # record: một phần tử của Table.build (có :entity và :path). settings: thiết lập ảnh của preset.
        # Trả về {pid:, stamp:} và thêm :note khi phải chụp bằng cách thay thế (xem write).
        # preview: chiều rộng tối đa (điểm ảnh) của ảnh nháp. Có thì chụp đúng như thật (cùng cô lập, camera, kiểu, nền) nhưng ảnh nhỏ theo tỉ lệ ảnh thật,
        #   không lưu ảnh nào, trả về {pid:, kind:, png: nội dung PNG} (xem trước góc chụp trước khi chụp hàng loạt).
        def self.shoot(model, record, settings, iso_side: 'right', kind: :full, preview: nil)
          settings = Preset.settings!(settings)
          Images.kind!(kind)
          location = kind == :location
          settings = location_settings(settings) if location
          raise ArgumentError, 'Bên của góc Iso không hợp lệ.' unless ISO_SIDES.include?(iso_side)
          entity = record[:entity]
          raise ArgumentError, 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless entity.respond_to?(:valid?) && entity.valid?
          pid = Images.id!(entity.persistent_id)
          view = model.active_view
          isolate = !location && ISOLATING_VIEWS.include?(settings['image_view'])
          framed = isolate || (location && ISOLATING_VIEWS.include?(settings['image_view'])) # có đặt camera (Iso / Chính diện); Khung nhìn hiện tại thì chụp nguyên khung
          saved = {camera: copy_camera(view), selection: model.selection.to_a, options: nil}
          ensure_writable(Images.dir(model))
          temp = preview ? preview_path(model, pid, kind) : Images.temp_path(model, pid, kind)
          png = nil
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
            if framed
              notes << aim(view, entity, settings['image_view'], FrontProbe.front_world(record), iso_side, yaw: settings['image_yaw'], pitch: settings['image_pitch'])
            end
            size = [settings['image_width'], settings['image_height']]
            size = preview_size(size, preview) if preview
            frame(view, record, size, 1.0 + settings['image_margin'] / 100.0, scale: location ? settings['image_location_scale'] : 1) if framed
            view.refresh
            notes << write(view, temp, size, settings)
            if preview then png = File.binread(temp) else Images.commit(model, pid, kind) end
          rescue StandardError => error
            log("#{error.class}: #{error.message} | đối tượng #{pid} | #{settings.inspect} | #{error.backtrace.to_a.first(4).join(' <- ')}")
            raise
          ensure
            restore(model, view, saved, operation, temp)
          end
          result = preview ? {pid: pid, kind: kind, png: png} : Images.info(model, pid, Images.dir(model), kind).merge(pid: pid, kind: kind).reject { |key, _| key == :has }
          note = notes.compact.uniq.join('; ')
          note.empty? ? result : result.merge(note: note)
        end

        # Ảnh nháp: tối đa max_width điểm ảnh bề ngang, cùng tỉ lệ với ảnh thật; ảnh thật nhỏ hơn thì giữ nguyên (không phóng to).
        def self.preview_size(size, max_width)
          width = [size[0], max_width].min
          [width, [(size[1] * width.to_f / size[0]).round, 32].max]
        end

        # File tạm của ảnh nháp (xóa ngay sau khi đọc), tên bắt đầu bằng dấu chấm để không lẫn với ảnh của món.
        def self.preview_path(model, pid, kind)
          File.join(Images.dir(model), ".preview_#{pid}#{kind == :location ? '_loc' : ''}.png")
        end

        def self.location_settings(settings)
          LOCATION_SETTINGS.each_with_object(settings.dup) { |(main, own), out| out[main] = settings.fetch(own) }
        end

        # Mỗi bước khôi phục chạy độc lập: một bước lỗi không được làm hỏng các bước sau, cũng không được biến lần chụp
        # đã thành công thành thất bại (lỗi khôi phục chỉ ghi vào capture.log).
        def self.restore(model, view, saved, operation, temp)
          steps = {
            'hủy thao tác' => -> { model.abort_operation if operation },
            'trả tuỳ chọn hiển thị' => -> { restore_options(model, saved[:options]) },
            'trả camera' => -> { view.camera = saved[:camera] },
            'trả lựa chọn' => -> { restore_selection(model, saved[:selection]) },
            'dọn file tạm' => -> { FileUtils.rm_f(temp) }
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

        # Đặt camera nhìn vào tâm món đồ từ góc đã chọn, đủ xa để không nằm trong món đồ; frame sau đó lùi ra cho trọn món đồ.
        # front: hướng mặt trước của món trong thế giới ([x, y] đơn vị, từ FrontProbe.front_world); có thì chụp theo mặt trước,
        # chưa có thì chụp theo trục thế giới (DIRECTIONS) và trả về ghi chú để người dùng biết ảnh đó chưa đồng bộ.
        # yaw / pitch (độ): góc lệch ngang và góc cao, chỉ dùng cho Chính diện (xem Front.camera_direction); chưa có mặt trước thì lệch quanh hướng -Y của thế giới.
        def self.aim(view, entity, name, front = nil, side = 'right', yaw: 0, pitch: 0)
          box = entity.bounds
          center = box.center
          vector = if name == 'front' then Front.camera_direction(name, front || [0.0, -1.0], side, yaw: yaw, pitch: pitch)
                   elsif front then Front.camera_direction(name, front, side)
                   else DIRECTIONS.fetch(name)
                   end
          vector = [-vector[0], vector[1], vector[2]] if !front && name == 'isometric' && side == 'left' # theo trục thế giới: đối xứng qua mặt phẳng nhìn thẳng từ -Y
          direction = Geom::Vector3d.new(*vector).normalize
          eye = center.offset(direction, [box.diagonal.to_f, 1.0].max * 2.0)
          camera = Sketchup::Camera.new(eye, center, Geom::Vector3d.new(0, 0, 1))
          current = view.camera
          camera.perspective = current.perspective?
          if current.perspective? then camera.fov = current.fov else camera.height = current.height end # giữ đúng FOV (phối cảnh) hoặc độ cao khung (song song) đang dùng
          view.camera = camera
          front ? nil : 'món chưa có mặt trước nên chụp theo trục thế giới'
        end

        # Lùi camera ra (extend) cho trọn hộp bao của món rồi mới chụp: hộp bao tính theo tọa độ thế giới (View#zoom tính theo tọa độ cục bộ với đối tượng
        # nằm trong group, nên lệch), và tính theo CẢ tỉ lệ ảnh lẫn tỉ lệ khung nhìn rồi lấy khoảng cách xa hơn, vì write_image có thể lấy khung theo bên nào
        # cũng được; nhờ vậy món dài hoặc cao không bị cắt khi ảnh có tỉ lệ khác khung nhìn. Giữ hướng nhìn đã đặt bởi aim.
        # scale > 1: nhìn vùng rộng gấp scale lần hộp bao quanh tâm hộp (ảnh vị trí).
        def self.frame(view, record, size, margin, scale: 1)
          entity = record[:entity]
          bounds = record[:transform] ? Geometry.world_bounds([record]) : entity.bounds
          return view.zoom(entity) if bounds.empty? # không tính được hộp bao: về cách cũ
          low = bounds.min.to_a
          high = bounds.max.to_a
          if scale != 1
            center = low.zip(high).map { |a, b| (a + b) / 2.0 }
            half = low.zip(high).map { |a, b| (b - a) / 2.0 * scale }
            low = center.zip(half).map { |c, h| c - h }
            high = center.zip(half).map { |c, h| c + h }
          end
          camera = view.camera
          view_aspect = view.vpheight.to_f.positive? ? view.vpwidth.to_f / view.vpheight : 1.0
          perspective = camera.perspective?
          fits = [size[0].to_f / size[1], view_aspect].uniq.map do |aspect|
            ViewFit.camera(low, high, direction: camera.direction.to_a, up: camera.up.to_a, perspective: perspective,
                                                              fov: perspective ? camera.fov : nil, fov_is_height: perspective && camera.fov_is_height?, aspect: aspect, margin: margin)
          end
          fit = fits.max_by { |candidate| candidate[:height] || Math.sqrt(candidate[:eye].zip(candidate[:target]).sum { |e, t| (e - t)**2 }) }
          camera.set(Geom::Point3d.new(*fit[:eye]), Geom::Point3d.new(*fit[:target]), Geom::Vector3d.new(*fit[:up]))
          camera.height = fit[:height] if fit[:height]
          view.camera = camera
        end

        # Camera.new luôn bắt đầu ở FOV 35 độ nên phải gán lại đúng FOV đang dùng. Gán nguyên giá trị Camera#fov, KHÔNG đổi sang góc ngang dù fov_is_height?:
        # SketchUp hiểu giá trị theo chế độ (ngang / dọc) của khung nhìn khi gán camera, đổi đi là FOV bị tăng sau mỗi lần chụp (60 thành 82,32 ở beta.53).
        # Chỉ đọc fov / fov_is_height? khi camera là phối cảnh: đọc ở camera song song làm SketchUp báo cảnh báo trong cửa sổ Ruby Console.
        def self.copy_camera(view)
          camera = view.camera
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
