Vue.component('exclusion-list', {
  template: /*html*/ `
    <div
      class="modal fade p-0"
      tabindex="-1"
      role="dialog"
      id="exclusionListModal"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-menu">
          <div class="modal-header">
            <h5 class="modal-title">{{ $root.translated('exclusionList') }}</h5>
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
            <p class="mb-2">
              {{ $root.translated('tagExclusionDescription') }}
            </p>

            <div class="my-3">
              <h5>{{ $root.translated("folder") }}</h5>
              <textarea
                v-model="$root.folderExclusionList"
                class="custom-textarea text-gray-5 w-100"
                id="folderExclusionList">
              </textarea>
            </div>

            <div>
              <h5>{{ $root.translated("tag") }}</h5>
              <textarea
                v-model="$root.layerExclusionList"
                class="custom-textarea text-gray-5 w-100"
                id="layerExclusionList">
              </textarea>
            </div>
          </div>

          <div class="modal-footer">
            <button type="button" class="btn btn-outline-dark mr-1"
              @click="$root.setKeywords('Reset')">{{ $root.translated('reset') }}</button>
            <button type="button" class="btn btn-primary"
              @click="$root.setKeywords('Save')">{{ $root.translated('save') }}</button>
          </div>
        </div>
      </div>
    </div>
  `
});