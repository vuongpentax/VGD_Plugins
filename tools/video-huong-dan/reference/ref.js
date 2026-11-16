// --- VGD Reference thật (plugins/VGD_Reference/runtime/vgd_reference/ui/web/index.html) ---
// Hàm thật của bảng là window.VGDReference.render/message/importStatus: ở đây mô phỏng phía Ruby bằng dữ liệu theo thời gian.
// Ảnh nổi trên khung nhìn SketchUp không nằm trong hộp thoại, nên được vẽ bằng một khung minh họa (#vp) trong từng đoạn.
const REF_DIR='../../../plugins/VGD_Reference/runtime/vgd_reference/ui/web/';
let refSig='';
async function mountReference(frameId='cf'){await mountApp(REF_DIR+'index.html',frameId,'vgd.reference.theme');W.VGDReference.render({items:[],selected_id:null,hidden_all:false})}
// s = {items:[{id,name,width,height,locked,visible,selected,opacity,sample}], selected_id, hidden_all, message, importing, confirm}
async function refApply(s){
 const items=s.items.map(i=>({...i,thumbnail:new URL('../samples/'+i.sample+'.svg',location.href).href})),sig=JSON.stringify([items,s.selected_id,s.hidden_all]);
 if(sig!==refSig){refSig=sig;W.VGDReference.render({items,selected_id:s.selected_id,hidden_all:s.hidden_all});
  await Promise.all([...W.document.querySelectorAll('#items img.thumb')].map(im=>im.decode().catch(()=>{})))}
 W.VGDReference.importStatus(!!s.importing,s.importing||'');
 // thông báo: gán trực tiếp (hàm thật tự ẩn sau 4,5 giây thời gian thực, không hợp với quay từng khung hình)
 const m=W.document.getElementById('message');m.textContent=s.message||'';m.classList.toggle('hidden',!s.message);
 W.document.getElementById('clearAllDialog').classList.toggle('hidden',!s.confirm);
}
