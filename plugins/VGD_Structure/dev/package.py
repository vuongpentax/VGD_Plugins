# Đóng gói VGD Structure thành .rbz. Từ gốc repo: python plugins/VGD_Structure/dev/package.py <phiên bản>
# <phiên bản> phải khớp VERSION trong runtime/vgd_structure.rb (x.y.z hoặc x.y.z-beta.N).
# Kết quả: plugins/VGD_Structure/outputs/local_release_<phiên bản>/VGD_Structure_v<phiên bản>.rbz (outputs/ không đưa vào git).
from pathlib import Path
import hashlib
import re
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
runtime = root / 'runtime'


def fail(message):
    print(f'LỖI: {message}')
    sys.exit(1)


match = re.search(r"VERSION = '(\d+\.\d+\.\d+(?:-(?:alpha|beta)\.\d+)?)'", (runtime / 'vgd_structure.rb').read_text(encoding='utf-8'))
if not match:
    fail('Không tìm thấy VERSION hợp lệ trong runtime/vgd_structure.rb')
version = match.group(1)
if len(sys.argv) > 1 and sys.argv[1] != version:
    fail(f'VERSION trong mã là {version}, không phải {sys.argv[1]}.')
# Bản thử (x.y.z-beta.N) dùng chung ghi chú của bản chốt x.y.z
notes = root / f"RELEASE_NOTES_v{version.split('-')[0]}.md"
if not notes.exists():
    fail(f'Thiếu {notes.name}')

out_dir = root / 'outputs' / f'local_release_{version}'
target = out_dir / f'VGD_Structure_v{version}.rbz'
if target.exists():
    fail(f'Đã tồn tại, không ghi đè: {target}')
out_dir.mkdir(parents=True, exist_ok=True)

files = sorted(path for path in runtime.rglob('*') if path.is_file() and '__pycache__' not in path.parts)
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.relative_to(runtime).as_posix())

with zipfile.ZipFile(target) as archive:
    if archive.testzip() is not None:
        fail('Gói zip bị lỗi.')
    names = archive.namelist()
    for required in ['vgd_structure.rb', 'vgd_structure/loader.rb', 'vgd_structure/core/schema.rb', 'vgd_structure/core/grid.rb', 'vgd_structure/core/axis_symbol.rb', 'vgd_structure/model_store.rb', 'vgd_structure/grid_tag.rb', 'vgd_structure/grid_builder.rb', 'vgd_structure/panel.rb', 'vgd_structure/html/index.html', 'vgd_structure/html/app.js', 'vgd_structure/html/style.css', 'vgd_structure/html/vgd-theme/vgd-theme.css', 'vgd_structure/assets/icons/grid.svg']:
        if required not in names:
            fail(f'Gói thiếu {required}')
    for name in names:
        if archive.read(name) != (runtime / name).read_bytes():
            fail(f'Nội dung gói khác nguồn: {name}')

data = target.read_bytes()
print(f'Đã tạo: {target}')
print(f'Số file: {len(names)}  Dung lượng: {len(data)} byte')
print(f'SHA-256: {hashlib.sha256(data).hexdigest()}')
