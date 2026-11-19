#!/usr/bin/env python3
"""Sinh icon thanh công cụ vẽ của VGD Structure: mỗi công cụ có ba file trong assets/icons/:
draw_<khóa>.svg (nguồn, 24 đơn vị), draw_<khóa>_16.png (small) và draw_<khóa>_24.png (large).
Một danh sách hình duy nhất vẽ ra cả SVG lẫn PNG (PIL, supersampling) nên hai bản khớp nhau.
Chạy: python3 dev/make_draw_icons.py (từ gốc plugin). Cần Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw

INK = '#292B2D'     # màu chính, cùng grid.svg
ACCENT = '#B48963'  # màu nhấn của theme VGD
OUT = Path(__file__).resolve().parent.parent / 'runtime' / 'vgd_structure' / 'assets' / 'icons'
SS = 16             # hệ số supersampling khi vẽ PNG
SIZE = 24           # kích thước lưới SVG

# Mỗi hình: ('line', x1, y1, x2, y2, màu, nét, nét đứt?) | ('rect', x, y, w, h, màu, nét, nét đứt?) | ('circle', cx, cy, r, màu, nét)
# | ('arc', cx, cy, r, góc đầu, góc cuối, màu, nét)
ICONS = {
    'column': [('rect', 7, 7, 10, 10, INK, 1.8, False), ('line', 12, 7, 12, 17, ACCENT, 1.2, True), ('line', 7, 12, 17, 12, ACCENT, 1.2, True)],
    'beam': [('rect', 2, 9, 20, 6, INK, 1.8, False), ('line', 2, 12, 22, 12, ACCENT, 1.2, True)],
    'wall': [('rect', 2, 9.5, 20, 5, INK, 1.8, False), ('line', 2, 12, 22, 12, ACCENT, 1.0, True)],
    'door': [('line', 3, 21, 3, 3, INK, 1.8, False), ('line', 3, 21, 21, 21, INK, 1.8, False), ('line', 21, 3, 21, 21, INK, 1.2, False), ('arc', 3, 21, 18, 270, 360, ACCENT, 1.2)],
    'window': [('rect', 3, 4, 18, 16, INK, 1.8, False), ('line', 3, 12, 21, 12, INK, 1.2, False), ('line', 12, 4, 12, 20, INK, 1.2, False)],
    'slab': [('rect', 2, 13, 20, 4, INK, 1.8, False), ('line', 2, 9, 22, 9, ACCENT, 1.2, True), ('line', 2, 19, 22, 19, ACCENT, 1.2, True)],
    'ceiling': [('rect', 2, 6, 20, 12, INK, 1.8, True), ('line', 2, 12, 22, 12, ACCENT, 1.0, False)],
}


def svg_of(key):
    parts = []
    for item in ICONS[key]:
        kind = item[0]
        if kind == 'line':
            _, x1, y1, x2, y2, col, w, dash = item
            extra = ' stroke-dasharray="3 2"' if dash else ''
            parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{col}" stroke-width="{w}"{extra}/>')
        elif kind == 'rect':
            _, x, y, w, h, col, sw, dash = item
            extra = ' stroke-dasharray="3 2"' if dash else ''
            parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none" stroke="{col}" stroke-width="{sw}"{extra}/>')
        elif kind == 'arc':
            import math
            _, cx, cy, r, a0, a1, col, sw = item
            x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
            x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
            parts.append(f'<path d="M{x0:.2f} {y0:.2f} A{r} {r} 0 0 1 {x1:.2f} {y1:.2f}" fill="none" stroke="{col}" stroke-width="{sw}"/>')
    title = {'column': 'Cột', 'beam': 'Dầm', 'wall': 'Tường', 'door': 'Cửa đi', 'window': 'Cửa sổ', 'slab': 'Sàn', 'ceiling': 'Trần'}[key]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" fill="none" role="img">\n'
            f'  <title>VGD Structure · {title}</title>\n  ' + '\n  '.join(parts) + '\n</svg>\n')


def dashed(draw, x1, y1, x2, y2, color, width):
    # nét đứt: đoạn 3 đơn vị, khoảng 2 đơn vị (theo hệ SVG, nhân với SS)
    import math
    length = math.hypot(x2 - x1, y2 - y1)
    if length == 0:
        return
    ux, uy = (x2 - x1) / length, (y2 - y1) / length
    t = 0.0
    while t < length:
        seg = min(3.0, length - t)
        draw.line([(x1 + ux * t, y1 + uy * t), (x1 + ux * (t + seg), y1 + uy * (t + seg))], fill=color, width=width)
        t += 5.0


def png_of(key, px):
    import math
    big = px * SS
    scale = big / SIZE
    im = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def rgb(hex_color):
        h = hex_color.lstrip('#')
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

    for item in ICONS[key]:
        kind = item[0]
        if kind == 'line':
            _, x1, y1, x2, y2, col, w, dash = item
            a, b = (x1 * scale, y1 * scale), (x2 * scale, y2 * scale)
            if dash:
                dashed(d, a[0], a[1], b[0], b[1], rgb(col), max(1, round(w * scale)))
            else:
                d.line([a, b], fill=rgb(col), width=max(1, round(w * scale)))
        elif kind == 'rect':
            _, x, y, w, h, col, sw, dash = item
            corners = [(x, y), (x + w, y), (x + w, y + h), (x, y + h), (x, y)]
            for (ax, ay), (bx, by) in zip(corners, corners[1:]):
                if dash:
                    dashed(d, ax * scale, ay * scale, bx * scale, by * scale, rgb(col), max(1, round(sw * scale)))
                else:
                    d.line([(ax * scale, ay * scale), (bx * scale, by * scale)], fill=rgb(col), width=max(1, round(sw * scale)))
        elif kind == 'arc':
            _, cx, cy, r, a0, a1, col, sw = item
            box = [(cx - r) * scale, (cy - r) * scale, (cx + r) * scale, (cy + r) * scale]
            d.arc(box, start=a0, end=a1, fill=rgb(col), width=max(1, round(sw * scale)))
    return im.resize((px, px), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key in ICONS:
        (OUT / f'draw_{key}.svg').write_text(svg_of(key), encoding='utf-8')
        png_of(key, 16).save(OUT / f'draw_{key}_16.png')
        png_of(key, 24).save(OUT / f'draw_{key}_24.png')
        print('đã tạo', key)


if __name__ == '__main__':
    main()
