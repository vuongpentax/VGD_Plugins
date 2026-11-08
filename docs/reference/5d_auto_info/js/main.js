const app = new Vue({
  el: '#app',

  mixins: [
    globalMixin,
    openDialogsMixin,
    showModalsMixin,
    userOptionsMixin,
    validatorsMixin
  ],

  data: {
    hasCrtext: false,
    presetsList: [],
    currentPreset: '',
    editingPresets: false,
    presetLanguage: 'en-US',
    isRefreshing: false, // Flag to prevent infinite loop
    currency: 'USD',
    currencies: [
      'BRL',
      'CNY',
      'CZK',
      'EUR',
      'JPY',
      'KRW',
      'PLN',
      'RUB',
      'SEK',
      'TRY',
      'THB',
      'UAH',
      'USD',
      'VND'
    ],
    roundUnit: {
      '0': 0,
      '0.0': 1,
      '0.00': 2,
      '0.000': 3,
      '0.0000': 4,
      '0.00000': 5,
      '0.000000': 6
    },
    lengthUnit: {
      'mm': 1000,
      'cm': 100,
      'm': 1,
      'in': 39.3700787,
      'ft': 3.2808399,
      'yd': 1.0936133
    },
    areaUnit: {
      'mm²': 1000000,
      'cm²': 10000,
      'm²': 1,
      'in²': 1550.0031,
      'ft²': 10.7639104,
      'yd²': 1.19599005
    },
    volumeUnit: {
      'mm³': 1000000000,
      'cm³': 1000000,
      'm³': 1,
      'in³': 61023.7441,
      'ft³': 35.3146667,
      'yd³': 1.30795062,
    },
    imageSizes: [
      128,
      256,
      512,
      1024
    ],
    imageViews: [
      'Isometric view',
      'Top view',
      'Front view',
      'Left view',
      'Right view',
      'Back view',
      'Bottom view',
      'Current view'
    ],
    imageStyles: [
      'Color style',
      'White style',
      'Current style'
    ],
    isCurrentView: false,
    totalRow: true,
    zoomSelection: true,
    projectedArea: true,
    requireObject: true,
    columnsHidden: false,
    columnStates: {
      ordinal: true,
      image: false,
      entity: false,
      definition: true,
      instance: false,
      description: false,
      lenX: false,
      lenY: false,
      lenZ: false,
      lenXZ: false,
      lenXY: false,
      lenXYZ: true,
      areaXZ: false,
      areaXY: false,
      areaFace: false,
      areaProjected: false,
      volume: false,
      ifc: false,
      tag: false,
      material: false,
      status: false,
      owner: false,
      url: false,
      size: false,
      price: false,
      dynamic: false,
      quantity: true,
      total: false,
    },
    orderedColumns: [],
    columnSearchQuery: '',
    itemSearchQuery: '',
    isCheckedAll: false,
    sortables: [],
    sortColumn: '',
    sortOrder: 1,

    columnsToTotalKeys: [
      'areaXZ',
      'areaXY',
      'areaFace',
      'areaProjected',
      'volume',
      'quantity',
      'lenX',
      'lenY',
      'lenZ',
      'total',
    ],

    objects: [],
    filteredObjects: [],
    savedSettings: {},
    layerList: [],
    materialList: [],
    ifcList: [],
    dynamicList: {},
    selectedItem: 'tag',
    cancelEditTimeout: null,

    modifiedHeaders: {
      areaFace: false,
      areaProjected: false,
      areaXY: false,
      areaXZ: false,
      dynamic: false,
      definition: false,
      description: false,
      entity: false,
      ifc: false,
      image: false,
      instance: false,
      lenX: false,
      lenXY: false,
      lenXYZ: false,
      lenXZ: false,
      lenY: false,
      lenZ: false,
      material: false,
      ordinal: false,
      owner: false,
      price: false,
      quantity: false,
      size: false,
      status: false,
      tag: false,
      total: false,
      url: false,
      volume: false,
    },

    settings: {},
    roundLength: false,
    formatLength: false,
    roundArea: false,
    formatArea: false,
    roundVolume: false,
    formatVolume: false,
    decimalSeparator: false,
    imageWidth: 256,
    imageHeight: 256,
    imageView: false,
    imageStyle: false,

    disabledButtons: true,
    currentHighlightedCell: false,
    currentHighlightedHeaderCell: false,
    highlightedIds: [],
    lastHighlightedId: null,
    findText: '',
    replaceText: '',
    showReplaceInput: false,
    isHighlighted: false,

    editingHeader: null,
    editedHeaderText: '',

    editingExtra: false,
    editingColKey: null,
    statusList: ['new', 'existing', 'reuse', 'temporary', 'demolition'],
    dynamicSearchQuery: '',
    dynamicAttribute: '',
    dynamicAccessInfo: {},
    editingDynamicType: null,
    editingDynamicOptions: {},
    editingDynamicUnits: '',
    customColumns: {},
    editingCell: null,
    originalCellValue: '',
    editedCellValue: '',
    isSaved: false,
    requiredSavedHeaders: [],
    initialTransformX: 0,
    initialTransformY: 0,
    editingGroupVal: null,
    editedGroupText: '',
    groupByColumn: 'none',
    mergeIdentical: true,
    collapsedGroups: {},
  },

  // Add Event listeners
  mounted() {
    // Add global click listener
    document.addEventListener('click', this.handleGlobalClick);

    // Language
    this.language = localStorage.getItem(languageKey) || 'en-US';
    loadLanguage(this);

    // Theme
    const savedTheme = localStorage.getItem(themeKey) || 'light';
    this.themeIcon = savedTheme === 'light' ? 'moon' : 'sun';
    this.currentTheme = savedTheme;
    applyTheme(savedTheme);

    // Total
    const totalRowSaved = localStorage.getItem(totalRowKey);
    this.totalRow = totalRowSaved === 'true';

    // Zoom
    const zoomSelectionSaved = localStorage.getItem(zoomSelectionKey);
    this.zoomSelection = zoomSelectionSaved === 'true';

    // Group By
    const groupByColumnSaved = localStorage.getItem(groupByColumnKey);
    if (groupByColumnSaved) {
      this.groupByColumn = groupByColumnSaved;
    }

    // Merge Identical
    const mergeIdenticalSaved = localStorage.getItem(mergeIdenticalKey);
    if (mergeIdenticalSaved !== null) {
      this.mergeIdentical = mergeIdenticalSaved === 'true';
    }

    // Column States
    const columnStatesSaved = localStorage.getItem(columnStatesKey);
    if (columnStatesSaved) {
      this.columnStates = JSON.parse(columnStatesSaved);
    }

    // Column Sorting
    const sortColumnSaved = localStorage.getItem(sortColumnKey);
    this.sortColumn = sortColumnSaved || 'definition';

    // Column Orders
    const sortOrderSaved = localStorage.getItem(sortOrderKey);
    this.sortOrder = Number(sortOrderSaved) || 1;

    // DRAG AND DROP
    const columnsList = document.getElementById('columnsList');
    const sortableColumns = new Sortable(columnsList, {
      animation: 150,
      onEnd: this.handleSortColumns,
    });
    this.sortables.push(sortableColumns);

    // Handle tool tip by Bootstrap
    handleTooltip(this);

    // Handle resize table when open columns dropdown
    const tableContainer = document.getElementById('tableContainer');

    $('.dropdown').on('shown.bs.dropdown', (e) => {
      if (!$(e.target).find('#columnButton').length) return;

      const dropdownWidth = $('#checkList').outerWidth();
      const safePadding = 8;
      const totalOffset = dropdownWidth + safePadding;
      const windowWidth = window.innerWidth;

      const remainingPercent = ((windowWidth - totalOffset) / windowWidth) * 100;

      tableContainer.style.transition = 'all 0.3s ease';
      tableContainer.style.marginLeft = `${totalOffset}px`;
      tableContainer.style.width = `${remainingPercent}%`;
    });

    $('.dropdown').on('hidden.bs.dropdown', () => {
    tableContainer.style.transition = 'all 0.3s ease';
    tableContainer.style.marginLeft = '0px';
    tableContainer.style.width = '100%';
  });
  },

  // Remove Event listeners to avoid memory leaks
  beforeDestroy() {
    document.removeEventListener('click', this.handleGlobalClick);

    $('#presetsButton').off('click');
  },

  watch: {
    currency(newVal) {
      if (this.isRefreshing) return;
      localStorage.setItem(currencyKey, newVal);
    },
    roundLength(newVal) {
      if (this.isRefreshing) return;
      const value = this.roundUnit[newVal];
      sketchup.changeRound('length', value);
    },
    roundArea(newVal) {
      if (this.isRefreshing) return;
      const value = this.roundUnit[newVal];
      sketchup.changeRound('area', value);
    },
    roundVolume(newVal) {
      if (this.isRefreshing) return;
      const value = this.roundUnit[newVal];
      sketchup.changeRound('volume', value);
    },
    formatLength(newVal) {
      if (this.isRefreshing) return;
      const value = this.lengthUnit[newVal];
      sketchup.changeUnit('length', value);
    },
    formatArea(newVal) {
      if (this.isRefreshing) return;
      const value = this.areaUnit[newVal];
      sketchup.changeUnit('area', value);
    },
    formatVolume(newVal) {
      if (this.isRefreshing) return;
      const value = this.volumeUnit[newVal];
      sketchup.changeUnit('volume', value);
    },
    decimalSeparator(newVal) {
      if (this.isRefreshing) return;
      sketchup.changeDecimalSeparator(newVal);
    },
    imageHeight(newVal) {
      if (this.isRefreshing) return;
      this.changeImageSettings();
    },
    imageWidth(newVal) {
      if (this.isRefreshing) return;
      this.changeImageSettings();
    },
    imageView(newVal) {
      if (this.isRefreshing) return;
      if (newVal === 'Current view') {
        this.isCurrentView = true;
      } else {
        this.isCurrentView = false;
      }
      this.changeImageSettings();
    },
    imageStyle(newVal) {
      if (this.isRefreshing) return;
      this.changeImageSettings();
    },
    groupByColumn(newVal) {
      if (this.isRefreshing) return;
      localStorage.setItem(groupByColumnKey, newVal);
      this.collapsedGroups = {};
    },
    mergeIdentical(newVal) {
      if (this.isRefreshing) return;
      localStorage.setItem(mergeIdenticalKey, String(newVal));
    },
  },

  computed: {
    filteredColumns() {
      const query = this.columnSearchQuery.toLowerCase();
      return this.orderedColumns.filter((colKey) => {
        let translated = '';
        if (colKey.includes('dynamicAttribute')) {
          translated = this.translated('dynamic').toLowerCase();
        } else if (colKey.includes('customAttribute')) {
          translated = this.translated('customAttribute').toLowerCase();
        } else {
          translated = this.translated(colKey).toLowerCase();
        }

        return translated.includes(query);
      });
    },

    filteredDynamicAttributes() {
      const query = this.dynamicSearchQuery.toLowerCase();
      filtered = this.dynamicList.filter(attr => attr.toLowerCase().includes(query));

      return filtered;
    },

    filteredItems() {
      const query = this.itemSearchQuery.toLowerCase();
      let itemsList = [];

      if (this.selectedItem === 'ifc') {
        itemsList = this.ifcList;
      } else if (this.selectedItem === 'tag') {
        itemsList = this.layerList;
      } else if (this.selectedItem === 'material') {
        itemsList = this.materialList;
      }
      filtered = itemsList.filter(attr => attr.toLowerCase().includes(query));
      if (filtered.length === 0) {
        filtered = [this.translated('notFound')];
      }

      return filtered;
    },

    checkedCount() {
      // Filter column has this.columnStates[colKey] === true
      return this.orderedColumns.filter((colKey) => {
        return this.columnStates[colKey];
      }).length;
    },

    ordinalMap() {
      return this.groupedObjects.reduce((map, item, index) => {
        map[item.id] = index + 1;
        return map;
      }, {});
    },

    groupedObjects() {
      if (!Array.isArray(this.objects) || this.objects.length === 0) return [];

      const quantityColumn = 'quantity';

      // Helper to build image metadata for the first row of a group
      const buildImageMeta = (row) => {
        let imageSrc = row.image || '../images/image.png';
        let isMaterial = imageSrc.includes('material');
        let isColor = imageSrc.includes('color');
        return {
          imageSrc,
          imageStyle: {
            objectFit: isMaterial ? 'cover' : 'unset',
            objectPosition: isMaterial ? 'center' : 'unset',
            padding: imageSrc ? '.5rem' : 'unset'
          },
          imageContainerStyle: {
            backgroundColor: isMaterial && isColor ? this.getMaterialColor(imageSrc) : 'transparent'
          },
          showUpdateButton: true
        };
      };

      // Without merging: return all rows individually with image metadata
      if (!this.mergeIdentical) {
        return this.objects.map((row) => ({ ...row, ...buildImageMeta(row) }));
      }

      // Helper: merge a set of rows by identical descriptive data, summing quantity only.
      // 'total' (In Model) is a per-definition count (count_used_instances) — not additive.
      const mergeRows = (rows) => {
        let map = {};
        rows.forEach((row) => {
          let rowData = { ...row };
          // Exclude identity/hierarchy fields and quantitative fields from the key
          delete rowData.id;
          delete rowData.ordinal;
          delete rowData.parent;
          delete rowData.parentDef;
          delete rowData.quantity;
          delete rowData.total;
          let key = JSON.stringify(rowData);
          if (!map[key]) {
            map[key] = { firstRow: null, totalQuantity: 0 };
          }
          map[key].totalQuantity += parseFloat(row[quantityColumn]) || 0;
          if (!map[key].firstRow) {
            map[key].firstRow = { ...row, ...buildImageMeta(row) };
          }
        });
        return Object.values(map).map((group) => {
          const firstRow = group.firstRow;
          firstRow[quantityColumn] = String(group.totalQuantity);
          // total (In Model) stays as-is from firstRow — it's count_used_instances, not a sum
          return firstRow;
        });
      };

      // No grouping: global merge across all rows
      if (this.groupByColumn === 'none') {
        return mergeRows(this.objects);
      }

      // Grouped by a column: merge identical rows within each group, then flatten
      const col = this.groupByColumn;
      const buckets = {};
      this.objects.forEach((row) => {
        const val = String(row[col] ?? '');
        if (!buckets[val]) buckets[val] = [];
        buckets[val].push(row);
      });
      const result = [];
      Object.values(buckets).forEach((groupRows) => {
        mergeRows(groupRows).forEach((row) => result.push(row));
      });
      return result;
    },

    sortedObjects() {
      if (!this.sortColumn) return this.groupedObjects;

      // console.log('sortedObjects > this.sortColumn', this.sortColumn);
  
      let thousandSeparator = this.decimalSeparator === '.' ? ',' : '.';

      const objects = [...this.groupedObjects].sort((a, b) => {
        let textA, textB;

        if (this.sortColumn.includes('len') || this.sortColumn.includes('area') || this.sortColumn.includes('volume')) {
          textA = this.removeThousandSeparator(this.safeValue(a[this.sortColumn]), thousandSeparator);
          textB = this.removeThousandSeparator(this.safeValue(b[this.sortColumn]), thousandSeparator);
        } else if (this.sortColumn.includes('image')) {
          textA = a.imageSrc ? 1 : 0;
          textB = b.imageSrc ? 1 : 0;
        } else {
          textA = this.safeValue(a[this.sortColumn]);
          textB = this.safeValue(b[this.sortColumn]);
        }

        return String(textA).localeCompare(String(textB), undefined, { numeric: true }) * this.sortOrder;
      });

      objects.forEach((row, index) => {
        row.ordinal = index + 1;
      });

      return objects;
    },

    groupByLabel() {
      if (this.groupByColumn === 'none') return this.translated('noGrouping');
      return this.translated(this.groupByColumn, true);
    },

    isGroupEditable() {
      return ['definition', 'description', 'instance', 'parent', 'owner', 'url', 'size', 'price'].includes(this.groupByColumn);
    },

    tableRows() {
      const rows = this.sortedObjects;
      if (!Array.isArray(rows) || rows.length === 0) return [];

      // Helper: mark _totalDuplicate on non-merging rows based on final display order
      const markDuplicates = (arr) => {
        if (this.mergeIdentical) return arr;
        const seenDefs = new Set();
        return arr.map((row) => {
          if (row._isParentRow) return row;
          const def = row.definition || '';
          const isDup = seenDefs.has(def);
          seenDefs.add(def);
          return isDup ? { ...row, _totalDuplicate: true } : row;
        });
      };

      // No group headers when not grouping
      if (this.groupByColumn === 'none') {
        return markDuplicates(rows);
      }

      // Specific column: sort by group column (stable sort preserves user sort within groups)
      const col = this.groupByColumn;
      const sorted = [...rows].sort((a, b) => {
        const valA = String(a[col] !== undefined && a[col] !== null ? a[col] : '');
        const valB = String(b[col] !== undefined && b[col] !== null ? b[col] : '');
        return valA.localeCompare(valB, undefined, { numeric: true });
      });

      // Re-assign ordinals after group sort
      sorted.forEach((row, index) => { row.ordinal = index + 1; });

      // Insert group header rows whenever the group value changes
      const result = [];
      let lastGroupVal = undefined;

      sorted.forEach((row) => {
        const val = String(row[col] !== undefined && row[col] !== null ? row[col] : '');
        if (val !== lastGroupVal) {
          lastGroupVal = val;
          result.push({ _isParentRow: true, _parent: val || '-', _groupVal: val, id: 'group-row-' + val });
        }
        row._groupVal = val;
        result.push(row);
      });

      return markDuplicates(result);
    },

    visibleColumnCount() {
      if (!this.orderedColumns || !this.columnStates) return 1;
      return this.orderedColumns.filter((col) => this.columnStates[col]).length || 1;
    }
  },

  methods: {
    safeValue(value) {
      return (value !== undefined && value !== null) ? value : '';
    },

    toggleGroup(groupVal) {
      this.$set(this.collapsedGroups, groupVal, !this.collapsedGroups[groupVal]);
    },

    highlightGroup(groupVal) {
      if (this.editingGroupVal === groupVal) return; // Editing in progress
      // Collect all entity rows belonging to this group
      const groupRows = this.tableRows.filter(r => !r._isParentRow && r._groupVal === groupVal);
      if (!groupRows.length) return;

      const ids = groupRows.map(r => r.id && r.id.split('-')[0]).filter(Boolean);
      if (!ids.length) return;

      // If all items in this group are already highlighted, deselect them all
      const allHighlighted = ids.every(id => this.highlightedIds.includes(id));
      if (allHighlighted) {
        this.highlightedIds = this.highlightedIds.filter(id => !ids.includes(id));
        this.lastHighlightedId = this.highlightedIds[this.highlightedIds.length - 1] || null;
        sketchup.highlight(this.highlightedIds, '', this.zoomSelection);
        return;
      }

      // Default text: definition name of first item in group
      const textContent = groupRows[0].definition || String(groupVal) || '';

      this.highlightedIds = ids;
      this.lastHighlightedId = ids[ids.length - 1];

      sketchup.highlight(ids, textContent, this.zoomSelection);
    },

    startEditingGroup(groupVal, currentText) {
      if (!this.isGroupEditable) return;
      this.editingGroupVal = groupVal;
      this.editedGroupText = currentText;
      this.$nextTick(() => {
        const input = this.$refs.groupEditInput;
        const el = Array.isArray(input) ? input[0] : input;
        if (el) { el.focus(); el.select(); }
      });
    },

    saveGroupEdit(groupVal) {
      if (!this.editingGroupVal || this.editingGroupVal !== groupVal) return;
      const newText = this.editedGroupText.trim();
      this.editingGroupVal = null;
      this.editedGroupText = '';
      if (!newText || newText === groupVal) return;
      const groupRows = this.tableRows.filter(r => !r._isParentRow && r._groupVal === groupVal);
      if (!groupRows.length) return;
      sketchup.changeValue(groupRows[0].id, this.groupByColumn, newText);
    },

    handleGroupEditEvent(event, groupVal) {
      if (event.key === 'Enter') {
        event.preventDefault();
        this.saveGroupEdit(groupVal);
      } else if (event.key === 'Escape') {
        this.editingGroupVal = null;
        this.editedGroupText = '';
      }
    },

    handleGlobalClick(event) {
      // The logic from your snippet
      const { target: element } = event;

      // Ignore event if click to update image button
      if (
        element.classList && element.classList.contains('update-image') ||
        element.closest && element.closest('.update-image')
      ) {
        return;
      }

      let cell = element;

      // If user clicks a <span>, we find the closest <td>
      if (element.tagName === 'SPAN') {
        cell = element.closest('td');
      }

      // If it is a <td> itself
      if (cell?.tagName === 'TD') {
        const row = cell.closest('tr');
        if (row && row.id !== 'extra') {
          const textContent = cell.textContent.trim();
          const id = cell.id.split('-')[0];

          // Group header row td has no id — highlight is handled by highlightGroup()
          if (!id) return;

          if (event.ctrlKey) {
            // Ctrl+click: toggle entity in/out of selection
            const idx = this.highlightedIds.indexOf(id);
            if (idx === -1) {
              this.highlightedIds = [...this.highlightedIds, id];
              this.lastHighlightedId = id;
            } else {
              this.highlightedIds = this.highlightedIds.filter(hid => hid !== id);
            }
          } else if (event.shiftKey && this.lastHighlightedId) {
            // Shift+click: range selection from last clicked to current
            const visibleRows = this.tableRows.filter(r => !r._isParentRow);
            const lastIndex = visibleRows.findIndex(r => r.id && r.id.split('-')[0] === this.lastHighlightedId);
            const currentIndex = visibleRows.findIndex(r => r.id && r.id.split('-')[0] === id);
            if (lastIndex !== -1 && currentIndex !== -1) {
              const start = Math.min(lastIndex, currentIndex);
              const end = Math.max(lastIndex, currentIndex);
              const rangeIds = visibleRows.slice(start, end + 1).map(r => r.id.split('-')[0]);
              const combined = new Set([...this.highlightedIds, ...rangeIds]);
              this.highlightedIds = Array.from(combined);
            } else {
              this.highlightedIds = [id];
              this.lastHighlightedId = id;
            }
          } else {
            // Regular single click
            this.highlightedIds = [id];
            this.lastHighlightedId = id;
          }

          // Call highlight function with all highlighted IDs
          sketchup.highlight(this.highlightedIds, textContent, this.zoomSelection);
        }
      } else { // If clicked outside <td>
        this.$nextTick(() => {
          const inputRef = this.$refs['dynamicInput'];
          const inputElement = Array.isArray(inputRef) ? inputRef[0] : inputRef;
          if (inputElement && inputElement !== cell) {
            this.cancelEditDynamic();
          }
        });

        const tableEl = this.$refs.myTable;
        if (tableEl) {
          tableEl.focus();
        }
      }
    },

    handleMouseLeave() {
      sketchup.mouseLeave();
    },

    // changeLanguage(lang) {
    //   this.language = lang;
    //   localStorage.setItem(languageKey, this.language);
    //   loadLanguage(this);
    //   sketchup.changeLanguage(this.language);

    //   this.handleTooltip();
    // },

    changeImageSettings() {
      const width = this.imageWidth;
      const height = this.imageHeight;
      const view = this.imageView;
      const style = this.imageStyle;

      sketchup.imageSettings(width, height, view, style);
    },

    handleSortColumns() {
      const items = document.querySelectorAll('#columnsList li');
      const newOrder = [];

      items.forEach((item) => {
        const key = item.id.replace('checkbox-', '');
        if (key) {
          newOrder.push(key);
        }
      });

      localStorage.setItem(columnOrdersKey, JSON.stringify(newOrder));
      this.getOrderedColumns();
    },

    handleSortPresets(evt) {
      const { oldIndex, newIndex } = evt;
      if (oldIndex === newIndex) return;

      const updated = [...this.presetsList];
      const moved = updated.splice(oldIndex, 1)[0];
      updated.splice(newIndex, 0, moved);
      this.presetsList = updated;

      sketchup.reorderPresets(updated);
    },

    // Function to toggle the display of the total row based on the switch status
    toggleTotalRow() {
      localStorage.setItem(totalRowKey, JSON.stringify(this.totalRow));
    },

    toggleZoomSelection() {
      sketchup.zoomSelection(this.zoomSelection);
      localStorage.setItem(zoomSelectionKey, this.zoomSelection);
    },

    toggleProjectedArea() {
      if (this.projectedArea) {
        this.modalTitle = 'confirmation';
        this.modalAction1 = {
          text: 'no',
          action: () => this.realtimeProjectedArea('no')
        };
        this.modalAction2 = {
          text: 'yes',
          action: () => this.realtimeProjectedArea('yes'),
        };
        this.modalMessage = 'projectedAreaMessage';
        this.showModal('#actionModal', 'wait');
      } else {
        sketchup.projectedArea(this.projectedArea);
      }
    },

    getSumForColumn(colKey) {
      const decSep = this.decimalSeparator;
      const thouSep = decSep === '.' ? ',' : '.';

      let total = 0;
      let decimalLength = 0;
      let isFirstRow = true;

      // For 'total' (In Model = count_used_instances), only count the first occurrence
      // of each definition, since the value is the same for all instances of a definition.
      const seenDefinitions = colKey === 'total' ? new Set() : null;

      this.objects.forEach((row) => {
        // Get value follow colKey
        let rawValue = row[colKey];

        // Find decimal length from first row
        if (isFirstRow && typeof rawValue === 'string') {
          // Get decimal part to format, example '5.123' => 3
          decimalLength = (rawValue.split(decSep)[1] || '').length;
          isFirstRow = false;
        }

        const numberValue = this.parseNumber(rawValue, decSep, thouSep);
        if (!isNaN(numberValue)) {
          if (seenDefinitions) {
            const defKey = row.definition || '';
            if (!seenDefinitions.has(defKey)) {
              seenDefinitions.add(defKey);
              total += numberValue;
            }
          } else {
            total += numberValue;
          }
        }
      });

      // Format number
      return this.formatNumber(total, decSep, thouSep, decimalLength);
    },

    parseNumber(value, decimalSeparator, thousandSeparator) {
      if (typeof value === 'number') return value;
      if (typeof value !== 'string') return NaN;

      // Replace thousandSeparator by '' to remove
      let normalized = value.replace(
        new RegExp(`\\${thousandSeparator}`, 'g'),
        ''
      );
      // Replace decimalSeparator by '.'
      if (decimalSeparator !== '.') {
        normalized = normalized.replace(decimalSeparator, '.');
      }
      return parseFloat(normalized);
    },

    formatNumber(num, decimalSeparator, thousandSeparator, decimalLength) {
      if (isNaN(num)) return '';

      let fixedStr = num.toFixed(decimalLength);

      // Replace '.' by decimalSeparator
      if (decimalSeparator !== '.') {
        fixedStr = fixedStr.replace('.', decimalSeparator);
      }

      // Separate integer with decimal
      let [intPart, decPart] = fixedStr.split(decimalSeparator);

      // Add thousandSeparator for intPart (Ex: 123456 => '123.456')
      intPart = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, thousandSeparator);

      if (decPart === undefined) {
        return intPart;
      } else {
        return intPart + decimalSeparator + decPart;
      }
    },

    restoreLastPreset() {
      const lastPresetSaved = localStorage.getItem(lastPresetKey);
      this.currentPreset = lastPresetSaved && this.presetsList.includes(lastPresetSaved) ? lastPresetSaved : this.presetsList[0] || 'Default';
      sketchup.selectPreset(this.currentPreset);
    },

    noticeNewVersion(value) {
      this.isNewVersion = value;
    },

    checkUpdate() {
      sketchup.checkUpdate();
    },

    displayButtonUpdateImage() {
      const tds = document.querySelectorAll('table[id*="image"] td');
      tds.forEach((td) => {
        const updateButton = td.querySelector('.update-image');

        if (updateButton) {
          td.style.position = 'relative';
        }
      });
    },

    // This is for disable buttons when select object or not
    disableButtons(value) {
      this.disabledButtons = value;
    },

    displayMessageText(value) {
      if (this.objects && value) {
        return;
      }

      this.requireObject = value;
    },

    updateFolderPath(path, notice) {
      // console.log('path', path);
      const input = document.getElementById('folderPath');
      input.value = path;

      if (!notice) {
        return;
      }

      const message = this.translated('updateImagesFolderMessage');
      this.showMessageModal(message, 'info', 2000);
    },

    completeExport() {
      const message = this.translated('exportExcelMessage');
      this.showMessageModal(message, 'success', 2000);
    },

    realtimeProjectedArea(value) {
      this.projectedArea = value === 'yes';

      sketchup.projectedArea(this.projectedArea);
    },

    // UPDATE DATA
    updateData(data) {
      // console.log('updateData', data);
      this.objects = data.data;
      this.customColumns = data.custom_columns;

      // Hide message text require select object
      this.requireObject = false;

      // Custom header or user setting
      this.updateModifiedHeaders();

      this.layerList          = data.layer_list;
      this.materialList       = data.material_list;
      this.ifcList            = data.ifc_list || [];
      this.dynamicList        = data.dynamic_list;
      this.dynamicAttribute   = data.recent_dynamic_key || 'n/a';
      this.dynamicAccessInfo  = data.dynamic_access_info || {};
      this.hasCrtext          = data.has_crtext || false;
      this.projectedArea      = data.projected_area || false;

      // Preset
      if (this.orderedColumns.length === 0) {
        this.restoreLastPreset();
      };

      // Sort layer list
      this.layerList.sort((a, b) =>
        a.toLowerCase().localeCompare(b.toLowerCase())
      );

      // Sort material list
      this.materialList.sort((a, b) =>
        a.toLowerCase().localeCompare(b.toLowerCase())
      );

      // Call the methods that handle grouping, sorting, etc.
      this.getOrderedColumns();
      this.initColumns();

      // Update tooltips after DOM is updated
      this.$nextTick(() => {
        handleTooltip(this);
      });

      // Close any loading modal
      $('#waitAllImagesModal').modal('hide');
    },

    setCurrentPreset(data) {
      // console.log('setCurrentPreset');
      const columns = data.columns;
      const headers = data.headers;
      const order = data.order;

      this.columnStates = columns;
      this.modifiedHeaders = headers;
      this.orderedColumns = order;

      // Restore customColumns from preset (preserves {dictionary,attribute} Hash)
      if (data.custom_columns !== undefined) {
        this.customColumns = data.custom_columns;
      }

      localStorage.setItem(columnStatesKey, JSON.stringify(columns));
      localStorage.setItem(modifiedHeadersKey, JSON.stringify(headers));
      localStorage.setItem(columnOrdersKey, JSON.stringify(order));

      this.getOrderedColumns();
    },

    updatePresetHeaders(data) {
      this.modifiedHeaders = data;
      localStorage.setItem(modifiedHeadersKey, JSON.stringify(data));
    },

    findKeyByValue(unitObj, value) {
      return Object.keys(unitObj).find(key => unitObj[key] === value) || '';
    },

    updatePresetSettings(data) {
      // console.log('updatePresetSettings', data.language);
      this.presetLanguage = data.language;
      this.currency = data.currency;
      this.sortColumn = data.sort_column;
      this.sortOrder = data.sort_order;
      this.settings = data.settings;

      this.isRefreshing = true; // Start blocking watcher

      this.roundLength = this.findKeyByValue(this.roundUnit, this.settings.roundLength);
      this.formatLength = this.findKeyByValue(this.lengthUnit, this.settings.formatLength);

      this.roundArea = this.findKeyByValue(this.roundUnit, this.settings.roundArea);
      this.formatArea = this.findKeyByValue(this.areaUnit, this.settings.formatArea);

      this.roundVolume = this.findKeyByValue(this.roundUnit, this.settings.roundVolume);
      this.formatVolume = this.findKeyByValue(this.volumeUnit, this.settings.formatVolume);

      this.decimalSeparator = this.settings.decimalSeparator;

      this.imageWidth = this.settings.imageWidth || 256;
      this.imageHeight = this.settings.imageHeight || 256;
      this.imageView = this.settings.imageView;
      this.imageStyle = this.settings.imageStyle;
      if (this.imageView === 'Current view') {
        this.isCurrentView = true;
      } else {
        this.isCurrentView = false;
      }

      // Wait nextTick then unlock watcher
      this.$nextTick(() => {
        this.isRefreshing = false;
      });

      localStorage.setItem(sortColumnKey, JSON.stringify(this.sortColumn));
      localStorage.setItem(sortOrderKey, JSON.stringify(this.sortOrder));
    },

    updatePresetList(data) {
      // console.log('updatePresetList', data);
      this.presetsList = data;

      if (!this.presetsList.includes(this.currentPreset)) {
        this.currentPreset = this.presetsList[0];
      }
    },

    getOrderedColumns() {
      // Return the list of columns in the desired or saved order
      if (!this.objects || !this.objects.length) return [];

      const allColumns = this.orderedColumns.filter((col) => col !== 'id');

      // Get orders value in string
      const columnOrdersSaved = localStorage.getItem(columnOrdersKey);

      if (columnOrdersSaved) {
        // Convert string to Array
        // const savedKeys = columnOrdersSaved.split(',');
        const savedKeys = JSON.parse(columnOrdersSaved);

        // Filter valid keys
        let validKeys = savedKeys.filter(key => allColumns.includes(key));

        // If a new column is added but not in 'savedKeys' => add
        allColumns.forEach((col) => {
          if (!validKeys.includes(col)) {
            validKeys.push(col);
          }
        });

        this.orderedColumns = validKeys;
      } else {
        this.orderedColumns = allColumns;
      }

      return this.orderedColumns;
    },

    initColumns() {
      this.orderedColumns.forEach((col) => {
        // If columnStates not yet defined, default to true
        if (this.columnStates[col] === undefined) {
          this.$set(this.columnStates, col, true);
        }
      });
    },

    updateModifiedHeaders() {
      const modifiedHeadersSaved = localStorage.getItem(modifiedHeadersKey);
      if (modifiedHeadersSaved) {
        this.modifiedHeaders = JSON.parse(modifiedHeadersSaved);
      }
    },

    // Handling the header click
    handleHeaderClick(colKey) {
      this.currentHighlightedHeaderCell = colKey;

      // Reverse sort order
      this.sortOrder *= -1;
      this.sortColumn = colKey;

      // Save values
      localStorage.setItem(sortColumnKey, this.sortColumn);
      localStorage.setItem(sortOrderKey, this.sortOrder);
    },

    // Return extra info for the second header row
    getExtraInfo(key) {
      // console.log('key', key);
      if (key.includes('len')) {
        return this.formatLength;
      } else if (key.includes('area')) {
        return this.formatArea;
      } else if (key === 'volume') {
        return this.formatVolume;
      } else if (key === 'dynamic') {
        return this.dynamicAttribute; // First dynamic component attribute
      } else if (key.includes('dynamicAttribute')) {
        return this.customColumns ? this.customColumns[key] : 'Name'; // First dynamic component attribute
      } else if (key.includes('customAttribute')) {
        const info = this.customColumns && this.customColumns[key];
        return info ? (info.attribute || '') : '';
      } else if (key === 'price') {
        return this.currency;
      } else if (key === 'quantity') {
        return this.translated('selection');
      } else if (key === 'total') {
        return this.translated('in_model');
      } else {
        return '';
      }
    },

    // Cell click
    handleDataCellClick(event, row, colKey) {
      // Clear previous editable-cell indicator (text-primary only)
      if (this.currentHighlightedCell) {
        this.currentHighlightedCell.classList.remove('text-primary');
        this.currentHighlightedCell = null;
      }
      const target = event.currentTarget;
      // Mark editable cells with text-primary; row-level bg highlight is handled reactively
      const isEditable = [
        'image',
        'definition',
        'description',
        'price',
        'url',
      ].includes(colKey);
      if (isEditable) {
        target.classList.add('text-primary');
        this.currentHighlightedCell = target;
      }
    },

    // Style alignment for cells
    getDataCellStyle(key, isCell) {
      if (['ordinal', 'image', 'size'].includes(key)) {
        return { textAlign: 'center' };
      } else if (
        key.includes('len') ||
        key.includes('area') ||
        key === 'volume' ||
        key === 'price' ||
        key === 'quantity' ||
        key === 'total'
      ) {
        return { textAlign: 'right' };
      } else if (isCell && ['instance', 'description'].includes(key)) {
        return { whiteSpace: 'pre-wrap' };
      } else {
        return { textAlign: 'left' };
      }
    },

    // For status badge
    getStatusBadgeClass(value) {
      if (value === '') {
        return;
      } else if (value === this.translated('new')) {
        return 'badge badge-primary';
      } else if (value === this.translated('existing')) {
        return 'badge badge-warning';
      } else if (value === this.translated('reuse')) {
        return 'badge badge-success';
      } else if (value === this.translated('temporary')) {
        return 'badge badge-tertiary';
      } else if (value === this.translated('demolition')) {
        return 'badge badge-danger';
      } else {
        return 'badge badge-dark';
      }
    },

    // For images
    updateImage(row) {
      row.imageSrc = 'images/image.png';
      this.$set(row, 'imageSrc', row.imageSrc);
      this.$set(row, 'imageStyle', {
        width: '128px',
        height: '128px',
        objectFit: 'cover',
        objectPosition: 'center',
        padding: '.5rem'
      });

      sketchup.updateImage(row.id.split('-')[0]);
    },

    adjustImageSize(event, row) {
      const imgElement = event.target;
      const imgHeight = imgElement.naturalHeight;
      const imgWidth = imgElement.naturalWidth;
      imgElement.width = (imgWidth / imgHeight) * imgElement.height;
    },

    getMaterialColor(imagePath) {
      if (!imagePath.includes('color')) return 'transparent';

      let colorName = imagePath.replace(/^auto_info_/, '').replace(/\.png$/, '');
      return convertDataColor(colorName);
    },

    addSumRow() {
      const columnsToTotalKeys = ["areaXZ", "areaXY", "areaFace", "areaProjected", "volume", "quantity", "total"];
      let definitionTracker = new Set();

      let table = this.$refs.myTable;
      if (!table) return;
  
      let tbody = this.$refs.myTableBody;
      let tfoot = table.querySelector("tfoot");

      if (!tfoot) {
        tfoot = document.createElement("tfoot");
        table.appendChild(tfoot);
      } else {
        tfoot.innerHTML = "";
      }

      let sumRow = document.createElement("tr");
      sumRow.className = "sum-row";
      sumRow.id = "totalRow";

      let columns = this.orderedColumns;

      columns.forEach((colKey) => {
        let sumCell = document.createElement("td");
        sumCell.classList.add("extra-cell", "text-right", "font-weight-bold");

        if (columnsToTotalKeys.includes(colKey)) {
          let total = 0;

          let rows = tbody.querySelectorAll("tr:not(.sum-row)");
          rows.forEach((row) => {
            let cell = row.querySelector(`[id*='-${colKey}']`);
            let definitionCell = row.querySelector(`[id*='-definition']`);

            if (cell && cell.textContent.trim() !== "") {
              let value = parseFloat(cell.textContent.replace(/,/g, "")) || 0;

              if (colKey === "total") {
                let definitionValue = definitionCell ? definitionCell.textContent.trim() : "";
                if (!definitionTracker.has(definitionValue)) {
                  total += value;
                  definitionTracker.add(definitionValue);
                }
              } else {
                total += value;
              }
            }
          });

          sumCell.textContent = this.formatNumber(total);
        }

        sumRow.appendChild(sumCell);
      });
  
      tfoot.appendChild(sumRow);
    },

    addNewColumn() {
      $('#columnButton').dropdown('hide');
      this.initCreateNewColumn();
    },

    addCustomAttributeColumn(optionValues) {
      this.columnsHidden = false; // Reset columns hidden

      // Extract values from the modal
      const columnName = optionValues.columnName || 'Custom';
      const columnType = optionValues.columnType || 'custom';

      // Generate unique column key
      let baseKey = 'customAttribute';
      let newKey = baseKey;
      let counter = 0;

      // Increment the key if it already exists
      while (this.orderedColumns && this.orderedColumns.includes(newKey)) {
        counter++;
        newKey = `${baseKey}${counter}`;
      }

      // Add the new column to Vue's data
      this.orderedColumns.push(newKey);
      this.$set(this.columnStates, newKey, true); // Default to visible (reactive)
      this.$set(this.modifiedHeaders, newKey, columnName); // Use the user-provided name (reactive)

      // Save the updated state to localStorage
      localStorage.setItem(columnOrdersKey, JSON.stringify(this.orderedColumns));
      localStorage.setItem(columnStatesKey, JSON.stringify(this.columnStates));
      localStorage.setItem(modifiedHeadersKey, JSON.stringify(this.modifiedHeaders));

      if (!this.customColumns) {
        this.customColumns = {};
      }

      // Prepare the attribute information
      const attributeInfo = {
        dictionary: optionValues.attributeDictionaryName || '',
        attribute: optionValues.attributeName || ''
      };
      this.customColumns[newKey] = attributeInfo;

      // Notify SketchUp about the new custom column
      sketchup.addCustomAttributeColumn(newKey, attributeInfo, columnType);

      // Show success message
      const message = this.translated('columnAddedSuccessfully') || 'Column added successfully';
      this.showMessageModal(message, 'success', 2000);
    },

    addCustomDynamicColumn(optionValues = {}) {
      this.columnsHidden = false; // Reset columns hidden
      let baseKey = 'dynamicAttribute';
      let newKey = baseKey;
      let counter = 0;

      // Increment the key if it already exists
      while (this.orderedColumns && this.orderedColumns.includes(newKey)) {
        counter++;
        newKey = `${baseKey}${counter}`;
      }
      // console.log('newKey', newKey);

      // Add the new custom column to Vue's data first
      const columnName = optionValues.columnName || '';
      this.orderedColumns.push(newKey);
      this.$set(this.columnStates, newKey, true); // Default to visible (reactive)
      this.$set(this.modifiedHeaders, newKey, columnName); // Use the user-provided name (reactive)

      // Save the updated state to localStorage
      localStorage.setItem(columnOrdersKey, JSON.stringify(this.orderedColumns));
      localStorage.setItem(columnStatesKey, JSON.stringify(this.columnStates));
      localStorage.setItem(modifiedHeadersKey, JSON.stringify(this.modifiedHeaders));

      if (!this.customColumns) {
        this.customColumns = {};
      }

      const newAttr = this.dynamicList[0];
      this.customColumns[newKey] = newAttr;

      // Notify SketchUp about the new custom column
      sketchup.addCustomDynamicColumn(newKey, newAttr);
    },

    removeCustomColumn(colKey) {
      // Remove the column from Vue's data
      this.orderedColumns = this.orderedColumns.filter((col) => col !== colKey);
      delete this.columnStates[colKey];
      delete this.modifiedHeaders[colKey];
      delete this.customColumns[colKey];

      // Save the updated state to localStorage
      localStorage.setItem(columnOrdersKey, JSON.stringify(this.orderedColumns));
      localStorage.setItem(columnStatesKey, JSON.stringify(this.columnStates));
      localStorage.setItem(modifiedHeadersKey, JSON.stringify(this.modifiedHeaders));

      // Notify SketchUp about the removed custom column
      // sketchup.removeCustomColumn(colKey);
    },

    onCheckboxChange() {
      this.updateCheckAllColumns();
    },

    checkAllColumns(isChecked) {
      this.filteredColumns.forEach((colKey) => {
        this.columnStates[colKey] = isChecked;
      });
      this.updateCheckAllColumns();
    },

    updateCheckAllColumns() {
      const allChecked = this.filteredColumns.every(
        (colKey) => this.columnStates[colKey]
      );
      this.isCheckedAll = allChecked;

      // Check if all columns are hidden (none selected)
      this.columnsHidden = this.filteredColumns.every(
        (colKey) => !this.columnStates[colKey] // True if all values are false
      );

      this.saveColumnStatesToLocalStorage();
      loadLanguage(this);
    },

    saveColumnStatesToLocalStorage() {
      localStorage.setItem(columnStatesKey, JSON.stringify(this.columnStates));
    },

    removeThousandSeparator(numberString, thousandSeparator) {
      if (numberString === null || numberString === undefined) {
        numberString = '';
      } else {
        numberString = String(numberString);
      }
      return numberString.replace(new RegExp('\\' + thousandSeparator, 'g'), '');
    },

    resizeTable() {
      const table = this.$refs.myTable;
      const columns = Array.from(table.querySelectorAll('th'));
      columns.forEach((column, index) => {
        if (index === 0) return; // Do not resize first column

        // Create a div to contain resize arrow handle
        const resizeHandle = document.createElement('div');
        resizeHandle.classList.add('resize');
        column.appendChild(resizeHandle);

        let isResizing = false;
        let startX = 0;
        let startWidth = 0;

        resizeHandle.addEventListener('mousedown', (e) => {
          isResizing = true;
          startX = e.pageX;
          startWidth = parseInt(getComputedStyle(column).width, 10);
        });

        document.addEventListener('mousemove', (e) => {
          if (!isResizing) return;
          const width = startWidth + (e.pageX - startX);
          column.style.width = `${width}px`;
        });

        document.addEventListener('mouseup', () => {
          isResizing = false;
        });
      });
    },

    resetAll() {
      // Create an object to track localStorage keys that need to be removed
      const localStorageKeys = {};

      // Get all keys from localStorage
      const allKeys = Object.keys(localStorage);

      // Filter out keys that contain 'extensionName' but exclude those with 'language'
      const filteredKeys = allKeys.filter(
        (key) => key.includes(extensionName) && !key.includes('language')
      );

      // Mark these filtered keys for removal
      filteredKeys.forEach((key) => {
        localStorageKeys[key] = true;
      });

      // Remove each key from localStorage
      Object.keys(localStorageKeys).forEach((key) => {
        localStorage.removeItem(key);
      });

      // Show a modal after clearing the localStorage keys
      const message = this.translated('noticeDefaultMessage');
      this.showMessageModal(message, 'reset', 2000);

      // Call the reset function from the 'sketchup' object
      sketchup.resetAll();
    },

    handlePresetButtonClick(event) {
      this.editingPresets = false;
    },

    selectPreset(preset) {
      // Reset required saved headers
      this.requiredSavedHeaders = [];

      // Call Sketchup action
      sketchup.selectPreset(preset);

      // Update current preset
      this.currentPreset = preset;

      // Save to last preset
      localStorage.setItem(lastPresetKey, this.currentPreset);

      this.columnsHidden = false; // Reset columns hidden
    },

    importPresets() {
      this.modalTitle = 'confirmation';
      this.modalAction1 = {
        text: 'no',
        action: () => this.importPresetsSketchup('no')
      };
      this.modalAction2 = {
        text: 'yes',
        action: () => this.importPresetsSketchup('yes'),
      };
      this.modalMessage = 'importPresetsMessage';
      this.showModal('#actionModal', 'wait');
    },

    importPresetsSketchup(value) {
      if (value === 'yes') {
        sketchup.importPresets();
      }

      this.editingPresets = false;
    },

    exportPresets() {
      sketchup.exportPresets();
    },

    resetPresets() {
      this.modalTitle = 'confirmation';
      this.modalAction1 = {
        text: 'no',
        action: () => this.resetPresetsSketchup('no')
      };
      this.modalAction2 = {
        text: 'yes',
        action: () => this.resetPresetsSketchup('yes'),
      };
      this.modalMessage = 'resetPresetsMessage';
      this.showModal('#actionModal', 'wait');
    },

    resetPresetsSketchup(value) {
      if (value === 'yes') {
        sketchup.resetPresets();
      }
      this.currentPreset = 'Default Preset';
      this.editingPresets = false;
    },

    editPresets() {
      this.editingPresets = true;
    },

    updateDropdownPosition() {
      const menu = this.$refs.dropdownMenu;
      if (!menu) return;

      const currentTransform = menu.style.transform;
      const match = currentTransform.match(/translate3d\((-?\d+\.?\d*)px, (-?\d+\.?\d*)px, (-?\d+\.?\d*)px\)/);
      // console.log('match', match);
      let currentX = 0;
      let currentY = 0;
      if (match) {
        currentX = parseFloat(match[1]);
        currentY = parseFloat(match[2]);
      }

      const rect = menu.getBoundingClientRect();
      const desiredRight = window.innerWidth - 53;
      const overflowAmount = rect.right - desiredRight;
      if (overflowAmount > 0) {
        const newX = currentX - overflowAmount;
        menu.style.transform = `translate3d(${newX}px, ${currentY}px, 0px)`;
      } else {
        menu.style.transform = currentTransform;
      }
    },

    closePresets() {
      this.editingPresets = false;
    },

    addPreset() {
      // console.log('addPreset');
      const presetInput = document.getElementById('presetInput');
      const presetText = presetInput.value === '' ? 'New Preset' : presetInput.value
      this.presetsList.push(presetText);

      this.savePreset(presetText);

      presetInput.value = ''; // Clear input field

      const message = this.translated('newPresetMessage');
      this.showMessageModal(message, 'info');
    },

    deletePreset(preset) {
      this.presetsList = this.presetsList.filter((item) => item !== preset);

      sketchup.deletePreset(preset);

      if (preset === this.currentPreset) {
        this.currentPreset = this.presetsList[0]; // Set to first preset in the list
      }

      // Save to last preset
      localStorage.setItem(lastPresetKey, this.presetsList[0]);

      // Show modal
      const message = this.translated('deletePresetMessage');
      this.showMessageModal(message, 'error');
    },

    renamePreset(oldName, newName) {
      const idx = this.presetsList.indexOf(oldName);
      if (idx === -1) return;

      this.$set(this.presetsList, idx, newName);

      if (this.currentPreset === oldName) {
        this.currentPreset = newName;
        localStorage.setItem(lastPresetKey, newName);
      }

      sketchup.renamePreset(oldName, newName);
    },

    updatePreset(preset) {
      // Update by save override
      this.savePreset(preset);

      // Show modal
      const message = this.translated('updatePresetMessage');
      this.showMessageModal(message, 'reset');
    },

    savePreset(preset) {
      const checkboxStates = localStorage.getItem(columnStatesKey)
      const modifiedHeaders = this.collectUserHeaders();
      const columnOrder = localStorage.getItem(columnOrdersKey);
      const sortColumn = localStorage.getItem(sortColumnKey);
      const sortOrder = localStorage.getItem(sortOrderKey);
      const currency = localStorage.getItem(currencyKey);
      const language = localStorage.getItem(languageKey);
      this.presetLanguage = this.language;

      // Create data
      const data = {
        columns: JSON.parse(checkboxStates),
        customColumns: this.collectCustomColumns(),
        headers: modifiedHeaders,
        order: JSON.parse(columnOrder),
        sortColumn: sortColumn,
        sortOrder: JSON.parse(sortOrder),
        currency: currency,
        language: language
      };

      sketchup.savePreset(preset, data);
      this.requiredSavedHeaders = []; // Mark preset is saved
    },

    collectUserHeaders() {
      const result = {};
      const table = document.getElementById('myTable');
      if (!table) {
        console.warn(`Table element with id='myTable' not found.`);
        return result;
      }

      const headers = table.querySelectorAll('th');
      headers.forEach((th) => {
        const colId = th.id;
        const colText = th.textContent.trim();

        if (colId) {
          result[colId] = colText;
        }
      });

      return result;
    },

    collectCustomColumns() {
      const extraRow = document.getElementById('extra');
      const extraCustomColumns = extraRow.querySelectorAll('td[id*="dynamicAttribute"], td[id*="customAttribute"]');

      const customColumns = {}
      extraCustomColumns.forEach((td) => {
        const colId = td.id.split('-')[1]; // Get the column key from the id

        // For customAttribute columns, preserve the full {dictionary, attribute} object
        const savedInfo = this.customColumns && this.customColumns[colId];
        if (colId && colId.includes('customAttribute') && savedInfo !== null && typeof savedInfo === 'object') {
          customColumns[colId] = savedInfo;
        } else {
          const colText = td.textContent.trim();
          if (colId) customColumns[colId] = colText;
        }
      });

      return customColumns;
    },

    // HANDLE SEARCH
    performSearch() {
      this.showReplaceInput = this.findText.trim() !== '';

      if (!this.findText) {
        this.resetSearch(); // Reset if input is empty
        return;
      }

      const regex = new RegExp('(' + this.escapeRegExp(this.findText) + ')', 'gi');

      this.groupedObjects.forEach((row) => {
        let rowVisible = false;

        // Iterate through visible columns
        Object.keys(row).forEach((colKey) => {
          if (!this.columnStates[colKey] || ['ordinal', 'image'].includes(colKey)) return; // Ignore hidden column and image

          let cellText = row[colKey]?.toString() || '';
          const originalText = this.removeHighlight(cellText); // Remove old highlight

          if (originalText.toLowerCase().includes(this.findText.toLowerCase())) {
            rowVisible = true;

            // Store highlighted text separately
            if (!row.highlightedText) {
              row.highlightedText = {};
            }

            row.highlightedText[colKey] = originalText.replace(
              regex,
              "<span class='search-highlight'>$1</span>"
            );

            this.isHighlighted = true;
          } else {
            if (row.highlightedText) {
              row.highlightedText[colKey] = originalText; // Reset highlight if not matching
            }
          }
        });

        // Hide rows if not contain find text
        row.isHidden = !rowVisible;
      });
    },

    performReplace() {
      if (!this.findText || !this.replaceText) return; // Ignore if not enough data

      const regex = new RegExp(this.escapeRegExp(this.findText), 'gi');
      let replacedText;

      this.groupedObjects.forEach((row) => {
        if (row.isHidden) return; // Ignore rows are hidden

        Object.keys(row).forEach((colKey) => {
          if (!this.columnStates[colKey] ||
            [
              'ordinal',
              'entity',
              'image',
              'tag',
              'material',
              'ifc',
              'dynamic'
            ].includes(colKey)) {
            this.resetSearch(); // Reset search if trying to replace in hidden column or non-editable column
            return; // Ignore hidden column and image
          }

          let cellText = row[colKey]?.toString() || '';
          const originalText = this.removeHighlight(cellText); // Delete highlight if exists

          if (originalText.includes(this.findText)) {
            replacedText = originalText.replace(regex, this.replaceText);
            row[colKey] = replacedText;

            sketchup.changeValue(row.id, colKey, replacedText); // Update SketchUp value

            // Clear search highlight
            this.resetSearch();
          }
        });
      });
    },

    resetSearch() { // Delete highlight and display all rows
      // console.log('resetSearch');
      this.findText = '';
      this.showReplaceInput = false;
      this.isHighlighted = false;
      this.columnSearchQuery = '';
      this.itemSearchQuery = '';
      this.dynamicSearchQuery = '';

      this.groupedObjects.forEach((row) => {
        row.isHidden = false;
      });
    },

    escapeRegExp(string) {
      return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    },

    removeHighlight(text) {
      return text.replace(/<span class='search-highlight'>(.*?)<\/span>/gi, "$1");
    },

    translated(key, isHeader = false) {
      // Only keep origin header if it is edited and required to save
      // Or the current language is the preset language
      if (this.requiredSavedHeaders.includes(key) ||
          (this.language === this.presetLanguage &&
          this.modifiedHeaders[key])) {
          return this.modifiedHeaders[key];
      } else {
        return this.languageData[key] || key;
      }
    },

    // HANDLE EDIT HEADERS
    startEditingHeader(colKey) {
      this.editingHeader = colKey;
      if (colKey.includes('dynamicAttribute')) {
        const header = document.getElementById(colKey);
        const headerText = header.textContent.trim();
        this.editedHeaderText = headerText === this.translated('dynamic') ? this.translated('dynamic') : headerText;
      } else if (colKey.includes('customAttribute')) {
        const header = document.getElementById(colKey);
        const headerText = header.textContent.trim();
        this.editedHeaderText = headerText === this.translated('custom') ? this.translated('custom') : headerText;
      } else {
        this.editedHeaderText = this.translated(colKey);
      }
      this.$nextTick(() => {
        const inputRef = this.$refs[`headerInput-${colKey}`];
        const inputElement = Array.isArray(inputRef) ? inputRef[0] : inputRef;
        if (inputElement) {
          inputElement.focus();
          inputElement.select();
        }
      });
    },

    saveHeaderEdit(colKey) {
      const header = document.getElementById(colKey);
      const headerText = header.textContent.trim();

      if (this.editedHeaderText.trim() !== '') {
        this.modifiedHeaders[colKey] = this.editedHeaderText;
      }
      this.editingHeader = null;

      // Only save if header text is changed
      if (this.editedHeaderText.trim() !== headerText) {
        this.requiredSavedHeaders.push(colKey);
      }

      handleTooltip(this);
    },

    cancelHeaderEdit() {
      this.editingHeader = null;
    },

    handleHeaderKeydown(event, colKey) {
      if (event.key === 'Enter') {
        this.saveHeaderEdit(colKey);
      } else if (event.key === 'Escape') {
        this.cancelHeaderEdit();
      }
    },

    // HANDLE EDIT CELLS
    startEditingCell(event, row, colKey) {
      const editableTypes = [
        'image',
        'definition',
        'instance',
        'description',
        'ifc',
        'tag',
        'material',
        'status',
        'owner',
        'url',
        'size',
        'price',
        'dynamic'
      ]

      if (!editableTypes.includes(colKey) && !colKey.includes('customAttribute') && colKey !== 'dynamic' && !colKey.includes('dynamicAttribute')) {
        const message = this.translated('noticeEditableMessage');
        this.showMessageModal(message, 'reset');
        return;
      }

      // For dynamic/dynamicAttribute columns, check access type
      if (colKey === 'dynamic' || colKey.includes('dynamicAttribute')) {
        const label = colKey === 'dynamic'
          ? this.dynamicAttribute
          : (this.customColumns[colKey] || '');

        const accessInfo = this.dynamicAccessInfo[label];

        if (!accessInfo) {
          const message = this.translated('noticeEditableMessage');
          this.showMessageModal(message, 'reset');
          return;
        }

        this.editingDynamicType = accessInfo.access;
        this.editingDynamicOptions = accessInfo.options || {};
        this.editingDynamicUnits = accessInfo.units || '';
      } else {
        this.editingDynamicType = null;
        this.editingDynamicOptions = {};
        this.editingDynamicUnits = '';
      }

      this.editingCell = `${row.id}-${colKey}`;
      this.originalCellValue = String(row[colKey] ?? '');

      // For LIST type, row stores the display label but <select> binds to stored values.
      // Convert display label → stored value so the correct option is pre-selected.
      if (this.editingDynamicType === 'LIST') {
        const displayLabel = String(row[colKey] ?? '');
        this.editedCellValue = this.editingDynamicOptions[displayLabel] ?? displayLabel;
      } else {
        this.editedCellValue = String(row[colKey] ?? '');
      }

      this.selectedItem = colKey;

      this.$nextTick(() => {
        if (['tag', 'material', 'ifc'].includes(colKey)) {
          const ref = this.$refs[`itemEditor-${row.id}-${colKey}`][0];
          if (ref) ref.focus();

          this.positionFloatingMenu(event.currentTarget);
        }
        const inputRefs = this.$refs[`cellInput-${row.id}-${colKey}`];
        if (Array.isArray(inputRefs)) inputRefs[0].focus();
        else inputRefs?.focus();

        const textAreaRefs = this.$refs[`cellTextArea-${row.id}-${colKey}`];
        if (Array.isArray(textAreaRefs)) {
          textAreaRefs[0].focus();
          this.resizeTextarea(textAreaRefs[0]);
        }
      });
    },

    saveCellEdit(row, colKey) {
      // console.log('saveCellEdit', row, colKey);
      if (this.isSaved) return;
      this.isSaved = true;

      const originalText = this.originalCellValue?.trim() || '';
      const editText = String(this.editedCellValue ?? '').trim();

      // Accept value === '' if key === 'image' to clear image.src
      if ((editText !== '' && editText !== originalText && colKey === 'definition') || colKey !== 'definition') {
        row[colKey] = this.editedCellValue;

        // Update the cell value
        // this.updateObjects(row.id, colKey, this.editedCellValue);
        sketchup.changeValue(row.id, colKey, this.editedCellValue);
      }
      this.editingCell = null;

      this.$nextTick(() => {
        this.isSaved = false;
      });
    },

    updateObjects(rowId, colKey, value) {
      const objectIndex = this.objects.findIndex(obj => obj.id === rowId);
      if (objectIndex !== -1) {
        this.$set(this.objects, objectIndex, {
          ...this.objects[objectIndex],
          [colKey]: value
        });
      }
    },

    cancelCellEdit() {
      this.editingCell = null;
      this.isSaved = false;
      this.itemSearchQuery = ''; // Clear search query when focus out
    },

    handleCellEvent(event, row, colKey) {
      if (event.type === 'keydown' && event.key === 'Enter') {
        // Save when press only Enter
        if (!event.shiftKey && !event.altKey && !event.ctrlKey && !event.metaKey) {
          event.preventDefault();
          this.saveCellEdit(row, colKey);
        }
      } else if (event.type === 'blur') {
        this.saveCellEdit(row, colKey);
      } else if (event.type === 'keydown' && event.key === 'Escape') {
        this.cancelCellEdit();
      }
    },

    resizeTextarea(textArea) {
      textArea.style.height = 'auto';
      textArea.style.height = textArea.scrollHeight+'px';
    },

    // HANDLE EDIT DYNAMIC COMPONENTS
    editDynamic(target) {
      if (this.filteredDynamicAttributes.length === 0) {
        const message = this.translated('noticeDynamicMessage');
        this.showMessageModal(message, 'info', 2000);
        return;
      }

      const cell = target.closest('td');
      if (cell) {
        this.editingColKey = cell.id.replace('extra-', ''); // Get colKey from id
      }

      this.editingExtra = true;

      this.$nextTick(() => {
        const inputRef = this.$refs['dynamicInput'];
        const inputElement = Array.isArray(inputRef) ? inputRef[0] : inputRef;
        if (inputElement) {
          inputElement.focus();
        }

        // Adjust list-container position to prevent overflow beyond right edge
        if (cell) {
          const listContainer = cell.querySelector('.list-container');
          if (listContainer) {
            listContainer.style.transform = '';
            const rect = listContainer.getBoundingClientRect();
            const overflow = rect.right - (window.innerWidth - 20);
            if (overflow > 0) {
              listContainer.style.transform = `translateX(-${overflow}px)`;
            }
          }
        }
      });
    },

    selectDynamicAttribute(colKey, attr) {
      // console.log('selectDynamicAttribute', colKey, attr);
      if (this.editingColKey === 'dynamic') {
        this.dynamicAttribute = attr;
        sketchup.recentDynamicKey(attr);
      } else {
        this.customColumns[colKey] = attr;
        sketchup.customDynamicAttribute(colKey, attr);
      }
      this.cancelEditDynamic();
    },

    cancelEditDynamic() {
      this.editingExtra = false;
    },

    handleItemClick(item, rowId, colKey) {
      // console.log('Clicked item:', item, rowId, colKey); // Debug check
      if (item === this.translated('notFound')) return;

      this.selectItem(rowId, colKey, item);
    },

    selectItem(rowId, colKey, item) {
      sketchup.changeValue(rowId, colKey, item);
      // Update edited value
      this.updateObjects(rowId, colKey, item);
      this.cancelCellEdit(); // Close cell edit if open
    },

    handleFocusIn() {
      if (this.cancelEditTimeout) clearTimeout(this.cancelEditTimeout);
    },

    handleFocusOut() {
      this.cancelEditTimeout = setTimeout(this.cancelCellEdit, 100);
    },

    // Collapse/Expand table
    toggleColumns() {
      const table = this.$refs.myTable;
      this.$nextTick(() => {
        const dropdownMenu = document.getElementById('checkList');

        if (!dropdownMenu) return;
      
        const dropdownWidth = dropdownMenu.offsetWidth;
        // console.log('dropdownWidth', dropdownWidth);
        const safePadding = 8;
        const totalOffset = dropdownWidth + safePadding;
      
        if (table.classList.contains('columns-open')) {
          table.classList.remove('columns-open');
          table.style.marginLeft = '0px';
        } else {
          table.classList.add('columns-open');
          table.style.transform = `translateX(${totalOffset}px)`;
        }
      });
    },

    positionFloatingMenu(triggerElement) {
      // console.log('positionFloatingMenu', triggerElement);
      if (!triggerElement) return;

      // Get bounding boxes
      const triggerRect = triggerElement.getBoundingClientRect();
      const viewportWidth = window.innerWidth;
      const viewportHeight = window.innerHeight;

      const menuElement = document.getElementById('itemsList');
      const menuWidth = menuElement.offsetWidth;
      const menuHeight = menuElement.offsetHeight;

      // Default position below trigger
      let left = triggerRect.left + window.scrollX;

      const spaceBelow = viewportHeight - triggerRect.bottom - 10;
      const spaceAbove = triggerRect.top - 10;

      // If not enough space below and space above is more, place above
      if (spaceBelow < menuHeight && spaceAbove > spaceBelow) {
        top = triggerRect.top + window.scrollY - menuHeight;
      }

      if (triggerRect.left + menuWidth + 40 > viewportWidth) {
        left = viewportWidth - (triggerRect.left + menuWidth + 30);
        menuElement.style.left = `${left}px`;
      }

      // Limit height if needed
      const availableHeight = (top > triggerRect.bottom)
        ? triggerRect.top - 70
        : viewportHeight - triggerRect.bottom - 70;

      menuElement.style.maxHeight = availableHeight < 45 ? '45px' : `${availableHeight}px`;
      menuElement.style.overflowY = 'auto';
      menuElement.style.visibility = 'visible';
    },

    imagesFolder() {
      sketchup.imagesFolder();
    },

    updateAllImagesConfirm() {
      this.modalTitle = 'confirmation';
      this.modalAction1 = {
        text: 'no',
        action: () => {}
      };
      this.modalAction2 = {
        text: 'yes',
        action: () => this.updateImages('yes'),
      };
      this.modalMessage = 'updateAllImagesMessage';
      this.showModal('#actionModal', 'wait');
    },

    updateImages() {
      sketchup.updateImages();
      const message = this.translated('waitAllImagesMessage');
      this.showMessageModal(message, 'processing');
    },

    cancelUpdateImages() {
      hideAllModals();
    },

    cancelProcessing() {
      hideAllModals();
    },

    // ─── Data Bridge ─────────────────────────────────────────────────────────

    showDataBridgeModal() {
      $("#dataBridgeModal").modal("show");
    },

    updateDataBridgePreview(data) {
      const modal = this._getDataBridgeModal();
      if (modal) modal.receivePreview(data);
    },

    dataBridgeApplied(result) {
      const modal = this._getDataBridgeModal();
      if (modal) modal.onApplied(result);
    },

    _getDataBridgeModal() {
      return this.$children.find(
        (c) => c.$el && c.$el.id === "dataBridgeModal"
      );
    },
  },
});

