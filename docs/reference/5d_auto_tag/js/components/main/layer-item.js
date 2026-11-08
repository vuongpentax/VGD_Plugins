Vue.component('layer-item', {
  props: ['layer', 'expanded'],
  template: /*html*/ `
    <li
      v-if="!layer.folder || (layer.folder && expanded)"
      :key="layer.id"
      :ref="'layer-' + layer.id"
      :data-layer-id="layer.id"
      draggable="true"
      class="list-group-item cursor-default pl-2 pr-1"
      :class="{
        'item-selected': $root.selectedLayers.some(l => l.id === layer.id) && !$root.editingLayer && !$root.isSampleTool,
        'drop-hover': layer.id === $root.dragOverLayerId
      }"
      style="align-items: center"
      @click="$root.selectLayer(layer, $event)"
      @mousedown="$root.onDragStart($event, layer.id, 'layer')"
    >
      <!-- Visible -->
      <div
        class="text-center cursor-pointer mr-2"
        :id="'visible-' + layer.id"
        :data-visible="layer.visible"
        @click.stop="$root.toggleVisibleLayer(layer)"
        @click.ctrl="$root.toggleIsolateLayer(layer.name)"
      >
        <i
          :class="[
            'modus-icons hover-icon',
            { 'text-gray-4': $root.hiddenLayers.includes(layer.name) }
          ]"
        >
          {{ $root.hiddenLayers.includes(layer.name) ? 'visibility_off' : 'visibility_on' }}
        </i>
      </div>

      <!-- Name -->
      <div
        :id="'name-' + layer.id"
        :class="[
          'flex-fill name-box mr-2',
          $root.isSampleTool ? 'cursor-sample': 'cursor-default',
          { 'text-gray-4': $root.hiddenLayers.includes(layer.name) }
        ]"
        @dblclick.stop="$root.startRenameLayer(layer)"
        @contextmenu="$root.toggleContextMenu($event, 'layer', layer.name)"
      >
        <span v-if="$root.editingLayer !== layer.id">{{ layer.name }}</span>
        <input type="text"
          v-if="$root.editingLayer === layer.id"
          v-model="$root.editingLayerName"
          :id="'input-' + layer.id"
          class="custom-input form-control form-control-sm"
          @blur="$root.renameLayer(layer)"
          @keyup.enter="$root.renameLayer(layer)"
          @keyup.esc="$root.cancelRenameLayer()"
        >
        <i
          v-if="$root.activeLayer === layer.name"
          class="modus-icons text-danger float-right mr-2"
        >
          pencil
        </i>
        <i
          v-if="(layer.name === $root.currentLayer) && $root.isSampleTool"
          class="modus-icons text-success float-right mr-2"
        >
          paint_bucket
        </i>
      </div>

      <!-- Dash -->
      <div
        v-show="!$root.compactMode"
        :id="'dash-' + layer.id"
        :class="['dash-box cursor-default ml-2 pr-3', { 'text-gray-4': $root.hiddenLayers.includes(layer.name) }]"
        style="min-width: 120px"
        @click.stop="$root.toggleDashesList(layer.id, layer.name)"
      >
        <div v-if="layer.dash === 'Default'"> {{ layer.dash }} </div>
        <div v-else>
          <img
            :src="$root.dashesImageSource(layer.dash)"
            alt=""
            width="100"
            height="30"
          >
        </div>
      </div>

      <!-- Pin -->
      <div
        class="cursor-pointer text-center"
        :id="'pin-' + layer.id"
        :data-pin="Object.keys($root.pinLayers).includes(layer.id) ? 'off' : 'on'"
        @click.stop="$root.togglePinLayer(layer)"
      >
        <div>
          <i
            :class="['modus-icons hover-icon', { 'text-danger': Object.keys($root.pinLayers).includes(layer.id) }]"
          >
            map_marker
          </i>
        </div>
      </div>

      <!-- Color -->
      <div
        class="ml-2 mr-1"
        :id="'color-' + layer.id"
        :data-color="layer.color"
        @click.stop="$root.toggleColorPicker(layer)"
      >
        <div
          class="color-box"
          :style="{ backgroundColor: layer.color }"
        ></div>
      </div>
    </li>
  `
});
