# Tạo file HTML xem trước giao diện (mock window.sketchup, dữ liệu mẫu). Từ plugins/VGD_BIM: python3 dev/make_preview.py
# Kết quả ở outputs/VGD_BIM_giao_dien.html (outputs/ không đưa vào git). Chỉ để xem giao diện, không thay SketchUp.
import base64, json, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = os.path.join(ROOT, 'runtime', 'vgd_bim_lite')
OUT = os.path.join(ROOT, 'outputs', 'VGD_BIM_giao_dien.html')
os.makedirs(os.path.dirname(OUT), exist_ok=True)
VERSION = re.search(r"VERSION = '([^']+)'", open(os.path.join(ROOT, 'runtime', 'vgd_bim_lite.rb'), encoding='utf-8').read()).group(1)
def rd(p): return open(os.path.join(B, p), encoding='utf-8').read()
def data_uri(p, mime): return f"data:{mime};base64," + base64.b64encode(open(os.path.join(B, p), 'rb').read()).decode()

html = rd('html/index.html')
theme_css = rd('html/vgd-theme/vgd-theme.css')
style_css = rd('html/style.css')
theme_js = rd('html/vgd-theme/vgd-theme.js')
app_js = rd('html/app.js')
vi = json.load(open(os.path.join(B, 'config/vi.json'), encoding='utf-8'))

# Font: nhúng trực tiếp (file nhỏ)
for f in ['manrope-vietnamese-wght-normal.woff2', 'manrope-latin-wght-normal.woff2']:
    theme_css = theme_css.replace(f'url("fonts/{f}")', f'url("{data_uri("html/vgd-theme/fonts/" + f, "font/woff2")}")')
    theme_css = theme_css.replace(f"url('fonts/{f}')", f'url("{data_uri("html/vgd-theme/fonts/" + f, "font/woff2")}")')
logo_dark = data_uri('assets/icons/vgd_primary_dark.svg', 'image/svg+xml')
logo_light = data_uri('assets/icons/vgd_primary_light.svg', 'image/svg+xml')
app_js = app_js.replace('../assets/icons/vgd_primary_dark.svg', logo_dark).replace('../assets/icons/vgd_primary_light.svg', logo_light)
theme_js = theme_js.replace('../assets/icons/vgd_primary_dark.svg', logo_dark).replace('../assets/icons/vgd_primary_light.svg', logo_light)
html = html.replace('../assets/icons/vgd_primary_dark.svg', logo_dark)

COLUMNS = [
 {"key":"ordinal","label":"#","kind":"text"},{"key":"entity","label":"Loại","kind":"text"},
 {"key":"definition","label":"Họ","kind":"text"},{"key":"instance","label":"Tên","kind":"text","editable":"name"},
 {"key":"description","label":"Mô tả","kind":"text","editable":"description"},
 {"key":"lenX","label":"Rộng (X) mm","kind":"number"},{"key":"lenY","label":"Dài (Y) mm","kind":"number"},
 {"key":"lenZ","label":"Cao (Z) mm","kind":"number"},{"key":"lenXZ","label":"(X) x (Z) mm","kind":"text"},
 {"key":"lenXY","label":"(X) x (Y) mm","kind":"text"},{"key":"lenXYZ","label":"(X) x (Y) x (Z) mm","kind":"text"},
 {"key":"areaXZ","label":"Diện tích (X*Z) m²","kind":"sum"},{"key":"areaXY","label":"Diện tích (X*Y) m²","kind":"sum"},
 {"key":"areaFace","label":"Diện tích mặt m²","kind":"sum"},{"key":"volume","label":"Thể tích m³","kind":"sum"},
 {"key":"tag","label":"Phân loại thẻ","kind":"text"},{"key":"tag_group","label":"Nhóm hạng mục","kind":"text"},
 {"key":"material","label":"Vật liệu","kind":"text"},{"key":"status","label":"Tình trạng","kind":"status","editable":"status"},
 {"key":"quantity","label":"Số lượng","kind":"sum"}]
BUILT_IN = [
 {"name":"Tất cả","group":"","columns":["ordinal","entity","definition","instance","description","material","tag","status","quantity"],"builtin":True},
 {"name":"Phần thô","group":"Phần thô","columns":["ordinal","entity","instance","lenX","lenY","lenZ","areaFace","volume","tag","material","quantity"],"builtin":True},
 {"name":"Hoàn thiện","group":"Hoàn thiện","columns":["ordinal","entity","instance","description","lenX","lenY","lenZ","areaXZ","areaXY","areaFace","tag","material","status","quantity"],"builtin":True},
 {"name":"Đồ rời","group":"Đồ rời","columns":["ordinal","entity","definition","instance","description","lenX","lenY","lenZ","tag","material","status","quantity"],"builtin":True}]
