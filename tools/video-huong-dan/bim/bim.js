// --- VGD BIM thật (plugins/VGD_BIM/runtime/vgd_bim/html/index.html) ---
// Hộp thoại nhận dữ liệu qua window.VGD.receive(sự kiện, dữ liệu). Cột, preset, nhãn dịch là dữ liệu thật do Ruby của plugin sinh ra
// (bim/fixture.json, tạo bằng `ruby plugins/VGD_BIM/dev/ui_fixture.rb`). Số dòng, tên món, giá là ví dụ.
const BIM_URL='../../../plugins/VGD_BIM/runtime/vgd_bim/html/index.html';
let BF=null;
const bimEl=s=>W.document.querySelector(s);
const BIM_PRESETS=null;
function bimConfig(mode,o={}){
 return Object.assign({mode,version:'1.1.0',language:'vi',app:{settings:{language:'vi',image_dir:'',exclude_words:'tay nắm, handle'},dir:'C:\\VGD\\VGD_BIM',dir_exists:true},preset_info:BF.preset_info,table:{columns:BF.columns,presets:BF.presets,view:{}},fields:BF.fields,categories:BF.categories,units:BF.units,methods:BF.methods,presets:BIM_PRESETS,locale:BF.vi,vi_en:null,scan_options:{scope:'model',faces:true}},o)}
const BIM_ROWS=[['Tủ bếp dưới','Cabinet',1200,600,800,'Phần thô'],['Tủ bếp trên','Cabinet',1200,350,720,'Phần thô'],['Bàn ăn','Table',1600,800,750,'Nội thất rời'],['Ghế ăn','Chair',450,450,900,'Nội thất rời'],['Sofa 3 chỗ','Sofa',2100,900,820,'Nội thất rời']];
const bimRows=()=>BIM_ROWS.map((r,i)=>({index:i,entity_type:'Nhóm',definition:r[1],name:r[0],description:'',lenX:r[2],lenY:r[3],lenZ:r[4],areaXZ:.96,areaXY:.72,areaFace:2.1,areaProjected:1.5,volume:.5,ifc:'',tag:'',tag_group:r[5],material:'',status:'new',owner:'',url:'',size:'',price:null,total:null,locked:false,quantity:1,parents:[],parent:'',pid:900+i,has_image:false,image_stamp:0,image_url:null}));
const bimTable=(o={})=>Object.assign({columns:BF.columns,presets:BF.presets,groups:BF.groups,statuses:BF.statuses,options:{zoom:true,isolate:false,deep:false,projected:false,isolating:false},rows:bimRows(),selected:[],hint:null,view:{},choices:{tags:[],materials:[]}},o);
async function mountBim(frameId='cf',mode='table'){
 BF=await (await fetch('../bim/fixture.json')).json();
 BF.presetsJson=await (await fetch('../../../plugins/VGD_BIM/runtime/vgd_bim/config/presets.json')).json();
 await mountApp(BIM_URL,frameId,'VGD_BIM_theme',{stub:true});
 W.VGD.receive('config',bimConfig(mode,{presets:BF.presetsJson}));
 if(mode==='table')W.VGD.receive('table',bimTable());
}
// dữ liệu mẫu cho các tab còn lại (hình dạng theo dev/test_ui*.cjs của plugin)
const BIM_INFO=()=>({count:2,fields:{category:'furniture',item_type:'cabinet',description:null,unit:'pcs',quantity_method:'count',include_boq:true},objects:[
 {entity_type:'Group',source:'RAW',instance_name:'Tủ bếp dưới',definition_name:'Cabinet',tag:'',material:'',dimensions:{width:1200,depth:600,height:800},status:'UNCLASSIFIED',locked:false},
 {entity_type:'Group',source:'RAW',instance_name:'Tủ bếp trên',definition_name:'Cabinet',tag:'',material:'',dimensions:{width:1200,depth:350,height:720},status:'UNCLASSIFIED',locked:false}]});
const BIM_MAP=()=>[
 {index:0,source_type:'definition_name',source_value:'Cabinet',kind:'object',instances:2,eligible:2,protected:0,suggestion:{data:{category:'furniture',item_type:'cabinet',unit:'pcs',quantity_method:'count'},confidence:'HIGH',source:'HEURISTIC'}},
 {index:1,source_type:'definition_name',source_value:'Chair',kind:'object',instances:4,eligible:4,protected:0,suggestion:{data:{category:'furniture',item_type:'chair',unit:'pcs',quantity_method:'count'},confidence:'HIGH',source:'HEURISTIC'}},
 {index:2,source_type:'definition_name',source_value:'Sofa',kind:'object',instances:1,eligible:1,protected:0,suggestion:{data:{category:'furniture',item_type:'sofa',unit:'pcs',quantity_method:'count'},confidence:'MEDIUM',source:'HEURISTIC'}}];
const BIM_TAGS=()=>({groups:BF.groups.slice(0,5),tags:[{name:'Tủ bếp',group:BF.groups[0],in_model:true,visible:true},{name:'Bàn ghế',group:BF.groups[1],in_model:true,visible:true},{name:'Sofa',group:BF.groups[1],in_model:false}],selection:2,
 rules:[{tag:'Tủ bếp',keywords:'tủ, cabinet'},{tag:'Bàn ghế',keywords:'bàn, ghế, table, chair'}],catalog:[{group:'A. ARCHITECTURAL',label_vi:'Kiến trúc',count:15,tags:['A. CHIMNEY','A. WALL']}]});
// chuyển tab như Ruby làm: gửi config (mode) rồi dữ liệu của tab
function bimGo(mode,event,data){W.VGD.receive('config',bimConfig(mode,{presets:BF.presetsJson}));if(event)W.VGD.receive(event,data)}
const bimBtn=txt=>[...W.document.querySelectorAll('button')].find(b=>b.textContent.trim()===txt);
const BIM_TREE=()=>({supported:true,styles_supported:true,line_styles:['Solid Line'],color_by_tag:false,isolated:null,pinned:[],recent:['Tủ bếp'],folders:[{id:1,name:'Nội thất cố định',visible:true,parent_id:null},{id:2,name:'Nội thất rời',visible:true,parent_id:null}],layers:[{id:10,name:'Tủ bếp',visible:true,folder_id:1,color:'#b07a45',line_style:''},{id:11,name:'Tủ trên',visible:true,folder_id:1,color:'#8a6a3a',line_style:''},{id:12,name:'Bàn ăn',visible:true,folder_id:2,color:'#5a7d9a',line_style:''},{id:13,name:'Ghế ăn',visible:false,folder_id:2,color:'#7a9a5a',line_style:''},{id:14,name:'Sofa',visible:true,folder_id:null,color:'#9a5a7a',line_style:''}]});
