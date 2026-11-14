const openDialogsMixin = {
  data() {
    return {
      HOMEPAGE: '',
      HOMEPAGE_EN:      'https://5dplus.info',
      HOMEPAGE_VI:      'https://5dplus.info',
      FACEBOOK:         'https://facebook.com/5dplus.sketchup',
      EMAIL:            'support@5dplus.info',
      STORE:            'https://5dplus.info/store.html',
      USER_ORDERS:      'https://app.lemonsqueezy.com/my-orders',
      SAMPLES:          'https://5dplus.info/download/plus/index.html',
      USER_MANUAL_EN:   'https://5dplus.info',
      USER_MANUAL_VI:   'https://5dplus.info',
      RELEASE_NOTES_EN: 'https://5dplus.info',
      RELEASE_NOTES_VI: 'https://5dplus.info',
      NOTICE_EN:        'https://5dplus.info',
      NOTICE_VI:        'https://5dplus.info',
      TUTORIALS_EN:     {},
      TUTORIALS_VI:     {},
    }
  },

  watch: {
    // Re-initialize tooltips when tutorialUrl changes (button appears/disappears via v-if)
    tutorialUrl: {
      handler() {
        handleTooltip(this);
      },
      deep: true
    },
  },

  methods: {
    openSupporter(type, video = false) {
      if (!type) return;

      let url = '';

      if (type === 'userManual') {
        url = this.language === 'vi-VN' ? this.USER_MANUAL_VI : this.USER_MANUAL_EN;
      } else if (type === 'releaseNotes') {
        url = this.language === 'vi-VN' ? this.RELEASE_NOTES_VI : this.RELEASE_NOTES_EN;
      } else if (type === 'samples') {
        url = this.SAMPLES;
      } else if (type === 'store') {
        url = this.STORE;
      } else {
        url = this.language === 'vi-VN' ? this.TUTORIALS_VI[type] : this.TUTORIALS_EN[type];
      }
      sketchup.openSupporter(url, video);
    },

    isUrlExist(type) {
      return this.language === 'vi-VN' ? this.TUTORIALS_VI[type] : this.TUTORIALS_EN[type];
    },

    updateUrls(urls) {
      const safeUrls = urls || {};
      this.HOMEPAGE_EN        = safeUrls.homepageEn        || this.HOMEPAGE_EN;
      this.HOMEPAGE_VI        = safeUrls.homepageVi        || this.HOMEPAGE_VI;
      this.FACEBOOK           = safeUrls.facebook          || this.FACEBOOK;
      this.EMAIL              = safeUrls.email             || this.EMAIL;
      this.STORE              = safeUrls.store             || this.STORE;
      this.USER_ORDERS        = safeUrls.userOrders        || this.USER_ORDERS;
      this.SAMPLES            = safeUrls.samples           || this.SAMPLES;
      this.USER_MANUAL_EN     = safeUrls.userManualEn      || this.USER_MANUAL_EN;
      this.USER_MANUAL_VI     = safeUrls.userManualVi      || this.USER_MANUAL_VI;
      this.RELEASE_NOTES_EN   = safeUrls.releaseNotesEn    || this.RELEASE_NOTES_EN;
      this.RELEASE_NOTES_VI   = safeUrls.releaseNotesVi    || this.RELEASE_NOTES_VI;
      this.NOTICE_EN          = safeUrls.noticeEn          || this.NOTICE_EN;
      this.NOTICE_VI          = safeUrls.noticeVi          || this.NOTICE_VI;
      this.TUTORIALS_EN       = safeUrls.tutorialsEn       || this.TUTORIALS_EN;
      this.TUTORIALS_VI       = safeUrls.tutorialsVi       || this.TUTORIALS_VI;

      // Set tutorial URLs after data is loaded
      if (typeof this.setTutorialUrls === 'function') {
        this.setTutorialUrls();
      }

      // Restore last modal open
      this.restoreLastModal();
    },
  }
}

function updateUrls(urls) {
  document.getElementById('app').__vue__.updateUrls(urls);
}