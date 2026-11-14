Vue.component('custom-footer', {
  template: /*html*/ `
    <div class="custom-footer border-top p-2">
      <div class="d-flex">
        <div v-if="!$root.isExcel && !$root.compactMode" class="d-flex">
          <!-- MORE COMMANDS -->
          <div class="dropdown d-flex">
            <button
              type="button"
              class="btn btn-icon-only btn-text-dark"
              data-toggle="dropdown"
              aria-haspopup="true"
              aria-expanded="false"
            >
              <i class="modus-icons">bookings</i>
            </button>

            <div class="dropdown-menu custom-menu p-2" id="moreCommands">
              <div class="d-flex">
                <button
                  type="button"
                  class="btn btn-icon-only btn-text-dark mr-1"
                  data-toggle="tooltip"
                  :title="$root.translated('exclusionList')"
                  @click="$root.showExclusionListModal()"
                >
                  <i class="modus-icons mr-2">filter</i>
                </button>

                <button
                  type="button"
                  class="btn btn-icon-only btn-text-dark mr-1"
                  data-toggle="tooltip"
                  :title="$root.translated('autoCreateFolder')"
                  @click="$root.sketchupActions('autoTagFolder')"
                >
                  <i class="modus-icons mr-2">folder_open</i>
                </button>

                <button
                  type="button"
                  class="btn btn-icon-only btn-text-dark mr-1"
                  data-toggle="tooltip"
                  :title="$root.translated('autoTagByName')"
                  @click="$root.autoNameTag()"
                >
                  <i class="modus-icons mr-2">paper_plane</i>
                </button>

                <button
                  type="button"
                  class="btn btn-icon-only btn-text-dark mr-1"
                  data-toggle="tooltip"
                  :title="$root.translated('importSketchup')"
                  @click="$root.sketchupActions('importSketchup')"
                >
                  <i class="modus-icons mr-2">file_check_in</i>
                </button>

                <button
                  type="button"
                  class="btn btn-icon-only btn-text-dark mr-1"
                  data-toggle="tooltip"
                  :title="$root.translated('exportTags')"
                  @click="$root.exportLayers()"
                >
                  <i class="modus-icons mr-2">file_check_out</i>
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="d-flex ml-auto">
          <!-- COMPACT BUTTON -->
          <button
            v-if="!$root.isExcel"
            type="button"
            class="btn btn-icon-only btn-text-dark"
            data-toggle="tooltip"
            :title="$root.compactMode ? $root.translated('fullMode') : $root.translated('compactMode')"
            @click="$root.toggleCompactMode()"
          >
            <i class="modus-icons">{{ $root.compactMode ? 'window_template' : 'window' }}</i>
          </button>

          <!-- IMPORT EXCEL -->
          <button
            v-if="$root.isExcel"
            type="button"
            class="btn btn-primary float-right"
            data-toggle="tooltip"
            :title="$root.translated('importSelectedTags')"
            :disabled="!Object.values($root.excelCheckboxStates).some(v => v)"
            @click="$root.importSelectedExcelRows"
          >
            {{ $root.translated('import') }}
          </button>
        </div>
      </div>

    </div>
  `
});

