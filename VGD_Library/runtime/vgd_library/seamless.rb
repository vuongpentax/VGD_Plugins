# encoding: UTF-8
module VGD
  module Library
    module Seamless
      def self.close
        @dialog.close if @dialog
        @dialog = nil
      end

      def self.show
        close
        @model = Sketchup.active_model
        @materials = Advanced.texture_materials(@model)
        raise 'Chọn mặt có map hoặc vật liệu hiện tại để làm seamless.' if @materials.empty?
        @images, @results = {}, {}
        @dialog = UI::HtmlDialog.new(dialog_title: 'VGD — Map seamless', preferences_key: 'VGD_Library_seamless',
          width: 980, height: 700, min_width: 680, min_height: 460, resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
        @dialog.add_action_callback('seam') do |_context, action, payload|
          Library.defer do
            begin
              raise 'Model đã đổi. Mở lại Map seamless.' unless Sketchup.active_model.equal?(@model)
              args = JSON.parse(payload)
              case action
              when 'ready'
                @dialog.execute_script("VGDSeam.start(#{JSON.generate(@materials.map(&:display_name))});") if @dialog
              when 'preview' then preview(args)
              when 'apply' then apply(args)
              when 'all'
                @materials.each_index do |i|
                  preview(args.merge('index' => i))
                  apply(args.merge('index' => i))
                end
                reply('Đã áp dụng seamless cho tất cả vật liệu đã chọn.')
              when 'close' then close
              end
            rescue StandardError => e
              reply(e.message, true)
            end
          end
        end
        @dialog.set_on_closed { @dialog = nil; @images = {}; @results = {} }
        @dialog.set_file(File.join(Library::ROOT, 'seamless.html'))
        @dialog.show
      end

      def self.reply(text, error = false)
        @dialog.execute_script("VGDSeam.message(#{JSON.generate(text)},#{error});") if @dialog
      end

      def self.preview(args)
        index = Integer(args.fetch('index', 0))
        material = @materials[index]
        raise 'Vật liệu không còn tồn tại.' unless material && material.valid? && material.texture
        resolution = Integer(args.fetch('resolution', 1024))
        raise 'Độ phân giải không hợp lệ.' unless [256, 512, 1024, 2048].include?(resolution)
        key = [index, resolution]
        image = @images[key] ||= Pixels.from_rep(material.texture.image_rep(true), resolution)
        flatten = Float(args.fetch('flatten', 50)) / 100
        feather = Float(args.fetch('feather', 4)) / 100
        fixed = args.fetch('autoskip', true) && Pixels.seam_error(image) < 0.5 ? image : Pixels.seamless(image, flatten, feather)
        @results[index] = { image: fixed, width: material.texture.width.to_f, height: material.texture.height.to_f,
          options: [resolution, flatten, feather, args.fetch('autoskip', true)] }
        folder = Storage.dir('seamless')
        token = "#{@model.object_id}-#{index}-#{resolution}"
        original = File.join(folder, token + '-before.png')
        result = File.join(folder, token + '-after.png')
        Pixels.to_rep(image).save_file(original)
        Pixels.to_rep(fixed).save_file(result)
        @preview_serial = (@preview_serial || 0) + 1
        data = { index: index, before: Catalog.file_url(original) + "?v=#{@preview_serial}", after: Catalog.file_url(result) + "?v=#{@preview_serial}",
          before_error: Pixels.seam_error(image).round(2), after_error: Pixels.seam_error(fixed).round(2),
          width: image.width, height: image.height }
        @dialog.execute_script("VGDSeam.preview(#{JSON.generate(data)});") if @dialog
      end

      def self.apply(args)
        index = Integer(args.fetch('index', 0))
        resolution = Integer(args.fetch('resolution', 1024))
        options = [resolution, Float(args.fetch('flatten', 50)) / 100, Float(args.fetch('feather', 4)) / 100, args.fetch('autoskip', true)]
        preview(args) unless @results[index] && @results[index][:options] == options
        result, material = @results.fetch(index), @materials.fetch(index)
        raise 'Vật liệu đã bị xóa.' unless material.valid?
        Library.transaction('Map seamless') do |_model|
          material.texture = Pixels.to_rep(result[:image])
          material.texture.size = [result[:width], result[:height]]
        end
        reply("Đã áp dụng cho #{material.display_name}. Giữ cỡ vật liệu thật; Ctrl+Z để hoàn tác.")
        Library.send_model
      end
    end
  end
end
