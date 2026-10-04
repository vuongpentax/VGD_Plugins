require 'sketchup.rb'

module VGD_ImageImporter
  @last_dir ||= ""

  def self.show_dialog
    dialog = UI::HtmlDialog.new({
      :dialog_title => "VGD Image Importer",
      :preferences_key => "com.vgd.image_importer",
      :scrollable => false,
      :resizable => true,
      :width => 420,
      :height => 380,
      :min_width => 380,
      :min_height => 350,
      :style => UI::HtmlDialog::STYLE_DIALOG
    })

    html_content = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        * { box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #0f172a; margin: 0; padding: 12px; font-size: 12px; user-select: none; }
        .card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 6px; padding: 10px; margin-bottom: 10px; box-shadow: 0 1px 2px rgba(0,0,0,0.03); }
        .title { font-weight: 700; color: #0284c7; margin-bottom: 8px; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }
        .row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; gap: 8px; }
        .row:last-child { margin-bottom: 0; }
        .label-group { display: flex; align-items: center; gap: 5px; }
        label { font-weight: 500; }
        input[type="number"], select { padding: 4px 8px; border: 1px solid #cbd5e1; border-radius: 4px; font-size: 12px; outline: none; width: 150px; background: #fff; }
        input[type="checkbox"] { transform: scale(1.1); margin: 0; }

        .help-icon {
          display: inline-flex; align-items: center; justify-content: center; width: 15px; height: 15px; background: #e2e8f0; color: #475569; font-size: 10px; font-weight: bold; border-radius: 50%; cursor: help; transition: all 0.15s ease;
        }
        .help-icon:hover { background: #0284c7; color: #ffffff; }

        #floating-tooltip {
          position: fixed; display: none; background: #0f172a; color: #f8fafc; font-size: 11px; padding: 6px 10px; border-radius: 4px; max-width: 220px; line-height: 1.35; pointer-events: none; z-index: 9999; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); border-left: 3px solid #0284c7;
        }

        .btn-group { display: flex; gap: 8px; margin-top: 10px; }
        button { flex: 1; padding: 8px; border: none; border-radius: 5px; font-weight: 600; cursor: pointer; font-size: 12px; transition: 0.15s; }
        .btn-main { background: #0284c7; color: white; }
        .btn-main:hover { background: #0369a1; }
        .btn-sub { background: #e2e8f0; color: #475569; }
        .btn-sub:hover { background: #cbd5e1; }
      </style>
    </head>
    <body>

      <div id="floating-tooltip"></div>

      <div class="card">
        <div class="title">Nguồn & Loại Đối Tượng</div>
        <div class="row">
          <div class="label-group">
            <label>Chế độ chọn ảnh:</label>
            <span class="help-icon" data-tip="<b>Thư mục:</b> Import toàn bộ ảnh.<br><b>File lẻ:</b> Chọn từng file (bấm Cancel khi chọn xong).">?</span>
          </div>
          <select id="sourceMode">
            <option value="folder">Chọn Cả Thư Mục</option>
            <option value="files">Chọn File Lẻ</option>
          </select>
        </div>
        <div class="row">
          <div class="label-group">
            <label>Loại Import:</label>
            <span class="help-icon" data-tip="<b>Component 2D:</b> Dựng đứng, xoay camera.<br><b>Nằm phẳng:</b> Đặt phẳng trên mặt đất.<br><b>Vật liệu:</b> Chỉ lưu vào khay Materials.">?</span>
          </div>
          <select id="importType" onchange="toggleUI()">
            <option value="comp_2d">Component 2D</option>
            <option value="flat">Nằm Phẳng</option>
            <option value="texture_only">Chỉ Import Vật Liệu</option>
          </select>
        </div>
      </div>

      <div class="card">
        <div class="title">Cấu Hình Kích Thước</div>
        <div class="row">
          <div class="label-group">
            <label>Phương thức Scale:</label>
            <span class="help-icon" data-tip="<b>mm/px:</b> Phụ thuộc độ phân giải ảnh.<br><b>Chiều cao:</b> Ép toàn bộ về 1 chiều cao cố định.">?</span>
          </div>
          <select id="scaleMethod" onchange="toggleScale()">
            <option value="pixel">Theo tỉ lệ (mm/px)</option>
            <option value="height">Chiều cao cố định (mm)</option>
          </select>
        </div>
        <div class="row" id="pixelRow">
          <div class="label-group">
            <label>Tỷ lệ (mm/px):</label>
            <span class="help-icon" data-tip="Quy đổi 1 Pixel ảnh = bao nhiêu mm thực tế.">?</span>
          </div>
          <input type="number" id="mmPerPixel" step="0.1" value="2.0">
        </div>
        <div class="row" id="heightRow" style="display:none;">
          <div class="label-group">
            <label>Chiều cao target (mm):</label>
            <span class="help-icon" data-tip="Chiều cao chuẩn áp dụng cho tất cả ảnh (mm).">?</span>
          </div>
          <input type="number" id="targetHeight" value="2000">
        </div>
      </div>

      <div class="card" id="layoutCard">
        <div class="title">Sắp Xếp & Màn Hình</div>
        <div class="row" id="faceCamRow">
          <div class="label-group">
            <label>Always Face Camera:</label>
            <span class="help-icon" data-tip="Bề mặt ảnh tự động luôn xoay hướng về phía Camera.">?</span>
          </div>
          <input type="checkbox" id="alwaysFaceCamera" checked>
        </div>
        <div class="row">
          <div class="label-group">
            <label>Khoảng cách (mm):</label>
            <span class="help-icon" data-tip="Khoảng hở giữa các ảnh khi đặt trên không gian 3D.">?</span>
          </div>
          <input type="number" id="spacing" value="500">
        </div>
        <div class="row">
          <div class="label-group">
            <label>Số lượng / hàng:</label>
            <span class="help-icon" data-tip="Số lượng ảnh xếp trên 1 hàng trước khi xuống dòng.">?</span>
          </div>
          <input type="number" id="itemsPerRow" value="10">
        </div>
      </div>

      <div class="btn-group">
        <button class="btn-sub" onclick="sketchup.closeDialog()">Hủy</button>
        <button class="btn-main" onclick="submitData()">IMPORT NGAY</button>
      </div>

      <script>
        const tooltip = document.getElementById('floating-tooltip');
        let mouseX = 0, mouseY = 0;

        document.querySelectorAll('.help-icon[data-tip]').forEach(icon => {
          icon.addEventListener('mouseenter', (e) => {
            tooltip.innerHTML = icon.getAttribute('data-tip');
            tooltip.style.display = 'block';
            positionTooltip();
          });
          icon.addEventListener('mousemove', (e) => {
            mouseX = e.clientX; mouseY = e.clientY;
            if (tooltip.style.display === 'block') positionTooltip();
          });
          icon.addEventListener('mouseleave', () => { tooltip.style.display = 'none'; });
        });

        function positionTooltip() {
          let x = mouseX + 12, y = mouseY + 12;
          if (x + 220 > window.innerWidth) x = mouseX - 230;
          tooltip.style.left = x + 'px'; tooltip.style.top = y + 'px';
        }

        function toggleScale() {
          const m = document.getElementById('scaleMethod').value;
          document.getElementById('heightRow').style.display = (m === 'height') ? 'flex' : 'none';
          document.getElementById('pixelRow').style.display = (m === 'pixel') ? 'flex' : 'none';
        }

        function toggleUI() {
          const type = document.getElementById('importType').value;
          document.getElementById('layoutCard').style.display = (type === 'texture_only') ? 'none' : 'block';
          document.getElementById('faceCamRow').style.display = (type === 'comp_2d') ? 'flex' : 'none';
        }

        function submitData() {
          sketchup.runImport({
            sourceMode: document.getElementById('sourceMode').value,
            importType: document.getElementById('importType').value,
            scaleMethod: document.getElementById('scaleMethod').value,
            targetHeight: parseFloat(document.getElementById('targetHeight').value) || 0,
            mmPerPixel: parseFloat(document.getElementById('mmPerPixel').value) || 2.0,
            alwaysFaceCamera: document.getElementById('alwaysFaceCamera').checked,
            spacing: parseFloat(document.getElementById('spacing').value) || 500,
            itemsPerRow: parseInt(document.getElementById('itemsPerRow').value) || 10
          });
        }
      </script>
    </body>
    </html>
    HTML

    dialog.set_html(html_content)
    dialog.add_action_callback("closeDialog") { |ac| dialog.close }
    dialog.add_action_callback("runImport") { |ac, config|
      dialog.close
      self.process_import(config)
    }
    dialog.show
  end

  def self.process_import(cfg)
    model = Sketchup.active_model
    entities = model.active_entities
    materials = model.materials
    image_files = []
    supported_exts = %w[.jpg .jpeg .png .bmp .tif .tiff]

    if cfg["sourceMode"] == "folder"
      dir_path = UI.select_directory(title: "VGD Image Importer - Chọn Thư Mục", directory: @last_dir)
      if dir_path && File.directory?(dir_path)
        @last_dir = dir_path
        image_files = Dir.entries(dir_path).select { |f| supported_exts.include?(File.extname(f).downcase) }.map { |f| File.join(dir_path, f).tr("\\", "/") }
      end
    else
      UI.messagebox("VGD Image Importer:\n\nChọn từng ảnh.\nKhi chọn đủ, bấm Cancel để bắt đầu Import.")
      filter = "Image Files|*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.JPG;*.PNG||"
      loop do
        selected = UI.openpanel("Select Image (Cancel to finish)", @last_dir, filter)
        break unless selected
        @last_dir = File.dirname(selected)
        image_files << selected.tr("\\", "/")
      end
    end

    image_files.uniq!
    return if image_files.empty?

    model.start_operation("VGD Image Importer Process", true)
    current_x = 0.0; current_y = 0.0; row_height = 0.0
    spacing = cfg["spacing"].to_f.mm
    items_per_row = cfg["itemsPerRow"].to_i

    image_files.each_with_index do |file_path, index|
      next unless File.exist?(file_path)
      file_name = File.basename(file_path, ".*")

      begin
        img_temp = entities.add_image(file_path, ORIGIN, 100.mm)
        p_w = img_temp.pixelwidth.to_f
        p_h = img_temp.pixelheight.to_f
        img_temp.erase!

        if cfg["scaleMethod"] == "height" && cfg["targetHeight"].to_f > 0
          h = cfg["targetHeight"].to_f.mm
          w = h * (p_w / p_h)
        else
          w = (p_w * cfg["mmPerPixel"].to_f).mm
          h = (p_h * cfg["mmPerPixel"].to_f).mm
        end

        if cfg["importType"] == "texture_only"
          mat_name = "VGD_" + file_name.gsub(/[^0-9A-Za-z]/, '_')
          mat = materials[mat_name] || materials.add(mat_name)
          mat.texture = file_path
          mat.texture.size = [w, h]
          next
        end

        comp_def = model.definitions.add(file_name)
        comp_def.behavior.always_face_camera = true if (cfg["importType"] == "comp_2d" && cfg["alwaysFaceCamera"])
        comp_def.entities.add_image(file_path, ORIGIN, w)

        t_center = Geom::Transformation.translation(Geom::Vector3d.new(-w / 2.0, 0, 0))
        comp_def.entities.transform_entities(t_center, comp_def.entities.to_a)

        if cfg["importType"] == "comp_2d"
          t_rotate = Geom::Transformation.rotation(ORIGIN, Geom::Vector3d.new(1, 0, 0), 90.degrees)
          comp_def.entities.transform_entities(t_rotate, comp_def.entities.to_a)
        end

        inst_x = current_x + w / 2.0
        entities.add_instance(comp_def, Geom::Transformation.new(Geom::Point3d.new(inst_x, current_y, 0)))

        current_x += w + spacing
        row_height = [row_height, h].max

        if (index + 1) % items_per_row == 0
          current_x = 0.0
          current_y += row_height + spacing
          row_height = 0.0
        end
      rescue => e
        puts "Error #{file_path}: #{e.message}"
      end
    end
    model.commit_operation
  end
end

# Khởi tạo Command & Toolbar Icon
cmd = UI::Command.new("VGD Image Importer") {
  VGD_ImageImporter.show_dialog
}
cmd.tooltip = "VGD Image Importer"
cmd.status_bar_text = "Mở công cụ VGD Image Importer"

icon_file = File.join(__dir__, 'vgd_icon.png')
cmd.small_icon = icon_file
cmd.large_icon = icon_file

# Menu Plugins
menu = UI.menu("Plugins").add_submenu("VGD Tools")
menu.add_item(cmd)

# Toolbar ngoài màn hình
toolbar = UI::Toolbar.new("VGD Tools")
toolbar.add_item(cmd)
toolbar.show
