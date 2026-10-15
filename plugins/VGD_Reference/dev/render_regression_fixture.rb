# Match the drawing boundary observed in SketchUp 24.0.484: numeric UV arrays
# preserve the image, whereas Vector3d UVs render a flat sampled color.
module VGD
  module Reference
    class RenderFixtureView
      attr_accessor :drawing_color
      attr_reader :calls

      def initialize
        @calls = []
      end

      def draw2d(primitive, points, **options)
        uvs = options.fetch(:uvs)
        unless uvs.length == points.length && uvs.all? { |uv| uv.is_a?(Array) && uv.length == 3 && uv.all? { |value| value.is_a?(Numeric) } }
          raise 'UVs must be numeric arrays for the verified SketchUp 2024 drawing path.'
        end
        @calls << [primitive, points, options]
      end
    end

    previous_store = Session.instance_variable_get(:@store)
    previous_entries = TextureCache.entries.dup
    begin
      store = ReferenceStore.new
      item = ReferenceItem.new(id: 'render-fixture', source_type: :file, source_path: 'fixture.png',
                               image_width: 64, image_height: 64, x: 24, y: 48,
                               width: 140, height: 140, z_index: 1)
      store.add(item)
      Session.instance_variable_set(:@store, store)
      view = RenderFixtureView.new
      TextureCache.entries[item.id] = { view: view, texture_id: 3 }
      overlay = ReferenceOverlay.new
      overlay.draw(view)
      raise 'Textured quad was not drawn.' unless view.calls.length == 1
      _, points, options = view.calls.last
      raise 'Frame order changed.' unless points.map(&:to_a) == [[24.0, 48.0, 0], [164.0, 48.0, 0], [164.0, 188.0, 0], [24.0, 188.0, 0]]
      raise 'Full image UV orientation changed.' unless options[:uvs] == [[0.0, 1.0, 0.0], [1.0, 1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
      item.view_u0, item.view_v0, item.view_u1, item.view_v1 = 0.1, 0.2, 0.8, 0.7
      overlay.draw(view)
      expected = [[0.1, 0.8, 0.0], [0.8, 0.8, 0.0], [0.8, 0.3, 0.0], [0.1, 0.3, 0.0]]
      actual = view.calls.last[2][:uvs]
      raise 'Crop/pan UVs changed.' unless actual.flatten.zip(expected.flatten).all? { |a, b| (a - b).abs < 1e-9 }
      puts 'PASS: full and cropped image drawing uses numeric UV arrays with the correct orientation.'
    ensure
      Session.instance_variable_set(:@store, previous_store)
      TextureCache.entries.replace(previous_entries)
    end
  end
end
