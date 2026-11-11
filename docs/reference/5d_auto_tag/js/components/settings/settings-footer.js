Vue.component('settings-footer', {
  template: /*html*/ `
    <div class="custom-footer border-top">
      <div class="d-flex justify-content-between px-3 py-2">
        <button
          type="button"
          class="btn btn-icon-only btn-danger"
          data-toggle="tooltip"
          :title="$root.translated('resetAllSettings')"
          @click="$root.resetAllSettings()"
        >
          <i class="modus-icons">update</i>
        </button>

        <input
          type="text"
          class="form-control flex-grow-1 border ml-1 mb-2"
          :value="$root.settingsFolderPath"
          :placeholder="$root.translated('defaultPath')"
          disabled
        >
        <button
          type="button"
          class="btn btn-primary btn-icon-only ml-1"
          data-toggle="tooltip"
          :title="$root.translated('locateSettingsFolder')"
          @click="$root.locateSettingsFolder()"
        >
          <i class="modus-icons">folder_open</i>
        </button>

        <button
          type="button"
          class="btn btn-icon-only btn-dark ml-1"
          data-toggle="tooltip"
          :title="$root.translated('exportSettingsFile')"
          @click="$root.exportSettings('json')"
        >
          <i class="modus-icons">save_as</i>
        </button>

        <button
          type="button"
          class="btn btn-icon-only btn-success ml-1"
          data-toggle="tooltip"
          :title="$root.translated('exportExcelFile')"
          @click="$root.exportSettings('excel')"
        >
          <i class="modus-icons">file_type_xls</i>
        </button>
      </div>
    </div>
  `
});
