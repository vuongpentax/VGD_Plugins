# encoding: UTF-8
require 'json'

module VGD_ImageImporter
  SUPPORTED = %w[.jpg .jpeg .jfif .jpe .png .apng .bmp .dib .tif .tiff .tga .webp .gif .avif .ico .svg .heic .heif].freeze
  CONVERTED = %w[.jfif .jpe .apng .dib .webp .gif .avif .ico .svg .heic .heif].freeze
  MIME = { '.jfif' => 'image/jpeg', '.jpe' => 'image/jpeg', '.apng' => 'image/png',
    '.dib' => 'image/bmp', '.webp' => 'image/webp', '.gif' => 'image/gif', '.avif' => 'image/avif',
    '.ico' => 'image/x-icon', '.svg' => 'image/svg+xml' }.freeze
  DEFAULTS = {
    'importType' => 'comp_2d', 'scaleMethod' => 'pixel', 'mmPerPixel' => 2.0,
    'targetHeight' => 2000.0, 'targetWidth' => 2000.0, 'spacing' => 500.0,
    'itemsPerRow' => 10, 'alwaysFaceCamera' => true, 'recursive' => false,
    'theme' => 'dark'
  }.freeze

  def self.options(input)
    raise ArgumentError, 'Cấu hình không hợp lệ.' unless input.is_a?(Hash)
    cfg = DEFAULTS.merge(input.select { |key, _| DEFAULTS.key?(key) })
    raise ArgumentError, 'Loại nhập không hợp lệ.' unless %w[comp_2d flat texture_only].include?(cfg['importType'])
    raise ArgumentError, 'Cách tính kích thước không hợp lệ.' unless %w[pixel height width].include?(cfg['scaleMethod'])
    %w[mmPerPixel targetHeight targetWidth spacing].each do |key|
      number = Float(cfg[key])
      raise ArgumentError, "#{key}: cần số #{key == 'spacing' ? 'không âm' : 'dương'}." unless number.finite? && (key == 'spacing' ? number >= 0 : number > 0)
      cfg[key] = number
    end
    count = Float(cfg['itemsPerRow'])
    raise ArgumentError, 'Số ảnh mỗi hàng phải là số nguyên từ 1 đến 1000.' unless count.finite? && count == count.to_i && count.between?(1, 1000)
    cfg['itemsPerRow'] = count.to_i
    %w[alwaysFaceCamera recursive].each { |key| cfg[key] = cfg[key] == true }
    cfg['theme'] = cfg['theme'] == 'dark' ? 'dark' : 'light'
    cfg
  rescue TypeError, ArgumentError => error
    raise ArgumentError, error.message
  end

  def self.image_file?(path)
    File.file?(path) && SUPPORTED.include?(File.extname(path).downcase)
  end

  def self.normalize_files(paths)
    paths.map { |path| File.expand_path(path).tr('\\', '/') }.select { |path| image_file?(path) }
      .uniq { |path| Sketchup.platform == :platform_win ? path.downcase : path }
      .sort_by { |path| path.downcase.gsub(/\d+/) { |digits| format('%020d', digits.to_i) } }
  end

  def self.folder_files(directory, recursive = false)
    files = []
    # Do not follow directory symlinks/junctions into recursive cycles.
    pending = [File.realpath(directory)]
    visited = {}
    until pending.empty?
      folder = pending.shift
      real = File.realpath(folder)
      next if visited[real]
      visited[real] = true
      Dir.children(folder).each do |name|
        path = File.join(folder, name)
        if image_file?(path)
          files << path
        elsif recursive && File.directory?(path) && !File.symlink?(path)
          pending << path
        end
      end
    end
    normalize_files(files)
  end

  def self.dimensions(pixel_width, pixel_height, cfg)
    pw, ph = Float(pixel_width), Float(pixel_height)
    raise ArgumentError, 'Không đọc được kích thước ảnh.' unless pw.finite? && ph.finite? && pw > 0 && ph > 0
    case cfg['scaleMethod']
    when 'height'
      height = cfg['targetHeight'] / 25.4
      [height * pw / ph, height]
    when 'width'
      width = cfg['targetWidth'] / 25.4
      [width, width * ph / pw]
    else
      [pw * cfg['mmPerPixel'] / 25.4, ph * cfg['mmPerPixel'] / 25.4]
    end
  end

  def self.read_pixels(path)
    image = Sketchup::ImageRep.new
    # SketchUp 2022 load_file returns nil on SUCCESS. It raises for bad data.
    # Check actual decoded dimensions, not the undocumented return value.
    image.load_file(path)
    raise ArgumentError, 'Ảnh có kích thước không hợp lệ.' unless image.width > 0 && image.height > 0
    [image.width, image.height]
  end

  def self.import_one(model, entities, path, cfg, x, y, prepared_path = path)
    width, height = dimensions(*read_pixels(prepared_path), cfg)
    name = File.basename(path, '.*')
    if cfg['importType'] == 'texture_only'
      # Always add a new material; never replace an existing model material.
      material = model.materials.add("VGD_#{name}")
      begin
        material.texture = prepared_path
        material.texture.size = [width, height]
      rescue StandardError
        model.materials.remove(material)
        raise
      end
      return [width, height]
    end
    definition = model.definitions.add(name)
    instance = nil
    begin
      image = definition.entities.add_image(prepared_path, ORIGIN, width)
      raise 'Không tạo được ảnh trong component.' unless image
      definition.entities.transform_entities(Geom::Transformation.translation([-width / 2, 0, 0]), [image])
      if cfg['importType'] == 'comp_2d'
        definition.entities.transform_entities(Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees), [image])
        definition.behavior.always_face_camera = cfg['alwaysFaceCamera']
      end
      definition.set_attribute('VGD_ImageImporter', 'source', path)
      instance = entities.add_instance(definition, Geom::Transformation.translation([x + width / 2, y, 0]))
      raise 'Không đặt được component.' unless instance
    rescue StandardError
      instance.erase! if instance && instance.valid?
      model.definitions.remove(definition)
      raise
    end
    [width, height]
  end

  def self.process_import(input, files = @files, prepared = {}, preparation_errors = {})
    cfg = options(input)
    paths = Array(files).uniq
    raise ArgumentError, 'Chưa chọn ảnh để nhập.' if paths.empty?
    model = Sketchup.active_model
    entities = model.active_entities
    successes, errors = [], []
    x = y = row_height = 0.0
    row_count = 0
    spacing = cfg['spacing'] / 25.4
    model.start_operation('VGD · Nhập ảnh', true)
    begin
      paths.each do |path|
        begin
          raise 'Ảnh đã bị xóa hoặc không được hỗ trợ.' unless image_file?(path)
          raise preparation_errors[path] if preparation_errors.key?(path)
          width, height = import_one(model, entities, path, cfg, x, y, prepared.fetch(path, path))
          successes << path
          next if cfg['importType'] == 'texture_only'
          x += width + spacing
          row_height = [row_height, height].max
          row_count += 1
          if row_count == cfg['itemsPerRow']
            x = 0.0
            y += row_height + spacing
            row_height = 0.0
            row_count = 0
          end
        rescue StandardError => error
          errors << { 'name' => File.basename(path), 'message' => error.message }
        end
      end
      successes.empty? ? model.abort_operation : model.commit_operation
    rescue StandardError
      model.abort_operation
      raise
    end
    { 'imported' => successes.length, 'failed' => errors.length, 'errors' => errors }
  end
end
