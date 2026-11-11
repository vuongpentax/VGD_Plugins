Vue.component("action-modal", {
  props: [
    "modalTitle",
    "editTitle",
    "editAction",
    "modalMessage",
    "modalAction0",
    "modalAction1",
    "modalAction2",
  ],
  template: /*html*/ `
    <div class="modal fade" tabindex="-1" id="actionModal">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-modal">
          <modal-header
            :modal-title="modalTitle"
            :edit-title="editTitle"
            :edit-action="editAction"
          ></modal-header>

          <div class="modal-body">
            <div
              v-html="$root.translated(modalMessage)"
              class="mb-2"
            ></div>
          </div>

          <div class="modal-footer border-top-0">
            <button
              v-if="modalAction0"
              type="button"
              class="btn btn-outline-dark"
              data-dismiss="modal"
              @click="modalAction0.action"
            >
              {{ $root.translated(modalAction0.text) }}
            </button>
            <button
              v-if="modalAction1"
              type="button"
              class="btn btn-outline-dark"
              data-dismiss="modal"
              @click="modalAction1.action"
            >
              {{ $root.translated(modalAction1.text) }}
            </button>
            <button
              v-if="modalAction2"
              type="button"
              class="btn btn-primary"
              data-dismiss="modal"
              @click="modalAction2.action"
              @keydown.enter="modalAction2.action"
            >
              {{ $root.translated(modalAction2.text) }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `,
});
