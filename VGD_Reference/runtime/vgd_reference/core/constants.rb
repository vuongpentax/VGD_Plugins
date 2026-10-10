module VGD
  module Reference
    VERSION = '1.0.0-beta.7'.freeze
    MIN_SKETCHUP_VERSION = 23
    OVERLAY_ID = 'vgd.reference.images'.freeze
    OVERLAY_NAME = 'VGD Reference'.freeze
    FILE_EXTENSIONS = %w[.jpg .jpeg .jfif .jpe .png .apng .bmp .dib .tif .tiff .tga .webp .gif .avif .ico .cur .svg .heic .heif .jp2 .j2k .jxr .wdp .hdp].freeze
    MAX_IMAGE_BYTES = 20 * 1024 * 1024
    MAX_CONVERTED_BYTES = 64 * 1024 * 1024
    MAX_IMAGE_PIXELS = 32_000_000
    TRANSFER_CHUNK_BYTES = 192 * 1024
    MIN_FRAME_SIZE = 80.0
    DEFAULT_FRAME_RATIO = 0.36
    HANDLE_SIZE = 9.0
    CROP_MIN_SPAN = 0.02
    OPACITY_MIN = 10
    TEMP_PREFIX = 'vgd_reference'.freeze
  end
end
