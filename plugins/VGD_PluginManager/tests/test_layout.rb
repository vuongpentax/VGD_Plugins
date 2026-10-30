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
TB_KEY = 'QtRubyWorkspace\\\\RubyToolBar-59648'   # khóa thô trong file: hai dấu gạch chéo
good_tb = ["        \"#{TB_KEY}\": {", '            "Floating": false', '            "Height": 30', '            "Tray": 1', '        }']
snap = { 'year' => '2024', 'saved_at' => '2026-10-30 12:00:00',
         'blocks' => { 'ToolbarSettings' => ['        "ToolbarSettings": {', '            "LargeIcons": false', '            "ToolbarState": "ff0001"', '        }'],
                       TB_KEY => good_tb,
                       'Evil' => ['        "Evil": {', '            "x": 1', '        }'],
                       'Workspace\\\\Trays' => ['        "Workspace\\\\Trays": {', '            "Count": 2', '        },', '        "Evil2": {', '            "x": 1', '        }'] },
         'main_window' => { 'DockWidgetState' => '"DockWidgetState": "7b0a20"', 'ToolBarState' => '"ToolBarState": "0011"',
                            'Geometry' => '"Geometry": "khong-duoc-nhan"', 'Evil' => '"Evil": "x"' },
         'shortcuts' => { 'Num_Shortcuts' => 2, 'Shortcut_1' => '0 0 0 H selectDollyTool:', 'Shortcut_2' => '0 1 1 9 Camera/Next',
                          'NotShortcut' => 'x', 'Shortcut_3' => { 'a' => 1 } } }
blob = { 'layout' => snap, 'registry' => { 'Workspace' => Base64.strict_encode64("REG\xFF\xFE".b), 'Other' => Base64.strict_encode64('x') } }
check 'nhập snapshot hợp lệ', L.import_blob('Render', blob) == true
saved = JSON.parse(File.read(File.join(L.preset_dir('Render'), 'layout.json')))
check 'chỉ giữ các khối layout đúng cấu trúc (bỏ khóa lạ và khối có mục thừa chèn kèm)', saved['blocks'].keys.sort == ['ToolbarSettings', TB_KEY].sort && saved['blocks'][TB_KEY] == good_tb
check 'MainWindow chỉ giữ DockWidgetState và ToolBarState (bỏ Geometry và khóa lạ)', saved['main_window'].keys.sort == %w[DockWidgetState ToolBarState]
check 'snapshot cũ (format 1, có prefs) không còn được nhận', !saved.key?('prefs') && saved['format'] == 2
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

# --- Bộ kiểm tra khối layout ---
check 'khối hợp lệ được nhận', L.valid_block?(TB_KEY, good_tb)
check 'khóa không thuộc nhóm layout bị từ chối', !L.valid_block?('Evil', ['        "Evil": {', '            "x": 1', '        }'])
check 'dòng đầu không khớp khóa bị từ chối', !L.valid_block?(TB_KEY, ['        "Other": {', '            "x": 1', '        }'])
check 'khối có mục thừa chèn kèm bị từ chối', !L.valid_block?('ToolbarSettings', ['        "ToolbarSettings": {', '            "x": 1', '        },', '        "Evil": {', '            "y": 2', '        }'])
check 'khối có giá trị lồng nhau hoặc mảng bị từ chối', !L.valid_block?('ToolbarSettings', ['        "ToolbarSettings": {', '            "x": {"a": 1}', '        }']) &&
  !L.valid_block?('ToolbarSettings', ['        "ToolbarSettings": {', '            "x": [1, 2]', '        }'])
check 'thụt lề sai hoặc có dấu phẩy thừa bị từ chối', !L.valid_block?('ToolbarSettings', ['    "ToolbarSettings": {', '        "x": 1', '    }']) &&
  !L.valid_block?('ToolbarSettings', ['        "ToolbarSettings": {', '            "x": 1,', '        }'])
check 'khối quá dài hoặc quá nhiều khối bị từ chối', !L.valid_block?('ToolbarSettings', ['        "ToolbarSettings": {', *(['            "x": 1'] * (L::MAX_BLOCK_LINES + 1)), '        }']) &&
  L.clean_blocks((1..(L::MAX_BLOCKS + 1)).map { |i| ["Workspace\\\\T#{i}", ["        \"Workspace\\\\T#{i}\": {", '            "a": 1', '        }']] }.to_h).empty?
check 'MainWindow chỉ nhận chuỗi đúng khóa', L.clean_main_window('DockWidgetState' => '"DockWidgetState": "ab"').size == 1 &&
  L.clean_main_window('DockWidgetState' => '"ToolBarState": "ab"').empty? && L.clean_main_window('DockWidgetState' => '"DockWidgetState": {"a": 1}').empty? &&
  L.clean_main_window('Geometry' => '"Geometry": "ab"').empty?

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

