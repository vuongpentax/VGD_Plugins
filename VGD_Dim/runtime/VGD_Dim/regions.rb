# encoding: UTF-8
module VGD
  module Dim
    module Regions
      extend self
      DICT = 'VGD_Dim_Regions'.freeze unless const_defined?(:DICT, false)
      OWNER = 'VGD Dim'.freeze unless const_defined?(:OWNER, false)
      EPSILON = 0.01.mm unless const_defined?(:EPSILON, false)

      def state(model)
        value = JSON.parse(model.get_attribute(DICT, 'state', '{}'))
        value.is_a?(Hash) ? value : {}
      rescue JSON::ParserError, TypeError
        {}
      end

      def public_state(model)
        value = state(model)
        boundary = value['boundary']
        details = Array(value['details']).map { |r| {'id'=>r['id'], 'name'=>r['name']} }
        {'boundary'=>boundary && boundary['name'], 'details'=>details,
         'active_detail'=>value['active_detail'].to_s}
      end

      def active_record(model)
        value = state(model)
        id = value['active_detail'].to_s
        detail = Array(value['details']).find { |r| r['id'].to_s == id } unless id.empty?
        detail || value['boundary']
      end

      def bounds(record)
        return nil unless record.is_a?(Hash) && record['min'].is_a?(Array) && record['max'].is_a?(Array)
        {'min'=>record['min'].map(&:to_f), 'max'=>record['max'].map(&:to_f)}
      end

      def active_bounds(model)
        bounds(active_record(model))
      end

      def contains?(box, point, tolerance=EPSILON)
        return true unless box
        p = point.to_a
        3.times.all? { |i| p[i] >= box['min'][i] - tolerance && p[i] <= box['max'][i] + tolerance }
      end

      def contains_part?(box, points)
        return true unless box
        points.all? { |point| contains?(box, point) }
      end

      def corners(first, second)
        lo = 3.times.map { |i| [first.to_a[i], second.to_a[i]].min }
        hi = 3.times.map { |i| [first.to_a[i], second.to_a[i]].max }
        (0..7).map { |i| Geom::Point3d.new(3.times.map { |axis| ((i & (1 << axis)) != 0) ? hi[axis] : lo[axis] }) }
      end

      def record_bounds(first, second)
        points = corners(first, second)
        lo = 3.times.map { |i| [first.to_a[i], second.to_a[i]].min }
        hi = 3.times.map { |i| [first.to_a[i], second.to_a[i]].max }
        raise ArgumentError, 'Boundary cần có chiều dài, rộng và cao lớn hơn 0.' if 3.times.any? { |i| hi[i] - lo[i] <= EPSILON }
        {'min'=>lo, 'max'=>hi}
      end

      def root_context!(model)
        raise ArgumentError, 'Thoát khỏi Group/Component đang sửa rồi mới đặt vùng.' unless Array(model.active_path).empty?
      end

      def begin_pick(type, name='')
        model = Sketchup.active_model
        root_context!(model)
        raise ArgumentError, 'Loại vùng không hợp lệ.' unless %w[boundary detail].include?(type)
        clean_name = name.to_s.strip
        if type == 'detail'
          raise ArgumentError, 'Nhập tên Detail Region.' if clean_name.empty?
          raise ArgumentError, 'Tên Detail Region quá dài (tối đa 64 ký tự).' if clean_name.length > 64
          current = state(model)
          raise ArgumentError, 'Hãy tạo Boundary trước.' unless current['boundary']
          duplicate = Array(current['details']).any? { |r| r['name'].casecmp(clean_name).zero? }
          raise ArgumentError, 'Tên Detail Region đã tồn tại.' if duplicate
        end
        model.select_tool(PickTool.new(type, clean_name))
        true
      end

      def save(model, type, name, first, second)
        box = record_bounds(first, second)
        current = state(model)
        if type == 'detail'
          boundary = bounds(current['boundary'])
          raise ArgumentError, 'Detail Region phải nằm hoàn toàn trong Boundary.' unless boundary && corners(first, second).all? { |p| contains?(boundary, p) }
          raise ArgumentError, 'Đã có 64 Detail Region; hãy xóa một vùng trước.' if Array(current['details']).size >= 64
        elsif type == 'boundary'
          outside = Array(current['details']).any? do |detail|
            old = bounds(detail)
            old && (0..7).any? { |i| !contains?(box, Geom::Point3d.new(3.times.map { |axis| ((i & (1 << axis)) != 0) ? old['max'][axis] : old['min'][axis] })) }
          end
          raise ArgumentError, 'Boundary mới không chứa các Detail Region đã lưu.' if outside
        end

        id = type == 'boundary' ? 'boundary' : SecureRandom.uuid
        record = box.merge('id'=>id, 'name'=>type == 'boundary' ? 'Boundary' : name.to_s)
        model.start_operation(type == 'boundary' ? 'VGD Dim — Boundary' : 'VGD Dim — Detail Region', true)
        begin
          replace_outline(model, type, id, record)
          if type == 'boundary'
            current['boundary'] = record
          else
            current['details'] = Array(current['details']) + [record]
            current['active_detail'] = id
          end
          model.set_attribute(DICT, 'state', JSON.generate(current))
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
        record
      end

      def replace_outline(model, type, id, record)
        old = model.entities.grep(Sketchup::Group).select do |group|
          group.get_attribute(DICT, 'owner') == OWNER &&
            group.get_attribute(DICT, 'type') == type &&
            group.get_attribute(DICT, 'id') == id
        end
        old.each do |group|
          unless group.entities.size == 12 && group.entities.all? { |e| e.is_a?(Sketchup::Edge) }
            raise ArgumentError, 'Đường viền vùng có đối tượng chỉnh sửa thêm; không thay thế tự động.'
          end
        end
        group = model.entities.add_group
        group.name = type == 'boundary' ? 'VGD Boundary' : "VGD Detail — #{record['name']}"
        group.set_attribute(DICT, 'owner', OWNER)
        group.set_attribute(DICT, 'type', type)
        group.set_attribute(DICT, 'id', id)
        tag_name = type == 'boundary' ? '000 DIM BOUNDARY' : '000 DIM DETAIL'
        group.layer = model.layers[tag_name] || model.layers.add(tag_name)
        lo = record['min']; hi = record['max']
        pts = (0..7).map { |i| Geom::Point3d.new(3.times.map { |axis| ((i & (1 << axis)) != 0) ? hi[axis] : lo[axis] }) }
        (0..7).each do |i|
          3.times do |axis|
            j = i ^ (1 << axis)
            group.entities.add_line(pts[i], pts[j]) if i < j
          end
        end
        old.each(&:erase!)
      end

      def set_active(model, id)
        value = state(model)
        id = id.to_s
        unless id.empty?
          raise ArgumentError, 'Detail Region không tồn tại.' unless Array(value['details']).any? { |r| r['id'].to_s == id }
        end
        model.start_operation('VGD Dim — Chọn Detail Region', true)
        model.set_attribute(DICT, 'state', JSON.generate(value.merge('active_detail'=>id)))
        model.commit_operation
        public_state(model)
      rescue StandardError
        model.abort_operation if model
        raise
      end

      def delete_detail(model, id)
        value = state(model)
        details = Array(value['details'])
        record = details.find { |r| r['id'].to_s == id.to_s }
        raise ArgumentError, 'Chọn Detail Region cần xóa.' unless record
        groups = model.entities.grep(Sketchup::Group).select do |group|
          group.get_attribute(DICT, 'owner') == OWNER && group.get_attribute(DICT, 'type') == 'detail' && group.get_attribute(DICT, 'id').to_s == id.to_s
        end
        groups.each do |group|
          raise ArgumentError, 'Đường viền có đối tượng chỉnh sửa thêm; hãy xử lý thủ công.' unless group.entities.size == 12 && group.entities.all? { |e| e.is_a?(Sketchup::Edge) }
        end
        model.start_operation('VGD Dim — Xóa Detail Region', true)
        groups.each(&:erase!)
        value['details'] = details.reject { |r| r['id'].to_s == id.to_s }
        value['active_detail'] = '' if value['active_detail'].to_s == id.to_s
        model.set_attribute(DICT, 'state', JSON.generate(value))
        model.commit_operation
        public_state(model)
      rescue StandardError
        model.abort_operation if model
        raise
      end

      class PickTool
        def initialize(type, name)
          @type, @name = type, name
          @input = Sketchup::InputPoint.new
          @first = nil
          @cursor = nil
          @finished = false
          @failed = false
        end
        def activate
          Sketchup.status_text = @type == 'boundary' ? 'VGD Dim: Chọn góc thứ nhất của Boundary, sau đó chọn góc đối diện.' : 'VGD Dim: Chọn góc thứ nhất của Detail Region, sau đó chọn góc đối diện.'
        end
        def onMouseMove(_flags, x, y, view)
          @input.pick(view, x, y)
          @cursor = @input.position if @input.valid?
          view.invalidate
        end
        def onLButtonDown(_flags, x, y, view)
          @input.pick(view, x, y)
          return unless @input.valid?
          point = @input.position
          unless @first
            @first = point
            Sketchup.status_text = 'VGD Dim: Chọn góc đối diện để hoàn tất vùng.'
            return
          end
          record = Regions.save(Sketchup.active_model, @type, @name, @first, point)
          @finished = true
          Sketchup.active_model.select_tool(nil)
          Dialog.send_js('onRegionSaved', {'state'=>Regions.public_state(Sketchup.active_model), 'name'=>record['name']})
          Sketchup.status_text = 'VGD Dim: Đã lưu vùng.'
        rescue StandardError => error
          @failed = true
          Dialog.send_js('onError', {'message'=>error.message})
          Sketchup.active_model.select_tool(nil)
        end
        def draw(view)
          @input.draw(view) if @input.valid?
          return unless @first && @cursor
          points = Regions.corners(@first, @cursor)
          lines = []
          (0..7).each do |i|
            3.times do |axis|
              j = i ^ (1 << axis)
              lines.concat([points[i], points[j]]) if i < j
            end
          end
          view.drawing_color = Sketchup::Color.new(184, 132, 82)
          view.line_width = 2
          view.draw(GL_LINES, lines)
        end
        def onCancel(_reason, _view)
          unless @finished || @failed
            Dialog.send_js('onRegionCancelled', {})
            Sketchup.status_text = 'VGD Dim: Đã hủy đặt vùng.'
          end
        end
      end
    end
  end
end





