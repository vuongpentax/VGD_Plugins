# ============================================================
# VGD DIMENSION & TEXT MANAGER
# ============================================================

module VGDDimTextManager

  extend self

  # ==========================================================
  # MATERIAL
  # ==========================================================

  def get_material(model, name, hex)

    mat = model.materials[name]
    mat ||= model.materials.add(name)

    h = hex.delete("#")

    mat.color = Sketchup::Color.new(
      h[0..1].to_i(16),
      h[2..3].to_i(16),
      h[4..5].to_i(16)
    )

    mat
  end


  # ==========================================================
  # MM -> PT
  # ==========================================================

  def mm_to_pt(mm)
    mm.to_f * 72.0 / 25.4
  end


  # ==========================================================
  # SCAN DEEP
  # ==========================================================

  def scan_entities(entities, settings, processed, stats)

    entities.each do |entity|

      # ------------------------------------------------------
      # DIMENSION
      # ------------------------------------------------------

      if entity.is_a?(Sketchup::Dimension)

        begin

          entity.material =
            settings["dim_material"]

          stats[:dimensions] += 1

        rescue => e

          puts "DIM ERROR: #{e.message}"

        end

      end


      # ------------------------------------------------------
      # TEXT
      # ------------------------------------------------------

      if entity.is_a?(Sketchup::Text)

        begin

          # COLOR
          entity.material =
            settings["text_material"]


          # FONT
          #
          # SketchUp 2026.2+
          #

          if entity.respond_to?(:font=)

            entity.font = {
              name: settings["font"],
              size: settings["size_pt"].to_i,
              bold: settings["bold"],
              italic: settings["italic"]
            }

          end

          stats[:texts] += 1

        rescue => e

          puts "TEXT ERROR: #{e.message}"

        end

      end


      # ------------------------------------------------------
      # GROUP
      # ------------------------------------------------------

      if entity.is_a?(Sketchup::Group)

        stats[:groups] += 1

        begin

          scan_entities(
            entity.entities,
            settings,
            processed,
            stats
          )

        rescue => e

          puts "GROUP ERROR: #{e.message}"

        end

      end


      # ------------------------------------------------------
      # COMPONENT
      # ------------------------------------------------------

      if entity.is_a?(Sketchup::ComponentInstance)

        stats[:components] += 1

        begin

          definition =
            entity.definition

          id =
            definition.object_id


          unless processed[id]

            processed[id] = true

            scan_entities(
              definition.entities,
              settings,
              processed,
              stats
            )

          end

        rescue => e

          puts "COMPONENT ERROR: #{e.message}"

        end

      end

    end

  end


  # ==========================================================
  # MODEL UNITS
  # ==========================================================

  def apply_units(model, settings)

    begin

      units =
        model.options["UnitsOptions"]


      unit =
        case settings["unit"]

        when "mm"
          2

        when "cm"
          3

        when "m"
          4

        when "inch"
          0

        when "ft"
          1

        else
          2

        end


      units["LengthUnit"] =
        unit


      units["LengthPrecision"] =
        settings["precision"].to_i


      units["SuppressUnitsDisplay"] =
        !settings["show_unit"]


    rescue => e

      puts "UNITS ERROR: #{e.message}"

    end

  end


  # ==========================================================
  # OPEN MODEL INFO - DIMENSIONS
  # ==========================================================

  def open_dimension_settings

    begin

      UI.show_model_info("Dimensions")

    rescue

      begin

        Sketchup.send_action(
          "showModelPropertiesPanel;"
        )

      rescue

        UI.messagebox(
          "Không thể tự mở Model Info."
        )

      end

    end

  end


  # ==========================================================
  # OPEN MODEL INFO - TEXT
  # ==========================================================

  def open_text_settings

    begin

      UI.show_model_info("Text")

    rescue

      begin

        UI.show_model_info("Text")

      rescue

        UI.messagebox(
          "Không thể tự mở Model Info."
        )

      end

    end

  end


  # ==========================================================
  # APPLY
  # ==========================================================

  def apply(settings)

    model =
      Sketchup.active_model


    model.start_operation(
      "VGD Dimension & Text Manager",
      true
    )


    begin

      # ------------------------------------------------------
      # MATERIAL
      # ------------------------------------------------------

      settings["dim_material"] =
        get_material(
          model,
          "VGD_DIM_COLOR",
          settings["dim_color"]
        )


      settings["text_material"] =
        get_material(
          model,
          "VGD_TEXT_COLOR",
          settings["text_color"]
        )


      # ------------------------------------------------------
      # UNIT
      # ------------------------------------------------------

      apply_units(
        model,
        settings
      )


      # ------------------------------------------------------
      # SCAN
      # ------------------------------------------------------

      stats = {
        dimensions: 0,
        texts: 0,
        groups: 0,
        components: 0
      }


      scan_entities(
        model.entities,
        settings,
        {},
        stats
      )


      model.commit_operation


      model.active_view.refresh


      UI.messagebox(
        "VGD DIMENSION & TEXT\n\n" \
        "Đã Apply!\n\n" \
        "Dimension : #{stats[:dimensions]}\n" \
        "Text      : #{stats[:texts]}\n" \
        "Groups    : #{stats[:groups]}\n" \
        "Components: #{stats[:components]}\n\n" \
        "Font: #{settings["font"]}\n" \
        "Size: #{settings["size_display"]}"
      )


    rescue => e

      model.abort_operation

      UI.messagebox(
        "VGD ERROR\n\n#{e.message}"
      )

      puts e.backtrace.join("\n")

    end

  end


  # ==========================================================
  # DIALOG
  # ==========================================================

  def show_dialog

    dialog =
      UI::HtmlDialog.new(
        dialog_title:
          "VGD DIMENSION & TEXT MANAGER",

        preferences_key:
          "VGDDimTextManager",

        scrollable:
          false,

        resizable:
          false,

        width:
          560,

        height:
          760,

        style:
          UI::HtmlDialog::STYLE_DIALOG
      )


    html = <<~HTML

      <!DOCTYPE html>

      <html>

      <head>

      <meta charset="UTF-8">

      <style>

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        padding: 20px;
        background: #202020;
        color: #eeeeee;
        font-family: Arial, sans-serif;
        font-size: 13px;
      }

      h1 {
        margin: 0 0 18px;
        font-size: 20px;
      }

      .section {
        background: #2b2b2b;
        border: 1px solid #444;
        border-radius: 8px;
        padding: 15px;
        margin-bottom: 12px;
      }

      .title {
        font-size: 14px;
        font-weight: bold;
        margin-bottom: 14px;
      }

      .row {
        display: flex;
        align-items: center;
        margin-bottom: 10px;
      }

      .label {
        width: 125px;
        color: #bbb;
      }

      input,
      select {
        flex: 1;
        height: 32px;
        background: #191919;
        color: white;
        border: 1px solid #555;
        border-radius: 5px;
        padding: 5px 8px;
      }

      input[type=color] {
        width: 55px;
        flex: none;
        padding: 2px;
      }

      input[type=checkbox] {
        width: 18px;
        height: 18px;
        flex: none;
      }

      .size {
        width: 100px;
        flex: none;
      }

      .sizeunit {
        width: 90px;
        flex: none;
        margin-left: 8px;
      }

      .btn {
        width: 100%;
        height: 34px;
        border: none;
        border-radius: 5px;
        background: #444;
        color: white;
        cursor: pointer;
        margin-top: 5px;
      }

      .btn:hover {
        background: #555;
      }

      .apply {
        background: #e5ad00;
        color: #111;
        font-weight: bold;
      }

      .apply:hover {
        background: #f2bd12;
      }

      .footer {
        display: flex;
        gap: 10px;
      }

      .footer button {
        flex: 1;
        height: 40px;
        border: none;
        border-radius: 6px;
        cursor: pointer;
        font-weight: bold;
      }

      .cancel {
        background: #444;
        color: white;
      }

      .info {
        color: #999;
        font-size: 11px;
        line-height: 1.5;
        margin-top: 8px;
      }

      </style>

      </head>


      <body>

      <h1>
        VGD DIMENSION & TEXT
      </h1>


      <!-- ================================================= -->
      <!-- FONT CHUNG -->
      <!-- ================================================= -->

      <div class="section">

        <div class="title">
          FONT & SIZE — CHUNG CHO DIM + TEXT
        </div>


        <div class="row">

          <div class="label">
            Font
          </div>

          <select id="font">

            <option>Arial</option>
            <option>Arial Narrow</option>
            <option>Calibri</option>
            <option>Tahoma</option>
            <option>Verdana</option>
            <option>Roboto</option>
            <option>Helvetica</option>
            <option>Times New Roman</option>

          </select>

        </div>


        <div class="row">

          <div class="label">
            Size
          </div>

          <input
            id="size"
            class="size"
            type="number"
            value="10"
            min="1"
            step="0.5"
          >


          <select
            id="size_unit"
            class="sizeunit"
          >

            <option value="pt">
              pt
            </option>

            <option value="mm">
              mm
            </option>

          </select>

        </div>


        <div class="row">

          <div class="label">
            Bold
          </div>

          <input
            id="bold"
            type="checkbox"
          >

        </div>


        <div class="row">

          <div class="label">
            Italic
          </div>

          <input
            id="italic"
            type="checkbox"
          >

        </div>


        <div class="info">

          Font + Size này dùng chung cho Dimension và Text.<br>

          1 mm = 2.83465 pt.

        </div>

      </div>


      <!-- ================================================= -->
      <!-- DIMENSION -->
      <!-- ================================================= -->

      <div class="section">

        <div class="title">
          DIMENSION
        </div>


        <div class="row">

          <div class="label">
            Color
          </div>

          <input
            id="dim_color"
            type="color"
            value="#000000"
          >

        </div>


        <div class="row">

          <div class="label">
            Unit
          </div>

          <select id="unit">

            <option value="mm">
              Millimeter (mm)
            </option>

            <option value="cm">
              Centimeter (cm)
            </option>

            <option value="m">
              Meter (m)
            </option>

            <option value="inch">
              Inch
            </option>

            <option value="ft">
              Feet
            </option>

          </select>

        </div>


        <div class="row">

          <div class="label">
            Precision
          </div>

          <select id="precision">

            <option value="0">
              0
            </option>

            <option value="1">
              0.0
            </option>

            <option value="2">
              0.00
            </option>

            <option value="3">
              0.000
            </option>

            <option value="4">
              0.0000
            </option>

          </select>

        </div>


        <div class="row">

          <div class="label">
            Show Unit
          </div>

          <input
            id="show_unit"
            type="checkbox"
            checked
          >

        </div>


        <button
          class="btn"
          onclick="openDimInfo()"
        >

          Mở Model Info → Dimensions

        </button>


        <div class="info">

          Font/Size của Native Dimension do SketchUp quản lý
          trong Model Info. Sau khi chọn Font/Size tại đây,
          dùng "Update selected dimensions" của SketchUp.

        </div>

      </div>


      <!-- ================================================= -->
      <!-- TEXT -->
      <!-- ================================================= -->

      <div class="section">

        <div class="title">
          TEXT
        </div>


        <div class="row">

          <div class="label">
            Color
          </div>

          <input
            id="text_color"
            type="color"
            value="#000000"
          >

        </div>


        <div class="info">

          Text sẽ được Apply trực tiếp nếu SketchUp hỗ trợ
          Text Font API.

        </div>

      </div>


      <!-- ================================================= -->
      <!-- SCAN -->
      <!-- ================================================= -->

      <div class="section">

        <div class="title">
          DEEP SCAN
        </div>


        <div class="row">

          <div class="label">
            Groups
          </div>

          <input
            type="checkbox"
            checked
            disabled
          >

        </div>


        <div class="row">

          <div class="label">
            Components
          </div>

          <input
            type="checkbox"
            checked
            disabled
          >

        </div>

      </div>


      <!-- ================================================= -->
      <!-- FOOTER -->
      <!-- ================================================= -->

      <div class="footer">

        <button
          class="cancel"
          onclick="sketchup.cancel()"
        >

          CANCEL

        </button>


        <button
          class="apply"
          onclick="applySettings()"
        >

          APPLY

        </button>

      </div>


      <script>

      function mmToPt(mm) {

        return mm * 72 / 25.4;

      }


      function applySettings() {

        let size =
          parseFloat(
            document.getElementById(
              "size"
            ).value
          );


        let unit =
          document.getElementById(
            "size_unit"
          ).value;


        let displaySize =
          size + " " + unit;


        if (unit === "mm") {

          size =
            mmToPt(size);

        }


        let settings = {

          font:
            document.getElementById(
              "font"
            ).value,

          size_pt:
            size,

          size_display:
            displaySize,

          bold:
            document.getElementById(
              "bold"
            ).checked,

          italic:
            document.getElementById(
              "italic"
            ).checked,

          dim_color:
            document.getElementById(
              "dim_color"
            ).value,

          text_color:
            document.getElementById(
              "text_color"
            ).value,

          unit:
            document.getElementById(
              "unit"
            ).value,

          precision:
            document.getElementById(
              "precision"
            ).value,

          show_unit:
            document.getElementById(
              "show_unit"
            ).checked

        };


        sketchup.apply(
          JSON.stringify(settings)
        );

      }


      function openDimInfo() {

        sketchup.open_dim_info();

      }

      </script>


      </body>

      </html>

    HTML


    dialog.set_html(html)


    # ========================================================
    # CALLBACK APPLY
    # ========================================================

    dialog.add_action_callback(
      "apply"
    ) do |_, json|

      require "json"

      settings =
        JSON.parse(json)


      apply(settings)

    end


    # ========================================================
    # CALLBACK MODEL INFO
    # ========================================================

    dialog.add_action_callback(
      "open_dim_info"
    ) do

      open_dimension_settings

    end


    # ========================================================
    # CANCEL
    # ========================================================

    dialog.add_action_callback(
      "cancel"
    ) do

      dialog.close

    end


    dialog.show

  end


  # ==========================================================
  # MENU
  # ==========================================================

  unless @loaded

    @loaded = true

    UI.menu("Extensions").add_item(
      "VGD Dimension & Text Manager"
    ) {

      show_dialog

    }

  end

end


# ============================================================
# START
# ============================================================

VGDDimTextManager.show_dialog