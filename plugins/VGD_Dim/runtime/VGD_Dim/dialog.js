var VGD={
 presets:{},builtin:[],delTimer:null,autoTimer:null,busy:false,tab:'smart',
 ids:['dim.setcolor','dim.color','dim.arrow','dim.textorient','dim.align',
      'text.setcolor','text.color',
      'label.setcolor','label.color','label.leader','label.arrow',
      'units.unit','units.precision','units.show_unit','units.reset_text'],
 el:function(i){return document.getElementById(i)},
 get:function(){
  var s={dim:{},text:{},label:{},units:{}};
  this.ids.forEach(function(id){var p=id.split('.'),e=VGD.el(id);s[p[0]][p[1]]=e.type==='checkbox'?e.checked:e.value});
  return s;
 },
 set:function(s){
  this.ids.forEach(function(id){
   var p=id.split('.'),e=VGD.el(id),v=(s[p[0]]||{})[p[1]];
   if(v===undefined)return;
   if(e.type==='checkbox')e.checked=!!v;else e.value=v;
  });
 },
 opts:function(){
  var deep=this.el('o.deep').checked;
  return{scope:document.querySelector('input[name=scope]:checked').value,
   nested:deep,components:deep,hidden:this.el('o.hidden').checked,locked:this.el('o.locked').checked};
 },
 log:function(t,err){var l=this.el('log');l.textContent=t;l.className=err?'err':''},
 onBusy:function(v){
  this.busy=v;
  document.querySelectorAll('main button,#shared-scope button').forEach(function(b){b.disabled=v});
  if(!v)this.el('del').disabled=this.builtin.indexOf(this.el('preset').value)>=0;
 },
 /* ---- Smart Dim ---- */
 sdKeys:['face','h_side','v_side','off1','off2','min_seg','min_part','depth'],
 sdGet:function(){
  var o={};this.sdKeys.forEach(function(k){o[k]=VGD.el('sd.'+k).value});
  o.do_h=this.el('sd.do_h').checked;o.do_v=this.el('sd.do_v').checked;o.use_section=this.el('sd.use_section').checked;o.scene_only=this.el('sd.scene_only').checked;return o;
 },
 sdSet:function(o){
  this.sdKeys.forEach(function(k){if(o[k]!==undefined)VGD.el('sd.'+k).value=o[k]});
  if(o.do_h!==undefined)this.el('sd.do_h').checked=!!o.do_h;
  if(o.do_v!==undefined)this.el('sd.do_v').checked=!!o.do_v;
  if(o.use_section!==undefined)this.el('sd.use_section').checked=!!o.use_section;
  if(o.scene_only!==undefined)this.el('sd.scene_only').checked=!!o.scene_only;
 },
 smart:function(){
  if(this.busy)return;this.onBusy(true);
  this.log('Đang dựng Dimension…');
  sketchup.smart_dim(JSON.stringify({opts:this.sdGet(),settings:this.get()}));
 },
 onSmart:function(r){
  this.onBusy(false);
  var sum=function(a){return Math.round(a.reduce(function(x,y){return x+y},0)*10)/10};
  var names={'-y':'-Y (trước)','+y':'+Y (sau)','-x':'-X (trái)','+x':'+X (phải)','+z':'+Z (trên)','-z':'-Z (dưới)'};
  var t=(r.replaced?'Đã cập nhật':'Đã tạo')+' '+r.total+' Dim '+(r.section?'mặt cắt ':'mặt ')+(names[r.face]||r.face)+' · Tag '+(r.tag||r.group)+'.';
  if(r.scene)t+=' Scene: '+r.scene+'.';
  if(r.h.length)t+='\nNgang: '+r.h.join(' + ')+' = '+sum(r.h);
  if(r.v.length)t+='\nĐứng: '+r.v.join(' + ')+' = '+sum(r.v);
  if(r.warnings&&r.warnings.length)t+='\n'+r.warnings.join('\n');
  this.log(t);
 },
 manualDim:function(){
  if(this.busy)return;this.onBusy(true);this.log('Đang bật Dim thủ công…');
  sketchup.manual_dim(JSON.stringify({settings:this.get()}));
 },
 setBoundary:function(){
  if(this.busy)return;this.onBusy(true);this.log('Chọn hai góc đối diện để đặt Boundary.');
  sketchup.set_boundary();
 },
 setDetail:function(){
  if(this.busy)return;var name=this.el('region.name').value.trim();
  if(!name){this.log('Nhập tên Detail Region trước khi tạo.',true);return}
  this.onBusy(true);this.log('Chọn hai góc đối diện trong Boundary.');
  sketchup.set_detail(JSON.stringify({name:name}));
 },
 activateRegion:function(){
  sketchup.set_region(JSON.stringify({id:this.el('region.active').value}));
 },
 deleteRegion:function(){
  var id=this.el('region.active').value;
  if(!id){this.log('Chọn Detail Region cần xóa.',true);return}
  sketchup.delete_region(id);
 },
 applyRegions:function(r){
  if(!r)return;
  this.el('region.boundary').textContent=r.boundary||'Chưa đặt';
  var select=this.el('region.active'),current=r.active_detail||'';
  select.innerHTML='';
  var base=document.createElement('option');base.value='';base.textContent=r.boundary?'Toàn Boundary':'Chưa có Boundary';select.appendChild(base);
  (r.details||[]).forEach(function(item){var option=document.createElement('option');option.value=item.id;option.textContent=item.name;select.appendChild(option)});
  select.value=current;
  this.el('region.delete').disabled=!current;
 },
 onRegions:function(r){this.applyRegions(r);this.log('Đã cập nhật vùng áp dụng.')},
 onRegionSaved:function(r){this.onBusy(false);this.el('region.name').value='';this.applyRegions(r.state);this.log('Đã lưu '+r.name+'.')},
 onToolStart:function(r){this.onBusy(true);this.log(r.message)},
 onManualStatus:function(r){this.onBusy(false);this.log(r.message)},
 onRegionCancelled:function(){this.onBusy(false);this.log('Đã hủy đặt vùng.')}, /* ---- Quét / áp ---- */
 scan:function(){if(this.busy)return;this.onBusy(true);sketchup.scan(JSON.stringify({opts:this.opts()}))},
 onScan:function(r){
  this.onBusy(false);
  this.el('st.dim').textContent=r.dim;this.el('st.text').textContent=r.text;
  this.el('st.label').textContent=r.label;this.el('st.nested').textContent=r.nested;
  this.log('Đã quét xong. Chưa thay đổi gì trong model.');
 },
 run:function(){
  if(this.busy)return;
  var kinds=['dim','text','label'].filter(function(k){return VGD.el('kind.'+k).checked});
  if(!kinds.length){this.log('Chọn Dimension, Text hoặc Label để áp.',true);return}
  this.onBusy(true);
  this.log('Đang áp style…');
  this.saveAutoNow();
  var settings=this.get();delete settings.units;
  sketchup.run(JSON.stringify({kinds:kinds,settings:settings,opts:this.opts()}));
 },
 onResult:function(r){
  this.onBusy(false);
  var t='Đã áp style cho '+r.count.dim+' Dimension, '+r.count.text+' Text, '+r.count.label+' Label. Ctrl+Z để hoàn tác.',bad=false;
  Object.keys(r.report).forEach(function(k){
   var v=r.report[k];
   if(k==='dim.align'&&v.unsupported){bad=true;t+='\nDim bán kính không hỗ trợ vị trí chữ: '+v.unsupported+' cái.'}
  });
  if(r.units){
   t+='\nĐơn vị: '+['inch','feet','mm','cm','m'][r.units.unit]+', số lẻ '+r.units.precision+', '+(r.units.show_unit?'hiện':'ẩn')+' ký hiệu.';
   if(r.units.reset)t+=' Đã trả '+r.units.reset+' Dim về chữ tự động.';
  }
  this.log(t,bad);
 },
 /* ---- Font / size ---- */
 rebuild:function(){
  if(this.busy)return;this.onBusy(true);
  this.log('Đang làm mới Dimension…');
  sketchup.rebuild(JSON.stringify({opts:this.opts()}));
 },
 onRebuild:function(r){
  this.onBusy(false);
  var t='Đã làm mới '+r.rebuilt+' Dimension'+(r.custom?' ('+r.custom+' cái giữ chữ ghi đè)':'')+'. Ctrl+Z để hoàn tác.',bad=false;
  if(r.failed){t+='\nKhông làm mới được '+r.failed+' Dimension (giữ nguyên bản cũ).';bad=true}
  if(r.skipped)t+='\nBỏ qua '+r.skipped+' Dimension bán kính.';
  this.log(t,bad);
 },
 nativeApply:function(){if(this.busy)return;this.onBusy(true);this.log('Đang áp mẫu Model Info…');sketchup.native_apply()},
 unitsApply:function(){if(this.busy)return;this.onBusy(true);this.log('Đang áp đơn vị toàn model…');sketchup.units_apply(JSON.stringify({settings:this.get().units}))},
 onUnits:function(r){this.onBusy(false);this.set({units:r});this.log('Đã áp đơn vị toàn model: '+['inch','feet','mm','cm','m'][r.unit]+', '+r.precision+' số lẻ.'+(r.reset?' Đã mở '+r.reset+' chữ Dim dạng số.':''))},
 /* ---- Auto-Style: tự lưu khi form đổi ---- */
 saveAutoNow:function(){
  if(!this.el('auto.enabled').checked)return;
  sketchup.set_auto(JSON.stringify({enabled:true,settings:this.get()}));
 },
 saveAuto:function(){
  sketchup.set_auto(JSON.stringify({enabled:this.el('auto.enabled').checked,settings:this.get()}));
 },
 autoSoon:function(){
  if(!this.el('auto.enabled').checked)return;
  clearTimeout(this.autoTimer);
  this.autoTimer=setTimeout(function(){VGD.saveAuto()},500);
 },
 /* ---- Animation ---- */
 anim:function(on){
  sketchup.anim_set(JSON.stringify({enabled:on,transition:this.el('anim.transition').value,
   delay:this.el('anim.delay').value,loop:this.el('anim.loop').checked}));
 },
 onAnim:function(a){
  this.el('anim.transition').value=a.transition;this.el('anim.delay').value=a.delay;
  this.el('anim.loop').checked=a.loop;
  this.el('anim.state').textContent='Chuyển cảnh đang '+(a.enabled?'bật':'tắt')+'.';
 },
 /* ---- Preset ---- */
 loadPreset:function(){
  var n=this.el('preset').value;
  if(this.presets[n])this.set(this.presets[n]);
  this.el('pname').value=n;
  this.el('del').disabled=this.builtin.indexOf(n)>=0;
  this.autoSoon();
 },
 savePreset:function(){
  var n=this.el('pname').value.trim();
  if(!n){this.log('Nhập tên preset trước khi lưu.',true);return}
  var settings=this.get();delete settings.units;
  sketchup.save_preset(JSON.stringify({name:n,settings:settings}));
 },
 delPreset:function(){
  var b=this.el('del'),n=this.el('preset').value;
  if(!this.delTimer){
   b.textContent='Bấm lại để xóa';b.className='danger';
   this.delTimer=setTimeout(function(){VGD.resetDel()},3000);return;
  }
  this.resetDel();sketchup.delete_preset(n);
 },
 resetDel:function(){clearTimeout(this.delTimer);this.delTimer=null;var b=this.el('del');b.textContent='Xóa';b.className='quiet'},
 onState:function(d){
  if(d.version)this.el('ver').textContent='v'+d.version;
  this.presets=d.presets;this.builtin=d.builtin;
  var sel=this.el('preset'),cur=d.select||sel.value;sel.innerHTML='';
  Object.keys(d.presets).forEach(function(n){var o=document.createElement('option');o.textContent=n;sel.appendChild(o)});
  var first=!cur;
  if(cur&&d.presets[cur])sel.value=cur;
  this.el('pname').value=sel.value;
  this.el('del').disabled=this.builtin.indexOf(sel.value)>=0;
  if(d.auto)this.el('auto.enabled').checked=!!d.auto.enabled;
  if(d.anim)this.onAnim(d.anim);
  if(d.smart)this.sdSet(d.smart);
  if(first){if(d.auto&&d.auto.enabled&&d.auto.settings)this.set(d.auto.settings);else if(d.smart_style)this.set(d.smart_style);else this.loadPreset()}
  if(d.units)this.set({units:d.units});if(d.regions)this.applyRegions(d.regions);
  this.onBusy(false);this.updateScope();
 },
 onError:function(r){this.onBusy(false);this.log('Lỗi: '+r.message,true)},
 onToast:function(r){this.onBusy(false);this.log(r.message)},
 nav:function(name,focus){
  if(!this.el('panel-'+name))return;
  this.tab=name;
  document.querySelectorAll('[data-tab]').forEach(function(b){var on=b.dataset.tab===name;b.setAttribute('aria-selected',on?'true':'false');b.tabIndex=on?0:-1;if(on&&focus)b.focus()});
  document.querySelectorAll('.function-panel').forEach(function(p){p.hidden=p.id!=='panel-'+name});
  this.el('shared-scope').hidden=['font','style'].indexOf(name)<0;
  this.updateScope();document.querySelector('main').scrollTop=0;
 },
 updateScope:function(){
  var scope=document.querySelector('input[name=scope]:checked').value;
  var labels={selected:'Đang chọn',context:'Group đang mở',model:'Toàn model'};
  ['font','style'].forEach(function(k){VGD.el('badge-'+k).textContent=labels[scope]});
  this.el('badge-smart').textContent='Group/Component đang chọn';this.el('badge-units').textContent='Toàn model';this.el('badge-animation').textContent='Toàn model';this.el('badge-presets').textContent='Lưu trên máy';
 },
 mountScope:function(){var target=this.el(innerWidth<=740?'mobile-scope':'desktop-scope');if(this.el('shared-scope').parentElement!==target)target.appendChild(this.el('shared-scope'))},
 toggleTheme:function(){this.setTheme(document.body.dataset.theme==='dark'?'light':'dark')},
 setTheme:function(theme){document.documentElement.dataset.theme=theme;document.body.dataset.theme=theme;this.el('theme').setAttribute('aria-pressed',theme==='dark'?'true':'false');try{localStorage.setItem('vgd.dim.theme',theme)}catch(e){}}
};
['dim','text','label'].forEach(function(k){
 VGD.el(k+'.color').addEventListener('input',function(){VGD.el(k+'.setcolor').checked=true});
});
VGD.ids.forEach(function(id){
 VGD.el(id).addEventListener('change',function(){VGD.autoSoon()});
 VGD.el(id).addEventListener('input',function(){VGD.autoSoon()});
});
document.querySelectorAll('[data-tab]').forEach(function(b){b.addEventListener('click',function(){VGD.nav(b.dataset.tab)});b.addEventListener('keydown',function(e){var buttons=Array.from(document.querySelectorAll('[data-tab]')),i=buttons.indexOf(b),target=null;if(e.key==='ArrowDown'||e.key==='ArrowRight')target=(i+1)%buttons.length;if(e.key==='ArrowUp'||e.key==='ArrowLeft')target=(i+buttons.length-1)%buttons.length;if(e.key==='Home')target=0;if(e.key==='End')target=buttons.length-1;if(target!==null){e.preventDefault();VGD.nav(buttons[target].dataset.tab,true)}})});
document.querySelectorAll('input[name=scope]').forEach(function(e){e.addEventListener('change',function(){VGD.updateScope()})});
window.addEventListener('resize',function(){VGD.mountScope()});
window.onload=function(){var theme='dark';try{theme=localStorage.getItem('vgd.dim.theme')||theme}catch(e){}VGD.setTheme(theme);VGD.nav('smart');VGD.mountScope();sketchup.ready()};
