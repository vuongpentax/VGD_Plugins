// Giao diện VGD Diagram: cây cấu kiện (bên trái) và mô hình 3D (bên phải).
// Ruby gọi VGD.onTree / onScene / onSuggested / onExport / onToast / onError; giao diện gọi sketchup.<tên>(JSON).
(function () {
  'use strict';
  var MAX_ORDER = 9999;
  var EXPLODE = 0.9;      // hệ số đẩy cụm ra khỏi tâm mô hình khi tách tự động (xem explodeDistance)
  var STAGGER = 0.35;     // giây giữa hai cấu kiện khi phát lắp ráp
  var DURATION = 0.7;     // giây để một cấu kiện lắp vào
  var PRESET_PHI = 1.1;   // độ cao camera khi chọn một góc nhìn có sẵn
  var AXES = {            // hướng tách cố định (SketchUp: Z hướng lên, Y là chiều sâu)
    front: [0, -1, 0], back: [0, 1, 0], left: [-1, 0, 0], right: [1, 0, 0], up: [0, 0, 1], down: [0, 0, -1]
  };
  var VIEWPOINTS = {      // góc nhìn có sẵn: góc phương vị của camera (theta)
    front_left: -3 * Math.PI / 4,
    front_right: -Math.PI / 4,
    back_left: 3 * Math.PI / 4,
    back_right: Math.PI / 4
  };
  // Style mặc định của SketchUp (giả lập): mặt xám trắng, cạnh đen, nền trắng khi xuất ảnh.
  var FACE_COLOR = 0xf2f2f0;
  var EDGE_COLOR = 0x1a1a1a;
  var HOT_COLOR = 0xe8a25e;   // màu tô sáng khi trỏ vào dòng cây
  var EDGE_ANGLE = 30;        // cạnh được vẽ khi hai mặt gấp nhau quá 30 độ
  var EXPORT_W = 1600;
  var EXPORT_H = 1200;
  var MAX_TAGS = 15;      // số nhãn tối đa trên một ảnh
  var PAST_COLOR = 0xcfcfcb; // màu cấu kiện đã lắp ở bước trước
  var VIDEO_W = 1280;
  var VIDEO_H = 720;
  var VIDEO_FPS = 30;
  var MOVE_SECONDS = 0.9;    // thời gian một cấu kiện bay vào chỗ
  var HOLD_SECONDS = 0.7;    // thời gian giữ hình sau mỗi bước
  var END_HOLD_SECONDS = 2;  // thời gian giữ hình lắp hoàn chỉnh ở cuối video
  var ARROW_UNTIL = 0.8;     // mũi tên hiện trong 80% đầu của mỗi bước
  var EXPORT_VIEWS = [
    { key: 'truoc', dir: [0, -1, 0], up: [0, 0, 1] },
    { key: 'phai', dir: [1, 0, 0], up: [0, 0, 1] },
    { key: 'tren', dir: [0, 0, 1], up: [0, 1, 0] },
    { key: 'iso', dir: [1, -1, 1], up: [0, 0, 1] }
  ];

  var pending = {};       // key -> chuỗi người dùng nhập (chưa lưu)
  var entries = {};       // key -> {input, original, mixed}: ô nhập thứ tự của từng nhóm
  var tree = document.getElementById('tree');
  var status = document.getElementById('status');
  var saveButton = document.getElementById('save');
  var slider = document.getElementById('explode');
  var sliderValue = document.getElementById('explode-value');
  var playButton = document.getElementById('play');
  var viewMessage = document.getElementById('view-msg');
  var canvas = document.getElementById('view');
  var emptyMessage = document.getElementById('empty');
  var imageFormat = document.getElementById('image-format');
  var ffmpegInput = document.getElementById('ffmpeg-path');
  var videoFormat = document.getElementById('video-format');
  var partSelect = document.getElementById('explode-part');
  var dirSelect = document.getElementById('explode-dir');
  var viewpointSelect = document.getElementById('viewpoint');
  var distanceInput = document.getElementById('explode-distance');
  var autoInput = document.getElementById('explode-auto');

  var view = null;        // khung 3D: renderer, scene, camera, parts, góc nhìn
  var playing = null;     // {start, count} khi đang phát lắp ráp
  var treeNodes = [];     // cây hiện tại (có số nhãn)
  var labelLayer = document.getElementById('labels');
  var labels = [];        // {el, part}: nhãn số đặt trên mô hình 3D
  var recording = false;  // đang quay video
  var imageMime = 'image/png'; // định dạng ảnh đang xuất (PNG hoặc JPEG)
  var explodeSettings = {};    // id cấu kiện -> {dir, distance}: hướng và khoảng cách tách riêng từng cụm

  function send(name, data) {
    if (window.sketchup && window.sketchup[name]) window.sketchup[name](JSON.stringify(data || {}));
  }

  function setStatus(text, isError) {
    status.textContent = text;
    status.className = isError ? 'status error' : 'status';
  }

  function setViewMessage(text) {
    viewMessage.textContent = text || '';
  }

  function updateSave() {
    saveButton.disabled = Object.keys(pending).length === 0;
  }

  function clamp(value, low, high) {
    return Math.min(Math.max(value, low), high);
  }

  // Trả về số thứ tự hợp lệ, '' khi để trống, hoặc null khi sai.
  function checkOrder(text) {
    var value = String(text).trim();
    if (value === '') return '';
    if (!/^\d+$/.test(value)) return null;
    var number = Number(value);
    return number >= 1 && number <= MAX_ORDER ? value : null;
  }

  // Ghi giá trị một ô nhập vào danh sách chưa lưu và đổi màu viền. Trả về true nếu hợp lệ.
  function applyOrder(entry, text) {
    var checked = checkOrder(text);
    entry.input.classList.toggle('invalid', checked === null);
    entry.input.classList.toggle('changed', checked !== null && checked !== entry.original);
    if (checked === null) {
      setStatus('Thứ tự phải là số từ 1 đến ' + MAX_ORDER + ', hoặc để trống.', true);
      return false;
    }
    if (checked === entry.original && !entry.mixed) delete pending[entry.key];
    else pending[entry.key] = checked;
    updateSave();
    return true;
  }

  // Mọi khóa của nhóm và các nhóm con (để tô sáng cả cụm khi trỏ vào).
  function idsOf(node) {
    var ids = node.ids.slice();
    (node.children || []).forEach(function (child) { ids = ids.concat(idsOf(child)); });
    return ids;
  }

  function renderNode(node, container) {
    var item = document.createElement('li');
    var row = document.createElement('div');
    row.className = 'row';

    var name = document.createElement('button');
    name.type = 'button';
    name.className = 'name';
    name.textContent = node.name;
    name.title = 'Chọn ' + node.name + ' trong model';
    name.onclick = function () { send('select', { key: node.key }); };
    name.onmouseenter = function () { highlight(idsOf(node)); };
    name.onmouseleave = function () { highlight(null); };

    var count = document.createElement('span');
    count.className = 'count';
    count.textContent = node.count > 1 ? '× ' + node.count : '';

    var order = document.createElement('input');
    order.type = 'text';
    order.inputMode = 'numeric';
    order.maxLength = 4;
    order.className = 'order';
    order.setAttribute('aria-label', 'Thứ tự lắp của ' + node.name);
    order.placeholder = node.mixed ? 'nhiều số' : '—';
    var original = node.order === null || node.order === undefined ? '' : String(node.order);
    order.value = original;
    var entry = { key: node.key, input: order, original: original, mixed: !!node.mixed };
    entries[node.key] = entry;
    order.oninput = function () {
      if (applyOrder(entry, order.value)) setStatus('');
    };

    var badge = null;
    if (node.number) {
      badge = document.createElement('span');
      badge.className = 'badge';
      badge.textContent = String(node.number);
    }
    row.append(badge || document.createTextNode(''), name, count, order);
    item.append(row);
    if (node.children && node.children.length) {
      var children = document.createElement('ul');
      node.children.forEach(function (child) { renderNode(child, children); });
      item.append(children);
    }
    container.append(item);
  }

  // ---------- Khung 3D ----------

  function createView() {
    if (view) return view;
    if (!window.THREE) {
      setViewMessage('Không tải được thư viện 3D (three.min.js).');
      return null;
    }
    var renderer;
    try {
      renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true, alpha: true });
    } catch (error) {
      setViewMessage('Máy này không mở được khung 3D (WebGL): ' + error.message);
      return null;
    }
    renderer.setClearColor(0x000000, 0);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    var scene = new THREE.Scene();
    scene.add(new THREE.AmbientLight(0xffffff, 0.75));
    var sun = new THREE.DirectionalLight(0xffffff, 0.7);
    sun.position.set(1, -2, 3);
    scene.add(sun);
    var camera = new THREE.PerspectiveCamera(35, 1, 1, 1e7);
    camera.up.set(0, 0, 1); // SketchUp dùng trục Z hướng lên
    view = {
      renderer: renderer,
      scene: scene,
      camera: camera,
      parts: [],
      center: new THREE.Vector3(),
      target: new THREE.Vector3(),
      dist: 5000,
      theta: 0.8,
      phi: 1.1
    };
    bindOrbit();
    resize();
    window.addEventListener('resize', resize);
    requestAnimationFrame(loop);
    return view;
  }

  function resize() {
    if (!view) return;
    var width = canvas.clientWidth;
    var height = canvas.clientHeight;
    if (!width || !height) return;
    view.renderer.setSize(width, height, false);
    view.camera.aspect = width / height;
    view.camera.updateProjectionMatrix();
  }

  function bindOrbit() {
    var drag = null;
    canvas.addEventListener('pointerdown', function (event) {
      drag = { x: event.clientX, y: event.clientY };
      canvas.setPointerCapture(event.pointerId);
    });
    canvas.addEventListener('pointermove', function (event) {
      if (!drag) return;
      view.theta -= (event.clientX - drag.x) * 0.008;
      view.phi = clamp(view.phi - (event.clientY - drag.y) * 0.008, 0.05, Math.PI - 0.05);
      drag = { x: event.clientX, y: event.clientY };
    });
    canvas.addEventListener('pointerup', function () { drag = null; });
    canvas.addEventListener('pointercancel', function () { drag = null; });
    canvas.addEventListener('wheel', function (event) {
      event.preventDefault();
      view.dist = clamp(view.dist * Math.exp(event.deltaY * 0.001), 50, 1e6);
    }, { passive: false });
  }

  function placeCamera() {
    var c = view.camera;
    var t = view.target;
    var d = view.dist;
    c.position.set(
      t.x + d * Math.sin(view.phi) * Math.cos(view.theta),
      t.y + d * Math.sin(view.phi) * Math.sin(view.theta),
      t.z + d * Math.cos(view.phi)
    );
    c.lookAt(t);
  }

  // Các nhóm có số nhãn (theo thứ tự cây).
  function numberedNodes(nodes, out) {
    nodes.forEach(function (node) {
      if (node.number) out.push(node);
      numberedNodes(node.children || [], out);
    });
    return out;
  }

  // Đặt nhãn số lên cấu kiện đầu tiên của mỗi nhóm có số.
  function rebuildLabels() {
    labelLayer.textContent = '';
    labels = [];
    if (!view) return;
    numberedNodes(treeNodes, []).forEach(function (node) {
      var part = view.parts.filter(function (p) { return node.ids.indexOf(p.id) !== -1; })[0];
      if (!part) return;
      var el = document.createElement('div');
      el.className = 'tag';
      el.textContent = String(node.number);
      labelLayer.append(el);
      labels.push({ el: el, part: part });
    });
  }

  // Đổi vị trí nhãn theo camera: nhãn ở sau camera thì ẩn.
  function updateLabels() {
    var width = canvas.clientWidth;
    var height = canvas.clientHeight;
    var anchor = new THREE.Vector3();
    labels.forEach(function (item) {
      anchor.copy(item.part.mesh.position).project(view.camera);
      var visible = anchor.z > -1 && anchor.z < 1;
      item.el.style.display = visible ? '' : 'none';
      if (!visible) return;
      item.el.style.left = ((anchor.x + 1) / 2 * width) + 'px';
      item.el.style.top = ((1 - anchor.y) / 2 * height) + 'px';
    });
  }

  function clearParts() {
    labelLayer.textContent = '';
    labels = [];
    if (!view) return;
    view.parts.forEach(function (part) {
      view.scene.remove(part.mesh);
      part.geometry.dispose();
      part.material.dispose();
      part.edges.geometry.dispose();
      part.edges.material.dispose();
    });
    view.parts = [];
    fillPartSelect();
  }

  function setModel(data) {
    if (!createView()) return;
    clearParts();
    playing = null;
    playButton.disabled = true;
    var parts = data.parts || [];
    if (parts.length === 0) {
      setViewMessage('Model chưa có hình học để hiển thị.');
      return;
    }
    var box = new THREE.Box3();
    var built = parts.map(function (item) {
      var geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(item.positions, 3));
      geometry.computeBoundingBox();
      box.union(geometry.boundingBox);
      return { data: item, geometry: geometry };
    });
    built.forEach(function (entry) {
      var center = entry.geometry.boundingBox.getCenter(new THREE.Vector3());
      entry.geometry.translate(-center.x, -center.y, -center.z);
      entry.geometry.computeVertexNormals();
      var material = new THREE.MeshLambertMaterial({ color: FACE_COLOR, side: THREE.DoubleSide });
      var mesh = new THREE.Mesh(entry.geometry, material);
      // Cạnh đen như SketchUp: vẽ các cạnh gấp góc lớn hơn EDGE_ANGLE độ.
      var edgeGeometry = new THREE.EdgesGeometry(entry.geometry, EDGE_ANGLE);
      var edgeMaterial = new THREE.LineBasicMaterial({ color: EDGE_COLOR });
      var edges = new THREE.LineSegments(edgeGeometry, edgeMaterial);
      mesh.add(edges);
      view.scene.add(mesh);
      view.parts.push({
        id: entry.data.id,
        order: entry.data.order,
        name: entry.data.name,
        mesh: mesh,
        geometry: entry.geometry,
        material: material,
        edges: edges,
        center: center,
        size: entry.geometry.boundingBox.getSize(new THREE.Vector3())
      });
    });
    view.target.copy(box.getCenter(new THREE.Vector3()));
    view.center.copy(view.target);
    // Lùi camera đủ xa để mô hình vẫn vừa khung khi đã tách rời hết.
    view.span = box.getSize(new THREE.Vector3()).length();
    view.dist = Math.max(view.span * 2.3, 500);
    setViewMessage(data.truncated ? 'Mô hình quá lớn: chỉ hiện một phần hình học.' : '');
    updatePlayButton();
    fillPartSelect();
    updatePositions();
    rebuildLabels();
  }

  // Vị trí t của một cấu kiện: 1 = đang tách hết, 0 = đã lắp. Khi phát lắp ráp thì theo thứ tự.
  function partT(part) {
    if (playing && part.rank !== undefined) {
      var elapsed = (performance.now() - playing.start) / 1000;
      var p = clamp((elapsed - part.rank * STAGGER) / DURATION, 0, 1);
      return (1 - p) * (1 - p);
    }
    return slider.value / 100;
  }

  // Cài đặt tách riêng của một cấu kiện: hướng ('auto', 'still' hoặc một trục) và khoảng cách mm (null = tự động).
  function settingsOf(part) {
    var key = String(part.id);
    if (!explodeSettings[key]) explodeSettings[key] = { dir: 'auto', distance: null };
    return explodeSettings[key];
  }

  // Hướng tách đơn vị. 'auto' là hướng từ tâm mô hình ra cụm; 'still' là không tách (trả về null).
  function explodeDirection(part, dir) {
    if (dir === 'still') return null;
    if (dir === 'auto') {
      var radial = part.center.clone().sub(view.center);
      return radial.lengthSq() > 1e-6 ? radial.normalize() : new THREE.Vector3(0, 0, 1);
    }
    var axis = AXES[dir];
    return new THREE.Vector3(axis[0], axis[1], axis[2]);
  }

  // Khoảng cách tách (mm) khi ở 100 %. Tự động: đẩy cụm ra khỏi tâm, cộng nửa kích thước
  // của chính cụm theo hướng tách (để không lọt vào cụm gần nó) và một khoảng hở nhỏ
  // (5 % kích thước mô hình) để cụm mỏng vẫn rời hẳn khỏi chỗ cũ.
  function explodeDistance(part, direction, setting) {
    if (setting.distance !== null) return setting.distance;
    var outward = part.center.clone().sub(view.center).dot(direction);
    var half = 0.5 * (Math.abs(part.size.x * direction.x) + Math.abs(part.size.y * direction.y) +
      Math.abs(part.size.z * direction.z));
    return EXPLODE * Math.max(0, outward) + half + 0.05 * view.span;
  }

  // Độ dịch chuyển của một cấu kiện với mức tách t (0 = đã lắp, 1 = tách hết).
  function explodedOffset(part, t) {
    var setting = settingsOf(part);
    var direction = explodeDirection(part, setting.dir);
    if (!direction || t <= 0) return new THREE.Vector3();
    return direction.multiplyScalar(explodeDistance(part, direction, setting) * t);
  }

  // Khoảng cách hiển thị (mm) của một cấu kiện: số nhập tay, hoặc số tính tự động.
  function displayDistance(part) {
    var setting = settingsOf(part);
    var direction = explodeDirection(part, setting.dir);
    return direction ? explodeDistance(part, direction, setting) : 0;
  }

  function updatePositions() {
    if (!view) return;
    view.parts.forEach(function (part) {
      part.mesh.position.copy(part.center).add(explodedOffset(part, partT(part)));
    });
    sliderValue.textContent = slider.value + ' %';
  }

  // ---------- Điều khiển tách: cụm, hướng, khoảng cách, góc nhìn ----------

  // Các cấu kiện đang được chỉnh: 'all' là tất cả, còn lại là chỉ số trong view.parts.
  function scopeParts() {
    if (!view) return [];
    if (partSelect.value === 'all') return view.parts;
    var part = view.parts[Number(partSelect.value)];
    return part ? [part] : [];
  }

  function fillPartSelect() {
    partSelect.textContent = '';
    var hasParts = !!view && view.parts.length > 0;
    if (hasParts) {
      partSelect.append(new Option('Tất cả', 'all'));
      view.parts.forEach(function (part, index) {
        partSelect.append(new Option((index + 1) + '. ' + (part.name || 'Cấu kiện'), String(index)));
      });
      partSelect.value = 'all';
    }
    partSelect.disabled = !hasParts;
    refreshExplodeControls();
  }

  // Đưa hướng tách, khoảng cách và ô tự động về đúng trạng thái của cụm đang chọn.
  function refreshExplodeControls() {
    var parts = scopeParts();
    var hasParts = parts.length > 0;
    dirSelect.disabled = !hasParts;
    distanceInput.disabled = !hasParts || autoInput.checked;
    autoInput.disabled = !hasParts;
    viewpointSelect.disabled = !view;

    var dirs = parts.map(function (part) { return settingsOf(part).dir; });
    var mixed = dirs.some(function (dir) { return dir !== dirs[0]; });
    var mixedOption = dirSelect.querySelector('option[value="mixed"]');
    if (mixed && !mixedOption) {
      mixedOption = new Option('Nhiều hướng', 'mixed');
      mixedOption.disabled = true;
      dirSelect.append(mixedOption);
    }
    if (!mixed && mixedOption) mixedOption.remove();
    dirSelect.value = mixed ? 'mixed' : (dirs[0] || 'auto');

    var autoAll = parts.every(function (part) { return settingsOf(part).distance === null; });
    var autoSome = parts.some(function (part) { return settingsOf(part).distance === null; });
    autoInput.checked = autoAll;
    autoInput.indeterminate = autoSome && !autoAll;
    // Một cụm: hiện đúng khoảng cách (mm). Nhiều cụm: để trống, vì mỗi cụm có số riêng.
    if (parts.length === 1) {
      distanceInput.value = String(Math.round(displayDistance(parts[0])));
      distanceInput.placeholder = '';
    } else {
      distanceInput.value = '';
      distanceInput.placeholder = autoAll ? 'Tự động' : 'Nhiều giá trị';
    }
    distanceInput.disabled = !hasParts || autoInput.checked;
  }

  // Áp dụng thay đổi cho cụm đang chọn; sau đó cập nhật ô và vị trí.
  function changeScope(change) {
    scopeParts().forEach(function (part) { change(settingsOf(part), part); });
    refreshExplodeControls();
    updatePositions();
  }

  function bindExplodeControls() {
    dirSelect.addEventListener('change', function () {
      if (dirSelect.value === 'mixed') return;
      changeScope(function (setting) { setting.dir = dirSelect.value; });
    });
    partSelect.addEventListener('change', refreshExplodeControls);
    autoInput.addEventListener('change', function () {
      if (autoInput.checked) {
        changeScope(function (setting) { setting.distance = null; });
        return;
      }
      // Bỏ tự động: lấy đúng khoảng cách hiện tại làm điểm xuất phát để nhập tay.
      changeScope(function (setting, part) { setting.distance = Math.round(displayDistance(part)); });
    });
    distanceInput.addEventListener('change', function () {
      var value = parseFloat(distanceInput.value);
      if (!isFinite(value) || value < 0) {
        refreshExplodeControls();
        return;
      }
      changeScope(function (setting) { setting.distance = value; });
    });
    viewpointSelect.addEventListener('change', function () {
      var theta = VIEWPOINTS[viewpointSelect.value];
      if (theta === undefined || !view) return;
      view.theta = theta;
      view.phi = PRESET_PHI;
    });
  }
  bindExplodeControls();

  function orderedParts() {
    return view ? view.parts.filter(function (part) { return part.order !== null && part.order !== undefined; })
      .sort(function (a, b) { return a.order - b.order; }) : [];
  }

  function updatePlayButton() {
    playButton.disabled = orderedParts().length === 0;
  }

  function stopPlayback() {
    if (!playing) return;
    playing = null;
    view.parts.forEach(function (part) { delete part.rank; });
    updatePlayButton();
  }

  function startPlayback() {
    var ordered = orderedParts();
    if (ordered.length === 0) {
      setViewMessage('Chưa có cấu kiện nào có thứ tự lắp. Nhập thứ tự ở cột bên trái.');
      return;
    }
    ordered.forEach(function (part, rank) { part.rank = rank; });
    playing = { start: performance.now(), count: ordered.length };
    playButton.disabled = true;
    setViewMessage('Đang phát lắp ráp theo thứ tự.');
  }

  function advancePlayback() {
    var finishAt = (playing.count - 1) * STAGGER + DURATION;
    if ((performance.now() - playing.start) / 1000 < finishAt) return;
    stopPlayback();
    slider.value = 0;
    setViewMessage('');
  }

  function highlight(ids) {
    if (!view) return;
    view.parts.forEach(function (part) {
      var on = !!ids && part.id !== null && part.id !== undefined && ids.indexOf(part.id) !== -1;
      part.material.color.setHex(on ? HOT_COLOR : FACE_COLOR);
    });
  }

  function loop() {
    requestAnimationFrame(loop);
    if (!view) return;
    if (playing) advancePlayback();
    placeCamera();
    view.camera.updateMatrixWorld();
    updatePositions();
    updateLabels();
    view.renderer.render(view.scene, view.camera);
  }

  // ---------- Xuất ảnh: góc chuẩn, cụm, từng bước ----------

  function padNumber(n) {
    return n < 10 ? '0' + n : String(n);
  }

  // Vẽ một nhãn số lên ảnh xuất (vị trí theo camera của ảnh đang xuất).
  function drawTag(ctx, camera, item) {
    var anchor = new THREE.Vector3().copy(item.part.mesh.position).project(camera);
    if (anchor.z < -1 || anchor.z > 1) return;
    var x = (anchor.x + 1) / 2 * EXPORT_W;
    var y = (1 - anchor.y) / 2 * EXPORT_H;
    ctx.beginPath();
    ctx.arc(x, y, 22, 0, Math.PI * 2);
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#B48963';
    ctx.stroke();
    ctx.fillStyle = '#222222';
    ctx.font = 'bold 24px Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(item.el.textContent, x, y + 1);
  }

  // Chú thích dưới ảnh (tên cụm hoặc bước).
  function drawCaption(ctx, text) {
    ctx.fillStyle = '#222222';
    ctx.font = 'bold 26px Arial, sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'bottom';
    ctx.fillText(text, 30, EXPORT_H - 24);
  }

  // Đặt mỗi cấu kiện ở vị trí lắp (t = 0) hoặc tách ra (t = 1). tFor(part) trả về 0 hoặc 1.
  function placeParts(tFor) {
    view.parts.forEach(function (part) {
      part.mesh.position.copy(part.center).add(explodedOffset(part, tFor(part)));
    });
  }

  function showParts(predicate) {
    view.parts.forEach(function (part) { part.mesh.visible = !!predicate(part); });
  }

  function colorParts(colorFor) {
    view.parts.forEach(function (part) { part.material.color.setHex(colorFor(part)); });
  }

  function restoreParts() {
    view.parts.forEach(function (part) {
      part.mesh.visible = true;
      part.material.color.setHex(FACE_COLOR);
    });
  }

  // Mũi tên từ vị trí tách ra tới vị trí lắp của cấu kiện (chiều lắp).
  function addArrow(part, arrows) {
    var from = part.mesh.position.clone();
    var direction = part.center.clone().sub(from);
    var length = direction.length();
    if (length < 1) return;
    var arrow = new THREE.ArrowHelper(direction.clone().normalize(), from, length * 0.9, HOT_COLOR,
      Math.min(length * 0.25, 150), Math.min(length * 0.12, 80));
    view.scene.add(arrow);
    arrows.push(arrow);
  }

  function clearArrows(arrows) {
    arrows.forEach(function (arrow) {
      view.scene.remove(arrow);
      arrow.line.geometry.dispose();
      arrow.line.material.dispose();
      arrow.cone.geometry.dispose();
      arrow.cone.material.dispose();
    });
    arrows.length = 0;
  }

  // Các số thứ tự đã đặt, tăng dần. Mỗi số là một bước lắp.
  function stepOrders() {
    var seen = {};
    view.parts.forEach(function (part) {
      if (part.order !== null && part.order !== undefined) seen[part.order] = true;
    });
    return Object.keys(seen).map(Number).sort(function (a, b) { return a - b; });
  }

  function orthoCamera(center, radius, dir, up, aspect) {
    aspect = aspect || EXPORT_W / EXPORT_H;
    var camera = new THREE.OrthographicCamera(-radius * aspect, radius * aspect, radius, -radius, 0.1, radius * 10);
    var direction = new THREE.Vector3().fromArray(dir).normalize();
    camera.up.fromArray(up);
    camera.position.copy(center).addScaledVector(direction, radius * 4);
    camera.lookAt(center);
    camera.updateMatrixWorld();
    return camera;
  }

  // Vẽ một ảnh: nền trắng, hình 3D, nhãn (nếu có) và chú thích (nếu có), rồi gửi về Ruby.
  function captureView(ctx, out, renderer, glCanvas, camera, key, tagItems, caption) {
    renderer.render(view.scene, camera);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, EXPORT_W, EXPORT_H);
    ctx.drawImage(glCanvas, 0, 0);
    tagItems.forEach(function (item) { drawTag(ctx, camera, item); });
    if (caption) drawCaption(ctx, caption);
    send('save_image', { key: key, data: out.toDataURL(imageMime, 0.92) });
  }

  // Cảnh báo về mô hình sơ đồ (dùng cho nút Kiểm tra và sau khi xuất).
  function diagramWarnings() {
    var warnings = [];
    var unassigned = labels.filter(function (item) { return item.part.order === null || item.part.order === undefined; }).length;
    if (unassigned) warnings.push(unassigned + ' nhóm chưa có thứ tự lắp.');
    if (labels.length > MAX_TAGS) warnings.push('Tổng quan có ' + labels.length + ' nhãn (tối đa ' + MAX_TAGS + '), nên xuất theo cụm.');
    stepOrders().forEach(function (k) {
      var count = labels.filter(function (item) { return item.part.order === k; }).length;
      if (count > MAX_TAGS) warnings.push('Bước ' + k + ' có ' + count + ' nhãn, nên tách bước.');
    });
    return warnings;
  }

  // Xuất: 4 góc chuẩn (tổng quan), từng cụm (iso), từng bước lắp (iso). Mỗi ảnh gửi về Ruby ghi ra file.
  function exportImages(format) {
    if (!view || view.parts.length === 0) {
      setStatus('Chưa có mô hình để xuất.', true);
      return;
    }
    imageMime = format === 'jpg' ? 'image/jpeg' : 'image/png';
    var renderer = null;
    var arrows = [];
    try {
      renderer = new THREE.WebGLRenderer({
        canvas: document.createElement('canvas'),
        antialias: true,
        preserveDrawingBuffer: true
      });
      renderer.setPixelRatio(1);
      renderer.setSize(EXPORT_W, EXPORT_H, false);
      renderer.setClearColor(0xffffff, 1);
      var glCanvas = renderer.domElement;
      var out = document.createElement('canvas');
      out.width = EXPORT_W;
      out.height = EXPORT_H;
      var ctx = out.getContext('2d');

      // 1. Tổng quan: bốn góc chuẩn theo trạng thái hiện tại của khung 3D.
      var box = new THREE.Box3();
      view.parts.forEach(function (part) { box.expandByObject(part.mesh); });
      var center = box.getCenter(new THREE.Vector3());
      var radius = Math.max(box.getSize(new THREE.Vector3()).length() / 2 * 1.1, 1);
      EXPORT_VIEWS.forEach(function (spec) {
        var camera = orthoCamera(center, radius, spec.dir, spec.up);
        captureView(ctx, out, renderer, glCanvas, camera, spec.key, labels, null);
      });

      // Khung chung cho cụm và bước: lấy theo bố cục đã tách, để mọi ảnh cùng tỉ lệ.
      placeParts(function () { return 1; });
      var exploded = new THREE.Box3();
      view.parts.forEach(function (part) { exploded.expandByObject(part.mesh); });
      var isoCenter = exploded.getCenter(new THREE.Vector3());
      var isoRadius = Math.max(exploded.getSize(new THREE.Vector3()).length() / 2 * 1.1, 1);
      var iso = orthoCamera(isoCenter, isoRadius, [1, -1, 1], [0, 0, 1]);

      // 2. Theo cụm: mỗi nhóm cấp đầu một ảnh, chỉ hiện cấu kiện của cụm đó ở vị trí lắp.
      treeNodes.forEach(function (node, index) {
        var ids = idsOf(node);
        var members = view.parts.filter(function (part) { return ids.indexOf(part.id) !== -1; });
        if (members.length === 0) return;
        placeParts(function () { return 0; });
        showParts(function (part) { return members.indexOf(part) !== -1; });
        colorParts(function () { return FACE_COLOR; });
        var tags = labels.filter(function (item) { return members.indexOf(item.part) !== -1; });
        captureView(ctx, out, renderer, glCanvas, iso, 'cum-' + padNumber(index + 1), tags, 'Cụm: ' + node.name);
        restoreParts();
      });

      // 3. Theo bước: mỗi số thứ tự là một bước. Đã lắp: xám; bước này: cam + mũi tên; chưa lắp: ẩn.
      stepOrders().forEach(function (k) {
        var isPast = function (part) { return part.order === null || part.order === undefined || part.order < k; };
        var isNow = function (part) { return part.order === k; };
        placeParts(function (part) { return isNow(part) ? 1 : 0; });
        showParts(function (part) { return isPast(part) || isNow(part); });
        colorParts(function (part) { return isNow(part) ? HOT_COLOR : PAST_COLOR; });
        view.parts.forEach(function (part) { if (isNow(part)) addArrow(part, arrows); });
        var names = view.parts.filter(isNow).map(function (part) { return part.name; });
        var unique = names.filter(function (name, i) { return names.indexOf(name) === i; });
        var caption = ('Bước ' + k + ': ' + unique.join(', ')).slice(0, 90);
        var tags = labels.filter(function (item) { return isNow(item.part); });
        captureView(ctx, out, renderer, glCanvas, iso, 'buoc-' + padNumber(k), tags, caption);
        clearArrows(arrows);
        restoreParts();
      });

      send('export_done');
      var warnings = diagramWarnings();
      setStatus('Đã xuất ảnh.' + (warnings.length ? ' Cảnh báo: ' + warnings.join(' ') : ''), warnings.length > 0);
    } catch (error) {
      setStatus('Xuất ảnh thất bại: ' + error.message, true);
    } finally {
      clearArrows(arrows);
      if (view) restoreParts();
      if (renderer) renderer.dispose();
    }
  }


  // ---------- Xuất video lắp ráp theo bước ----------

  // Định dạng WebM mà trình duyệt quay được. (MP4 không quay trực tiếp: dùng chuỗi khung PNG rồi ghép bằng ffmpeg.)
  function pickVideoType() {
    var candidates = ['video/webm;codecs=vp9', 'video/webm'];
    for (var i = 0; i < candidates.length; i++) {
      if (MediaRecorder.isTypeSupported(candidates[i])) return candidates[i];
    }
    return null;
  }

  // Khung iso theo bố cục đã tách, để mọi bước cùng tỉ lệ.
  function isoFrame(aspect) {
    placeParts(function () { return 1; });
    var box = new THREE.Box3();
    view.parts.forEach(function (part) { box.expandByObject(part.mesh); });
    var center = box.getCenter(new THREE.Vector3());
    var radius = Math.max(box.getSize(new THREE.Vector3()).length() / 2 * 1.1, 1);
    placeParts(function () { return 0; });
    return orthoCamera(center, radius, [1, -1, 1], [0, 0, 1], aspect);
  }

  // Chuẩn bị bộ vẽ video: renderer, canvas khung hình, camera iso. Trả về null nếu không xuất được (đã báo lỗi).
  function prepareVideo() {
    if (!view || view.parts.length === 0) {
      setStatus('Chưa có mô hình để xuất video.', true);
      return null;
    }
    // Cùng danh sách và cùng thứ tự với "Phát lắp ráp" trong khung 3D, để video khớp với bản xem trước.
    var ordered = orderedParts();
    if (ordered.length === 0) {
      setStatus('Chưa có bước lắp để xuất video. Nhập hoặc đề xuất thứ tự trước.', true);
      return null;
    }
    var renderer = new THREE.WebGLRenderer({
      canvas: document.createElement('canvas'),
      antialias: true,
      preserveDrawingBuffer: true
    });
    renderer.setPixelRatio(1);
    renderer.setSize(VIDEO_W, VIDEO_H, false);
    renderer.setClearColor(0xffffff, 1);
    var canvas = document.createElement('canvas');
    canvas.width = VIDEO_W;
    canvas.height = VIDEO_H;
    var finish = (ordered.length - 1) * STAGGER + DURATION;
    return {
      renderer: renderer,
      glCanvas: renderer.domElement,
      canvas: canvas,
      ctx: canvas.getContext('2d'),
      camera: isoFrame(VIDEO_W / VIDEO_H),
      arrows: [],
      arrowParts: [],
      ordered: ordered,
      finish: finish,
      total: finish + END_HOLD_SECONDS
    };
  }

  function disposeVideo(s) {
    clearArrows(s.arrows);
    if (view) restoreParts();
    s.renderer.dispose();
  }

  // Vị trí t của một cấu kiện ở thời điểm tVideo (giây), đúng công thức của "Phát lắp ráp":
  // cấu kiện có thứ tự bay vào theo thứ tự xếp hạng, cấu kiện chưa có thứ tự ở vị trí lắp.
  function videoT(part, s, tVideo) {
    var rank = s.ordered.indexOf(part);
    if (rank < 0) return 0;
    var p = clamp((tVideo - rank * STAGGER) / DURATION, 0, 1);
    return (1 - p) * (1 - p);
  }

  // Vẽ khung hình ở thời điểm t (giây) vào canvas của s, theo đúng chuyển động của bản xem trước.
  // Mũi tên và chú thích chỉ là phần thêm: mũi tên khi cấu kiện bắt đầu bay, chú thích là cấu kiện đang bay.
  function drawTimelineFrame(t, s) {
    placeParts(function (part) { return videoT(part, s, t); });
    showParts(function () { return true; });
    colorParts(function () { return FACE_COLOR; });

    var flying = s.ordered.filter(function (part) {
      var p = clamp((t - s.ordered.indexOf(part) * STAGGER) / DURATION, 0, 1);
      return p > 0 && p < 1;
    });
    var arrowing = s.ordered.filter(function (part) {
      var p = clamp((t - s.ordered.indexOf(part) * STAGGER) / DURATION, 0, 1);
      return p > 0 && p < ARROW_UNTIL;
    });
    var changed = arrowing.length !== s.arrowParts.length ||
      arrowing.some(function (part, i) { return part !== s.arrowParts[i]; });
    if (changed) {
      clearArrows(s.arrows);
      arrowing.forEach(function (part) { addArrow(part, s.arrows); });
      s.arrowParts = arrowing;
    }

    s.renderer.render(view.scene, s.camera);
    var ctx = s.ctx;
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, VIDEO_W, VIDEO_H);
    ctx.drawImage(s.glCanvas, 0, 0);
    labels.forEach(function (item) { drawTag(ctx, s.camera, item); });
    if (flying.length) {
      var names = flying.map(function (part) { return part.name; });
      var unique = names.filter(function (name, i) { return names.indexOf(name) === i; });
      drawCaption(ctx, ('Đang lắp: ' + unique.join(', ')).slice(0, 90));
    } else if (t >= s.finish) {
      drawCaption(ctx, 'Lắp ráp hoàn chỉnh');
    }
  }

  // Quay video (WebM hoặc MP4) bằng MediaRecorder theo thời gian thực.
  function exportVideo(format) {
    if (recording) return;
    if (format === 'png') {
      exportFrames();
      return;
    }
    if (!window.MediaRecorder || !HTMLCanvasElement.prototype.captureStream) {
      setStatus('Trình duyệt này không quay được video.', true);
      return;
    }
    var mime = pickVideoType();
    if (!mime) {
      setStatus('Trình duyệt này không quay được video WebM.', true);
      return;
    }
    var s = prepareVideo();
    if (!s) return;

    var chunks = [];
    var frameId = null;
    try {
      var recorder = new MediaRecorder(s.canvas.captureStream(VIDEO_FPS), { mimeType: mime, videoBitsPerSecond: 4000000 });
      recorder.ondataavailable = function (event) {
        if (event.data && event.data.size) chunks.push(event.data);
      };
      recorder.onstop = function () {
        recording = false;
        disposeVideo(s);
        var blob = new Blob(chunks, { type: mime.split(';')[0] });
        var reader = new FileReader();
        reader.onload = function () {
          send('save_video', { data: reader.result, ext: format });
          setStatus('Đã quay video lắp ráp (' + s.ordered.length + ' cấu kiện có thứ tự).');
        };
        reader.readAsDataURL(blob);
      };

      recording = true;
      var startedAt = performance.now();
      recorder.start();
      var tick = function (now) {
        var t = (now - startedAt) / 1000;
        if (t >= s.total) {
          recorder.stop();
          return;
        }
        drawTimelineFrame(t, s);
        frameId = requestAnimationFrame(tick);
      };
      frameId = requestAnimationFrame(tick);
      setStatus('Đang quay video lắp ráp...');
    } catch (error) {
      recording = false;
      if (frameId) cancelAnimationFrame(frameId);
      disposeVideo(s);
      setStatus('Quay video thất bại: ' + error.message, true);
    }
  }

  // Xuất chuỗi khung hình PNG đánh số (30 khung mỗi giây), để đổi sang MP4 bằng ffmpeg trên máy.
  // Không dùng MediaRecorder nên chạy được trên mọi phiên bản SketchUp.
  function exportFrames() {
    var s = prepareVideo();
    if (!s) return;
    var frameCount = Math.ceil(s.total * VIDEO_FPS);
    var index = 0;
    recording = true;
    setStatus('Đang xuất ' + frameCount + ' khung hình...');
    var next = function () {
      try {
        if (index >= frameCount) {
          recording = false;
          disposeVideo(s);
          send('video_done', { count: frameCount, fps: VIDEO_FPS });
          return;
        }
        drawTimelineFrame(index / VIDEO_FPS, s);
        send('save_frame', { index: index + 1, data: s.canvas.toDataURL('image/png') });
        index += 1;
        setTimeout(next, 0);
      } catch (error) {
        recording = false;
        disposeVideo(s);
        setStatus('Xuất khung hình thất bại: ' + error.message, true);
      }
    };
    next();
  }

  // ---------- Cầu nối với Ruby ----------

  window.VGD = {
    onTree: function (data) {
      pending = {};
      entries = {};
      updateSave();
      tree.textContent = '';
      var nodes = data.nodes || [];
      treeNodes = nodes;
      rebuildLabels();
      emptyMessage.textContent = data.message || 'Model chưa có nhóm hoặc component nào.';
      emptyMessage.hidden = nodes.length > 0 && !data.message;
      nodes.forEach(function (node) { renderNode(node, tree); });
      if (!data.message) setStatus('');
    },
    onScene: function (data) {
      setModel(data);
    },
    onSuggested: function (data) {
      var count = 0;
      (data.changes || []).forEach(function (change) {
        var entry = entries[change.key];
        if (!entry) return;
        entry.input.value = String(change.order);
        if (applyOrder(entry, entry.input.value)) count += 1;
      });
      setStatus('Đã đề xuất thứ tự cho ' + count + ' nhóm (từ dưới lên, theo từng lớp). Kiểm tra rồi bấm Lưu thứ tự.');
    },
    onExport: function (data) {
      exportImages(data.format || 'png');
    },
    onVideo: function (data) {
      exportVideo(data.format || 'webm');
    },
    onSettings: function (data) {
      ffmpegInput.value = data.ffmpegPath || '';
    },
    onVersion: function (data) {
      document.getElementById('ver').textContent = 'Phiên bản ' + data.version;
    },
    onToast: function (data) { setStatus(data.message, false); },
    onError: function (data) { setStatus(data.message, true); }
  };

  window.VGD.refresh = function () { send('refresh'); };
  window.VGD.suggestOrders = function () { send('suggest_orders'); };
  window.VGD.exportSvg = function () { send('export'); };
  window.VGD.exportViews = function () { send('export_views', { format: imageFormat.value }); };
  window.VGD.exportVideo = function () { send('export_video', { format: videoFormat.value }); };
  window.VGD.saveFfmpeg = function () { send('save_ffmpeg', { path: ffmpegInput.value }); };
  window.VGD.pickFfmpeg = function () { send('pick_ffmpeg'); };
  window.VGD.checkDiagram = function () {
    var warnings = diagramWarnings();
    setStatus(warnings.length ? 'Cảnh báo: ' + warnings.join(' ') : 'Không có cảnh báo.', warnings.length > 0);
  };
  window.VGD.saveOrders = function () {
    var items = Object.keys(pending).map(function (key) {
      var value = pending[key];
      return { key: Number(key), order: value === '' ? null : Number(value) };
    });
    if (items.length === 0) return;
    send('save_orders', { changes: items });
    pending = {};
    updateSave();
  };
  window.VGD.play = function () {
    if (!view) return;
    startPlayback();
  };
  window.VGD.reset = function () {
    stopPlayback();
    slider.value = 0;
    setViewMessage('');
  };

  // Chỉ dùng để kiểm thử tự động (dev/test_ui.cjs): trả về vị trí các mảnh và trạng thái phát.
  window.VGD.__debug = function () {
    return {
      parts: view ? view.parts.length : 0,
      positions: view ? view.parts.map(function (part) {
        return [part.mesh.position.x, part.mesh.position.y, part.mesh.position.z];
      }) : [],
      playing: !!playing,
      slider: Number(slider.value),
      labels: labels.length,
      ordered: orderedParts().map(function (part) { return part.id; }),
      // Vị trí camera so với tâm nhìn, và độ dịch chuyển của từng cụm khi tách hết (100 %).
      camera: view ? [
        view.camera.position.x - view.target.x,
        view.camera.position.y - view.target.y,
        view.camera.position.z - view.target.z
      ] : [],
      offsets: view ? view.parts.map(function (part) {
        var offset = explodedOffset(part, 1);
        return [offset.x, offset.y, offset.z];
      }) : []
    };
  };

  slider.addEventListener('input', function () {
    stopPlayback();
    updatePositions();
  });

  VGDTheme.start({ key: 'vgd.diagram.theme', button: document.getElementById('theme') });
  send('ready');
})();