no_reg = { 'layout' => snap.merge('year' => '2024'), 'registry' => {} }
L.import_blob('KhongReg', no_reg)
spawned.clear
L.schedule_apply('KhongReg', ['layout'])
check 'layout 2024 chỉ có trong file cài đặt (không có registry) vẫn áp được', JSON.parse(File.read(L.job_file))['steps'][0]['parts'] == ['layout']
only_sc = { 'layout' => { 'year' => '2024', 'shortcuts' => { 'Num_Shortcuts' => 1, 'Shortcut_1' => '0 0 0 H selectDollyTool:' } } }
L.import_blob('ChiPhim', only_sc)
msg = L.schedule_apply('ChiPhim', ['layout'])
check 'bộ chỉ có phím tắt mà đòi áp layout thì báo không có gì để áp', msg.include?('Không có mục nào') || msg.include?('chưa lưu')
L.schedule_apply('ChiPhim', %w[layout shortcuts])
check 'bộ chỉ có phím tắt: chỉ áp phím tắt', JSON.parse(File.read(L.job_file))['steps'][0]['parts'] == ['shortcuts']
spawned.clear

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

# --- Nhập phím tắt từ file .dat ---
def write_dat(path, text)
  File.binwrite(path, "\xFF\xFE".b + text.encode('UTF-16LE').b)
end
dat = File.join(Dir.tmpdir, "sc_#{$$}.dat")
body = "[Accelerator]\r\nCount=7\r\n0 0 0 I selectImageIglooTool:\r\n1 0 1 S File/Save Incremental\r\n" \
       "0 0 1 H Tools/One Click Tools/Ẩn\r\n0 1 0 ` Extensions/PTL Tools/Thông tin đối tượng\r\n0 0 0 , Edit/Item/Rotate 90/Around Blue\r\n" \
       "hong 0 0 X khong hop le\r\n0 0 0 I selectOrbitTool:\r\n[File Locations]\r\nModels=C:\\Users\\PC\\Documents\\\r\nEvil=1 2 3 4 abc\r\n"
write_dat(dat, body)
data, err = L.parse_dat(dat)
check 'đọc .dat UTF-16 có BOM, không lỗi', err.nil? && data
sc = data[:shortcuts]
check 'đếm đúng: trùng tổ hợp phím thì dòng sau thay, dòng sai định dạng bị bỏ qua', sc['Num_Shortcuts'] == 5 && data[:skipped] == 1 && data[:declared] == 7
check 'đánh số Shortcut_1..N liên tục và giữ nguyên dòng gốc (tiếng Việt, ký tự đặc biệt)',
  sc.keys.grep(/\AShortcut_/).size == 5 && sc['Shortcut_1'] == '0 0 0 I selectOrbitTool:' && sc.values.include?('0 0 1 H Tools/One Click Tools/Ẩn') &&
  sc.values.include?('0 1 0 ` Extensions/PTL Tools/Thông tin đối tượng') && sc.values.include?('0 0 0 , Edit/Item/Rotate 90/Around Blue')
check 'mục [File Locations] bị bỏ qua hoàn toàn', sc.reject { |k, _| k == 'Num_Shortcuts' }.values.none? { |v| v.include?('Models') || v.include?('Evil') || v.include?('C:') }
check 'dữ liệu đọc ra qua được bộ lọc phím tắt', L.clean_shortcuts(sc) == sc

File.binwrite(dat, "\xEF\xBB\xBF[Accelerator]\nCount=1\n0 0 0 H selectDollyTool:\n".b)
d2, e2 = L.parse_dat(dat)
check 'cũng đọc được UTF-8 có BOM và xuống dòng LF', e2.nil? && d2[:shortcuts] == { 'Num_Shortcuts' => 1, 'Shortcut_1' => '0 0 0 H selectDollyTool:' }
File.binwrite(dat, "[File Locations]\nModels=C:\\x\n")
check 'file không có [Accelerator] bị từ chối', L.parse_dat(dat)[1].include?('[Accelerator]')
File.binwrite(dat, "[Accelerator]\nCount=0\n")
check 'không có phím nào hợp lệ bị từ chối', L.parse_dat(dat)[1].include?('không có phím tắt hợp lệ')
File.binwrite(dat, "\xFF\xFE\x41".b)
check 'UTF-16 lẻ byte không làm crash', L.parse_dat(dat)[1].include?('mã hóa')
File.binwrite(dat, "\xFF\xFEx".b + 'a' * (L::DAT_MAX_BYTES + 1))
check 'file quá lớn bị từ chối', L.parse_dat(dat)[1].include?('quá lớn')
check 'file không tồn tại', L.parse_dat(File.join(Dir.tmpdir, 'khong_co_file.dat'))[1].include?('Không tìm thấy')
File.binwrite(dat, "[Accelerator]\n" + (1..(L::DAT_MAX_ENTRIES + 1)).map { |i| "0 0 0 K#{i} selectLineTool:" }.join("\n"))
check 'quá nhiều phím tắt bị từ chối', L.parse_dat(dat)[1].include?('quá nhiều')

spawned.clear
msg = L.schedule_import(sc)
j = JSON.parse(File.read(L.job_file))
snap_in = JSON.parse(File.read(File.join(L.jobs_dir, 'shortcuts_dat', 'layout.json')))
check 'nhập .dat lập một bước apply phím tắt cho năm hiện tại', msg.include?('File > Exit') && spawned.size == 1 && j['steps'].size == 1 &&
  j['steps'][0] == { 'op' => 'apply', 'year' => '2024', 'dir' => File.join(L.jobs_dir, 'shortcuts_dat'), 'parts' => ['shortcuts'] }
check 'snapshot tạm có đúng phím tắt, không có layout', snap_in['shortcuts'] == sc && snap_in['blocks'] == {} && snap_in['main_window'] == {} && snap_in['year'] == '2024'

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
