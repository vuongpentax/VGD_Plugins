require 'json'
require 'securerandom'

module VGD_Cabinet_Draw
  module ModelData
    extend self
    def stamp(entity, kind, data = {})
      entity.set_attribute(Schema::DICTIONARY, 'schema', Schema::MODEL_SCHEMA)
      entity.set_attribute(Schema::DICTIONARY, 'id', SecureRandom.uuid)
      entity.set_attribute(Schema::DICTIONARY, 'kind', kind.to_s)
      entity.set_attribute(Schema::DICTIONARY, 'params_json', JSON.generate(data))
      entity.set_attribute(Schema::DICTIONARY, 'revision', 1)
      entity
    end

    def cabinet?(entity)
      entity && entity.get_attribute(Schema::DICTIONARY, 'kind') == 'cabinet'
    end

    def root_for(entity)
      current = entity
      while current
        return current if cabinet?(current)
        parent = current.respond_to?(:parent) ? current.parent : nil
        current = parent.respond_to?(:parent) ? parent.parent : nil
        break unless current.is_a?(Sketchup::Group) || current.is_a?(Sketchup::ComponentInstance)
      end
      nil
    rescue StandardError
      nil
    end

    def params(entity)
      JSON.parse(entity.get_attribute(Schema::DICTIONARY, 'params_json', '{}'))
    rescue JSON::ParserError
      {}
    end
  end
end
