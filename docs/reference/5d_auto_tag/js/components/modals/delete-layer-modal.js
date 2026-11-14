Vue.component('delete-layer-modal', {
  template: /*html*/ `
    <div
      class="modal fade p-0"
      tabindex="-1"
      role="dialog"
      id="confirmDeleteLayerModal"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-menu">
          <div class="modal-header">
            <h5 class="modal-title">{{ $root.translated('deleteTags') }}</h5>
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
            <p class="mb-3">
              {{ $root.translated('deleteTagsDescription') }}
            </p>

            <div class="form-group">
              <label for="assignLayerSelect">{{ $root.translated('assignAnotherTag') }}</label>
              <select
                v-model="$root.deleteLayerOptions.assignLayer"
                class="custom-select form-control"
                id="assignLayerSelect"
              >
                <option
                  v-for="layer in Object.values($root.layers)"
                  :key="layer.id"
                  :value="layer.name"
                >
                  {{ layer.name }}
                </option>
              </select>
            </div>

            <div class="form-group">
              <div class="custom-control custom-checkbox">
                <input
                  v-model="$root.deleteLayerOptions.deleteEntities"
                  type="checkbox"
                  class="custom-control-input"
                  id="deleteEntityCheckbox"
                >
                <label
                  class="custom-control-label"
                  for="deleteEntityCheckbox"
                >
                  {{ $root.translated('deleteEntities') }}
                </label>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-outline-dark"
              data-dismiss="modal"
            >
              {{ $root.translated('cancel') }}
            </button>
            <button
              type="button"
              class="btn btn-danger"
              @click="$root.confirmDeleteLayer"
            >
              {{ $root.translated('delete') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
});

