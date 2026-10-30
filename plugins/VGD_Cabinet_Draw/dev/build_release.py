from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs'
VERSION = '1.0.0-beta.69'
RUNTIME_DIR = ROOT / 'runtime' / 'VGD_Cabinet_Draw'
LOADER_FILES = [
    ('VGD_Cabinet_Draw.rb', 'VGD_Cabinet_Draw.rb'),
    ('main.rb', 'VGD_Cabinet_Draw/main.rb'),
]

def packaged_files():
    # Gói .rbz gồm loader, main.rb và toàn bộ runtime; dev/ và test/ không đưa vào.
    files = list(LOADER_FILES)
    for path in sorted(RUNTIME_DIR.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts:
            relative = path.relative_to(ROOT).as_posix()
            files.append((relative, f'VGD_Cabinet_Draw/{relative}'))
    return files

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rbz = OUT / f'VGD_Cabinet_Draw_{VERSION}.rbz'
    source = OUT / f'VGD_Cabinet_Draw_{VERSION}_source.zip'
    files = packaged_files()
    with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
        for source_path, archive_path in files:
            archive.write(ROOT / source_path, archive_path)
    with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in ROOT.rglob('*'):
            if path.is_file() and 'outputs' not in path.parts and '.git' not in path.parts:
                archive.write(path, path.relative_to(ROOT).as_posix())
    manifest = {path.name: sha256(path) for path in (rbz, source)}
    (OUT / 'SHA256.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    with zipfile.ZipFile(rbz) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(files)
        assert 'VGD_Cabinet_Draw/main.rb' in archive.namelist()
        assert 'main.rb' not in archive.namelist()
    print(f'RBZ: {rbz}')
    print(f'Source: {source}')
    print(f'Packaged files: {len(files)}')

if __name__ == '__main__':
    main()
