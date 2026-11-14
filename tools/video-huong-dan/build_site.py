#!/usr/bin/env python3
"""Dựng thư mục _site để đăng lên GitHub Pages: các trang hướng dẫn tương tác của VGD Center.

Chỉ chép đúng các file cần chạy (giao diện Center, theme, font, hoạt ảnh) và GIỮ NGUYÊN đường dẫn tương đối
như trong repo, nên các trang chạy được mà không sửa gì. Chạy từ bất kỳ đâu: python3 tools/video-huong-dan/build_site.py
Thêm hướng dẫn cho plugin mới: tạo tools/video-huong-dan/guides/<id>/index.html (id trùng id trong catalog).
"""
import html
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '_site'
VIDEO = ROOT / 'tools' / 'video-huong-dan'
CENTER = ROOT / 'plugins' / 'VGD_Center' / 'vgd_center'


def copy_files(src_dir, dst_dir, patterns):
    dst_dir.mkdir(parents=True, exist_ok=True)
    for pattern in patterns:
        for f in sorted(src_dir.glob(pattern)):
            if f.is_file():
                shutil.copy2(f, dst_dir / f.name)


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    # Hoạt ảnh và phần dùng chung (không chép render.js, build_site.py, tài liệu)
    copy_files(VIDEO, OUT / 'tools' / 'video-huong-dan', ['common.css', 'common.js', 'scene-*.html'])
    # Font của hoạt ảnh
    shutil.copytree(ROOT / 'shared' / 'vgd-theme' / 'fonts', OUT / 'shared' / 'vgd-theme' / 'fonts')
    # Giao diện Center thật mà hoạt ảnh nhúng (chỉ file web, không chép mã Ruby)
    site_center = OUT / 'plugins' / 'VGD_Center' / 'vgd_center'
    copy_files(CENTER, site_center, ['dialog.html', 'catalog.json', 'icon.svg'])
    shutil.copytree(CENTER / 'assets', site_center / 'assets')
    shutil.copytree(CENTER / 'vgd-theme', site_center / 'vgd-theme')
    copy_files(CENTER / 'manager', site_center / 'manager', ['*.js', '*.css'])
    copy_files(CENTER / 'guides', site_center / 'guides', ['*.html'])
    # Trang hướng dẫn: mỗi thư mục guides/<id>/ là một plugin
    ids = []
    for page in sorted((VIDEO / 'guides').glob('*/index.html')):
        gid = page.parent.name
        if not re.fullmatch(r'[a-z][a-z0-9_]*', gid):
            raise SystemExit(f'Tên thư mục hướng dẫn không hợp lệ: {gid}')
        shutil.copytree(page.parent, OUT / 'guides' / gid)
        ids.append(gid)
    if not ids:
        raise SystemExit('Không có trang hướng dẫn nào trong tools/video-huong-dan/guides/')
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
