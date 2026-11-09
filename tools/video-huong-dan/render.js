// Quay từng khung hình của một đoạn animation rồi ghép MP4 bằng ffmpeg.
// Dùng: node tools/video-huong-dan/render.js <file.html> <ra.mp4> [fps]
const {chromium}=require('playwright'),{execFileSync}=require('child_process'),fs=require('fs'),os=require('os'),path=require('path');
(async()=>{
 const [html,out,fpsArg]=process.argv.slice(2),fps=+(fpsArg||30);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'vgd-frames-'));
 const b=await chromium.launch(),p=await b.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1.5});
 await p.goto('file://'+path.resolve(html));await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(300);
 const n=Math.round(await p.evaluate(()=>DUR)*fps);
 for(let i=0;i<n;i++){await p.evaluate(t=>render(t),i/fps);await p.screenshot({path:`${dir}/f_${String(i).padStart(4,'0')}.png`})}
 await b.close();
 execFileSync('ffmpeg',['-y','-loglevel','error','-framerate',String(fps),'-i',`${dir}/f_%04d.png`,'-c:v','libx264','-pix_fmt','yuv420p','-crf','18','-movflags','+faststart',out]);
 fs.rmSync(dir,{recursive:true});console.log('xong',out,n,'khung');
})();
