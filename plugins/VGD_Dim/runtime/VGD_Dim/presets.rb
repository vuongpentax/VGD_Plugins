# encoding: UTF-8
module VGD
  module Dim
    module Presets
      BUILTIN={'VGD Standard'=>Core.validate_settings({})}.freeze unless const_defined?(:BUILTIN,false)
      def self.all
        custom=Store.read('presets',{})
        custom={} unless custom.is_a?(Hash)
        BUILTIN.merge(custom.reject { |name,_| BUILTIN.key?(name) })
      end
      def self.save(name,settings)
        name=name.to_s.strip
        return false if name.empty? || BUILTIN.key?(name)
        data=all.reject { |key,_| BUILTIN.key?(key) }
        data[name]=Core.validate_settings(settings)
        Store.write('presets',data)
        true
      end
      def self.delete(name)
        return false if BUILTIN.key?(name)
        data=all.reject { |key,_| BUILTIN.key?(key) }
        return false unless data.key?(name)
        data.delete(name); Store.write('presets',data)
        true
      end
    end
  end
end
