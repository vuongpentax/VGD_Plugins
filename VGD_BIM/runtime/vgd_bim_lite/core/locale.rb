require 'json'
module VGD
  module BIM
    module Locale
      def self.dictionary
        @dictionary ||= JSON.parse(File.read(File.expand_path('../config/vi.json', __dir__), encoding: 'UTF-8'))
      end
      def self.label(group, value)
        dictionary.fetch(group.to_s, {}).fetch(value.to_s, value.to_s)
      end
      def self.field(key); label('fields', key); end
      def self.value(key, value)
        return value ? 'Có' : 'Không' if value == true || value == false
        label(key, value)
      end
    end
  end
end
