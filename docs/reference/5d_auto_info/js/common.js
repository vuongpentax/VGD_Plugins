// LINKS
HOMEPAGE_EN       = "https://5dplus.info";
HOMEPAGE_VI       = "https://5dplus.info";
FACEBOOK          = "https://facebook.com/5dplus.sketchup";
STORE             = "https://5dplus.lemonsqueezy.com";
USER_MANUAL_EN    = "https://5dplus.info";
USER_MANUAL_VI    = "https://5dplus.info";
RELEASE_NOTES_EN  = "https://5dplus.info";
RELEASE_NOTES_VI  = "https://5dplus.info";
NOTICE_EN         = "https://5dplus.info";
NOTICE_VI         = "https://5dplus.info";

// Store user selection
const extensionName       = '5d_auto_info-';
const themeKey            = `${extensionName}theme`;
const languageKey         = `${extensionName}language`;

const lastPresetKey       = `${extensionName}lastPreset`;
const totalRowKey         = `${extensionName}totalRow`;
const zoomSelectionKey    = `${extensionName}zoomSelection`;
const columnStatesKey     = `${extensionName}columnStates`;
const columnOrdersKey     = `${extensionName}columnOrders`;
const sortColumnKey       = `${extensionName}sortColumn`;
const sortOrderKey        = `${extensionName}sortOrder`;
const currencyKey         = `${extensionName}currency`;
const modifiedHeadersKey  = `${extensionName}modifiedHeaders`;
const columnWidthKey      = `${extensionName}columnWidths`;
const groupByColumnKey    = `${extensionName}groupByColumn`;
const mergeIdenticalKey   = `${extensionName}mergeIdentical`;

// Global variable to store toast timer
let toastTimer = null;

document.addEventListener("contextmenu", function (event) {
  event.preventDefault();
});

function loadLanguage(context) {
  axios
    .get(`../languages/resources/${context.language}.json`)
    .then((response) => {
      context.languageData = response.data;
    });
}

function applyTheme(theme) {
  const themeStylesheet = document.getElementById("theme-stylesheet");

  if (theme === "dark") {
    document.documentElement.setAttribute("data-theme", "dark");
    themeStylesheet.href = "../css/modus-dark.min.css";
  } else {
    document.documentElement.setAttribute("data-theme", "light");
    themeStylesheet.href = "../css/modus.min.css";
  }
}

function handleTooltip(context) {
  context.$nextTick(() => {
    // Dispose existing
    $('[data-toggle="tooltip"]').tooltip("dispose");
    $('[data-toggle="dropdown"]').tooltip("dispose");

    // Get the element via data-toggle
    const tooltipElements = context.$el.querySelectorAll(
      "[data-toggle='tooltip'], [data-toggle='dropdown']"
    );
    tooltipElements.forEach((el) => {
      new bootstrap.Tooltip(el, {
        trigger: "hover",
        delay: { show: 750, hide: 100 },
      });
    });
  });
}

function hideAllTooltips() {
  // Hide all currently visible tooltips using Bootstrap 4 + jQuery method
  $('[data-toggle="tooltip"], [data-toggle="dropdown"]').tooltip('hide');
  
  // Also remove any dangling tooltip elements
  $('.tooltip').remove();
}

// Base constants aligned with Bootstrap 4 defaults
const BASE_MODAL  = 1050;
const BASE_STEP   = 20;
const BASE_GAP    = 10;

function bringModalToFront($modal) {
  // Compute the top z-index for the new modal
  const modalZ = BASE_MODAL + BASE_STEP;

  // Set modal z-index before showing
  $modal.css("z-index", modalZ);

  // On show (before animation), adjust backdrop z-index immediately
  $modal.one("show.bs.modal", function () {
    setTimeout(function () {
      const $bd = $(".modal-backdrop").last();
      if ($bd.length) {
        $bd.css("z-index", modalZ - BASE_GAP);
      }
    }, 10);
  });

  // Show with chosen backdrop/keyboard behaviors
  $modal.modal({
    show: true,
  });
}

