// --- VGD Scenes thật (plugins/VGD_Scenes/runtime/vgd_scenes/dialog.html) ---
// Hộp thoại nhận trạng thái qua window.VGDScenes.receive('state'|'result'|'started'|'progress'|'exported', dữ liệu). Phía Ruby (tạo scene,
// mặt cắt, xuất file) được mô phỏng bằng dữ liệu theo thời gian; chữ kết quả do chính hộp thoại dựng. Tên model, scene, số đo là ví dụ.
const SC_URL='../../../plugins/VGD_Scenes/runtime/vgd_scenes/dialog.html';
const scEl=id=>W.document.getElementById(id);
const SC_SETTINGS={project:'',template:'<OBJECT>_<VIEW>',views:['ISO','TOP','FRONT','RIGHT'],axis_mode:'local',grouping:'combined',isolate:true,width:1920,height:1080,margin:10,grid:'thirds',format:'png',transparent:false,ratio_locked:false,export_scale:1,date_folder:false,paper:'A4_L',section_axis:'Y',section_percent:50,section_offset:0,section_flip:false,section_name:'A-A',normal_x:0,normal_y:1,normal_z:0,scale_mode:'free',scale_denominator:0,paper_margin:15};
const scScene=(id,name,sel,kind)=>({id:String(id),name,owned:true,imported:false,frame:{width:1920,height:1080,margin:10},group:'Tủ bếp',kind:kind||'view',selected:!!sel});
function scState(o={}){
 return Object.assign({model:'1',title:'Phong bep',selection:1,editing:false,scenes:[],native_order_supported:true,native_order_dirty:false,section_sets:{},dim_available:false,presets:{},
  settings:SC_SETTINGS,camera:{eye_z_mm:1500,perspective:true,fov:35,fov_vertical:true,height_mm:null,supported:true,sig:'a',saved_sig:null},frame_cleanup:{count:0},
  current_frame:{width:1920,height:1080,margin:10},frame_active:false,grid_active:false,busy:false,transfer:null},o)}
async function mountScenes(frameId='cf',state){
 await mountApp(SC_URL,frameId,'VGD.Scenes.Theme',{stub:true});
 W.VGDScenes.receive('state',scState(state));
}
function scTab(name){W.document.querySelector('[data-tab="'+name+'"]').click()}
