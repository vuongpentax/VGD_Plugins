# encoding: UTF-8
# Kiểm thử phần Ruby của tính năng layout/phím tắt (lập job, snapshot, xuất/nhập).
# Không chạy PowerShell: helper/apply_layout.ps1 chỉ được kiểm tra trong SketchUp thật trên Windows.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'base64'
$LOAD_PATH.unshift(File.join(__dir__, 'stub'))

build = File.expand_path(ARGV[0])
fake = Dir.mktmpdir('fake_appdata')
ENV['APPDATA'] = fake
ENV['TEMP'] = Dir.tmpdir
plug = File.join(fake, 'SketchUp/SketchUp 2024/SketchUp/Plugins')
FileUtils.mkdir_p(plug)
File.write(File.join(plug, 'alpha.rb'), "a\n")
File.write(File.join(plug, 'beta.rb'), "b\n")

require File.join(build, 'VGD_PluginManager/main')
L = VGD::PluginManager::Layout
T = VGD::PluginManager::Toggle

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

spawned = []
L.spawner = ->(args) { spawned << args }

# --- Thư mục của bộ ---
d1 = L.preset_dir('Render')
check 'tên thư mục nằm trong layouts', d1.start_with?(L.layouts_dir)
check 'hai tên khác nhau có thư mục khác nhau', L.preset_dir('Render') != L.preset_dir('render') && L.preset_dir('a b') != L.preset_dir('a_b')
evil = L.preset_dir('../../x')
check 'tên có ../ không thoát khỏi layouts', File.expand_path(evil).start_with?(File.expand_path(L.layouts_dir) + '/') && !File.basename(evil).include?('/')
check 'tên tiếng Việt giữ được chữ', File.basename(L.preset_dir('Vẽ nhà')).start_with?('Vẽ_nhà-')

# --- Lập job ---
msg = L.schedule_capture('Render', %w[layout shortcuts bậy])
job = JSON.parse(File.read(L.job_file))
check 'schedule trả về hướng dẫn đóng SketchUp', msg.include?('File > Exit')
check 'helper được chạy một lần với PowerShell, Bypass, -File và -Job', spawned.size == 1 &&
  spawned[0][0] == 'powershell.exe' && spawned[0].include?('Bypass') && spawned[0].include?('-File') && spawned[0].include?('-Job') &&
  spawned[0].last.end_with?('job.json'.tr('/', '\\')) 
check 'job có pid, id, log, kết quả, sao lưu', job['sketchup_pid'] == Process.pid && job['id'].to_s.size == 16 &&
  job['log'] == VGD::PluginManager::Log.path && job['result'] == L.result_file && job['backup_dir'] == L.backup_dir && job['restart'] == true
step = job['steps'][0]
check 'bước capture đúng năm, thư mục, và bỏ phần lạ', step == { 'op' => 'capture', 'year' => '2024', 'dir' => L.preset_dir('Render'), 'parts' => %w[layout shortcuts] }
L.schedule_capture('Render', ['layout'])
check 'job mới có id khác (job cũ tự hủy)', JSON.parse(File.read(L.job_file))['id'] != job['id']
check 'không chọn mục nào thì không lập job', L.schedule_capture('Render', []).include?('ít nhất') && spawned.size == 2
Sketchup.platform = :platform_osx
check 'không phải Windows thì từ chối', L.schedule_capture('Render', ['layout']).include?('Windows') && spawned.size == 2
Sketchup.platform = :platform_win

# --- Snapshot: nhập, đọc thông tin, áp ---
check 'chưa có snapshot thì info nil', L.info('Render').nil?
check 'áp khi chưa lưu bị từ chối', L.schedule_apply('Render', ['layout']).include?('chưa lưu')
snap = { 'year' => '2024', 'saved_at' => '2026-10-30 12:00:00',
         'prefs' => { 'ToolbarSettings' => { 'LargeIcons' => 1 }, 'QtRubyWorkspace\\RubyToolBar-59648' => { 'Tray' => 1 },
                      'MainWindow' => { 'DockWidgetState' => 'abcd', 'ToolBarState' => '0011', 'Geometry' => 'khong-duoc-nhan' },
                      'Evil' => { 'x' => 1 }, 'DangerousSetting' => 'x' },
         'shortcuts' => { 'Num_Shortcuts' => 2, 'Shortcut_1' => '0 0 0 H selectDollyTool:', 'Shortcut_2' => '0 1 1 9 Camera/Next',
                          'NotShortcut' => 'x', 'Shortcut_3' => { 'a' => 1 } } }
blob = { 'layout' => snap, 'registry' => { 'Workspace' => Base64.strict_encode64("REG\xFF\xFE".b), 'Other' => Base64.strict_encode64('x') } }
check 'nhập snapshot hợp lệ', L.import_blob('Render', blob) == true
saved = JSON.parse(File.read(File.join(L.preset_dir('Render'), 'layout.json')))
check 'chỉ giữ các khóa layout cho phép', saved['prefs'].keys.sort == ['MainWindow', 'QtRubyWorkspace\\RubyToolBar-59648', 'ToolbarSettings'] &&
  saved['prefs']['MainWindow'].keys.sort == %w[DockWidgetState ToolBarState]
