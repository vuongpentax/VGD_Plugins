module VGD
  module Reference
    module TextureCache
      module_function

      def load(item, view, image_rep = nil)
        return nil unless item && view
        entry = entries[item.id]
        if entry && entry[:view] == view && entry[:texture_id]
          item.texture_id = entry[:texture_id]
          return entry[:texture_id]
        end
        release_texture(entry) if entry
        base_rep = image_rep || (entry && entry[:base_rep])
        base_rep ||= load_image_rep(item)
        baked_opacity = item.opacity.to_i
        active_rep = baked_opacity < 100 ? opacity_image_rep(base_rep, baked_opacity) : base_rep
        texture_id = view.load_texture(active_rep)
        entries[item.id] = {
          view: view, texture_id: texture_id, base_rep: base_rep,
          active_rep: active_rep, opacity_baked: baked_opacity
        }
        item.texture_id = texture_id
        item.texture_dirty = false
        item.instance_variable_set(:@opacity_baked, baked_opacity)
        texture_id
      rescue StandardError => error
        ImageLoader.log_error('Texture load failed', error)
        item.texture_id = nil if item
        nil
      end

      # Texture IDs belong to the SketchUp::View that created them. Overlay#draw
      # supplies the authoritative view for the current render pass, so refresh
      # the ID if that view differs from the one used when the image was added.
      # Keep active_rep intact: during opacity preview it intentionally differs
      # from item.opacity until the slider value is committed.
      def texture_for(item, view)
        return nil unless item && view
        entry = entries[item.id]
        return nil unless entry
        return entry[:texture_id] if entry[:view] == view && entry[:texture_id]

        image_rep = entry[:active_rep] || entry[:base_rep]
        return nil unless image_rep

        release_texture(entry)
        texture_id = view.load_texture(image_rep)
        raise ArgumentError, 'SketchUp did not return a texture ID.' if texture_id.nil?

        entry[:view] = view
        entry[:texture_id] = texture_id
        item.texture_id = texture_id
        texture_id
      rescue StandardError => error
        ImageLoader.log_error('Texture view refresh failed', error)
        item.texture_id = nil if item
        nil
      end

      def preview_opacity(item, view)
        entry = entries[item.id]
        unless entry
          return nil unless load(item, view)
          entry = entries[item.id]
        end
        return entry[:texture_id] if entry[:opacity_baked] == 100
        replace_texture(item, entry, entry[:base_rep], 100, view)
      end

      def commit_opacity(item, view)
        entry = entries[item.id]
        return load(item, view) unless entry
        opacity = item.opacity.to_i
        image_rep = opacity == 100 ? entry[:base_rep] : opacity_image_rep(entry[:base_rep], opacity)
        replace_texture(item, entry, image_rep, opacity, view)
      rescue StandardError => error
        ImageLoader.log_error('Opacity texture failed', error)
        item.instance_variable_set(:@opacity_baked, 100)
        nil
      end

      def baked_opacity(item)
        entry = item && entries[item.id]
        entry ? entry[:opacity_baked].to_i : 100
      end

      def release_item(item_or_id)
        id = item_or_id.respond_to?(:id) ? item_or_id.id : item_or_id.to_s
        entry = entries.delete(id)
        release_texture(entry) if entry
        item_or_id.texture_id = nil if item_or_id.respond_to?(:texture_id=)
        true
      rescue StandardError => error
        ImageLoader.log_error('Texture release failed', error)
        false
      end

      def release_all(clear: false)
        entries.each_value { |entry| release_texture(entry) }
        if clear
          entries.clear
        else
          entries.each_value do |entry|
            entry[:texture_id] = nil
            entry[:active_rep] = entry[:base_rep]
            entry[:opacity_baked] = 100
          end
        end
      end

      def reload_all(items, view)
        items.each { |item| load(item, view) }
      end

      def entries
        @entries ||= {}
      end

      def load_image_rep(item)
        image, = ImageLoader.load(item.source_path, allow_bitmap: item.source_type == :clipboard)
        image
      end
      private_class_method :load_image_rep

      def release_texture(entry)
        return unless entry && entry[:texture_id] && entry[:view]
        entry[:view].release_texture(entry[:texture_id])
        entry[:texture_id] = nil
      rescue StandardError => error
        ImageLoader.log_error('Texture release failed', error)
      end
      private_class_method :release_texture

      def replace_texture(item, entry, image_rep, opacity, view)
        release_texture(entry)
        entry[:view] = view
        entry[:active_rep] = image_rep
        entry[:opacity_baked] = opacity
        entry[:texture_id] = view.load_texture(image_rep)
        item.texture_id = entry[:texture_id]
        item.texture_dirty = false
        item.instance_variable_set(:@opacity_baked, opacity)
        entry[:texture_id]
      end
      private_class_method :replace_texture

      def opacity_image_rep(base_rep, opacity)
        width = base_rep.width.to_i
        height = base_rep.height.to_i
        bpp = base_rep.bits_per_pixel.to_i
        raise ArgumentError, 'Unsupported image pixel format.' unless [24, 32].include?(bpp)
        source = base_rep.data
        source_row_bytes = width * (bpp / 8)
        source_stride = source_row_bytes + base_rep.row_padding.to_i
        target = String.new(capacity: width * height * 4, encoding: Encoding::BINARY)
        alpha_factor = opacity.to_f / 100.0
        height.times do |row|
          offset = row * source_stride
          width.times do |column|
            pixel = offset + column * (bpp / 8)
            target << source.byteslice(pixel, 3)
            source_alpha = bpp == 32 ? source.getbyte(pixel + 3) : 255
            target << [(source_alpha * alpha_factor).round].pack('C')
          end
        end
        Sketchup::ImageRep.new.set_data(width, height, 32, 0, target)
      end
      private_class_method :opacity_image_rep
    end
  end
end
