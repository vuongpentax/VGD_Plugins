// Inspect the production draw commands recorded by test_upgrade.rb. Canvas
// is an offline visual fixture; it does not certify SketchUp's renderer.
const fs=require('fs');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES+'/playwright');
(async()=>{
 const commands=JSON.parse(fs.readFileSync('outputs/preview_draw.json'));
 const html=`<!doctype html><meta charset="utf-8"><style>body{margin:0;background:#e7e4df}canvas{display:block}</style><canvas width="640" height="660"></canvas><script>
 const ctx=document.querySelector('canvas').getContext('2d');
 for(const [mode,points,color,stipple] of ${JSON.stringify(commands)}){
  ctx.fillStyle=ctx.strokeStyle='rgba('+color.slice(0,3).join(',')+','+(color[3]/255)+')';ctx.setLineDash(stipple==='-'?[4,4]:[]);ctx.lineWidth=1;
  const polygon=vertices=>{ctx.beginPath();vertices.forEach((p,i)=>i?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]));ctx.closePath();};
  if(mode===4){for(let i=0;i<points.length;i+=3){polygon(points.slice(i,i+3));ctx.fill();}}
  else if(mode===2){polygon(points);ctx.stroke();}
  else if(mode===1){ctx.beginPath();ctx.moveTo(...points[0].slice(0,2));ctx.lineTo(...points[1].slice(0,2));ctx.stroke();}
 }
 ctx.fillStyle='#63492f';ctx.font='12px sans-serif';ctx.fillText('VGD · Preview fixture 1600 × 600 × 2700 · Shaker / X',24,26);
 </script>`;
 fs.writeFileSync('outputs/preview_canvas.html',html);
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try {
  const page=await browser.newPage({viewport:{width:640,height:660}});const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.setContent(html);await page.screenshot({path:'outputs/preview_canvas.png'});
  if(errors.length)throw Error(errors.join('\n'));
  console.log('PASS offline preview canvas: production draw commands rendered; screenshot requires visual inspection, no native SketchUp rendering claim');
 } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
