Vue.component('context-menu', {
  template: /*html*/ `
    <div
      v-if="$root.showContextMenu"
      class="custom-menu border bg-gray-light floating-menu"
      id="contextMenu"
    >
      <ul class="list-group list-group-borderless bg-gray-light py-2">
        <div class="px-2">
          <!--
          <li
            v-if="$root.currentFolder"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click=$root.moreActions("collapseAll")
          >
            <i class="modus-icons">chevron_double_up</i>
            {{ $root.translated('collapseAll') }}
          </li>

          <li
            v-if="$root.currentFolder"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click=$root.moreActions("expandAll")
          >
            <i class="modus-icons">chevron_double_down</i>
            {{ $root.translated('expandAll') }}
          </li>
          -->

          <li
            v-if="$root.selectedObjects && $root.selectedLayers.length === 1 && ($root.currentLayer || $root.currentLayer === '')"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('tagAllEntities')"
          >
            <i class="modus-icons text-danger">tag</i>
            {{ $root.translated('tagAllEntities') }}
          </li>

          <li
            v-if="$root.selectedObjects && $root.selectedLayers.length === 1 && ($root.currentLayer || $root.currentLayer === '')"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('tagNestedObjects')"
          >
            <i class="modus-icons text-primary">tag</i>
            {{ $root.translated('tagNestedObjects') }}
          </li>

          <li
            v-if="$root.selectedObjects && $root.selectedLayers.length === 1 && ($root.currentLayer || $root.currentLayer === '')"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('tagNestedGeometries')"
          >
            <i class="modus-icons">tag</i>
            {{ $root.translated('tagNestedGeometries') }}
          </li>
        </div>

        <div v-if="($root.selectedObjects && $root.selectedLayers.length == 1)" class="dropdown-divider"></div>

        <div class="px-2">
          <li
            v-if="$root.currentFolder"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('onAllFolders')"
          >
            <i class="modus-icons">visibility_on</i>
            {{ $root.translated('turnOnAllFolders') }}
          </li>

          <li
            v-if="$root.currentLayer || $root.currentLayer === ''"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('onAllLayers')"
          >
            <i class="modus-icons">visibility_on</i>
            {{ $root.translated('turnOnAllTags') }}
          </li>
  
          <li
            v-if="$root.currentFolder"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('offAllFolders')"
          >
            <i class="modus-icons">visibility_off</i>
            {{ $root.translated('turnOffAllFolders') }}
          </li>

          <li
            v-if="$root.currentLayer || $root.currentLayer === ''"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('offAllLayers')"
          >
            <i class="modus-icons">visibility_off</i>
            {{ $root.translated('turnOffAllTags') }}
          </li>

          <li
            v-if="$root.currentFolder"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('isolateFolder')"
          >
            <i class="modus-icons text-danger">visibility_on</i>
            {{ $root.translated('isolateSelectedFolder') }}
          </li>

          <li
            v-if="$root.currentLayer || $root.currentLayer === ''"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('isolateLayer')"
          >
            <i class="modus-icons text-danger">visibility_on</i>
            {{ $root.translated('isolateSelectedTag') }}
          </li>
        </div>

        <div class="dropdown-divider"></div>

        <div class="px-2">
          <li
            v-if="$root.currentLayer || $root.currentLayer === ''"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('visibleAllScenes')"
          >
            <i class="modus-icons">visibility_on</i>
            {{ $root.translated('setVisibilityScenes') }}
          </li>

          <li
            v-if="$root.currentFolder"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('deleteFolder')"
          >
            <i class="modus-icons text-danger">delete</i>
            {{ $root.translated('explodeTagFolder') }}
          </li>

          <li
            v-if="$root.currentLayer || $root.currentLayer === ''"
            class="list-group-item list-item-left-control custom-list-group-item"
            @click="$root.moreActions('deleteLayer')"
          >
            <i class="modus-icons text-danger">delete</i>
            {{ $root.translated('deleteTag') }}
          </li>
        </div>
      </ul>
    </div>
  `
});

