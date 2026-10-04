"""Test real image pixels through the installed SketchUp 2022 decoder DLL."""
import ctypes
import json
import os
from pathlib import Path

root = Path(__file__).resolve().parent.parent
formats = root / 'outputs' / 'formats'
sketchup = Path('C:/Program Files/SketchUp/SketchUp 2022')
with os.add_dll_directory(str(sketchup)):
    api = ctypes.CDLL(str(sketchup / 'SketchUpAPI.dll'))
p = ctypes.c_void_p
s = ctypes.c_size_t
api.SUImageRepCreate.argtypes = [ctypes.POINTER(p)]
api.SUImageRepLoadFile.argtypes = [p, ctypes.c_char_p]
api.SUImageRepGetPixelDimensions.argtypes = [p, ctypes.POINTER(s), ctypes.POINTER(s)]
api.SUImageRepGetDataSize.argtypes = [p, ctypes.POINTER(s), ctypes.POINTER(s)]
api.SUImageRepGetData.argtypes = [p, s, ctypes.c_void_p]
api.SUImageRepRelease.argtypes = [ctypes.POINTER(p)]
report = {'decoder': str(sketchup / 'SketchUpAPI.dll'), 'tests': []}
files = [formats / f'Ảnh người #1.{ext}' for ext in ['png', 'jpg', 'bmp', 'tif', 'tga']]
files += [formats / f'decoded_{ext}.png' for ext in ['webp', 'gif', 'avif', 'ico', 'svg', 'jfif']]
api.SUInitialize()
try:
    for file in files:
        image = p()
        try:
            assert api.SUImageRepCreate(ctypes.byref(image)) == 0
            result = api.SUImageRepLoadFile(image, str(file).encode('utf-8'))
            assert result == 0, f'{file.name}: decoder failed ({result})'
            width, height, size, bpp = s(), s(), s(), s()
            assert api.SUImageRepGetPixelDimensions(image, ctypes.byref(width), ctypes.byref(height)) == 0
            assert api.SUImageRepGetDataSize(image, ctypes.byref(size), ctypes.byref(bpp)) == 0
            expected_height = 16 if file.name == 'decoded_ico.png' else 12
            assert (width.value, height.value) == (16, expected_height)
            item = {'file': file.name, 'width': width.value, 'height': height.value, 'bpp': bpp.value}
            if file.name in ['decoded_webp.png', 'decoded_avif.png']:
                assert bpp.value == 32, 'Alpha channel missing'
                pixels = (ctypes.c_ubyte * size.value)()
                assert api.SUImageRepGetData(image, size, pixels) == 0
                alphas = bytes(pixels)[3::4]
                assert min(alphas) == 0 and max(alphas) == 255, 'Transparent/opaque pixels changed'
                item['alpha'] = [min(alphas), max(alphas)]
            report['tests'].append(item)
        finally:
            if image.value:
                api.SUImageRepRelease(ctypes.byref(image))
    report['success'] = True
finally:
    api.SUTerminate()
    (root / 'outputs' / 'native_codec_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('PASS: SketchUp 2022 native decoder read PNG/JPG/BMP/TIFF/TGA and converted WebP/GIF/AVIF/ICO/SVG/JFIF PNG; Unicode paths, dimensions, WebP/AVIF alpha preserved.')
