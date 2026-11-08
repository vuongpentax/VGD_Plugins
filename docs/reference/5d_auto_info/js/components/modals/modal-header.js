Vue.component("modal-header", {
  props: [
    "modalTitle",
    "editTitle",
    "editAction",
    "closeAction"
  ],
  template: /*html*/ `
    <div class="modal-header">
      <h5 class="modal-title">{{ $root.translated(modalTitle) }}</h5>
      <div>
        <button
          v-if="editTitle && editAction"
          type="button"
          class="btn btn-sm btn-icon-only btn-outline-dark"
          data-toggle="tooltip" :title="$root.translated('edit')"
          @click="editAction(editTitle)"
        >
          <i class="modus-icons">pencil</i>
        </button>
        <button
          type="button"
          class="btn btn-sm btn-icon-only btn-danger"
          data-dismiss="modal"
          @click="closeAction ? closeAction() : null"
        >
          <i class="modus-icons">close</i>
        </button>
      </div>
    </div>
  `,
});
