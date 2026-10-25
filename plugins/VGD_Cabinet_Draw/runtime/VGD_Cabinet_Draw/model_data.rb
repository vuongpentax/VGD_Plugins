require 'json'
require 'securerandom'

module VGD_Cabinet_Draw
  module ModelData
    extend self

    # Gắn dữ liệu VGD vào một đối tượng. ID được giữ nguyên nếu đối tượng đã có;
    # revision tăng mỗi lần ghi lại.
    def stamp(entity, kind, data = {})
      dict = Schema::DICTIONARY
      existing_id = entity.get_attribute(dict, 'id')
      revision = entity.get_attribute(dict, 'revision').to_i
      entity.set_attribute(dict, 'schema', Schema::MODEL_SCHEMA)
      entity.set_attribute(dict, 'id', existing_id.to_s.empty? ? SecureRandom.uuid : existing_id)
      entity.set_attribute(dict, 'kind', kind.to_s)
      entity.set_attribute(dict, 'params_json', JSON.generate(data))
      entity.set_attribute(dict, 'revision', existing_id.to_s.empty? ? 1 : revision + 1)
      entity
    end

    # Cấp ID mới (dùng khi một bản sao mang thuộc tính của bản gốc).
    def new_id!(entity)
      dict = Schema::DICTIONARY
      entity.set_attribute(dict, 'id', SecureRandom.uuid) if entity.get_attribute(dict, 'id')
      entity
    end

    def id_for(entity)
      entity && entity.get_attribute(Schema::DICTIONARY, 'id')
    end

    def schema_version(entity)
      entity && entity.get_attribute(Schema::DICTIONARY, 'schema').to_i
    end

    # Chụp toàn bộ thuộc tính của đối tượng: { tên_từ_điển => { khóa => giá trị } }.
    def snapshot(entity)
      out = {}
      dicts = entity.attribute_dictionaries
      return out unless dicts
      dicts.each do |dict|
        out[dict.name] = {}
        dict.each_pair { |key, value| out[dict.name][key] = value }
      end
      out
    end

    # Ghi lại một ảnh chụp thuộc tính lên đối tượng.
    def restore(entity, snap)
      snap.each do |dict_name, pairs|
        pairs.each { |key, value| entity.set_attribute(dict_name, key, value) }
      end
      entity
    end

    def cabinet?(entity)
      entity && entity.get_attribute(Schema::DICTIONARY, 'kind') == 'cabinet'
    end

    def params(entity)
      JSON.parse(entity.get_attribute(Schema::DICTIONARY, 'params_json', '{}'))
    rescue JSON::ParserError
      {}
    end
  end
end
