// LINKS
HOMEPAGE_EN       = "https://5dplus.info";
HOMEPAGE_VI       = "https://5dplus.info";
FACEBOOK          = "https://facebook.com/5dplus.sketchup";
STORE             = "https://5dplus.lemonsqueezy.com";
SAMPLES           = "https://5dplus.info/download/auto-tag/index.html";
USER_MANUAL_EN    = "https://5dplus.info";
USER_MANUAL_VI    = "https://5dplus.info";
RELEASE_NOTES_EN  = "https://5dplus.info";
RELEASE_NOTES_VI  = "https://5dplus.info";
NOTICE_EN         = "https://5dplus.info";
NOTICE_VI         = "https://5dplus.info";

// Store user selection
const extensionName = "5d_auto_tag-";
const themeKey      = `${extensionName}theme`;
const languageKey   = `${extensionName}language`;

const recentSearchKey     = `${extensionName}recentSearch`;
const visibleSavedKey     = `${extensionName}visibleLayer`;
const recentLayerKey      = `${extensionName}recentLayer`;
const pinLayersKey        = `${extensionName}pinLayers`;
const sortLayersKey       = `${extensionName}sortLayers`;
const compactModeKey      = `${extensionName}compactMode`;
const excelFileNameKey    = `${extensionName}excelFileName`;
const savedTableKey       = `${extensionName}savedTable`;
const useExcelKey         = `${extensionName}useExcel`;
const exportLayersKey     = `${extensionName}exportLayers`;

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
  const themeStylesheet = document.getElementById('theme-stylesheet');

  if (theme === 'dark') {
    document.documentElement.setAttribute('data-theme', 'dark');
    themeStylesheet.href = '../css/modus-dark.min.css';
  } else {
    document.documentElement.setAttribute('data-theme', 'light');
    themeStylesheet.href = '../css/modus.min.css';
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

// Function to hide all tooltips immediately 
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
  const $msg = $("#noticeMessage");

  // Bring modal to front
  bringModalToFront($msg);

  // Auto close if needed
  const dur =
    delay === "wait" || delay === false
      ? null
      : typeof delay === "number"
      ? delay
      : 1500;

  if (dur) {
    setTimeout(function () {
      $msg.one("hidden.bs.modal", function () {
        bringModalToDefault($msg);
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
  return new Promise(function (resolve) {
    const $modals = $(".modal.show");

    if ($modals.length === 0) {
      resolve();
      return;
    }

    let hiddenCount = 0;
    const totalModals = $modals.length;

    $modals.each(function () {
      const $modal = $(this);

      $modal.one("hidden.bs.modal", function () {
        hiddenCount++;
        if (hiddenCount === totalModals) {
          resolve();
        }
      });

      $modal.modal("hide");
    });
  });
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
