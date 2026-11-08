const showModalsMixin = {
  data() {
    return {
      noticeType: 'info',
      noticeMessage: '',

      modalTitle: '',
      editTitle: '',
      editAction: null,
      modalMessage: '',
      modalAction0: null,
      modalAction1: null,
      modalAction2: null,

      isProcessing: false,
    }
  },

  methods: {
    notAvailable() {
      this.showNoticeModal(this.translated('notAvailable'));
    },

    handleOpenModal(modalId, saveState = true) {
      if (!modalId) return;

      if (this.currentModal && this.currentModal !== modalId) {
        this.hideModal(this.currentModal);
      } else {
        this.currentModal = modalId;
      }

      this.showModal(modalId, 'wait');
      handleTooltip(this.$root);

      if (saveState) {
        // Add event listener for when modal is shown (fully visible)
        $(modalId)
          .off('shown.bs.modal.modalShown')
          .on('shown.bs.modal.modalShown', () => {
            this.saveModalState(modalId);
          });
      }

      // Add event listener for when modal is hidden by any method (click, esc...)
      $(modalId)
        .off('hidden.bs.modal.clearLastDialog')
        .on('hidden.bs.modal.clearLastDialog', () => {
          const savedModalId = localStorage.getItem(lastDialogModalKey);
          if (savedModalId === modalId) {
            this.closeAndClear();
          }
        });
    },

    handleCloseModal(modalId) {
      this.hideModal(modalId);

      this.currentModal = null; // Clear current modal state
    },

    cancelProcessingModal() {
      if (this.isProcessing) {
        this.isProcessing = false;
        hideAllModals();
      }
    },

    restoreModal() {
      setTimeout(() => {
        // Restore previous modal if applicable
        if (!this.currentModal) return;
        const previousModal = this.currentModal;
        if (this.shouldStoreModals.includes(previousModal)) {
          this.handleOpenModal(previousModal);
        }
      }, 1600);
    },

    showMessageModal(message, type, delay = 1500, restoreModal = false) {
      if (!message) return;

      this.hideModal('#actionModal'); // Hide action modal if open

      this.noticeMessage = message;
      this.noticeType = type || 'info';

      // Track processing state for 'processing' type with 'wait' delay
      if (type === 'processing' && delay === 'wait') {
        this.isProcessing = true;
      }

      this.showToast(delay);

      if (!restoreModal) return;
      this.restoreModal();
    },

    // This is also for receive notice from SketchUp
    showNoticeModal(message, action1 = null, action2 = null) {
      if (!message) return;

      this.hideModal('#messageModal'); // Hide message modal if open

      const previousModal = this.currentModal;

      this.modalTitle = 'notification';
      this.modalMessage = message;

      // Configure action1 based on type
      if (action1) {
        if (action1 === 'no' || action1 === 'cancel') {
          this.modalAction1 = {
            text: this.translated(action1),
            action: () => this.hideModal('#actionModal')
          };
        }

      } else {
        this.modalAction1 = null; // Clear modalAction1 if no action1 provided
      }

      // Configure action2 based on type
      if (action2) {
        if (typeof action2 === 'string') {
          if (action2 === 'closeDialog') {
            this.modalAction2 = {
              text: this.translated('yes'),
              action: () => this.closeDialog()
            };
          }
        } else if (typeof action2 === 'function') {
          this.modalAction2 = {
            text: 'OK',
            action: () => action2()
          };
        } else {
          this.modalAction2 = {
            text: this.translated(action2),
            action: () => this.hideModal('#actionModal')
          };
        }

      } else { // Default action2 if no action2 provided
        this.modalAction2 = {
          text: 'OK',
          action: () => null,
        };
      }

      setTimeout(() => {
        hideAllModals();
        this.showModal('#actionModal', 'wait');
      }, 300);
    },

    showModal(id, delay = 1500) {
      showModal(id, delay);
    },

    hideModal(id) {
      hideModal(id);
    },

    showToast(delay = 1500) {
      showToast(delay);
    },
  }
};

function showNoticeModal(notice, action1 = null, action2 = null) {
  document.getElementById('app').__vue__.showNoticeModal(notice, action1, action2);
}

function showMessageModal(message, type, delay = null) {
  document.getElementById('app').__vue__.showMessageModal(message, type, delay);
}