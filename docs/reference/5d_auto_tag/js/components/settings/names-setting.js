Vue.component('names-setting', {
  template: /*html*/ `
    <div
      class="tab-pane fade"
      id="namesSettingContainer"
      role="tabpanel"
      aria-labelledby="secondTabSetting"
    >
      <ul class="list-group list-group-condensed ml-2 mr-3" id="namesSetting">
        <li
          v-for="item in $root.namesSetting"
          :key="item.id"
          :id="'names-setting-' + item.id"
          class="setting-item d-flex mb-1"
        >
          <button
            type="button"
            disabled="disabled"
            class="btn btn-text-dark btn-icon-only cursor-drag"
          >
            <i class="modus-icons">drag_indicator</i>
          </button>

          <div class="flex-grow-1 d-flex">
            <input
              v-model="item.source"
              type="text"
              class="form-control"
              :placeholder="$root.translated($root.currentSetting + 'SourceHeader')"
              @blur="$root.initSettingsSorting($root.currentSetting)"
              @click="$root.updateSaveStatus(item.id, 'source')"
            />
          </div>

          <button type="button" class="btn btn-icon-only text" disabled>
            <i class="modus-icons text-danger">caret_right</i>
          </button>

          <div class="flex-grow-1">
            <input
              v-model="item.target"
              type="text"
              class="form-control"
              :placeholder="$root.translated($root.currentSetting + 'TargetHeader')"
              @blur="$root.initSettingsSorting($root.currentSetting)"
              @click="$root.updateSaveStatus(item.id, 'target')"
            />
          </div>
          <button type="button" class="btn btn-sm btn-icon-only btn-text-danger mt-1 ml-1" @click="$root.removeSetting(item.id)">
            <i class="modus-icons">close</i>
          </button>
        </li>
      </ul>
    </div>
  `
});

