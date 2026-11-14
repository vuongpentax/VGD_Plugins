Vue.component('export-layers', {
  template: /*html*/ `
    <div
      class="modal fade"
      tabindex="-1"
      role="dialog"
      id="exportLayersModal"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-menu">
          <div class="modal-header">
            <h5 class="modal-title">{{ $root.translated('exportTags')}}</h5>
            <button
              type="button"
              class="btn btn-sm btn-icon-only btn-danger"
              data-dismiss="modal"
              aria-label="Close"
            >
              <i class="modus-icons">close</i>
            </button>
          </div>

          <div class="modal-body p-2" id="exportLayersContainer">
            <div class="input-with-icon-right">
              <input
                v-model="$root.exportSearchQuery"
                class="form-control mr-2"
                :placeholder="$root.translated('search')"
                id="exportSearchInput"
              >
              <div class="input-icon cursor-pointer hover-icon">
                <i
                  class="modus-icons"
                  @click="$root.exportSearchQuery ? $root.clearSearch() : null"
                >
                  {{ $root.exportSearchQuery ? 'close' : 'search' }}
                </i>
              </div>
            </div>

            <div class="d-flex justify-content-between p-2">
              <div class="custom-control custom-checkbox mr-1">
                <input
                  type="checkbox"
                  class="custom-control-input"
                  id="checkAllExportLayers"
                  v-model="$root.checkAllExportLayersValue"
                  @change="$root.checkAllExportLayers()"
                />
                <label
                  class="custom-control-label"
                  for="checkAllExportLayers"
                  >
                  {{ $root.translated($root.checkAllExportLayersValue ? 'uncheckAll' : 'checkAll') }}
                </label>
              </div>
              <label class="badge-pill badge-dark px-2 mt-2">{{ $root.checkedCount }} / {{ $root.exportLayersLength }}</label>
            </div>

            <div class="p-2" id="exportLayersList">
              <div
                v-for="(exportLayer, index) in $root.filteredExportLayers"
                :key="index + '-' + exportLayer.id"
                :export-layer-id="exportLayer.id"
                class="d-flex"
              >
                <div class="custom-control custom-checkbox">
                  <input
                    type="checkbox"
                    class="custom-control-input"
                    :id="index + '-checkExportLayer'"
                    v-model="exportLayer.checked"
                    @change="$root.updateCheckAllExportLayers()"
                  />
                  <label class="custom-control-label custom-label" :for="index + '-checkExportLayer'">{{ exportLayer.name }}</label>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer justify-content-center">
            <div class="d-flex">
              <button
                type="button"
                class="btn btn-primary mr-1"
                data-toggle="tooltip"
                :title="$root.translated('exportToSketchup')"
                @click="$root.exportToSketchup()"
              >
                <img src="../images/sketchup_logo.svg" alt="SketchUp SVG icon" width="16" height="16" class="mr-2">
                SketchUp
              </button>

              <button
                type="button"
                class="btn btn-success"
                data-toggle="tooltip"
                :title="$root.translated('exportToExcel')"
                @click="$root.exportToExcel()"
              >
                <i class="modus-icons left-icon">file_type_xls</i>
                Excel
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `
});

