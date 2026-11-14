Vue.component("presets-container", {
  data() {
    return {
      newSetName: '',
      editingPreset: '',   // name of the preset currently being renamed
      editingSetName: '',  // the new name being typed in the rename input
    };
  },

  computed: {
    editingPresets: {
      get() { return this.$root.editingPresets; },
      set(val) { this.$root.editingPresets = val; }
    },
    currentPreset: {
      get() { return this.$root.currentPreset; },
      set(val) { this.$root.currentPreset = val; }
    },
    presetsList: {
      get() { return this.$root.presetsList; },
      set(val) { this.$root.presetsList = val; }
    },
    roundLength: {
      get() { return this.$root.roundLength; },
      set(val) { this.$root.roundLength = val; }
    },
    formatLength: {
      get() { return this.$root.formatLength; },
      set(val) { this.$root.formatLength = val; }
    },
    roundArea: {
      get() { return this.$root.roundArea; },
      set(val) { this.$root.roundArea = val; }
    },
    formatArea: {
      get() { return this.$root.formatArea; },
      set(val) { this.$root.formatArea = val; }
    },
    roundVolume: {
      get() { return this.$root.roundVolume; },
      set(val) { this.$root.roundVolume = val; }
    },
    formatVolume: {
      get() { return this.$root.formatVolume; },
      set(val) { this.$root.formatVolume = val; }
    },
    currency: {
      get() { return this.$root.currency; },
      set(val) { this.$root.currency = val; }
    },
    decimalSeparator: {
      get() { return this.$root.decimalSeparator; },
      set(val) { this.$root.decimalSeparator = val; }
    },
    imageWidth: {
      get() { return this.$root.imageWidth; },
      set(val) { this.$root.imageWidth = val; }
    },
    imageHeight: {
      get() { return this.$root.imageHeight; },
      set(val) { this.$root.imageHeight = val; }
    },
    imageView: {
      get() { return this.$root.imageView; },
      set(val) { this.$root.imageView = val; }
    },
    imageStyle: {
      get() { return this.$root.imageStyle; },
      set(val) { this.$root.imageStyle = val; }
    },
    isCurrentView() {
      return this.$root.isCurrentView;
    },
  },

  mounted() {
    const presetsList = this.$el.querySelector('#presetsList');
    const sortablePresets = new Sortable(presetsList, {
      animation: 150,
      handle: '.drag-handle',
      onEnd: this.$root.handleSortPresets,
    });
    this.$root.sortables.push(sortablePresets);

    $('#presetsButton').on('click', () => {
      this.$root.editingPresets = false;
    });
  },

  methods: {
    toggleEditingPresets() {
      this.editingPresets = !this.editingPresets;

      if (!this.editingPresets) {
        // Exit any ongoing renaming
        this.cancelRename();
      }
    },

    renameSet(preset) {
      // Toggle edit mode for this preset
      if (this.editingPreset === preset) {
        this.cancelRename();
        return;
      }

      // Start editing — seed input with current name
      this.editingPreset = preset;
      this.editingSetName = preset;

      // Focus the input after Vue updates the DOM
      this.$nextTick(() => {
        const input = document.querySelector(`#rename-${preset}`);
        if (input) {
          input.focus();
          input.select();
        }
      });
    },

    saveRename(preset) {
      const newName = this.editingSetName && this.editingSetName.trim();

      // If empty or same name, cancel
      if (!newName || newName === preset) {
        this.cancelRename();
        return;
      }

      this.$root.renamePreset(preset, newName);

      // Exit edit mode
      this.cancelRename();
    },

    cancelRename() {
      this.editingPreset = '';
      this.editingSetName = '';
    },

    handleRenameKeydown(event, preset) {
      if (event.key === 'Enter') {
        event.preventDefault();
        this.saveRename(preset);
      } else if (event.key === 'Escape') {
        this.cancelRename();
      }
    },
  },

  template: /*html*/ `
    <div class="dropdown mr-3">
      <button
        type="button"
        class="btn btn-outline-dark dropdown-toggle"
        id="presetsButton"
        :disabled="$root.disabledButtons"
        data-toggle="dropdown"
        aria-haspopup="true"
        aria-expanded="false"
      >
        {{ currentPreset }}
      </button>
      <div class="dropdown-menu presets-container custom-menu pt-0 mt-1">
        <div class="d-flex justify-content-between p-2 border-bottom">
          <div v-show="editingPresets" class="d-flex">
            <!-- Start Special elements -->
            <input type="file" id="hiddenFileInput" style="display: none" ref="doc" accept=".json"
              onchange="readFile" />
            <!-- End Special elements -->
            <button
              type="button"
              class="btn btn-icon-only btn-text-dark"
              data-toggle="tooltip"
              :title="$root.translated('import')"
              @click.stop="$root.importPresets()"
            >
              <i class="modus-icons">file_check_in</i>
            </button>
            <button
              type="button"
              class="btn btn-icon-only btn-text-dark"
              data-toggle="tooltip"
              :title="$root.translated('export')"
              @click.stop="$root.exportPresets()"
            >
              <i class="modus-icons">file_check_out</i>
            </button>
            <button
              type="button"
              class="btn btn-icon-only btn-text-dark"
              data-toggle="tooltip"
              :title="$root.translated('reset')"
              @click.stop="$root.resetPresets()"
            >
              <i class="modus-icons">refresh</i>
            </button>
          </div>

          <div class="ml-auto">
            <button
              v-show="editingPresets"
              type="button"
              class="btn btn-icon-only btn-text-success ml-1"
              @click.stop="$root.closePresets()"
            >
              <i class="modus-icons">check</i>
            </button>
            <button
              v-show="!editingPresets"
              type="button"
              class="btn btn-icon-only btn-text-dark"
              id="editPresets"
              ref="editButton"
              data-toggle="tooltip"
              :title="$root.translated('edit')"
              @click.stop="$root.editPresets()">
              <i class="modus-icons">tune</i>
            </button>
            <button
              v-show="!editingPresets"
              type="button"
              class="btn btn-icon-only btn-text-dark">
              <i class="modus-icons">close</i>
            </button>
          </div>
        </div>

        <div class="d-flex">
          <!-- SETTINGS -->
          <div class="p-2 units-settings">

            <!-- UNITS -->
            <div class="mb-2 bg-gray-light p-2 rounded">
              <h5 class="modal-title mr-auto mb-1">{{ $root.translated('units') }}</h5>

              <div class="form-group mb-1">
                <form class="d-flex mb-0">
                  <label class="custom-label flex-grow-1 mt-1" for="roundLength">
                    {{ $root.translated('length') }}
                  </label>
                  <select
                    v-model="roundLength"
                    class="custom-select form-control w-90 mr-1"
                    id="roundLength"
                  >
                    <option
                      v-for="(value, key) in $root.roundUnit"
                      :key="key"
                      :value="key"
                    >
                      {{ key }}
                    </option>
                  </select>

                  <select
                    v-model="formatLength"
                    class="custom-select form-control w-70"
                    id="formatLength"
                  >
                    <option
                      v-for="(value, key) in $root.lengthUnit"
                      :key="key"
                      :value="key"
                    >
                      {{ key }}
                    </option>
                  </select>
                </form>
              </div>

              <div class="form-group mb-1">
                <form class="d-flex mb-0">
                  <label class="custom-label flex-grow-1 mt-1" for="roundArea">
                    {{ $root.translated('area') }}
                  </label>
                  <select
                    v-model="roundArea"
                    class="custom-select form-control w-90 mr-1"
                    id="roundArea"
                  >
                    <option
                      v-for="(value, key) in $root.roundUnit"
                      :key="key"
                      :value="key"
                    >
                      {{ key }}
                    </option>
                  </select>

                  <select
                    v-model="formatArea"
                    class="custom-select form-control w-70"
                    id="formatArea"
                  >
                    <option
                      v-for="(value, key) in $root.areaUnit"
                      :key="key"
                      :value="key"
                    >
                      {{ key }}
                    </option>
                  </select>
                </form>
              </div>

              <div class="form-group mb-1">
                <form class="d-flex mb-0">
                  <label class="custom-label flex-grow-1 mt-1" for="roundVolume">
                    {{ $root.translated('volume') }}
                  </label>
                  <select
                    v-model="roundVolume"
                    class="custom-select form-control w-90 mr-1"
                    id="roundVolume"
                  >
                    <option
                      v-for="(value, key) in $root.roundUnit"
                      :key="key"
                      :value="key"
                    >
                      {{ key }}
                    </option>
                  </select>
                
                  <select
                    v-model="formatVolume"
                    class="custom-select form-control w-70"
                    id="formatVolume"
                  >
                    <option
                      v-for="(value, key) in $root.volumeUnit"
                      :key="key"
                      :value="key"
                    >
                      {{ key }}
                    </option>
                  </select>
                </form>
              </div>

              <div class="form-group mb-1">
                <form class="d-flex mb-0">
                  <label class="custom-label flex-grow-1 mt-1" for="currency">
                    {{ $root.translated('currency') }}
                  </label>
                  <select
                    v-model="currency"
                    class="custom-select form-control w-70 ml-1"
                    id="currency"
                  >
                    <option
                      v-for="(value, index) in $root.currencies"
                      :key="index"
                      :value="value"
                    >
                      {{ value }}
                    </option>
                  </select>
                </form>
              </div>

              <div class="form-group mb-0">
                <form class="d-flex mb-0">
                  <label class="custom-label flex-grow-1 mt-1" for="decimalSeparator">
                    {{ $root.translated('decimalSymbol') }}
                  </label>
                  <select
                    v-model="decimalSeparator"
                    class="custom-select form-control w-70"
                    id="decimalSeparator"
                  >
                    <option>.</option>
                    <option>,</option>
                  </select>
                </form>
              </div>
            </div>

            <!-- IMAGE -->
            <div class="p-2 bg-gray-light rounded">
              <div class="d-flex mb-1">
                <h5 class="modal-title mr-auto">{{ $root.translated('images') }}</h5>
                <form v-if="isCurrentView" class="form-inline">
                  <select
                    v-model="imageWidth"
                    class="custom-select form-control w-50 mr-1"
                    id="imageWidth"
                  >
                    <option
                      v-for="(value, index) in $root.imageSizes"
                      :key="index"
                      :value="value"
                    >
                      {{ value }}
                    </option>
                  </select>
                  <select
                    v-model="imageHeight"
                    class="custom-select form-control w-50"
                    id="imageHeight"
                  >
                    <option
                      v-for="(value, index) in $root.imageSizes"
                      :key="index"
                      :value="value"
                    >
                      {{ value }}
                    </option>
                  </select>
                </form>
              </div>

              <form class="form-inline mb-1">
                <select v-model="imageView"
                  class="custom-select form-control w-50 mr-1"
                  id="imageView"
                >
                  <option
                    v-for="(value, index) in $root.imageViews"
                    :key="index"
                    :value="value"
                  >
                    {{ value }}
                  </option>
                </select>
                <select v-model="imageStyle"
                  class="custom-select form-control w-50"
                  id="imageStyle"
                >
                  <option
                    v-for="(value, index) in $root.imageStyles"
                    :key="index"
                    :value="value"
                  >
                    {{ value }}
                  </option>
                </select>
              </form>
              <form class="form-inline mb-0">
                <input
                  type="text"
                  class="form-control mr-1 bg-white border text-truncate"
                  disabled
                  :placeholder="$root.translated('imagesFolderPath')"
                  id="folderPath" />
                <button
                  type="button"
                  class="btn btn-icon-only btn-text-secondary border"
                  data-toggle="tooltip"
                  :title="$root.translated('setImagesFolder')"
                  @click="$root.imagesFolder()"
                >
                  <i class="modus-icons">folder_open</i>
                </button>
              </form>
            </div>
          </div>

          <!-- PRESETS -->
          <div class="bg-white px-2">
            <div class="d-flex justify-content-between my-2">
              <input
                type="text"
                class="form-control custom-form-control"
                id="presetInput"
                :placeholder="$root.translated('newPreset')"
              />
              <button
                type="button"
                class="btn btn-sm btn-icon-only btn-primary ml-1 mt-1"
                id="addPreset"
                data-toggle="tooltip"
                :title="$root.translated('add')"
                @click.stop="$root.addPreset()">
                <i class="modus-icons">add</i>
              </button>
            </div>

            <div class="" id="presetsList">
              <div
                v-for="(preset, index) in presetsList"
                :key="preset"
                :id="\`preset-\${index}\`"
                class="d-flex mb-1"
              >
                <button
                  v-show="editingPresets"
                  class="drag-handle btn btn-sm btn-icon-only btn-text-secondary mt-1 mr-1"
                  style="cursor: grab"
                >
                  <i class="modus-icons">drag_indicator</i>
                </button>

                <button
                  v-show="editingPresets"
                  class="btn btn-sm btn-icon-only btn-text-danger mt-1 mr-1"
                  data-toggle="tooltip"
                  :title="$root.translated('delete')"
                  @click.stop="$root.deletePreset(preset)"
                >
                  <i class="modus-icons">delete</i>
                </button>

                <button
                  v-if="!(editingPresets && editingPreset === preset)"
                  :class="['preset-button btn btn-outline-dark flex-grow-1', { 'active': preset === currentPreset }]"
                  @click.stop="$root.selectPreset(preset)"
                >
                  {{ preset }}
                </button>

                <input
                  v-else
                  type="text"
                  class="form-control flex-grow-1 text-center"
                  :id="\`rename-\${preset}\`"
                  v-model="editingSetName"
                  @keydown="handleRenameKeydown($event, preset)"
                />

                <button
                  v-show="!editingPresets"
                  class="btn btn-sm btn-icon-only btn-text-dark mt-1 ml-1"
                  data-toggle="tooltip"
                  :title="$root.translated('update')"
                  @click.stop="$root.updatePreset(preset)"
                >
                  <i class="modus-icons">update</i>
                </button>

                  <button
                    v-if="editingPresets"
                    class="btn btn-sm btn-icon-only mt-1 ml-1"
                    :class="editingPreset === preset ? 'btn-text-success' : 'btn-text-dark'"
                    @click.stop="editingPreset !== preset ? renameSet(preset) : saveRename(preset)"
                  >
                    <i class="modus-icons">{{editingPreset !== preset ? 'pencil' : 'check'}}</i>
                  </button>
              </div>
            </div>
          </div>

        </div>
      </div>
    </div>
  `,
});