function updateData(data) {
  document.getElementById('app').__vue__.updateData(data);
}

function setCurrentPreset(data) {
  document.getElementById('app').__vue__.setCurrentPreset(data);
}

function updatePresetHeaders(data) {
  document.getElementById('app').__vue__.updatePresetHeaders(data);
}

function updatePresetSettings(data) {
  document.getElementById('app').__vue__.updatePresetSettings(data);
}

function updatePresetList(data) {
  document.getElementById('app').__vue__.updatePresetList(data);
}

function updateFolderPath(data, notice) {
  document.getElementById('app').__vue__.updateFolderPath(data, notice);
}

function noticeNewVersion(data) {
  document.getElementById('app').__vue__.noticeNewVersion(data);
}

function disableButtons(data) {
  document.getElementById('app').__vue__.disableButtons(data);
}

function displayMessageText(data) {
  document.getElementById('app').__vue__.displayMessageText(data);
}

function showNoticeModal(message) {
  app.showNoticeModal(message);
}

function importNotice() {
  const message = app.translated('importNoticeMessage');
  app.showMessageModal(message, 'info');
}

function importFailed() {
  const message = app.translated('importFailedMessage');
  app.showMessageModal(message, 'reset');
}

function exportNotice() {
  const message = app.translated('exportNoticeMessage');
  app.showMessageModal(message, 'info');
}

