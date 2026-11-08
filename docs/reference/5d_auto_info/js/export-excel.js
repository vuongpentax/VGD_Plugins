async function exportExcel() {
  const table = document.getElementById("myTable");
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet("Sheet1");
  const colWidthsInPixels = getHtmlColumnWidthsInPixels(table);

  // Set column widths
  let excelColIndex = 1;
  colWidthsInPixels.forEach((pixel) => {
    if (pixel !== 0) {
      const excelWidth = pixelsToColumnWidth(pixel);
      sheet.getColumn(excelColIndex++).width = excelWidth;
    }
  });

  const headerRowHeight = convertExcelHeight(20);
  const imageColumnWidth = 11;
  const imageRowHeight = convertExcelHeight(66);
  const defaultImageWidth = 80;
  const defaultImageHeight = 80;

  const imageColIndexes = new Set();
  let totalVisibleColumns = 0;

  // ===== 1. Header Row =====
  const headerCells = table.getElementsByTagName('th');
  if (headerCells.length > 0) {
    const headerRowData = [];
    const headerAlignments = [];
    let visibleColIndex = 0;

    for (let i = 0; i < headerCells.length; i++) {
      const headerCell = headerCells[i];
      if (getComputedStyle(headerCell).display === 'none') continue;

      const columnName = headerCell.textContent.trim();
      const textAlign = getComputedStyle(headerCell).textAlign;
      const isImage = headerCell.querySelector('img') || headerCell.id.includes("image");
      if (isImage) imageColIndexes.add(visibleColIndex);

      headerRowData.push(columnName);
      headerAlignments.push(textAlign);
      visibleColIndex++;
    }
    totalVisibleColumns = visibleColIndex;

    const addedHeaderRow = sheet.addRow(headerRowData);
    addedHeaderRow.height = headerRowHeight;

    for (let i = 0; i < addedHeaderRow.cellCount; i++) {
      const cell = addedHeaderRow.getCell(i + 1);
      if (imageColIndexes.has(i)) {
        sheet.getColumn(i + 1).width = imageColumnWidth;
      }
      cell.font = {
        bold: true,
        name: 'Calibri',
        size: 11,
      };
      cell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFE1E1E1' }
      };
      cell.alignment = {
        horizontal: mapTextAlign(headerAlignments[i]),
        vertical: 'middle'
      };
    }
  }

  // ===== 2. Extra Row =====
  const extraRow = table.querySelector("#extra");
  if (extraRow) {
    const extraRowData = [];
    const extraAlignments = [];
    const extraCells = extraRow.getElementsByTagName('td');

    for (let i = 0, visibleCol = 0; i < extraCells.length - 2; i++) {
      const extraCell = extraCells[i];
      if (getComputedStyle(extraCell).display === 'none') continue;

      const textAlign = getComputedStyle(extraCell).textAlign;
      const value = extraCell.tagName === 'TEXTAREA'
        ? convertToExcelFormat(extraCell.value.trim())
        : extraCell.textContent.trim();

      extraRowData.push(value);
      extraAlignments.push(textAlign);
      visibleCol++;
    }

    if (extraRowData.some(v => v !== '')) {
      const addedExtraRow = sheet.addRow(extraRowData);

      for (let i = 0; i < addedExtraRow.cellCount; i++) {
        const cell = addedExtraRow.getCell(i + 1);
        cell.font = {
          name: 'Calibri',
          italic: true,
        };
        cell.alignment = {
          horizontal: mapTextAlign(extraAlignments[i]),
          vertical: 'middle'
        };
      }
    }
  }

  // ===== 3. Body Rows =====
  const bodyRows = table.getElementsByTagName('tbody')[0].getElementsByTagName('tr');
  for (let i = 0; i < bodyRows.length; i++) {
    const bodyRow = bodyRows[i];
    const bodyCells = bodyRow.getElementsByTagName("td");
    const bodyRowData = [];
    const bodyAlignments = [];
    const imageInfo = [];

    const isParentRow = bodyRow.classList.contains('parent-row');
    const hasImage = rowHasImage(bodyCells);

    for (let j = 0, excelCol = 0; j < bodyCells.length; j++) {
      const bodyCell = bodyCells[j];
      if (getComputedStyle(bodyCell).display === 'none') continue;

      const textAlign = getComputedStyle(bodyCell).textAlign;
      const img = bodyCell.querySelector("img");

      if (img) {
        try {
          const { base64 } = await getImageBase64(img);
          bodyRowData.push({ __imgBase64: base64 });
          imageInfo.push(excelCol);
        } catch (err) {
          console.warn("Image load error:", err);
          bodyRowData.push(bodyCell.textContent.trim());
        }
      } else {
        let value;
        if (isParentRow) {
          const clone = bodyCell.cloneNode(true);
          clone.querySelectorAll('i').forEach(el => el.remove());
          value = clone.textContent.trim();
        } else {
          value = bodyCell.textContent.trim();
          if (!containsNonNumeric(bodyCell)) {
            const parsed = parseNumberWithDelimiter(value);
            value = isNaN(parsed) ? value : parsed;
          }
        }
        bodyRowData.push(value);
      }

      bodyAlignments.push(textAlign);
      excelCol++;
    }

    const cleanedBodyRowData = bodyRowData.map(cell =>
      typeof cell === 'object' && cell.__imgBase64 ? null : cell
    );
    const addedBodyRow = sheet.addRow(cleanedBodyRowData);
    // console.log('hasImage', hasImage);
    addedBodyRow.height = hasImage ? imageRowHeight : null;

    const cellCount = isParentRow ? totalVisibleColumns : addedBodyRow.cellCount;
    for (let i = 0; i < cellCount; i++) {
      const cell = addedBodyRow.getCell(i + 1);
      cell.font = { name: 'Calibri' };
      cell.alignment = {
        wrapText: true,
        horizontal: mapTextAlign(bodyAlignments[i] || 'left'),
        vertical: 'top',
      };
      if (isParentRow) {
        cell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FFE1E1E1' }
        };
      }
    }

    imageInfo.forEach((colIndex, j) => {
      const base64 = bodyRowData[colIndex].__imgBase64;
      const imageId = workbook.addImage({
        base64: `data:image/png;base64,${base64}`,
        extension: 'png',
      });

      const colWidth = sheet.getColumn(colIndex + 1).width || imageColumnWidth;
      const colPixels = columnWidthToPixels(colWidth);
      const rowPixels = imageRowHeight * (4 / 3);

      const offsetXInPixels = 5; // Fixed padding from left in pixels
      const offsetXRatio = offsetXInPixels / colPixels;
      const tlCol = colIndex + offsetXRatio;

      const offsetY = Math.max((rowPixels - defaultImageHeight) / 2, 0);
      const tlRow = addedBodyRow.number - 1 + (offsetY / rowPixels);

      sheet.addImage(imageId, {
        tl: { col: tlCol, row: tlRow },
        ext: { width: defaultImageWidth, height: defaultImageHeight }
      });
    });
  }

  // ===== 4. Footer Row =====
  const footerRow = document.getElementById("totalRow");
  if (footerRow) {
    const footerCells = footerRow.getElementsByTagName("td");
    const footerRowData = [];
    const footerAlignments = [];

    for (let i = 0; i < footerCells.length; i++) {
      const footerCell = footerCells[i];
      if (getComputedStyle(footerCell).display === 'none') continue;

      const textAlign = getComputedStyle(footerCell).textAlign;
      let value = footerCell.textContent.trim();
      if (!containsNonNumeric(footerCell)) {
        const parsed = parseNumberWithDelimiter(value);
        value = isNaN(parsed) ? value : parsed;
      }
      footerRowData.push(value);
      footerAlignments.push(textAlign);
    }

    const addedFooterRow = sheet.addRow(footerRowData);
    for (let i = 0; i < addedFooterRow.cellCount; i++) {
      const cell = addedFooterRow.getCell(i + 1);
      cell.font = { size: 14, bold: true };
      cell.alignment = {
        horizontal: mapTextAlign(footerAlignments[i]),
        vertical: 'middle',
      };
    }
  }

  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob([buffer], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  saveAs(blob, "exported_info.xlsx");

  if (typeof completeExport === 'function') completeExport();
}

