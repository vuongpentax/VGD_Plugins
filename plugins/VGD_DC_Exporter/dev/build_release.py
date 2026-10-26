from pathlib import Path
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs'
VERSION = '1.0.0'
FILES = [
    'VGD_DC_Exporter.rb',
    'VGD_DC_Exporter/main.rb',
    'VGD_DC_Exporter/params.rb',
    'VGD_DC_Exporter/walker.rb',
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rbz = OUT / f'VGD_DC_Exporter_{VERSION}.rbz'
    with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in FILES:
            archive.write(ROOT / name, name)
    with zipfile.ZipFile(rbz) as archive:
        assert archive.testzip() is None
        assert sorted(archive.namelist()) == sorted(FILES), archive.namelist()
    print(f'RBZ: {rbz}')


if __name__ == '__main__':
    main()
