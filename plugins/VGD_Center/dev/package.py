"""Đóng gói VGD Center thành RBZ.

Cách dùng (từ thư mục gốc repo):
    python plugins/VGD_Center/dev/package.py
Tạo ra plugins/VGD_Center/outputs/local_release_<version>/VGD_Center_v<version>.rbz
và file .sha256 đi kèm. Không ghi đè file đã tồn tại.
"""
import hashlib
import json
import re
import shutil
import sys
import zipfile
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
REPO = PLUGIN.parents[1]
SHARED = REPO / 'shared' / 'vgd-center'
RUNTIME = PLUGIN / 'VGD_Center'
LOADER = PLUGIN / 'VGD_Center.rb'


sys.stdout.reconfigure(encoding='utf-8')


def fail(message):
    print(f'LỖI: {message}')
    sys.exit(1)


def read_version():
    main = (RUNTIME / 'main.rb').read_text(encoding='utf-8')
    match = re.search(r"VERSION = '(\d+\.\d+\.\d+)'", main)
    if not match:
        fail('Không tìm thấy VERSION trong main.rb')
    return match.group(1)


def sync_shared_metadata():
    # Bản đóng gói phải dùng đúng catalog và center-update từ shared/.
    for name in ('catalog.json', 'center-update.json'):
        shutil.copyfile(SHARED / name, RUNTIME / name)


def check_catalog():
    catalog = json.loads((RUNTIME / 'catalog.json').read_text(encoding='utf-8'))
    if catalog.get('schema_version') != 1 or catalog.get('channel') != 'latest':
        fail('catalog.json không đúng schema latest.')
    for product in catalog['products']:
        # Sản phẩm đang phát triển chưa có bản phát hành; VGD Center cũng bỏ qua chúng.
        if product.get('lifecycle') == 'in_development':
            continue
        version = product['version']
        if not re.fullmatch(r'\d+\.\d+\.\d+(?:-(?:alpha|beta)(?:\.\d+)?)?', version):
            fail(f"Phiên bản không hợp lệ: {product['id']} {version}")
        expected = re.search(r'-(alpha|beta)', version)
        expected_channel = expected.group(1) if expected else 'stable'
        if product['release_channel'] != expected_channel:
            fail(f"Kênh phát hành không khớp phiên bản: {product['id']}")
        url = product['download']['url']
        if not url.endswith('/' + product['download']['filename']):
            fail(f"Tên file không khớp URL: {product['id']}")


def collect_files():
    files = [(LOADER, 'VGD_Center.rb')]
    for path in sorted(RUNTIME.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts:
            files.append((path, path.relative_to(PLUGIN).as_posix()))
    return files


def main():
    version = read_version()
    if len(sys.argv) > 1 and sys.argv[1] != version:
        fail(f'Phiên bản trong main.rb là {version}, không phải {sys.argv[1]}.')
    notes = PLUGIN / f'RELEASE_NOTES_v{version}.md'
    if not notes.exists():
        fail(f'Thiếu {notes.name}')

    sync_shared_metadata()
    check_catalog()

    out_dir = PLUGIN / 'outputs' / f'local_release_{version}'
    rbz = out_dir / f'VGD_Center_v{version}.rbz'
    if rbz.exists():
        fail(f'Đã tồn tại, không ghi đè: {rbz}')
    out_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
        for source, entry in collect_files():
            archive.write(source, entry)

    digest = hashlib.sha256(rbz.read_bytes()).hexdigest()
    (out_dir / f'{rbz.name}.sha256').write_text(f'{digest}  {rbz.name}\n', encoding='ascii')
    print(f'Đã tạo: {rbz}')
    print(f'Dung lượng: {rbz.stat().st_size} byte')
    print(f'SHA-256: {digest}')


if __name__ == '__main__':
    main()
