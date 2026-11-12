'use strict';
// Đơn vị, số lẻ và dấu thập phân của preset đang dùng. Số liệu từ SketchUp luôn là mm / m² / m³; chỉ đổi khi hiển thị.
// Dùng tableState (app.js) vào lúc gọi.
const LENGTH_FACTORS={mm:1,cm:0.1,m:0.001,in:1/25.4,ft:1/304.8};
const AREA_FACTORS={m2:1,cm2:1e4,ft2:10.763910416709722};
const VOLUME_FACTORS={m3:1,cm3:1e6,ft3:35.31466672148859};
const UNIT_LABELS={mm:'mm',cm:'cm',m:'m',in:'in',ft:'ft',m2:'m²',cm2:'cm²',ft2:'ft²',m3:'m³',cm3:'cm³',ft3:'ft³'};
// Dùng khi chưa có thiết lập từ Ruby; trùng với Preset::DEFAULT_SETTINGS (Ruby gửi bản chính thức trong config.preset_info).
const FALLBACK_SETTINGS={length_unit:'mm',length_digits:0,area_unit:'m2',area_digits:2,volume_unit:'m3',volume_digits:3,decimal_separator:',',currency:'VND',image_margin:20,image_location_scale:4,image_width:512,image_height:512,image_view:'isometric',image_style:'color',image_background:'transparent',image_yaw:0,image_pitch:0,loc_width:512,loc_height:512,loc_view:'isometric',loc_style:'color',loc_background:'transparent',loc_margin:20,loc_yaw:0,loc_pitch:0};
function defaultSettings(){return (config&&config.preset_info&&config.preset_info.defaults)||FALLBACK_SETTINGS;}
function workSettings(){return (tableState&&tableState.settings)||defaultSettings();}
const unitLabel=key=>UNIT_LABELS[key]||key;
const lengthLabel=()=>unitLabel(workSettings().length_unit);
const areaLabel=()=>unitLabel(workSettings().area_unit);
const volumeLabel=()=>unitLabel(workSettings().volume_unit);
const toUnit=mm=>mm==null||mm===''?mm:Number(mm)*(LENGTH_FACTORS[workSettings().length_unit]||1);
const toArea=m2=>m2==null||m2===''?m2:Number(m2)*(AREA_FACTORS[workSettings().area_unit]||1);
const toVolume=m3=>m3==null||m3===''?m3:Number(m3)*(VOLUME_FACTORS[workSettings().volume_unit]||1);
// Đổi nhãn cột có đơn vị mm / m² / m³ ở cuối sang đơn vị của preset.
function withUnit(label){return String(label).replace(/ mm$/,' '+lengthLabel()).replace(/\(mm\)$/,'('+lengthLabel()+')').replace(/ m²$/,' '+areaLabel()).replace(/ m³$/,' '+volumeLabel());}
// Số có nhóm hàng nghìn: dấu thập phân theo preset ("," thì nghìn là "."; "." thì nghìn là ",").
function groupDigits(intPart){const thousands=workSettings().decimal_separator===','?'.':',';return intPart.replace(/\B(?=(\d{3})+(?!\d))/g,thousands);}
function fmt(value,digits){
  if(value==null||value==='')return '';
  const [whole,frac]=Number(value).toFixed(digits).split('.');
  return groupDigits(whole)+(frac?workSettings().decimal_separator+frac:'');
}
// Tối đa digits số lẻ, bỏ số 0 thừa ở cuối.
function number(value,digits=1){
  if(value==null||value==='')return '';
  const [whole,frac]=Number(value).toFixed(digits).split('.');
  const trimmed=(frac||'').replace(/0+$/,'');
  return groupDigits(whole)+(trimmed?workSettings().decimal_separator+trimmed:'');
}
const LEN_KEYS=new Set(['lenX','lenY','lenZ']);
const AREA_KEYS=new Set(['areaXZ','areaXY','areaFace','areaProjected']);
// Giá trị của cột theo đơn vị đang dùng (cột không có đơn vị đổi được thì giữ nguyên).
function scaledValue(key,value){return LEN_KEYS.has(key)?toUnit(value):AREA_KEYS.has(key)?toArea(value):key==='volume'?toVolume(value):value;}
function digitsFor(key){
  const s=workSettings();
  if(key.startsWith('len'))return s.length_digits;
  if(AREA_KEYS.has(key))return s.area_digits;
  if(key==='volume')return s.volume_digits;
  if(key==='price'||key==='total'||key==='calc_total'||key==='mat_price'||key==='mat_cost')return s.currency==='VND'?0:2;
  return 0;
}
