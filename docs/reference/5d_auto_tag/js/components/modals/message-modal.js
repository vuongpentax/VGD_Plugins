Vue.component('message-modal', {
  template: /*html*/ `
    <div
      class="modal fade"
      id="messageModal"
      tabindex="-1"
      role="dialog"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div
          :class="[
            'toast show text-center',
            { 
              'toast-primary': $root.noticeType === 'info',
              'toast-success': $root.noticeType === 'success',
              'toast-danger': $root.noticeType === 'error',
              'toast-warning': $root.noticeType === 'warning',
              'toast-dark': $root.noticeType === 'reset' || $root.noticeType === 'updating',
            }
          ]"
          role="alert"
          aria-live="assertive"
          aria-atomic="true"
        >
          <i
            v-if="$root.noticeType === 'updating'"
            class="modus-icons left-icon spin mr-2"
          >
            update
          </i>
          {{ $root.noticeMessage }}
        </div>
      </div>
    </div>
  `
});

