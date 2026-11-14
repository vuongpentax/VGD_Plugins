Vue.component('file-manager', {
  template: /*html*/ `
    <div class="d-flex my-2 px-3">
      <div class="d-flex align-items-center file-upload">
        <label
          class="btn btn-icon-only btn-outline-dark border mb-0"
          data-toggle="tooltip"
          :title="$root.translated('chooseExcelFile')"
          for="loadExcelFile"
        >
          <i class="modus-icons">file_type_xls</i>
        </label>
      </div>

      <input
        type="file"
        @change="$root.loadExcelFile"
        accept=".xlsx, .xls"
        id="loadExcelFile"
        style="display: none;"
      />

      <input
        type="text"
        class="form-control ml-1"
        :value="$root.settingsFileName"
        disabled
      />

      <!--
      <button
        v-show="!$root.isReset"
        type="button"
        class="btn btn-icon-only btn-dark ml-1"
        data-toggle="tooltip"
        :title="$root.translated('reset')"
        @click="$root.resetSettings()"
      >
        <i class="modus-icons">refresh</i>
      </button>
      -->

      <button
        v-show="!$root.isSaved"
        type="button"
        class="btn btn-success ml-1"
        data-toggle="tooltip"
        :title="$root.translated('saveDefault')"
        @click="$root.saveSettings()"
      >
        {{ $root.translated('save') }}
      </button>
    </div>
  `
});

