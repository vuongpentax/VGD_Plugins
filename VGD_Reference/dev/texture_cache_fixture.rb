module VGD
  module Reference
    class TextureCacheFixtureView
      attr_reader :loaded, :released

      def initialize(texture_id)
        @texture_id = texture_id
        @loaded = []
        @released = []
      end

      def load_texture(image_rep)
        @loaded << image_rep
        @texture_id
      end

      def release_texture(texture_id)
        @released << texture_id
        true
      end
    end

    old_view = TextureCacheFixtureView.new(41)
    draw_view = TextureCacheFixtureView.new(84)
    item = Struct.new(:id, :texture_id).new('fixture', 41)
    base_rep = Object.new
    active_rep = Object.new
    TextureCache.entries.clear
    TextureCache.entries['fixture'] = {
      view: old_view, texture_id: 41, base_rep: base_rep,
      active_rep: active_rep, opacity_baked: 100
    }

    texture_id = TextureCache.texture_for(item, draw_view)
    raise 'Overlay did not bind a texture to its draw view.' unless texture_id == 84
    raise 'Previous view texture was not released.' unless old_view.released == [41]
    raise 'Draw view did not load the active ImageRep.' unless draw_view.loaded == [active_rep]
    raise 'Texture cache lost the active ImageRep.' unless TextureCache.entries['fixture'][:active_rep].equal?(active_rep)
    raise 'Reference item did not receive the new texture ID.' unless item.texture_id == 84

    TextureCache.entries.clear
    puts 'PASS: overlay textures are rebound to the draw view without changing the active ImageRep.'
  end
end
