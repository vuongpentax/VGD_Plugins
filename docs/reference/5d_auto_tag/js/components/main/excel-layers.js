Vue.component('excel-layers', {
  props: ['dashesSrc'],
  template: /*html*/ `
    <div v-if="$root.isExcel" class="px-2" id="excelLayers">
      <table
        class="table table-sm table-bordered table-hover"
        style="table-layout: fixed; width: 100%;"
      >
        <thead>
          <tr class="bg-dark text-white sticky-top">
            <!-- Checkbox All -->
            <th class="text-center" style="width: 32px">
              <div class="custom-control custom-checkbox">
                <input
                  type="checkbox"
                  class="custom-control-input"
                  id="checkAllExcelTags"
                  @change="$root.toggleCheckAllExcel($event.target.checked)"
                />
                <label for="checkAllExcelTags" class="custom-control-label"></label>
              </div>
            </th>
            <th 
              v-for="key in Object.keys($root.excelRows[0] || {})"
              :id="'header' + key"
              :style="key === 'Color' ? 'width: 54px; text-align: center' : key === 'Dashes' ? 'min-width: 120px' : ''"
            >
              {{ key }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, index) in $root.filteredExcelRows"
            :key="$root.getRowKey(row)"
            :class="[
              'cursor-default',
              {
                'highlight': $root.excelRowStates[$root.getRowKey(row)],
                'font-weight-bold': $root.getRowKey(row) && $root.getRowKey(row).includes('<') && $root.getRowKey(row).includes('>')
              }
            ]"
          >
            <!-- Checkbox Category -->
            <td
              class="text-center"
              :class="{'bg-gray-2': $root.getRowKey(row) && $root.getRowKey(row).includes('<') && $root.getRowKey(row).includes('>') }"
            >
              <div class="custom-control custom-checkbox">
                <input
                  v-model="$root.excelCheckboxStates[$root.getRowKey(row)]"
                  type="checkbox"
                  class="custom-control-input"
                  :id="'checkCategory' + index"
                  :attribute="$root.getRowKey(row) && $root.getRowKey(row).includes('<') && $root.getRowKey(row).includes('>') ? 'checkbox-category' : ''"
                  @change="$root.getRowKey(row) && $root.getRowKey(row).includes('<') && $root.getRowKey(row).includes('>') 
                    ? $root.toggleCheckCategory(index, $event.target.checked)
                    : $root.handleCheckboxChange($root.getRowKey(row))"
                />
                <label :for="'checkCategory' + index" class="custom-control-label"></label>
              </div>
            </td>

            <!-- Render each column -->
            <td
              v-for="(value, key) in row"
              :class="{
                'bg-gray-2': value && typeof value === 'string' && value.includes('<') && value.includes('>')
              }"
              :key="key"
              @click="$root.handleRowClick(row)"
            >
              <!-- Color column -->
              <div
                v-if="key === 'Color' && value"
                class="color-square"
                :style="{ backgroundColor: value.replace('Color', 'rgba') }"
              >
              </div>

              <!-- Dashes column -->
              <div v-else-if="key === 'Dashes' && value && !(value.includes('<') && value.includes('>'))">
                <img v-if="value !== 'Default'"
                  :src="dashesSrc + value.toLowerCase().replace(/ /g, '_') + '.svg'"
                  alt="" width="100" height="30" />
                <span v-else>Default</span>
              </div>

              <!-- Normal cell -->
              <span v-else>
                {{ value.replace(/[<>]/g, "") }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  `
});

