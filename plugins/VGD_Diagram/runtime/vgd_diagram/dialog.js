// Giao diện VGD Diagram: cây cấu kiện (bên trái) và mô hình 3D (bên phải).
// Ruby gọi VGD.onTree / onScene / onSuggested / onExport / onToast / onError; giao diện gọi sketchup.<tên>(JSON).
(function () {
  'use strict';
  var MAX_ORDER = 9999;
  var EXPLODE = 0.9;      // mức tách tối đa: cấu kiện cách tâm mô hình thêm 90% khoảng cách của nó
  var STAGGER = 0.35;     // giây giữa hai cấu kiện khi phát lắp ráp
  var DURATION = 0.7;     // giây để một cấu kiện lắp vào
  // Style mặc định của SketchUp (giả lập): mặt xám trắng, cạnh đen, nền trắng khi xuất ảnh.
  var FACE_COLOR = 0xf2f2f0;
  var EDGE_COLOR = 0x1a1a1a;
  var HOT_COLOR = 0xe8a25e;   // màu tô sáng khi trỏ vào dòng cây
  var EDGE_ANGLE = 30;        // cạnh được vẽ khi hai mặt gấp nhau quá 30 độ
  var EXPORT_W = 1600;
  var EXPORT_H = 1200;
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

  var view = null;        // khung 3D: renderer, scene, camera, parts, góc nhìn
  var playing = null;     // {start, count} khi đang phát lắp ráp
  var treeNodes = [];     // cây hiện tại (có số nhãn)
  var labelLayer = document.getElementById('labels');
  var labels = [];        // {el, part}: nhãn số đặt trên mô hình 3D

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
        center: center
      });
    });
    view.target.copy(box.getCenter(new THREE.Vector3()));
    view.center.copy(view.target);
    // Lùi camera đủ xa để mô hình vẫn vừa khung khi đã tách rời hết.
    view.dist = Math.max(box.getSize(new THREE.Vector3()).length() * 2.3, 500);
    setViewMessage(data.truncated ? 'Mô hình quá lớn: chỉ hiện một phần hình học.' : '');
    updatePlayButton();
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

  function updatePositions() {
    if (!view) return;
    view.parts.forEach(function (part) {
      var offset = part.center.clone().sub(view.center).multiplyScalar(EXPLODE * partT(part));
      part.mesh.position.copy(part.center).add(offset);
    });
    sliderValue.textContent = slider.value + ' %';
  }

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

  // ---------- Xuất ảnh các góc ----------

  // Vẽ nhãn số lên ảnh xuất (vị trí theo camera của góc đang xuất).
  function drawTags(ctx, camera) {
    var anchor = new THREE.Vector3();
    labels.forEach(function (item) {
      anchor.copy(item.part.mesh.position).project(camera);
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
    });
  }

  // Vẽ bốn góc chuẩn bằng phối cảnh song song (camera trực giao), rồi gửi từng ảnh về Ruby ghi ra file.
  // Ảnh theo trạng thái khung 3D hiện tại (kể cả mức tách rời).
  function exportImages() {
    if (!view || view.parts.length === 0) {
      setStatus('Chưa có mô hình để xuất.', true);
      return;
    }
    var renderer = null;
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

      var box = new THREE.Box3();
      view.parts.forEach(function (part) { box.expandByObject(part.mesh); });
      var center = box.getCenter(new THREE.Vector3());
      var radius = Math.max(box.getSize(new THREE.Vector3()).length() / 2 * 1.1, 1);
      var aspect = EXPORT_W / EXPORT_H;

      EXPORT_VIEWS.forEach(function (spec) {
        var camera = new THREE.OrthographicCamera(-radius * aspect, radius * aspect, radius, -radius, 0.1, radius * 10);
        var dir = new THREE.Vector3().fromArray(spec.dir).normalize();
        camera.up.fromArray(spec.up);
        camera.position.copy(center).addScaledVector(dir, radius * 4);
        camera.lookAt(center);
        camera.updateMatrixWorld();
        renderer.render(view.scene, camera);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, EXPORT_W, EXPORT_H);
        ctx.drawImage(glCanvas, 0, 0);
        drawTags(ctx, camera);
        send('save_image', { key: spec.key, data: out.toDataURL('image/png') });
      });
      send('export_done');
      setStatus('Đã xuất ảnh các góc.');
    } catch (error) {
      setStatus('Xuất ảnh thất bại: ' + error.message, true);
    } finally {
      if (renderer) renderer.dispose();
    }
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
    onExport: function () {
      exportImages();
    },
    onToast: function (data) { setStatus(data.message, false); },
    onError: function (data) { setStatus(data.message, true); }
  };

  window.VGD.refresh = function () { send('refresh'); };
  window.VGD.suggestOrders = function () { send('suggest_orders'); };
  window.VGD.exportSvg = function () { send('export'); };
  window.VGD.exportViews = function () { send('export_views'); };
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
      labels: labels.length
    };
  };

  slider.addEventListener('input', function () {
    stopPlayback();
    updatePositions();
  });

  VGDTheme.start({ key: 'vgd.diagram.theme', button: document.getElementById('theme') });
  send('ready');
})();
