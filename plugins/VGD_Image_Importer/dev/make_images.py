"""Real, small image fixtures for native and browser codec integration tests."""
from pathlib import Path
from PIL import Image

out = Path(__file__).resolve().parent.parent / 'outputs' / 'formats'
out.mkdir(parents=True, exist_ok=True)
image = Image.new('RGBA', (16, 12), (0, 0, 0, 0))
for y in range(12):
    for x in range(8):
        image.putpixel((x, y), (220, 90, 40, 255))
for ext, format_name in [('png', 'PNG'), ('bmp', 'BMP'), ('tif', 'TIFF'), ('tga', 'TGA'), ('webp', 'WEBP'), ('gif', 'GIF'), ('avif', 'AVIF'), ('ico', 'ICO')]:
    extra = {'lossless': True} if ext == 'webp' else {}
    target = image.resize((16, 16)) if ext == 'ico' else image
    target.save(out / f'Ảnh người #1.{ext}', format=format_name, **extra)
image.convert('RGB').save(out / 'Ảnh người #1.jpg', quality=95)
image.convert('RGB').save(out / 'Ảnh người #1.jfif', format='JPEG', quality=95)
(out / 'Ảnh người #1.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="12"><rect width="8" height="12" fill="#dc5a28"/></svg>', encoding='utf-8')
(out / 'corrupt.webp').write_bytes(b'not a valid webp')
print(f'Created real fixtures: {out}')
