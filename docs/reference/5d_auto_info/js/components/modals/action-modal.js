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
  data() {
    return {
      actionExecuted: false
    };
  },
  mounted() {
    // Listen for modal hidden event to handle close without action
    $('#actionModal').on('show.bs.modal', () => {
      this.actionExecuted = false;
    });
    $('#actionModal').on('hidden.bs.modal', () => {
      // If modal was closed without clicking OK (action2), call action1 (cancel)
      if (!this.actionExecuted && this.modalAction1 && typeof this.modalAction1.action === 'function') {
        this.modalAction1.action();
      }
    });
  },
  beforeDestroy() {
    $('#actionModal').off('show.bs.modal');
    $('#actionModal').off('hidden.bs.modal');
  },
  methods: {
    handleAction1() {
      this.actionExecuted = true;
      if (this.modalAction1 && typeof this.modalAction1.action === 'function') {
        this.modalAction1.action();
      }
    },
    handleAction2() {
      this.actionExecuted = true;
      if (this.modalAction2 && typeof this.modalAction2.action === 'function') {
        this.modalAction2.action();
      }
    },
    handleClose() {
      // Close button triggers cancel action
      if (this.modalAction1 && typeof this.modalAction1.action === 'function') {
        this.actionExecuted = true;
        this.modalAction1.action();
      }
    }
  },
  template: /*html*/ `
    <div class="modal fade" tabindex="-1" id="actionModal">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-modal">
          <modal-header
            :modal-title="modalTitle"
            :edit-title="editTitle"
            :edit-action="editAction"
            :close-action="handleClose"
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
              @click="handleAction1"
            >
              {{ $root.translated(modalAction1.text) }}
            </button>
            <button
              v-if="modalAction2"
              type="button"
              class="btn btn-primary"
              data-dismiss="modal"
              @click="handleAction2"
              @keydown.enter="handleAction2"
            >
              {{ $root.translated(modalAction2.text) }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `,
});
