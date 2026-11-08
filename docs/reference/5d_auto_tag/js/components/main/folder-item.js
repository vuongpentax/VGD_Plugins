Vue.component('folder-item', {
  props: ['folder', 'expandFolders', 'layersInFolder', 'hiddenFolders', 'hiddenLayers', 'pinLayers', 'selectedFolder'],
  template: /*html*/ `
    <li
      :ref="'folder-' + folder.id"
      :data-folder-id="folder.id"
      class="folder-card cursor-default"
      :class="{
        'border-top border-bottom item-selected': selectedFolder === folder.id,
        'item-selected': $root.selectedFolders.some(f => f.id === folder.id),
        'text-gray-4': Array.isArray(hiddenFolders) && hiddenFolders.includes(folder.id)
      }"
    >
      <div
        class="list-group-item pl-2 pr-1"
        :class="{
          'drop-hover': folder.id === $root.dragOverFolderId
        }"
        @click.stop="$root.selectFolder(folder, $event)"
        @mousedown.stop="$root.onDragStart($event, folder.id, 'folder')"
        @dragover.prevent="$root.onDragOver($event, folder.id)"
        @dragleave.stop="$root.onDragLeave($event, folder.id)"
        @drop.stop="$root.onDrop($event, folder.id)"
      >
        <!-- Visibility -->
        <div
          class="cursor-pointer mr-1"
          @click.stop="$emit('toggle-visible-folder', folder.id)"
          @click.ctrl.stop="$emit('toggle-isolate-folder', folder.id)"
        >
          <i class="modus-icons hover-icon">
            {{ Array.isArray(hiddenFolders) && hiddenFolders.includes(folder.id) ? 'visibility_off' : 'visibility_on' }}
          </i>
        </div>

        <!-- Folder Icon -->
        <div class="hover-icon cursor-pointer mr-1" @click.stop="$emit('toggle-folder', folder)">
          <i
            class="modus-icons hover-icon"
            :class="{
              'text-danger': expandFolders.includes(folder.id)
            }"
          >
            {{ Array.isArray(expandFolders) && expandFolders.includes(folder.id) ? 'caret_down' : 'caret_right' }}
          </i>
          <i
            class="modus-icons"
            :class="{
              'text-danger': expandFolders.includes(folder.id)
            }"
          >
            {{ Array.isArray(expandFolders) && expandFolders.includes(folder.id) ? 'folder_open' : 'folder_closed' }}
          </i>
        </div>

        <!-- Folder Name -->
        <div
          :id="'folder-name-' + folder.id"
          class="flex-fill"
          @dblclick="$root.startRenameFolder(folder)"
          @contextmenu="$root.toggleContextMenu($event, 'folder', folder.id)"
        >
          <span v-if="$root.editingFolder !== folder.id">{{ folder.name }}</span>
          <input type="text"
            v-if="$root.editingFolder === folder.id"
            v-model="$root.editingFolderName"
            :id="'input-' + folder.id"
            class="custom-input form-control form-control-sm"
            @blur="$root.renameFolder(folder)"
            @keyup.enter="$root.renameFolder(folder)"
            @keyup.esc="$root.cancelRenameFolder()"
          >
        </div>

        <!-- Expand/Collapse -->
        <div class="hover-icon cursor-pointer ml-auto invisible" @click.stop="$emit('toggle-folder', folder)">
          <i class="modus-icons">
            {{ expandFolders.includes(folder.id) ? 'expand_more' : 'chevron_left' }}
          </i>
        </div>
      </div>

      <!-- CHILDREN + LAYERS -->
      <div class="pl-0">
        <transition name="fade-expand">
          <ul v-if="Array.isArray(expandFolders) && expandFolders.includes(folder.id)"
            class="list-group list-group-sm list-group-borderless ml-3"
            :class="{
              'border-left': expandFolders.includes(folder.id)
            }"
          >
            <!-- SUB-FOLDERS -->
            <folder-item
              v-for="child in folder.childrenFolders"
              :key="child.id"
              :folder="child"
              :expand-folders="expandFolders"
              :hidden-folders="hiddenFolders"
              :hidden-layers="hiddenLayers"
              :pin-layers="pinLayers"
              :selected-folder="selectedFolder"
              @toggle-folder="$emit('toggle-folder', $event)"
              @toggle-visible-folder="$emit('toggle-visible-folder', child.id)"
              @select-folder="$emit('select-folder', child.id)"
              @click.ctrl.stop="$emit('toggle-isolate-folder', folder.id)"
            ></folder-item>

            <!-- LAYERS IN FOLDER -->
            <layer-item
              v-for="layer in $root.filteredLayersInFolder(folder.id)"
              :key="layer.id"
              :layer="layer"
              :expanded="Array.isArray(expandFolders) && expandFolders.includes(folder.id)"
            ></layer-item>
          </ul>
        </transition>
      </div>
    </li>
  `
});
