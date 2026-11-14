Vue.component('color-modal', {
  template: /*html*/ `
    <div
      class="modal fade"
      id="colorPickerModal"
      tabindex="-1"
      role="dialog"
    >
       <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-menu">
          <div class="modal-header">
            <h5 class="modal-title">
              {{ $root.translated('colorPicker') }}
            </h5>
            <button type="button" class="btn btn-sm btn-icon-only btn-danger" data-dismiss="modal" aria-label="Close">
              <i class="modus-icons">close</i>
            </button>
          </div>
          <div class="">
            <!-- Thumbnail -->
            <div class="preview-container d-flex p-2">
              <div class="image-container" >
                <div class="solid-color" :style="{ backgroundColor: $root.rgbString }">
                </div>

                <div class="alpha-overlay"
                  :style="[$root.overlayStyles, { backgroundColor: 'rgba(255, 255, 255, ' + (1 - $root.alphaValue) + ')' }]"
                >
                </div>
              </div>
            </div>

            <!-- Color -->
            <div class="color-container mt-2">
              <ul class="nav nav-tabs nav-tabs-sm d-flex justify-content-center" role="tablist">
                <li class="nav-item">
                  <a class="nav-link" data-toggle="tab" href="#wheelColor" role="tab">HEX</a>
                </li>
                <li class="nav-item">
                  <a class="nav-link active" data-toggle="tab" href="#rgbColor" role="tab">RGB</a>
                </li>
                <li class="nav-item">
                  <a class="nav-link" data-toggle="tab" href="#hslColor" role="tab">HSL</a>
                </li>
              </ul>
      
              <div class="tab-content bg-white px-2 py-3">
                <div class="tab-pane fade" id="wheelColor" role="tabpanel" aria-labelledby="wheelColorTab">
                  <div class="ColorPicker" id="hexPicker"></div>
                  <div class="color-info d-flex mt-2 px-2">
                    <div class="color-circle mr-1" :style="{ backgroundColor: $root.hexString }"></div>
                    <input
                      @keydown.enter="$root.validateAndUpdateValue($event.target.value, 'hex')"
                      @blur="$root.validateAndUpdateValue($event.target.value, 'hex')"
                      @focus="$root.selectContent"
                      :value="$root.hexString"
                      type="text"
                      class="form-control text-center"
                      />
                  </div>
                </div>
      
                <div class="tab-pane fade show active" id="rgbColor" role="tabpanel" aria-labelledby="rgbColorTab">
                  <div class="d-flex px-2">
                    <div class="color-titles mr-1">
                      <div class="color-title">R</div>
                      <div class="color-title">G</div>
                      <div class="color-title">B</div>
                    </div>
                    <div class="ColorPicker" id="rgbPicker"></div>
                    <div class="color-values ml-1">
                      <input
                        @input="$root.validateAndUpdateValue($event.target.value, 'red')"
                        @focus="$root.selectContent"
                        :value="$root.redValue"
                        type="number"
                        min="0"
                        max="255"
                        class="color-value color-form-control custom-input text-center"
                      />
                      <input
                        @input="$root.validateAndUpdateValue($event.target.value, 'green')"
                        @focus="$root.selectContent"
                        :value="$root.greenValue"
                        type="number"
                        min="0"
                        max="255"
                        class="color-value color-form-control custom-input text-center mt-1"
                      />
                      <input
                        @input="$root.validateAndUpdateValue($event.target.value, 'blue')"
                        @focus="$root.selectContent"
                        :value="$root.blueValue"
                        type="number"
                        min="0"
                        max="255"
                        class="color-value color-form-control custom-input text-center mt-1"
                      />
                    </div>
                  </div>

                  <div class="color-info d-flex mt-3 px-2">
                    <div class="color-circle mr-1" :style="{ backgroundColor: $root.rgbString }"></div>
                    <input
                      disabled
                      :value="$root.rgbString"
                      type="text"
                      class="form-control text-center"
                      />
                  </div>
                </div>

                <div class="tab-pane fade" id="hslColor" role="tabpanel" aria-labelledby="hslColorTab">
                  <div class="d-flex px-2">
                    <div class="color-titles mr-1">
                      <div class="color-title">H</div>
                      <div class="color-title">S</div>
                      <div class="color-title">L</div>
                    </div>
                    <div class="ColorPicker" id="hslPicker"></div>
                    <div class="color-values ml-1">
                      <input
                        @input="$root.validateAndUpdateValue($event.target.value, 'hue')"
                        @focus="$root.selectContent"
                        :value="$root.hueValue"
                        type="number"
                        min="0"
                        max="359"
                        class="color-value color-form-control custom-input text-center"
                      />
                      <input
                        @input="$root.validateAndUpdateValue($event.target.value, 'saturation')"
                        @focus="$root.selectContent"
                        :value="$root.saturationValue"
                        type="number"
                        min="0"
                        max="100"
                        class="color-value color-form-control custom-input text-center mt-1"
                      />
                      <input
                        @input="$root.validateAndUpdateValue($event.target.value, 'lightness')"
                        @focus="$root.selectContent"
                        :value="$root.lightnessValue"
                        type="number"
                        min="0"
                        max="100"
                        class="color-value color-form-control custom-input text-center mt-1"
                      />
                    </div>
                  </div>
      
                  <div class="color-info d-flex mt-3 px-2">
                    <div
                      class="color-circle mr-1"
                      :style="{ backgroundColor: $root.hslString }">
                    </div>
                    <input
                      disabled
                      :value="$root.hslString"
                      type="text"
                      class="form-control text-center"
                      />
                  </div>
                </div>
              </div>
            </div>

            <!-- Transparent Picker -->
            <div class="transparent-container d-flex p-2 align-items-center bg-gray-1">
              <div class="color-picker mr-1" id="transPicker"></div>
              <input
                @input="$root.validateAndUpdateValue($event.target.value, 'alpha')"
                @focus="$root.selectContent"
                :value="$root.transValue"
                type="number"
                min="0"
                max="100"
                class="color-form-control custom-input text-center"
              />
            </div>
          </div>

          <div class="modal-footer justify-content-center">
            <button
              type="button"
              class="btn btn-primary"
              @click="$root.changeLayerColor()"
            >
              {{ $root.translated('ok') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
});

