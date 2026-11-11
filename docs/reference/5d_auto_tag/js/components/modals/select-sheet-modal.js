Vue.component('select-sheet-modal', {
  template: /*html*/ `
    <div
      class="modal fade"
      tabindex="-1"
      role="dialog"
      id="selectSheetModal"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-menu">
          <div class="modal-header">
            <h5>{{ $root.translated('selectSheet') }}</h5>
            <button
              type="button"
              class="btn btn-sm btn-icon-only btn-danger"
              data-dismiss="modal"
              aria-label="Close"
            >
              <i class="modus-icons">close</i>
            </button>
          </div>

          <div class="modal-body">
            <div class="d-flex">
              <select
                v-model="$root.selectedSheet"
                class="form-control custom-select"
              >
                <option
                  v-for="sheet in $root.sheetNames"
                  :key="sheet"
                  :value="sheet"
                >
                  {{ sheet }}
                </option>
              </select>

              <button
                type="button"
                class="btn btn-primary ml-1"
                data-dismiss="modal"
                @click="$root.loadSelectedSheet()"
              >
                {{ $root.translated('load') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `
});

