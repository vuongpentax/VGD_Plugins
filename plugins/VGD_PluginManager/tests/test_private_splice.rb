# encoding: UTF-8
# Kiểm chứng thuật toán chụp/áp layout trong PrivatePreferences.json theo dòng (bản tham chiếu Ruby của helper PowerShell).
# Dữ liệu mẫu dựng theo cấu trúc thật đã khảo sát (docs/NOI_LUU_CAI_DAT_SKETCHUP.md): thụt lề 4, LF, không dấu phẩy cuối.
require 'json'
require_relative 'support/splice_reference'

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

P = PrivateSplice

def entry(key, pairs)
  body = pairs.map { |k, v| "            #{JSON.generate(k)}: #{v}" }.join(",\n")
  body.empty? ? "        #{JSON.generate(key)}: {}" : "        #{JSON.generate(key)}: {\n#{body}\n        }"
end

# toolbars: số lượng thanh công cụ Ruby; mw: các khóa MainWindow; sections: thêm mục tùy ý (đã là văn bản)
def build(toolbars:, mw:, tail: nil, extra: [], flat: true, eol: "\n")
  secs = []
  secs << entry('Application', 'LastRun' => 5, 'Ratio' => '1.0', 'Name' => '"Tiếng Việt"')
  secs << "        \"Extensions\": {\n            \"Sub\": {\n                \"x\": 1,\n                \"y\": 2.0\n            },\n            \"Z\": true\n        }"
  secs << entry('File Locations', 'Models' => JSON.generate('C:\\Users\\x'))
  secs << entry('MainWindow', mw) unless mw.nil?
  toolbars.each { |i| secs << entry("QtRubyWorkspace\\RubyToolBar-#{59_648 + i}", 'Floating' => 'false', 'Height' => 30, 'Tray' => 1, 'Visible' => 'true', 'X' => i * 7, 'Y' => 0) }
  secs << entry('ToolbarSettings', 'LargeIcons' => 'false', 'ToolbarState' => '"ff0001"', 'ToolTipEnabled' => 'true')
  secs << entry('Workspace\\Trays', 'Count' => 2)
  secs << entry('Workspace\\Trays\\Dialogs\\Components', 'Expand' => 'true', 'height' => 120)
  secs << "        \"Workspace\\\\Trays\\\\Weird\": {\n            \"Nested\": {\n                \"a\": 1\n            }\n        }" unless flat
  secs.concat(extra)
  secs << tail if tail
  "{\n    \"This Computer Only\": {\n#{secs.join(",\n")}\n    }\n}".gsub("\n", eol)
end

MW_SRC = { 'DockWidgetState' => JSON.generate('7b0a20' * 3000), 'Geometry' => '"src-geometry"', 'ToolBarState' => '"00000001"' }
MW_DST = { 'DockWidgetState' => '"old-dock"', 'Geometry' => '"dst-geometry"', 'ToolBarState' => '"old-tb"' }
src = build(toolbars: (0...148).to_a, mw: MW_SRC)
dst = build(toolbars: (0...12).to_a, mw: MW_DST)
layout_names = ->(h) { h['This Computer Only'].keys.select { |k| k =~ /\A(Qt)?RubyWorkspace\\|\AWorkspace\\|\AToolbarSettings\z/ } }
non_layout = ->(h) { h['This Computer Only'].reject { |k, _| k =~ /\A(Qt)?RubyWorkspace\\|\AWorkspace\\|\AToolbarSettings\z|\AMainWindow\z/ } }

check 'mẫu hợp lệ', JSON.parse(src) && JSON.parse(dst)
cap = P.capture(src)
check 'chụp đủ: 148 thanh công cụ + ToolbarSettings + 2 mục Workspace', cap[:blocks].size == 148 + 1 + 2 && cap[:skipped] == 0
check 'chụp MainWindow: chỉ DockWidgetState và ToolBarState, bỏ Geometry', cap[:main_window].keys.sort == %w[DockWidgetState ToolBarState] &&
  cap[:main_window]['ToolBarState'] == '"ToolBarState": "00000001"'.sub('"ToolBarState": ', '"ToolBarState": ')
check 'khối chụp là văn bản thô, khóa có hai dấu gạch chéo, không có dấu phẩy sau thuộc tính cuối',
  cap[:blocks].key?('QtRubyWorkspace\\\\RubyToolBar-59648') && cap[:blocks]['ToolbarSettings'][0] == '        "ToolbarSettings": {' && cap[:blocks]['ToolbarSettings'][-1] == '        }' &&
  cap[:blocks]['ToolbarSettings'][1..-2].none? { |l| l.end_with?(',') }

out = P.apply(dst, cap[:blocks], cap[:main_window])
a = JSON.parse(dst); b = JSON.parse(out); s = JSON.parse(src)
check 'kết quả là JSON hợp lệ', b.is_a?(Hash)
check 'layout giờ giống hệt nguồn (148 thanh công cụ, ToolbarSettings, Workspace)', layout_names.(b).sort == layout_names.(s).sort &&
  layout_names.(b).all? { |k| b['This Computer Only'][k] == s['This Computer Only'][k] }