check 'chỉ giữ phím tắt hợp lệ (khóa đúng và giá trị chuỗi/số)', saved['shortcuts'].keys.sort == %w[Num_Shortcuts Shortcut_1 Shortcut_2]
check 'chỉ nhận file .reg Workspace/RubyWorkspace, nội dung nhị phân giữ nguyên',
  File.binread(File.join(L.preset_dir('Render'), 'Workspace.reg')) == "REG\xFF\xFE".b && !File.exist?(File.join(L.preset_dir('Render'), 'Other.reg'))
i = L.info('Render')
check 'info đúng', i['year'] == '2024' && i['layout'] && i['shortcuts'] && i['saved_at'].start_with?('2026')

check 'năm sai bị từ chối', L.import_blob('X', { 'layout' => { 'year' => '../x' } }) == false
check 'cấu trúc sai bị từ chối', L.import_blob('X', 'abc') == false && L.import_blob('X', { 'layout' => 5 }) == false
check 'base64 hỏng không làm crash', L.import_blob('X', { 'layout' => { 'year' => '2024' }, 'registry' => { 'Workspace' => '!!!' } }) == false
big = Base64.strict_encode64('a' * (L::MAX_BLOB_BYTES + 1))
check 'file registry quá lớn bị từ chối', L.import_blob('X', { 'layout' => { 'year' => '2024' }, 'registry' => { 'Workspace' => big } }) == false
check 'nhập hỏng không để lại thư mục dở dang', L.info('X').nil?

# --- Áp dụng ---
spawned.clear
L.schedule_apply('Render', %w[layout shortcuts])
st = JSON.parse(File.read(L.job_file))['steps'][0]
check 'áp cùng năm: layout + phím tắt', st == { 'op' => 'apply', 'year' => '2024', 'dir' => L.preset_dir('Render'), 'parts' => %w[layout shortcuts] }
old = { 'layout' => snap.merge('year' => '2022'), 'registry' => {} }
L.import_blob('Cu2022', old)
msg = L.schedule_apply('Cu2022', ['layout'])
check 'layout khác năm không áp được', msg.include?('2022') && msg.include?('không áp được') && spawned.size == 1
L.schedule_apply('Cu2022', %w[layout shortcuts])
check 'khác năm: chỉ áp phím tắt', JSON.parse(File.read(L.job_file))['steps'][0]['parts'] == ['shortcuts']

# --- Chuyển phím tắt giữa hai bản ---
L.schedule_shortcuts_transfer('2022', '2024')
steps = JSON.parse(File.read(L.job_file))['steps']
check 'chuyển phím tắt: capture từ nguồn rồi apply vào đích, cùng thư mục tạm',
  steps.size == 2 && steps[0]['op'] == 'capture' && steps[0]['year'] == '2022' && steps[1]['op'] == 'apply' && steps[1]['year'] == '2024' &&
  steps[0]['dir'] == steps[1]['dir'] && steps.all? { |s| s['parts'] == ['shortcuts'] }

# --- Kết quả helper ---
check 'chưa có kết quả thì nil', L.take_result.nil?
FileUtils.mkdir_p(L.jobs_dir)
File.write(L.result_file, "Da luu\r\nXong\r\n")
check 'đọc kết quả một lần rồi xóa', L.take_result == "Da luu\r\nXong" && !File.exist?(L.result_file) && L.take_result.nil?

# --- Xuất/nhập bộ kèm layout ---
FileUtils.rm_rf(L.layouts_dir)
T.save_set('Render', %w[alpha beta])
T.save_set('Khac', %w[alpha])
L.import_blob('Render', blob)
state = T.state['sets'].map { |s| [s['name'], s['layout'] && s['layout']['year']] }.to_h
check 'state có thông tin layout theo bộ', state == { 'Khac' => nil, 'Render' => '2024' }
out = File.join(Dir.tmpdir, "sets_layout_#{$$}.json")
msg = T.export_sets(out)
exp = JSON.parse(File.read(out))
check 'xuất ghi version 2 và layout của bộ có lưu', exp['version'] == 2 && exp['layouts'].keys == ['Render'] && msg.include?('kèm layout')
sets, err, layouts = T.read_sets_file(out)
check 'đọc lại có layout', err.nil? && sets.keys.sort == %w[Khac Render] && layouts.keys == ['Render']
T.delete_set('Render'); T.delete_set('Khac')
check 'xóa bộ xóa luôn layout của nó', L.info('Render').nil? && !File.exist?(L.preset_dir('Render'))
msg = T.import_sets(sets, false, layouts)
check 'nhập khôi phục bộ và layout', msg.include?('layout/phím tắt của 1 bộ') && L.info('Render') && L.info('Render')['shortcuts']
raw = JSON.parse(File.read(out)); raw['layouts']['Render']['layout']['year'] = 'bậy'
File.write(out, JSON.generate(raw))
s2, e2, l2 = T.read_sets_file(out)
T.delete_set('Render')
msg = T.import_sets(s2, false, l2)
check 'layout hỏng trong file nhập bị bỏ qua, bộ vẫn nhập', !msg.include?('layout/phím tắt') && T.load_sets.key?('Render') && L.info('Render').nil?
old_v1 = { 'format' => 'vgd_plugin_sets', 'version' => 1, 'sets' => { 'Cu' => ['alpha'] } }
File.write(out, JSON.generate(old_v1))
s3, e3, l3 = T.read_sets_file(out)
check 'file định dạng cũ (version 1) vẫn đọc được', e3.nil? && s3 == { 'Cu' => ['alpha'] } && l3 == {}

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
