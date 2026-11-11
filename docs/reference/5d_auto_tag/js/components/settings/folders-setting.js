Vue.component('folders-setting', {
  template: /*html*/ `
    <div
      class="tab-pane fade show active"
      id="foldersSettingContainer"
      role="tabpanel"
      aria-labelledby="firstTabSetting"
    >
      <ul class="list-group list-group-condensed ml-2 mr-3" id="foldersSetting">
        <li
          v-for="item in $root.foldersSetting"
          :key="item.id"
          :id="'folders-setting-' + item.id"
          class="setting-item d-flex mb-1"
        >
          <button
            type="button"
            disabled="disabled"
            class="btn btn-text-dark btn-icon-only cursor-drag"
          >
            <i class="modus-icons">drag_indicator</i>
          </button>

          <div class="flex-grow-1">
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

          <button
            type="button"
            class="btn btn-sm btn-icon-only btn-text-danger mt-1 ml-1"
            @click="$root.removeSetting(item.id)"
          >
            <i class="modus-icons">close</i>
          </button>
        </li>
      </ul>
    </div>
  `
});

