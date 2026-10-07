# frozen_string_literal: true
module VGD_Cabinet
  # The production builder writes into this in-memory sink. No temporary model
  # entities, operations, materials, tags or component definitions are created.
  class PreviewMesh
    %i[Face Guide Model].each { |name| remove_const(name) if const_defined?(name,false) }
    Face = Struct.new(:points, :normal, :material) do
      def reverse!; self.normal = normal.reverse; end
      def pushpull(distance)
        base = points.dup
        top = base.map { |p| p.offset(normal, distance) }
        @polygons = [base.reverse, top] + base.each_index.map { |i| [base[i], base[(i+1)%base.size], top[(i+1)%base.size], top[i]] }
      end
      def polygons; @polygons || [points]; end
      def vertices; polygons.flatten.map { |p| Struct.new(:position).new(p) }; end
      def outer_loop; Struct.new(:vertices).new(points.map { |p| Struct.new(:position).new(p) }); end
      def erase!; @erased = true; end
      def valid?; !@erased; end
    end
    Guide = Struct.new(:a, :b, :layer)
    class Entities < Array
      def add_group; group = Group.new; self << group; group; end
      def add_face(points)
        points = points.map { |p| p.is_a?(Geom::Point3d) ? p : Geom::Point3d.new(p) }
        normal = nil
        (1...points.size-1).each do |i|
          n = (points[i]-points[0]).cross(points[i+1]-points[0])
          if n.length > 1e-10
            normal = n.normalize; break
          end
        end
        raise ModelingRules::Invalid, 'Mặt preview quá nhỏ.' unless normal
        face = Face.new(points, normal); self << face; face
      end
      def add_cline(a, b); guide = Guide.new(a, b); self << guide; guide; end
      def grep(klass)
        return select { |e| e.is_a?(Face) && e.valid? } if klass == Sketchup::Face
        return [] if klass == Sketchup::Edge
        super
      end
      def transform_entities(tr, items)
        items.each { |item| item.transform!(tr) if item.respond_to?(:transform!) }
      end
      def clear!; clear; end
    end
    class Group
      attr_accessor :name, :layer, :material, :transformation
      attr_reader :entities
      def initialize; @entities = Entities.new; @name = ''; @transformation = Geom::Transformation.new; end
      def transform!(tr); @transformation = tr * @transformation; end
      def to_component; self; end
      def definition; self; end
      def set_attribute(*); end
      def valid?; !@erased; end
      def erase!; @erased = true; end
    end
    class Palette < Hash
      remove_const(:Material) if const_defined?(:Material,false)
      Material = Struct.new(:name, :color, :alpha)
      def add(name); self[name] = Material.new(name); end
    end
    Model = Struct.new(:layers, :materials)
    attr_reader :surfaces, :guides, :bounds
    def self.from_data(data)
      mesh=allocate
      surfaces=data.fetch('surfaces').map { |points,kind| [points.map { |p| Geom::Point3d.new(p) },kind.to_sym] }
      guides=data.fetch('guides',[]).map { |line| line.map { |p| Geom::Point3d.new(p) } }
      bounds=Geom::BoundingBox.new; surfaces.each { |points,_| bounds.add(points) }
      mesh.instance_variable_set(:@surfaces,surfaces); mesh.instance_variable_set(:@guides,guides); mesh.instance_variable_set(:@bounds,bounds)
      mesh
    end
    def self.from_definition(definition,transform=Geom::Transformation.new)
      mesh=from_data('surfaces'=>[],'guides'=>[])
      mesh.collect_native(definition.entities,transform,[],[])
      mesh
    end
    def collect_native(entities,transform,names,ancestors)
      raise ModelingRules::Invalid,'Mẫu tủ quá phức tạp để lưu preview.' if @surfaces.size>60_000 || ancestors.size>32
      entities.each do |entity|
        next if entity.respond_to?(:hidden?) && entity.hidden?
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          definition=entity.definition
          next if ancestors.include?(definition)
          collect_native(definition.entities,transform*entity.transformation,names+[entity.name.to_s,definition.name.to_s],ancestors+[definition])
        elsif entity.is_a?(Sketchup::Face)
          polygon_mesh=entity.mesh
          polygon_mesh.polygons.each do |indices|
            points=indices.map { |index| polygon_mesh.point_at(index.abs).transform(transform) }
            @bounds.add(points)
            @surfaces << [points,names.any? { |name| name.start_with?('Cánh','Mặt Ngăn Kéo') } ? :front : :body]
          end
        elsif entity.is_a?(Sketchup::ConstructionLine) && entity.start && entity.end
          @guides << [entity.start.transform(transform),entity.end.transform(transform)]
        end
      end
    end
    def to_data
      {'surfaces'=>@surfaces.map { |poly,kind| [poly.map(&:to_a),kind.to_s] },'guides'=>@guides.map { |line| line.map(&:to_a) }}
    end
    def initialize(params)
      previous = Thread.current[:vgd_cabinet_preview_model]
      layers = Palette.new; layers[0] = 'Untagged'
      Thread.current[:vgd_cabinet_preview_model] = Model.new(layers, Palette.new)
      entities = Entities.new
      Modeling.draw(entities, params)
      @surfaces = []; @guides = []; @bounds = Geom::BoundingBox.new
      collect(entities, Geom::Transformation.new, [])
    ensure
      Thread.current[:vgd_cabinet_preview_model] = previous
    end
    def collect(entities, transform, names)
      entities.each do |entity|
        if entity.is_a?(Group) && entity.valid?
          collect(entity.entities, transform * entity.transformation, names + [entity.name])
        elsif entity.is_a?(Face) && entity.valid?
          entity.polygons.each do |polygon|
            world = polygon.map { |p| p.transform(transform) }
            @bounds.add(world)
            @surfaces << [world, names.any? { |name| name.start_with?('Cánh', 'Mặt Ngăn Kéo') } ? :front : :body]
          end
        elsif entity.is_a?(Guide)
          @guides << [entity.a.transform(transform), entity.b.transform(transform)]
        end
      end
    end
    def draw(view, transform)
      # Painter order gives a translucent X-ray overlay without changing model style.
      eye = view.camera.eye
      direction = view.camera.direction
      projected = @surfaces.filter_map do |polygon, kind|
        points = polygon.map { |p| p.transform(transform) }
        next if points.any? { |p| (p-eye).dot(direction) <= 0 }
        distance = points.sum { |p| p.distance(eye) } / points.size
        screen_points=points.map { |p| screen=view.screen_coords(p); Geom::Point3d.new(screen.x,screen.y,0) }
        area=screen_points.each_index.sum { |i| a=screen_points[i]; b=screen_points[(i+1)%screen_points.size]; a.x*b.y-b.x*a.y }
        next if area.abs<1e-6 # Edge-on faces cannot be tessellated.
        screen_points.reverse! if area<0
        [distance, screen_points, kind]
      end.sort_by { |distance, _, _| -distance }
      projected.each do |_, points, kind|
        view.drawing_color = Sketchup::Color.new(180, 137, 99, kind == :front ? 52 : 28)
        # Face outlines include curved boards and rail rebates from the actual builder.
        triangles = Geom.tesselate(points)
        view.draw2d(GL_TRIANGLES, triangles) unless triangles.empty?
      end
      view.line_width = 1; view.line_stipple = ''
      view.drawing_color = Sketchup::Color.new(125, 89, 58, 155)
      projected.each { |_, points, _| view.draw2d(GL_LINE_LOOP, points) }
      view.line_stipple = '-'; view.drawing_color = Sketchup::Color.new(125, 89, 58, 185)
      @guides.each do |line|
        world = line.map { |p| p.transform(transform) }
        next if world.any? { |p| (p-eye).dot(direction) <= 0 }
        view.draw2d(GL_LINES, world.map { |p| view.screen_coords(p) })
      end
    ensure
      view.line_stipple = ''; view.line_width = 1
    end
  end
end
