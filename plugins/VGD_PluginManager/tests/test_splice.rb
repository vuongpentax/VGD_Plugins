# encoding: UTF-8
# Kiểm chứng thuật toán chỉnh phím tắt theo dòng (bản tham chiếu Ruby của helper PowerShell).
require 'json'
require_relative 'support/splice_reference'

def check(label, cond)
  puts "#{cond ? 'OK  ' : 'FAIL'} #{label}"
  $fail = true unless cond
end

FIXTURE = <<~JSON
{
    "Shared for All Computers": {
        "Preferences": {
            "AviExportFPS": 24.0,
            "AviExportAR": 1.7777777777777777,
            "MaxUndo": 100
        }
    },
    "Windows Only": {
        "PrintOptions": {
            "LineWeight": 0.5,
            "PixelsPerInch": 150.0
        },
        "Settings": {
            "Image Editor": "",
            "Num_Shortcuts": 2,
            "Shortcut_1": "0 0 0 H selectDollyTool:",
            "Shortcut_2": "0 1 1 9 Camera/Next",
            "Zoom": 1.0
        },
        "UserLibrariesComponentBrowser1": {
            "Path1": "C:\\\\ProgramData\\\\SketchUp"
        }
    },
    "Mac Only": {},
    "timestamp": 1793379238292
}
JSON

NEW = { 'Num_Shortcuts' => 99, 'Shortcut_1' => '0 0 0 A selectArcTool:', 'Shortcut_10' => "0 0 1 H Tools/One Click Tools/Ẩn",
        'Shortcut_2' => '0 1 0 ` Extensions/Quote "x" \\ test', 'Evil' => 'x', 'Shortcut_x' => 'bo qua' }

out = Splice.apply(FIXTURE, NEW)
doc = JSON.parse(out)
set = doc['Windows Only']['Settings']
check 'kết quả vẫn là JSON hợp lệ', doc.is_a?(Hash)
check 'phím tắt mới thay hoàn toàn, Num_Shortcuts tự đếm lại (3, không phải 99)', set['Num_Shortcuts'] == 3 &&
  set.keys.grep(/\AShortcut_/).sort == %w[Shortcut_1 Shortcut_10 Shortcut_2] && set['Shortcut_1'] == '0 0 0 A selectArcTool:'
check 'chuỗi có tiếng Việt, dấu nháy, gạch chéo ngược giữ đúng', set['Shortcut_10'].end_with?('Ẩn') && set['Shortcut_2'] == NEW['Shortcut_2']
check 'khóa lạ không lọt vào', !set.key?('Evil') && !set.key?('Shortcut_x')
check 'các mục khác của Settings giữ nguyên và đúng thứ tự', set.keys.reject { |k| k =~ /Shortcut/ } == ['Image Editor', 'Zoom'] && set['Zoom'] == 1.0
check 'số thực dạng 24.0, 150.0, 1.0 không bị đổi thành số nguyên', out.include?('"AviExportFPS": 24.0,') && out.include?('"PixelsPerInch": 150.0') && out.include?('"Zoom": 1.0')
check 'phần ngoài khối phím tắt giống hệt từng byte', out.sub(/^ {12}"Num_Shortcuts".*?^ {12}"Zoom"/m, 'X') == FIXTURE.sub(/^ {12}"Num_Shortcuts".*?^ {12}"Zoom"/m, 'X')
check 'có đúng dấu phẩy: mục cuối không có', out =~ /"Zoom": 1.0\n        \}/ && out.lines.grep(/Shortcut_10/).first.rstrip.end_with?(',')

crlf = FIXTURE.gsub("\n", "\r\n")
out2 = Splice.apply(crlf, NEW)
check 'file CRLF giữ nguyên kiểu xuống dòng', !out2.gsub("\r\n", '').include?("\n") && JSON.parse(out2)['Windows Only']['Settings']['Num_Shortcuts'] == 3
check 'chạy lại với cùng dữ liệu cho kết quả y hệt (không đổi thêm)', Splice.apply(out, NEW) == out
check 'danh sách rỗng thì xóa hết phím tắt, JSON vẫn hợp lệ',
  (s0 = JSON.parse(Splice.apply(FIXTURE, {}))['Windows Only']['Settings']) && s0.keys == ['Image Editor', 'Zoom']

no_trailing = FIXTURE.chomp
check 'file không có dòng trống cuối giữ nguyên điều đó', !Splice.apply(no_trailing, NEW).end_with?("\n") && Splice.apply(FIXTURE, NEW).end_with?("}\n")

only_sc = FIXTURE.sub(/^ {12}"Image Editor".*\n/, '').sub(/^ {12}"Zoom".*\n/, '').sub('"Shortcut_2": "0 1 1 9 Camera/Next",', '"Shortcut_2": "0 1 1 9 Camera/Next"')
check 'Settings chỉ có phím tắt: vẫn đúng, mục cuối không dấu phẩy', (o3 = Splice.apply(only_sc, NEW)) && JSON.parse(o3) && o3.lines.grep(/Shortcut_2/).first.rstrip.end_with?('Extensions/Quote \"x\" \\\\ test"')

nested = FIXTURE.sub('"Zoom": 1.0', '"Zoom": { "a": 1 }')
check 'Settings có mục lồng nhau thì từ chối, không sửa', (begin; Splice.apply(nested, NEW); false; rescue RuntimeError => e; e.message.include?('long nhau'); end)
check 'không có Windows Only thì từ chối', (begin; Splice.apply(FIXTURE.sub('Windows Only', 'Mac Only X'), NEW); false; rescue RuntimeError; true; end)
check 'Settings nằm ngoài Windows Only không bị nhận nhầm', (begin; Splice.apply(FIXTURE.sub('"Settings": {', '"Setting": {').sub('"Mac Only": {}', "\"Settings\": {\n    }"), NEW); false; rescue RuntimeError; true; end)

puts($fail ? 'CÓ LỖI' : 'TẤT CẢ ĐẠT')
exit($fail ? 1 : 0)
