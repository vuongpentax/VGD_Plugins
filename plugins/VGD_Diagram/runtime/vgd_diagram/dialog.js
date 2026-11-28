// Giao diện VGD Diagram. Ruby gọi VGD.onTree / onToast / onError; giao diện gọi sketchup.<tên>(JSON).
(function () {
  'use strict';
  var MAX_ORDER = 9999;
  var pending = {};       // key -> chuỗi người dùng nhập (chưa lưu)
  var tree = document.getElementById('tree');
  var status = document.getElementById('status');
  var saveButton = document.getElementById('save');

  function send(name, data) {
    if (window.sketchup && window.sketchup[name]) window.sketchup[name](JSON.stringify(data || {}));
  }

  function setStatus(text, isError) {
    status.textContent = text;
    status.className = isError ? 'status error' : 'status';
  }

  function updateSave() {
    saveButton.disabled = Object.keys(pending).length === 0;
  }

  // Trả về số thứ tự hợp lệ, '' khi để trống, hoặc null khi sai.
  function checkOrder(text) {
    var value = String(text).trim();
    if (value === '') return '';
    if (!/^\d+$/.test(value)) return null;
    var number = Number(value);
    return number >= 1 && number <= MAX_ORDER ? value : null;
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
    order.value = node.order === null || node.order === undefined ? '' : String(node.order);
    order.oninput = function () {
      var checked = checkOrder(order.value);
      var original = node.order === null || node.order === undefined ? '' : String(node.order);
      order.classList.toggle('invalid', checked === null);
      order.classList.toggle('changed', checked !== null && checked !== original);
      if (checked === null) {
        setStatus('Thứ tự phải là số từ 1 đến ' + MAX_ORDER + ', hoặc để trống.', true);
        return;
      }
      if (checked === original && !node.mixed) delete pending[node.key];
      else pending[node.key] = checked;
      setStatus('');
      updateSave();
    };

    row.append(name, count, order);
    item.append(row);
    if (node.children && node.children.length) {
      var children = document.createElement('ul');
      node.children.forEach(function (child) { renderNode(child, children); });
      item.append(children);
    }
    container.append(item);
  }

  window.VGD = {
    onTree: function (data) {
      pending = {};
      updateSave();
      tree.textContent = '';
      var nodes = data.nodes || [];
      document.getElementById('empty').hidden = nodes.length > 0;
      nodes.forEach(function (node) { renderNode(node, tree); });
      setStatus('');
    },
    onToast: function (data) { setStatus(data.message, false); },
    onError: function (data) { setStatus(data.message, true); }
  };

  window.VGD.refresh = function () { send('refresh'); };
  window.VGD.exportSvg = function () { send('export'); };
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

  VGDTheme.start({ key: 'vgd.diagram.theme', button: document.getElementById('theme') });
  send('ready');
})();