function exportFailed() {
  const message = app.translated('exportFailedMessage');
  app.showMessageModal(message, 'reset');
}

function updateDataBridgePreview(data) {
  document.getElementById('app').__vue__.updateDataBridgePreview(data);
}

function dataBridgeApplied(result) {
  document.getElementById('app').__vue__.dataBridgeApplied(result);
}

function receiveLastBridgeFile(path) {
  document.getElementById('app').__vue__._getDataBridgeModal().receiveLastBridgeFile(path);
}

function showModal(id, delay = 1500) {
  $(id).modal('show');
  setTimeout(function() {
    $(id).modal('hide');
  }, delay);
}

/**
 * Get text from cell with automatic line breaks detection
 * Detects where text wraps on UI and inserts \n at those positions
 */
function getTextWithLineBreaks(cell) {
  // If cell has image or badge, use simple innerText
  if (cell.querySelector('img') || cell.querySelector('.badge')) {
    return cell.innerText.trim();
  }

  const text = cell.innerText.trim();

  // If text is short or already has line breaks, return as is
  if (text.length < 20 || text.includes('\n')) {
    return text;
  }

  // Check if cell has word-wrap enabled
  const style = window.getComputedStyle(cell);
  const hasWrap = style.whiteSpace !== 'nowrap';

  if (!hasWrap) {
    return text;
  }

  try {
    // Create a temporary span to measure each word
    const tempSpan = document.createElement('span');
    tempSpan.style.visibility = 'hidden';
    tempSpan.style.position = 'absolute';
    tempSpan.style.whiteSpace = 'nowrap';
    tempSpan.style.font = style.font;
    tempSpan.style.fontSize = style.fontSize;
    tempSpan.style.fontWeight = style.fontWeight;
    tempSpan.style.fontFamily = style.fontFamily;
    tempSpan.style.letterSpacing = style.letterSpacing;
    document.body.appendChild(tempSpan);

    const cellWidth = cell.offsetWidth;
    const cellPaddingLeft = parseFloat(style.paddingLeft);
    const cellPaddingRight = parseFloat(style.paddingRight);
    const availableWidth = cellWidth - cellPaddingLeft - cellPaddingRight;

    const words = text.split(/\s+/);
    let result = '';
    let currentLine = '';

    words.forEach((word, index) => {
      const testLine = currentLine ? currentLine + ' ' + word : word;
      tempSpan.textContent = testLine;
      const lineWidth = tempSpan.offsetWidth;

      if (lineWidth > availableWidth && currentLine) {
        // Line would overflow, add line break
        result += currentLine + '\n';
        currentLine = word;
      } else {
        currentLine = testLine;
      }

      // Add last word
      if (index === words.length - 1) {
        result += currentLine;
      }
    });

    document.body.removeChild(tempSpan);
    return result;
  } catch (e) {
    // If any error occurs, fallback to simple innerText
    return text;
  }
}

