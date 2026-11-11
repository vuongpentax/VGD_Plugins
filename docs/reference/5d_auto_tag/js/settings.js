new Vue({
  el: '#app',

  data: {
    languageData: {},
    noticeType: "info",
    noticeMessage: "",
    modalTitle: "",
    editTitle: "",
    editAction: null,
    modalMessage: "",
    modalAction0: null,
    modalAction1: null,
    modalAction2: null,

    settingsFolderPath: '',
    currentSetting: 'folders',
    foldersSetting: [],
    namesSetting: [],
    tabDescription: 'foldersTagDescription',
    settingsFileName: '',
    foldersFileName: '',
    namesFileName: '',
    fileName: '',
    selectedSheet: '',
    sheetNames: [],
    workbook: null,
    foldersSaved: true,
    namesSaved: true,
    isSaved: true,
    isReset: false,
    sortables: []
  },

  mounted() {
    sketchup.ready();

    // LOAD LAST SAVED FROM LOCAL STORAGE
    // Language
    const languageSaved = localStorage.getItem(languageKey) || 'en-US';
    if (languageSaved) {
      this.language = languageSaved;
    }

    this.loadLanguage().then(() => {
      this.toggleSettings('folders');
    });

    // Theme
    const savedTheme = localStorage.getItem(themeKey) || 'light';
    if (savedTheme) {
      applyTheme(savedTheme);
    }

    // Handle tool tip by Bootstrap
    handleTooltip(this);
  },

  beforeDestroy() {
    this.destroySettingsSorting();
  },

  methods: {
    loadLanguage() {
      // Fetch file JSON
      return axios
        .get(`../languages/resources/${this.language}.json`)
        .then((response) => {
          this.languageData = response.data;
        });
    },

    initSettingsSorting(tab) {
      const itemsList = document.getElementById(`${tab}Setting`);
      if (!itemsList) {
        console.warn(`toggleSettings: ${tab}Setting not found.`);
        return;
      }

      const sortableItems = new Sortable(itemsList, {
        animation: 150,
        onEnd: this.handleSortItems,
      });
      this.sortables.push(sortableItems);
    },

    destroySettingsSorting() {
      this.sortables.forEach(sortable => {
        if (sortable && typeof sortable.destroy === 'function') {
          try {
            sortable.destroy();
          } catch (error) {
            console.warn('Error destroying sortable:', error);
          }
        }
      });
      this.sortables = [];
    },

    // Receive data from SketchUp
    updateSettings(type, data) {
      const settings = data.map(obj => {
        const key = Object.keys(obj)[0];
        return {
          id: Date.now() + Math.random(),
          target: key,
          source: obj[key].join(', ')
        };
      });

      if (type === 'folders') {
        this.foldersSetting = settings;
      } else if (type === 'names') {
        this.namesSetting = settings;
      } else {
        return;
      }
    },

    toggleSettings(tab) {
      this.currentSetting = tab;
      this.tabDescription = this.translated(`${tab}TagDescription`);

      this.checkSaved();

      this.$nextTick(() => {
        this.initSettingsSorting(tab);
      });
    },

    handleSortItems(evt) {
      if (this.currentSetting === 'folders') {
        const movedItem = this.foldersSetting.splice(evt.oldIndex, 1)[0];
        this.foldersSetting.splice(evt.newIndex, 0, movedItem);
        this.foldersSaved = false;
        this.foldersFileName = '...';
      } else if (this.currentSetting === 'names') {
        const movedItem = this.namesSetting.splice(evt.oldIndex, 1)[0];
        this.namesSetting.splice(evt.newIndex, 0, movedItem);
        this.namesSaved = false;
        this.namesFileName = '...';
      }

      this.checkSaved();
    },

    updateSaveStatus(itemId, field) {
      // console.log(`updateSaveStatus called for itemId: ${itemId}, field: ${field}`);
      this.destroySettingsSorting();

      if (this.currentSetting === 'folders') {
        const item = this.foldersSetting.find(item => item.id === itemId);
        if (item) {
          item[field] !== item[field].trim();
          this.isSaved = false;
          this.foldersFileName = '...';
        }
      } else if (this.currentSetting === 'names') {
        const item = this.namesSetting.find(item => item.id === itemId);
        if (item) {
          item[field] !== item[field].trim();
          this.isSaved = false;
          this.namesFileName = '...';
        }

      } else {
        console.error("Invalid settings type selected.");
        return;
      }
    },

    addSetting() {
      const newItem = { 
        id: Date.now() + Math.random(), // id unique
        source: '',
        target: ''
      };

      if (this.currentSetting === 'folders') {
        this.foldersSetting.push(newItem);
        this.foldersSaved = false;
        this.foldersFileName = '...';
      } else if (this.currentSetting === 'names') {
        this.namesSetting.push(newItem);
        this.namesSaved = false;
        this.namesFileName = '...';
      }

      this.checkSaved();
    },

    removeSetting(itemId) {
      if (this.currentSetting === 'folders') {
        this.foldersSetting = this.foldersSetting.filter(item => item.id !== itemId);
        this.foldersSaved = false;
        this.foldersFileName = '...';
      } else if (this.currentSetting === 'names') {
        this.namesSetting = this.namesSetting.filter(item => item.id !== itemId);
        this.namesSaved = false;
        this.namesFileName = '...';
      } else {
        console.error("Invalid settings type selected.");
        return;
      }

      this.checkSaved();
    },

    checkSaved() {
      this.isSaved = this.currentSetting === 'folders' ? this.foldersSaved : this.namesSaved;
      this.isReset = this.currentSetting === 'folders' ? !this.foldersFileName : !this.namesFileName;

      const fileName = this.currentSetting === 'folders' ? this.foldersFileName : this.namesFileName;
      this.settingsFileName = fileName || this.translated('defaultSettings');
    },

    // LOAD FILE
    loadExcelFile(event) {
      const file = event.target.files[0];

      if (!file) return;

      const reader = new FileReader();
      reader.onload = (e) => {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });

        this.workbook = workbook;
        this.sheetNames = workbook.SheetNames;
        this.selectedSheet = this.sheetNames[0];

        // Allow selecting same file again
        event.target.value = '';

        $('#selectSheetModal').modal('show');
      };

      reader.readAsArrayBuffer(file);

      this.fileName = file.name;
    },

    loadSelectedSheet() {
      if (!this.workbook || !this.selectedSheet) return;

      // Get the selected sheet
      const sheet = this.workbook.Sheets[this.selectedSheet];

      // Convert sheet to JSON
      const rawData = XLSX.utils.sheet_to_json(sheet, { header: 1 });

      // Ignore first row as header
      const rows = rawData.slice(1);

      // Process raw data into desired structure
      this.loadSettings(rows);
    },

    loadSettings(rows) {
      const settings = rows
        .filter(row => row.length >= 2 && row[0] && row[1])
        .map(row => ({
          id: Date.now() + Math.random(),
          source: String(row[0]).trim(),
          target: String(row[1]).trim()
        }));

      if (this.currentSetting === 'folders') {
        this.foldersFileName = this.fileName;
        this.foldersSetting = settings;
        this.foldersSaved = false;
      } else if (this.currentSetting === 'names') {
        this.namesFileName =  this.fileName;;
        this.namesSetting = settings;
        this.namesSaved = false;
      }

      const message = this.translated(`${this.currentSetting}LoadMessage`);
      this.showMessageModal(message, 'info');
      this.checkSaved();
    },

    saveSettings() {
      let settings = [];
      if (this.currentSetting === 'folders') {
        settings = this.foldersSetting;
        this.foldersSaved = true;
      } else if (this.currentSetting === 'names') {
        settings = this.namesSetting;
        this.namesSaved = true;
      }

      const newSettings = this.filteredSettings(settings)

      sketchup.saveSettings(this.currentSetting, newSettings);

      const message = this.translated(`${this.currentSetting}SaveMessage`);
      this.showMessageModal(message, 'success');
      this.checkSaved();

      this.settingsFileName = this.translated('defaultSettings');
    },

    exportSettings(type) {
      if (type === 'json') {
        this.exportSettingsJson();
      } else if (type === 'excel') {
        this.exportSettingsExcel();
      }
    },

    exportSettingsJson() {
      const settings = {
        folders: this.filteredSettings(this.foldersSetting),
        names: this.filteredSettings(this.namesSetting)
      }
      sketchup.exportSettings(settings);
    },

    exportSettingsExcel() {
      const wb = XLSX.utils.book_new();

      // Folders Settings Sheet
      const foldersData = [
        ['Tags Includes', 'Folder'], // Header
        ...this.foldersSetting
          .filter(item => item.source.trim() && item.target.trim())
          .map(item => [item.source.trim(), item.target.trim()])
      ];
      const wsFolders = XLSX.utils.aoa_to_sheet(foldersData);
      XLSX.utils.book_append_sheet(wb, wsFolders, 'Folders');

      // Names Settings Sheet
      const namesData = [
        ['Objects Includes', 'Tag'], // Header
        ...this.namesSetting
          .filter(item => item.source.trim() && item.target.trim())
          .map(item => [item.source.trim(), item.target.trim()])
      ];
      const wsNames = XLSX.utils.aoa_to_sheet(namesData);
      XLSX.utils.book_append_sheet(wb, wsNames, 'Names');

      // Export to Excel file
      const wbout = XLSX.write(wb, { bookType: 'xlsx', type: 'array' });
      const blob = new Blob([wbout], { type: 'application/octet-stream' });

      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `Custom Settings.xlsx`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    },

    // resetSettings() {
    //   // Reset local storage
    //   if (this.currentSetting === 'folders') {
    //     this.foldersSetting = []
    //     this.foldersFileName = '';
    //     this.foldersSaved = true;
    //   } else if (this.currentSetting === 'names') {
    //     this.namesSetting = [];
    //     this.namesFileName = '';
    //     this.namesSaved = true;
    //   }

    //   this.settingsFileName = this.translated('defaultSettings');

    //   sketchup.resetSettings(this.currentSetting);

    //   const message = this.translated(`${this.currentSetting}ResetMessage`);
    //   this.showMessageModal(message, 'reset');
    //   this.checkSaved();
    // },

    resetAllSettings() {
      sketchup.resetAllSettings();
      this.isReset = true;
      this.isSaved = true;
      this.settingsFileName = this.translated('defaultSettings');
      this.foldersFileName = '';
      this.namesFileName = '';
      this.foldersSaved = true;
      this.namesSaved = true;
    },

    filteredSettings(settings) {
      const newSettings = settings
        .filter(item => item.target.trim() && item.source.trim())
        .map(item => {
          return {
            [item.target.trim()]: item.source.split(',').map(t => t.trim())
          };
        });

      return newSettings;
    },

    locateSettingsFolder() {
      sketchup.locateSettingsFolder();
    },

    updateSettingsFolderPath(path) {
      this.settingsFolderPath = path;
    },

    translated(key) {
      return this.languageData[key] || key;
    },

    // This is also for receive message from SketchUp
    showMessageModal(message, type, delay = 1500) {
      if (!message) return;

      this.noticeMessage = message;
      this.noticeType = type || 'info';
      this.showToast(delay);
    },

    // This is also for receive notice from SketchUp
    showNoticeModal(message, action1 = null, action2 = null) {
      // Hide #noticeMessage if it's open
      this.hideModal("#noticeMessage");

      if (!message) return;

      setTimeout(() => {
        this.modalTitle = 'notification';
        this.modalMessage = message;

        if (action1) {
          if (action1 === 'no') {
            this.modalAction1 = {
              text: this.translated('no'),
              action: () => this.hideModal('#actionModal')
            };
          } else {
            this.modalAction1 = {
              text: this.translated(action1),
              action: () => {
                // Default action for other types
              }
            };
          }
        } else {
          this.modalAction1 = null; // Clear modalAction1 if no action1 provided
        }

        if (action2) {
          if (action2 === 'closeDialog') {
            this.modalAction2 = {
              text: this.translated('yes'),
              action: () => this.closeDialog()
            };
          } else if (typeof action2 === 'function') {
            this.modalAction2 = {
              text: 'OK',
              action: () => {
                this.hideModal('#actionModal');
                action2();
              }
            };
          } else {
            this.modalAction2 = {
              text: this.translated(action2),
              action: () => {
                this.hideModal('#actionModal');
              }
            };
          }
        } else {
          this.modalAction2 = {
            text: 'OK',
            action: () => this.hideModal('#actionModal')
          };
        }

        this.showModal("#actionModal", 'wait');
      }, 100);
    },

    showAbcModal() {
      this.modalTitle = 'confirm';
      this.modalMessage = 'requireSafeCloseDialog';
      this.modalAction0 = { text: 'saveAndClose', action: () => {this.saveAll(); this.closeDialog(); } };
      this.modalAction1 = { text: 'cancel', action: () => this.hideModal('#actionModal') };
      this.modalAction2 = { text: 'OK', action: () => this.closeDialog() };

      this.showModal('#actionModal', 'wait');
    },

    showModal(id, delay = 1500) {
      showModal(id, delay);
    },

    hideModal(id) {
      hideModal(id);
    },

    showToast(delay = 1500) {
      showToast(delay);
    }
  },
});

// Global functions to be called from SketchUp

function confirmCloseDialog() {
  document.getElementById('app').__vue__.confirmCloseDialog();
}

function showNoticeModal(notice, action1 = null, action2 = null) {
  document.getElementById('app').__vue__.showNoticeModal(notice, action1, action2);
}

function showMessageModal(message, type, delay = null) {
  document.getElementById('app').__vue__.showMessageModal(message, type, delay);
}

function updateSettings(type, data) {
  document.getElementById('app').__vue__.updateSettings(type, data);
}

function updateSettingsFolderPath(path) {
  document.getElementById('app').__vue__.updateSettingsFolderPath(path);
};