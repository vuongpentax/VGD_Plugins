// Quay từng khung hình của một đoạn animation rồi ghép MP4 bằng ffmpeg.
// Dùng: node tools/video-huong-dan/render.js <file.html> <ra.mp4> [fps]
// Trang cần giao diện Center thật (iframe) nên được phục vụ qua một máy chủ HTTP tạm thời ở gốc repo.
const {chromium}=require('playwright'),{execFileSync}=require('child_process'),fs=require('fs'),os=require('os'),path=require('path'),http=require('http');
const TYPES={'.html':'text/html;charset=utf-8','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.woff2':'font/woff2','.json':'application/json','.png':'image/png'};
const repo=path.resolve(__dirname,'..','..');
function serve(){return new Promise(res=>{const s=http.createServer((q,r)=>{const f=path.join(repo,decodeURIComponent(q.url.split('?')[0]));if(!f.startsWith(repo)){r.writeHead(403);return r.end()}
 fs.readFile(f,(e,d)=>{if(e){r.writeHead(404);return r.end()}r.writeHead(200,{'Content-Type':TYPES[path.extname(f)]||'application/octet-stream'});r.end(d)})}).listen(0,'127.0.0.1',()=>res(s))})}
(async()=>{
 const [html,out,fpsArg]=process.argv.slice(2),fps=+(fpsArg||30);
 const srv=await serve(),url=`http://127.0.0.1:${srv.address().port}/${path.relative(repo,path.resolve(html)).split(path.sep).join('/')}`;
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'vgd-frames-'));
 const b=await chromium.launch(),p=await b.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1.5,colorScheme:'dark'});
 p.on('pageerror',e=>{console.error('Lỗi trang:',e.message);process.exitCode=1});
 await p.goto(url);await p.waitForFunction('window.__ready===true',null,{timeout:30000});await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(300);
 const n=Math.round(await p.evaluate(()=>DUR)*fps);
 for(let i=0;i<n;i++){await p.evaluate(t=>render(t),i/fps);await p.screenshot({path:`${dir}/f_${String(i).padStart(4,'0')}.png`})}
 await b.close();srv.close();
 execFileSync('ffmpeg',['-y','-loglevel','error','-framerate',String(fps),'-i',`${dir}/f_%04d.png`,'-c:v','libx264','-pix_fmt','yuv420p','-crf','18','-movflags','+faststart',out]);
 fs.rmSync(dir,{recursive:true});console.log('xong',out,n,'khung');
})();
