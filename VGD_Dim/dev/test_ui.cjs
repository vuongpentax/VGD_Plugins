const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const deps=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
if(!deps)throw Error('Set CODEX_PRIMARY_RUNTIME_NODE_MODULES');
const {chromium}=require(path.join(deps,'playwright'));
const assert=(v,m)=>{if(!v)throw Error(m)};
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const page=await browser.newPage({viewport:{width:540,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{
   window.calls=[];window.alerts=[];
   window.alert=m=>alerts.push(m);
   window.sketchup=new Proxy({},{get:(_,action)=>payload=>calls.push({action,payload})});
  });
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/VGD_Dim/dialog.html')).href);
  const last=async()=>page.evaluate(()=>calls.at(-1));
  assert((await last()).action==='ready','Ready missing');
  assert(await page.title()==='VGD Dim','Rename missing');
  await page.evaluate(()=>VGD.onState({
   presets:{'VGD Standard':{dim:{setcolor:false,color:'#000000',arrow:'keep',textorient:'keep',align:'keep'},text:{setcolor:false,color:'#000000'},label:{setcolor:false,color:'#000000',arrow:'keep',leader:'keep'},units:{enabled:false,unit:'2',precision:'0',show_unit:false}}},
   builtin:['VGD Standard'],auto:{enabled:false},smart:{},anim:{enabled:true,transition:1,delay:2,loop:false}
  }));
  const palette=await page.evaluate(()=>({header:getComputedStyle(document.querySelector('header')).backgroundColor,button:getComputedStyle(document.querySelector('footer .solid')).backgroundColor}));
  assert(palette.header==='rgb(43, 43, 43)' && palette.button==='rgb(180, 137, 99)','T+ palette lost');
  assert(await page.locator('#del').isDisabled(),'Builtin deletion enabled');
  await page.getByRole('button',{name:'Quét',exact:true}).click();
  let call=await last(),data=JSON.parse(call.payload);
  assert(call.action==='scan' && data.opts.scope==='selected' && data.opts.nested && data.opts.components && !data.opts.hidden && !data.opts.locked,'Default scan unsafe/wrong');
  await page.locator('[id="dim.color"]').fill('#112233');
  await page.selectOption('[id="dim.arrow"]','dot');
  await page.selectOption('[id="dim.textorient"]','aligned');
  await page.selectOption('[id="dim.align"]','above');
  await page.selectOption('[id="label.leader"]','pushpin');
  await page.getByRole('button',{name:'Áp style theo phạm vi',exact:true}).click();
  data=JSON.parse((await last()).payload);
  assert(data.kinds.join(',')==='dim,text,label' && data.settings.dim.setcolor && data.settings.dim.color==='#112233' && data.settings.dim.align==='above' && data.settings.label.leader==='pushpin' && !data.settings.units.enabled,'Style payload wrong');
  await page.locator('input[name=scope][value=model]').check();
  await page.getByRole('button',{name:'Quét',exact:true}).click();
  assert(JSON.parse((await last()).payload).opts.scope==='model','Whole model not available');
  await page.locator('input[name=scope][value=context]').check();
  await page.getByRole('button',{name:'Quét',exact:true}).click();
  assert(JSON.parse((await last()).payload).opts.scope==='context','Context scope missing');
  await page.locator('[id="sd.face"]').selectOption('-y');
  await page.locator('[id="sd.off1"]').fill('120');
  await page.getByRole('button',{name:'Smart Dim cho tủ đang chọn',exact:true}).click();
  data=JSON.parse((await last()).payload);
  assert((await last()).action==='smart_dim' && data.opts.face==='-y' && data.opts.off1==='120' && data.opts.do_h && data.opts.do_v,'Smart payload wrong');
  await page.getByRole('button',{name:'Làm mới size theo Model Info',exact:true}).click();
  assert((await last()).action==='rebuild','Rebuild callback missing');
  await page.click('#dim-info');assert((await last()).action==='dim_info','Dim Info callback missing');
  await page.click('#text-info');assert((await last()).action==='text_info','Text Info callback missing');
  await page.click('#native-apply');assert((await last()).action==='native_apply','Native Apply missing');
  await page.evaluate(()=>VGD.onBusy(true));
  assert(await page.locator('#native-apply').isDisabled(),'Busy state missing');
  await page.evaluate(()=>VGD.onBusy(false));
  await page.locator('#pname').fill('My preset');
  await page.getByRole('button',{name:'Lưu preset',exact:true}).click();
  assert((await last()).action==='save_preset' && JSON.parse((await last()).payload).name==='My preset','Preset save missing');
  await page.locator('[id="auto.enabled"]').check();
  assert((await last()).action==='set_auto' && JSON.parse((await last()).payload).enabled,'Auto callback missing');
  await page.locator('[id="anim.transition"]').fill('3.5');
  await page.getByRole('button',{name:'Tắt animation',exact:true}).click();
  data=JSON.parse((await last()).payload);
  assert((await last()).action==='anim_set' && !data.enabled && data.transition==='3.5','Animation payload wrong');
  await page.locator('details').filter({has:page.getByText('Đơn vị của model',{exact:true})}).locator('summary').click();
  await page.locator('[id="units.enabled"]').check();
  await page.locator('[id="units.unit"]').selectOption('3');
  await page.getByRole('button',{name:'Áp style theo phạm vi',exact:true}).click();
  data=JSON.parse((await last()).payload);
  assert(data.settings.units.enabled && data.settings.units.unit==='3','Units missing');
  await page.evaluate(()=>{VGD.onScan({dim:2,text:3,label:4,nested:1});VGD.onError({message:'Test error'});});
  assert(await page.locator('[id="st.dim"]').innerText()==='2' && (await page.locator('#log').innerText()).includes('Test error'),'Stats/error missing');
  assert(await page.evaluate(()=>alerts.length)===0,'Popup remains');
  const out=path.resolve(__dirname,'../outputs');fs.mkdirSync(out,{recursive:true});
  await page.reload();
  await page.evaluate(()=>VGD.onState({presets:{'VGD Standard':{}},builtin:['VGD Standard'],auto:{enabled:false},smart:{},anim:{enabled:true,transition:1,delay:2,loop:false}}));
  for(const [width,height] of [[540,800],[360,600]]){
   await page.setViewportSize({width,height});
   const layout=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,footer:document.querySelector('footer').getBoundingClientRect().bottom<=innerHeight,main:document.querySelector('main').clientHeight>100}));
   assert(!layout.overflow && layout.footer && layout.main,'Clipped UI '+width);
   await page.screenshot({path:path.join(out,'vgd_dim_full_'+width+'.png')});
  }
  assert(errors.length===0,errors.join(';'));
  console.log('PASS: VGD Dim full UI, T+ palette, all scopes, Smart/Info/rebuild, presets/auto/animation/Units payloads, busy state, inline errors/no popups, footer at 540 and 360px');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
