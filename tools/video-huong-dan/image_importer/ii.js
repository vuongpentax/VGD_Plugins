// --- VGD Image Importer thật (plugins/VGD_Image_Importer/runtime/vgd_image_importer/dialog.html) ---
// Hàm thật của hộp thoại là window.VGDImporter.receive(sự kiện, dữ liệu): ở đây mô phỏng phía Ruby bằng dữ liệu theo thời gian.
// Dùng sau common.js. Ảnh trong danh sách là hình mẫu do dự án vẽ (samples/), không phải ảnh thật.
const II_DIR='../../../plugins/VGD_Image_Importer/runtime/vgd_image_importer/';
const II_SETTINGS={importType:'comp_2d',scaleMethod:'pixel',mmPerPixel:2,targetHeight:2000,targetWidth:2000,spacing:500,itemsPerRow:5,alwaysFaceCamera:true,recursive:false};
let iiSig='';
async function mountImporter(frameId='cf'){
 await mountApp(II_DIR+'dialog.html',frameId,'vgd.image_importer.theme');
 W.VGDImporter.receive('settings',{...II_SETTINGS,version:'1.1.2'});
}
// s = {files:[{name,sample}], settings:{...}, status:'...', result:null|{imported,failed,errors}}; chỉ vẽ lại danh sách khi nó đổi
async function iiApply(s){
 W.VGDImporter.receive('settings',{...II_SETTINGS,...s.settings,version:'1.1.2'});
 const list=s.files.map((f,i)=>({id:i,name:f.name,path:'C:\\Anh\\tham_khao\\'+f.name})),sig=JSON.stringify(list);
 if(sig!==iiSig){iiSig=sig;W.VGDImporter.receive('files',list);
  const rows=[...W.document.querySelectorAll('#fileList .file-row')],imgs=[];
  rows.forEach((row,i)=>{const im=row.querySelector('img.thumb');if(im&&s.files[i].sample){im.onerror=null;im.src=new URL('samples/'+s.files[i].sample+'.svg',location.href).href;imgs.push(im)}});
  await Promise.all(imgs.map(im=>im.decode().catch(()=>{})))}
 const dlg=W.document.getElementById('resultDialog');
 if(s.result){if(!dlg.open)W.VGDImporter.receive('result',s.result)}else{if(dlg.open)dlg.close();W.VGDImporter.receive('status',{message:s.status,error:false})}
}
