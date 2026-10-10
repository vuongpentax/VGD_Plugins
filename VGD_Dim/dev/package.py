from pathlib import Path
import hashlib
import json
import re
import zipfile

root = Path(__file__).resolve().parent.parent
runtime = root / 'runtime'
output = root / 'outputs'
output.mkdir(exist_ok=True)
version_text = (runtime / 'VGD_Dim/version.rb').read_text(encoding='utf-8')
match = re.search(r"VERSION\s*=\s*'([^']+)'", version_text)
if not match:
    raise SystemExit('Cannot determine VGD Dim version.')
version = match.group(1)
runtime_files = ['vgd_dim.rb'] + ['VGD_Dim/' + name for name in [
    'main.rb', 'defaults.rb', 'reload.rb', 'engine.rb', 'native_style.rb', 'store.rb',
    'managed.rb', 'core.rb', 'presets.rb', 'autostyle.rb', 'animation.rb', 'smartdim.rb', 'regions.rb', 'manual_dim.rb',
    'probe.rb', 'dialog.rb', 'dialog.html', 'dialog.css', 'dialog.js', 'dim.svg',
    'smart_dim.svg', 'version.rb', 'update_core/manifest.rb', 'update_core/bootstrap.rb',
    'update_core/client.rb', 'update_core/installer.rb', 'update_core/updater.rb',
    'update_core/update_installer.ps1'
]]
for name in runtime_files:
    if not (runtime / name).is_file():
        raise SystemExit(f'Missing runtime file: {name}')
rbz = output / f'VGD_Dim_v{version}.rbz'
source_zip = output / f'VGD_Dim_v{version}_source.zip'
with zipfile.ZipFile(rbz, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in runtime_files:
        archive.write(runtime / name, name)
with zipfile.ZipFile(rbz) as archive:
    if archive.testzip() is not None or archive.namelist() != runtime_files:
        raise SystemExit('RBZ validation failed: unexpected entry or corrupt archive.')
    for name in runtime_files:
        if archive.read(name) != (runtime / name).read_bytes():
            raise SystemExit(f'RBZ content differs from runtime: {name}')
manifest_path = root / 'VGD_UPDATE_MANIFEST.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
manifest.update({
    'product_id': 'vgd_dim',
    'version': version,
    'channel': 'beta' if '-' in version else 'stable',
    'min_sketchup_year': '2022',
    'filename': rbz.name,
    'bytes': rbz.stat().st_size,
    'sha256': hashlib.sha256(rbz.read_bytes()).hexdigest(),
    'download_url': f"https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/main/shared/vgd-center/packages/{rbz.name}"
})
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
dev_files = [
    'check_ruby.cjs', 'test_fixture.rb', 'test_engine.rb', 'test_native_style.rb',
    'test_core.rb', 'test_smartdim.rb', 'test_ui.cjs', 'import_claude_ui.py',
    'build_ui.py', 'native_smoke.rb', 'deploy.ps1', 'test_deploy.py',
    'test_store.rb', 'test_update_installer.ps1', 'package.py'
]
doc_files = [
    'README.md', 'AGENTS.md', 'ANNOTATION_REQUIREMENTS.md', 'SELECTION_REQUIREMENTS.md',
    'FEATURE_STATUS.md', 'UI_DESIGN.md', 'DEVELOPMENT_NOTES.md', 'VGD_UPDATE_MANIFEST.json',
    'HOW_TO_RELEASE.md', f'RELEASE_NOTES_v{version}.md'
]
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in runtime_files:
        archive.write(runtime / name, 'runtime/' + name)
    for name in dev_files:
        path = root / 'dev' / name
        if path.is_file():
            archive.write(path, 'dev/' + name)
    for folder in ['claude_reference', 'claude_v6_reference']:
        path = root / 'dev' / folder
        if path.exists():
            for file in sorted(path.rglob('*')):
                if file.is_file():
                    archive.write(file, file.relative_to(root).as_posix())
    for name in doc_files:
        path = root / name
        if path.is_file():
            archive.write(path, name)
    validation = output / 'VALIDATION.json'
    if validation.is_file():
        archive.write(validation, 'outputs/VALIDATION.json')
with zipfile.ZipFile(source_zip) as archive:
    if archive.testzip() is not None or json.loads(archive.read('VGD_UPDATE_MANIFEST.json')) != manifest:
        raise SystemExit('Source ZIP validation failed.')
hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [rbz, source_zip]}
(output / 'PACKAGES_SHA256.json').write_text(json.dumps(hashes, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'version': version, 'runtime_files': len(runtime_files), 'rbz_bytes': rbz.stat().st_size,
                  'sha256': hashes[rbz.name], 'source_zip': source_zip.name}, indent=2))
