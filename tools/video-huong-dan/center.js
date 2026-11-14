// --- VGD Center thật (plugins/VGD_Center/vgd_center/dialog.html): hàm thật là window.VGD và window.VGDManager ---
// Dùng cùng common.js (nạp common.js trước, center.js sau).
const CENTER_DIR='../../plugins/VGD_Center/vgd_center/';
let CAT=null;
async function mountCenter(frameId='cf',page='catalog'){
 CAT=await (await fetch(CENTER_DIR+'catalog.json')).json();
 await mountApp(CENTER_DIR+'dialog.html?preview',frameId,'vgd-center-theme');
 W.VGD.setStatus('');openPage(page);
}
const openPage=p=>W.document.querySelector(`.nav [data-page=${p}]`).click();
// Trạng thái Center gửi cho giao diện: st = {id: 'installed' | 'update' | 'install'}
function centerState(st,settings={language:'vi',auto_update:true},center='latest'){
 const older={dim:'4.0.0',cabinet:'4.5.2',library:'1.1.9',image_importer:'1.1.0',scenes:'1.5.9',bim:'1.0.9',reference:'1.0.1',cabinet_draw:'0.9.9'};
 return{version:'1.2.5',sketchup:'24.0.0',settings,center_update:{state:center,current_version:'1.2.5',latest_version:'1.2.5'},
  products:CAT.products.filter(p=>p.download).map(p=>{const s=st[p.id]||'installed';
   return{id:p.id,name:p.name,version:p.version,release_channel:p.release_channel,description:p.description,icon:p.icon,guide:p.guide,minimum_sketchup:p.minimum_sketchup,compatible:true,
    installed:s!=='install',installed_version:s==='install'?null:(s==='update'?older[p.id]:p.version),action:s==='install'?'install':s==='update'?'update':null}})}}
// Hộp thoại tiến trình/kết quả của Center: ph 0 = đang tải, 1 = xác minh và cài, 2 = hoàn tất, -1 = đóng
function centerOverlay(ph,pct,id,done){const ov=W.document.getElementById('overlay');
 if(ph<0){ov.classList.remove('open');return}
 if(ph===2)W.VGD.notify('success',done[0],done[1]);
 else W.VGD.progress({id,phase:ph?'Đang xác minh và cài đặt':'Đang tải gói',current:pct,total:100})}

// --- Tab Quản lý của Center thật (đoạn 4, 5, 6) ---
const MGR_NAMES=['vgd_cabinet','vgd_dim','vgd_library','vgd_scenes','vgd_reference'];
// on: {tên: true/false}; pending: tên plugin đang chờ nạp
function mgrState(on,pending,msg=''){W.VGDManager.renderToggle({year:2024,sets:[],plugins:MGR_NAMES.map(n=>({name:n,status:on[n]===false?'off':'on',items:2,members:[n],pending:n===pending}))},msg)}
const mgrRow=n=>[...W.document.querySelectorAll('#mgrList .mgr-row')].find(r=>r.querySelector('.nm').textContent.trim().startsWith(n));
const mgrScroll=y=>{W.document.querySelector('main').scrollTop=y};
// Mở tab Quản lý và cuộn tới mốc y (toạ độ nội dung)
function mgrOpen(tab){openPage('manager');W.document.querySelector('main').style.paddingBottom='260px';/* giữ trang đủ dài để vị trí cuộn không đổi giữa các khung */W.document.getElementById(tab==='migrate'?'mgr-tab-migrate':'mgr-tab-toggle').click()}
function contentTop(sel){const m=W.document.querySelector('main'),a=m.getBoundingClientRect(),b=W.document.querySelector(sel).getBoundingClientRect();return b.top-a.top+m.scrollTop}
