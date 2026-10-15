"""Build the sidebar UI from reviewed Claude v6 form controls, never execute archive code."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
source = (root / 'dev/claude_v6_reference/VGD_Dim/dialog.html').read_text(encoding='utf-8')
sections = re.findall(r'<section>.*?</section>', source, re.S)
smart, scope, font, style, animation = sections
units = source[source.index(' <details class="adv">'):source.index('</main>')]
preset = re.search(r'<div class="presets">.*?</div>', source, re.S).group()
font = font.replace('onclick="sketchup.dim_info()"', 'id="dim-info" onclick="sketchup.dim_info()"').replace('onclick="sketchup.text_info()"', 'id="text-info" onclick="sketchup.text_info()"')
font = font.replace('SketchUp 2022 không cho chỉnh font/size bằng code. Chỉnh trong Model Info trước, rồi áp lại bằng một trong hai nút dưới.', 'Chỉnh font, cỡ chữ theo pt hoặc Height trong Model Info, rồi áp mẫu cho các đối tượng cần đổi.')
smart = smart.replace('Mặt đứng</label>', 'Mặt theo trục tủ</label>')
smart = smart.replace('Gần trục nhất (mặt đứng)', 'Gần gốc tọa độ (mặt đứng)')
smart = smart.replace('  <button class="solid wide"', '  <label class="chk"><input type="checkbox" id="sd.scene_only" checked> Gắn bộ Dim vào Scene hiện tại</label>\n  <p class="note">Scene cần bật lưu Tags. Tag bộ này hiển thị trong Scene hiện tại và ẩn ở các Scene khác có lưu Tags.</p>\n  <button class="solid wide"', 1)
smart = re.sub(r'<p class="note">Chọn Group/Component.*?</p>', '<p class="note">Đo theo trục riêng của tủ, gồm tủ xoay quanh Z. Tủ nghiêng, shear hoặc các khối khác hệ trục sẽ được báo lỗi. Chạy lại cùng tủ/mặt/Scene sẽ thay bộ Dim cũ. Bộ mặt cắt dùng Tag riêng <b>000_DIM_SECTION…</b>.</p>', smart, flags=re.S)
smart = smart.replace('<h2>1 · Smart Dim</h2>', '<h2>Dim thủ công</h2><button class="wide" onclick="VGD.manualDim()">Bắt đầu Dim thủ công</button><p class="note">Chọn điểm đầu, điểm cuối rồi chọn phía đặt đường Dim. Nhấn Esc để kết thúc.</p><h2>Boundary &amp; Detail Region</h2><p class="note">Boundary giới hạn cả Smart Dim và Dim thủ công. Detail Region là vùng con có tên để tập trung dim chi tiết.</p><div class="row"><button onclick="VGD.setBoundary()">Đặt / cập nhật Boundary</button><span id="region.boundary">Chưa đặt</span></div><div class="row"><input type="text" id="region.name" maxlength="64" placeholder="Tên Detail Region"><button onclick="VGD.setDetail()">Tạo vùng</button></div><div class="row"><select id="region.active" aria-label="Detail Region" onchange="VGD.activateRegion()"><option value="">Dùng toàn Boundary</option></select><button class="quiet" id="region.delete" onclick="VGD.deleteRegion()">Xóa vùng</button></div><h2>1 · Smart Dim</h2>')
smart = smart.replace('Bỏ đoạn nhỏ hơn', 'Bỏ khe / đoạn dưới (mm)').replace('Tay nắm và chi tiết nhỏ bị bỏ.', 'Khe hoặc đoạn dưới ngưỡng bị gộp; ví dụ khe 1–2 mm sẽ không tạo dim riêng. Tay nắm và chi tiết nhỏ bị bỏ.')
style = style.replace('<div class="sub">Đổi màu', '<div class="checks"><label class="chk"><input id="kind.dim" type="checkbox" checked> Dimension</label><label class="chk"><input id="kind.text" type="checkbox" checked> Text</label><label class="chk"><input id="kind.label" type="checkbox" checked> Label</label></div>\n  <div class="sub">Đổi màu')
style = style.replace('Sau khi áp, Dim nằm ở Tag 000 DIM, Text/Label ở Tag 000 TEXT.', 'Dim thường vào Tag 000 DIM; Text/Label vào 000 TEXT. Bộ Smart Dim giữ Tag của Group để Scene tiếp tục quản lý hiển thị. Đơn vị không đổi khi áp style.')
units = units.replace('<details class="adv">', '<section>').replace('<summary>Nâng cao · Đơn vị của model</summary>', '<h2>Đơn vị toàn model</h2>').replace('</details>', '</section>')
units = re.sub(r'   <label class="chk"><input type="checkbox" id="units.enabled".*?</label>\n', '', units)
units = units.replace('id="units.reset_text" checked', 'id="units.reset_text"')
units = units.replace('   <p class="note">Dim có chữ', '   <button class="solid wide" onclick="VGD.unitsApply()">Áp đơn vị cho toàn model</button>\n   <p class="note">Dim có chữ')
scope = scope.replace('<section>', '<section id="shared-scope" class="scope-card">', 1).replace('<h2>2 · Phạm vi</h2>', '<h2>Phạm vi áp dụng</h2>')
scope = re.sub(r'<p class="note">Áp dụng cho mục 3.*?</p>', '<p class="note">Chỉ dùng cho Font &amp; Kiểu dáng. Component chung definition đổi mọi bản sao; Make Unique để sửa riêng.</p>', scope, flags=re.S)
scope = scope.replace('Quét (chỉ đếm)', 'Quét')
icons = {
 'smart':'M3 6h18M5 3v6M19 3v6M5 12h14v8H5zM10 12v8',
 'font':'M4 5h16M12 5v15M7 20h10',
 'style':'M4 6h16M4 12h16M4 18h16M8 3v6M16 9v6M10 15v6',
 'presets':'M5 3h12l3 3v15H4V3zM8 3v6h8V3M8 14h8v7',
 'animation':'M8 5l11 7-11 7z',
 'units':'M3 8h18v8H3zM7 8v4M11 8v6M15 8v4M19 8v6'
}
titles = {'smart':'Smart Dim','font':'Font & cỡ chữ','style':'Kiểu dáng','presets':'Preset','animation':'Animation','units':'Đơn vị'}
descriptions = {'smart':'Đo tủ đang chọn · cập nhật bộ Dim cũ','font':'Mẫu chữ Model Info · đổi cỡ chữ và font','style':'Màu, endpoint, hướng chữ và leader','presets':'Lưu bộ kiểu dáng trên máy này','animation':'Chuyển cảnh và thời gian slideshow','units':'Thiết lập đơn vị chung cho cả model'}
panels = {'smart':smart, 'font':font, 'style':style, 'presets':'<section><h2>Bộ kiểu dáng</h2>'+preset+'<p class="note">Preset chỉ lưu kiểu dáng. Áp đơn vị là thao tác riêng; thiết lập Smart Dim được lưu sau lượt đo thành công.</p></section>', 'animation':animation, 'units':units}
nav = ''.join(f'<button id="tab-{k}" class="nav-item" role="tab" aria-controls="panel-{k}" aria-selected="{str(k=="smart").lower()}" tabindex="{0 if k=="smart" else -1}" data-tab="{k}" title="{titles[k]}"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="{icons[k]}"/></svg><span>{titles[k]}</span></button>' for k in titles)
content = ''.join(f'<div id="panel-{k}" class="function-panel" role="tabpanel" aria-labelledby="tab-{k}" {"" if k=="smart" else "hidden"}><div class="panel-heading"><h1>{titles[k]}</h1><p>{descriptions[k]}</p><span class="scope-badge" id="badge-{k}"></span></div>{re.sub(r"<h2>[1-5] · ", "<h2>", panels[k])}</div>' for k in titles)
html = f'''<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>VGD Dim</title><link rel="stylesheet" href="dialog.css"></head><body>
<header><div class="brand"><svg class="brand-logo" viewBox="0 0 180 180" role="img" aria-label="VGD"><rect x="3" y="3" width="174" height="174" rx="25" fill="var(--vgd-tile)" stroke="var(--vgd-border)" stroke-width="3"/><path d="M90 18 27 54 90 89Z" fill="var(--vgd-surface)"/><path d="M90 18 153 54 90 89Z" fill="var(--vgd-accent)"/><path d="M27 54 90 89V162L27 126Z" fill="var(--vgd-tile)"/><path d="M90 89 153 54V101C153 129 126 149 90 162Z" fill="var(--vgd-logo-face)"/><path d="M53 99 90 120V162L53 141Z" fill="var(--vgd-bg)"/><path d="M53 131 90 152V162L53 141Z" fill="var(--vgd-accent-strong)"/><path d="M90 18 27 54V126L90 162C126 149 153 129 153 101V54Z" fill="none" stroke="var(--vgd-logo-outline)" stroke-width="4" stroke-linejoin="round"/><path d="M90 18V89L153 54M27 54 90 89V162M53 99V141L90 162M53 99 90 120V152M27 54 90 18 153 54 90 89Z" fill="none" stroke="var(--vgd-logo-outline)" stroke-width="4" stroke-linejoin="round"/></svg><div class="brand-copy"><span class="brand-wordmark">VGD</span><b>Dim</b><small id="ver">3.3.0 beta</small></div></div><button id="theme" class="theme-button" aria-label="Chuyển giao diện sáng tối" aria-pressed="false" onclick="VGD.toggleTheme()"><svg viewBox="0 0 24 24" aria-hidden="true"><circle class="sun" cx="12" cy="12" r="4"/><path class="sun" d="M12 2v2m0 16v2M4.93 4.93l1.42 1.42m11.3 11.3 1.42 1.42M2 12h2m16 0h2M4.93 19.07l1.42-1.42m11.3-11.3 1.42-1.42"/><path class="moon" d="M20 15.2A8.3 8.3 0 0 1 8.8 4 8.3 8.3 0 1 0 20 15.2Z"/></svg></button></header>
<div class="workspace"><aside><nav role="tablist" aria-label="Chức năng VGD Dim">{nav}</nav><div id="desktop-scope">{scope}</div><div class="sidebar-foot">DIM · TEXT · LABEL<br>SketchUp native</div></aside>
<main><div id="mobile-scope"></div>{content}</main></div>
<footer><span class="status-dot" aria-hidden="true"></span><div id="log" role="status" aria-live="polite">Chọn tủ rồi bấm Smart Dim. Thiết lập đo được lưu sau khi chạy thành công.</div></footer>
<script src="dialog.js"></script></body></html>
'''
(root / 'runtime/VGD_Dim/dialog.html').write_text(html, encoding='utf-8')
print('Built six panels and one shared scope card.')
