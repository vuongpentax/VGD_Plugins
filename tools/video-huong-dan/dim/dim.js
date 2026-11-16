// --- VGD Dim thật (plugins/VGD_Dim/runtime/vgd_dim/dialog.html) ---
// Hàm thật của hộp thoại là đối tượng VGD (nav, log, onBusy, onSmart, onResult, onRebuild, onAnim, onUnits, onState...). Phía Ruby
// (đo, dựng Dim, áp style) được mô phỏng bằng dữ liệu theo thời gian; chữ kết quả do chính hộp thoại dựng. Tên preset, số đo là ví dụ.
const DIM_URL='../../../plugins/VGD_Dim/runtime/vgd_dim/dialog.html';
async function mountDim(frameId='cf',tab='smart'){
 await mountApp(DIM_URL,frameId,'vgd.dim.theme',{stub:true});
 W.VGD.onState({version:'4.0.2',presets:{'VGD mặc định':{},'Bản vẽ thi công':{}},builtin:['VGD mặc định'],select:'VGD mặc định',auto:{enabled:false},
  anim:{enabled:false,transition:2,delay:2,loop:false},smart:{face:'-y',do_h:true,do_v:true,off1:100,off2:200,min_seg:10,min_part:20,depth:3},units:{unit:2,precision:0,show_unit:false}});
 W.VGD.nav(tab);
}
const dimEl=id=>W.document.getElementById(id);
