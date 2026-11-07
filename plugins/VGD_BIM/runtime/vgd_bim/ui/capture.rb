require 'fileutils'

module VGD
  module BIM
    module UI
      # Chụp ảnh một món đồ (group / component) bằng View#write_image. Chỉ chạy khi người dùng bấm Cập nhật ảnh.
      #
      # Chế độ isolate: cô lập món đồ (ẩn phần còn lại của model), zoom vào nó rồi chụp ảnh vuông.
      #   Mọi thay đổi trong model nằm trong một thao tác mở rồi HỦY (abort_operation), nên không để lại bước undo
      #   và trạng thái ẩn / hiện tự trở lại như cũ ngay cả khi lỗi giữa chừng.
      # Chế độ current: chụp đúng khung nhìn đang thấy (giữ tỉ lệ khung nhìn), không đổi camera hay model.
      # Cả hai chế độ bỏ chọn tạm thời (để khung chọn không lọt vào ảnh) rồi trả lại; camera và tuỳ chọn hiển thị luôn được trả lại.
      module Capture
        THUMB_SIZE = 128 # cạnh dài của ảnh nhỏ hiện trong bảng
        WHITE_BACKGROUND_OFF = %w[DrawGround DrawHorizon].freeze # tắt mặt đất và chân trời để nền thật sự trắng

        # record: một phần tử của Table.build (có :entity và :path). Trả về {pid:, stamp:}.
        def self.shoot(model, record, settings)
          entity = record[:entity]
          raise ArgumentError, 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless entity.respond_to?(:valid?) && entity.valid?
          pid = Images.id!(entity.persistent_id)
          view = model.active_view
          isolate = settings['capture_mode'] == 'isolate'
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
            saved[:options] = whiten(model) if settings['image_background'] == 'white'
            view.zoom(entity) if isolate
            view.refresh
            write(view, Images.temp_path(model, pid, :full), dimensions(view, isolate, settings['image_size']), settings)
            write(view, Images.temp_path(model, pid, :thumb), dimensions(view, isolate, THUMB_SIZE), settings)
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
          raise 'SketchUp không chụp được ảnh. Kiểm tra thư mục lưu ảnh trong Cài đặt.' unless ok
        end

        # Ảnh vuông khi cô lập; chụp khung nhìn hiện tại thì giữ tỉ lệ khung nhìn.
        def self.dimensions(view, square, longest)
          return [longest, longest] if square
          width = view.vpwidth.to_f
          height = view.vpheight.to_f
          return [longest, longest] if width <= 0 || height <= 0
          return [longest, [(longest * height / width).round, 1].max] if width >= height
          [[(longest * width / height).round, 1].max, longest]
        end

        def self.copy_camera(camera)
          copy = Sketchup::Camera.new(camera.eye, camera.target, camera.up)
          copy.perspective = camera.perspective?
          if camera.perspective? then copy.fov = camera.fov else copy.height = camera.height end
          copy
        end

        # Nền trắng: đổi tạm màu nền và tắt mặt đất / chân trời (chỉ đụng các khóa có trong bản SketchUp này). Trả về giá trị cũ.
        def self.whiten(model)
          options = model.rendering_options
          known = options.each_key.to_a
          saved = {}
          (['BackgroundColor'] + WHITE_BACKGROUND_OFF).each { |key| saved[key] = options[key] if known.include?(key) }
          saved.each_key do |key|
            options[key] = key == 'BackgroundColor' ? Sketchup::Color.new(255, 255, 255) : false
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
