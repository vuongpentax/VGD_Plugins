"""Dựng thư mục _site để đăng lên GitHub Pages: các trang hướng dẫn tương tác của VGD Center và các plugin.

Chỉ chép đúng các file cần chạy (giao diện thật của plugin, theme, font, hoạt ảnh) và GIỮ NGUYÊN đường dẫn tương đối
như trong repo, nên các trang chạy được mà không sửa gì. Chạy từ bất kỳ đâu: python3 tools/video-huong-dan/build_site.py
Thêm hướng dẫn cho plugin mới: tạo tools/video-huong-dan/guides/<id>/chapters.json (id trùng id trong catalog) và các đoạn
hoạt ảnh; trang index.html được sinh từ guides/_template.html. Khóa "web" trong chapters.json (nếu có) là thư mục web của
plugin cần chép (đường dẫn từ gốc repo, ví dụ plugins/VGD_Image_Importer/runtime/vgd_image_importer).
"""
import html
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '_site'
VIDEO = ROOT / 'tools' / 'video-huong-dan'
CENTER = ROOT / 'plugins' / 'VGD_Center' / 'vgd_center'
WEB_SUFFIXES = {'.html', '.css', '.js', '.svg', '.json', '.woff2', '.png', '.ttf', '.woff'}


def copy_files(src_dir, dst_dir, patterns):
    dst_dir.mkdir(parents=True, exist_ok=True)
    for pattern in patterns:
        for f in sorted(src_dir.glob(pattern)):
            if f.is_file():
                shutil.copy2(f, dst_dir / f.name)


def copy_web_dir(src, dst):
    # Chỉ chép file web (không chép mã Ruby, script PowerShell, thư mục dev/test)
    for f in sorted(src.rglob('*')):
        if f.is_file() and (f.suffix.lower() in WEB_SUFFIXES or f.name == 'LICENSE'):
            target = dst / f.relative_to(src)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, target)


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    # Hoạt ảnh và phần dùng chung (không chép render.js, build_site.py, tài liệu)
    copy_files(VIDEO, OUT / 'tools' / 'video-huong-dan', ['common.css', 'common.js', 'center.js', 'scene-*.html'])
    for sub in sorted(p for p in VIDEO.iterdir() if p.is_dir() and p.name not in ('guides', '__pycache__')):
        copy_web_dir(sub, OUT / 'tools' / 'video-huong-dan' / sub.name)
    # Font của hoạt ảnh
    shutil.copytree(ROOT / 'shared' / 'vgd-theme' / 'fonts', OUT / 'shared' / 'vgd-theme' / 'fonts')
    # Giao diện Center thật mà hoạt ảnh nhúng (chỉ file web, không chép mã Ruby)
    site_center = OUT / 'plugins' / 'VGD_Center' / 'vgd_center'
    copy_files(CENTER, site_center, ['dialog.html', 'catalog.json', 'icon.svg'])
    shutil.copytree(CENTER / 'assets', site_center / 'assets')
    shutil.copytree(CENTER / 'vgd-theme', site_center / 'vgd-theme')
    copy_files(CENTER / 'manager', site_center / 'manager', ['*.js', '*.css'])
    copy_files(CENTER / 'guides', site_center / 'guides', ['*.html'])
    # Trang hướng dẫn: mỗi thư mục guides/<id>/chapters.json là một plugin; index.html sinh từ mẫu chung
    template = (VIDEO / 'guides' / '_template.html').read_text(encoding='utf-8')
    ids = []
    for chapters in sorted((VIDEO / 'guides').glob('*/chapters.json')):
        gid = chapters.parent.name
        if not re.fullmatch(r'[a-z][a-z0-9_]*', gid):
            raise SystemExit(f'Tên thư mục hướng dẫn không hợp lệ: {gid}')
        data = json.loads(chapters.read_text(encoding='utf-8'))
        for chapter in data['chapters']:
            if not (VIDEO / f"{chapter['scene']}.html").is_file():
                raise SystemExit(f"{gid}: không thấy đoạn hoạt ảnh {chapter['scene']}.html")
        if data.get('web'):
            web = (ROOT / data['web']).resolve()
            if ROOT not in web.parents or not web.is_dir():
                raise SystemExit(f"{gid}: thư mục web không hợp lệ: {data['web']}")
            copy_web_dir(web, OUT / data['web'])
        out = OUT / 'guides' / gid
        out.mkdir(parents=True)
        shutil.copy2(chapters, out / 'chapters.json')
        (out / 'index.html').write_text(template, encoding='utf-8')
        ids.append(gid)
    if not ids:
        raise SystemExit('Không có chapters.json nào trong tools/video-huong-dan/guides/')
    items = ''.join(f'<li><a href="guides/{html.escape(i)}/">{html.escape(i)}</a></li>' for i in ids)
    (OUT / 'index.html').write_text(
        '<!doctype html><html lang="vi"><meta charset="utf-8"><title>VGD · Hướng dẫn</title>'
        f'<body style="font:16px/1.6 sans-serif;max-width:640px;margin:40px auto;padding:0 20px"><h1>VGD · Hướng dẫn</h1><ul>{items}</ul></body></html>',
        encoding='utf-8')
    (OUT / '.nojekyll').write_text('', encoding='utf-8')
    total = sum(f.stat().st_size for f in OUT.rglob('*') if f.is_file())
    print(f'Đã dựng {OUT} ({total / 1024:.0f} KB), hướng dẫn: {", ".join(ids)}')


if __name__ == '__main__':
    main()
