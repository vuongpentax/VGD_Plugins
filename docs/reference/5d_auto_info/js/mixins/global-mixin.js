const globalMixin = {
  data() {
    return {
      // Global links from common.js
      HOMEPAGE: "",
      HOMEPAGE_EN: HOMEPAGE_EN,
      HOMEPAGE_VI: HOMEPAGE_VI,
      FACEBOOK: FACEBOOK,
      STORE: STORE,
      USER_MANUAL_EN: USER_MANUAL_EN,
      USER_MANUAL_VI: USER_MANUAL_VI,
      RELEASE_NOTES_EN: RELEASE_NOTES_EN,
      RELEASE_NOTES_VI: RELEASE_NOTES_VI,
      NOTICE_EN: NOTICE_EN,
      NOTICE_VI: NOTICE_VI,

      currentTheme: 'light',
      themeIcon: 'sun',
      language: 'en-US',
      languages: [
        { code: 'cs-CZ', name: 'Čeština' },
        { code: 'de-DE', name: 'Deutsch' },
        { code: 'en-US', name: 'English' },
        { code: 'es-ES', name: 'Español' },
        { code: 'fr-FR', name: 'Français' },
        { code: 'it-IT', name: 'Italiano' },
        { code: 'ja-JP', name: '日本語' },
        { code: 'ko-KR', name: '한국어' },
        { code: 'nl-NL', name: 'Nederlands' },
        { code: 'pl-PL', name: 'Polski' },
        { code: 'pt-BR', name: 'Português' },
        { code: 'ru-RU', name: 'Русский' },
        { code: 'sk-SK', name: 'Slovenčina' },
        { code: 'sl-SI', name: 'Slovenščina' },
        { code: 'sv-SE', name: 'Svenska' },
        { code: 'th-TH', name: 'ภาษาไทย' },
        { code: 'tr-TR', name: 'Türkçe' },
        { code: 'uk-UA', name: 'Українська' },
        { code: 'vi-VN', name: 'Tiếng Việt' },
        { code: 'zh-CN', name: '简体中文' },
      ],
      languageData: {},

      noticeType: "info",
      noticeMessage: "",
      modalTitle: "",
      editTitle: "",
      editAction: null,
      modalMessage: "",
      modalAction0: null,
      modalAction1: null,
      modalAction2: null,

      sketchupVersion: 2021, // Default to 2021
      isNewVersion: false,
      isMetric: true,
      lengthUnit: 'mm',
    }
  },

  mounted() {
    sketchup.ready();

    // Tooltip
    handleTooltip(this);

    // Homepage
    this.HOMEPAGE = this.language === 'vi-VN' ? this.HOMEPAGE_VI : this.HOMEPAGE_EN;
  },

  methods: {
    changeLanguage(lang) {
      this.language = lang;
      localStorage.setItem(languageKey, this.language);
      loadLanguage(this);

      handleTooltip(this);
    },

    translated(key) {
      return this.languageData[key] || key;
    },

    switchTheme() {
      const newTheme = this.currentTheme === 'light' ? 'dark' : 'light';

      applyTheme(newTheme);
      this.currentTheme = newTheme;
      this.themeIcon = this.currentTheme === 'light' ? 'moon' : 'sun';

      localStorage.setItem(themeKey, newTheme);
    },

    noticeNewVersion(value) {
      this.isNewVersion = value;
    },

    checkUpdate() {
      sketchup.checkUpdate();
    },
  }
}

function noticeNewVersion(data) {
  document.getElementById('app').__vue__.noticeNewVersion(data);
}