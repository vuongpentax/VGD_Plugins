# encoding: UTF-8
module VGD
  module Dim
    module ManualDim
      extend self

      def start(settings)
        model = Sketchup.active_model
        Regions.root_context!(model)
        raise 'APPLY đang chạy; đợi hoàn tất trước khi tạo Dim.' if NativeStyle.running?
        config = Core.validate_settings(settings || {})
        model.select_tool(Tool.new(config))
        true
      end

      class Tool
        def initialize(config)
          @config = config
          @phase = :start
          @input = Sketchup::InputPoint.new
          @input_start = Sketchup::InputPoint.new
          @first = @last_end = @offset = nil
          @placed = 0
          @failed = false
        end

        def activate
          prompt
        end

        def prompt
          Sketchup.status_text = case @phase
            when :start then 'VGD Dim: Chọn điểm đầu của Dim.'
            when :end then 'VGD Dim: Chọn điểm cuối của Dim.'
            else 'VGD Dim: Chọn phía và khoảng cách đặt đường Dim.'
          end
        end

        def onMouseMove(_flags, x, y, view)
          if @phase == :offset && @first && @last_end
            @offset = offset_from_cursor(view, x, y)
          else
            @input.pick(view, x, y, @phase == :end ? @input_start : nil)
          end
          view.invalidate
        end

        def onLButtonDown(_flags, x, y, view)
          if @phase == :offset
            offset = offset_from_cursor(view, x, y)
            raise ArgumentError, 'Không xác định được mặt phẳng đặt Dim; hãy chọn hướng nhìn khác.' unless offset && offset.length > 0.01.mm
            create_dimension(@first, @last_end, offset)
            @placed += 1
            view.invalidate
            @phase = :start
            @first = @last_end = @offset = nil
            @input_start = Sketchup::InputPoint.new
            prompt
            return
          end
          @input.pick(view, x, y, @phase == :end ? @input_start : nil)
          raise ArgumentError, 'Không bắt được điểm; hãy chọn lại.' unless @input.valid?
          point = @input.position
          if @phase == :start
            @first = point
            @input_start.copy!(@input)
            @phase = :end
          else
            raise ArgumentError, 'Hai điểm Dim phải khác nhau.' if point.distance(@first) <= 0.01.mm
            @last_end = point
            @phase = :offset
          end
          prompt
          view.invalidate
        rescue StandardError => error
          @failed = true
          Dialog.send_js('onError', {'message'=>error.message})
          Sketchup.active_model.select_tool(nil)
        end

        def onKeyDown(key, _repeat, _flags, view)
          if key == 27
            Sketchup.active_model.select_tool(nil)
          elsif key == 8
            @phase = :start
            @first = @last_end = @offset = nil
            @input_start = Sketchup::InputPoint.new
            prompt
            view.invalidate
          end
        end

        def onCancel(_reason, _view)
          Dialog.send_js('onManualStatus', {'message'=>@placed > 0 ? 'Đã tạo Dim thủ công.' : 'Đã hủy Dim thủ công.'}) unless @failed
          Sketchup.status_text = ''
        end

        def draw(view)
          @input.draw(view) if @phase != :offset && @input.valid?
          return unless @first && @last_end
          offset = @offset || offset_from_cursor(view, view.vpwidth / 2, view.vpheight / 2)
          return unless offset && offset.length > 0.01.mm
          view.drawing_color = Sketchup::Color.new(184, 132, 82)
          view.line_width = 2
          view.draw(GL_LINES, [@first, @first + offset, @last_end, @last_end + offset, @first + offset, @last_end + offset])
        rescue StandardError
          nil
        end

        def getExtents
          box = Geom::BoundingBox.new
          [@first, @last_end, (@first && @offset ? @first + @offset : nil),
           (@last_end && @offset ? @last_end + @offset : nil)].compact.each { |point| box.add(point) }
          box
        end

        private

        def offset_from_cursor(view, x, y)
          ray = view.pickray(x, y)
          axis = @first.vector_to(@last_end)
          axis.normalize!
          direction = view.camera.direction
          normal = axis.cross(direction)
          return nil if normal.length < 1.0e-9
          normal.normalize!
          hit = Geom.intersect_line_plane(ray, [@first, normal])
          return nil unless hit
          offset = @first.vector_to(hit)
          offset - Geom::Vector3d.new(axis.x * offset.dot(axis), axis.y * offset.dot(axis), axis.z * offset.dot(axis))
        end

        def create_dimension(first, last, offset)
          model = Sketchup.active_model
          box = Regions.active_bounds(model)
          points = [first, last, first + offset, last + offset]
          raise ArgumentError, 'Dim vượt khỏi Boundary/Detail Region đang chọn.' unless Regions.contains_part?(box, points)
          model.start_operation('VGD Dim — Dim thủ công', true)
          begin
            dimension = model.entities.add_dimension_linear(first, last, offset)
            Core.style_dim(dimension, @config['dim'], {}, true)
            model.selection.clear
            model.selection.add(dimension)
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          model.active_view.invalidate
        end
      end
    end
  end
end

