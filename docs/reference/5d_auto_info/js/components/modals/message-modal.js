Vue.component("message-modal", {
  props: {
    // info | success | error | warning | reset | processing
    noticeType: {
      type: String,
      default: "info",
      validator: value =>
        ["info", "success", "error", "warning", "reset", "processing"].includes(value),
    },

    // Content message
    noticeMessage: {
      type: String,
      default: "",
    },
  },

  template: /*html*/ `
    <div class="modal fade" id="messageModal" tabindex="-1" role="dialog">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div
          :class="[
            'toast show text-center',
            {
              'toast-primary': noticeType === 'info',
              'toast-success': noticeType === 'success',
              'toast-danger': noticeType === 'error',
              'toast-warning': noticeType === 'warning',
              'toast-dark': noticeType === 'reset' || noticeType === 'processing',
            }
          ]"
          style="pointer-events: auto;"
          role="alert"
          aria-live="assertive"
          aria-atomic="true"
        >
          <i
            v-if="noticeType === 'processing'"
            class="modus-icons left-icon spin mr-2"
          >
            update
          </i>

          <span v-html="noticeMessage"></span>
          <button
            v-if="noticeType === 'processing'"
            type="button"
            class="btn btn-danger ml-3 cursor-pointer"
            @click="$root.cancelProcessing()"
          >Cancel</button>
        </div>
      </div>
    </div>
  `,
});
