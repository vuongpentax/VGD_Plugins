"""Đóng gói VGD Diagram thành RBZ kèm SHA-256 (chạy từ plugins/VGD_Diagram: python dev/package.py).

Kết quả nằm trong outputs/ (thư mục này không được commit).
"""
import hashlib
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
runtime = root / 'runtime'
output = root / 'outputs'
output.mkdir(exist_ok=True)

version_text = (runtime / 'vgd_diagram' / 'version.rb').read_text(encoding='utf-8')
match = re.search(r"VERSION\s*=\s*'([^']+)'", version_text)
if not match:
    raise SystemExit('Không đọc được phiên bản VGD Diagram.')
version = match.group(1)

runtime_files = [
    'vgd_diagram.rb',
    'vgd_diagram/version.rb',
    'vgd_diagram/tree.rb',
    'vgd_diagram/model_io.rb',
    'vgd_diagram/scene.rb',
    'vgd_diagram/views.rb',
    'vgd_diagram/dialog.rb',
    'vgd_diagram/dialog.html',
    'vgd_diagram/dialog.css',
    'vgd_diagram/dialog.js',
    'vgd_diagram/main.rb',
    'vgd_diagram/reload.rb',
    'vgd_diagram/diagram.svg',
    'vgd_diagram/vendor/three.min.js',
    'vgd_diagram/vendor/THREE_LICENSE.txt',
    'vgd_diagram/vgd-theme/vgd-theme.css',
    'vgd_diagram/vgd-theme/vgd-theme.js',
    'vgd_diagram/vgd-theme/vgd-controls.css',
    'vgd_diagram/vgd-theme/fonts/manrope-latin-wght-normal.woff2',
    'vgd_diagram/vgd-theme/fonts/manrope-vietnamese-wght-normal.woff2',
    'vgd_diagram/vgd-theme/fonts/LICENSE',
]
for name in runtime_files:
    if not (runtime / name).is_file():
        raise SystemExit(f'Thiếu file runtime: {name}')

rbz = output / f'VGD_Diagram_v{version}.rbz'
with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in runtime_files:
        archive.write(runtime / name, name)

with zipfile.ZipFile(rbz) as archive:
    if archive.testzip() is not None or archive.namelist() != runtime_files:
        raise SystemExit('Kiểm tra RBZ thất bại: sai danh sách file hoặc file hỏng.')
    for name in runtime_files:
        if archive.read(name) != (runtime / name).read_bytes():
            raise SystemExit(f'Nội dung RBZ khác bản runtime: {name}')

digest = hashlib.sha256(rbz.read_bytes()).hexdigest()
print(f'{rbz.name}')
print(f'  dung lượng: {rbz.stat().st_size} byte')
print(f'  SHA-256: {digest}')
