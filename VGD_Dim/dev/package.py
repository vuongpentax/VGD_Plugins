from pathlib import Path
import zipfile
import hashlib
import json
import re

root = Path(__file__).resolve().parent.parent
output = root / 'outputs'
output.mkdir(exist_ok=True)
version = re.search(r"VERSION\s*=\s*'([^']+)'", (root / 'runtime/vgd_dim.rb').read_text(encoding='utf-8')).group(1)
files = ['vgd_dim.rb'] + ['VGD_Dim/' + name for name in [
    'main.rb', 'defaults.rb', 'reload.rb', 'engine.rb', 'native_style.rb',
    'store.rb', 'core.rb', 'presets.rb', 'autostyle.rb', 'animation.rb', 'smartdim.rb', 'probe.rb', 'dialog.rb',
    'dialog.html', 'dialog.css', 'dialog.js', 'dim.svg']]
rbz = output / f'VGD_Dim_v{version}.rbz'
source = output / f'VGD_Dim_v{version}_source.zip'
with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(root / 'runtime' / name, name)
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(root / 'runtime' / name, 'runtime/' + name)
    for name in ['check_ruby.cjs', 'test_fixture.rb', 'test_engine.rb', 'test_native_style.rb', 'test_core.rb', 'test_smartdim.rb', 'test_ui.cjs', 'import_claude_ui.py',
                 'native_smoke.rb', 'deploy.ps1', 'test_deploy.py', 'test_store.rb', 'package.py']:
        archive.write(root / 'dev' / name, 'dev/' + name)
    for file in sorted((root / 'dev/claude_reference').iterdir()):
        archive.write(file, 'dev/claude_reference/' + file.name)
    for name in ['README.md', 'AGENTS.md', 'SELECTION_REQUIREMENTS.md', 'FEATURE_STATUS.md']:
        archive.write(root / name, name)
    archive.write(output / 'VALIDATION.json', 'outputs/VALIDATION.json')
for file in [rbz, source]:
    with zipfile.ZipFile(file) as archive:
        assert archive.testzip() is None
with zipfile.ZipFile(rbz) as archive:
    assert set(archive.namelist()) == set(files)
    assert all((root / 'runtime' / n).read_bytes() == archive.read(n) for n in files)
manifest = {file.name: hashlib.sha256(file.read_bytes()).hexdigest() for file in [rbz, source]}
(output / 'PACKAGES_SHA256.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({'files': len(files), 'bytes': rbz.stat().st_size, 'sha256': manifest}, indent=2))
