function printPDF() {
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt' });

  // Register Roboto font for Vietnamese Unicode support
  if (typeof ROBOTO_FONT_BASE64 !== 'undefined') {
    doc.addFileToVFS('Roboto-Regular.ttf', ROBOTO_FONT_BASE64);
    doc.addFont('Roboto-Regular.ttf', 'Roboto', 'normal');
    doc.setFont('Roboto');
  }

  // Temporarily hide the extra row if it has no visible content,
  // so autoTable (with includeHiddenHtml: false) will skip it.
  const extraRow = document.getElementById('extra');
  let extraWasHidden = false;
  if (extraRow) {
    const hasContent = Array.from(extraRow.querySelectorAll('td')).some(function (td) {
      return window.getComputedStyle(td).display !== 'none' && td.textContent.trim().length > 0;
    });
    if (!hasContent) {
      extraRow.style.display = 'none';
      extraWasHidden = true;
    }
  }

  doc.autoTable({
    html: '#myTable',
    includeHiddenHtml: false,
    styles: {
      font: (typeof ROBOTO_FONT_BASE64 !== 'undefined') ? 'Roboto' : 'helvetica',
      fontSize: 8,
      cellPadding: 3,
      overflow: 'linebreak',
      lineWidth: 0.5,
      lineColor: [180, 180, 180],
      fillColor: [255, 255, 255],
      textColor: [0, 0, 0],
    },
    headStyles: {
      fillColor: [210, 210, 210],
      textColor: [0, 0, 0],
      fontStyle: 'bold',
      lineWidth: 0.5,
      lineColor: [180, 180, 180],
    },
    footStyles: {
      fillColor: [210, 210, 210],
      fontStyle: 'bold',
      lineWidth: 0.5,
      lineColor: [180, 180, 180],
    },
    bodyStyles: {
      fillColor: [255, 255, 255],
    },
    didParseCell: function (data) {
      const cell = data.cell.raw;
      if (!cell || typeof cell.querySelector !== 'function') return;

      // 1. Extra row (2nd thead row): light gray background, alignment from DOM
      if (data.section === 'head' && data.row.index === 1) {
        data.cell.styles.fillColor = [241, 241, 241];
        data.cell.styles.fontStyle = 'normal';
        const extraAlign = window.getComputedStyle(cell).textAlign;
        if (extraAlign === 'right' || extraAlign === 'end') {
          data.cell.styles.halign = 'right';
        } else if (extraAlign === 'center') {
          data.cell.styles.halign = 'center';
        } else {
          data.cell.styles.halign = 'left';
        }
        return;
      }

      // 2. Parent group header rows: strip modus-icon text, keep label only
      if (cell.classList && cell.classList.contains('parent-row-cell')) {
        const clone = cell.cloneNode(true);
        clone.querySelectorAll('i').forEach(function (el) { el.remove(); });
        const label = clone.textContent.replace(/\s+/g, ' ').trim();
        data.cell.text = [label];
        data.cell.styles.fontStyle = 'bold';
        data.cell.styles.fillColor = [230, 230, 230];
        data.cell.styles.halign = 'left';
        return;
      }

      // 3. Image / material-overlay cells: clear text, reserve row height
      const img = cell.querySelector('img.fit-image');
      const overlay = cell.querySelector('.image-container .image-overlay');
      if (img || overlay) {
        data.cell.text = [''];
        data.row.height = 30;
        data.cell.styles.fillColor = [255, 255, 255];
        return;
      }

      // 4. All other body cells: white background
      if (data.section === 'body') {
        data.cell.styles.fillColor = [255, 255, 255];
      }

      // 5. Apply text alignment from computed style
      const align = window.getComputedStyle(cell).textAlign;
      if (align === 'right' || align === 'end') {
        data.cell.styles.halign = 'right';
      } else if (align === 'center') {
        data.cell.styles.halign = 'center';
      } else {
        data.cell.styles.halign = 'left';
      }

      // 6. Preserve font-weight (bold) from computed style
      const weight = window.getComputedStyle(cell).fontWeight;
      if (parseInt(weight) >= 600 || weight === 'bold') {
        data.cell.styles.fontStyle = 'bold';
      }

      // 7. Restore line breaks: autoTable parser strips \n from HTML.
      // Cells with white-space:pre-wrap store multi-line text as \n in text nodes.
      // Re-read via innerText which respects CSS white-space and actual rendering.
      if (data.section === 'body') {
        const rawText = cell.innerText !== undefined ? cell.innerText : cell.textContent;
        if (rawText && rawText.indexOf('\n') !== -1) {
          const lines = rawText.split('\n').map(function (l) { return l.trimEnd(); });
          // Remove trailing empty lines
          while (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();
          if (lines.length > 1) {
            data.cell.text = lines;
          }
        }
      }
    },
    didDrawCell: function (data) {
      const cell = data.cell.raw;
      if (!cell || typeof cell.querySelector !== 'function') return;

      const overlay = cell.querySelector('.image-container .image-overlay');
      const img = cell.querySelector('img.fit-image');

      if (overlay) {
        const rgb = parseRgb(window.getComputedStyle(overlay).backgroundColor);
        if (rgb) {
          const size = Math.min(data.cell.width - 6, data.cell.height - 6, 24);
          doc.setFillColor(rgb.r, rgb.g, rgb.b);
          doc.rect(
            data.cell.x + (data.cell.width - size) / 2,
            data.cell.y + (data.cell.height - size) / 2,
            size, size, 'F'
          );
        }
      } else if (img) {
        try {
          const imgData = getBase64Image(img, 256, 256, 2);
          const size = Math.min(data.cell.width - 6, data.cell.height - 6, 24);
          doc.addImage(
            imgData.dataURL,
            'PNG',
            data.cell.x + (data.cell.width - size) / 2,
            data.cell.y + (data.cell.height - size) / 2,
            size, size
          );
        } catch (e) {
          // ignore image draw errors (e.g. cross-origin)
        }
      }
    },
  });

  if (extraWasHidden) {
    extraRow.style.display = '';
  }

  doc.save('table.pdf');
}

function parseRgb(rgb) {
  if (!rgb) return null;
  const m = rgb.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  if (!m) return null;
  return { r: parseInt(m[1]), g: parseInt(m[2]), b: parseInt(m[3]) };
}

function getBase64Image(img, maxWidth, maxHeight, scaleFactor) {
  maxWidth = maxWidth || 512;
  maxHeight = maxHeight || 512;
  scaleFactor = scaleFactor || 2;

  let canvas = document.createElement('canvas');
  let width = img.width * scaleFactor;
  let height = img.height * scaleFactor;

  if (width > maxWidth * scaleFactor) {
    height = Math.round(height * (maxWidth * scaleFactor / width));
    width = maxWidth * scaleFactor;
  }
  if (height > maxHeight * scaleFactor) {
    width = Math.round(width * (maxHeight * scaleFactor / height));
    height = maxHeight * scaleFactor;
  }

  canvas.width = width;
  canvas.height = height;
  let ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0, width, height);
  let dataURL = canvas.toDataURL('image/png');

  return { dataURL: dataURL, width: width / scaleFactor, height: height / scaleFactor };
}