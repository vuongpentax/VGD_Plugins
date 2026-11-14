Vue.component("user-options-modal", {
  template: /*html*/ `
    <div class="modal fade" tabindex="-1" role="dialog" id="userOptionsModal">
      <div class="modal-dialog modal-dialog-centered option-dialog" role="document">
        <div class="modal-content custom-modal">
          <modal-header
            :modal-title="$root.modalTitle"
            :edit-title="$root.editTitle"
            :edit-action="$root.editAction"
          ></modal-header>
          <div class="modal-body pb-2">
            <div class="options-container">
              <div
                v-if="option.key && !option.hidden"
                v-for="(option, index) in $root.userOptions"
                :key="index"
                class="form-group custom-form-group"
                :class="[
                  $root.directionOptionsModal == 'horizontal' ? 'd-flex' : '',
                ]"
              >
                <!-- Regular fields -->
                <div class="d-flex align-items-center justify-content-between w-100">
                  <label
                    v-if="option.showLabel"
                    :for="'userOption' + index"
                    class="option-label"
                    :class="{ 'mt-1 w-50': $root.directionOptionsModal == 'horizontal' }"
                  >
                    {{ option.label }}
                    <a
                      v-if="option.toolTip"
                      href="" target="_blank"
                      data-toggle="tooltip"
                      :title="option.toolTip"
                    >?</a>
                  </label>

                  <input
                    v-if="option.type === 'slider'"
                    class="form-control slider-value text-center"
                    type="number"
                    @input="$root.onUserOptionChange(index, $event.target, $event.target.value)"
                    :value="$root.optionsSliderValue"
                    :min="option.min"
                    :max="option.max"
                  />
                </div>

                <div v-if="option.type !== 'group'" :class="{ 'w-50': $root.directionOptionsModal == 'horizontal' }">
                  <!-- Text Input -->
                  <input
                    v-if="option.type === 'input' || option.type === 'number'"
                    :type="option.type"
                    :id="'userOption' + index"
                    class="form-control custom-form-control"
                    :class="{ 'is-invalid': option.messageError, 'text-dark': option.key === 'preview_text' }"
                    :value="$root.translated(option.value)"
                    :data-option-index="index"
                    @input="$root.onUserOptionChange(index, $event.target, $event.target.value)"
                    @blur="option.validationType ? $root.handleInputValidation(index, $event.target, option.validationType) : null"
                    :maxlength="option.maxlength || 100"
                    :placeholder="option.placeholder || ''"
                    :disabled="option.disabled"
                  />

                  <!-- Select Dropdown -->
                  <select
                    v-else-if="option.type === 'select'"
                    :id="'userOption' + index"
                    class="form-control custom-select"
                    :class="{ 'is-invalid': option.messageError }"
                    :value="option.value"
                    :disabled="option.disabled"
                    @change="$root.onUserOptionChange(index, $event.target, $event.target.value)"
                  >
                    <option
                      v-for="(optionItem, optIndex) in option.options"
                      :key="optIndex"
                      :value="optionItem.value"
                    >
                      {{ optionItem.label }}
                    </option>
                  </select>

                  <!-- Radio -->
                  <div v-else-if="option.type === 'radio'" class="mb-2">
                    <div 
                      v-for="(optionItem, optIndex) in option.options"
                      :key="option.key + optIndex"
                      class="custom-control custom-radio"
                      :disabled="optionItem.disabled"
                    >
                      <input
                        class="custom-control-input"
                        type="radio"
                        :name="'gridRadios' + option.key"
                        :id="'gridRadios' + option.key + optIndex"
                        :value="optionItem.value"
                        :checked="optionItem.value === option.value"
                        :disabled="option.disabled || optionItem.disabled"
                        @change="$root.onUserOptionChange(index, $event.target, $event.target.value)"
                      >
                      <label class="custom-control-label" :for="'gridRadios' + option.key + optIndex">
                        {{ optionItem.label }}
                      </label>
                    </div>
                  </div>

                  <!-- Checkbox -->
                  <div v-else-if="option.type === 'checkbox'" class="custom-control custom-checkbox">
                    <input
                      type="checkbox"
                      :id="'userOption' + index"
                      class="custom-control-input"
                      :class="{ 'is-invalid': option.validationError }"
                      :checked="option.value"
                      :disabled="option.disabled"
                      @change="$root.onUserOptionChange(index, $event.target, $event.target.checked)"
                    />
                    <label :for="'userOption' + index" class="custom-control-label">
                      <span class="clipped-text">{{ option.label }}</span>
                      <a
                        v-if="option.toolTip"
                        href=""
                        target="_blank"
                        data-toggle="tooltip"
                        :title="option.toolTip">?</a>
                    </label>
                  </div>

                  <!-- Slider -->
                  <div v-else-if="option.type === 'slider'" class="mt-1">
                    <input
                      type="range"
                      class="custom-range"
                      @input="$root.onUserOptionChange(index, $event.target, $event.target.value)"
                      :value="option.value"
                      :min="option.min"
                      :max="option.max"
                      :step="option.step"
                      :id="'customRange' + index"
                    >
                  </div>

                  <small v-if="option.helpText" id="passwordHelpBlock" class="form-text text-muted">
                    {{ option.helpText || '' }}
                  </small>

                  <!-- Error Message -->
                  <div v-if="option.messageError && (option.showMessageError !== false)" class="invalid-feedback">
                    <small class="text-danger">{{ option.messageError }}</small>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <modal-footer
            :modalAction1 = "{
              text: 'cancel',
              action: () => $root.handleUserOptionsCancel()
            }"
            :modalAction2 = "{
              text: 'OK',
              action: () => $root.handleUserOptionsConfirm(),
              disabled: !!$root.hasOptionsError
            }"
          ></modal-footer>
        </div>
      </div>
    </div>
  `,
});
