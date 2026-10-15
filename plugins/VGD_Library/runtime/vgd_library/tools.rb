# encoding: UTF-8
module VGD
  module Library
    module Tools
      def self.instance?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      def self.pick(view, x, y)
        picker = view.pick_helper
        picker.do_pick(x, y)
        paths = picker.count.times.map { |i| picker.path_at(i) }.compact
        paths.find { |path| path.last.is_a?(Sketchup::Face) } || paths.first
      end

      def self.editable!(path)
        raise 'Không chọn được đối tượng.' unless path && !path.empty?
        raise 'Đối tượng hoặc vỏ ngoài đang khóa.' if path.any? { |e| e.respond_to?(:locked?) && e.locked? }
      end

      # Recreate the picked route after make_unique. Entity indices survive a
      # definition clone, while references to the old nested face do not.
      def self.isolate_path(path)
        editable!(path)
        route = path.dup
        route.each_with_index do |entity, i|
          next unless instance?(entity)
          children = entity.definition.entities.to_a
          indices = route[(i + 1)..-1].each_cons(2).map do |parent, child|
            instance?(parent) ? parent.definition.entities.to_a.index(child) : nil
          end
          first_index = children.index(route[i + 1]) if route[i + 1]
          entity.make_unique
          next unless route[i + 1]
          raise 'Không xác định được đường chọn mặt.' unless first_index
          route[i + 1] = entity.definition.entities.to_a[first_index]
          indices.each_with_index do |index, j|
            next unless index
            route[i + j + 2] = route[i + j + 1].definition.entities.to_a[index]
          end
        end
        route
      end

      def self.effective_material(path)
        path.reverse_each do |entity|
          return entity.material if entity.respond_to?(:material) && entity.material
        end
        Geometry.selection_inherited(Sketchup.active_model)
      end

      class ClickTool
        def initialize(mode, args = {})
          @model, @mode, @args = Sketchup.active_model, mode, args
        end

        def activate
          instructions = { 'rotate_face' => 'Bấm mặt để xoay 90°; Ctrl+bấm nhập góc; Esc thoát.',
            'paint' => 'Bấm mặt để tô vật liệu đang dùng; Esc thoát.',
            'swap_pick' => 'Bấm vật liệu muốn giữ (A), rồi bấm vật liệu cần thay (B).',
            'replace_pick' => 'Bấm đối tượng muốn giữ (A), rồi bấm đối tượng cần thay (B).' }
          Sketchup.status_text = 'VGD: ' + instructions.fetch(@mode)
        end

        def onMouseMove(_flags, x, y, view)
          @path = Tools.pick(view, x, y)
          view.tooltip = @path ? (@mode == 'replace_pick' ? 'Chọn group/component' : 'Chọn mặt/vật liệu') : ''
        end

        def onLButtonDown(flags, x, y, view)
          raise 'Model đã đổi; mở lại công cụ.' unless Sketchup.active_model.equal?(@model)
          path = Tools.pick(view, x, y)
          Tools.editable!(path)
          case @mode
          when 'rotate_face', 'paint'
            raise 'Bấm vào một mặt.' unless path.last.is_a?(Sketchup::Face)
            angle = 90.0
            if @mode == 'rotate_face' && (flags & COPY_MODIFIER_MASK) != 0
              input = UI.inputbox(['Góc xoay (độ)'], [90], 'VGD — Xoay map từng mặt')
              return unless input
              angle = Float(input[0])
              raise 'Góc xoay không hợp lệ.' unless angle.finite? && angle.abs <= 360_000
            end
            result = Library.transaction(@mode == 'paint' ? 'Tô từng mặt' : 'Xoay map từng mặt') do |model|
              route = Tools.isolate_path(path)
              material = @mode == 'paint' ? Materials.current(model) : Tools.effective_material(route)
              raise 'Chọn vật liệu trước khi tô.' unless material
              if @mode == 'paint'
                route.last.material = material
                Materials.remember(model, material)
              else
                raise 'Mặt chưa có vật liệu ảnh.' unless material.texture
                Geometry.transform(route.last, material, angle * Math::PI / 180.0)
              end
              'Đã sửa mặt vừa bấm. Ctrl+Z để hoàn tác.'
            end
            Library.message(result)
          when 'swap_pick'
            material = Tools.effective_material(path)
            raise 'Đối tượng chưa có vật liệu.' unless material
            if !@source
              @source = material
              Sketchup.status_text = "VGD: giữ #{@source.display_name}; bấm vật liệu B cần thay."
            else
              result = Library.transaction('Thay vật liệu bằng chuột') { |model| Advanced.swap_material(model, material, @source, @args.fetch('scope', 'model')) }
              Materials.remember(@model, @source)
              Library.message(result)
              @model.select_tool(nil)
            end
          when 'replace_pick'
            instance = path.reverse.find { |e| Tools.instance?(e) }
            raise 'Bấm vào group hoặc component.' unless instance
            if !@source
              @source = instance
              Sketchup.status_text = "VGD: giữ #{@source.definition.name}; bấm đối tượng B cần thay."
            else
              raise 'Đối tượng A không còn tồn tại.' unless @source.valid?
              result = Library.transaction('Thay thế đối tượng') do |model|
                if @args.fetch('replace_scope', 'family') == 'one'
                  raise 'Không thể thay đối tượng bằng chính họ component đó.' if @source.definition == instance.definition
                  index = path.index(instance)
                  instance = Tools.isolate_path(path[0..index]).last
                end
                Replacement.apply(model, @source, instance, @args)
              end
              Library.message(result)
              @model.select_tool(nil)
            end
          end
          view.invalidate
        rescue StandardError => e
          Library.message(e.message, true)
        end

        def onCancel(_reason, _view)
          @model.select_tool(nil)
        end
      end
    end

    module Replacement
      def self.family(definition)
        [definition.name.to_s.sub(/#\d+\z/, ''), definition.get_attribute('dynamic_attributes', 'name', '').to_s]
      end

      def self.descendant?(root, candidate, seen = {})
        return true if root == candidate
        return false if seen[root.object_id]
        seen[root.object_id] = true
        root.entities.any? { |e| Tools.instance?(e) && descendant?(e.definition, candidate, seen) }
      end

      def self.bounds_transform(old_bounds, new_bounds)
        old_size = [old_bounds.width, old_bounds.height, old_bounds.depth]
        new_size = [new_bounds.width, new_bounds.height, new_bounds.depth]
        scales = old_size.zip(new_size).map { |old, fresh| fresh.abs < 1.0e-8 ? 1.0 : old / fresh }
        Geom::Transformation.translation(old_bounds.min.to_a) * Geom::Transformation.scaling(*scales) * Geom::Transformation.translation(new_bounds.min.to_a.map { |v| -v })
      end

      def self.apply(model, source, target, args)
        raise 'Chọn hai đối tượng khác nhau.' if source == target
        raise 'Đóng chế độ sửa trước khi thay thế đối tượng.' if model.active_path
        definition = source.definition
        raise 'Không thể thay đối tượng bằng chính họ component đó.' if definition == target.definition
        # Prevent a recursive definition (placing a parent inside its own child).
        targets = if args.fetch('replace_scope', 'family') == 'one'
                    [target]
                  else
                    matches = model.definitions.select { |d| d == target.definition || (!target.is_a?(Sketchup::Group) && family(d) == family(target.definition)) }
                    if matches.any? { |candidate| descendant?(definition, candidate) }
                      raise 'Đối tượng A chứa mẫu B bên trong; không thể tạo vòng lồng component.'
                    end
                    collected = []
                    contains = lambda do |d, seen|
                      next true if matches.include?(d)
                      next false if seen[d.object_id]
                      seen[d.object_id] = true
                      d.entities.any? { |e| Tools.instance?(e) && contains.call(e.definition, seen) }
                    end
                    visit = lambda do |entities, depth|
                      raise 'Cấu trúc quá sâu.' if depth > 64
                      entities.each do |e|
                        next unless Tools.instance?(e) && e.valid? && !e.locked? && !e.hidden? && e != source
                        if matches.include?(e.definition)
                          collected << e
                        elsif contains.call(e.definition, {})
                          e.make_unique
                          visit.call(e.definition.entities.to_a, depth + 1)
                        end
                      end
                    end
                    visit.call(model.entities.to_a, 0)
                    collected
                  end
        targets = targets.uniq.select { |e| e.valid? && !e.locked? && !e.hidden? && e != source }
        raise 'Không có đối tượng thay thế hợp lệ.' if targets.empty?
        targets.each do |instance|
          parent = instance.parent
          raise 'Đối tượng B nằm trong A; không thể tạo vòng lồng component.' if parent.is_a?(Sketchup::ComponentDefinition) && descendant?(definition, parent)
        end
        count = 0
        targets.each do |instance|
          old_definition = instance.definition
          old_transform = instance.transformation
          old_bounds = old_definition.bounds
          attributes = instance.attribute_dictionary('dynamic_attributes')
          saved = attributes ? attributes.each_pair.to_h : {}
          instance = instance.to_component if instance.is_a?(Sketchup::Group)
          instance.definition = definition
          if args.fetch('keep_size', true)
            instance.transformation = old_transform * bounds_transform(old_bounds, definition.bounds)
          else
            instance.transformation = old_transform
          end
          # Instance properties (tag/name/material/other dictionaries) stay on B.
          # Copy defaults from A, then compatible values and size/position from B.
          defaults = source.attribute_dictionary('dynamic_attributes')
          defaults.each_pair { |key, value| instance.set_attribute('dynamic_attributes', key, value) } if defaults
          compatible = definition.attribute_dictionary('dynamic_attributes')
          saved.each do |key, value|
            if key.match?(/\A_?(?:len[xyz]|[xyz]|rot[xyz])(?:_.*)?\z/i) || (compatible && compatible.keys.include?(key)) || (defaults && defaults.keys.include?(key))
              instance.set_attribute('dynamic_attributes', key, value)
            end
          end
          if args.fetch('redraw_dc', true) && compatible && defined?($dc_observers) && $dc_observers
            instance.make_unique
            redraw = $dc_observers.get_latest_class
            redraw.redraw(instance) if redraw && redraw.respond_to?(:redraw)
          end
          count += 1
        end
        "Đã thay #{count} đối tượng; giữ vị trí, thuộc tính instance#{args.fetch('keep_size', true) ? ' và kích thước' : ''}. Ctrl+Z để hoàn tác."
      end
    end
  end
end
