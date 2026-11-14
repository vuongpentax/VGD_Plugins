Vue.component("settings-container", {
  template: /*html*/ `
    <li class="nav-settings ml-auto mt-2 mr-3">
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
        <div class="dropdown">
          <button
            class="btn btn-icon-only btn-text-dark badge-pill"
            type="button"
            data-toggle="dropdown"
            aria-haspopup="true"
            aria-expanded="false"
          >
            <i class="modus-icons">settings</i>
          </button>

          <div
            class="dropdown-menu dropdown-menu-right custom-menu"
            id="settings"
          >
            <div class="px-3 pt-3">
              <div class="d-flex justify-content-between mb-3">
                <h5 class="modal-title">{{ $root.translated('settings') }}</h5>
                <button
                  type="button"
                  class="btn btn-sm btn-icon-only btn-danger"
                  data-dismiss="modal"
                  aria-label="Close"
                >
                  <i class="modus-icons">close</i>
                </button>
              </div>
            </div>
            <div class="px-3 pb-2" id="bodySettings">
              <!-- Language -->
              <div class="form-group">
                <form class="form-inline">
                  <select
                    class="form-control custom-select w-100"
                    id="language"
                    :value="$root.language"
                    @change="$root.changeLanguage($event.target.value)"
                  >
                    <option v-for="lang in $root.languages" :key="lang.code" :value="lang.code">
                      {{ lang.name }}
                    </option>
                  </select>
                </form>
              </div>

              <button
                type="button"
                class="btn btn-block btn-dark mt-2"
                @click="$root.sketchupActions('customSettings')"
              >
                {{ $root.translated('customSettings') }}
              </button>

              <!--
              <button
                type="button"
                class="btn btn-block btn-outline-dark mt-2"
                :disabled="$root.isReset"
                id="resetAll"
                @click="$root.resetAll()"
              >
                {{ $root.translated('resetAll') }}
              </button>
              -->

              <button
                type="button"
                class="btn btn-block btn-primary"
                @click="$root.openSupporter('samples')"
              >
                {{ $root.translated('downloadSample') }}
              </button>

              <button
                class="btn btn-block btn-success"
                type="button"
                @click="$root.openSupporter('userManual')"
              >
                {{ $root.translated('userManual') }}
              </button>

              <button
                type="button"
                class="btn btn-block btn-outline-dark"
                @click="$root.openSupporter('store')"
              >
                {{ $root.translated('moreExtensions') }}
              </button>

              <button
                type="button"
                class="btn btn-tertiary btn-block border"
                id="downloadNew"
                @click="$root.checkUpdate"
              >
                <div
                  v-if="$root.isNewVersion"
                  class="download-notification"
                  id="newVersion"
                ></div>
                {{ $root.translated('checkForUpdate') }}
              </button>

              <div
                class="chip chip-solid chip-input btn-block"
                data-toggle="modal"
                data-target="#supportModal"
              >
                <div class="chip-thumbnail">
                  <img src="../images/trinhvucuong.jpg" alt="" />
                </div>
                <div
                  class="chip-text text-center d-block"
                  data-toggle="tooltip"
                  :title="$root.translated('inviteCoffee')">
                  {{ $root.translated('supportMe') }}
                </div>
              </div>
            </div>

            <div class="dropdown-divider mt-0"></div>

            <div class="px-3">
              <a
                href=""
                class="text-decoration-none"
                data-toggle="tooltip"
                :title="$root.translated('releaseNotes')"
                @click.stop="$root.openSupporter('releaseNotes')"
              >
                <p class="text-center mb-2">
                  {{ $root.translated('releaseDate') }}<br />2026.02.22
                </p>
              </a>
            </div>
          </div>
        </div>
      </div>

      <!-- Notification -->
      <div
        v-if="$root.isNewVersion"
        class="mr-1"
        data-toggle="tooltip"
        :title="$root.translated('new')"
      >
      </div>
    </li>
  `,
});
