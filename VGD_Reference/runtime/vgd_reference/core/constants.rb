module VGD
  module Reference
    VERSION = '1.0.0-beta.6'.freeze
    MIN_SKETCHUP_VERSION = 23
    OVERLAY_ID = 'vgd.reference.images'.freeze
    OVERLAY_NAME = 'VGD Reference'.freeze
    FILE_EXTENSIONS = %w[.jpg .jpeg .png].freeze
    MIN_FRAME_SIZE = 80.0
    DEFAULT_FRAME_RATIO = 0.36
    HANDLE_SIZE = 9.0
    CROP_MIN_SPAN = 0.02
    OPACITY_MIN = 10
    TEMP_PREFIX = 'vgd_reference'.freeze
  end
end
