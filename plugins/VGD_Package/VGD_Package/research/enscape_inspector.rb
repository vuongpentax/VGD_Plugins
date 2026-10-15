# frozen_string_literal: true

require 'rexml/document'

module VGD
  module Pack
    module Research
      # Read-only inventory of model/material/entity attribute dictionaries.
      # It records path-like values for research and never mutates the model.
      module EnscapeInspector
        IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .tif .tiff .bmp .exr .hdr].freeze
        module_function

        def inspect(model = Sketchup.active_model)
          records = []
          enumerate_owners(model) do |owner, owner_info|
            begin
              dictionaries = owner.attribute_dictionaries
              next unless dictionaries
              dictionaries.each do |dictionary|
                dictionary.each_pair do |key, value|
                  begin
                    strings = extract_strings(value)
                    path_hits = strings.flat_map { |string| find_asset_strings(string) }.uniq
                    records << {
                      'owner' => owner_info,
                      'dictionary' => dictionary.name.to_s,
                      'key' => key.to_s,
                      'value' => safe_value(value),
                      'asset_candidates' => path_hits
                    }
                  rescue StandardError => e
                    records << {
                      'owner' => owner_info, 'dictionary' => dictionary.name.to_s,
                      'key' => key.to_s, 'inspection_error' => e.message
                    }
                  end
                end
              end
            rescue StandardError
              next
            end
          end

          {
            'format' => 'VGD_PACK_ENSCAPE_RESEARCH',
            'plugin_version' => PLUGIN_VERSION,
            'created_at' => Time.now.iso8601,
            'sketchup_version' => Compatibility.version,
            'model' => model.path.to_s,
            'read_only' => true,
            'search_extensions' => IMAGE_EXTENSIONS,
            'dictionary_entries' => records.length,
            'entries' => records
          }
        end

        def enumerate_owners(model)
          yield model, { 'type' => 'model' }
          model.materials.each do |material|
            yield material, { 'type' => 'material', 'name' => material.name.to_s }
          end
          visited = {}
          walk_entities(model.entities, visited) { |entity| yield entity, entity_identity(entity) }
          model.definitions.each do |definition|
            next if definition.respond_to?(:image?) && definition.image?
            key = definition.entityID rescue definition.object_id
            unless visited[key]
              yield definition, definition_identity(definition)
              visited[key] = true
            end
            walk_entities(definition.entities, visited) { |entity| yield entity, entity_identity(entity) }
          end
        end

        def walk_entities(entities, visited, &block)
          entities.each do |entity|
            next unless entity.respond_to?(:attribute_dictionaries)
            key = entity.entityID rescue entity.object_id
            next if visited[key]
            visited[key] = true
            block.call(entity)
            if entity.respond_to?(:definition)
              definition = entity.definition rescue nil
              if definition && definition.respond_to?(:entities)
                walk_entities(definition.entities, visited, &block)
              end
            elsif entity.respond_to?(:entities)
              walk_entities(entity.entities, visited, &block)
            end
          end
        end

        def entity_identity(entity)
          info = { 'type' => entity.typename.to_s }
          info['name'] = entity.name.to_s if entity.respond_to?(:name) && !entity.name.to_s.empty?
          info['entity_id'] = entity.entityID if entity.respond_to?(:entityID)
          info
        rescue StandardError
          { 'type' => 'entity' }
        end

        def definition_identity(definition)
          {
            'type' => 'component_definition',
            'name' => definition.name.to_s,
            'entity_id' => definition.entityID
          }
        rescue StandardError
          { 'type' => 'component_definition' }
        end

        def extract_strings(value, depth = 0)
          return [] if depth > 12
          case value
          when String then extract_serialized_strings(value, depth + 1)
          when Array then value.flat_map { |item| extract_strings(item, depth + 1) }
          when Hash then value.values.flat_map { |item| extract_strings(item, depth + 1) }
          else []
          end
        end

        def extract_serialized_strings(text, depth)
          stripped = text.to_s.strip
          if stripped.start_with?('<')
            document = REXML::Document.new(stripped)
            xml_strings(document.root, depth)
          elsif stripped.start_with?('{', '[')
            extract_strings(JSON.parse(stripped), depth + 1)
          else
            [text]
          end
        rescue StandardError
          [text]
        end

        def xml_strings(element, depth, values = [])
          return values if !element || depth > 12
          element.attributes.each_attribute { |attribute| values << attribute.value.to_s }
          element.children.each do |child|
            if child.is_a?(REXML::Text)
              values.concat(extract_strings(child.value.to_s, depth + 1))
            elsif child.is_a?(REXML::Element)
              xml_strings(child, depth + 1, values)
            end
          end
          values
        rescue StandardError
          values
        end

        def find_asset_strings(string)
          text = string.to_s
          stripped = text.strip
          extension = /\.(?:jpg|jpeg|png|tif|tiff|bmp|exr|hdr)\z/i
          return [] unless stripped.match?(extension)
          return [] if stripped.match?(/[\u0000\r\n"'<>|]/)

          windows_path = stripped.match?(/\A[A-Z]:[\\\/]/i)
          unc_path = stripped.start_with?('\\\\')
          url = stripped.match?(/\A[a-z][a-z0-9+.-]*:\/\//i)
          return [] if url

          # Enscape stores both absolute paths and filename-only hints.
          # XML/JSON values are parsed before reaching this method, so a
          # complete image filename is the safest candidate boundary.
          return [stripped] if windows_path || unc_path

          # Enscape can also store filename-only hints such as "texture.jpg".
          [stripped]
        end

        def safe_value(value, depth = 0)
          return '[max depth]' if depth > 12
          case value
          when String, Numeric, TrueClass, FalseClass, NilClass then value
          when Array then value.map { |item| safe_value(item, depth + 1) }
          when Hash then value.each_with_object({}) { |(key, item), result| result[key.to_s] = safe_value(item, depth + 1) }
          else value.to_s
          end
        rescue StandardError
          '[unreadable]'
        end
      end
    end
  end
end
