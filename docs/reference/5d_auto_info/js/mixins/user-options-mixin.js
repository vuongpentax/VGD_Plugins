const userOptionsMixin = {
  data() {
    return {
      // User Options Modal
      userOptionsMessage: null,
      userOptionsType: '',
      userOptions: [
        {
          key: "option1",
          label: "Option 1",
          showLabel: true,
          type: "text",
          value: "",
          disabled: false,
          validationType: "string",
          messageError: null,
        },
      ],
      hasOptionsError: false,
    };
  },

  computed: {
  },

  mounted() {
  },

  beforeDestroy() {
  },

  methods: {
    initCreateNewColumn() {
      this.$root.modalTitle = this.translated('addColumn');
      this.userOptionsType = 'addCustomColumn';
      this.userOptions = [
        {
          key: "name_group",
          label: '',
          showLabel: false,
          type: "group",
          group: "horizontal",
          disabled: false,
          gap: "4px",
          children: [
            {
              key: "columnType",
              label: this.translated('type'),
              showLabel: true,
              type: "select",
              options: [
                { value: 'dynamic', label: this.translated('dynamic') },
                { value: 'custom', label: this.translated('customAttribute') }
              ],
              value: 'dynamic', // Default to dynamic (existing feature)
              disabled: false,
              width: '50%'
            },
            {
              key: "columnName",
              label: this.translated('name'),
              showLabel: true,
              type: "text",
              value: 'New Column',
              disabled: false,
              validationType: "string",
              messageError: null,
              width: '50%'
            }
          ]
        },
        {
          key: "custom_group",
          label: '',
          showLabel: false,
          type: "group",
          group: "horizontal",
          disabled: false,
          gap: "4px",
          children: [
            {
              key: 'attributeDictionaryName',
              label: this.translated('dictionaryName'),
              showLabel: true,
              type: 'text',
              value: '',
              hidden: true, // Hidden by default since default type is 'dynamic'
              placeholder: '...',
              validationType: 'string',
              messageError: null,
              width: '50%'
            },
            {
              key: 'attributeName',
              label: this.translated('attributeName'),
              showLabel: true,
              type: 'text',
              value: '',
              hidden: true, // Hidden by default since default type is 'dynamic'
              placeholder: '...',
              validationType: 'string',
              messageError: null,
              width: '50%'
            },
          ]
        }
      ];

      this.showUserOptions();
    },

    showUserOptions(focusKey = null) {
      // Hide all modals before showing user options modal
      hideAllModals();

      // Reset
      this.hasOptionsError = false;

      // Show modal
      this.$root.showModal('#userOptionsModal', 'wait');

      // Focus input if key provided
      if (focusKey) {
        this.focusUserOptionsInput(focusKey);
      }
    },

    focusUserOptionsInput(key) {
      $('#userOptionsModal').one('shown.bs.modal', () => {
        const inputElement = document.getElementById(`userOption_${key}`);

        if (inputElement) {
          inputElement.focus();
          inputElement.select();
        }
      });
    },

    onUserOptionChange(index, element, value, childKey = null) {
      if (!this.userOptions[index]) return;

      // Handle child options in group
      if (childKey && this.userOptions[index].type === 'group' && this.userOptions[index].children) {
        const childOption = this.userOptions[index].children.find(child => child.key === childKey);
        if (childOption) {
          childOption.value = value;
          childOption.messageError = null;

          // Clear error state from the element if validation exists
          if (element && childOption.validationType) {
            this.clearValidationError(element);
          }

          // Special handling for columnType changes
          if (childKey === 'columnType' && this.userOptionsType === 'addCustomColumn') {
            const customGroup = this.userOptions.find(opt => opt.key === 'custom_group');

            if (customGroup && customGroup.children) {
              // Show custom fields only when type is 'custom'
              // Hide custom fields when type is 'dynamic'
              customGroup.children.forEach(child => {
                this.$set(child, 'hidden', value !== 'custom');
              });
            }
          }
        }
        return; // Exit after handling child option
      }

      this.userOptions[index].value = value;

      // Clear validation error when user changes value
      if (this.userOptions[index]) {
        this.userOptions[index].messageError = null;
      }

      // Clear error state
      this.clearValidationError(element);
    },

    handleUserOptionsConfirm() {
      // Reset validation state
      this.hasOptionsError = false;

      // Loop through userOptions to validate each option
      this.userOptions.forEach((option, index) => {
        if (option.validationType && (option.type === 'input' || option.type === 'number' || option.type === 'text')) {
          const element = document.querySelector(`[data-option-index="${index}"]`);
          if (element) {
            const validation = this.validateInput(element, option.validationType, index, null);
            if (!validation.isValid) {
              this.hasOptionsError = true;
            }
          }
        }

        // Check existing messageError for regular options
        if (option.messageError) {
          this.hasOptionsError = true;
        }

        // Validate and check child options for group types
        if (option.type === 'group' && option.children) {
          option.children.forEach((child, childIndex) => {
            // Skip validation for hidden fields
            if (child.hidden) return;

            // Validate child options with validationType
            if (child.validationType && (child.type === 'input' || child.type === 'number' || child.type === 'text')) {
              const childElement = document.querySelector(`[data-option-index="${index}"][data-child-key="${child.key}"]`);
              if (childElement) {
                const validation = this.validateInput(childElement, child.validationType, index, child.key);
                if (!validation.isValid) {
                  this.hasOptionsError = true;
                }
              }
            }

            // Check existing messageError for child options
            if (child.messageError) {
              this.hasOptionsError = true;
            }
          });
        }
      });

      // If there is any error, do not proceed
      if (this.hasOptionsError) {
        const message = this.translated("pleaseFixValidationErrors");
        this.$root.showMessageModal(message, "error");
        return;
      }

      // Process user options
      this.processUserOptions();
      this.$root.hideModal('#userOptionsModal');
    },

    handleUserOptionsCancel() {
      // Reset all validation errors
      this.userOptions.forEach((option) => {
        option.messageError = null;

        // Reset child options validation errors
        if (option.type === 'group' && option.children) {
          option.children.forEach(child => {
            child.messageError = null;
          });
        }
      });

      // Hide modal
      this.$root.hideModal('#userOptionsModal');

      // Reset states
      this.hasOptionsError = false;
      this.$root.modalAction1 = null;
      this.$root.modalAction2 = null;
      this.$root.modalTitle = "";
    },

    processUserOptions() {
      // Create an object with the user option values
      const optionValues = {};

      this.userOptions.forEach((option) => {
        if (option.type === 'group' && option.children) {
          // Handle group options - collect values from children
          option.children.forEach(child => {
            optionValues[child.key] = child.value;
          });
        } else {
          // Handle regular option
          optionValues[option.key] = option.value;
        }
      });

      let showProcessingMessage = false;

      switch (true) {
        case this.userOptionsType === 'exportTextures':
          sketchup.exportTextures(this.selectedItems, this.selectedType, optionValues);
          showProcessingMessage = true;
          break;

        case this.userOptionsType === 'addCustomColumn':
          // Check columnType to determine which method to call
          const columnType = optionValues.columnType || 'custom';

          if (columnType === 'dynamic') {
            // Use the existing addCustomDynamicColumn method for Dynamic Attributes
            this.$root.addCustomDynamicColumn(optionValues);
          } else {
            // Use the new method for Custom Attributes
            this.$root.addCustomAttributeColumn(optionValues);
          }
          break;

        default:
          break;
      }

      // Show processing message
      if (showProcessingMessage) {
        const message = this.translated('processing');
        this.$root.showMessageModal(message, 'processing', 'wait');
      }

      // Clear user options after processing
      this.userOptions = [];
      this.userOptionsType = '';
      this.checkedList = [];
      this.selectedItems = [];
    }
  }
};
