Vue.component("data-bridge-modal", {
  data() {
    return {
      step: 1,               // 1 | 2 | 3
      // File parsing state
      fileData: [],
      fileHeaders: [],
      jsonArrayPath: "",
      jsonArrayKeys: [],
      fileName: "",
      _pendingJson: null,
      // Import config state
      matchField: "",
      matchBy: "definition", // 'definition' | 'instance' | 'attribute'
      attrDict: "",
      attrKey: "",
      scope: "all",          // 'all' | 'selection'
      // Preview state
      previewRows: [],
      isLoading: false,
      // Column mapping state
      // columnMapping: { fileHeader: { type: ''|'known'|'customAttribute', key: '', dict: '5D+', attrName: '' } }
      columnMapping: {},
      // Recent file
      lastFilePath: "",
    };
  },

  mounted() {
    $("#dataBridgeModal").on("show.bs.modal", () => {
      this.resetImport();
      sketchup.getLastBridgeFile();
    });
  },

  beforeDestroy() {
    $("#dataBridgeModal").off("show.bs.modal");
  },

  computed: {
    matchedCount() {
      return this.previewRows.filter((r) => r.matched).length;
    },

    unmatchedCount() {
      return this.previewRows.filter((r) => !r.matched).length;
    },

    // All field keys present in the preview changes (union across all rows)
    previewFieldKeys() {
      const all = new Set();
      this.previewRows.forEach((row) => {
        Object.keys(row.changes || {}).forEach((k) => all.add(k));
      });
      return Array.from(all);
    },

    // Writable internal column keys available for mapping
    knownColumns() {
      return [
        'definition', 'instance', 'description', 'tag', 'material',
        'ifc', 'status', 'owner', 'url', 'size', 'price', 'image',
      ];
    },

    // File headers that are NOT the matchField
    mappableHeaders() {
      return this.fileHeaders.filter((h) => h !== this.matchField);
    },

    lastFileBaseName() {
      if (!this.lastFilePath) return "";
      return this.lastFilePath.replace(/\\/g, "/").split("/").pop();
    },
  },

  watch: {
    matchField() {
      this.initColumnMapping();
    },
  },

  methods: {
    // File parsing

    handleFileChange(e) {
      const file = e.target.files[0];
      if (!file) return;
      this.fileName = file.name;
      // Save path for next session (file.path available in SketchUp's CEF, otherwise falls back to name)
      const filePath = file.path || file.name;
      sketchup.saveLastBridgeFile(filePath);
      this.lastFilePath = filePath;
      this.fileData = [];
      this.fileHeaders = [];
      this.jsonArrayPath = "";
      this.jsonArrayKeys = [];
      this._pendingJson = null;

      const ext = file.name.split(".").pop().toLowerCase();
      if (ext === "json") {
        this.readJson(file);
      } else if (ext === "csv") {
        this.readCsv(file);
      } else if (ext === "xlsx" || ext === "xls") {
        this.readXlsx(file);
      } else {
        this.$root.showMessageModal(
          this.$root.translated("dataBridgeUnsupportedFile"),
          "error"
        );
      }
    },

    readJson(file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        try {
          const parsed = JSON.parse(e.target.result);
          if (Array.isArray(parsed)) {
            this.setFileData(parsed);
          } else if (typeof parsed === "object" && parsed !== null) {
            const arrayKeys = Object.keys(parsed).filter((k) =>
              Array.isArray(parsed[k])
            );
            if (arrayKeys.length === 0) {
              // Treat the single object as a one-row array
              this.setFileData([parsed]);
            } else if (arrayKeys.length === 1) {
              this.jsonArrayPath = arrayKeys[0];
              this.setFileData(parsed[arrayKeys[0]]);
            } else {
              // Multiple arrays — ask the user which one to use
              this.jsonArrayKeys = arrayKeys;
              this._pendingJson = parsed;
            }
          }
        } catch (err) {
          this.$root.showMessageModal(
            this.$root.translated("dataBridgeInvalidJson"),
            "error"
          );
        }
      };
      reader.readAsText(file, "UTF-8");
    },

    selectJsonArrayPath(key) {
      this.jsonArrayPath = key;
      this.jsonArrayKeys = [];
      this.setFileData(this._pendingJson[key]);
      this._pendingJson = null;
    },

    readCsv(file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const rows = this.parseCsv(e.target.result);
        if (!rows.length) {
          this.$root.showMessageModal(
            this.$root.translated("dataBridgeEmptyFile"),
            "error"
          );
          return;
        }
        this.setFileData(rows);
      };
      reader.readAsText(file, "UTF-8");
    },

    parseCsv(text) {
      const lines = text
        .replace(/\r\n/g, "\n")
        .replace(/\r/g, "\n")
        .split("\n")
        .filter((l) => l.trim());
      if (lines.length < 2) return [];
      const headers = this.parseCsvLine(lines[0]);
      const rows = [];
      for (let i = 1; i < lines.length; i++) {
        const vals = this.parseCsvLine(lines[i]);
        if (!vals.length) continue;
        const row = {};
        headers.forEach((h, idx) => {
          row[h] = vals[idx] !== undefined ? vals[idx] : "";
        });
        rows.push(row);
      }
      return rows;
    },

    parseCsvLine(line) {
      const result = [];
      let current = "";
      let inQuotes = false;
      for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '"') {
          if (inQuotes && line[i + 1] === '"') {
            current += '"';
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (ch === "," && !inQuotes) {
          result.push(current.trim());
          current = "";
        } else {
          current += ch;
        }
      }
      result.push(current.trim());
      return result;
    },

    readXlsx(file) {
      const reader = new FileReader();
      reader.onload = async (e) => {
        try {
          const workbook = new ExcelJS.Workbook();
          await workbook.xlsx.load(e.target.result);
          const sheet = workbook.worksheets[0];
          if (!sheet) {
            this.$root.showMessageModal(
              this.$root.translated("dataBridgeEmptyFile"),
              "error"
            );
            return;
          }
          const rows = [];
          let headers = [];
          sheet.eachRow((row, rowNumber) => {
            // ExcelJS: row.values[0] is always null (1-indexed)
            const values = row.values.slice(1);
            if (rowNumber === 1) {
              headers = values.map((v) => (v != null ? String(v).trim() : ""));
            } else {
              const rowObj = {};
              headers.forEach((h, idx) => {
                rowObj[h] = values[idx] != null ? String(values[idx]) : "";
              });
              rows.push(rowObj);
            }
          });
          if (!rows.length) {
            this.$root.showMessageModal(
              this.$root.translated("dataBridgeEmptyFile"),
              "error"
            );
            return;
          }
          this.setFileData(rows);
        } catch (err) {
          this.$root.showMessageModal(
            this.$root.translated("dataBridgeReadError"),
            "error"
          );
        }
      };
      reader.readAsArrayBuffer(file);
    },

    setFileData(rows) {
      if (!rows || rows.length === 0) return;
      this.fileData = rows;
      this.fileHeaders = Object.keys(rows[0] || {});
      this.matchField = this.fileHeaders[0] || "";
    },

    // Step navigation

    initColumnMapping() {
      const known = this.knownColumns;
      const mapping = {};
      this.fileHeaders.forEach((h) => {
        if (h === this.matchField) return;
        if (known.includes(h)) {
          mapping[h] = { type: 'known', key: h, dict: '5D+', attrName: h };
        } else {
          mapping[h] = { type: '', key: '', dict: '5D+', attrName: h };
        }
      });
      this.columnMapping = mapping;
    },

    goToStep2() {
      if (!this.fileData.length) return;
      this.initColumnMapping();
      this.step = 2;
    },

    previewMatch() {
      if (!this.matchField) return;
      this.isLoading = true;
      // Serialize columnMapping into a flat structure for Ruby:
      // { fileHeader => { type, key, dict, attrName } }
      sketchup.previewDataBridge({
        fileData: this.fileData,
        matchField: this.matchField,
        matchBy: this.matchBy,
        attrDict: this.attrDict,
        attrKey: this.attrKey,
        scope: this.scope,
        columnMapping: this.columnMapping,
      });
    },

    receivePreview(rows) {
      this.previewRows = rows.map((r) => {
        const checkedFields = {};
        Object.keys(r.changes || {}).forEach((k) => {
          checkedFields[k] = true;
        });
        return Object.assign({}, r, { checkedFields });
      });
      this.isLoading = false;
      this.step = 3;
    },

    applyChanges() {
      const changes = [];
      this.previewRows.forEach((row) => {
        if (!row.matched || !row.entityId) return;
        Object.keys(row.changes).forEach((key) => {
          if (row.checkedFields[key]) {
            const change = row.changes[key];
            changes.push({
              entityId: row.entityId,
              key,
              value: change.value,
              dict: change.dict || null,
              attrName: change.attrName || null,
            });
          }
        });
      });
      if (!changes.length) return;
      this.isLoading = true;
      sketchup.applyDataBridge(changes);
    },

    receiveLastBridgeFile(path) {
      this.lastFilePath = path || "";
    },

    onApplied(result) {
      this.isLoading = false;
      $("#dataBridgeModal").modal("hide");
      const msg = `${result.applied} / ${result.total} ${this.$root.translated(
        "dataBridgeAppliedMsg"
      )}`;
      this.$root.showMessageModal(msg, "success");
    },

    resetImport() {
      this.step = 1;
      this.fileData = [];
      this.fileHeaders = [];
      this.jsonArrayPath = "";
      this.jsonArrayKeys = [];
      this.fileName = "";
      this._pendingJson = null;
      this.previewRows = [];
      this.isLoading = false;
      this.columnMapping = {};
      this.attrDict = "";
      this.attrKey = "";
      // Note: lastFilePath is NOT reset — preserved across opens
    },
  },

  template: /*html*/ `
    <div class="modal fade" id="dataBridgeModal" tabindex="-1" role="dialog">
      <div
        class="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable"
        role="document"
        style="max-width: none !important;"
      >
        <div class="modal-content custom-modal">

          <!-- Header -->
          <div class="modal-header">
            <h5 class="modal-title">
              {{ $root.translated('dataBridge') }}
            </h5>
            <button
              type="button"
              data-dismiss="modal"
              aria-label="Close"
              class="btn btn-icon-only btn-text-dark">
              <i class="modus-icons">close</i>
            </button>
          </div>

          <div class="modal-body">
            <div>

              <!-- Step indicator -->
              <div class="d-flex align-items-center mb-3" style="gap:6px; flex-wrap:wrap;">
                <span :class="['badge', step >= 1 ? 'badge-primary' : 'badge-secondary']">1</span>
                {{ $root.translated('dataBridgeStepFile') }}
                <i class="modus-icons text-muted">chevron_right</i>
                <span :class="['badge', step >= 2 ? 'badge-primary' : 'badge-secondary']">2</span>
                {{ $root.translated('dataBridgeStepConfig') }}
                <i class="modus-icons text-muted">chevron_right</i>
                <span :class="['badge', step >= 3 ? 'badge-primary' : 'badge-secondary']">3</span>
                {{ $root.translated('dataBridgeStepPreview') }}
              </div>

              <!-- ── Step 1: File upload ── -->
              <div v-if="step === 1">
                <div class="d-flex align-items-center file-upload bg-gray-1 p-1 mb-3">
                  <label
                    class="btn btn-outline-dark bg-white mb-0 flex-shrink-0"
                    for="fileId"
                  >
                    {{ $root.translated('import') }}
                  </label>
                  <input
                    type="file"
                    @change="handleFileChange"
                    accept=".xlsx, .xls, .csv, .json"
                    id="fileId"
                  />
                  <span class="ml-1 mt-1">{{ fileName ? fileName : $root.translated('dataBridgeSelectFile') }}</span>
                </div>

                <!-- Last used file hint -->
                <div v-if="lastFilePath && !fileData.length" class="mb-2 d-flex align-items-center" style="gap:6px;">
                  <small class="text-muted">{{ $root.translated('lastUsedFile') }}:</small>
                  <span class="badge badge-light" :title="lastFilePath">{{ lastFileBaseName }}</span>
                </div>

                <!-- JSON array path chooser (appears when JSON has multiple array keys) -->
                <div v-if="jsonArrayKeys.length > 0" class="mb-3">
                  <label class="font-weight-bold">{{ $root.translated('selectArrayKey') }}</label>
                  <div class="list-group mt-1" style="overflow-y:auto;">
                    <button
                      v-for="key in jsonArrayKeys"
                      :key="key"
                      type="button"
                      class="list-group-item list-group-item-action"
                      @click="selectJsonArrayPath(key)"
                    >{{ key }}</button>
                  </div>
                </div>

                <!-- Parsed data preview -->
                <div v-if="fileData.length > 0 && jsonArrayKeys.length === 0">
                  <p class="text-muted small mb-1">
                    <strong>{{ fileData.length }}</strong> {{ $root.translated('rowsLoaded') }}
                    <span v-if="jsonArrayPath">
                      &nbsp;({{ $root.translated('from') }}: <strong>{{ jsonArrayPath }}</strong>)
                    </span>
                  </p>
                  <div style="overflow-x:auto; overflow-y:auto;">
                    <table class="table table-sm table-bordered mb-0">
                      <thead class="bg-gray-1">
                        <tr>
                          <th v-for="h in fileHeaders" :key="h">{{ h }}</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="(row, i) in fileData.slice(0, 5)" :key="i">
                          <td v-for="h in fileHeaders" :key="h">{{ row[h] }}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                  <p v-if="fileData.length > 5" class="text-muted small mt-1 mb-0">
                    ... {{ fileData.length - 5 }} more rows
                  </p>
                </div>
              </div>

              <!-- ── Step 2: Config ── -->
              <div v-if="step === 2">
                <div class="form-group">
                  <label class="font-weight-bold">{{ $root.translated('matchField') }}</label>
                  <select class="form-control custom-select" v-model="matchField">
                    <option v-for="h in fileHeaders" :key="h" :value="h">{{ h }}</option>
                  </select>
                  <small class="form-text text-muted">
                    {{ $root.translated('matchFieldHint') }}
                  </small>
                </div>

                <div class="form-group">
                  <label class="font-weight-bold">{{ $root.translated('matchBy') }}</label>
                  <select class="form-control custom-select" v-model="matchBy">
                    <option value="definition">{{ $root.translated('matchByDefinition') }}</option>

                    <option value="attribute">{{ $root.translated('matchByAttribute') }}</option>
                  </select>
                </div>

                <div v-if="matchBy === 'attribute'" class="row">
                  <div class="col">
                    <div class="form-group">
                      <label>{{ $root.translated('dictionaryName') }}</label>
                      <input
                        type="text"
                        class="form-control"
                        v-model="attrDict"
                        placeholder="e.g. SU_DefinitionSet"
                      />
                    </div>
                  </div>
                  <div class="col">
                    <div class="form-group">
                      <label>{{ $root.translated('attributeName') }}</label>
                      <input
                        type="text"
                        class="form-control"
                        v-model="attrKey"
                        placeholder="e.g. room_id"
                      />
                    </div>
                  </div>
                </div>

                <div class="form-group mb-0">
                  <label class="font-weight-bold">{{ $root.translated('dataBridgeScope') }}</label>
                  <div class="mt-1">
                    <div class="custom-control custom-radio custom-control-inline">
                      <input
                        type="radio"
                        id="scopeAll"
                        class="custom-control-input"
                        value="all"
                        v-model="scope"
                      />
                      <label class="custom-control-label" for="scopeAll">
                        {{ $root.translated('scopeAll') }}
                      </label>
                    </div>
                    <div class="custom-control custom-radio custom-control-inline">
                      <input
                        type="radio"
                        id="scopeSel"
                        class="custom-control-input"
                        value="selection"
                        v-model="scope"
                      />
                      <label class="custom-control-label" for="scopeSel">
                        {{ $root.translated('scopeSelection') }}
                      </label>
                    </div>
                  </div>
                </div>

                <!-- ── Column mapping ── -->
                <div v-if="mappableHeaders.length > 0" class="form-group mt-3 mb-0">
                  <label class="font-weight-bold">{{ $root.translated('columnMapping') }}</label>
                  <p class="text-muted small mb-2">{{ $root.translated('columnMappingHint') }}</p>
                  <div style="overflow-x:auto;">
                    <table class="table table-sm table-bordered mb-0">
                      <thead class="bg-gray-1">
                        <tr>
                          <th style="min-width:130px;">{{ $root.translated('fileColumn') }}</th>
                          <th class="align-middle text-center">
                            <i class="modus-icons" style="font-size:13px;">chevron_right</i>
                          </th>
                          <th>{{ $root.translated('internalColumn') }}</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="h in mappableHeaders" :key="h">
                          <td class="align-middle" style="min-width:130px;">{{ h }}</td>
                          <td class="align-middle text-center">
                            <i class="modus-icons" style="font-size:13px;">chevron_right</i>
                          </td>
                          <td>
                            <!-- Unified mapping selector -->
                            <select
                              class="form-control custom-select"
                              :value="columnMapping[h] && (columnMapping[h].type === 'customAttribute' ? 'customAttribute' : columnMapping[h].type === 'known' ? columnMapping[h].key : '')"
                              @change="e => {
                                const v = e.target.value;
                                if (v === '') {
                                  columnMapping[h].type = ''; columnMapping[h].key = '';
                                } else if (v === 'customAttribute') {
                                  columnMapping[h].type = 'customAttribute'; columnMapping[h].key = '';
                                } else {
                                  columnMapping[h].type = 'known'; columnMapping[h].key = v;
                                }
                              }"
                            >
                              <option value="">({{ $root.translated('skipColumn') }})</option>
                              <option v-for="col in knownColumns" :key="col" :value="col">{{ $root.translated(col) || col }}</option>
                              <option value="customAttribute">{{ $root.translated('customAttribute') }}</option>
                            </select>

                            <!-- Custom attribute inputs -->
                            <div
                              v-if="columnMapping[h] && columnMapping[h].type === 'customAttribute'"
                              class="d-flex mt-3" style="gap:4px;"
                            >
                              <div class="w-50">
                                <label class="option-label">{{ $root.translated('dictionaryName') }}</label>
                                <input
                                  type="text"
                                  class="form-control custom-form-control w-100"
                                  style="width:90px; flex-shrink:0;"
                                  :placeholder="$root.translated('dictionaryName')"
                                  v-model="columnMapping[h].dict"
                                />
                              </div>

                              <div class="w-50">
                                <label class="option-label">{{ $root.translated('attributeName') }}</label>
                                  <input
                                  type="text"
                                  class="form-control custom-form-control w-100"
                                  :placeholder="$root.translated('attributeName')"
                                  v-model="columnMapping[h].attrName"
                                />
                              </div>
                            </div>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>

              <!-- ── Step 3: Preview ── -->
              <div v-if="step === 3">
                <p class="small mb-2">
                  <span class="text-success mr-1">{{ matchedCount }} {{ $root.translated('matched') }}</span>
                  &nbsp;
                  <span class="text-danger mr-1">{{ unmatchedCount }} {{ $root.translated('unmatched') }}</span>
                </p>

                <div style="overflow-x:auto; overflow-y:auto;">
                  <table class="table table-sm table-bordered mb-0">
                    <thead class="bg-gray-1">
                      <tr>
                        <th style="min-width:100px;">{{ matchField }}</th>
                        <th style="min-width:120px;">{{ $root.translated('definition') }}</th>
                        <th
                          v-for="key in previewFieldKeys"
                          :key="key"
                          style="min-width:160px;"
                        >{{ key.startsWith('__custom__') ? (previewRows[0] && previewRows[0].changes[key] && previewRows[0].changes[key].label || key) : ($root.translated(key) || key) }}</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        v-for="(row, i) in previewRows"
                        :key="i"
                      >
                        <!-- Match key value -->
                        <td>{{ row.rowData[matchField] }}</td>

                        <!-- Matched entity name -->
                        <td>
                          <span v-if="row.matched" class="text-success">{{ row.entityName }}</span>
                          <span v-else class="text-danger">-</span>
                        </td>

                        <!-- Per-field old → new with checkbox -->
                        <td v-for="key in previewFieldKeys" :key="key">
                          <template v-if="row.matched && row.changes[key]">
                            <div class="d-flex align-items-center flex-wrap" style="gap:4px;">
                              <div class="custom-control custom-checkbox">
                                <input
                                  type="checkbox"
                                  v-model="row.checkedFields[key]"
                                  class="custom-control-input"
                                  :id="'cb-' + i + '-' + key"
                                />
                                <label class="custom-control-label" :for="'cb-' + i + '-' + key"></label>
                              </div>
                              <span
                                v-if="row.changes[key].current !== row.changes[key].value"
                                class="text-muted"
                                style="text-decoration:line-through; font-size:11px;"
                              >{{ row.changes[key].current || '-' }}</span>
                              <i
                                v-if="row.changes[key].current !== row.changes[key].value"
                                class="modus-icons"
                                style="font-size:11px;"
                              >caret_right</i>
                              <span style="font-size:11px;">{{ row.changes[key].value }}</span>
                            </div>
                          </template>
                          <template v-else>
                            <span class="text-muted small">-</span>
                          </template>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

            </div>

          </div><!-- /modal-body -->

          <!-- Footer -->
          <div class="modal-footer border-top-0">
            <!-- Back button (steps 2 and 3) -->
            <button
              v-if="step > 1"
              type="button"
              class="btn btn-outline-dark"
              :disabled="isLoading"
              @click="step--"
            >{{ $root.translated('back') }}</button>

            <!-- Close / cancel -->
            <button
              type="button"
              class="btn btn-outline-dark"
              data-dismiss="modal"
              @click="resetImport"
            >{{ $root.translated('close') }}</button>

            <!-- Step 1 → 2 -->
            <button
              v-if="step === 1"
              type="button"
              class="btn btn-primary"
              :disabled="!fileData.length || jsonArrayKeys.length > 0"
              @click="goToStep2"
            >{{ $root.translated('next') }}</button>

            <!-- Step 2 → 3: run preview match -->
            <button
              v-if="step === 2"
              type="button"
              class="btn btn-primary"
              :disabled="isLoading || !matchField"
              @click="previewMatch"
            >
              <i v-if="isLoading" class="modus-icons left-icon spin">update</i>
              {{ $root.translated('previewMatch') }}
            </button>

            <!-- Step 3: apply -->
            <button
              v-if="step === 3"
              type="button"
              class="btn btn-primary"
              :disabled="isLoading"
              @click="applyChanges"
            >
              <i v-if="isLoading" class="modus-icons left-icon spin">update</i>
              {{ $root.translated('applyChanges') }}
            </button>
          </div>

        </div><!-- /modal-content -->
      </div>
    </div>
  `,
});
