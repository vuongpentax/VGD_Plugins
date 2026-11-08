Vue.component('support-modal', {
  mounted() {
    const style = document.createElement('style')
    style.innerHTML = /*css*/ `
      #supportModal .modal-dialog {
        margin: auto !important;
        width: 270px !important;
      }

      .modal-body-support img {
        max-height: 330px;
        max-width: 100%;
        height: auto;
        border-radius: 3px;
      }
    `
    document.head.appendChild(style)
  },
  template: /*html*/ `
    <div
      class="modal fade"
      id="supportModal"
      tabindex="-1"
      role="dialog"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content custom-menu bg-white">
          <div class="modal-header">
            <h5 class="modal-title">
              {{ $root.translated('support') }}
            </h5>
            <button
              type="button"
              class="btn btn-sm btn-icon-only btn-danger"
              data-dismiss="modal"
              aria-label="Close"
            >
              <i class="modus-icons">close</i>
            </button>
          </div>

          <div class="modal-body-support">
            <ul
              class="nav nav-tabs d-flex align-items-center bg-gray-light px-3 pt-2"
              id="supportTabs"
              role="tablist"
            >
              <li class="nav-item flex-grow-1">
                <a
                  class="nav-link"
                  id="supportFirstTab"
                  data-toggle="tab"
                  href="#supportFirst"
                  role="tab"
                  aria-controls="supportFirst"
                  aria-selected="false"
                >
                  Bank
                </a>
              </li>

              <li class="nav-item flex-grow-1">
                <a
                  class="nav-link"
                  id="supportSecondTab"
                  data-toggle="tab"
                  href="#supportSecond"
                  role="tab"
                  aria-controls="supportSecond"
                  aria-selected="false"
                >
                  Paypal
                </a>
              </li>
            </ul>

            <div class="tab-content p-2">
              <div
                class="tab-pane fade show active"
                id="supportFirst"
                role="tabpanel"
              >
                <img src="../images/vcb.svg" alt="">
              </div>

              <div
                class="tab-pane fade"
                id="supportSecond"
                role="tabpanel"
              >
                <a href="https://paypal.me/cyentruk" target="_blank">
                  <img src="../images/paypal.svg" alt="">
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `
});