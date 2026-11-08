new Vue({
  el: '#app',

  data: {
    // Global links from common.js
    HOMEPAGE: "",
    HOMEPAGE_EN: HOMEPAGE_EN,
    HOMEPAGE_VI: HOMEPAGE_VI,
    FACEBOOK: FACEBOOK,
    STORE: STORE,
    SAMPLES: SAMPLES,
    USER_MANUAL_EN: USER_MANUAL_EN,
    USER_MANUAL_VI: USER_MANUAL_VI,
    RELEASE_NOTES_EN: RELEASE_NOTES_EN,
    RELEASE_NOTES_VI: RELEASE_NOTES_VI,
    NOTICE_EN: NOTICE_EN,
    NOTICE_VI: NOTICE_VI,

    currentTheme: 'light',
    themeIcon: 'sun',
    language: 'en-US',
    languages: [
      { code: "en-US", name: "English" },
      { code: "es-ES", name: "Español" },
      { code: "de-DE", name: "Deutsch" },
      { code: "pt-BR", name: "Português" },
      { code: "th-TH", name: "ภาษาไทย" },
      { code: "vi-VN", name: "Tiếng Việt" },
      { code: "zh-CN", name: "简体中文" },
    ],
    languageData: {},
    isNewVersion: false,
    noticeType: "info",
    noticeMessage: "",
    modalTitle: "",
    editTitle: "",
    editAction: null,
    modalMessage: "",
    modalAction0: null,
    modalAction1: null,
    modalAction2: null,
    currentModal: null,

    isReset: false,
    compactMode: false,
    dashesSource: 'black_dashes',

    defaultFolderExclusionList: [],
    defaultLayerExclusionList: [],
    folderExclusionList: [],
    layerExclusionList: [],
    sortables: [],
    inputSearchQuery: '',
    folders: [],
    hiddenFolders: [],
    expandFolders: [],
    currentFolder: null,
    selectedFolder: null,
    isolateFolder: null,
    editingFolder: null,
    editingFolderName: '',
    layers: {},
    dashes: [],
    pinLayers: {},
    hiddenLayers: [],
    activeLayer: null,
    currentLayer: null,
    recentLayer: null,
    isolateLayer: null,
    editingLayer: null,
    editingLayerName: '',
    colorByTag: false,
    isSampleTool: false,
    showDashesList: false,
    showContextMenu: false,
    highlightedLayerId: null,
    sortColumn: 'name',
    sortOrder: 1,

    selectedFolders: [],
    lastSelectedFolder: null,
    selectedLayers: [],
    lastSelectedLayer: null,
    draggingItem: null,
    draggingType: null,
    dragOverFolderId: null,
    dragOverLayerId: null,

    selectedObjects: false,
    deleteLayerTargets: [],
    deleteLayerOptions: {
      assignLayer: 'Untagged',
      deleteEntities: false
    },

    isExport: false,
    exportSearchQuery: '',
    checkAllExportLayersValue: false,
    exportLayersLength: 0,
    checkedLayersLength: 0,

    isExcel: false,
    isResetExcel: true,
    workbook: null,
    sheetNames: [],
    selectedSheet: '',
    excelRows: [],
    excelCheckboxStates: {},
    excelRowStates: {},
    excelFileName: '',
    excelSaved: true,

    initialColor: '#ff0000',
    initialTrans: 'rgb(255, 255, 255, 0.5)',
    hexPicker: null,
    rgbPicker: null,
    hslPicker: null,
    transPicker: null,
    alphaValue: 1,
    transValue: 100,
    redValue: 0,
    greenValue: 0,
    blueValue: 0,
    hueValue: 0,
    saturationValue: 0,
    lightnessValue: 0,
    deltas: [],
    hexString: '',
    rgbString: '',
    rgbaString: '',
    hslString: '',
    hslValue: 'hsl(0, 0, 0)',
    overlayStyles: [],
    newColor: '#ff0000',

    userOptions: [
      { 
        key: "option1",
        label: "Option 1",
        showLabel: true,
        type: "text",
        value: "",
        disabled: false,
      },
    ],
    userOptionsType: "",
    scenes: [],
    hasOptionsError: false
  },

  mounted() {
    sketchup.ready();

    // Language
    this.language = localStorage.getItem(languageKey) || "en-US";
    loadLanguage(this);
    sketchup.changeLanguage(this.language);

    // Theme
    const savedTheme = localStorage.getItem(themeKey) || 'light';
    this.themeIcon = savedTheme === 'light' ? 'moon' : 'sun';
    this.currentTheme = savedTheme;
    applyTheme(savedTheme);
    this.dashesSource = savedTheme === 'light' ? 'black_dashes' : 'white_dashes';

    // Use Excel
    const useExcelSaved = JSON.parse(localStorage.getItem(useExcelKey)) || false;
    this.isExcel = useExcelSaved;
    if (this.isExcel) {
      this.loadExcelContent();
    }

    // Compact mode
    const compactModeSaved = localStorage.getItem(compactModeKey);
    this.compactMode = compactModeSaved === 'true';

    // Recent layer
    const recentLayerSaved = JSON.parse(localStorage.getItem(recentLayerKey)) || null;
    this.recentLayer = recentLayerSaved;

    // Pinned layers
    const pinLayersSaved = JSON.parse(localStorage.getItem(pinLayersKey)) || {};
    this.pinLayers = pinLayersSaved;

    // Sort settings
    const sortSettings = JSON.parse(localStorage.getItem(sortLayersKey)) || {};
    this.sortColumn = sortSettings.column || 'name';
    this.sortOrder = sortSettings.order || 1;

    // Handle tool tip by Bootstrap
    handleTooltip(this);

    // Focus to search input
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
      searchInput.focus();
    }

    // Close the dashes menu when clicking outside
    document.addEventListener('click', (event) => {
      const dashesList = document.getElementById('dashesList');
      const element = event.target;

      if (!element.id.includes(this.selectedFolder) && (
          element.id !== 'searchInput' &&
          element.tagName.toLowerCase() !== 'button') ||
          element.class == 'modus-content') {
        this.selectedFolder = null;
        this.selectedFolders = [];
      }

      // Close dashes list if clicked outside
      if (this.currentLayer &&
          dashesList &&
          !dashesList.contains(event.target) && 
          !event.target.closest('[id^="dash-"]')) {
        this.showDashesList = false;
      }

      // Close context menu if clicked outside
      const contextMenu = document.getElementById('contextMenu');
      if ((this.currentLayer || this.currentFolder) &&
          contextMenu &&
          !contextMenu.contains(event.target) &&
          (event.target.textContent !== this.currentLayer || event.target.textContent !== this.currentFolder)) {
        this.showContextMenu = false;
        this.currentLayer = null;
      }
    });

    this.handleEsc = (event) => {
      if (event.key === 'Escape') {
        sketchup.minimizeDialog();
      }
    };
    window.addEventListener('keydown', this.handleEsc);
  },

  beforeDestroy() {
    window.removeEventListener('keydown', this.handleEsc);
  },

  computed: {
    foldersTree() {
      const map = {};
      const roots = [];

      // Build lookup
      this.folders.forEach(folder => {
        map[folder.id] = { ...folder, childrenFolders: [] };
      });

      // Build tree
      this.folders.forEach(folder => {
        if (folder.parent) {
          if (map[folder.parent]) {
            map[folder.parent].childrenFolders.push(map[folder.id]);
          }
        } else {
          roots.push(map[folder.id]);
        }
      });

      // Sort childrenFolders in each folder
      Object.values(map).forEach(folder => {
        folder.childrenFolders = this.sortFolders(folder.childrenFolders);
      });

      // Sort roots (parent folders)
      return this.sortFolders(roots);
    },

    filteredPinLayers() {
      const query = (this.inputSearchQuery || '').toLowerCase();

      // Convert pinLayers object → array of { id, name }
      const pins = Object.entries(this.pinLayers).map(([id, name]) => ({ id, name }));

      if (!query) {
        return pins.sort((a, b) => 
          a.name.toLowerCase() > b.name.toLowerCase() ? 1 : -1
        );
      }

      const terms = query.split(',').map(term => term.trim()).filter(term => term !== '');

      return pins
        .filter(pin => 
          terms.some(term => pin.name.toLowerCase().includes(term))
        )
        .sort((a, b) => 
          a.name.toLowerCase() > b.name.toLowerCase() ? 1 : -1
        );
    },

    filteredFoldersTree() {
      const query = (this.inputSearchQuery || '').toLowerCase().trim();
      if (!query) {
        // No search → show full tree
        return this.foldersTree;
      }

      const terms = query.split(',').map(term => term.trim()).filter(term => term !== '');

      const filterFolder = (folder) => {
        const folderMatch = terms.some(term => folder.name.toLowerCase().includes(term));

        // Filter children recursively
        const matchedChildren = folder.childrenFolders
          .map(child => filterFolder(child))
          .filter(child => child !== null);

        // Filter layers in folder
        const matchedLayers = this.layersInFolder(folder.id)
          .filter(layer =>
            terms.some(term => layer.name.toLowerCase().includes(term))
          );

        // If folder itself matches OR has matching children OR has matching layers → keep this folder
        if (folderMatch || matchedChildren.length > 0 || matchedLayers.length > 0) {
          return {
            ...folder,
            childrenFolders: matchedChildren
          };
        }

        // Otherwise, exclude this folder
        return null;
      };

      return this.foldersTree
        .map(folder => filterFolder(folder))
        .filter(folder => folder !== null);
    },

    filteredLayers() {
      const query = this.inputSearchQuery.toLowerCase();

      const result = query
        ? Object.values(this.layers).filter(layer =>
            query.split(',').map(term => term.trim()).filter(term => term !== '').some(term =>
              layer.name.toLowerCase().includes(term)
            )
          )
        : Object.values(this.layers);

      return this.sortLayers(result);
    },

    layersWithoutFolder() {
      return this.filteredLayers.filter(layer => !layer.folder);
    },

    filteredExcelRows() {
      const query = this.inputSearchQuery.toLowerCase().trim().normalize('NFKC');
      if (!query) return this.excelRows;

      const terms = query.split(',').map(term => term.trim().normalize('NFKC')).filter(term => term !== '');

      return this.excelRows.filter(row =>
        Object.entries(row)
          .filter(([key, _]) => key !== 'Color' && key !== 'Dashes')
          .some(([_, value]) =>
            terms.some(term =>
              String(value).toLowerCase().normalize('NFKC').includes(term)
            )
          )
      );
    },

    // Get first column key from Excel rows
    // Priority: 'Name' column first, then first column if 'Name' doesn't exist
    firstColumnKey() {
      if (this.excelRows.length > 0) {
        const keys = Object.keys(this.excelRows[0]);
        // Check if 'Name' column exists
        if (keys.includes('Name')) {
          return 'Name';
        }
        // Otherwise use first column
        return keys.length > 0 ? keys[0] : 'Name';
      }
      return 'Name'; // Default fallback
    },

    filteredExportLayers() {
      const query = this.exportSearchQuery.toLowerCase();

      const result = Object.values(this.layers)
      .filter(layer => layer.name !== 'Untagged') // Exclude 'Untagged'
      .filter(layer => {
        if (!query) return true;
        return query.split(',')
        .map(term => term.trim())
        .filter(term => term !== '')
        .some(term => layer.name.toLowerCase().includes(term));
      });

      // Ensure each layer has a checked property
      result.forEach(layer => {
      if (!layer.hasOwnProperty('checked')) {
        this.$set(layer, 'checked', false);
      }
      });

      return this.sortLayers(result);
    },

    checkedCount() {
      return this.getCheckedExportLayers().length;
    }
  },

  watch: {
    inputSearchQuery(newQuery) {
      if (!newQuery.trim()) return;

      // this.expandFolders = []; // Reset expandFolders
      const query = newQuery.toLowerCase();
      const terms = query.split(',').map(term => term.trim()).filter(term => term !== '');

      const expandMatchingFolders = (folder) => {
        let shouldExpand = false;

        // Check if this folder matches
        const folderMatch = terms.some(term => folder.name.toLowerCase().includes(term));

        // Check if any child folders match
        const childrenMatch = folder.childrenFolders.some(child => expandMatchingFolders(child));

        // Check if any layer in this folder matches
        const layersMatch = this.layersInFolder(folder.id).some(layer =>
          terms.some(term => layer.name.toLowerCase().includes(term))
        );

        if (folderMatch || childrenMatch || layersMatch) {
          shouldExpand = true;
          if (!this.expandFolders.includes(folder.id)) {
            this.expandFolders.push(folder.id);
          }
        }

        return shouldExpand;
      };

      this.foldersTree.forEach(folder => {
        expandMatchingFolders(folder);
      });
    },

    'newColor': function (newColor) {
      this.redValue = newColor[0];
      this.greenValue = newColor[1];
      this.blueValue = newColor[2];
      this.alphaValue = newColor[3];
      this.transValue = Math.round(this.alphaValue * 100);

      this.rgbString = `rgb(${this.redValue}, ${this.greenValue}, ${this.blueValue})`
      this.rgbaString = `rgba(${this.redValue}, ${this.greenValue}, ${this.blueValue}, ${this.alphaValue})`
      this.initialTrans = this.rgbaString;
      this.dynamicColor = this.rgbaString;

      const hexValues = this.rgbToHex(this.redValue, this.greenValue, this.blueValue);
      this.initialColor = hexValues;
      this.hexString = hexValues;

      const hslValues = this.rgbaToHsl(this.rgbaString);
      this.hueValue = hslValues.hue;
      this.saturationValue = hslValues.saturation;
      this.lightnessValue = hslValues.lightness;
      this.hslString = hslValues.hslString;

      // Update for Color Picker
      if (this.hexPicker && this.hexPicker.color.hexString !== newColor) {
        this.hexPicker.color.set(this.initialColor);
        this.texturedColorized = true;
      }
      if (this.rgbPicker && this.rgbPicker.color.hexString !== newColor) {    
        this.rgbPicker.color.set(this.initialColor);
        this.texturedColorized = true;
      }
      if (this.hslPicker && this.hslPicker.color.hexString !== newColor) {
        this.hslPicker.color.set(this.initialColor);
        this.texturedColorized = true;
      }
      if (this.pickerTrans && this.pickerTrans.color.rgbaString !== newColor) {
        this.pickerTrans.color.set(this.initialTrans);
      }
    }
  },

  methods: {
    changeLanguage(lang) {
      this.language = lang;
      localStorage.setItem(languageKey, this.language);
      loadLanguage(this);
      sketchup.changeLanguage(this.language);

      if (this.isExcel) {
        this.loadExcelContent();
      }

      handleTooltip(this);
    },

    translated(key) {
      return this.languageData[key] || key;
    },

    switchTheme() {
      const newTheme = this.currentTheme === 'light' ? 'dark' : 'light';

      applyTheme(newTheme);
      this.currentTheme = newTheme;
      this.themeIcon = this.currentTheme === 'light' ? 'moon' : 'sun';

      this.dashesSource = newTheme === 'light' ? 'black_dashes' : 'white_dashes';

      localStorage.setItem(themeKey, newTheme);
      sketchup.changeTheme(newTheme);
    },

    updateUrls(urls) {
      this.HOMEPAGE_EN      = urls.homepageEn || HOMEPAGE_EN;
      this.HOMEPAGE_VI      = urls.homepageVi || HOMEPAGE_VI;
      this.STORE            = urls.store || STORE;
      this.SAMPLES          = urls.samples || SAMPLES;
      this.USER_MANUAL_EN   = urls.userManualEn || USER_MANUAL_EN;
      this.USER_MANUAL_VI   = urls.userManualVi || USER_MANUAL_VI;
      this.RELEASE_NOTES_EN = urls.releaseNotesEn || RELEASE_NOTES_EN;
      this.RELEASE_NOTES_VI = urls.releaseNotesVi || RELEASE_NOTES_VI;
      this.NOTICE_EN        = urls.noticeEn || NOTICE_EN;
      this.NOTICE_VI        = urls.noticeVi || NOTICE_VI;
    },

    noticeNewVersion(value) {
      this.isNewVersion = value;
    },

    openSupporter(type) {
      if (!type) return;

      let url = "";
      let video = false;

      if (type === "userManual") {
        url = this.language === "vi-VN" ? this.USER_MANUAL_VI : this.USER_MANUAL_EN;
      } else if (type === "releaseNotes") {
        url = this.language === "vi-VN" ? this.RELEASE_NOTES_VI : this.RELEASE_NOTES_EN;
      } else if (type === "styles") {
        url = this.language === "vi-VN" ? this.STYLES_LESSON_VI : this.STYLES_LESSON_EN;
      } else if (type === "tags") {
        url = this.language === "vi-VN" ? this.TAGS_LESSON_VI : this.TAGS_LESSON_EN;
      } else if (type === "samples") {
        url = this.SAMPLES;
      } else if (type === "store") {
        url = this.STORE;
      } else {
        url = this.HOMEPAGE;
      }
      sketchup.openSupporter(url, video);
    },

    checkUpdate() {
      sketchup.checkUpdate();
    },

    //

    // EXCEL HELPER
    getRowKey(row) {
      if (!row) return undefined;
      return row[this.firstColumnKey];
    },

    clearSearch() {
      this.inputSearchQuery = '';
      this.exportSearchQuery = '';
    },

    foldersInFolder(parentId) {
      const folders = this.folders.filter(folder => folder.parent === parentId || (!folder.parent && parentId === ''));
      return this.sortFolders(folders);
    },

    filteredLayersInFolder(folderId) {
      const query = (this.inputSearchQuery || '').toLowerCase();
      const terms = query.split(',').map(term => term.trim()).filter(term => term !== '');

      return this.layersInFolder(folderId).filter(layer => {
        if (!terms.length) return true;
        return terms.some(term => layer.name.toLowerCase().includes(term));
      });
    },

    layersInFolder(folderId) {
      const list = Object.values(this.layers).filter(layer => layer.folder === String(folderId));
      return this.sortLayers(list);
    },

    toggleSort(column) {
      // Toggle sort order if the same column is clicked
      if (this.sortColumn === column) {
        this.sortOrder *= -1; // Flip between ascending and descending
      } else {
        this.sortColumn = column; // Set new sort column
        this.sortOrder = 1; // Reset to ascending order
      }

      localStorage.setItem(sortLayersKey, JSON.stringify({
        column: this.sortColumn,
        order: this.sortOrder
      }));
    },

    sortFolders(folders) {
      // Only allow folder sort by 'name' or 'visible'
      if (this.sortColumn !== 'name' && this.sortColumn !== 'visible') {
        // Fallback to sort by name
        return folders.sort((a, b) => (a.name.toLowerCase() > b.name.toLowerCase() ? 1 : -1));
      }

      switch(this.sortColumn) {
        case 'name':
          return folders.sort((a, b) => (a.name.toLowerCase() > b.name.toLowerCase() ? 1 : -1) * this.sortOrder);
        case 'visible':
          return folders.sort((a, b) => (a.visible === b.visible ? 0 : a.visible ? -1 : 1) * this.sortOrder);
      }
    },

    sortLayers(layers) {
      return layers.sort((a, b) => {
        // Always place "Untagged" layer first regardless of sort order
        if (a.name === "Untagged") return -1;
        if (b.name === "Untagged") return 1;

        // Continue with normal sorting for other layers
        switch(this.sortColumn) {
          case 'name':
            return (a.name.toLowerCase() > b.name.toLowerCase() ? 1 : -1) * this.sortOrder;
          case 'color':
            return (a.color > b.color ? 1 : -1) * this.sortOrder;
          case 'visible':
            return (a.visible === b.visible ? 0 : a.visible ? -1 : 1) * this.sortOrder;
          case 'dash':
            return (a.dash > b.dash ? 1 : -1) * this.sortOrder;
          case 'pin':
            const aPinned = Object.values(this.pinLayers).includes(a.name);
            const bPinned = Object.values(this.pinLayers).includes(b.name);
            return (aPinned === bPinned ? 0 : aPinned ? -1 : 1) * this.sortOrder;
          default:
            return (a.name.toLowerCase() > b.name.toLowerCase() ? 1 : -1) * this.sortOrder;
        }
      });
    },

    updateData(data) {
      this.folders = data.folders;
      this.layers = data.layers;
      this.dashes = data.dashes;
      this.activeLayer = data.activeLayer;
      this.exportLayersLength = this.layers.length - 1; // Exclude 'Untagged' layer

      this.hiddenFolders = this.folders
        .filter(folder => folder.visible === false)
        .map(folder => folder.id);

      this.hiddenLayers = Object.values(this.layers)
        .filter(layer => layer.visible === false)
        .map(layer => layer.name);
    },

    selectFolder(folder, event) {
      if (event.shiftKey && this.lastSelectedFolder) {
        // Shift + click → select range
        const foldersArray = this.sortFolders(this.folders);
        const lastIndex = foldersArray.findIndex(f => f.id === this.lastSelectedFolder);
        const currentIndex = foldersArray.findIndex(f => f.id === folder.id);

        if (lastIndex !== -1 && currentIndex !== -1) {
          const [from, to] = [lastIndex, currentIndex].sort((a, b) => a - b);
          const range = foldersArray.slice(from, to + 1);

          const existingIds = new Set(this.selectedFolders.map(f => f.id));
          const newSelection = range.filter(f => !existingIds.has(f.id));

          this.selectedFolders = [...this.selectedFolders, ...newSelection];
        }
      } else if (event.ctrlKey || event.metaKey) {
        // Ctrl + click → toggle
        const index = this.selectedFolders.findIndex(f => f.id === folder.id);
        if (index === -1) {
          this.selectedFolders.push(folder);
        } else {
          this.selectedFolders.splice(index, 1);
        }
      } else {
        // Normal click → select 1
        this.selectedFolders = []; // Clear selected layers
        this.selectedFolder = folder.id;
      }

      this.lastSelectedFolder = folder.id;
    },

    refreshFolder(folder) {
      if (folder && folder.id) {
        // Check existing folders (same id)
        const existingFolder = this.folders.find(f => f.id === folder.id);

        if (existingFolder) {
          // Update folder in place
          existingFolder.name = folder.name;
          existingFolder.visible = folder.visible;
          existingFolder.parent = folder.parent || null;
          existingFolder.children = folder.children || [];
        } else {
          // Add new folder
          this.folders.push({
            id: folder.id,
            name: folder.name,
            visible: folder.visible,
            parent: folder.parent || null,
            children: folder.children || [],
          });
        }

        // Update hiddenFolders
        this.hiddenFolders = this.folders
          .filter(f => f.visible === false)
          .map(f => f.id);

        this.scrollToElement(`[data-folder-id="${folder.id}"]`, 'modelLayers');
      } else {
        console.warn('Invalid folder data:', folder);
      }

    },

    refreshLayer(layer) {
      if (layer && layer.id) {
        // Check existing layer (same id)
        const existingLayer = this.layers.find(l => l.name === layer.name);

        if (existingLayer) {
          // Update layer in place
          existingLayer.name = layer.name;
          existingLayer.visible = layer.visible;
          existingLayer.parent = layer.parent || null;
          existingLayer.children = layer.children || [];
        } else {
          // Add new layer
          this.layers.push({
            id: layer.id,
            name: layer.name,
            visible: layer.visible,
            color: layer.color,
            dash: layer.dash,
            folder: layer.folder
          });
        }

        // If the layer is isolated, update the isolate state
        if (layer.isolate) {
          this.isolateLayer = layer.name;
        }

        // Update hiddenLayers based on visibility
        if (!layer.visible) {
          if (!this.hiddenLayers.includes(layer.name)) {
            this.hiddenLayers.push(layer.name);
          }
        } else {
          const index = this.hiddenLayers.indexOf(layer.name);
          if (index > -1) {
            this.hiddenLayers.splice(index, 1);
          }
        }

        // Scroll to the newly created layer
        this.scrollToElement(`[data-layer-id="${layer.id}"]`, 'modelLayers');
      } else {
        console.warn('Invalid layer data:', layer);
      }
    },

    updateSelection(layer, selected_objects) {
      this.selectedObjects = selected_objects;

      if (!layer) {
        return;
      } else {
        this.recentLayer = layer;
        localStorage.setItem(recentLayerKey, JSON.stringify(layer));
      }
    },

    updateScenesList(scenesList) {
      // console.log(scenesList);
      // Convert scenesList to array of objects with value and label
      this.scenesList = scenesList.map(scene => ({
        value: scene,
        label: scene,
      }));

      this.showUserOptions('scenesVisible');
    },

    toggleVisibleFolder(folderId) {
      const folder = this.folders.find(f => f.id === folderId);
      if (!folder) return;

      const targetVisible = !folder.visible;

      if (this.selectedFolders.some(f => f.id === folder.id)) {
        // Multi toggle selected folders
        this.selectedFolders.forEach(selectedFolder => {
          selectedFolder.visible = targetVisible;

          sketchup.visibleFolder(selectedFolder.id, targetVisible);

          const index = this.hiddenFolders.indexOf(selectedFolder.id);
          if (targetVisible) {
            if (index > -1) {
              this.hiddenFolders.splice(index, 1);
            }
          } else {
            if (index === -1) {
              this.hiddenFolders.push(selectedFolder.id);
            }
          }
        });
      } else {
        // Single toggle
        folder.visible = targetVisible;
        sketchup.visibleFolder(folder.id, targetVisible);

        const index = this.hiddenFolders.indexOf(folder.id);
        if (targetVisible) {
          if (index > -1) {
            this.hiddenFolders.splice(index, 1);
          }
        } else {
          if (index === -1) {
            this.hiddenFolders.push(folder.id);
          }
        }
      }
    },

    toggleVisibleLayer(layer) {
      if (this.activeLayer === layer.name) {
        // If the active layer is clicked, do nothing
        return;
      }

      // Determine the target visibility
      const targetVisible = this.hiddenLayers.includes(layer.name);

      if (this.selectedLayers.some(l => l.id === layer.id)) {
        // Multi toggle for selected layers
        this.selectedLayers.forEach(selectedLayer => {
          selectedLayer.visible = targetVisible;

          // Call SketchUp
          sketchup.visibleLayer(selectedLayer.name, targetVisible);

          // Update hiddenLayers
          const index = this.hiddenLayers.indexOf(selectedLayer.name);
          if (targetVisible) {
            // Show layer
            if (index > -1) {
              this.hiddenLayers.splice(index, 1);
            }
          } else {
            // Hide layer
            if (index === -1) {
              this.hiddenLayers.push(selectedLayer.name);
            }
          }
        });
      } else {
        // Single toggle for clicked layer
        layer.visible = targetVisible;
        sketchup.visibleLayer(layer.name, targetVisible);

        const index = this.hiddenLayers.indexOf(layer.name);
        if (targetVisible) {
          if (index > -1) {
            this.hiddenLayers.splice(index, 1);
          }
        } else {
          if (index === -1) {
            this.hiddenLayers.push(layer.name);
          }
        }
      }
    },

    updateAllFoldersVisibility(visible) {
      const seenIds = new Set();

      this.folders.forEach(folder => {
        seenIds.add(folder.id);
        folder.visible = visible;
      });

      this.hiddenFolders = visible ? [] : Array.from(seenIds);
    },

    updateAllLayersVisibility(visible) {
      const seenNames = new Set();

      this.layers.forEach(layer => {
        seenNames.add(layer.name);
        if (layer.name === this.activeLayer) {
          layer.visible = true; // Always keep the active layer visible
        } else {
          layer.visible = visible;
        }
      });

      this.hiddenLayers = visible ? [] : Array.from(seenNames);
    },

    updateIsolatedFolderVisibility(folderId) {
      const seenIds = new Set();

      this.folders.forEach(folder => {
        seenIds.add(folder.id);
        folder.visible = (folder.id === folderId);
      });

      this.hiddenFolders = Array.from(seenIds).filter(id => id !== folderId);
    },

    updateIsolatedLayerVisibility(layerName) {
      const seenNames = new Set();

      this.layers.forEach(layer => {
        seenNames.add(layer.name);
        if (layer.name === this.activeLayer) {
          layer.visible = true; // Always keep the active layer visible
        } else {
          layer.visible = (layer.name === layerName);
        }
      });

      this.hiddenLayers = Array.from(seenNames).filter(name => name !== layerName && name !== this.activeLayer);
    },

    handleVisibleAllFolders(folderId, visible) {
      sketchup.visibleAllFolders(folderId, visible);
      this.updateAllFoldersVisibility(visible);
    },

    handleTagEntities(layerName, action) {
      sketchup.tagEntities(layerName, action);
    },

    handleVisibleAllLayers(visible) {
      sketchup.visibleAllLayers(visible);
      this.updateAllLayersVisibility(visible);
    },

    toggleIsolateFolder(folderId) {
      if (this.selectedFolders.length > 0) {
        // Bulk isolate selected folders
        if (this.isolateFolder && this.isolateFolder === 'bulk') {
          sketchup.visibleAllFolders(folderId, true);
          this.updateAllFoldersVisibility(true);
          this.isolateFolder = null;
        } else {
          const folderIds = this.selectedFolders.map(f => f.id);
          sketchup.isolateFolders(folderIds);

          this.folders.forEach(folder => {
            folder.visible = folderIds.includes(folder.id);
          });

          this.hiddenFolders = this.folders
            .filter(f => !f.visible)
            .map(f => f.id);

          this.isolateFolder = 'bulk';
        }
      } else {
        // Single isolate
        if (this.isolateFolder && this.isolateFolder === folderId) {
          sketchup.visibleAllFolders(folderId, true);
          this.updateAllFoldersVisibility(true);
          this.isolateFolder = null;
        } else {
          sketchup.isolateFolder(folderId);
          this.updateIsolatedFolderVisibility(folderId);
          this.isolateFolder = folderId;
        }
      }
    },

    toggleIsolateLayer(layerName) {
      if (this.selectedLayers.length > 1 && !this.selectedLayers.some(l => l.name === this.activeLayer)) {
        // Bulk isolate selectedLayers
        if (this.isolateLayer && this.isolateLayer === 'bulk') {
          sketchup.visibleAllLayers(true);
          this.updateAllLayersVisibility(true);
          this.isolateLayer = null;
        } else {
          const layerNames = this.selectedLayers.map(l => l.name).filter(name => name !== 'Untagged' && name !== this.activeLayer);
          if (layerNames.length === 0) return;

          sketchup.isolateLayers(layerNames);
          this.layers.forEach(layer => {
            layer.visible = layerNames.includes(layer.name);
          });
          this.hiddenLayers = Object.values(this.layers)
          .filter(l => !l.visible)
          .map(l => l.name);
          
          this.isolateLayer = 'bulk';
        }
      } else {
        if (this.isolateLayer && this.isolateLayer === layerName) {
          sketchup.visibleAllLayers(true);
          this.updateAllLayersVisibility(true);
          this.isolateLayer = null;
        } else {
          sketchup.isolateLayer(layerName);
          this.updateIsolatedLayerVisibility(layerName);
          this.isolateLayer = layerName;
        }
      }
    },

    handleDeleteFolder(folderId) {
      const folder = this.folders.find(f => f.id === folderId);
      if (!folder) return;

      if (this.selectedFolders.some(f => f.id === folder.id)) {
        this.selectedFolders.forEach(selectedFolder => {
          sketchup.deleteFolder(selectedFolder.id);
        });
      } else {
        sketchup.deleteFolder(folder.id);
      }
    },

    handleDeleteLayer(layerName) {
      const isMultiple = this.selectedLayers.length > 1;

      let targets = [];
      if (isMultiple) {
        targets = this.selectedLayers.map(l => l.name);
      } else {
        targets = [layerName];
      }

      const undeletable = targets.find(name => name === 'Untagged' || name === this.activeLayer);
      if (undeletable) {
        const message = this.translated('cannotDeleteActiveTag');
        this.showMessageModal(message, 'reset');
        return;
      }

      this.deleteLayerTargets = targets;
      this.deleteLayerOptions = { assignLayer: 'Untagged', deleteEntities: false };
      $('#confirmDeleteLayerModal').modal('show');
    },

    confirmDeleteLayer() {
      const targets = this.deleteLayerTargets;
      const options = this.deleteLayerOptions;

      targets.forEach(layerName => {
        const layerEntry = Object.entries(this.layers).find(([id, l]) => l.name === layerName);
        if (layerEntry) {
          const [layerId] = layerEntry;
          sketchup.deleteLayer(layerName, JSON.stringify(options));
          this.$delete(this.layers, layerId);
          this.hiddenLayers = this.hiddenLayers.filter(name => name !== layerName);
        } else {
          console.warn(`Layer "${layerName}" does not exist.`);
        }
      });

      this.selectedLayers = [];
      this.deleteLayerTargets = [];
      $('#confirmDeleteLayerModal').modal('hide');
    },

    createFolder(folderName) {
      if (!folderName || folderName.trim() === '') {
        folderName = "New Folder";
      }

      // Automatically expand the folder if a new folder is added
      if (this.selectedFolder) {
        this.expandFolders.push(this.selectedFolder);
      }

      // Clear search query after creating a folder
      this.inputSearchQuery = '';

      // Send request to SketchUp to create the folder
      sketchup.createFolder(folderName, this.selectedFolder);
    },

    startRenameFolder(folder) {
      // Hide the context menu if it's open
      this.hideContextMenu();

      this.editingFolder = folder.id;
      this.editingFolderName = folder.name;

      this.$nextTick(() => {
        const inputEl = document.getElementById(`input-${folder.id}`);
          if (inputEl) {
            inputEl.focus();
            inputEl.select();
        } else {
          console.warn('Ref not found or not input:', inputEl);
        }
      });
    },

    renameFolder(folder) {
      const trimmedName = this.editingFolderName.trim();

      // Check if name is not empty
      if (trimmedName !== '' && trimmedName !== folder.name) {
        sketchup.renameFolder(folder.id, trimmedName);
        folder.name = trimmedName;
        this.cancelRenameFolder();
      }

      this.cancelRenameFolder();
    },

    cancelRenameFolder() {
      this.editingFolder = null;
      this.editingFolderName = '';
    },

    handleToggleFolder(folder) {
      const index = this.expandFolders.indexOf(folder.id);

      if (index > -1) {
        // Folder is opened → close it
        this.expandFolders.splice(index, 1);
      } else {
        // Folder is closed → open it
        this.expandFolders.push(folder.id);
      }
    },

    createLayer(layerName) {
      // console.log('Creating layer with name:', layerName);
      if (!layerName || layerName.trim() === '') {
        layerName = "Tag";
      }

      const nameExists = Object.values(this.layers).some(
        existingItem => existingItem.name === layerName
      );

      if (!nameExists) {
        // Automatically expand the folder if a new layer is added
        if (this.selectedFolder) {
          this.expandFolders.push(this.selectedFolder);
        }

        this.currentLayer = layerName;
        sketchup.createLayer(layerName, this.selectedFolder);
      } else {
        const message = this.translated('uniqueTagMessage');
        this.showMessageModal(message, 'reset');
      }
    },

    selectLayer(layer, event) {
      this.timer = setTimeout(() => {

        if (event.shiftKey && this.lastSelectedLayerId) {
          // const layersArray = this.sortLayers(Object.values(this.layers));
          const layersArray = [
            ...this.layersWithoutFolder,
            ...this.getVisibleLayersInExpandedFolders()
          ];
          const lastIndex = layersArray.findIndex(l => l.id === this.lastSelectedLayerId);
          const currentIndex = layersArray.findIndex(l => l.id === layer.id);

          if (lastIndex !== -1 && currentIndex !== -1) {
            const [from, to] = [lastIndex, currentIndex].sort((a, b) => a - b);
            const range = layersArray.slice(from, to + 1);

            const existingIds = new Set(this.selectedLayers.map(l => l.id));
            const newSelection = range.filter(l => !existingIds.has(l.id));

            this.selectedLayers = [...this.selectedLayers, ...newSelection];
          }
        } else if (event.ctrlKey || event.metaKey) {
          const index = this.selectedLayers.findIndex(l => l.id === layer.id);
          if (index === -1) {
            this.selectedLayers.push(layer);
          } else {
            this.selectedLayers.splice(index, 1);
          }
        } else {
          this.selectedLayers = [layer];

          if (this.editingLayer && this.editingLayer === layer.id) { 
            return;
          } else if (this.editingLayer) {
            this.cancelRenameLayer();
          }

          if (this.isSampleTool) {
            this.currentLayer = layer.name;
            sketchup.selectSampleLayer(layer.name);
          } else {
            sketchup.selectLayer(layer.name);
          }
        }

        this.lastSelectedLayerId = layer.id;

      }, 100);
    },

    startRenameLayer(layer) {
      // Hide the context menu if it's open
      this.hideContextMenu();

      if (this.timer) {
        clearTimeout(this.timer);
        this.timer = null;
      };

      if (layer.name === 'Untagged') {
        return; // Do not allow renaming the "Untagged" layer
      }

      this.editingLayer = layer.id;
      this.editingLayerName = layer.name;

      this.$nextTick(() => {
        const inputEl = document.getElementById(`input-${layer.id}`);
          if (inputEl) {
            inputEl.focus();
            inputEl.select();
        } else {
          console.warn('Ref not found or not input:', inputEl);
        }
      });
    },

    renameLayer(layer) {
      const trimmedName = this.editingLayerName.trim();

      // Check if name is not empty and different from current name
      if (trimmedName !== '' && trimmedName !== layer.name) {
        // Check if the name already exists in other layers
        const nameExists = Object.values(this.layers).some(
          existingLayer => existingLayer.name === trimmedName && existingLayer.id !== layer.id
        );

        if (!nameExists) {
          sketchup.renameLayer(layer.name, trimmedName);
          layer.name = trimmedName;
        } else {
          const message = this.translated('uniqueTagMessage');
          this.showMessageModal(message, 'reset');
        }
      }

      this.cancelRenameLayer();
    },

    cancelRenameLayer() {
      this.editingLayer = null;
      this.editingLayerName = '';
    },

    toggleContextMenu(event, type, currentValue) {
      event.preventDefault();

      // Check user clicked on a folder or layer
      const element = event.target.closest('[id]');

      if (type === 'folder') {
        this.currentFolder = currentValue;
        this.currentLayer = null;
      } else {
        this.currentFolder = null;
        this.currentLayer = currentValue;
        if (this.selectedLayers.length <= 1) {
          this.selectedLayers = [];
          this.selectedLayers = [currentValue];
        }
      }

      this.showContextMenu = true;
      // Wait for Vue to render the menu before positioning it

      this.$nextTick(() => {
        // Get reference to the element that was clicked
        const menu = document.getElementById('contextMenu');

        if (!element || !menu) return;

        // Get position from the mouse click instead of the element
        const rect = element.getBoundingClientRect();
        const click = {
          top: event.clientX,
          left: event.clientX,
          right: event.clientY,
          bottom: event.clientY,
        };

        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;

        const distanceToTop = rect.top;
        const distanceToBottom = viewportHeight - rect.bottom;

        const menuTopDown = rect.bottom + 1;
        const menuTopUp = rect.top - 1;

        // Reset
        menu.style.maxHeight = '';
        menu.style.overflowY = '';

        const menuRect = menu.getBoundingClientRect();
        const menuHeight = menuRect.height;

        if (distanceToBottom >= distanceToTop) {
          if (distanceToBottom >= menuHeight + 10) {
            menu.style.top = `${menuTopDown}px`;
          } else {
            menu.style.top = `${menuTopDown}px`;
            menu.style.maxHeight = `calc(100vh - ${menuTopDown + 60}px)`;
            menu.style.overflowY = 'auto';
          }
        } else {
          if (distanceToTop >= menuHeight + 10) {
            menu.style.top = `${menuTopUp - menuHeight}px`;
          } else {
            menu.style.top = `${10}px`;
            menu.style.maxHeight = `calc(${distanceToTop - 10}px)`;
            menu.style.overflowY = 'auto';
          }
        }

        if (menuRect.width > viewportWidth - 20) {
          menu.style.maxWidth = `calc(100vw - 20px)`;
          menu.style.left = `10px`;
        } else {
          menu.style.left = click.left > 10 ? `${Math.min(click.left, viewportWidth - menu.offsetWidth - 10)}px` : `10px`;
        }
      });
    },

    hideContextMenu() {
      this.showContextMenu = false;
    },

    selectDash(layerDash) {
      const layers = this.selectedLayers.map(layer => layer.name);
      const currentLayers = layers.length > 1 ? layers : [this.currentLayer];

      // Change the dash in SketchUp
      sketchup.changeLayerDash(currentLayers, layerDash);

      // Update the layer's dash property in local state
      for (const id in this.layers) {
        const layer = this.layers[id];
        if (currentLayers.includes(layer.name)) {
          this.$set(this.layers[id], 'dash', layerDash);
        }
      }

      this.showDashesList = false; // Close the menu after selection
    },

    toggleDashesList(layerId, layerName) {
      this.showDashesList = true;
      this.currentLayer = layerName;

      this.$nextTick(() => {
        const element = document.getElementById(`dash-${layerId}`);
        const menu = document.getElementById('dashesList');

        if (!element || !menu) return;

        const rect = element.getBoundingClientRect();

        const viewportHeight = window.innerHeight;
        const viewportWidth = window.innerWidth;

        const distanceToTop = rect.top;
        const distanceToBottom = viewportHeight - rect.bottom;

        menu.style.left = `${Math.min(rect.left - 10, viewportWidth - menu.offsetWidth - 10)}px`;

        const menuTopDown = rect.bottom + 2;
        const menuTopUp = rect.top - 2;

        // Reset
        menu.style.maxHeight = '';
        menu.style.overflowY = '';

        const menuRect = menu.getBoundingClientRect();
        const menuHeight = menuRect.height;

        if (distanceToBottom >= distanceToTop) {
          if (distanceToBottom >= menuHeight + 10) {
            menu.style.top = `${menuTopDown}px`;
          } else {
            menu.style.top = `${menuTopDown}px`;
            menu.style.maxHeight = `calc(100vh - ${menuTopDown + 60}px)`;
            menu.style.overflowY = 'auto';
          }
        } else {
          if (distanceToTop >= menuHeight + 10) {
            menu.style.top = `${menuTopUp - menuHeight}px`;
          } else {
            menu.style.top = `${10}px`;
            menu.style.maxHeight = `calc(${distanceToTop - 10}px)`;
            menu.style.overflowY = 'auto';
          }
        }
      });
    },

    togglePinLayer(layer) {
      if (!Object.keys(this.pinLayers).includes(layer.id)) {
        this.$set(this.pinLayers, layer.id, layer.name);
      } else {
        this.$delete(this.pinLayers, layer.id, layer.name);
      }

      // Save pinned layers to localStorage
      localStorage.setItem(pinLayersKey, JSON.stringify(this.pinLayers));
    },

    setColorByTag(value) {
      this.colorByTag = value;
    },

    handleColorByTag() {
      this.colorByTag = !this.colorByTag;
      sketchup.colorByTag(this.colorByTag);
    },

    activeSampleTool() {
      this.isSampleTool = true;
      sketchup.sampleTool(this.currentLayer);
    },

    cancelSampleTool() {
      this.isSampleTool = false;
      this.currentLayer = null;
    },

    autoNameTag() {
      this.showUserOptions('autoNameTag');
    },

    moreActions(action) {
      if (action === 'collapseAll') {
        this.inputSearchQuery = ''; // Clear search query
        this.expandFolders = [];
        handleTooltip(this);
      } else if (action === 'expandAll') {
        this.inputSearchQuery = ''; // Clear search query
        this.expandFolders = this.folders.map(folder => folder.id);
        handleTooltip(this);
      }

      if (this.currentLayer === null && this.currentFolder === null) {
        return;
      }

      if (action === 'onAllFolders') {
        this.handleVisibleAllFolders(this.currentFolder, true);
      } else if (action === 'offAllFolders') {
        this.handleVisibleAllFolders(this.currentFolder, false);
      } else if (action === 'isolateFolder') {
        this.toggleIsolateFolder(this.currentFolder);
      } else if (action === 'tagAllEntities') {
        this.handleTagEntities(this.currentLayer, action);
      } else if (action === 'tagNestedObjects') {
        this.handleTagEntities(this.currentLayer, action);
      } else if (action === 'tagNestedGeometries') {
        this.handleTagEntities(this.currentLayer, action);
      } else if (action === 'onAllLayers') {
        this.handleVisibleAllLayers(true);
      } else if (action === 'offAllLayers') {
        this.handleVisibleAllLayers(false);
      } else if (action === 'isolateLayer') {
        this.toggleIsolateLayer(this.currentLayer);
      } else if (action === 'visibleAllScenes') {
        sketchup.createScenesList();
      } else if (action === 'deleteFolder') {
        this.handleDeleteFolder(this.currentFolder);
      } else if (action === 'deleteLayer') {
        this.handleDeleteLayer(this.currentLayer);
      }

      this.showContextMenu = false; // Close the context menu after action
    },

    showUserOptions(type) {
      this.hideModal(this.currentModal);
      this.userOptionsType = type;

      // Reset
      this.hasOptionsError = false;
      this.showMessageOptions = true;

      this.initUserOptions(type);
      this.showModal("#userOptionsModal", "wait");
    },

    initUserOptions(value) {
      // Reset error state when initializing options
      this.hasOptionsError = false;
      this.modalTitle = this.translated('options');

      // Use switch (true) to handle inclusive cases
      switch (true) {
        case value === "scenesVisible":
          this.initScenesVisible();
          break;
        case value === "autoNameTag":
          this.initAutoNameTag();
          break;
      }

      handleTooltip(this);
    },

    initScenesVisible() {
      const layer = this.currentLayer;
      const scene = this.scenesList[0].value;

      this.userOptions = [
        {
          key: "tag",
          label: this.translated("tag"),
          showLabel: true,
          type: "input",
          value: layer,
          disabled: true,
        },
        {
          key: "visible",
          label: this.translated("visible"),
          showLabel: true,
          type: "select",
          options: [
            {
              value: "on",
              label: this.translated("on"),
            },
            {
              value: "off",
              label: this.translated("off"),
            },
          ],
          value: "off",
          disabled: false
        },
        {
          key: "sceneExcluded",
          label: this.translated("sceneExcluded"),
          showLabel: false,
          type: "checkbox",
          value: true,
          disabled: false
        },
        {
          key: "scene",
          label: this.translated("sceneExcluded"),
          showLabel: false,
          type: "select",
          options: this.scenesList,
          value: scene,
          disabled: false
        },
      ];
    },

    initAutoNameTag() {
      this.userOptions = [
        {
          key: "basedOn",
          label: this.translated("basedOn"),
          showLabel: true,
          type: "select",
          options: [
            {
              value: "definitionName",
              label: this.translated("definitionName"),
            },
            {
              value: "instanceName",
              label: this.translated("instanceName"),
            }
          ],
          value: "definitionName",
          disabled: false,
        },
      ];
    },

    onUserOptionChange(index, element, value) {
      if (!this.userOptions[index]) return;

      this.userOptions[index].value = value;

      // Handle specific option dependencies
      const optionKey = this.userOptions[index].key;

      if (optionKey === "sceneExcluded") {
        const scenesIndex = this.userOptions.findIndex(option => option.key === "scenes");
        if (scenesIndex !== -1) {
          this.$set(this.userOptions[scenesIndex], "disabled", value === true ? false : true);
        }
      }
    },

    handleUserOptionsConfirm() {
      // Reset validation state
      this.hasOptionsError = false;

      // Loop through userOptions to validate each option
      this.userOptions.forEach((option, index) => {
        // Validate regular options with validationType
        if (option.validationType && (option.type === 'input' || option.type === 'number')) {
          const element = document.querySelector(`[data-option-index="${index}"]`);
          if (element) {
            const validation = this.validateInput(index, element, option.validationType);
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
            // Validate child options with validationType
            if (child.validationType && (child.type === 'input' || child.type === 'number')) {
              const childElement = document.querySelector(`[data-option-index="${index}"][data-child-key="${child.key}"]`);
              if (childElement) {
                const validation = this.validateInput(index, childElement, child.validationType, child.key);
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
        this.showMessageModal(message, "error");
        return;
      }

      // Process user options
      this.processUserOptions();
      this.hideModal("#userOptionsModal");
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

      // Reset error state
      this.hasOptionsError = false;

      this.hideModal("#userOptionsModal");
      this.modalAction1 = null;
      this.modalAction2 = null;
      this.modalTitle = "";

      // Restore previous modal
      this.showModal(this.currentModal, "wait");
    },

    processUserOptions() {
      // Create an object with the user option values
      const optionValues = {};
      this.userOptions.forEach((option) => {
        optionValues[option.key] = option.value;
      });

      // Debug: Log all option values
      // console.log("All option values:", optionValues);

      // Process based on the current context
      if (this.userOptionsType === "scenesVisible") {
        sketchup.visibleAllScenes(optionValues);

      } else if (this.userOptionsType === "autoNameTag") {
        sketchup.autoNameTag(optionValues);
      }

      hideAllTooltips();
      this.cleanUpUserOptions();
    },

    cleanUpUserOptions() {
      this.userOptions = [];
      this.scenesList = [];
      this.hideModal("#userOptionsModal");
    },

    exportToSketchup() {
      const checkedExportLayers = this.getCheckedExportLayers();

      // Check if checkedExportLayers is valid
      if (!checkedExportLayers || !Array.isArray(checkedExportLayers) || checkedExportLayers.length === 0) {
        const message = this.translated('chooseAtLeastOneTag');
        this.showMessageModal(message, 'info');
        return;
      }

      sketchup.exportLayers(checkedExportLayers);
    },

    exportToExcel() {
      const checkedExportLayers = this.getCheckedExportLayers();

      // Check if checkedExportLayers is valid
      if (!checkedExportLayers || !Array.isArray(checkedExportLayers) || checkedExportLayers.length === 0) {
        const message = this.translated('chooseAtLeastOneTag');
        this.showMessageModal(message, 'info');
        return;
      }

      const tableData = [
        ['Name', 'Color', 'Dashes'],
        ...Object.values(this.layers)
          .filter(layer => 
            typeof layer.name === 'string' && 
            layer.name.trim() && 
            layer.name !== "Untagged" && 
            checkedExportLayers.includes(layer.name)
          )
          .map(layer => [
            layer.name.trim(),
            layer.color.replace('rgba', 'Color') || '',
            layer.dash || ''
          ])
      ];

      // Sort the table data alphabetically by layer name,
      // but keep the header row at the top
      const sortedTable = tableData.sort((a, b) => {
        // Always keep header row at the top
        if (a[0] === 'Name') return -1;
        if (b[0] === 'Name') return 1;

        // Sort all other layers alphabetically by name
        return a[0].localeCompare(b[0], undefined, { sensitivity: 'base' });
      });

      const worksheet = XLSX.utils.aoa_to_sheet(sortedTable);
      const workbook = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(workbook, worksheet, 'Layers');

      const wbout = XLSX.write(workbook, { bookType: 'xlsx', type: 'array' });
      const blob = new Blob([wbout], {
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      });

      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'exported_layers.xlsx';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      this.hideModal(this.currentModal);
      setTimeout(() => {
        const message = this.translated('tagsExportedToExcel');
        const actionModal = 'restoreModal';
        this.showNoticeModal(message, null, actionModal);
      }, 100);
    },

    exportCompleted(number, path) {
      this.hideModal(this.currentModal);

      setTimeout(() => {
        const message =
          this.translated('exportCompleted') +
          '<br><br>' +
          this.translated('tagsExportedToSketchUp') +
          '<b> ' + number + '</b>' +
          '<br><b>' +
          path + '</b>'
        ;
        const actionModal = 'restoreModal';
        this.showNoticeModal(message, null, actionModal);
      }, 100);
    },

    importCompleted(number, path) {
      this.hideModal(this.currentModal);

      setTimeout(() => {
        const message =
          this.translated('importCompleted') +
          '<br><br>' +
          this.translated('tagsLoadedIntoModel') +
          '<b> ' + number + '</b>' +
          '<br><b>' + 
          path + '</b>'
        ;
        const actionModal = 'restoreModal';
        this.showNoticeModal(message, null, actionModal);
      }, 100);
    },

    dashesImageSource(layerDash) {
      const imgSrc =
        `../images/${this.dashesSource}/` + layerDash.toLowerCase().replace(/ /g, '_') + '.svg';
      return imgSrc;
    },

    sketchupActions(action) {
      sketchup.sketchupActions(action);
    },

    exportLayers() {
      this.handleOpenModal('#exportLayersModal', false);
    },

    toggleCompactMode() {
      this.compactMode = !this.compactMode;
      localStorage.setItem(compactModeKey, this.compactMode.toString());
      handleTooltip(this);
    },

    // EXCEL
    useExcel() {
      this.isExcel = !this.isExcel;
      localStorage.setItem(useExcelKey, JSON.stringify(this.isExcel));
      this.loadExcelContent();
      handleTooltip(this);
    },

    loadExcelContent() {
      const savedTable = JSON.parse(localStorage.getItem(savedTableKey));
      if (!savedTable) {
        this.loadDefaultExcel();
      } else {
        this.excelRows = savedTable;
      }

      const excelFileNameSaved = localStorage.getItem(excelFileNameKey);
      this.excelFileName = excelFileNameSaved;
      this.isResetExcel = this.excelFileName === null || this.excelFileName === '';
    },

    // Load Excel file
    loadExcelFile(event) {
      const file = event.target.files[0];

      if (!file) return;

      const reader = new FileReader();
      reader.onload = (e) => {
        this.parseExcelBuffer(e.target.result);

        // Allow selecting same file again
        event.target.value = '';

        $('#selectSheetModal').modal('show');
      };
      reader.readAsArrayBuffer(file);

      this.excelFileName = file.name;
      this.excelSaved = false;
    },

    // Load default Excel
    loadDefaultExcel() {
      let url = "../assets/default.xlsx";
      if (this.language === "vi-VN") {
        url = "../assets/default_vi.xlsx";
      }

      axios.get(url, { responseType: "blob" }).then((response) => {
        const reader = new FileReader();
        reader.onload = (e) => {
          this.parseExcelBuffer(e.target.result, true);
        };
        reader.readAsArrayBuffer(response.data);
      });
    },

    saveExcelAsDefault() {
      localStorage.setItem(excelFileNameKey, this.excelFileName);
      localStorage.setItem(savedTableKey, JSON.stringify(this.excelRows));

      this.excelSaved = true;
      this.isResetExcel = false;

      const message = this.translated('setDefaultMessage');
      this.showMessageModal(message, 'info');
    },

    parseExcelBuffer(buffer, autoLoad = false) {
      const data = new Uint8Array(buffer);
      const workbook = XLSX.read(data, { type: 'array' });

      this.workbook = workbook;
      this.sheetNames = workbook.SheetNames;
      this.selectedSheet = this.sheetNames[0];

      if (autoLoad) {
        this.loadSelectedSheet();
      }
    },

    loadSelectedSheet() {
      if (!this.workbook || !this.selectedSheet) return;

      // Get the selected sheet
      const sheet = this.workbook.Sheets[this.selectedSheet];

      // Convert sheet to JSON
      const rawData = XLSX.utils.sheet_to_json(sheet, { header: 1 });

      // First row is header
      const header = rawData[0] || [];
      const dataRows = rawData.slice(1);

      this.excelRows = dataRows.map(row => {
        const rowObj = {};
        header.forEach((col, index) => {
          rowObj[col] = row[index] !== undefined ? String(row[index]) : '';
        });
        return rowObj;
      });

      // Reset states
      this.excelCheckboxStates = {};
      this.excelRowStates = {};
    },

    // Handle check all
    toggleCheckAllExcel(value) {
      this.filteredExcelRows.forEach(row => {
        const rowKey = this.getRowKey(row);
        this.$set(this.excelCheckboxStates, rowKey, value);
      });
    },

    toggleCheckCategory(rowIndex, value) {
      const categoryRow = this.filteredExcelRows[rowIndex];
      const categoryName = this.getRowKey(categoryRow);

      // Find index of next category row
      const nextCategoryIndex = this.filteredExcelRows.slice(rowIndex + 1).findIndex(r => {
        const rowKey = this.getRowKey(r);
        return typeof rowKey === 'string' && rowKey.includes('<') && rowKey.includes('>');
      });

      const endIndex = nextCategoryIndex === -1 ? this.filteredExcelRows.length : rowIndex + 1 + nextCategoryIndex;

      for (let i = rowIndex + 1; i < endIndex; i++) {
        const row = this.filteredExcelRows[i];
        const rowKey = this.getRowKey(row);
        if (typeof rowKey === 'string' && !rowKey.includes('<') && !rowKey.includes('>')) {
          this.$set(this.excelCheckboxStates, rowKey, value);
        }
      }

      this.$set(this.excelCheckboxStates, categoryName, value);

      // Handle Check All after Category unchecked
      this.handleCheckboxChange(categoryName);
    },

    handleCheckboxChange(rowName) {
      const index = this.excelRows.findIndex(r => this.getRowKey(r) === rowName);
      const currentRow = this.excelRows[index];
      const isChecked = this.excelCheckboxStates[rowName];
      const currentRowKey = this.getRowKey(currentRow);
      const isCategory = typeof currentRowKey === 'string' && currentRowKey.includes('<') && currentRowKey.includes('>');

      // If uncheck layer, uncheck Category
      if (!isChecked && !isCategory) {
        for (let i = index - 1; i >= 0; i--) {
          const row = this.excelRows[i];
          const rowKey = this.getRowKey(row);
          if (rowKey && rowKey.includes('<') && rowKey.includes('>')) {
            this.$set(this.excelCheckboxStates, rowKey, false);
            break;
          }
        }
      }

      // ✅ If check a child row → watch all child rows to check category
      if (isChecked && !isCategory) {
        let parentIndex = -1;

        for (let i = index - 1; i >= 0; i--) {
          const row = this.excelRows[i];
          const rowKey = this.getRowKey(row);
          if (typeof rowKey === 'string' && rowKey.includes('<') && rowKey.includes('>') && index > i) {
            parentIndex = i;
            break;
          }
        }

        if (parentIndex !== -1) {
          let allChecked = true;

          const categoryName = this.getRowKey(this.excelRows[parentIndex]);
          for (let i = parentIndex + 2; i < this.excelRows.length; i++) {
            const row = this.excelRows[i];
            const rowKey = this.getRowKey(row);

            // Stop checking when reaching the next category row
            if (typeof rowKey === 'string' && rowKey.includes('<') && rowKey.includes('>')) break;

            // If any child row is unchecked, set allChecked to false
            if (!this.excelCheckboxStates[rowKey]) {
              allChecked = false;
              break;
            }
          }

          if (allChecked) {
            this.$set(this.excelCheckboxStates, categoryName, true);
          }
        }
      }

      // 🔁 Update "Check All"
      const checkAllBox = document.querySelector('#excelLayers thead input[type="checkbox"]');
      if (checkAllBox) {
        const allChecked = this.filteredExcelRows.every(row => {
          return this.excelCheckboxStates[this.getRowKey(row)];
        });
        checkAllBox.checked = allChecked;
      }
    },

    handleRowClick(row) {
      const firstColumnKey = this.firstColumnKey;
      const layer = {
        name: row[firstColumnKey],
        color: row['Color'],
        dashes: row['Dashes']
      };
      sketchup.importLayers([layer]);
    },

    excelSelectableRows() {
      return this.filteredExcelRows
        .filter(row => {
          const rowKey = this.getRowKey(row);
          return typeof rowKey === 'string' && !rowKey.includes('<') && !rowKey.includes('>');
        })
        .map(row => {
          const firstColumnKey = this.firstColumnKey;
          return {
            name: row[firstColumnKey],
            color: row['Color'],
            dashes: row['Dashes']
          };
        });
    },

    importSelectedExcelRows() {
      const selected = [];
      for (const row of this.excelSelectableRows()) {
        if (this.excelCheckboxStates[row.name]) {
          const layer = {
            name: row.name,
            color: row.color,
            dashes: row.dashes
          };
          selected.push(layer);
        }
      }

      sketchup.importLayers(selected);

      this.excelRowStates = {};
      this.excelCheckboxStates = {};

      // Reset checkboxes
      const checkAllBox = document.querySelector('#excelLayers thead input[type="checkbox"]');
      checkAllBox.checked = false;
    },

    resetExcel() {
      this.excelRows = [];
      this.excelFileName = '';
      localStorage.removeItem(savedTableKey);
      localStorage.removeItem(excelFileNameKey);
      this.loadDefaultExcel();
      this.excelSaved = true;
      this.isResetExcel = true;

      const message = this.translated('resetExcelMessage');
      this.showMessageModal(message, 'reset');
    },

    // END OF EXCEL

    checkReset() {
      let localStorageKeys = {};
      const allKeys = Object.keys(localStorage);
      const filteredKeys = allKeys.filter(
        (key) => key.includes(extensionName) && !key.includes("language")
      );

      filteredKeys.forEach((key) => {
        localStorageKeys[key] = true;
      });

      const keyLength = Object.keys(localStorageKeys).length;
      this.isReset = keyLength === 0;

      return localStorageKeys
    },

    resetAll() {
      localStorageKeys = this.checkReset();
      Object.keys(localStorageKeys).forEach((key) => {
        localStorage.removeItem(key);
      });
      this.pinLayers = {};
      this.isReset = true;
      this.excelFileName = ''

      if (this.isExcel) {
        this.loadExcelContent();
      }

      const message = this.translated('noticeDefaultMessage');
      this.showMessageModal(message, 'reset');
    },

    setExclusionList(data) {
      const { folder, layer, defaultFolder, defaultLayer } = data;
      this.folderExclusionList = folder.join(", ");
      this.layerExclusionList = layer.join(", ");
      this.defaultFolderExclusionList = defaultFolder.join(", ");
      this.defaultLayerExclusionList = defaultLayer.join(", ");
    },

    showExclusionListModal() {
      $('#exclusionListModal').modal('show');
    },

    setKeywords(action) {
      let message, type;

      if (action === 'Save') {
        const folderKeywordsArray = this.folderExclusionList.split(',').map(k => k.trim()).filter(k => k);
        const layerKeywordsArray = this.layerExclusionList.split(',').map(k => k.trim()).filter(k => k);
        sketchup.setExclusionList([folderKeywordsArray, layerKeywordsArray]);
        message = this.translated('saveExclusionListSuccess');
        type = 'success';
      } else if (action === 'Reset') {
        sketchup.setExclusionList(action);
        this.folderExclusionList = this.defaultFolderExclusionList;
        this.layerExclusionList = this.defaultLayerExclusionList;
        message = this.translated('resetExclusionListSuccess');
        type = 'reset';
      }

      $('#exclusionListModal').modal('hide');
      this.showMessageModal(message, type);
    },

    scrollToElement(selector, containerId) {
      this.$nextTick(() => {
        const el = document.querySelector(selector);
        const container = document.getElementById(containerId);

        if (el && container) {
          const elRect = el.getBoundingClientRect();
          const containerRect = container.getBoundingClientRect();

          const offset = elRect.top - containerRect.top - (containerRect.height / 2) + (elRect.height / 2);
          container.scrollTop += offset;
        }
      });
    },

    checkAllExportLayers() {
      const newValue = this.checkAllExportLayersValue;

      this.filteredExportLayers.forEach(layer => {
        layer.checked = newValue;
      });

      this.exportSearchQuery = ''; // Clear search query after checking/unchecking all layers

      // Scroll to the first checked layer if we're checking all
      if (newValue && this.filteredExportLayers.length > 0) {
        const checkedLayers = this.getCheckedExportLayers();
        this.checkedLayersLength = checkedLayers.length;
        if (this.checkedLayersLength > 0) {
          const lastLayerName = checkedLayers[this.checkedLayersLength - 1]; // Get last element

          const lastLayer = Object.values(this.layers).find(layer => layer.name === lastLayerName);
          if (lastLayer) {
            this.scrollToElement(`[data-layer-id="${lastLayer.id}"]`, 'exportLayersList');
          }
        }
      }
    },

    getCheckedExportLayers() {
      const checkedExportLayers = this.filteredExportLayers.filter((layer) => layer.checked);
      return checkedExportLayers.map((layer) => layer.name);
    },

    updateCheckAllExportLayers() {
      const allChecked = this.filteredExportLayers.length > 0 && this.filteredExportLayers.every((layer) => layer.checked);
      this.checkAllExportLayersValue = allChecked;
    },

    getVisibleLayersInExpandedFolders() {
      const visibleLayers = [];

      this.expandFolders.forEach(folderId => {
        const layersInFolder = this.filteredLayersInFolder(folderId);
        visibleLayers.push(...layersInFolder);
      });

      return visibleLayers;
    },

    onDragStart(event, id, type = 'folder') {
      const el = event.currentTarget;
      el.setAttribute('draggable', 'true');

      el.addEventListener('dragstart', (e) => {
        this.draggingItem = id;
        this.draggingType = type;

        e.dataTransfer.effectAllowed = 'move';

        // Prepare multi drag
        let ids = [];

        if (type === 'folder') {
          ids = this.selectedFolders.length > 0
            ? this.selectedFolders.map(f => f.id)
            : [id];
        } else if (type === 'layer') {
          ids = this.selectedLayers.length > 0
            ? this.selectedLayers.map(l => l.id)
            : [id];
        }

        e.dataTransfer.setData('type', type);
        e.dataTransfer.setData('ids', JSON.stringify(ids));
      }, { once: true });
    },

    onDragOver(event, targetFolderId) {
      if (this.draggingItem === targetFolderId && this.draggingType === 'folder') return;

      this.dragOverFolderId = targetFolderId;
    },

    onDragLeave(event, targetFolderId) {
      if (this.dragOverFolderId === targetFolderId) {
        this.dragOverFolderId = null;
      }
    },

    onDrop(event, targetFolderId) {
      const type = event.dataTransfer.getData('type');
      const ids = JSON.parse(event.dataTransfer.getData('ids') || '[]');

      if (type === 'folder') {
        ids.forEach(id => {
          if (id === targetFolderId) {
            console.warn(`Cannot move folder ${id} into itself!`);
            return;
          }

          sketchup.moveFolder(id, targetFolderId);
          const folder = this.folders.find(f => f.id === id);
          if (folder) folder.parent = targetFolderId;
        });
      }
      else if (type === 'layer') {
        ids.forEach(id => {
          sketchup.moveLayer(id, targetFolderId);
          const layer = Object.values(this.layers).find(l => l.id === id);
          if (layer) layer.folder = targetFolderId;
        });
      }

      // Reset drag state
      this.draggingItem = null;
      this.draggingType = null;
      this.dragOverFolderId = null;
      this.dragOverLayerId = null;

      // Rebuild tree
      this.foldersTree = this.foldersTree;
    },

    onDropOutside(event) {
      const type = event.dataTransfer.getData('type');
      const ids = JSON.parse(event.dataTransfer.getData('ids') || '[]');

      if (type === 'folder') {
        ids.forEach(id => {
          sketchup.moveFolder(id, null);
          const folder = this.folders.find(f => f.id === id);
          if (folder) folder.parent = null;
        });
      }
      else if (type === 'layer') {
        ids.forEach(id => {
          sketchup.moveLayer(id, null);
          const layer = Object.values(this.layers).find(l => l.id === id);
          if (layer) layer.folder = null;
        });
      }

      // Reset drag state
      this.draggingItem = null;
      this.draggingType = null;
      this.dragOverFolderId = null;
      this.dragOverLayerId = null;

      // Rebuild tree
      this.foldersTree = this.foldersTree;
    },

    toggleColorPicker(layer) {
      this.currentLayer = layer.name;
      this.updateColorInfo(layer.color)
      $('#colorPickerModal').modal('show');
    },

    changeLayerColor() {
      layerColor = {
        r: this.redValue,
        g: this.greenValue,
        b: this.blueValue,
        a: this.alphaValue
      };

      const rgba = `rgba(${this.redValue}, ${this.greenValue}, ${this.blueValue}, ${this.alphaValue})`;
      const layers = this.selectedLayers.map(layer => layer.name);
      const currentLayers = layers.length > 1 ? layers : [this.currentLayer];

      // Change the color in SketchUp
      sketchup.changeLayerColor(currentLayers, layerColor);

      // Update the layer's color property in local state
      for (const id in this.layers) {
        const layer = this.layers[id];
        if (currentLayers.includes(layer.name)) {
          this.$set(this.layers[id], 'color', rgba);
        }
      }

      // Hide the modal after changing color
      $('#colorPickerModal').modal('hide');
    },

    updateColorInfo(color) {

      const colorValues = color.replace(/rgba?\(|\)/g, '').split(',');
      this.redValue = parseFloat(colorValues[0]);
      this.greenValue = parseFloat(colorValues[1]);
      this.blueValue = parseFloat(colorValues[2]);
      this.alphaValue = parseFloat(colorValues[3]) / 255;
      this.transValue = Math.round(this.alphaValue * 100);

      this.rgbString = `rgb(${this.redValue}, ${this.greenValue}, ${this.blueValue})`;
      this.rgbaString = color;
      this.initialTrans = this.rgbaString;

      const hexValues = this.rgbToHex(this.redValue, this.greenValue, this.blueValue);
      this.initialColor = hexValues;
      this.hexString = hexValues;

      const hslValues = this.rgbaToHsl(this.rgbaString);
      this.hueValue = hslValues.hue;
      this.saturationValue = hslValues.saturation;
      this.lightnessValue = hslValues.lightness;
      this.hslString = hslValues.hslString;

      if (this.hexPicker) {
        this.hexPicker.color.hexString = this.initialColor;
        this.pickerTrans.color.set(this.initialTrans);
      } else {
        this.initHexPicker();
        this.initTransPicker();
      }

      if (this.rgbPicker) {
        this.rgbPicker.color.hexString = this.initialColor;
      } else {
        this.initRgbPicker();
      }

      if (this.hslPicker) {
        this.hslPicker.color.hexString = this.initialColor;
      } else {
        this.initHslPicker();
      }
    },

    selectContent(event) {
      const input = event.target;

      if (input.value.startsWith('#') && input.value.length === 7) {
        input.setSelectionRange(1, 7);
      } else {
        input.select();
      }
    },

    initHexPicker() {
      this.hexPicker = new iro.ColorPicker("#hexPicker", {
        width: 86,
        color: this.initialColor,
        layoutDirection: 'horizontal',
        layout: [
          {
            component: iro.ui.Wheel,
            options: {
              sliderType: 'value',
              borderWidth: 0
            }
          },
          {
            component: iro.ui.Slider,
            options: {
              sliderType: 'value',
              sliderSize: 15,
              borderWidth: 1,
              borderColor: "#e1e1e1"
            }
          },
        ]
      });

      this.hexPicker.on('color:change', (color) => {
        this.updateColorValues(color, 'hex');
      });
    },

    initRgbPicker() {
      this.rgbPicker = new iro.ColorPicker("#rgbPicker", {
        width: 140,
        color: this.initialColor,
        borderWidth: 1,
        borderColor: "#e1e1e1",
        layout: [
          {
            component: iro.ui.Slider,
            layoutDirection: 'horizontal',
            options: {
              sliderType: 'red',
              sliderSize: 15,
            }
          },
          {
            component: iro.ui.Slider,
            layoutDirection: 'horizontal',
            options: {
              sliderType: 'green',
              sliderSize: 15,
            }
          },
          {
            component: iro.ui.Slider,
            layoutDirection: 'horizontal',
            options: {
              sliderType: 'blue',
              sliderSize: 15,
            }
          },
        ]
      });

      this.rgbPicker.on('color:change', (color) => {
        this.updateColorValues(color, 'rgb');
      });
    },

    initHslPicker() {
      this.hslPicker = new iro.ColorPicker("#hslPicker", {
        width: 140,
        color: this.initialColor,
        borderWidth: 1,
        borderColor: "#e1e1e1",
        layout: [
          {
            component: iro.ui.Slider,
            layoutDirection: 'horizontal',
            options: {
              sliderType: 'hue',
              sliderSize: 15,
            }
          },
          {
            component: iro.ui.Slider,
            layoutDirection: 'horizontal',
            options: {
              sliderType: 'saturation',
              sliderSize: 15,
            }
          },
          {
            component: iro.ui.Slider,
            layoutDirection: 'horizontal',
            options: {
              sliderType: 'value',
              sliderSize: 15,
            }
          },
        ]
      });

      this.hslPicker.on('color:change', (color) => {
        this.updateColorValues(color, 'hsl');
      });
    },

    initTransPicker() {
      this.pickerTrans = new iro.ColorPicker("#transPicker", {
        width: 155,
        color: this.initialTrans,
        borderWidth: 1,
        borderColor: "#e1e1e1",
        layout: [
          {
            component: iro.ui.Slider,
            layoutDirection: 'horizontal',
            options: {
              sliderType: 'alpha',
              sliderSize: 20,
            }
          },
        ]
      });

      this.pickerTrans.on('color:change', (color) => {
        this.initialTrans = color.rgbaString;
        this.alphaValue = color.alpha;
        this.transValue = Math.round(this.alphaValue * 100);
      });
    },

    updateColorValues(color, picker) {
      this.hexString = color.hexString;
      this.rgbString = color.rgbString;
      this.redValue = color.rgb.r;
      this.greenValue = color.rgb.g;
      this.blueValue = color.rgb.b;

      this.hslString = color.hslString;
      this.hueValue = color.hsl.h;
      this.saturationValue = color.hsl.s;
      this.lightnessValueValue = color.hsl.l;

      this.initialTrans = `rgba(${this.redValue}, ${this.greenValue}, ${this.blueValue}, ${this.alphaValue})`

      // Update for Color Picker
      if (this.hexPicker && picker !== 'hex') {
        this.hexPicker.color.set(this.initialTrans);
        this.texturedColorized = true;
      }
      
      if (this.rgbPicker && picker !== 'rgb') {
        this.rgbPicker.color.set(this.initialTrans);
        this.texturedColorized = true;
      }

      if (this.hslPicker && picker !== 'hsl') {
        this.hslPicker.color.set(this.initialTrans);
        this.texturedColorized = true;
      }

      if (this.pickerTrans && this.pickerTrans.color.rgbaString !== this.initialTrans) {
        this.pickerTrans.color.set(this.initialTrans);
      }
    },

    validateAndUpdateValue(value, type) {
      if (type === 'hex') {
        if (this.isValidHex(value)) {
          const rgb = this.hexToRgb(value);
          this.redValue = rgb.red;
          this.greenValue = rgb.green;
          this.blueValue = rgb.blue;
          this.alphaValue = 1;
        }
      } else {
        // Convert value to integer
        let intValue = parseInt(value);

        // Define min and max base on (R, G, B, H, S, L, A)
        let min, max;

        if (type === 'red' || type === 'green' || type === 'blue') {
          min = 0;
          max = 255;
        } else if (type === 'hue') {
          min = 0;
          max = 359;
        } else if (type === 'saturation' || type === 'lightness') {
          min = 0;
          max = 100;
        } else if (type === 'alpha') {
          min = 0;
          max = 100;
        }

        // If input < min, set to min
        if (intValue < min) {
          intValue = min;
        }

        // If input > max, set to max
        if (intValue > max) {
          intValue = max;
        }

        // Update value base on input type
        if (type === 'red') {
          this.redValue = intValue;
        } else if (type === 'green') {
          this.greenValue = intValue;
        } else if (type === 'blue') {
          this.blueValue = intValue;
        } else if (type === 'hue') {
          this.hueValue = intValue;
        } else if (type === 'saturation') {
          this.saturationValue = intValue;
        } else if (type === 'lightness') {
          this.lightnessValue = intValue;
        } else if (type === 'alpha') {
          this.alphaValue = intValue / 100;
        }

        if (type === 'hue' || type === 'saturation' || type === 'lightness') {
          const rgb = this.hslToRgb(this.hueValue, this.saturationValue, this.lightnessValue);
          this.redValue = rgb.r;
          this.greenValue = rgb.g;
          this.blueValue = rgb.b;
        }
      }

      this.newColor = [this.redValue, this.greenValue, this.blueValue, this.alphaValue];
    },

    isValidHex(color) {
      const hexRegex = /^#[0-9A-Fa-f]{6}$/;
      return hexRegex.test(color);
    },

    rgbaToHsl(rgbaString) {
      const rgbaMatch = rgbaString.match(/rgba?\((\d+),\s*(\d+),\s*(\d+),?\s*[\d\.]*\)/i);

      if (!rgbaMatch) {
        throw new Error("Invalid RGBA format");
      }

      let r = parseInt(rgbaMatch[1], 10) / 255;
      let g = parseInt(rgbaMatch[2], 10) / 255;
      let b = parseInt(rgbaMatch[3], 10) / 255;

      let max = Math.max(r, g, b), min = Math.min(r, g, b);
      let h, s, l = (max + min) / 2;

      if (max === min) {
        h = s = 0;
      } else {
        let delta = max - min;
        s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);
    
        switch (max) {
          case r:
            h = (g - b) / delta + (g < b ? 6 : 0);
            break;
          case g:
            h = (b - r) / delta + 2;
            break;
          case b:
            h = (r - g) / delta + 4;
            break;
        }

        h = Math.round(h * 60);
        if (h < 0) h += 360;
      }

      s = Math.round(s * 100);
      l = Math.round(l * 100);

      return {
        hue: h,
        saturation: s,
        lightness: l,
        hslString: `hsl(${h}, ${s}%, ${l}%)`,
      };
    },

    hslToRgb(h, s, l) {
      s /= 100;
      l /= 100;

      const c = (1 - Math.abs(2 * l - 1)) * s;
      const x = c * (1 - Math.abs((h / 60) % 2 - 1));
      const m = l - c / 2;
      let r = 0, g = 0, b = 0;

      if (h >= 0 && h < 60) {
        r = c; g = x; b = 0;
      } else if (h >= 60 && h < 120) {
        r = x; g = c; b = 0;
      } else if (h >= 120 && h < 180) {
        r = 0; g = c; b = x;
      } else if (h >= 180 && h < 240) {
        r = 0; g = x; b = c;
      } else if (h >= 240 && h < 300) {
        r = x; g = 0; b = c;
      } else if (h >= 300 && h < 360) {
        r = c; g = 0; b = x;
      }

      r = Math.round((r + m) * 255);
      g = Math.round((g + m) * 255);
      b = Math.round((b + m) * 255);

      return { r, g, b };
    },

    rgbToHex(r, g, b) {
      const toHex = (value) => {
        const hex = value.toString(16);
        return hex.length === 1 ? '0' + hex : hex;
      };

      return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
    },

    hexToRgb(hex) {
      // Clear '#' if any
      hex = hex.replace(/^#/, '');

      // Convert from 3 characters to 6 if any
      if (hex.length === 3) {
        hex = hex.split('').map(char => char + char).join('');
      }

      // Covert hex to rgb values
      const bigint = parseInt(hex, 16);
      const r = (bigint >> 16) & 255;
      const g = (bigint >> 8) & 255;
      const b = bigint & 255;

      // Return
      return {
        red: r,
        green: g,
        blue: b,
        rgbString: `rgb(${r}, ${g}, ${b})`,
      }
    },

    // ===== VALIDATION HANDLERS =====

    // Event handlers for blur validation (on focus loss)
    handleInputValidation(index, element, validationType, childKey = null) {
      if (!element) return;

      // Validate immediately on blur (no need for debouncing)
      const validationResult = this.validateInput(index, element, validationType, childKey);
      this.hasOptionsError = !validationResult.isValid;
    },

    validateInput(index, element, validationType, childKey = null) {
      // console.log("Validating input:", element, "Type:", validationType);
      if (!element) return { isValid: true };

      const value = element.value;
      let validation = { isValid: true };

      // Remove existing error styling
      element.classList.remove("is-invalid");

      switch (validationType) {
        case "stringEmpty":
          validation = this.validateStringInput(index, value, true, childKey); // Allow empty, max 50 chars
          break;
        case "string":
          validation = this.validateStringInput(index, value, false, childKey); // No empty, max 50 chars
          break;
        case "number":
          validation = this.validateNumberInput(index, value, true, true, childKey); // allow zero, allow negative
          break;
        case "numberPositive":
          validation = this.validateNumberInput(index, value, true, false, childKey); // allow zero, disallow negative
          break;
        default:
          return { isValid: true };
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

    validateStringInput(index, value, allowEmpty = false, childKey = null) {
      const trimmedValue = value.trim();

      let isValid = true;
      let message = null;

      // Check if value is empty (when not allowed)
      if (!allowEmpty && !trimmedValue) {
        message = this.translated("cannotBeEmpty");
        isValid = false;
      }

      // Check name length (max 50 characters)
      if (trimmedValue.length > 50) {
        message = this.translated("nameTooLong");
        isValid = false;
      }

      // Set messageError for the appropriate option or child option
      if (!isValid && message) {
        if (childKey && this.userOptions[index] && this.userOptions[index].type === 'group' && this.userOptions[index].children) {
          const childOption = this.userOptions[index].children.find(child => child.key === childKey);
          if (childOption) {
            childOption.messageError = message;
          }
        } else if (this.userOptions[index]) {
          this.userOptions[index].messageError = message;
        }
      }

      return { isValid: isValid };
    },

    validateNumberInput(index, value, allowZero = false, allowNegative = false, childKey = null) {
      const trimmedValue = value.toString().trim();

      let isValid = true;
      let message = null;

      // Check if value contains only valid number characters (digits, decimal point, minus sign)
      // This regex allows: optional minus, digits, optional decimal point and more digits
      const numberRegex = /^-?(\d+\.?\d*|\.\d+)$/;
      if (!numberRegex.test(trimmedValue)) {
        message = this.translated("mustBeNumber");
        isValid = false;
      }

      // Convert to number after validation
      const numericValue = parseFloat(trimmedValue);

      // Double check for NaN (shouldn't happen with regex, but safety check)
      if (isNaN(numericValue)) {
        message = this.translated("mustBeNumber");
        isValid = false;
      }

      // Check if value is zero (when not allowed)
      if (!allowZero && numericValue === 0) {
        message = this.translated("cannotBeZero");
        isValid = false;
      }

      // Check if value is negative (when not allowed)
      if (!allowNegative && numericValue < 0) {
        message = this.translated("cannotBeNegative");
        isValid = false;
      }

      // Check if value is empty
      if (!trimmedValue) {
        message = this.translated("cannotBeEmpty");
        isValid = false;
      }

      // Set messageError for the appropriate option or child option
      if (!isValid && message) {
        if (childKey && this.userOptions[index] && this.userOptions[index].type === 'group' && this.userOptions[index].children) {
          const childOption = this.userOptions[index].children.find(child => child.key === childKey);
          if (childOption) {
            childOption.messageError = message;
          }
        } else if (this.userOptions[index]) {
          this.userOptions[index].messageError = message;
        }
      }

      if (isValid) {
        this.hasOptionsError = false;
      }

      return { isValid: isValid };
    },

    showValidationError(element, message) {
      if (!element) return;

      // Add error styling to input
      element.classList.add("is-invalid");

      // Show error message
      // this.showMessageModal(message, "error", 1000);
    },

    clearValidationError(element) {
      if (!element) return;

      // Remove error styling from input
      element.classList.remove("is-invalid");
    },

    // MODAL HANDLERS

    handleOpenModal(modalId) {
      if (this.currentModal && this.currentModal !== modalId) {
        this.hideModal(this.currentModal);
      } else {
        this.currentModal = modalId;
      }

      this.showModal(modalId, "wait");
    },

    handleCloseModal(modalId) {
      this.hideModal(modalId);
      this.currentModal = null; // Clear current modal state
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
      // Hide #messageModal if it's open
      this.hideModal('#messageModal');

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
          } else if (action2 === "restoreModal") {
            this.modalAction2 = {
              text: "OK",
              action: () => {
                this.handleOpenModal(this.currentModal)
              },
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
    },
  },
});

// Global functions to be called from SketchUp

function showNoticeModal(notice, action1 = null, action2 = null) {
  document.getElementById('app').__vue__.showNoticeModal(notice, action1, action2);
}

function showMessageModal(message, type, delay = null) {
  document.getElementById('app').__vue__.showMessageModal(message, type, delay);
}

function updateUrls(urls) {
  document.getElementById("app").__vue__.updateUrls(urls);
}

function noticeNewVersion(data) {
  document.getElementById('app').__vue__.noticeNewVersion(data);
}

function setExclusionList(data) {
  document.getElementById('app').__vue__.setExclusionList(data);
}

function updateData(data) {
  document.getElementById('app').__vue__.updateData(data);
}

function refreshFolder(data) {
  document.getElementById('app').__vue__.refreshFolder(data);
}

function refreshLayer(data) {
  document.getElementById('app').__vue__.refreshLayer(data);
}

function updateSelection(data, selected_objects) {
  document.getElementById('app').__vue__.updateSelection(data, selected_objects);
}

function updateScenesList(data) {
  document.getElementById('app').__vue__.updateScenesList(data);
}

function setColorByTag(data) {
  document.getElementById('app').__vue__.setColorByTag(data);
}

function cancelSampleTool() {
  document.getElementById('app').__vue__.cancelSampleTool();
}

function importCompleted(number, path) {
  document.getElementById('app').__vue__.importCompleted(number, path);
}

function exportCompleted(number, path) {
  document.getElementById('app').__vue__.exportCompleted(number, path);
}

$('#supportModal').on('shown.bs.modal', function () {
  const languageOption = localStorage.getItem(languageKey) || 'en-US';
  if (languageOption !== 'vi-VN') {
    $('#supportSecondTab').tab('show');
  } else {
    $('#supportFirstTab').tab('show');
  }
});
