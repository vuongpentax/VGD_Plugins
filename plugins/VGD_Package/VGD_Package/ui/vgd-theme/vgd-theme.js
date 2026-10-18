/* VGD shared theme switch. Copied unchanged into each plugin's dialog folder as vgd-theme/vgd-theme.js.
   Usage: VGDTheme.start({ key: 'vgd.dim.theme', button: document.getElementById('theme') });
   - No saved choice: follow Windows light/dark.
   - User clicks the button: that choice is saved under `key` and kept on later launches.
   Saved values: 'light' or 'dark'. Anything else is ignored. */
(function (global) {
  'use strict';

  var query = global.matchMedia ? global.matchMedia('(prefers-color-scheme: dark)') : null;

  function readSaved(key) {
    try {
      var value = global.localStorage.getItem(key);
      return value === 'light' || value === 'dark' ? value : null;
    } catch (_) {
      return null;
    }
  }

  function writeSaved(key, value) {
    try { global.localStorage.setItem(key, value); } catch (_) { /* storage can be blocked; theme still applies */ }
  }

  function systemIsDark() {
    return !!(query && query.matches);
  }

  // Applies a theme to the page. Writes data-theme only for an explicit choice, so the CSS media query
  // keeps following Windows when nothing was saved.
  function apply(saved, button) {
    var root = global.document.documentElement;
    if (saved) root.setAttribute('data-theme', saved); else root.removeAttribute('data-theme');
    var dark = saved ? saved === 'dark' : systemIsDark();
    global.document.dispatchEvent(new CustomEvent('vgdtheme', { detail: { theme: dark ? 'dark' : 'light' } }));
    if (button) {
      button.textContent = dark ? '☀' : '☾'; // ☀ when dark (click for light), ☾ when light
      var label = dark ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối';
      button.title = label;
      button.setAttribute('aria-label', label);
      button.setAttribute('aria-pressed', String(dark));
    }
    return dark ? 'dark' : 'light';
  }

  function start(options) {
    var key = options.key;
    var button = options.button || null;
    var saved = readSaved(key);
    apply(saved, button);

    if (button) {
      button.addEventListener('click', function () {
        var nowDark = root().getAttribute('data-theme') === 'dark' || (!root().hasAttribute('data-theme') && systemIsDark());
        var next = nowDark ? 'light' : 'dark';
        writeSaved(key, next);
        apply(next, button);
      });
    }

    // Follow Windows live, but only while the user has not chosen a theme.
    if (query && query.addEventListener) {
      query.addEventListener('change', function () {
        if (!readSaved(key)) apply(null, button);
      });
    }
  }

  function root() { return global.document.documentElement; }

  // The theme in use right now: 'dark' or 'light', whether it came from a saved choice or from Windows.
  function current() {
    var saved = root().getAttribute('data-theme');
    return saved === 'dark' || (!saved && systemIsDark()) ? 'dark' : 'light';
  }

  global.VGDTheme = { start: start, apply: apply, current: current };
})(window);