function mapTextAlign(align) {
  if (align === 'left' || align === 'start') return 'left';
  if (align === 'right' || align === 'end') return 'right';
  if (align === 'center') return 'center';
  return 'left'; // fallback
}

function rowHasImage(cells) {
  return Array.from(cells).some(cell => {
    if (getComputedStyle(cell).display === 'none') return false;
    return cell.querySelector('img');
  });
}

function convertExcelHeight(heightInExcelUI) {
  return heightInExcelUI * 1.5;
}

function columnWidthToPixels(width) {
  return Math.floor(7 * width);
}

function pixelsToColumnWidth(pixels) {
  return Math.round(pixels / 7);
}

function getHtmlColumnWidthsInPixels(table) {
  const firstRow = table.querySelector('tr');
  const colWidths = [];

  if (!firstRow) return colWidths;

  const cells = firstRow.querySelectorAll('th, td');
  for (let cell of cells) {
    if (getComputedStyle(cell).display === 'none') continue;
    const style = getComputedStyle(cell);
    const width = cell.offsetWidth
      + parseFloat(style.marginLeft)
      + parseFloat(style.marginRight);
    colWidths.push(width);
  }

  return colWidths;
}

function containsNonNumeric(cell) {
  const validCharacters = '0123456789.,';
  for (let char of cell.textContent) {
    if (!validCharacters.includes(char)) {
      return true;
    }
  }
  return false;
}

function parseNumberWithDelimiter(stringNumber) {
  const decimalDelimiter = document.getElementById("decimalSeparator").value;
  let thousandSeparator, decimalSeparator;

  if (decimalDelimiter === ',') {
    thousandSeparator = '.';
    decimalSeparator = ',';
  } else {
    thousandSeparator = ',';
    decimalSeparator = '.';
  }

  return parseFloat(
    stringNumber
      .replace(new RegExp('\\' + thousandSeparator, 'g'), '')
      .replace(new RegExp('\\' + decimalSeparator), '.')
  );
}

function getImageBase64(img) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.crossOrigin = 'anonymous';
    image.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(image, 0, 0);
      const dataURL = canvas.toDataURL('image/png');
      resolve({ base64: dataURL.split(',')[1], width: canvas.width, height: canvas.height });
    };
    image.onerror = reject;
    image.src = img.src;
  });
}