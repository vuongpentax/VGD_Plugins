from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import json

root = Path(__file__).resolve().parents[1]
out = root / 'outputs/vgd_cabinet_modeling'
out.mkdir(parents=True, exist_ok=True)
version = '4.5.3'
files = ['vgd_cabinet.rb'] + ['VGD_Cabinet/' + name for name in [
    'main43.rb', 'geometry_engine.rb', 'modeling_rules.rb', 'modeling.rb', 'pano.rb','component_sharing.rb','frame_divisions.rb','rail_joinery.rb','preview_mesh.rb','library_store.rb', 'model_data.rb', 'box_conversion.rb', 'preset_store.rb', 'description_import.rb',
    'defaults.rb', 'draw_tool.rb', 'ui_renderer.rb', 'VGD_Cabinet_UI.html',
    'reload.rb', 'update_notice.rb', 'cabinet.svg', 'HUONG_DAN.txt']]
assert len(files) == 23
runtime = (root / 'cabinet_work/VGD_Cabinet/main43.rb').read_text(encoding='utf-8')
bootstrap = (root / 'cabinet_work/vgd_cabinet.rb').read_text(encoding='utf-8')
ui = (root / 'cabinet_work/VGD_Cabinet/VGD_Cabinet_UI.html').read_text(encoding='utf-8')
assert f"VERSION = '{version}'" in runtime
assert f"ex.version     = '{version}'" in bootstrap
assert f"<title>VGD Cabinet {version}</title>" in ui
assert f'class="brand-version">{version}</small>' in ui
assert 'VGD_EXPLODE' not in runtime and 'VGD_UNTAG' not in runtime
rbz = out / f'VGD_Cabinet_v{version}.rbz'
source = out / f'VGD_Cabinet_v{version}_source.zip'
with ZipFile(rbz, 'w', ZIP_DEFLATED) as z:
    for file in files:
        z.write(root / 'cabinet_work' / file, file)
with ZipFile(source, 'w', ZIP_DEFLATED) as z:
    for file in files:
        z.write(root / 'cabinet_work' / file, 'cabinet_work/' + file)
    for file in ['check_ruby.cjs', 'dependencies.cjs', 'sketchup_stub.rb', 'test_geometry.rb','test_upgrade.rb','test_library.rb','test_upgrade_ui.cjs','test_preview.cjs','native_upgrade.rb', 'test_vgd_features.rb', 'test_presets.rb', 'test_deploy.py', 'test_manifest.py',
                 'test_dom.cjs', 'test_payload.cjs', 'test_ui.cjs', 'test_description.rb', 'test_description.cjs', 'description_partial_fixture.json',
                 'defaults.json', 'presets.json', 'redesign_ui.cjs',
                 'ui_beta1.html', 'menu.css', 'menu.js', 'package_menu.py',
                 'sketchup_ui_stub.rb', 'test_commands.rb',
                 'package.json', 'pnpm-lock.yaml', 'test_reload.rb', 'sync_sketchup_2022.ps1']:
        z.write(root / 'cabinet_dev' / file, 'cabinet_dev/' + file)
    z.write(root / 'CODEX_HANDOFF.md', 'CODEX_HANDOFF.md')
    z.write(root / 'AGENTS.md', 'AGENTS.md')
    for file in ['README.md','PANO_RESEARCH.md','UPGRADE_RESEARCH.md','VALIDATION.json','RELEASE_NOTES_v4.5.3.md']:
        z.write(root/file,file)
    z.write(root / 'TESTS.txt', 'TESTS.txt')
for path in [rbz, source]:
    with ZipFile(path) as z:
        assert z.testzip() is None
    print(path, path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest())
with ZipFile(rbz) as z:
    assert set(z.namelist())==set(files)
    assert all(z.read(name)==(root/'cabinet_work'/name).read_bytes() for name in files)
sha_path = out / 'SHA256.json'
hashes = json.loads(sha_path.read_text(encoding='utf-8')) if sha_path.exists() else {}
hashes.update({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [rbz,source]})
sha_path.write_text(json.dumps(hashes,indent=2),encoding='utf-8')
