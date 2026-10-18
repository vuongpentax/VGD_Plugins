/* global sketchup */
(function () {
  'use strict';
  const el = (id) => document.getElementById(id);
  const esc = (value) => String(value == null ? '' : value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const channelNames = { diffuse: 'Màu nền', normal: 'Pháp tuyến', roughness: 'Độ nhám', ao: 'Che sáng môi trường', metallic: 'Kim loại' };
  const sourceNames = { sketchup: 'SketchUp', sketchup_pbr: 'SketchUp PBR' };
  const statusNames = { OK: 'OK · Có', EMBEDDED: 'EMBEDDED · Trong SKP', MISSING: 'MISSING · Thiếu', UNKNOWN: 'UNKNOWN · Chưa rõ' };
  const summaryNames = { OK: 'Có', EMBEDDED: 'Trong SKP', MISSING: 'Thiếu', UNKNOWN: 'Chưa rõ' };
  const root = document.documentElement;
  VGDTheme.start({ key: 'vgd-package-theme', button: el('themeButton') });
  window.VGDPack = {
    showScan(data) {
      const caps = data.capabilities || {};
      el('version').textContent = `SketchUp ${caps.sketchup_year || caps.sketchup_version || 'unknown'} · Model: ${data.model || 'chưa lưu'}`;
      el('capabilities').innerHTML = `<span>Texture SketchUp <b>${caps.native_texture ? 'Có' : 'Không'}</b></span><span>API PBR <b>${caps.native_pbr_api ? 'Có' : 'Không'}</b></span><span>Enscape <b>Chỉ đọc</b></span>`;
      const counts = data.summary || {};
      el('summary').innerHTML = Object.keys(counts).length ? Object.entries(counts).map(([key, value]) => `<div class="count"><strong>${esc(value)}</strong><span>${esc(summaryNames[key] || key)}</span></div>`).join('') : '<span>Chưa tìm thấy texture trong các vật liệu.</span>';
      el('assets').innerHTML = (data.assets || []).map((asset) => `<tr><td>${esc(asset.material_name)}</td><td>${esc(channelNames[asset.channel] || asset.channel)}</td><td>${esc(sourceNames[asset.source_type] || asset.source_type)}</td><td><span class="status ${esc(asset.status).toLowerCase()}">${esc(statusNames[asset.status] || asset.status)}</span></td><td class="path" title="${esc(asset.current_path)}">${esc(asset.current_path || '—')}</td></tr>`).join('');
      el('message').textContent = `Đã quét ${data.assets.length} tài nguyên.`;
    },
    showResearch(result) { el('message').textContent = `Đã xuất báo cáo chỉ đọc gồm ${result.entries} mục: ${result.path}`; },
    showError(message) { el('message').textContent = `Có lỗi xảy ra: ${message}`; }
  };
}());
