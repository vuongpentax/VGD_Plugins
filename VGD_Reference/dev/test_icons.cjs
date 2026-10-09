const fs=require('fs'),path=require('path'),assert=require('assert');
const {pathToFileURL}=require('url'),{resolve}=require('./dependencies.cjs');
const {chromium}=require(resolve('playwright'));
const luminance=hex=>{const rgb=hex.slice(1).match(/../g).map(v=>parseInt(v,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;};
(async()=>{
  const root=path.resolve(__dirname,'..'),folder=path.join(root,'runtime','vgd_reference','assets','toolbar'),output=path.join(root,'outputs','icon-preview');
  const manifest=JSON.parse(fs.readFileSync(path.join(folder,'icon_manifest.json'),'utf8'));
  const version=fs.readFileSync(path.join(root,'runtime','vgd_reference.rb'),'utf8').match(/extension\.version = '([^']+)'/)[1];
  assert.strictEqual(manifest.version,version);assert.deepStrictEqual(manifest.preview_sizes,[16,24,32]);
  const sources=Object.fromEntries(['light','dark'].map(theme=>[theme,fs.readFileSync(path.join(folder,manifest.icons.reference.files[theme]),'utf8')]));
  fs.mkdirSync(output,{recursive:true});
  const browser=await chromium.launch({headless:true,...(process.env.VGD_BROWSER_EXECUTABLE?{executablePath:process.env.VGD_BROWSER_EXECUTABLE}:{channel:'msedge'})});
  try{
    const page=await browser.newPage({viewport:{width:1000,height:650},deviceScaleFactor:1}),errors=[];
    page.on('pageerror',error=>errors.push(error.message));
    const parsed=await page.evaluate(sources=>Object.fromEntries(Object.entries(sources).map(([theme,source])=>{
      const svg=new DOMParser().parseFromString(source,'image/svg+xml').documentElement;
      return [theme,{tag:svg.tagName,viewBox:svg.getAttribute('viewBox'),fill:svg.getAttribute('fill'),stroke:svg.getAttribute('stroke-width'),cap:svg.getAttribute('stroke-linecap'),join:svg.getAttribute('stroke-linejoin'),paths:Array.from(svg.querySelectorAll('path')).map(p=>({d:p.getAttribute('d'),stroke:p.getAttribute('stroke')})),extra:svg.querySelectorAll('rect,image,style,script').length}];
    })),sources);
    for(const theme of ['light','dark']){
      const icon=parsed[theme];assert.strictEqual(icon.tag,'svg');assert.strictEqual(icon.viewBox,'0 0 24 24');assert.strictEqual(icon.fill,'none');assert.strictEqual(icon.stroke,'1.8');assert.strictEqual(icon.cap,'round');assert.strictEqual(icon.join,'round');assert.strictEqual(icon.extra,0);assert.strictEqual(icon.paths.length,3);
      assert.deepStrictEqual(icon.paths.map(p=>p.stroke),[manifest.colors[theme].outline,manifest.colors[theme].outline,'#A67C58']);
      const a=luminance(manifest.colors[theme].outline),b=luminance(manifest.colors[theme].toolbar),contrast=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);assert(contrast>=3,'Outline contrast is too low');
      console.log(`PASS: ${theme} SVG structure, transparency declaration, palette; outline contrast ${contrast.toFixed(2)}:1.`);
    }
    assert.deepStrictEqual(parsed.light.paths.map(p=>p.d),parsed.dark.paths.map(p=>p.d),'Theme geometry drift');
    const raster=await page.evaluate(async sources=>{
      const results=[];
      for(const [theme,source] of Object.entries(sources))for(const size of [16,24,32]){
        const image=new Image();image.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(source);await image.decode();
        const canvas=document.createElement('canvas');canvas.width=canvas.height=size;const ctx=canvas.getContext('2d');ctx.drawImage(image,0,0,size,size);const {data}=ctx.getImageData(0,0,size,size);
        const corners=[0,size-1,size*(size-1),size*size-1].map(i=>data[i*4+3]);
        let painted=0,accent=0;for(let i=0;i<data.length;i+=4)if(data[i+3]){painted++;if(Math.abs(data[i]-166)<8&&Math.abs(data[i+1]-124)<8&&Math.abs(data[i+2]-88)<8)accent++;}
        results.push({theme,size,corners,painted,accent});
      }
      return results;
    },sources);
    for(const row of raster){assert(row.corners.every(a=>a===0),'Opaque icon background');assert(row.painted>30&&row.accent>2,`Missing glyph/pin at ${row.size}px`);}
    await page.goto(pathToFileURL(path.join(root,'dev','icon_preview.html')).href);
    await page.locator('[data-glyph]').evaluateAll(images=>Promise.all(images.map(img=>img.decode())));
    assert.strictEqual(await page.locator('[data-glyph]').count(),10);
    assert(await page.locator('[data-glyph]').evaluateAll(images=>images.every(img=>img.complete&&img.naturalWidth>0)),'Broken preview asset');
    for(const theme of ['light','dark']){
      assert(await page.locator(`.theme[data-theme="${theme}"] [data-glyph]`).evaluateAll((images,filename)=>images.every(img=>img.src.endsWith(filename)),manifest.icons.reference.files[theme]),'Gallery/toolbar/size assets drift');
    }
    await page.screenshot({path:path.join(output,'icons-light-page.png'),fullPage:true});
    await page.locator('#theme').click();assert.strictEqual(await page.locator('html').getAttribute('data-page-theme'),'dark');
    await page.screenshot({path:path.join(output,'icons-dark-page.png'),fullPage:true});
    assert.deepStrictEqual(errors,[]);
    fs.writeFileSync(path.join(output,'report.json'),JSON.stringify({version,raster,errors},null,2)+'\n');
    console.log('PASS: identical geometry, transparent raster at 16/24/32 px, shared runtime assets in gallery/toolbar/size rows, and theme toggle.');
    console.log('Preview saved: '+output);
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
