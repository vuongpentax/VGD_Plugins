Vue.component('header-list', {
  template: /*html*/ `
    <div class="d-flex mb-1 ml-2 mr-3">
      <button
        type="button"
        disabled="disabled"
        class="btn btn-text-dark btn-icon-only"
      >
        <i class="modus-icons">drag_indicator</i>
      </button>

      <div class="flex-grow-1">
        <input
          type="text"
          class="form-control"
          disabled
          :value="$root.translated($root.currentSetting + 'SourceHeader')"
        />
      </div>

      <button type="button" class="btn btn-icon-only invisible" disabled>
        <i class="modus-icons text-dark">caret_right</i>
      </button>

      <div class="flex-grow-1">
        <input
          type="text"
          class="form-control"
          disabled
          :value="$root.translated($root.currentSetting + 'TargetHeader')"
        />
      </div>

      <button
        type="button"
        class="btn btn-sm btn-icon-only btn-primary ml-1 mt-1"
        data-toggle="tooltip"
        :title="$root.translated('addRow')"
        @click="$root.addSetting()"
      >
        <i class="modus-icons">add</i>
      </button>
    </div>
  `
});

