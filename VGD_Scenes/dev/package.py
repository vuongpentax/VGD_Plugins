from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent.parent
version = re.search(r"VERSION = '([^']+)'", (root / 'runtime/vgd_scenes.rb').read_text(encoding='utf-8')).group(1)
target = root / f'VGD_Scenes_v{version}.rbz'
source = root / f'VGD_Scenes_v{version}_source.zip'
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted((root / 'runtime').rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(root / 'runtime').as_posix())
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    for name in archive.namelist():
        assert archive.read(name) == (root / 'runtime' / name).read_bytes()
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
    for base in ['runtime', 'dev']:
        for path in sorted((root / base).rglob('*')):
            if path.is_file() and not {'node_modules', 'outputs', '__pycache__'}.intersection(path.parts):
                archive.write(path, path.relative_to(root).as_posix())
    for name in ['README.md', 'CODEX_HANDOFF.md']:
        archive.write(root / name, name)
with zipfile.ZipFile(source) as archive:
    assert archive.testzip() is None
    assert 'runtime/vgd_scenes/update_notice.rb' in archive.namelist()
print(f'Packaged and verified: {target} + {source}')
