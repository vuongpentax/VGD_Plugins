# encoding: UTF-8
module VGD
  module Dim
    module Store
      def self.read(key, fallback=nil)
        raw=Sketchup.read_default('VGDDim',key,nil)
        raw ? JSON.parse(raw) : fallback
      rescue JSON::ParserError, TypeError
        fallback
      end
      def self.write(key,value)
        Sketchup.write_default('VGDDim',key,JSON.generate(value))
      end
    end
  end
end
