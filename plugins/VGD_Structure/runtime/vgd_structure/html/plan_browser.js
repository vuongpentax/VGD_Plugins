// Cây dự án (Project Browser) của tab Mặt bằng, theo cách làm của Revit: tầng → nhóm phần tử → từng phần tử; loại cột / dầm / tường / cửa; lưới trục.
// Chỉ ĐỌC dữ liệu của cửa sổ (host.state) và nhờ cửa sổ mặt bằng chuyển tầng / chọn phần tử; không tự sửa dữ liệu.
(function () {
  'use strict';
  var host = null, root = null, filterText = '', open = {};
  var GROUPS = [['column', 'Cột', 'picks'], ['beam', 'Dầm', 'beamPicks'], ['wall', 'Tường', 'wallPicks'], ['opening', 'Cửa', 'openingPicks'], ['slab', 'Sàn', 'slabPicks'], ['ceiling', 'Trần', 'ceilingPicks']];
  var TYPE_GROUPS = [['column', 'Loại cột', 'types', 'columnType', 'picks'], ['beam', 'Loại dầm', 'beamTypes', 'beamType', 'beamPicks'], ['wall', 'Loại tường', 'wallTypes', 'wallType', 'wallPicks'], ['opening', 'Loại cửa', 'openingTypes', null, 'openingPicks']];
  var selectedKeys = {};

  function S() { return host.state; }
  function el(tag, props, parent) {
    var e = document.createElement(tag); Object.keys(props || {}).forEach(function (k) { if (k === 'text') e.textContent = props[k]; else e.setAttribute(k, props[k]); });
    if (parent) parent.appendChild(e); return e;
  }
  function norm(t) { return String(t || '').toLowerCase(); }
  function matches(text) { return !filterText || norm(text).indexOf(norm(filterText)) >= 0; }
  function typeLabel(kind, t) { return t.name + ' (' + (kind === 'column' ? t.w + '×' + t.d : kind === 'beam' ? t.w + '×' + t.h : kind === 'wall' ? 'dày ' + t.t : t.w + '×' + t.h) + ')'; }
  function typeOf(kind) { return {column: S().types, beam: S().beamTypes, wall: S().wallTypes, opening: S().openingTypes}[kind] || []; }
  function elementLabel(kind, ref, pick) {
    if (kind === 'opening') { var t = S().openingTypes.filter(function (x) { return x.id === pick.type; })[0]; return (t ? (t.kind === 'door' ? 'Cửa đi ' : 'Cửa sổ ') + t.name : 'Cửa') + ' · ' + pick.wall; }
    var name = {column: 'Cột', beam: 'Dầm', wall: 'Tường', slab: 'Sàn', ceiling: 'Trần'}[kind];
    return name + (pick && pick.free ? ' tự do ' : ' ') + ref;
  }
  // Loại thực sự của một phần tử: loại riêng, không thì loại mặc định của tầng, không thì loại đầu danh sách.
  function effectiveType(kind, level, pick) {
    if (pick && pick.type) return pick.type;
    var def = {column: level.columnType, beam: level.beamType, wall: level.wallType}[kind];
    var list = typeOf(kind);
    return def || (list[0] && list[0].id) || '';
  }

  function node(parent, id, label, opts) {
    var li = el('li', {role: 'treeitem', 'data-node': id, 'aria-expanded': opts.children ? String(!!isOpen(id)) : null}, parent);
    if (!opts.children) li.removeAttribute('aria-expanded');
    var row = el('div', {class: 'pb-row' + (opts.current ? ' current' : '') + (opts.selected ? ' selected' : '')}, li);
    if (opts.children) { var tg = el('button', {type: 'button', class: 'pb-toggle', 'aria-label': (isOpen(id) ? 'Thu gọn ' : 'Mở ') + label}, row); tg.textContent = isOpen(id) ? '▾' : '▸'; tg.onclick = function () { open[id] = !isOpen(id); render(); }; }
    else el('span', {class: 'pb-gap'}, row);
    var b = el('button', {type: 'button', class: 'pb-label', title: opts.title || label}, row); b.textContent = label;
    if (opts.count !== undefined) el('span', {class: 'pb-count', text: String(opts.count)}, row);
    b.onclick = opts.onClick || (opts.children ? function () { open[id] = !isOpen(id); render(); } : function () {});
    b.ondblclick = opts.onDouble || null;
    return li;
  }
  function isOpen(id) { return !!open[id] || !!filterText; } // đang lọc thì mở hết để thấy kết quả

  function render() {
    if (!root || !host) return;
    var st = S(), cur = host.currentLevel();
    root.replaceChildren();
    var head = el('div', {class: 'pb-head'}, root); el('h3', {text: 'Cây dự án'}, head);
    var f = el('input', {type: 'search', class: 'pb-filter', placeholder: 'Lọc theo tên...', 'aria-label': 'Lọc cây dự án'}, head); f.value = filterText;
    f.oninput = function () { filterText = f.value; var pos = f.selectionStart; render(); var nf = root.querySelector('.pb-filter'); nf.focus(); nf.setSelectionRange(pos, pos); };
    f.onkeydown = function (e) { e.stopPropagation(); if (e.key === 'Escape') { f.value = ''; filterText = ''; render(); } };
    var ul = el('ul', {role: 'tree', class: 'pb-tree'}, root), shown = 0;

    // Tầng
    var levels = node(ul, 'levels', 'Tầng', {children: true, count: st.levels.length});
    var lul = el('ul', {role: 'group'}, levels);
    st.levels.forEach(function (lv) {
      var any = false, kids = [];
      GROUPS.forEach(function (g) {
        var box = lv[g[2]] || {}, keys = Object.keys(box);
        var list = keys.filter(function (ref) { return matches(elementLabel(g[0], ref, box[ref])) || matches(lv.name); });
        if (!list.length && filterText) return;
        kids.push({g: g, box: box, list: list, total: keys.length}); any = list.length > 0 || any;
      });
      if (filterText && !any && !matches(lv.name)) return;
      shown++;
      var lid = 'lv:' + lv.id, li = node(lul, lid, lv.name, {children: true, current: lv.id === cur, title: lv.name + ' · cao độ ' + lv.elevation + ' mm (bấm đúp để xem mặt bằng)', onClick: function () { host.openLevel(lv.id); }, onDouble: function () { host.openLevel(lv.id); }});
      var gul = el('ul', {role: 'group'}, li);
      kids.forEach(function (k) {
        var gid = lid + ':' + k.g[0], gli = node(gul, gid, k.g[1], {children: true, count: k.total});
        var eul = el('ul', {role: 'group'}, gli);
        k.list.forEach(function (ref) {
          var key = lv.id + '|' + k.g[0] + '|' + ref;
          node(eul, 'el:' + key, elementLabel(k.g[0], ref, k.box[ref]), {selected: !!selectedKeys[key], onClick: function () { host.selectElement(lv.id, k.g[0], ref); }});
        });
      });
    });

    // Loại (của tầng đang xem)
    var types = node(ul, 'types', 'Loại', {children: true});
    var tul = el('ul', {role: 'group'}, types), curLevel = st.levels.filter(function (l) { return l.id === cur; })[0];
    TYPE_GROUPS.forEach(function (tg) {
      var list = typeOf(tg[0]).filter(function (t) { return matches(t.name) || matches(tg[1]); });
      if (filterText && !list.length) return;
      var gli = node(tul, 'tg:' + tg[0], tg[1], {children: true, count: typeOf(tg[0]).length}), eul = el('ul', {role: 'group'}, gli);
      list.forEach(function (t) {
        var used = curLevel ? Object.keys(curLevel[tg[4]] || {}).filter(function (ref) { return effectiveType(tg[0], curLevel, curLevel[tg[4]][ref]) === t.id; }) : [];
        node(eul, 'ty:' + t.id, typeLabel(tg[0], t), {count: used.length, title: typeLabel(tg[0], t) + ' · ' + used.length + ' phần tử ở tầng đang xem (bấm để chọn các phần tử đó)', onClick: function () { host.selectType(tg[0], t.id); }});
      });
    });

    // Lưới trục
    var grid = node(ul, 'grid', 'Lưới trục', {children: true, count: st.x.axes.length + st.y.axes.length});
    var gl = el('ul', {role: 'group'}, grid);
    [['x', 'Trục đứng (số)'], ['y', 'Trục ngang (chữ)']].forEach(function (d) {
      var axes = host.axes(d[0]).filter(function (a) { return matches(a.name) || matches(d[1]); });
      if (filterText && !axes.length) return;
      var dli = node(gl, 'ax:' + d[0], d[1], {children: true, count: host.axes(d[0]).length}), aul = el('ul', {role: 'group'}, dli);
      axes.forEach(function (a) { node(aul, 'axis:' + d[0] + ':' + a.name, a.name + ' · ' + a.offset + ' mm', {}); });
    });
    if (filterText && !shown && !root.querySelector('.pb-row .pb-label[title*="phần tử ở tầng"]')) el('p', {class: 'pb-empty', text: 'Không có mục nào khớp.'}, root);
  }

  window.VGDPlanBrowser = {
    init: function (h) { host = h; root = document.getElementById('pv-browser'); open = {levels: true}; render(); },
    render: render,
    // Phần tử đang chọn trên mặt bằng (khóa tầng|loại|mã) để tô sáng trong cây.
    highlight: function (keys) { selectedKeys = {}; keys.forEach(function (k) { selectedKeys[k] = true; }); if (root) { root.querySelectorAll('.pb-row.selected').forEach(function (r) { r.classList.remove('selected'); }); keys.forEach(function (k) { var n = root.querySelector('[data-node="' + 'el:' + k.replace(/"/g, '') + '"]'); if (n) n.firstChild.classList.add('selected'); }); } },
    reveal: function (levelId) { open['levels'] = true; open['lv:' + levelId] = true; },
    effectiveType: effectiveType,
    debug: function () { return {open: Object.keys(open).filter(function (k) { return open[k]; }), filter: filterText}; }
  };
})();