check 'mọi mục không phải layout giữ nguyên như đích (kể cả Extensions lồng nhau, số 1.0, 2.0, tiếng Việt)', non_layout.(b) == non_layout.(a)
check 'MainWindow: Dock/ToolBarState lấy từ nguồn, Geometry của máy đích được giữ', b['This Computer Only']['MainWindow'] == { 'DockWidgetState' => '7b0a20' * 3000, 'Geometry' => 'dst-geometry', 'ToolBarState' => '00000001' }
check 'số thực và chuỗi ngoài layout giữ nguyên từng byte', out.include?('"Ratio": 1.0') && out.include?('"y": 2.0') && out.include?('"Name": "Tiếng Việt"')
check 'dòng ngoài layout giống hệt đích từng dòng', (dst.lines.reject { |l| l =~ /RubyToolBar|Workspace\\\\Trays|ToolbarSettings|Floating|Height|Tray"|Visible|"X"|"Y"|LargeIcons|ToolbarState|ToolTip|Count|Expand|height|DockWidget|Geometry|"ToolBarState"/ }.map { |l| l.chomp.sub(/,\z/, '') } -
  out.lines.map { |l| l.chomp.sub(/,\z/, '') }).empty?
check 'áp hai lần cho kết quả y hệt', P.apply(out, cap[:blocks], cap[:main_window]) == out
rt = JSON.parse(P.apply(dst, P.capture(dst)[:blocks], P.capture(dst)[:main_window]))
check 'chụp chính file đích rồi áp lại: nội dung không đổi', rt == a

no_layout = build(toolbars: [], mw: nil).sub(/,\n        "ToolbarSettings".*?(?=,\n        "Workspace\\\\Trays": \{)/m, '')
no_layout = no_layout.sub(/,\n        "Workspace\\\\Trays": \{.*?\n        \}(?=,\n        "Workspace)/m, '').sub(/,\n        "Workspace\\\\Trays\\\\Dialogs\\\\Components".*?\n        \}(?=\n    \})/m, '')
check 'mẫu không có layout nào (và không có MainWindow)', (j = JSON.parse(no_layout)) && layout_names.(j).empty? && !j['This Computer Only'].key?('MainWindow')
o2 = P.apply(no_layout, cap[:blocks], cap[:main_window])
j2 = JSON.parse(o2)
check 'đích không có layout: mục mới thêm vào cuối, dấu phẩy đúng, MainWindow được tạo mới',
  layout_names.(j2).sort == layout_names.(s).sort && j2['This Computer Only']['MainWindow'] == { 'DockWidgetState' => '7b0a20' * 3000, 'ToolBarState' => '00000001' } && non_layout.(j2) == non_layout.(JSON.parse(no_layout))

last_layout = build(toolbars: (0...3).to_a, mw: MW_DST, tail: nil)
last_layout = last_layout.sub(/,\n        "ToolbarSettings".*\n    \}\n\}\z/m, "\n    }\n}")   # bỏ ToolbarSettings và Workspace, để toolbar cuối là mục cuối
check 'mẫu có mục layout là mục cuối (không dấu phẩy)', (jl = JSON.parse(last_layout)) && layout_names.(jl).all? { |k| k.start_with?('QtRubyWorkspace') }
o3 = P.apply(last_layout, cap[:blocks], cap[:main_window])
check 'xóa mục layout cuối cùng rồi thêm mục mới: dấu phẩy vẫn đúng', JSON.parse(o3)['This Computer Only'].keys.size == non_layout.(jl).size + 1 + layout_names.(s).size

check 'rỗng cả blocks và MainWindow: chỉ xóa layout, JSON vẫn hợp lệ', (jr = JSON.parse(P.apply(dst, {}, {}))) && layout_names.(jr).empty? && jr['This Computer Only']['MainWindow'] == a['This Computer Only']['MainWindow']

crlf = build(toolbars: (0...2).to_a, mw: MW_DST, eol: "\r\n")
oc = P.apply(crlf, cap[:blocks], cap[:main_window])
check 'file CRLF giữ nguyên kiểu xuống dòng và hợp lệ', !oc.gsub("\r\n", '').include?("\n") && JSON.parse(oc)

weird = build(toolbars: (0...2).to_a, mw: MW_DST, flat: false)
capw = P.capture(weird)
check 'mục layout không phẳng (có đối tượng lồng) bị bỏ qua và đếm', capw[:skipped] == 1 && !capw[:blocks].key?('Workspace\\\\Trays\\\\Weird')
check 'mục không phẳng ở đích vẫn bị thay thế như mọi mục layout (không để sót khóa cũ)', (jw = JSON.parse(P.apply(weird, cap[:blocks], cap[:main_window]))) && !jw['This Computer Only'].key?('Workspace\\Trays\\Weird')

bad = cap[:blocks].dup
bad['Workspace\\\\Trays'] = ["        \"Workspace\\\\Trays\": {", '            "Count": 1', '        },', '        "Evil": {', '            "x": 1', '        }']
check 'chèn khối có mục thừa (cố thêm khóa ngoài layout) bị từ chối', (begin; P.apply(dst, bad, {}); false; rescue RuntimeError; true; end)
bad2 = { 'Evil' => ['        "Evil": {', '            "x": 1', '        }'] }
check 'khóa không thuộc nhóm layout bị bỏ qua, không chèn', JSON.parse(P.apply(dst, bad2, {}))['This Computer Only'].key?('Evil') == false
bad3 = { 'ToolbarSettings' => ['        "Other": {', '            "x": 1', '        }'] }
check 'dòng đầu không khớp khóa bị từ chối', (begin; P.apply(dst, bad3, {}); false; rescue RuntimeError; true; end)
bad4 = { 'ToolbarSettings' => ['        "ToolbarSettings": {', '            "x": {"a": 1}', '        }'] }
check 'giá trị lồng nhau trong khối bị từ chối', (begin; P.apply(dst, bad4, {}); false; rescue RuntimeError; true; end)
check 'không có "This Computer Only" thì từ chối', (begin; P.apply('{"a": 1}', cap[:blocks], {}); false; rescue RuntimeError; true; end)

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