function bringModalToDefault($modal) {
  // Reset z-index
  $modal.css("z-index", "");

  // Reset backdrop z-index
  const $bd = $(".modal-backdrop").last();
  if ($bd.length) {
    $bd.css("z-index", "");
  }
}

function showToast(delay = 1500) {
  const $msg = $("#messageModal");

  // Clear any existing timer to prevent multiple hide calls
  if (toastTimer) {
    clearTimeout(toastTimer);
    toastTimer = null;
  }

  // If modal is already shown, just update content and reset timer
  if ($msg.hasClass('show')) {
    // Auto close if needed
    const dur =
      delay === "wait" || delay === false
        ? null
        : typeof delay === "number"
        ? delay
        : 1500;

    if (dur) {
      toastTimer = setTimeout(function () {
        $msg.one("hidden.bs.modal", function () {
          bringModalToDefault($msg);
          toastTimer = null;
        });
        $msg.modal("hide");
      }, dur);
    }
    return;
  }

  // Remove any existing backdrops before showing new modal
  $('.modal-backdrop').remove();
  $('body').removeClass('modal-open');

  // Reset any stuck state from previous show
  $msg.removeData('bs.modal');

  // Bring modal to front and show
  bringModalToFront($msg);

  // Auto close if needed
  const dur =
    delay === "wait" || delay === false
      ? null
      : typeof delay === "number"
      ? delay
      : 1500;

  if (dur) {
    toastTimer = setTimeout(function () {
      $msg.one("hidden.bs.modal", function () {
        bringModalToDefault($msg);
        toastTimer = null;
      });
      $msg.modal("hide");
    }, dur);
  }
}

function showModal(id, delay) {
  return new Promise(function (resolve) {
    $(id).modal("show");

    if (
      delay !== "wait" &&
      delay !== false &&
      typeof delay === "number" &&
      delay > 0
    ) {
      setTimeout(function () {
        $(id).one("hidden.bs.modal", function () {
          resolve();
        });
        $(id).modal("hide");
      }, delay);
    } else {
      resolve();
    }
  });
}

function hideModal(id) {
  return new Promise(function (resolve) {
    $(id).one("hidden.bs.modal", function () {
      resolve();
    });
    $(id).modal("hide");
  });
}

function hideAllModals() {
  // Remove all modal backdrops
  $('.modal-backdrop').remove();

  // Force hide all modals and reset Bootstrap internal state
  $('.modal').each(function() {
    const $modal = $(this);

    // Remove Bootstrap modal data to reset internal state
    $modal.removeData('bs.modal');

    // Force hide without animation
    $modal.removeClass('show fade');
    $modal.css('display', 'none');
    $modal.attr('aria-hidden', 'true');
    $modal.removeAttr('aria-modal');
    $modal.removeAttr('role');

    // Re-add fade class for next show
    $modal.addClass('fade');
  });

  // Clean up body classes and styles
  $('body').removeClass('modal-open');
  $('body').css('padding-right', '');
  $('body').css('overflow', '');

  // Reset processing state if exists
  if (typeof app !== 'undefined' && app) {
    app.isProcessing = false;
  }

  // Return a resolved Promise to maintain compatibility with Promise chains
  return Promise.resolve();
}

function hideAllDropdowns() {
  return new Promise(function (resolve) {
    const $dropdowns = $(".dropdown-menu.show");

    if ($dropdowns.length === 0) {
      resolve();
      return;
    }

    let hiddenCount = 0;
    const totalDropdowns = $dropdowns.length;

    $dropdowns.each(function () {
      const $dropdown = $(this);

      $dropdown.one("hidden.bs.dropdown", function () {
        hiddenCount++;
        if (hiddenCount === totalDropdowns) {
          resolve();
        }
      });

      $dropdown.dropdown("hide");
    });
  });
}

function callSketchupWithTooltipHide(sketchupMethod, ...args) {
  hideAllTooltips();
  return sketchupMethod.apply(sketchup, args);
}

// Ensure functions are available globally
window.showModal = showModal;
window.hideModal = hideModal;
window.showToast = showToast;
window.hideAllTooltips = hideAllTooltips;
window.callSketchupWithTooltipHide = callSketchupWithTooltipHide;
