// Hàm dùng chung cho các đoạn animation. Mỗi đoạn tự khai báo DUR, init(), render(t).
// Chuyển động theo phong cách "Corporate" của motion-design: cubic-bezier(0.2,0,0,1), không nảy.
const $=id=>document.getElementById(id),clamp=x=>Math.max(0,Math.min(1,x)),P=(t,a,b)=>clamp((t-a)/(b-a));
function bez(x1,y1,x2,y2){return x=>{if(x<=0)return 0;if(x>=1)return 1;let lo=0,hi=1,t=x;for(let i=0;i<30;i++){t=(lo+hi)/2;const cx=3*x1*t*(1-t)**2+3*x2*t*t*(1-t)+t**3;cx<x?lo=t:hi=t}return 3*y1*t*(1-t)**2+3*y2*t*t*(1-t)+t**3}}
const E=bez(.2,0,0,1),lerp=(a,b,k)=>a+(b-a)*k;
const R=el=>{const r=el.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}};
// Điểm đặt con trỏ: lệch xuống phải để không che chữ trên nút
const aim=(r,fx=.74)=>({x:r.x+r.w*fx,y:r.y+r.h*.72});
// Camera phóng to: đưa điểm (fx,fy) của world tới (tx,ty) trên màn hình
const zoomTo=(fx,fy,s,tx,ty)=>({s,x:tx-s*fx,y:ty-s*fy});
const mix=(a,b,k)=>({s:lerp(a.s,b.s,k),x:lerp(a.x,b.x,k),y:lerp(a.y,b.y,k)});
function pos(M,t){let m=null;for(const q of M)if(t>=q.a)m=q;if(!m)return M[0].f;const k=E(P(t,m.a,m.b)),mx=(m.f.x+m.t.x)/2,my=(m.f.y+m.t.y)/2,dx=m.t.x-m.f.x,dy=m.t.y-m.f.y,L=Math.hypot(dx,dy)||1,cx=mx-dy/L*m.arc,cy=my+dx/L*m.arc;
 return{x:(1-k)**2*m.f.x+2*(1-k)*k*cx+k*k*m.t.x,y:(1-k)**2*m.f.y+2*(1-k)*k*cy+k*k*m.t.y}}
// xung 0→1→0 trong [a,b] (dùng cho hiệu ứng nhấn nút)
const pulse=(t,a,b)=>clamp(Math.min(P(t,a,a+.35),1-P(t,b-.35,b)));
function cap(el,t,a,b,y){const o=E(P(t,a,a+.35))*(1-E(P(t,b,b+.3)));el.style.opacity=o;el.style.transform=`translate(-50%,${y+(1-o)*14}px)`}
function setWorld(c){$('world').style.transform=`translate(${c.x}px,${c.y}px) scale(${c.s})`}
// Con trỏ nằm ngoài world nên không bị phóng to theo camera
function drawCursor(c,p,t,fadeIn,fadeOut,press,rip){const sx=c.x+c.s*p.x,sy=c.y+c.s*p.y,cu=$('cur');
 cu.style.opacity=E(P(t,fadeIn,fadeIn+.4))*(1-E(P(t,fadeOut,fadeOut+.4)));cu.style.transform=`translate(${sx-4.3}px,${sy-2.2}px) scale(${1-.12*press})`;
 const r=$('rip');r.style.opacity=rip>0&&rip<1?1-rip:0;r.style.transform=`translate(${sx-5}px,${sy-5}px) scale(${1+rip*3})`}
function start(){
 // chờ font và (nếu có) giao diện Center thật tải xong rồi mới dựng; window.__ready báo cho render.js
 Promise.all([document.fonts.ready,window.CENTER_READY||Promise.resolve()]).then(async()=>{await init();window.__ready=true;
 if(location.search.includes('play')){const t0=performance.now();(function f(){render(((performance.now()-t0)/1000)%DUR);requestAnimationFrame(f)})()}})}
// Zoom vừa đủ để cả vùng r nằm trọn trong khung hình (chừa lề pad mỗi bên); maxS là mức zoom tối đa
const fitZoom=(r,maxS,tx,ty,pad=80)=>zoomTo(r.x+r.w/2,r.y+r.h/2,Math.min(maxS,(1280-2*pad)/r.w),tx,ty);

// --- Nhúng giao diện thật của một plugin (hộp thoại HTML) bằng iframe ---
// Cần chạy qua máy chủ HTTP (render.js tự mở). Mọi thay đổi trên giao diện đi qua hàm thật của plugin; ở đây chỉ mô phỏng
// phía Ruby bằng dữ liệu theo thời gian. W là cửa sổ của giao diện đang nhúng.
let W=null;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
// opts.stub: giao diện gọi sketchup.* mà không kiểm tra (ví dụ VGD Dim) nên cấp sẵn một đối tượng sketchup rỗng (mọi lệnh không làm gì)
async function mountApp(url,frameId='cf',themeKey=null,opts={}){
 if(themeKey){try{localStorage.setItem(themeKey,'dark')}catch(_){}}
 const f=$(frameId);
 if(opts.stub){const abs=new URL(url,location.href).href;let html=await (await fetch(abs)).text();
  html=html.replace('<head>',`<head><base href="${abs.slice(0,abs.lastIndexOf('/')+1)}"><script>window.sketchup=new Proxy({},{get:()=>()=>{}})<\/script>`);
  await new Promise(res=>{f.onload=res;f.srcdoc=html})}
 else await new Promise(res=>{f.onload=res;f.src=url});
 W=f.contentWindow;await sleep(500);
 const d=W.document,st=d.createElement('style');
 // tắt hiệu ứng chuyển động CSS để điều khiển từng khung hình
 st.textContent='*,*::before,*::after{transition:none!important;animation:none!important;scroll-behavior:auto!important}';d.head.appendChild(st);
 // mô phỏng :hover bằng lớp .fx-hover (rê chuột thật không có khi quay khung hình)
 for(const sh of d.styleSheets){let rules;try{rules=sh.cssRules}catch(_){continue}
  for(const r of [...rules]){if(r.selectorText&&r.selectorText.includes(':hover'))sh.insertRule(r.selectorText.replace(/:hover/g,'.fx-hover')+'{'+r.style.cssText+'}',sh.cssRules.length)}}
 return W;
}
// Vị trí phần tử trong iframe, tính theo toạ độ khung hình (chỉ đo khi world chưa phóng to)
// Nếu khung (iframe) bị phóng to bằng CSS (transform), hệ số phóng được nhân vào toạ độ phần tử bên trong.
function RC(sel,frameId='cf'){const el=typeof sel==='string'?W.document.querySelector(sel):sel,fr=$(frameId),f=fr.getBoundingClientRect(),r=el.getBoundingClientRect(),sx=f.width/(fr.offsetWidth||f.width),sy=f.height/(fr.offsetHeight||f.height);return{x:f.x+r.x*sx,y:f.y+r.y*sy,w:r.width*sx,h:r.height*sy}}
function hover(sel,on){const e=W.document.querySelector(sel);if(e)e.classList.toggle('fx-hover',!!on)}
