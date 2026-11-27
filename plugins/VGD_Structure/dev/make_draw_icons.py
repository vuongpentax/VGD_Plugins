#!/usr/bin/env python3
"""Sinh icon SVG thanh công cụ vẽ của VGD Structure theo kiểu isometric 3D (gần với icon Revit: cột, dầm, tường, cửa, sàn, trần là khối 3D).
Mỗi icon là danh sách khối (hộp) và chi tiết (lỗ cửa, lưới trần). Chỉ vẽ mặt nhìn thấy (trên, và hai mặt hướng về người xem).
Quy tắc bộ icon VGD (shared/VGD_ICON_SYSTEM_RULES.md): viewBox 24, nét 1.8, đầu nét và góc nối bo tròn, không nền,
nét chính #292B2D và điểm nhấn #B48963. Chạy: python3 dev/make_draw_icons.py (từ gốc plugin). Không cần thư viện ngoài."""
import math
from pathlib import Path

INK = '#292B2D'
ACCENT = '#B48963'
OUT = Path(__file__).resolve().parent.parent / 'runtime' / 'vgd_structure' / 'assets' / 'icons'
C30, S30 = math.cos(math.radians(30)), 0.5


def proj(p):
    x, y, z = p
    return ((x - y) * C30, (x + y) * S30 - z)


