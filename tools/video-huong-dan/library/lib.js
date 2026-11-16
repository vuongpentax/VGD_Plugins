// --- VGD Library thật (plugins/VGD_Library/runtime/vgd_library/dialog.html) ---
// Hàm thật của hộp thoại là window.VGD (begin, append, model, feedback, setView, favorites). Phía Ruby (quét thư mục, tô vật liệu,
// đặt model) được mô phỏng bằng dữ liệu theo thời gian; vân vật liệu và model là hình mẫu trong samples/ (tên là ví dụ).
const LIB_DIR='../../../plugins/VGD_Library/runtime/vgd_library/';
const ROOT_MTL='C:\\VatLieu\\Mau',ROOT_SKP='C:\\Model\\NoiThat';
const smp=n=>new URL('../samples/'+n+'.svg',location.href).href;
const MTL=[['Gỗ sồi tự nhiên','Gỗ','vl_go_soi'],['Gỗ óc chó','Gỗ','vl_go_oc_cho'],['Gỗ trầm đỏ','Gỗ','vl_go_tram'],['Đá trắng','Đá','vl_da_trang'],['Đá marble','Đá','vl_da_marble'],['Đá đen','Đá','vl_da_den'],['Gạch 600x600','Gạch','vl_gach_600'],['Gạch men xanh','Gạch','vl_gach_men'],['Vải linen','Vải','vl_vai_linen'],['Kim loại xước','Kim loại','vl_kim_loai'],['Bê tông','Đá','vl_be_tong']];
const SKP=[['Sofa 3 chỗ','Nội thất','sofa'],['Cây trang trí','Cây xanh','cay'],['Người đứng','Con người','nguoi'],['Chậu cây','Cây xanh','chau']];
const libMaterials=()=>MTL.map(([n,c,s],i)=>({id:'m'+i,name:n+'.jpg',label:n,category:c,root:ROOT_MTL,format:'JPG',kind:'material',width:600,height:600,preview:smp(s)}));
const libModels=()=>SKP.map(([n,c,s],i)=>({id:'s'+i,name:n+'.skp',label:n,category:c,root:ROOT_SKP,format:'SKP',kind:'model',preview:smp(s)}));
let libLast={};
async function mountLibrary(frameId='cf'){await mountApp(LIB_DIR+'dialog.html',frameId,'VGD.Library.Theme');W.VGD.model({materials:[],current:null,model_id:'1'})}
const libEl=id=>W.document.getElementById(id);
function libSet(el,v,ev){if(el.value!==String(v)){el.value=v;el.dispatchEvent(new W.Event(ev,{bubbles:true}))}}
// s = {loaded:0|'mtl'|'both', view, search, category, select(label), width, height, favorites:[id], status:[text,err], inModel:[{name,label,width,height}], current}
async function libApply(s){
 const key=JSON.stringify([s.loaded]);
 if(libLast.loaded!==key){libLast.loaded=key;
  const roots=s.loaded?(s.loaded==='both'?[ROOT_MTL,ROOT_SKP]:[ROOT_MTL]):[],items=s.loaded?(s.loaded==='both'?[...libMaterials(),...libModels()]:libMaterials()):[];
  W.VGD.begin({roots,online_roots:[],favorites:[],version:'1.2.1'});W.VGD.append(items,true,[]);
  // đặt lại ô tìm kiếm, nhóm và dòng trạng thái như một lần mở mới
  libSet(libEl('search'),'','input');libSet(libEl('category'),'','change');libEl('status').textContent='';libLast.hadStatus=true;
  libLast.view='library';libLast.search='';libLast.category='';libLast.select=null;libLast.fav='[]'}
 if(libLast.view!==s.view){libLast.view=s.view;W.VGD.setView(s.view);libLast.category=''}
 if((libLast.search||'')!==(s.search||'')){libLast.search=s.search||'';libSet(libEl('search'),s.search||'','input')}
 if((libLast.category||'')!==(s.category||'')){libLast.category=s.category||'';libSet(libEl('category'),s.category||'','change')}
 if((libLast.select||null)!==(s.select||null)){libLast.select=s.select||null;
  if(s.select){const card=[...W.document.querySelectorAll('#grid .card')].find(c=>c.querySelector('h3').textContent===s.select);if(card)card.querySelector('.swatch').click()}}
 if(s.width!==undefined){libSet(libEl('width'),s.width,'input');libSet(libEl('height'),s.height,'input')}
 const fav=JSON.stringify(s.favorites||[]);if(libLast.fav!==fav){libLast.fav=fav;W.VGD.favorites(s.favorites||[])}
 const mk=JSON.stringify([s.inModel||[],s.current||null]);if(libLast.model!==mk){libLast.model=mk;W.VGD.model({materials:s.inModel||[],current:s.current||null,model_id:'1'})}
 const st=s.status||['',false];if(st[0]||libLast.hadStatus){libEl('status').textContent=st[0];libEl('status').className=st[1]?'error':'success';libLast.hadStatus=!!st[0]}
 // chỉ chờ ảnh đang hiển thị (ảnh trong phần bị ẩn không bao giờ tải) và không chờ quá 1,5 giây
 const shown=[...W.document.querySelectorAll('#grid img,#preview img')].filter(im=>im.offsetParent);
 await Promise.race([Promise.all(shown.map(im=>im.decode().catch(()=>{}))),sleep(1500)]);
}
