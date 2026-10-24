"""Kiểm tra các danh sách file runtime của VGD_Cabinet không bị lệch nhau.

Danh sách file runtime được viết ở bốn nơi: package_menu.py (đóng gói), sync_sketchup_2022.ps1 (cài vào
SketchUp), test_deploy.py (kiểm tra cài) và reload.rb (nạp lại mã Ruby). Test này đọc cả bốn và so với
thư mục cabinet_work, để thêm hoặc đổi tên file mà quên một nơi sẽ bị phát hiện ngay.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
runtime = root / 'cabinet_work'
RUNTIME_DIR = 'VGD_Cabinet'


def quoted(text):
    return re.findall(r"'([^']+)'", text)


def statement(source, start, end):
    first = source.index(start)
    return source[first:source.index(end, first)]


def with_prefix(tokens):
    """Ghép tiền tố VGD_Cabinet/ cho các tên chỉ có phần tên file, giữ nguyên loader vgd_cabinet.rb."""
    names = [token for token in tokens if token != RUNTIME_DIR + '/']
    return [name if name == 'vgd_cabinet.rb' else RUNTIME_DIR + '/' + name for name in names]


package = with_prefix(quoted(statement((root / 'cabinet_dev/package_menu.py').read_text(encoding='utf-8'), 'files = [', 'assert len(files)')))
deploy_test = with_prefix(quoted(statement((root / 'cabinet_dev/test_deploy.py').read_text(encoding='utf-8'), 'files=[', '\n')))
ps1_text = (root / 'cabinet_dev/sync_sketchup_2022.ps1').read_text(encoding='utf-8-sig')
ps1 = [token.replace('\\', '/') for token in quoted(statement(ps1_text, '$ownedFiles = @(', ')\n'))]
reload_text = (runtime / RUNTIME_DIR / 'reload.rb').read_text(encoding='utf-8-sig')
reload_list = re.search(r'%w\[(.*?)\]', reload_text, re.S).group(1).split()

for label, files in (('package_menu.py', package), ('test_deploy.py', deploy_test), ('sync_sketchup_2022.ps1', ps1)):
    assert len(files) == len(set(files)), f'{label}: có file bị trùng trong danh sách'
    assert len(files) == 23, f'{label}: cần 23 file, đang có {len(files)}'

assert set(package) == set(deploy_test), f'package_menu.py khác test_deploy.py: {sorted(set(package) ^ set(deploy_test))}'
assert set(package) == set(ps1), f'package_menu.py khác sync_sketchup_2022.ps1: {sorted(set(package) ^ set(ps1))}'
missing = [name for name in package if not (runtime / name).is_file()]
assert not missing, f'file trong danh sách nhưng không có trong cabinet_work: {missing}'

ruby_in_runtime = {path.name for path in (runtime / RUNTIME_DIR).glob('*.rb')}
assert len(reload_list) == len(set(reload_list)), 'reload.rb: file bị trùng trong ruby_files'
assert set(reload_list) | {'reload.rb'} == ruby_in_runtime, \
    f'reload.rb khác các file .rb trong cabinet_work/{RUNTIME_DIR}: {sorted((set(reload_list) | {"reload.rb"}) ^ ruby_in_runtime)}'
packaged_ruby = {name.split('/', 1)[1] for name in package if name.startswith(RUNTIME_DIR + '/') and name.endswith('.rb')}
assert packaged_ruby == ruby_in_runtime, f'file .rb đóng gói khác file .rb trong runtime: {sorted(packaged_ruby ^ ruby_in_runtime)}'

print(f'PASS: 4 danh sách file runtime khớp nhau và khớp cabinet_work ({len(package)} file đóng gói, {len(reload_list) + 1} file Ruby)')
