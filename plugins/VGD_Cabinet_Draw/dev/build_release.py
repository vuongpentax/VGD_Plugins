from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs'
VERSION = '1.0.0-beta.1'
FILES = [
    ('VGD_Cabinet_Draw.rb', 'VGD_Cabinet_Draw.rb'),
    ('main.rb', 'VGD_Cabinet_Draw/main.rb'),
    ('icon.svg', 'VGD_Cabinet_Draw/icon.svg'),
    ('runtime/VGD_Cabinet_Draw/main.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/main.rb'),
    ('runtime/VGD_Cabinet_Draw/schema.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/schema.rb'),
    ('runtime/VGD_Cabinet_Draw/model_data.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/model_data.rb'),
    ('runtime/VGD_Cabinet_Draw/geometry.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/geometry.rb'),
    ('runtime/VGD_Cabinet_Draw/door_geometry.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/door_geometry.rb'),
    ('runtime/VGD_Cabinet_Draw/preview.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/preview.rb'),
    ('runtime/VGD_Cabinet_Draw/tools.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/tools.rb'),
    ('runtime/VGD_Cabinet_Draw/preset_store.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/preset_store.rb'),
    ('runtime/VGD_Cabinet_Draw/dialog.rb', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/dialog.rb'),
    ('runtime/VGD_Cabinet_Draw/dialog.html', 'VGD_Cabinet_Draw/runtime/VGD_Cabinet_Draw/dialog.html'),
    ('dev/native_smoke.rb', 'VGD_Cabinet_Draw/dev/native_smoke.rb'),
    ('README.md', 'VGD_Cabinet_Draw/README.md'),
]

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rbz = OUT / f'VGD_Cabinet_Draw_{VERSION}.rbz'
    source = OUT / f'VGD_Cabinet_Draw_{VERSION}_source.zip'
    with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
        for source_path, archive_path in FILES:
            archive.write(ROOT / source_path, archive_path)
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in ROOT.rglob('*'):
            if path.is_file() and 'outputs' not in path.parts and '.git' not in path.parts:
                archive.write(path, path.relative_to(ROOT).as_posix())
    manifest = {path.name: sha256(path) for path in (rbz, source)}
    (OUT / 'SHA256.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    with zipfile.ZipFile(rbz) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(FILES)
        assert 'VGD_Cabinet_Draw/main.rb' in archive.namelist()
        assert 'main.rb' not in archive.namelist()
    print(f'RBZ: {rbz}')
    print(f'Source: {source}')
    print(f'Runtime files: {len(FILES)}')

if __name__ == '__main__':
    main()
