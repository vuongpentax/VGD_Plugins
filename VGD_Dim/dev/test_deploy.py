from pathlib import Path
import json
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
outputs = root / 'outputs'
outputs.mkdir(exist_ok=True)
shell = Path(os.environ.get('VGD_POWERSHELL_PATH', r'C:/Users/TUNG/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'))

with tempfile.TemporaryDirectory(prefix='deploy_fixture_', dir=outputs) as directory:
    fixture = Path(directory).resolve()
    assert fixture.is_relative_to(outputs.resolve())
    plugins = fixture / 'SketchUp/SketchUp 2022/SketchUp/Plugins'
    plugins.mkdir(parents=True)
    legacy = plugins / 'tplus_dim.rb'
    legacy_bytes = b"module TPlus\n module Dim\n end\nend\n# TPlus_Dim/main\n"
    legacy.write_bytes(legacy_bytes)
    other = plugins / 'tplus_cabinet.rb'
    other.write_bytes(b'CABINET MUST BE PRESERVED')
    env = dict(os.environ, APPDATA=str(fixture))
    def deploy(*arguments):
        return subprocess.run([str(shell), '-NoProfile', '-File', str(root / 'dev/deploy.ps1'), *arguments],
                              env=env, capture_output=True, text=True, encoding='utf-8')
    result = deploy('-VerifyOnly')
    assert result.returncode == 0, result.stderr
    assert legacy.read_bytes() == legacy_bytes and not (plugins / 'vgd_dim.rb').exists()
    result = deploy()
    assert result.returncode == 0, result.stderr
    assert not legacy.exists()
    assert other.read_bytes() == b'CABINET MUST BE PRESERVED'
    owned = ['vgd_dim.rb'] + ['VGD_Dim/' + name for name in
        ['main.rb','defaults.rb','reload.rb','engine.rb','native_style.rb','dialog.html','dialog.css','dialog.js','dim.svg']]
    for name in owned:
        assert (plugins / name).read_bytes() == (root / 'runtime' / name).read_bytes(), name
    reports = [json.loads(path.read_text(encoding='utf-8-sig')) for path in outputs.glob('install_*/INSTALL_REPORT.json')]
    report = next(item for item in reports if item['Target'] == str(plugins))
    assert report['Status'] == 'VERIFIED' and report['LegacyLoaderDisabled']
    assert Path(report['LegacyBackup']).read_bytes() == legacy_bytes
    result = deploy()
    assert result.returncode == 0, result.stderr
    before = {name: (plugins / name).read_bytes() for name in owned}
    legacy.write_bytes(b'UNRELATED LOADER')
    result = deploy()
    assert result.returncode != 0
    assert legacy.read_bytes() == b'UNRELATED LOADER'
    assert all((plugins / name).read_bytes() == data for name, data in before.items())
    legacy.unlink()
    (plugins / 'vgd_dim.rb').write_bytes(b'FOREIGN VGD LOADER')
    result = deploy()
    assert result.returncode != 0 and (plugins / 'vgd_dim.rb').read_bytes() == b'FOREIGN VGD LOADER'
    assert other.read_bytes() == b'CABINET MUST BE PRESERVED'
print('PASS: deploy dry-run, T+ loader backup/retirement, 10 exact VGD files, repeated install, foreign-loader guards and Cabinet preservation')
