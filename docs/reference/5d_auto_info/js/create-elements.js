function createLi(liClass, liID, liOnclick, liContent) {
  const li = document.createElement("li");
  li.className = liClass;
  li.id = liID;
  li.onclick = liOnclick;
  li.textContent = liContent;
  return li;
}

function createDiv(divClass, divID) {
  const div = document.createElement("div");
  div.className = divClass;
  div.id = divID;
  return div;
}

function createSpan(spanClass, spanID, spanText) {
  const span = document.createElement("span");
  span.className = spanClass;
  span.id = spanID;
  span.textContent = spanText;
  return span;
}

function createLabel(labelClass, labelID, labelAttr, labelText) {
  const label = document.createElement("label");
  label.className = labelClass;
  label.id = labelID;
  label.setAttribute("for", labelAttr);
  label.textContent = labelText;
  return label;
}

function createInput(
  inputType,
  inputClass,
  inputID,
  inputDisable,
  inputValue,
  inputTrans = undefined
  ) {
  const input = document.createElement("input");
  input.type = inputType;
  input.className = inputClass;
  input.id = inputID;
  input.disabled = inputDisable;
  input.value = inputValue;
  if (inputTrans !== undefined) {
    input.setAttribute("data-translate", inputTrans);
  }
  return input;
}

function createButton(buttonClass, buttonID, buttonText, buttonTitle, buttonOnclick) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = buttonClass;
  button.id = buttonID;
  button.textContent = buttonText;
  button.title = buttonTitle;
  button.onclick = buttonOnclick;
  return button;
}

function createLink(linkText, linkDataKey, linkDataName, linkDataCut) {
  const a = document.createElement("a");
  a.className = "storey-item dropdown-item";
  a.href = "#";
  a.textContent = linkText;
  a.onclick = function () {
    selectStoreyItem(linkText, linkDataKey, linkDataName, linkDataCut);
  };
  return a;
}

function createI(iClass, ariaHidden, iText) {
  const i = document.createElement("i");
  i.className = iClass;
  i.setAttribute("aria-hidden", ariaHidden);
  i.textContent = iText;
  return i;
}

function createImg(imgSrc, imgWidth, imgHeight) {
  const img = document.createElement("img");
  img.src = imgSrc;
  img.width = imgWidth;
  img.height = imgHeight;
  img.onerror = function() { this.onerror = null; this.src = '../images/image.png'; };
  return img;
}

// TABLE ELEMENTS

function createTbody(tbodyClass, tbodyID) {
  const tbody = document.createElement("tbody");
  tbody.className = tbodyClass;
  tbody.id = tbodyID;
  return tbody;
}

function createTr(trClass, trID) {
  const tr = document.createElement("tr");
  tr.className = trClass;
  tr.id = trID;
  return tr;
}

function createTh(thClass, thID, thScope, thInnerText) {
  const th = document.createElement("th");
  th.className = thClass;
  th.id = thID;
  th.setAttribute("scope", thScope);
  th.innerText = thInnerText;
  return th;
}

function createTd(tdClass, tdID, tdScope, tdInnerText) {
  const td = document.createElement("td");
  td.className = tdClass;
  td.id = tdID;
  td.setAttribute("scope", tdScope);
  td.innerText = tdInnerText;
  return td;
}

function convertDataColor(colorString) {
  // Handle integer and float color input string
  let color;
  const match = colorString.match(
    /color\s*\(\s*([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\s*\)/,
  );

  if (match) {
    // Get color value for each channel
    const red = parseInt(match[1]);
    const green = parseInt(match[2]);
    const blue = parseInt(match[3]);
    // const alpha = parseInt(match[4]).toFixed(1); // Convert alpha from [0, 255] to [0, 1]
    const alphaColor = parseInt(match[4]); // Convert alpha from [0, 255] to [0, 1]
    let alpha;
    if (alphaColor > 1) {
      alpha = (alphaColor / 255).toFixed(1);
    } else {
      alpha = alphaColor;
    }
    color = `rgba(${red}, ${green}, ${blue}, ${alpha})`;
  }
  return color;
}
