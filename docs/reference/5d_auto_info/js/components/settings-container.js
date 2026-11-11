Vue.component("settings-container", {
  computed: {
    currency: {
      get() { return this.$root.currency; },
      set(val) { this.$root.currency = val; }
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
    isNewVersion() {
      return this.$root.isNewVersion;
    },
    isCurrentView() {
      return this.$root.isCurrentView;
    },
  },

  template: /*html*/ `
    <div class="d-flex">
      <!-- Theme -->
      <button
        type="button"
        class="btn btn-icon-only btn-text-dark badge-pill mr-1"
        data-toggle="tooltip"
        :title="$root.translated('switchTheme')"
        @click="$root.switchTheme()"
      >
        <i class="modus-icons">{{ $root.themeIcon }}</i>
      </button>

      <!-- Settings -->
      <div class="dropdown" id="settings">
        <button
          type="button"
          class="btn btn-icon-only btn-text-dark badge-pill"
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          <i class="modus-icons">settings</i>
        </button>
        <div class="dropdown-menu dropdown-menu-right custom-menu mt-1" id="options">
          <div class="px-3 pt-3">
            <div class="d-flex justify-content-between mb-3">
              <h5 class="modal-title">{{ $root.translated('settings') }}</h5>
              <button type="button" class="btn btn-sm btn-icon-only btn-danger" data-dismiss="modal"
                aria-label="Close">
                <i class="modus-icons">close</i>
              </button>
            </div>
          </div>
          <div id="bodyOptions">
            <div class="px-3 pb-2">
              <!-- LANGUAGE & CURRENCY -->
              <div class="form-group">
                <form class="form-inline">
                  <select
                    class="form-control custom-select"
                    id="language"
                    :value="$root.language"
                    @change="$root.changeLanguage($event.target.value)"
                  >
                    <option
                      v-for="lang in $root.languages"
                      :key="lang.code"
                      :value="lang.code"
                    >
                      {{ lang.name }}
                    </option>
                  </select>
                </form>
              </div>

              <!-- More Extensions -->
              <button
                type="button"
                class="btn btn-block btn-outline-dark"
                data-toggle="tooltip"
                :title="$root.translated('findMoreExtensions')"
                @click="$root.openSupporter('store')"
              >
                {{ $root.translated('moreExtensions') }}
              </button>

              <!-- Check Update -->
              <button
                type="button"
                class="btn btn-primary btn-block border"
                data-toggle="tooltip"
                :title="$root.translated('checkVersion')"
                id="downloadNew"
                @click="$root.checkUpdate"
              >
                <div
                  v-if="isNewVersion"
                  class="download-notification"
                  id="newVersion"
                ></div>
                {{ $root.translated('checkForUpdate') }}
              </button>

              <!-- Support -->
              <div class="chip chip-solid chip-input btn-block" data-toggle="modal" data-target="#supportModal">
                <div class="chip-thumbnail">
                  <img src="../images/trinhvucuong.jpg" alt="" />
                </div>
                <div
                  class="chip-text text-center d-block"
                  data-toggle="tooltip"
                  :title="$root.translated('inviteCoffee')"
                >
                  {{ $root.translated('supportMe') }}
                </div>
              </div>
            </div>
          </div>
          <div class="dropdown-divider"></div>
          <div class="px-3 pt-1 pb-2">
            <!-- Version Info -->
            <a
              href=""
              class="text-decoration-none"
              data-toggle="tooltip"
              :title="$root.translated('releaseNotes')"
              @click.stop="$root.openSupporter('releaseNotes')"
            >
              <p class="text-center mb-2">
                {{ $root.translated('releaseDate') }}<br />2026.06.16
              </p>
            </a>
          </div>
        </div>
      </div>
    </div>
  `,
});
