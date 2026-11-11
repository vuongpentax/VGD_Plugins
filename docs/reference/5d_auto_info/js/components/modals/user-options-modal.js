Vue.component("user-options-modal", {
  props: {
    userOptionsMessage: {
      type: String,
      default: null
    },
    userOptions: {
      type: Array,
      default: () => []
    },
  },

  template: /*html*/ `
    <div class="modal fade" tabindex="-1" role="dialog" id="userOptionsModal">
      <div class="modal-dialog modal-dialog-centered option-dialog" role="document">
        <div class="modal-content custom-modal">
          <modal-header
            :modal-title="$root.modalTitle || $root.translated('options')"
          ></modal-header>
          <div class="modal-body pb-2">
            <div
              v-if="userOptionsMessage"
              class="message message-primary"
            >
              <i class="modus-icons">info</i>
              <span>
                {{ userOptionsMessage }}
              </span>
            </div>

            <div class="options-container">
              <div
                v-for="(option, index) in userOptions"
                :key="index"
                class="form-group custom-form-group"
              >
                <div class="d-flex align-items-center justify-content-between w-100">
                  <label
                    v-if="option.showLabel"
                    :for="'userOption_' + option.key"
                    class="option-label"
                  >
                    {{ option.label }}
                  </label>
                </div>

                <!-- Group Layout (for horizontal display of multiple fields) -->
                <div v-if="option.type === 'group'">
                  <label
                    v-if="option.showLabel"
                    class="option-label"
                  >
                    {{ option.label }}
                  </label>

                  <div class="d-flex">
                    <div
                      v-for="(childOption, childIndex) in option.children"
                      :key="childOption.key"
                      :style="{ width: childOption.width || 'auto', marginRight: childIndex < option.children.length - 1 ? option.gap : '0' }"
                    >
                      <div>
                        <!-- Child Label -->
                        <label
                          v-if="childOption.showLabel && !childOption.hidden"
                          :for="'userOption_' + childOption.key"
                          class="option-label"
                        >
                          {{ childOption.label }}
                        </label>

                        <!-- Text Input for child -->
                        <input
                          v-if="(childOption.type === 'text' || childOption.type === 'number') && !childOption.hidden"
                          :type="childOption.type"
                          :id="'userOption_' + childOption.key"
                          class="form-control custom-form-control"
                          :class="{ 'is-invalid': childOption.messageError }"
                          :value="childOption.value"
                          :data-option-index="index"
                          :data-child-key="childOption.key"
                          @input="$parent.onUserOptionChange(index, $event.target, $event.target.value, childOption.key)"
                          @blur="childOption.validationType ? $parent.handleInputValidation(index, $event.target, childOption.validationType, childOption.key) : null"
                          :maxlength="childOption.maxlength || 100"
                          :placeholder="childOption.placeholder || ''"
                          :disabled="childOption.disabled"
                        />

                        <!-- Select for child -->
                        <select
                          v-else-if="childOption.type === 'select' && !childOption.hidden"
                          :id="'userOption_' + childOption.key"
                          class="form-control custom-select"
                          :class="{ 'is-invalid': childOption.messageError }"
                          :value="childOption.value"
                          :disabled="childOption.disabled"
                          @change="$parent.onUserOptionChange(index, $event.target, $event.target.value, childOption.key)"
                        >
                          <option
                            v-for="(optionItem, optIndex) in childOption.options"
                            :key="optIndex"
                            :value="optionItem.value"
                          >
                            {{ optionItem.label }}
                          </option>
                        </select>

                        <!-- Error Message for child -->
                        <div v-if="childOption.messageError && (childOption.showMessageError !== false)" class="invalid-feedback">
                          <small class="text-danger">{{ childOption.messageError }}</small>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div>
                  <!-- Input -->
                  <input
                    v-if="option.type === 'text' || option.type === 'number'"
                    :type="option.type"
                    :id="'userOption_' + option.key"
                    class="form-control custom-form-control"
                    :class="{ 'is-invalid': option.messageError }"
                    :value="option.value"
                    :data-option-index="index"
                    @input="$parent.onUserOptionChange(index, $event.target, $event.target.value)"
                    @blur="option.validationType ? $parent.handleInputValidation(index, $event.target, option.validationType) : null"
                    :placeholder="option.placeholder || ''"
                    :disabled="option.disabled"
                  />

                  <!-- Select -->
                  <select
                    v-else-if="option.type === 'select'"
                    :id="'userOption_' + option.key"
                    class="form-control custom-select"
                    :class="{ 'is-invalid': option.messageError }"
                    :value="option.value"
                    :disabled="option.disabled"
                    @change="$parent.onUserOptionChange(index, $event.target, $event.target.value)"
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
                        @change="$parent.onUserOptionChange(index, $event.target, $event.target.value)"
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
                      :id="'userOption_' + option.key"
                      class="custom-control-input"
                      :class="{ 'is-invalid': option.validationError }"
                      :checked="option.value"
                      :disabled="option.disabled"
                      @change="$parent.onUserOptionChange(index, $event.target, $event.target.checked)"
                    />
                    <label :for="'userOption_' + option.key" class="custom-control-label">
                      <span class="clipped-text">{{ option.label }}</span>
                      <a
                        v-if="option.toolTip"
                        href=""
                        target="_blank"
                        data-toggle="tooltip"
                        :title="option.toolTip">?</a>
                    </label>
                  </div>

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
              action: () => $parent.handleUserOptionsCancel()
            }"
            :modalAction2 = "{
              text: 'OK',
              action: () => $parent.handleUserOptionsConfirm(),
              disabled: !!$parent.hasOptionsError
            }"
          ></modal-footer>
        </div>
      </div>
    </div>
  `,
});