STATUSES = {'new':'Mới','existing':'Hiện hữu','reuse':'Dùng lại','temporary':'Tạm thời','removed':'Loại bỏ'}
def row(i, ent, de, name, lx, ly, lz, tag, tg, mat, status='new', vol=None, face=None, parents=None, desc=''):
    return {"index":i,"entity_type":ent,"definition":de,"name":name,"description":desc,"lenX":lx,"lenY":ly,"lenZ":lz,
            "areaXZ":round(lx*lz/1e6,3),"areaXY":round(lx*ly/1e6,3),"areaFace":face if face is not None else round(2*(lx*lz+ly*lz)/1e6,3),
            "volume":vol,"tag":tag,"tag_group":tg,"material":mat,"status":status,"locked":False,"quantity":1,"parents":parents or []}
ROWS = [
 row(0,'Nhóm','Group#1','Tường trục A',5000,200,2800,'Tường 200','Phần thô','Bê tông',vol=2.8,face=28.4,desc='Tường trục A, tầng 1'),
 row(1,'Nhóm','Group#2','Cột C1',400,400,2800,'Cột','Phần thô','Bê tông',vol=0.448,face=4.48),
 row(2,'Nhóm','Group#3','Dầm D1',5000,300,500,'Dầm','Phần thô','Bê tông',vol=0.75,face=6.0),
 row(3,'Nhóm','Group#4','Sàn tầng 1',6000,4000,150,'Sàn bê tông','Phần thô','Bê tông',vol=3.6,face=48.0),
 row(4,'Thành phần','VGD_CABINET','Tủ bếp dưới',2400,600,900,'Nội thất','Đồ rời','Gỗ MFC',status='existing',desc='Tủ bếp dưới, bên trái'),
 row(5,'Thành phần','VGD_CABINET','Tủ ti vi',1800,450,600,'Nội thất','Đồ rời','Gỗ MFC',status='new'),
 row(6,'Nhóm','Group#5','Trần thạch cao',5000,4000,10,'Trần','Hoàn thiện','Thạch cao',vol=0.2,face=20.0),
 row(7,'Nhóm','Group#6','Sơn tường P1',5000,2800,1,'Sơn 2 lớp','Hoàn thiện','Sơn Dulux',face=35.2),
 row(8,'Thành phần','D1','Cửa đi 1',900,50,2100,'Cửa','Hoàn thiện','Gỗ công nghiệp',status='reuse'),
 row(9,'Nhóm','Group#7','Gạch WC',2000,2000,8,'Gạch ốp lát','Hoàn thiện','Gạch 300x600',face=12.5),
 row(10,'Nhóm','Group#8','Hộp kỹ thuật',600,400,1500,'Thiết bị','Thiết bị','Thép',vol=0.36,face=3.6),
 row(11,'Thành phần','O_CAM','Ổ cắm 1',80,20,80,'Thiết bị','Thiết bị','Nhựa',status='temporary',parents=[10]),
]
for r in ROWS:
    if r['index']==10: r['volume']=0.36
CONFIG = {"mode":"table","version":VERSION,"fields":[],"categories":["architecture","finish","furniture","electrical","equipment","plumbing","hvac","other"],
          "units":["m2","m","m3","pcs","set","lot","kg","none"],"methods":["area","length","volume","count","assembly","manual"],
          "presets":[],"locale":vi,"scan_options":{"scope":"model","faces":False}}
TABLE = {"columns":COLUMNS,"presets":BUILT_IN,"groups":["Phần thô","Hoàn thiện","Đồ rời","Thiết bị","Khác","Chưa phân loại"],
         "statuses":STATUSES,"options":{"zoom":True,"isolate":False,"deep":False,"isolating":False},"rows":ROWS,"selected":None,"hint":None}
INFO = {"count":1,"fields":{"schema_version":1,"category":"","item_type":"","code":"","description":"","unit":"","quantity_method":"","zone":"","floor":"","include_boq":True,"finish_code":"","manufacturer":"","model_number":"","note":"","status":""},
        "objects":[{"entity_type":"Component","instance_name":"Tủ bếp dưới","definition_name":"VGD_CABINET","tag":"Nội thất","material":"Gỗ MFC","source":"RAW","status":"UNCLASSIFIED","locked":False,"dimensions":{"width":2400,"depth":600,"height":900}}]}

