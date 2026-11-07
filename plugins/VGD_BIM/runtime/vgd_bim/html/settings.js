'use strict';
// Tab Cài đặt và đơn vị đo. Dùng chung các hàm của app.js ($, node, card, button, call, message, config) vào lúc gọi.
// show: số chữ số lẻ khi hiện kích thước ở các bảng khác; digits: số chữ số lẻ trong bảng khối lượng.
const LENGTH_UNITS={mm:{factor:1,digits:0,show:1},cm:{factor:0.1,digits:1,show:2},m:{factor:0.001,digits:3,show:3}};
const lengthUnit=()=>{const u=config&&config.settings&&config.settings.length_unit;return LENGTH_UNITS[u]?u:'mm';};
// Số liệu từ SketchUp luôn tính bằng mm; chỉ khi hiện mới đổi sang đơn vị trong Cài đặt.
const toUnit=mm=>mm==null||mm===''?mm:Number(mm)*LENGTH_UNITS[lengthUnit()].factor;
const withUnit=label=>String(label).replace(/ mm$/,' '+lengthUnit()).replace(/\(mm\)$/,'('+lengthUnit()+')');
const SIZE_CHOICES=[256,512,768,1024,1536,2048];
function saveSetting(patch){call('settings_save',JSON.stringify(patch));}
function settingRow(parent,title,control,hint){
  const row=node('div',undefined,'setting-row'),text=node('div',undefined,'setting-text');
  text.append(node('strong',title));if(hint)text.append(node('span',hint,'muted'));
  row.append(text,control);parent.append(row);return row;
}
function choice(options,current,onChange,label){
  const select=node('select');select.setAttribute('aria-label',label);
  options.forEach(([value,text])=>select.append(new Option(text,String(value))));select.value=String(current);
  select.onchange=()=>onChange(select.value);return select;
}
function settingsView(data){
  const s=data.settings;config.settings=s;
  $('content').replaceChildren();$('primary-actions').replaceChildren();
  const general=card('Chung');
  general.append(node('p','Cài đặt lưu trên máy này và áp dụng cho mọi model. Mỗi thay đổi được lưu ngay.','hint'));
  settingRow(general,'Ngôn ngữ',choice([['vi','Tiếng Việt'],['en','English']],s.language,v=>saveSetting({language:v}),'Ngôn ngữ'),'Đổi ngôn ngữ sẽ tải lại cửa sổ. Báo cáo CSV luôn xuất bằng tiếng Việt.');
  settingRow(general,'Đơn vị chiều dài',choice([['mm','Milimét (mm)'],['cm','Xentimét (cm)'],['m','Mét (m)']],s.length_unit,v=>saveSetting({length_unit:v}),'Đơn vị chiều dài'),'Áp dụng cho kích thước hiện trong cửa sổ. Diện tích luôn là m², thể tích là m³; báo cáo CSV giữ nguyên mm.');
  const images=card('Hình ảnh');
  images.append(node('p','Ảnh chỉ được chụp khi bạn bấm nút trong tab Hình ảnh hoặc Bảng khối lượng. Plugin không tự chụp.','hint'));
  const dirBox=node('div',undefined,'dir-box');
  const dir=node('input');dir.type='text';dir.value=s.image_dir;dir.placeholder=data.dir;dir.maxLength=240;dir.setAttribute('aria-label','Thư mục lưu ảnh');
  const commit=()=>{if(dir.value.trim()!==s.image_dir)saveSetting({image_dir:dir.value.trim()});};
  dir.onchange=commit;dir.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();commit();}};
  const pick=button('Chọn thư mục…',()=>call('settings_pick_dir'));
  const open=button('Mở thư mục',()=>call('images_open_dir'));
  dirBox.append(dir,pick,open);
  settingRow(images,'Thư mục lưu ảnh',dirBox,'Để trống để dùng thư mục mặc định. Ảnh nằm trong thư mục con theo từng model, không ghi vào file SketchUp.');
  images.append(node('p',`Đang dùng: ${data.dir}`+(data.dir_exists?'':' (chưa có, sẽ được tạo khi chụp ảnh đầu tiên)'),'muted dir-now'));
  settingRow(images,'Cách chụp',choice([['isolate','Cô lập món đồ rồi chụp'],['current','Chụp đúng khung nhìn hiện tại']],s.capture_mode,v=>saveSetting({capture_mode:v}),'Cách chụp'),
    'Cô lập: ẩn tạm phần còn lại của model, zoom vào món đồ, chụp ảnh vuông rồi trả model về như cũ. Khung nhìn hiện tại: chụp đúng những gì đang thấy, không đổi gì.');
  settingRow(images,'Cỡ ảnh',choice(SIZE_CHOICES.map(n=>[n,`${n} px`]),SIZE_CHOICES.includes(s.image_size)?s.image_size:512,v=>saveSetting({image_size:Number(v)}),'Cỡ ảnh'),'Cạnh dài của ảnh. Ảnh lớn đẹp hơn nhưng chụp lâu hơn và tốn dung lượng.');
  settingRow(images,'Nền ảnh',choice([['transparent','Trong suốt'],['white','Trắng']],s.image_background,v=>saveSetting({image_background:v}),'Nền ảnh'),'Nền trắng tạm tắt mặt đất và chân trời khi chụp rồi trả lại.');
}
