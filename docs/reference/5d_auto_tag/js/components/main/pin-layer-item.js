Vue.component('pin-layer-item', {
  props: ['layer'],
  template: /*html*/ `
    <div
      :ref="'pinLayer-' + layer.id"
      :id="'pinLayer-' + layer.id"
      class="chip chip-outline flex-fill d-flex cursor-default"
      :class="{ 'cursor-sample': $root.isSampleTool }"
      @contextmenu="$root.toggleContextMenu($event, 'layer', layer.name)"
      @click="$root.selectLayer(layer, $event)"
    >
      <i
        :class="['modus-icons hover-icon cursor-pointer mr-2', { 'text-gray-4': $root.hiddenLayers.includes(layer.name) }]"
        @click.stop="$root.toggleVisibleLayer(layer)"
      >
        {{ $root.hiddenLayers.includes(layer.name) ? 'visibility_off' : 'visibility_on' }}
      </i>

      <div
        :class="['chip-text pin-text',
          { 'text-gray-4': $root.hiddenLayers.includes(layer.name) }
        ]"
      >
        {{ layer.name }}
      </div>

      <div
        class="chip-delete-right hover-icon cursor-pointer m-0"
        @click.stop="$root.togglePinLayer(layer)"
      >
        <i class="modus-icons">close</i>
      </div>
    </div>
  `
});

