Vue.directive('resize-arrow', {
  componentUpdated: function (el) {
    const ths = el.querySelectorAll('th');

    // Load saved widths
    let savedWidths = {};
    try {
      savedWidths = JSON.parse(localStorage.getItem(columnWidthKey)) || {};
    } catch (e) {}

    ths.forEach((th, index) => {
      if (index === ths.length - 1) return; // Skip last column
      if (th.querySelector('.resize')) return; // Avoid duplicate

      const resize = document.createElement('div');
      resize.className = 'resize';

      // Add dots
      const dots = document.createElement('div');
      dots.style.display = 'flex';
      dots.style.flexDirection = 'column';
      dots.style.gap = '3px';
      for (let i = 0; i < 3; i++) {
        const dot = document.createElement('span');
        dot.style.width = '4px';
        dot.style.height = '4px';
        dot.style.backgroundColor = '#999';
        dot.style.borderRadius = '50%';
        dot.style.display = 'block';
        dots.appendChild(dot);
      }
      resize.appendChild(dots);

      th.prepend(resize);

      // Apply saved width if any
      const colKey = th.getAttribute('id');
      if (savedWidths[colKey]) {
        th.style.width = savedWidths[colKey] + 'px';
      }

      let startX, startWidth;

      resize.addEventListener('mousedown', (e) => {
        e.preventDefault();
        startX = e.pageX;
        startWidth = th.offsetWidth;

        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
      });

      function onMouseMove(e) {
        const newWidth = Math.max(50, startWidth + (e.pageX - startX));
        th.style.width = newWidth + 'px';
      }

      function onMouseUp() {
        // Save width
        if (colKey) {
          savedWidths[colKey] = th.offsetWidth;
          localStorage.setItem(columnWidthKey, JSON.stringify(savedWidths));
        }
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
      }
    });

    // Handle last visible column (hide resize)
    ths.forEach(th => th.classList.remove('last-visible-col'));
    const visibleThs = Array.from(ths).filter(th => th.offsetParent !== null);
    if (visibleThs.length) {
      const lastVisibleTh = visibleThs[visibleThs.length - 1];
      lastVisibleTh.classList.add('last-visible-col');
    }
  }
});