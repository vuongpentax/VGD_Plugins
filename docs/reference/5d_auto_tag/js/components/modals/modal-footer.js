Vue.component("modal-footer", {
  props: ["modalAction1", "modalAction2"],
  methods: {
    handleClick(button) {
      if (button && !button.disabled && typeof button.action === "function") {
        button.action();
      }
    },
  },
  template: /*html*/ `
    <div class="modal-footer border-top-0 pb-3 pt-0">
      <button
        v-if="modalAction1 && modalAction1.text"
        type="button"
        class="btn btn-outline-dark"
        :class="{ 'disabled': modalAction1.disabled }"
        :disabled="modalAction1.disabled"
        data-dismiss="modal"
        @click="handleClick(modalAction1)"
      >
        {{ $root.translated(modalAction1.text) }}
      </button>
      <button
        v-if="modalAction2 && modalAction2.text"
        type="button"
        class="btn btn-primary"
        :class="{ 'disabled': modalAction2.disabled }"
        :disabled="modalAction2.disabled"
        data-dismiss="modal"
        @click="handleClick(modalAction2)"
        @keydown.enter="handleClick(modalAction2)"
      >
        {{ $root.translated(modalAction2.text) }}
      </button>
    </div>
  `,
});
