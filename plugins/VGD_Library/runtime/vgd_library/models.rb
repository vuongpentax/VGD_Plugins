# encoding: UTF-8
module VGD
  module Library
    module Models
      def self.insert(item)
        path = item[:path]
        raise 'Không thấy model. Hãy quét lại thư viện.' unless File.file?(path)
        model = Sketchup.active_model
        definition = Library.transaction('Nạp model thư viện') do |active|
          active.definitions.load(path)
        end
        raise 'Không đọc được model. Kiểm tra phiên bản SketchUp lưu tệp.' unless definition && definition.valid?
        model.select_tool(PlacementTool.new(model, definition))
        'Bấm để đặt model. Phím ←/→ xoay 90°, Esc thoát.'
      end

      def self.save_selected
        model = Sketchup.active_model
        instances = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        raise 'Chọn đúng một group/component để lưu vào thư viện.' unless instances.size == 1
        definition = instances.first.definition
        path = UI.savepanel('Lưu model vào thư viện', Catalog.roots.first, Storage.safe_name(definition.name) + '.skp')
        return 'Đã hủy lưu model.' unless path
        path += '.skp' unless File.extname(path).downcase == '.skp'
        raise 'Không lưu được model.' unless definition.save_copy(path)
        definition.save_thumbnail(path.sub(/\.skp\z/i, '.png'))
        'Đã lưu SKP và thumbnail. Bấm Làm mới để cập nhật thư viện.'
      end

      class PlacementTool
        def initialize(model, definition)
          @model, @definition = model, definition
          @input = Sketchup::InputPoint.new
          @angle = 0
          @edges = []
          collect(definition.entities, Geom::Transformation.new, 0)
        end

        def collect(entities, transform, depth)
          return if depth > 8 || @edges.size >= 12_000
          entities.each do |entity|
            next if entity.hidden?
            if entity.is_a?(Sketchup::Edge)
              @edges << [entity.start.position.transform(transform), entity.end.position.transform(transform)]
            elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
              collect(entity.definition.entities, transform * entity.transformation, depth + 1)
            end
            break if @edges.size >= 12_000
          end
        end

        def activate
          Sketchup.status_text = 'VGD: bấm để đặt model; ←/→ xoay 90°; Esc thoát.'
        end

        def valid?
          Sketchup.active_model.equal?(@model) && @definition.valid?
        end

        def transform
          Geom::Transformation.translation(@input.position.to_a) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, @angle * Math::PI / 180)
        end

        def onMouseMove(_flags, x, y, view)
          return @model.select_tool(nil) unless valid?
          @input.pick(view, x, y)
          view.tooltip = @input.tooltip if @input.valid?
          view.invalidate
        end

        def onKeyDown(key, _repeat, _flags, view)
          @angle += 90 if key == 39
          @angle -= 90 if key == 37
          view.invalidate
        end

        def onLButtonDown(_flags, x, y, view)
          return @model.select_tool(nil) unless valid?
          @input.pick(view, x, y)
          return unless @input.valid?
          instance = Library.transaction('Đặt model thư viện') { |model| model.active_entities.add_instance(@definition, transform) }
          @model.selection.clear
          @model.selection.add(instance)
          @model.select_tool(nil)
        rescue StandardError => e
          Library.message(e.message, true)
        end

        def draw(view)
          return unless valid? && @input.valid?
          view.drawing_color = '#a78968'
          view.line_width = 1
          t = transform
          points = @edges.flatten.map { |p| p.transform(t) }
          view.draw(GL_LINES, points) unless points.empty?
          @input.draw(view)
        end

        def onCancel(_reason, _view)
          @model.select_tool(nil)
        end
      end
    end
  end
end
