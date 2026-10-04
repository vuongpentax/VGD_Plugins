"""Build the integrated UI from the preserved, user-provided reference."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
html = (root / 'dev/claude_reference/dialog.html').read_text(encoding='utf-8-sig')
css = re.search(r'<style>(.*?)</style>', html, re.S).group(1)
js = re.search(r'<script>(.*?)</script>', html, re.S).group(1)
html = re.sub(r'<style>.*?</style>', '<link rel="stylesheet" href="dialog.css">', html, flags=re.S)
html = re.sub(r'<script>.*?</script>', '<script src="dialog.js"></script>', html, flags=re.S)
html = html.replace('chuẩn hóa Dimension, Text, Label', 'SMART DIM · MODEL INFO · 3.0 beta 1')
html = html.replace('value="selected"><span>', 'value="selected" checked><span>').replace('value="model" checked', 'value="model"')
html = html.replace('<section>\n  <h2>Smart Dim</h2>', '<details id="smart-panel" open><summary>SMART DIM · TỦ ĐANG CHỌN</summary><div>')
html = html.replace(' </section>\n\n <section>\n  <h2>Phạm vi</h2>', ' </div></details>\n\n <section>\n  <h2>Phạm vi</h2>', 1)
html = html.replace(' <section>\n  <h2>Dimension</h2>', ''' <section id="model-info">
  <h2>Model Info · Font / Size / Height</h2>
  <div class="bar"><button id="dim-info" onclick="sketchup.dim_info()">Dimensions</button><button id="text-info" onclick="sketchup.text_info()">Text / Label</button></div>
  <div class="row"><button id="native-apply" style="flex:1" onclick="VGD.nativeApply()">APPLY mẫu Model Info · Dim/Text chọn trực tiếp</button></div>
  <p class="note">Chỉnh mẫu chữ trong Model Info trước. APPLY mẫu chỉ áp Dim/Text chọn trực tiếp (Windows English); không quét trong group. Lưu SKP để mẫu đi cùng file.</p>
 </section>
 <section>
  <h2>Dimension</h2>''')
html = html.replace(' <section>\n  <h2>Text</h2>', ' <p class="note">Tag sau áp style: 000 DIM.</p>\n <section>\n  <h2>Text</h2>')
html = html.replace(' <section>\n  <h2>Label</h2>', ' <p class="note">Text / Label sau áp style: 000 TEXT.</p>\n <section>\n  <h2>Label</h2>')
html = html.replace('Component dùng chung definition chỉ sửa một lần và đổi tất cả bản sao.', 'Component dùng chung definition chỉ sửa một lần và đổi tất cả bản sao. Mặc định chỉ vùng chọn; hãy Make Unique nếu cần sửa riêng một bản.')
html = html.replace('Plugin tạo lại Dimension với font, size đó, giữ điểm đo, liên kết, chữ ghi đè, màu, mũi tên và Tag.', 'Plugin tạo lại Dim tuyến tính với mẫu chữ đó; giữ điểm đo, liên kết, chữ ghi đè, màu, endpoint và Tag. Dim bán kính được bỏ qua.')
html = html.replace('Chuẩn hóa tất cả</button>', 'Áp style theo phạm vi</button>')
html = html.replace('Ctrl+Z để hoàn tác.</p>', 'Ctrl+Z để hoàn tác. Smart Dim đo hộp bao tại lúc tạo; bấm lại sẽ tạo thêm bộ Dim.</p>', 1)
js = js.replace(' presets:{},builtin:[],delTimer:null,', ''' presets:{},builtin:[],delTimer:null,
 onBusy:function(value){document.querySelectorAll('button').forEach(function(b){b.disabled=value});if(!value)this.el('del').disabled=this.builtin.indexOf(this.el('preset').value)>=0;},
 nativeApply:function(){this.log('Đang áp mẫu Model Info…');sketchup.native_apply()},''')
css += '''
/* VGD Dim uses the established T+ palette. */
:root{--paper:#F7F7F5;--panel:#FFFFFF;--ink:#222222;--mute:#6F6F6F;--line:#E5E5E5;--field:#D6D6D6;--accent:#B48963;--accent-d:#8E6B4C}
body{overflow:hidden;font-size:12px}
main{min-height:0;scrollbar-gutter:stable}
header{background:#2B2B2B;color:#fff;border-top:3px solid var(--accent);flex:none}
header h1{font-size:17px}
header h1 small{display:block;color:#C8A98A;margin:3px 0 8px;font-size:10px}
header button{background:#fff}
button:hover{background:#F0E6DD}
button:disabled{opacity:.55;cursor:wait}
footer{flex:none}
section{background:#fff;border:1px solid var(--line);border-radius:3px;padding:0 10px 8px;margin-top:10px}
h2{margin-top:10px;font-size:12px}
details>div{overflow:hidden}
#model-info .bar{flex-wrap:wrap}
'''
runtime = root / 'runtime/VGD_Dim'
for name, content in [('dialog.html', html), ('dialog.css', css), ('dialog.js', js)]:
    (runtime / name).write_text(content, encoding='utf-8')
print('Built VGD Dim UI from preserved Claude reference')
