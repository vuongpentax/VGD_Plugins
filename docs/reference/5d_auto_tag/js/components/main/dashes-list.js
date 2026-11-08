Vue.component('dashes-list', {
  template: /*html*/ `
    <div
      v-if="$root.showDashesList"
      class="mt-1 custom-menu floating-menu bg-gray-light border"
      id="dashesList"
    >
      <ul class="list-group list-group-sm list-group-borderless p-2">
        <li
          v-for="dash in $root.dashes"
          :key="dash"
          :ref="dash"
          class="list-group-item border-0 list-item-right-control custom-list-group-item py-0 pr-1"
          @click="$root.selectDash(dash)"
          >
            <div v-if="dash === 'Default'" class="d-flex align-items-center">
              <span>Default</span>
            </div>
            <img
              v-else
              :src="$root.dashesImageSource(dash)"
              alt=""
              width="100"
              height="30"
            >
        </li>
      </ul>

    </div>
  `
});

