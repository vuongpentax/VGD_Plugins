"""Copies shared/vgd-theme into every plugin dialog folder that uses the shared theme.

Usage:
  python tools/sync_vgd_theme.py          copy the shared theme files into each plugin
  python tools/sync_vgd_theme.py --check  fail (exit 1) if any copy differs from shared/vgd-theme
"""
import filecmp
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'shared' / 'vgd-theme'
TARGETS = [
    'plugins/VGD_BIM/runtime/vgd_bim_lite/html',
    'plugins/VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw',
    'plugins/VGD_Center/VGD_Center',
    'plugins/VGD_Dim/runtime/VGD_Dim',
    'plugins/VGD_Image_Importer/runtime/vgd_image_importer',
    'plugins/VGD_Library/runtime/vgd_library',
    'plugins/VGD_Package/VGD_Package/ui',
    'plugins/VGD_Reference/runtime/vgd_reference/ui/web',
    'plugins/VGD_Scenes/runtime/vgd_scenes',
]


def files_of(folder):
    return sorted(p.relative_to(folder) for p in folder.rglob('*') if p.is_file())


def differs(target):
    if not target.is_dir():
        return True
    expected = files_of(SOURCE)
    if expected != files_of(target):
        return True
    return any(not filecmp.cmp(SOURCE / rel, target / rel, shallow=False) for rel in expected)


def main():
    check = '--check' in sys.argv
    failed = []
    for relative in TARGETS:
        target = ROOT / relative / 'vgd-theme'
        if check:
            if differs(target):
                failed.append(relative)
        else:
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(SOURCE, target)
            print('copied', relative)
    if check:
        if failed:
            print('Out of date:', *failed, sep='\n  ')
            sys.exit(1)
        print('All', len(TARGETS), 'copies match shared/vgd-theme')


if __name__ == '__main__':
    main()
