require 'fileutils'

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

        # record: một phần tử của Table.build (có :entity và :path). settings: thiết lập ảnh của preset. Trả về {pid:, stamp:}.
        def self.shoot(model, record, settings)
          settings = Preset.settings!(settings)
          entity = record[:entity]
          raise ArgumentError, 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless entity.respond_to?(:valid?) && entity.valid?
          pid = Images.id!(entity.persistent_id)
          view = model.active_view
          isolate = ISOLATING_VIEWS.include?(settings['image_view'])
          saved = {camera: copy_camera(view.camera), selection: model.selection.to_a, options: nil}
          FileUtils.mkdir_p(Images.dir(model))
          operation = false
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
            write(view, Images.temp_path(model, pid, :full), size, settings)
            write(view, Images.temp_path(model, pid, :thumb), thumb_size(*size), settings)
            Images.commit(model, pid, :full)
            Images.commit(model, pid, :thumb)
          ensure
            model.abort_operation if operation
            restore_options(model, saved[:options])
            view.camera = saved[:camera]
            model.selection.clear
            model.selection.add(*saved[:selection].select(&:valid?))
            Images::KINDS.each_key { |kind| FileUtils.rm_f(Images.temp_path(model, pid, kind)) }
          end
          Images.info(model, pid).merge(pid: pid).reject { |key, _| key == :has }
        end

        def self.write(view, file, size, settings)
          ok = view.write_image(filename: file, width: size[0], height: size[1], antialias: true, transparent: settings['image_background'] == 'transparent')
          raise 'SketchUp không chụp được ảnh. Kiểm tra thư mục lưu ảnh.' unless ok
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
          known = options.each_key.to_a
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
