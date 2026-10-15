"""Create a brand-new empty SKP using the installed SketchUp 2022 C API."""
import ctypes
import os
from pathlib import Path

root = Path(__file__).resolve().parent.parent
sketchup = Path('C:/Program Files/SketchUp/SketchUp 2022')
with os.add_dll_directory(str(sketchup)):
    api = ctypes.CDLL(str(sketchup / 'SketchUpAPI.dll'))
model = ctypes.c_void_p()
api.SUModelCreate.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
api.SUModelSaveToFile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
api.SUModelRelease.argtypes = [ctypes.POINTER(ctypes.c_void_p)]
api.SUInitialize()
try:
    assert api.SUModelCreate(ctypes.byref(model)) == 0
    target = root / 'outputs' / 'empty_native.skp'
    assert api.SUModelSaveToFile(model, str(target).encode('utf-8')) == 0
    print(target)
finally:
    if model.value:
        api.SUModelRelease(ctypes.byref(model))
    api.SUTerminate()