MOCK = """
(function(){
  var CONFIG = __CONFIG__;
  var TABLE = __TABLE__;
  var INFO = __INFO__;
  var presets = TABLE.presets.slice();
  var options = Object.assign({}, TABLE.options);
  var rows = TABLE.rows.map(function(r){return Object.assign({}, r);});
  function table(){ return {columns: TABLE.columns, presets: presets, groups: TABLE.groups, statuses: TABLE.statuses, options: Object.assign({}, options), rows: rows, selected: null, hint: null}; }
  function say(text, error){ window.VGD.receive('message', error ? {error: text} : {text: text}); }
  function showMode(mode){
    if(mode==='table'){ window.VGD.receive('config', Object.assign({}, CONFIG, {mode:'table'})); window.VGD.receive('table', table()); }
    else if(mode==='information'){ window.VGD.receive('config', Object.assign({}, CONFIG, {mode:'information'})); window.VGD.receive('information', INFO); }
    else { window.VGD.receive('config', Object.assign({}, CONFIG, {mode:mode})); say('Mẫu này chưa có trong bản xem trước. Chỉ có Bảng khối lượng và Thông tin đối tượng.'); }
  }
  window.sketchup = {
    ready: function(){ setTimeout(function(){ showMode('table'); say('Bản xem trước: dữ liệu mẫu. Chọn ô trong bảng để xem khung tên; tick "Chọn sâu" và thao tác trong SketchUp chỉ chạy được khi dùng plugin thật.'); }, 0); },
    open_panel: function(mode){ showMode(mode); },
    table_select: function(json){
      var p = JSON.parse(json);
      var r = rows.filter(function(x){ return x.index===p.index; })[0];
      window.VGD.receive('highlight', {index: p.index});
      if(!r) return;
      var f = p.field;
      var txt = {instance: r.name, description: r.description, status: (TABLE.statuses[r.status]||''), tag: r.tag, material: r.material, definition: r.definition, entity: r.entity_type, tag_group: r.tag_group}[f];
      if(txt===undefined) txt = r.name+(r.description?' · '+r.description:'')+' · '+(TABLE.statuses[r.status]||'')+(r.tag?' · '+r.tag:'');
      say('Khung tên trong SketchUp: "'+txt+'" (bản xem trước không vẽ được khung 3D).');
    },
    table_clear: function(){ say('Đã bỏ chọn (bản xem trước).'); },
    table_option: function(json){ var p = JSON.parse(json); Object.keys(p).forEach(function(k){ options[k] = p[k]; }); window.VGD.receive('options', Object.assign({isolating: false}, options)); },
    table_preset: function(json){
      var p = JSON.parse(json);
      if(p.action==='save'){ presets = presets.filter(function(x){return x.name!==p.name;}).concat([{name:p.name, group:p.group||'', columns:p.columns, builtin:false}]); say('Đã lưu preset "'+p.name+'".'); }
      if(p.action==='delete'){ presets = presets.filter(function(x){return x.name!==p.name || x.builtin;}); say('Đã xóa preset.'); }
      window.VGD.receive('presets', presets);
    },
    table_edit: function(json){
      var p = JSON.parse(json);
      rows.forEach(function(r){ if(r.index===p.index){ if(p.field==='name') r.name=p.value; if(p.field==='description') r.description=p.value; if(p.field==='status') r.status=p.value; } });
      window.VGD.receive('table', table());
    }
  };
  // Các hàm khác của plugin: không làm gì trong bản xem trước
  ['apply','clear','preview_convert','confirm_convert','save_rule','select_entity','save_tags','assign_tag','scan_options','export_tags','import_tags','export_report','save_rules','export_rules','import_rules'].forEach(function(name){
    window.sketchup[name] = function(){ say('Nút này chỉ hoạt động trong SketchUp.'); };
  });
  window.sketchup.table_view = function(){};
})();
"""
mock = MOCK.replace('__CONFIG__', json.dumps(CONFIG, ensure_ascii=False)).replace('__TABLE__', json.dumps(TABLE, ensure_ascii=False)).replace('__INFO__', json.dumps(INFO, ensure_ascii=False))

out = html
out = out.replace('<link rel="stylesheet" href="vgd-theme/vgd-theme.css">', '<style>' + theme_css + '</style>')
out = out.replace('<link rel="stylesheet" href="style.css">', '<style>' + style_css + '</style>')
out = out.replace('<script src="vgd-theme/vgd-theme.js"></script>', '<script>' + theme_js.replace('</script', '<\\/script') + '</script>')
out = out.replace('<script src="app.js"></script>', '<script>' + mock + '</script><script>' + app_js.replace('</script', '<\\/script') + '</script>')
out = out.replace('<title>VGD_BIM</title>', '<title>VGD_BIM · Bản xem trước giao diện</title>')
assert '<script src=' not in out and 'href="style.css"' not in out, 'external refs remain'
open(OUT, 'w', encoding='utf-8').write(out)
print('written', OUT, len(out), 'bytes')