function drawTable() {
  const table = document.getElementById('myTable');
  if (!table) {
    alert('Table not found!');
    return;
  }

  let tableData = [];

  for (let row of table.rows) {
    if (row.style.display === 'none') continue;

    let rowHeight = row.offsetHeight;
    let cells = [];

    for (let cell of row.cells) {
      if (cell.style.display === 'none') continue;

      // Temporarily clear modus-icons text (e.g. caret_down, caret_right) so they
      // are not included in the cell text sent to Ruby
      const iconEls = cell.querySelectorAll('i.modus-icons, .modus-icons');
      const iconTexts = [];
      iconEls.forEach(el => { iconTexts.push(el.textContent); el.textContent = ''; });

      // Get text with automatic line break detection
      let text = getTextWithLineBreaks(cell);

      // Restore icon text
      iconEls.forEach((el, i) => { el.textContent = iconTexts[i]; });

      let img = cell.querySelector('img') ? cell.querySelector('img').src : null;
      if (img) {
        img = decodeURIComponent(img); // Remove special characters (%20, %5C, ...)
      }
      let cellWidth = cell.offsetWidth;
      let computedStyle = window.getComputedStyle(cell);
      let textAlign = computedStyle.textAlign;

      // Check if text is bold
      let fontWeight = computedStyle.fontWeight;
      let isBold = fontWeight === 'bold' || parseInt(fontWeight) >= 700;

      // Check if cell is header
      let isHeader = cell.tagName === 'TH';

      cells.push({
        text: text, // Text with automatic \n insertion at wrap points
        align: textAlign,
        img: img,
        cellWidth: cellWidth,
        bold: isBold,
        isHeader: isHeader
      });
    }
    tableData.push({ rowHeight: rowHeight, cells: cells });
  }
  // console.log(tableData);
  sketchup.drawTable(tableData);
}

$('#supportModal').on('shown.bs.modal', function () {
  const languageOption = localStorage.getItem(languageKey) || 'en-US';
  // console.log('languageOption', languageOption);
  if (languageOption !== 'vi-VN') {
    $('#supportSecondTab').tab('show');
  } else {
    $('#supportFirstTab').tab('show');
  }
});

