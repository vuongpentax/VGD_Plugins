let cell;
let object_id;
let key;

function updateTableImage(folder, file_name) {
  const table = document.getElementById("myTable");
  let images = table.getElementsByTagName("img");
  let objectId;

  // Decode file name back to normal
  let fileName = file_name.replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">");

  if (fileName.includes("material") && !fileName.includes("color")) {
    let materialName = fileName.replace(/^auto_info_material_/, "").replace(/\.png$/, "");
    for (let i = 0; i < images.length; i++) {
      let img = images[i];

      const tr = img.closest('tr');
      const tdMaterial = tr.querySelector('td[id*="material"]');
      materialText = sanitizeFileName(tdMaterial.textContent);

      if (tdMaterial && materialText === materialName) {
        img.src = folder + "/" + fileName;
        img.style.width = "128px";
        img.style.height = "128px";
        img.style.objectFit = "cover";
        img.style.objectPosition = "center";
        objectId = img.id.split("-")[0];

        sketchup.changeValue(objectId, 'image', img.src.replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">"));
        break;
      };
    };
  } else if (fileName.includes("material") && fileName.includes("color")) {
    let materialName = fileName.replace("auto_info_material_", '').replace(/_color\(\d+,\d+,\d+,\d+\)\.png$/, '');
    let colorName = fileName.replace(/^auto_info_/, "").replace(/\.png$/, "");
    let colorRGB = convertDataColor(colorName);

    for (let i = 0; i < images.length; i++) {
      let img = images[i];

      let tr = img.closest('tr');
      let tdMaterial = tr.querySelector('td[id*="material"]');

      if (tdMaterial && tdMaterial.textContent === materialName) {
        let imgContainer = img.closest('div');
        imgContainer.style.background = colorRGB;

        img.src = folder + "/" + fileName;
        img.src = folder + "/" + fileName;
        img.style.width = "128px";
        img.style.height = "128px";
        img.style.objectFit = "cover";
        img.style.objectPosition = "center";
        objectId = img.id.split("-")[0];
        sketchup.changeValue(objectId, 'image', img.src.replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">"));
        break;
      };
    };
  } else {
    if (fileName.includes("current")) {
      objectId = fileName.replace("auto_info_current_", "").replace(/_\d{14}\.png$/, "");
    } else {
      objectId = fileName.replace("auto_info_", "").replace(/_\d{14}\.png$/, "");
    }

    for (let i = 0; i < images.length; i++) {
      let img = images[i];

      if (img.id.includes(objectId)) {
        img.src = folder + "/" + fileName;

        sketchup.changeValue(objectId, 'image', img.src.replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">"));
        break; // Stop the loop if matched
      };
    };
  }
};

function updateTableImages(folder, file_names) {
  const table = document.getElementById("myTable");
  let images = table.getElementsByTagName("img");

  for (let i = 0; i < images.length; i++) {
    let img = images[i];

    for (let j = 0; j < file_names.length; j++) {
      // Decode file name back to normal
      let fileName = file_names[j].replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">");

      let objectId;

      if (fileName.includes("material") && !fileName.includes("color")) {
        let materialName = fileName.replace(/^auto_info_material_/, "").replace(/\.png$/, "");

        let tr = img.closest('tr');
        let tdMaterial = tr.querySelector('td[id*="material"]');

        if (tdMaterial && tdMaterial.textContent === materialName) {
          img.src = folder + "/" + fileName;
          img.style.width = "128px";
          img.style.height = "128px";
          img.style.objectFit = "cover";
          img.style.objectPosition = "center";
          objectId = img.id.split("-")[0];

          sketchup.changeValue(objectId, 'image', img.src.replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">"));
          break;
        };
      } else if ((fileName.includes("material") && fileName.includes("color"))) {
        let materialName = fileName.replace("auto_info_material_", '').replace(/_color\(\d+,\d+,\d+,\d+\)\.png$/, '');
        let colorName = fileName.replace(/^auto_info_/, "").replace(/\.png$/, "");
        let colorRGB = convertDataColor(colorName);

        let tr = img.closest('tr');
        let tdMaterial = tr.querySelector('td[id*="material"]');

        if (tdMaterial && tdMaterial.textContent === materialName) {
          let imgContainer = img.closest('div');
          imgContainer.style.backgroundColor = colorRGB;

          img.src = folder + "/" + fileName;
          img.src = folder + "/" + fileName;
          img.style.width = "128px";
          img.style.height = "128px";
          img.style.objectFit = "cover";
          img.style.objectPosition = "center";
          objectId = img.id.split("-")[0];

          sketchup.changeValue(objectId, 'image', img.src.replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">"));
          break;
        };
      } else {
        if (fileName.includes("current")) {
          objectId = fileName.replace("auto_info_current_", "").replace(/_\d{14}\.png$/, "");
        } else {
          objectId = fileName.replace("auto_info_", "").replace(/_\d{14}\.png$/, "");
        }

        if (img.id.includes(objectId)) {
          img.src = folder + "/" + fileName;

          sketchup.changeValue(objectId, 'image', img.src.replace(/%ma/g, "#").replace(/%mb/g, "<").replace(/%mc/g, ">"));
          break; // Stop the loop if matched
        };
      }
    };

    if (i == images.length - 1) {
      $("#waitAllImagesModal").modal("hide");
      const modalID = "waitAllImagesModal";
      force_hide_modal(modalID);
    }
  };
};

function updateImageStyle(img, folder, fileName) {
  img.src = folder + "/" + fileName;
  img.style.width = "128px";
  img.style.height = "128px";
  img.style.objectFit = "cover";
  img.style.objectPosition = "center";
}

function updateMenuPosition(dataCell, selectContainer) {
  const menuHeight = selectContainer.offsetHeight;

  const cellRect = dataCell.getBoundingClientRect();
  const calculatedY = cellRect.bottom + window.scrollY;

  // Get the viewport dimensions
  const dialogHeight = window.innerHeight;
  const windowBottom = dialogHeight - 70;

  // Adjust menu height
  if (calculatedY + menuHeight > windowBottom) {
    selectContainer.style.maxHeight = `${windowBottom - calculatedY}px`;
  } else {
    selectContainer.style.maxHeight = "600px";
  }
}

function sanitizeFileName(str) {
  // Ignore special characters not accept in Windows file
  let new_str = str.replace(/[<>:"/\\|?*]/g, '');
  return new_str;
}

function force_hide_modal(modalID) {
  const modal = document.getElementById(modalID);
  const modalOverlay = document.querySelector(".modal-backdrop");

  // Hide modal
  modal.style.display = "none";
  modal.classList.remove("show");
  modal.classList.add("hide");

  // Hide backdrop
  if (modalOverlay) {
    modalOverlay.classList.remove("show");
    modalOverlay.classList.remove("fade");
    modalOverlay.classList.add("hide");
    modalOverlay.remove();
  }
}


