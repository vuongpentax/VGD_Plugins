const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const assert=(value,message)=>{if(!value)throw Error(message);};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.VGD_BROWSER_EXECUTABLE});
 try {
  const page=await browser.newPage({viewport:{width:640,height:780}});
  require('./ui_navigation.cjs')(page);
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(()=>{window.calls=[];window.sketchup={ready(){},action(value){calls.push(JSON.parse(value));}};});
  await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_scenes/dialog.html')).href);
  const settings={project:'',template:'<OBJECT>_<VIEW>',views:['ISO'],axis_mode:'local',grouping:'combined',isolate:true,width:1920,height:1080,margin:10,grid:'thirds',format:'png',transparent:false,paper:'A4_L',section_axis:'Y',section_percent:50,section_offset:0,section_flip:false,section_name:'A-A',normal_x:0,normal_y:1,normal_z:0,ratio_locked:false,export_scale:1,date_folder:false};
  let state={model:'A',title:'Khung',selection:1,editing:false,busy:false,settings,current_frame:{width:1920,height:1080,margin:10},camera:{perspective:true,fov:45,fov_vertical:true,eye_z_mm:1500,supported:true},presets:{'Hồ sơ đứng':{width:1200,height:1600,margin:20}},scenes:[{id:'1',name:'Tủ bếp_TOP',group:'Tủ bếp',selected:true,frame:{width:1920,height:1080,margin:10}},{id:'2',name:'Tủ bếp_ISO',group:'Tủ bếp',frame:{width:1200,height:1600,margin:15}},{id:'3',name:'Bàn_TOP',group:'Bàn',frame:{width:1600,height:1200,margin:10}}]};
  const sync=async(changes={})=>{state={...state,...changes};await page.evaluate(value=>VGDScenes.receive('state',value),state);};
  const result=async(success=true)=>page.evaluate(success=>VGDScenes.receive('result',{success,message:'Test'}),success);
  const mutations=()=>page.evaluate(()=>calls.filter(call=>call.action!=='refresh'));
  const last=async()=> (await mutations()).at(-1);
  await sync();await page.click('[data-tab="export"]');
  let count=(await mutations()).length;
  await page.fill('#width','12');await sync();assert((await mutations()).length===count && await page.inputValue('#width')==='12','Typing/poll saved or erased partial input');
  await page.fill('#width','2400');assert((await mutations()).length===count,'Saved while typing width');
  await page.press('#width','Enter');let call=await last();assert(call.action==='saveFrames'&&call.ids.join()==='1'&&call.frame.width===2400&&!call.settings,'Enter did not save only frame');
  count=(await mutations()).length;await page.focus('#height');assert((await mutations()).length===count,'Enter then blur duplicated frame');
  await page.fill('#margin','25');await page.focus('#height');assert((await last()).frame.margin===25,'Margin blur did not commit');
  await page.fill('#ratioInput','3:4');await page.press('#ratioInput','Enter');call=await last();assert(call.frame.width===1800&&call.frame.height===2400,'Ratio Enter incorrect');
  await page.selectOption('#namedPreset','Hồ sơ đứng');call=await last();assert(call.frame.width===1200&&call.frame.height===1600&&call.frame.margin===20,'Named preset did not auto save');
  await page.click('#swapRatio');call=await last();assert(call.frame.width===1600&&call.frame.height===1200,'Swap did not auto save');
  await page.fill('#presetName','Bản ngang');await page.click('#savePreset');assert((await last()).action==='framePreset'&&(await last()).name==='Bản ngang','Named save missing');await sync();
  await page.click('[data-tab="scenes"]');count=(await mutations()).length;
  await page.click('#selectGroup');assert(await page.locator('.scene-row input[type=checkbox]:checked').count()===2&&(await mutations()).length===count,'Group selection moved camera');
  await page.click('#selectNone');await page.fill('#groupQuery','Tủ bếp');await page.press('#groupQuery','Enter');assert(await page.locator('.scene-row input[type=checkbox]:checked').count()===2&&(await mutations()).length===count,'Text group selection visited scene');
  await page.click('[data-id="2"] .size-chip');
  const width=page.locator('[data-id="2"] [data-frame-key="width"]');
  await width.fill('20');await sync();assert(await width.inputValue()==='20'&&(await mutations()).length===count,'Poll erased inline draft');
  await width.fill('2000');await width.press('Enter');call=await last();assert(call.action==='saveFrames'&&call.ids.join()==='2'&&call.frame.width===2000,'Inline frame saved wrong page');
  await result(false);await width.press('Enter');assert((await mutations()).length===count+2,'Failed save could not retry identical input');
  await page.focus('#batchWidth');await page.fill('#batchWidth','3000');await page.click('#applyBatchFrame');call=await last();assert(call.ids.join()==='1,2'&&call.keep_ratio&&call.frame.width===3000,'Keep-ratio batch payload wrong');await sync();
  await page.uncheck('#batchKeepRatio');await page.selectOption('#batchPreset','Hồ sơ đứng');await page.click('#applyBatchFrame');call=await last();assert(!call.keep_ratio&&call.frame.height===1600,'Uniform preset batch wrong');await sync();
  await page.click('[data-tab="export"]');await page.fill('#cameraFov','65');await page.press('#cameraFov','Enter');call=await last();assert(call.action==='cameraPreview'&&call.camera.kind==='lens'&&call.camera.fov===65&&!call.frame,'FOV persisted frame/camera');await sync();
  for(const direction of ['+X','-X','+Y','-Y','+Z','-Z','AUTO']){await page.click('[data-align="'+direction+'"]');call=await last();assert(call.camera.direction===direction&&call.action==='cameraPreview','Axis button missing');await sync();}
  await page.selectOption('#alignAxes','local');await page.click('[data-align="AUTO"]');assert((await last()).camera.axis_mode==='local','Local auto missing');await sync();
  await page.click('#updateCurrentView');assert((await last()).action==='capture'&&(await last()).id==='1','Update saved wrong page');await sync();
  await sync({camera:{perspective:false,height_mm:2540,eye_z_mm:1500,supported:true}});assert(await page.locator('#fovField').isHidden()&&await page.locator('#parallelField').isVisible(),'Parallel exposes FOV');await page.fill('#parallelHeight','5000');await page.click('#previewLens');call=await last();assert(call.camera.height_mm===5000&&!('fov' in call.camera),'Parallel used FOV');await sync();
  await page.click('[data-tab="scenes"]');await width.fill('2500');count=(await mutations()).length;
  await sync({model:'B',scenes:[{id:'2',name:'Other model',selected:true,frame:{width:1000,height:1000,margin:10}}],current_frame:{width:1000,height:1000,margin:10}});
  await page.click('#selectGroup');assert((await mutations()).length===count&&await page.locator('.scene-name').innerText()==='Other model','Stale inline editor changed new model');
  for(const viewport of [{width:640,height:780},{width:460,height:540}]){await page.setViewportSize(viewport);await sync({model:'A',scenes:state.scenes});for(const tab of ['scenes','export']){await page.click('[data-tab="'+tab+'"]');assert(await page.evaluate(()=>document.querySelector('main').scrollWidth<=document.querySelector('main').clientWidth),'New layout overflows');}}
  fs.mkdirSync(path.resolve(__dirname,'../outputs'),{recursive:true});await page.screenshot({path:path.resolve(__dirname,'../outputs/frame_controls.png')});
  assert(!errors.length,errors.join('\n'));console.log('PASS: Enter/blur autosave only; no typing/poll commits; retry, inline page IDs, model switch; group without visit; named/bulk presets; six axes and preview-only FOV/parallel/Update');
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