def box(x0, x1, y0, y1, z0, z1):
    """Ba mặt nhìn thấy của hộp: trên, phải (x = x1), trước (y = y1)."""
    return {
        'top': [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        'right': [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        'front': [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
    }


def front_rect(x0, x1, z0, z1, y):
    """Hình chữ nhật trên mặt trước (y = y), dùng cho lỗ cửa / cửa sổ."""
    return [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)]


def wall_with_opening(x0, x1, y0, y1, h, ox0, ox1, oz0, oz1):
    """Tường một khối, có lỗ trên mặt trước: vẽ tường và viền lỗ (lỗ là phần accent)."""
    return box(x0, x1, y0, y1, 0, h), front_rect(ox0, ox1, oz0, oz1, y1)


def icon(key):
    """Trả về (nét chính: danh sách polygon, nét nhấn: danh sách (polygon, có_tô)) trong không gian 3D."""
    main, accent = [], []
    if key == 'column':
        b = box(0, 1.6, 0, 1.6, 0, 7)
        main += [b['top'], b['right'], b['front']]
        accent.append((b['top'], True))
    elif key == 'beam':
        b = box(0, 8, 0, 1.6, 4.4, 6.0)
        main += [b['top'], b['right'], b['front']]
        accent.append((b['front'], True))
    elif key == 'wall':
        b = box(0, 8, 0, 0.8, 0, 5.2)
        main += [b['top'], b['right'], b['front']]
        accent.append((b['top'], True))
    elif key == 'door':
        b = box(0, 8, 0, 0.8, 0, 5.2)
        main += [b['top'], b['right'], b['front']]
        opening = front_rect(2.6, 4.6, 0, 3.6, 0.8)
        leaf = front_rect(2.9, 4.3, 0, 3.4, 0.8)  # cánh cửa: tô nhạt, lùi vào trong lỗ
        accent.append((opening, False))
        accent.append((leaf, True))
    elif key == 'window':
        b = box(0, 8, 0, 0.8, 0, 5.2)
        main += [b['top'], b['right'], b['front']]
        opening = front_rect(2.6, 5.4, 1.6, 3.8, 0.8)
        accent.append((opening, False))
        accent.append(([(4.0, 0.8, 1.6), (4.0, 0.8, 3.8)], False))  # đố đứng
        accent.append(([(2.6, 0.8, 2.7), (5.4, 0.8, 2.7)], False))  # đố ngang
    elif key == 'slab':
        b = box(0, 8, 0, 6, 0, 1.2)
        main += [b['top'], b['right'], b['front']]
        accent.append((b['top'], True))
    elif key == 'ceiling':
        b = box(0, 8, 0, 6, 0, 0.8)
        main += [b['top'], b['right'], b['front']]
        grid = []
        grid.append([(4, 0, 0.8), (4, 6, 0.8)])  # lưới trần: một đường giữa mỗi phương
        grid.append([(0, 3, 0.8), (8, 3, 0.8)])
        for seg in grid:
            accent.append((seg, False))
    elif key == 'stair':
        # Vế thẳng ba bậc: biên dạng bậc ở hai mặt đầu (y = 0 và y = 6), nối các đỉnh; mép mặt bậc được nhấn.
        profile = [(0, 0), (7.5, 0), (7.5, 4.8), (5, 4.8), (5, 3.2), (2.5, 3.2), (2.5, 1.6), (0, 1.6)]
        front = [(x, 6, z) for x, z in profile]
        back = [(x, 0, z) for x, z in profile]
        main += [front, back]
        main += [[(x, 0, z), (x, 6, z)] for x, z in profile]
        accent += [([(0, 6, 1.6), (2.5, 6, 1.6)], False), ([(2.5, 6, 3.2), (5, 6, 3.2)], False), ([(5, 6, 4.8), (7.5, 6, 4.8)], False)]
    elif key == 'footing':
        # Đế móng đơn (bản rộng, thấp) với cổ cột nhỏ phía trên: cổ cột là nét nhấn.
        b = box(0, 8, 0, 6, 0, 1.6)
        main += [b['top'], b['right'], b['front']]
        n = box(2.8, 5.2, 1.8, 4.2, 1.6, 4)
        main += [n['top'], n['right'], n['front']]
        accent.append((n['top'], True))
    else:
        raise KeyError(key)
    return main, accent


def fit(points):
    """Co hình vào ô 20 đơn vị giữa khung 24 (lề 2), giữ tỉ lệ, căn giữa."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    scale = min(20 / (maxx - minx), 20 / (maxy - miny))
    ox = 12 - (minx + maxx) / 2 * scale
    oy = 12 - (miny + maxy) / 2 * scale
    return lambda p: (round(p[0] * scale + ox, 2), round(p[1] * scale + oy, 2))


def path_of(poly2d, closed):
    d = 'M' + ' L'.join(f'{x} {y}' for x, y in poly2d)
    return d + (' Z' if closed else '')


def svg_of(key, title):
    main, accent = icon(key)
    flat = [proj(p) for poly in main for p in poly] + [proj(p) for poly, _ in accent for p in poly]
    to_screen = fit(flat)
    main_paths = [path_of([to_screen(proj(p)) for p in poly], True) for poly in main]
    acc_items = []
    for poly, filled in accent:
        pts = [to_screen(proj(p)) for p in poly]
        closed = filled or len(pts) > 2
        fill = f' fill="{ACCENT}" fill-opacity="0.35"' if filled else ' fill="none"'
        acc_items.append(f'<path d="{path_of(pts, closed)}"{fill}/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" role="img" aria-labelledby="t">\n'
            f'  <title id="t">VGD Structure · {title}</title>\n'
            f'  <g stroke="{INK}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">\n'
            + ''.join(f'    <path d="{d}" fill="none"/>\n' for d in main_paths) +
            '  </g>\n'
            f'  <g stroke="{ACCENT}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">\n'
            + ''.join(f'    {item}\n' for item in acc_items) +
            '  </g>\n</svg>\n')


TITLES = {'column': 'Cột', 'beam': 'Dầm', 'wall': 'Tường', 'door': 'Cửa đi', 'window': 'Cửa sổ', 'slab': 'Sàn', 'ceiling': 'Trần', 'stair': 'Cầu thang', 'footing': 'Móng'}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key, title in TITLES.items():
        (OUT / f'draw_{key}.svg').write_text(svg_of(key, title), encoding='utf-8')
        print('đã tạo', key)


if __name__ == '__main__':
    main()
