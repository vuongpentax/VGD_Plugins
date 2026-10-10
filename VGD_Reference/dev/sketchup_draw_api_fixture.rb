# Minimal API boundary for the pure-Ruby drawing regression fixture.
GL_QUADS = 7
module Sketchup
  def self.version
    '24.0.484'
  end

  class Overlay
    def initialize(*_args); end
    def enabled?
      true
    end
  end

  class Color
    def initialize(*_args); end
  end
end

module UI
  def self.scale_factor(*_args)
    1.0
  end
end

module Geom
  class Point3d
    def initialize(*values)
      @values = values
    end
    def to_a
      @values
    end
  end
end
