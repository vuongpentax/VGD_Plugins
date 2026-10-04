
var VGD={
 presets:{},builtin:[],delTimer:null,
 onBusy:function(value){document.querySelectorAll('button').forEach(function(b){b.disabled=value});if(!value)this.el('del').disabled=this.builtin.indexOf(this.el('preset').value)>=0;},
 nativeApply:function(){this.log('Đang áp mẫu Model Info…');sketchup.native_apply()},
 ids:['dim.setcolor','dim.color','dim.arrow','dim.textorient','dim.align',
      'text.setcolor','text.color',
      'label.setcolor','label.color','label.leader','label.arrow',
      'units.enabled','units.unit','units.precision','units.show_unit'],
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
  return{scope:document.querySelector('input[name=scope]:checked').value,
   nested:this.el('o.nested').checked,components:this.el('o.components').checked,
   hidden:this.el('o.hidden').checked,locked:this.el('o.locked').checked};
 },
 log:function(t,err){var l=this.el('log');l.textContent=t;l.className=err?'err':''},
 scan:function(){sketchup.scan(JSON.stringify({opts:this.opts()}))},
 run:function(kinds){
  this.log('Đang xử lý…');
  if(this.el('auto.enabled').checked)this.saveAuto();
  sketchup.run(JSON.stringify({kinds:kinds,settings:this.get(),opts:this.opts()}));
 },
 rebuild:function(){
  this.log('Đang làm mới Dimension…');
  sketchup.rebuild(JSON.stringify({opts:this.opts()}));
 },
 onRebuild:function(r){
  var t='Đã làm mới '+r.rebuilt+' Dimension'+(r.custom?' ('+r.custom+' cái giữ chữ ghi đè)':'')+'. Ctrl+Z để hoàn tác.',bad=false;
  if(r.failed){t+='\nKhông làm mới được '+r.failed+' Dimension (giữ nguyên bản cũ).';bad=true}
  if(r.skipped)t+='\nBỏ qua '+r.skipped+' Dimension bán kính (chưa hỗ trợ).';
  this.log(t,bad);
 },
 sdKeys:['face','h_side','v_side','off1','off2','min_seg','min_part','depth'],
 sdGet:function(){
  var o={};this.sdKeys.forEach(function(k){o[k]=VGD.el('sd.'+k).value});
  o.do_h=this.el('sd.do_h').checked;o.do_v=this.el('sd.do_v').checked;return o;
 },
 sdSet:function(o){
  this.sdKeys.forEach(function(k){if(o[k]!==undefined)VGD.el('sd.'+k).value=o[k]});
  if(o.do_h!==undefined)this.el('sd.do_h').checked=!!o.do_h;
  if(o.do_v!==undefined)this.el('sd.do_v').checked=!!o.do_v;
 },
 smart:function(){
  this.log('Đang dựng Dimension…');
  sketchup.smart_dim(JSON.stringify({opts:this.sdGet(),settings:this.get()}));
 },
 onSmart:function(r){
  var sum=function(a){return Math.round(a.reduce(function(x,y){return x+y},0)*10)/10};
  var t='Đã tạo '+r.total+' Dimension trên mặt '+r.face+' (dùng '+r.parts+' chi tiết). Ctrl+Z để hoàn tác.';
  if(r.h.length)t+='\nNgang: '+r.h.join(' + ')+' = '+sum(r.h);
  if(r.v.length)t+='\nĐứng: '+r.v.join(' + ')+' = '+sum(r.v);
  this.log(t);
 },
 saveAuto:function(){sketchup.set_auto(JSON.stringify({enabled:this.el('auto.enabled').checked,settings:this.get()}))},
 anim:function(on){
  sketchup.anim_set(JSON.stringify({enabled:on,transition:this.el('anim.transition').value,
   delay:this.el('anim.delay').value,loop:this.el('anim.loop').checked}));
 },
 loadPreset:function(){
  var n=this.el('preset').value;
  if(this.presets[n])this.set(this.presets[n]);
  this.el('pname').value=n;
  this.el('del').disabled=this.builtin.indexOf(n)>=0;
 },
 savePreset:function(){
  var n=this.el('pname').value.trim();
  if(!n){this.log('Nhập tên preset trước khi lưu.',true);return}
  sketchup.save_preset(JSON.stringify({name:n,settings:this.get()}));
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
  if(first){if(d.auto&&d.auto.settings)this.set(d.auto.settings);else this.loadPreset()}
 },
 onScan:function(r){
  this.el('st.dim').textContent=r.dim;this.el('st.text').textContent=r.text;
  this.el('st.label').textContent=r.label;this.el('st.nested').textContent=r.nested;
  this.log('Đã quét xong. Chưa thay đổi gì trong model.');
 },
 onResult:function(r){
  var t='Đã chuẩn hóa '+r.count.dim+' Dimension, '+r.count.text+' Text, '+r.count.label+' Label. Ctrl+Z để hoàn tác.',bad=false;
  Object.keys(r.report).forEach(function(k){
   var v=r.report[k];
   if(v.unsupported||v.error){bad=true;t+='\n'+k+': '+(v.unsupported||0)+' không hỗ trợ, '+(v.error||0)+' lỗi'}
  });
  this.log(t,bad);
 },
 onAnim:function(a){
  this.el('anim.transition').value=a.transition;this.el('anim.delay').value=a.delay;
  this.el('anim.loop').checked=a.loop;
  this.el('anim.state').textContent='Chuyển cảnh đang '+(a.enabled?'bật':'tắt')+'.';
 },
 onError:function(r){this.log('Lỗi: '+r.message,true)},
 onToast:function(r){this.log(r.message)}
};
['dim','text','label'].forEach(function(k){
 VGD.el(k+'.color').addEventListener('input',function(){VGD.el(k+'.setcolor').checked=true});
});
window.onload=function(){sketchup.ready()};
