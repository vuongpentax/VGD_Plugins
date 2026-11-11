const validatorsMixin = {
  methods: {
    handleInputValidation(element, validationType, index = null, childKey = null) {
      // Early return if element is invalid
      if (!element) return;

      // Get element ID & value
      const elementId = element.id;
      const elementValue = element.value;

      // Validate immediately on blur (no need for debouncing)
      const validationResult = this.validateInput(element, validationType, index, childKey);

      // Get validated value with fallback
      const validateValue = validationResult.value !== undefined
        ? validationResult.value
        : (elementValue || '');

      if (elementId === 'buildingNameInput' && validationResult.isValid) {
        this.saveBuildingMetadata();
      } else if (elementId === 'uPrefixInput') {
        this.useUPrefix = true;
        if (this.gridsData && this.gridsData.axesData && this.gridsData.axesData.uAxes) {
          this.gridsData.axesData.uAxes.prefix = validateValue;
        }
      } else if (elementId === 'vPrefixInput') {
        this.useVPrefix = true;
        if (this.gridsData && this.gridsData.axesData && this.gridsData.axesData.vAxes) {
          this.gridsData.axesData.vAxes.prefix = validateValue;
        }
      }

      // Only format imperial for number types, not for string types
      const isNumberType = validationType === 'number' || validationType === 'numberPositive';
      const formattedValue = (isNumberType && !this.isMetric) ? formatImperial(validateValue) : validateValue;

      // Safely set element value
      if (element && typeof elementValue !== 'undefined') {
        element.value = formattedValue;
      }

      // Update Vue data model to persist formatted value across re-renders
      if (this.userOptions && this.userOptions[index]) {
        if (childKey && this.userOptions[index].type === 'group' && this.userOptions[index].children) {
          // Update child option value
          const childOption = this.userOptions[index].children.find(child => child.key === childKey);
          if (childOption) {
            this.$set(childOption, 'value', formattedValue);
          }
        } else {
          // Update regular option value
          this.$set(this.userOptions[index], 'value', formattedValue);
        }
      }

      // Update error state
      this.hasOptionsError = validationResult.isValid === false;
    },

    validateInput(element, validationType, index = null, childKey = null) {
      if (!element) return { isValid: true };

      const value = element.value;
      let validation = { isValid: true };

      // Remove existing error styling
      element.classList.remove('is-invalid');

      const stringMatch = validationType.match(/^(string|stringEmpty)-(\d+)$/);
      if (stringMatch) {
        const allowEmpty = stringMatch[1] === 'stringEmpty';
        const maxLength = parseInt(stringMatch[2], 10);
        validation = this.validateStringInput(value, allowEmpty, maxLength, index, childKey);
      } else {
        switch (validationType) {
          case 'pageName':
            validation = this.validatePageName(value, index, childKey);
            break;
          case 'prefix':
            validation = this.validateStringInput(value, true, 10, index, childKey); // Allow empty, max 10 chars
            break;
          case 'stringEmpty':
            validation = this.validateStringInput(value, true, 50, index, childKey); // Allow empty, max 50 chars
            break;
          case 'string':
            validation = this.validateStringInput(value, false, 50, index, childKey); // No empty, max 50 chars
            break;
          case 'number':
            validation = this.validateNumberInput(value, true, true, index, childKey); // allow zero, allow negative
            break;
          case 'numberPositive':
            validation = this.validateNumberInput(value, true, false, index, childKey); // allow zero, disallow negative
            break;
          default:
            return { isValid: true };
        }
      }

      // Show validation result
      if (!validation.isValid) {
        this.showValidationError(element, validation.message);

        // Keep original invalid value in input so user can see what they typed
        if (validation.originalValue !== undefined) {
          element.value = validation.originalValue;
        }

        return validation;
      } else {
        // Don't set hasOptionsError here, as other fields might still have errors
        return validation;
      }
    },

    validateStringInput(value, allowEmpty = false, maxLength = 50, index = null, childKey = null) {
      // Safely convert value to string and trim
      const stringValue = value == null ? '' : String(value);
      const trimmedValue = stringValue.trim();

      let isValid = true;
      let message = null;

      // Check if value is empty (when not allowed)
      if (!allowEmpty && !trimmedValue) {
        message = this.translated("cannotBeEmpty");
        isValid = false;
      }

      // Only validate length if value is not empty
      if (isValid && trimmedValue) {
        // Check name length (max characters)
        if (isValid && trimmedValue.length > maxLength) {
          message = this.translated("nameTooLong").replace("{max}", maxLength);
          isValid = false;
        }
      }

      // Set messageError for the appropriate option or child option
      if (!isValid) {
        if (index !== null) {
          if (childKey && this.userOptions[index] && this.userOptions[index].type === 'group' && this.userOptions[index].children) {
            const childOption = this.userOptions[index].children.find(child => child.key === childKey);
            if (childOption) {
              childOption.messageError = message;
            }
          } else if (this.userOptions[index]) {
            this.userOptions[index].messageError = message;
          }
        }

        return {
          originalValue: value,
          message: message,
          type: 'error',
          isValid: false
        };
      }

      return { isValid: true };
    },

    validateNumberInput(value, allowZero = false, allowNegative = false, index = null, childKey = null) {
      // Safely convert value to string and trim
      const stringValue = value == null ? '' : String(value);
      const trimmedValue = stringValue.trim();

      const originalValue = value;
      let numericValue = null;
      let isValid = true;
      let message = null;

      // Check if value is empty
      if (!trimmedValue) {
        message = this.translated("cannotBeEmpty");
        isValid = false;
      }

      // Only validate format if value is not empty
      if (isValid) {
        // Regex patterns for valid formats:
        // 1. Positive number (integer or decimal): 123, 123.45, .45
        // 2. Feet only: 6'
        // 3. Inches only: 12"
        // 4. Feet and inches: 6'12", 6' 12", 6'12, 6' 12
        // 5. Feet with fractional inches: 6'12 1/2", 6' 12 1/2"

        // Plain number: -12, 12.3, .5, -0.25
        const numberRegex = /^-?(\d+\.?\d*|\.\d+)$/;

        // Pattern for imperial format: feet'inches" or feet' inches" with optional fractions
        // Added -? at the beginning to support negative imperial values like -4", -6'12"
        const imperialRegex = /^-?(\d+)'\s*(\d+)?\s*(\d+\/\d+)?\s*"?$|^-?(\d+)\s*(\d+\/\d+)?\s*"$/;

        const isPlainNumber = numberRegex.test(trimmedValue);
        const isImperial = imperialRegex.test(trimmedValue);

        // Invalid format
        if (!isPlainNumber && !isImperial) {
          message = this.translated("mustBeNumber");
          isValid = false;
        } else {
          // Parse the value based on format
          if (isPlainNumber) {
            numericValue = parseFloat(trimmedValue);
          } else {
            numericValue = typeof parseImperial === 'function' ? parseImperial(trimmedValue) : NaN;
          }

          // Validate parsed value
          if (typeof numericValue !== 'number' || Number.isNaN(numericValue)) {
            message = this.translated('mustBeNumber');
            isValid = false;
          }

          // Check zero (only if value is valid)
          if (isValid && !allowZero && numericValue === 0) {
            message = this.translated('cannotBeZero');
            isValid = false;
          }

          // Check negative (only if value is valid)
          if (isValid && !allowNegative && numericValue < 0) {
            message = this.translated('cannotBeNegative');
            isValid = false;
          }
        }
      }

      // Set messageError for the appropriate option or child option
      if (!isValid) {
        if (index !== null) {
          if (childKey && this.userOptions[index] && this.userOptions[index].type === 'group' && this.userOptions[index].children) {
            const childOption = this.userOptions[index].children.find(child => child.key === childKey);
            if (childOption) {
              childOption.messageError = message;
            }
          } else if (this.userOptions[index]) {
            this.userOptions[index].messageError = message;
          }
        }

        return {
          originalValue: originalValue,
          message: message,
          type: 'error',
          isValid: false,
        };
      }

      this.hasOptionsError = false;

      return {
        originalValue: originalValue,
        value: numericValue,
        message: null,
        type: 'success',
        isValid: true,
      };
    },

    showValidationError(element, message) {
      if (!element) return;

      // Add error styling to input
      element.classList.add("is-invalid");

      // Show error message
      if (!message) return;

      this.showMessageModal(message, "error", 1000);
    },

    clearValidationError(element) {
      if (!element) return;

      // Remove error styling from input
      element.classList.remove("is-invalid");
    },

    clearAllValidationErrors() {
      // Remove all error styling
      document.querySelectorAll('.is-invalid').forEach(element => {
        element.classList.remove('is-invalid');
      });

      // Hide all error messages
      document.querySelectorAll('.invalid-feedback').forEach(element => {
        element.style.display = 'none';
      });

      this.hasErrors = false;
    },

    validateFormBeforeAction() {
      this.validateAllInputs();

      if (this.hasErrors) {
        this.notShowMessage = true;
        const message = this.translated('fixValidationErrors');
        this.showNoticeModal(message);
        this.notShowMessage = false;
        return false;
      } else {
        this.clearAllValidationErrors();
      }

      return true;
    },

    validateAllInputs() {
      this.hasErrors = false;
      this.highlightInvalidFields();
      return !this.hasErrors;
    },

    highlightInvalidFields() {
      // Validate prefix inputs (maxlength="10", allow empty, max 5 chars for prefix)
      document.querySelectorAll('input[maxlength="10"]').forEach(input => {
        if (input.value !== undefined) {
          const validation = this.validateStringInput(input.value, true, 5);
          if (!validation.isValid) {
            this.hasErrors = true;
            this.showValidationError(input, validation.message);
          }
        }
      });

      // Validate name inputs (maxlength="50", no empty, max 50 chars)
      document.querySelectorAll('input[maxlength="50"]').forEach(input => {
        if (input.value) {
          const validation = this.validateStringInput(input.value, false, 50);
          if (!validation.isValid) {
            this.hasErrors = true;
            this.showValidationError(input, validation.message);
          }
        }
      });

      // Validate number inputs (min="1", no zero, no negative)
      document.querySelectorAll('input[min="1"]').forEach(input => {
        if (input.value) {
          const validation = this.validateNumberInput(input.value, false, false);
          if (!validation.isValid) {
            this.hasErrors = true;
            this.showValidationError(input, validation.message);
          }
        }
      });
    },
  }
};