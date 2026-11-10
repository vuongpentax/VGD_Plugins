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
function start(){document.fonts.ready.then(init);
 if(location.search.includes('play')){const t0=performance.now();(function f(){render(((performance.now()-t0)/1000)%DUR);requestAnimationFrame(f)})()}}
// --- Giao diện tab Quản lý > Chuyển plugin (dùng chung cho đoạn 5, 6) ---
const PLUG=['VGD_Cabinet_Draw','VGD_Dim','VGD_Scenes','VGD_Library'];
const MGR_HEAD='<div class="eb">MỌI PLUGIN TRONG SKETCHUP</div><h2>Quản lý</h2><div class="mets"><div class="met"><b>3</b><span>Đang bật</span></div><div class="met"><b>1</b><span>Đã tắt</span></div><div class="met"><b>0</b><span>Bộ plugin</span></div></div>'
 +'<div class="tabs"><div id="tabT">Bật/tắt</div><div id="tabM">Chuyển plugin</div></div>';
const MIG_PANEL='<div class="vr"><span>Từ bản<span class="selbox" id="selSrc">2022 <small>▾</small></span></span><span>Sang bản<span class="selbox" id="selDst">2024 <small>▾</small></span></span></div>'
 +'<div class="vr" id="ovwRow"><span class="cbx" id="ovw"></span><span>Ghi đè nếu plugin đã tồn tại ở bản đích</span></div>'
 +'<div class="mt2"><div class="in" style="max-width:150px">Tìm plugin...</div><div class="btn" id="btnAll" style="min-height:26px;font-size:10px">Chọn hết đang hiện</div><div class="btn" id="btnNone" style="min-height:26px;font-size:10px">Bỏ chọn hết</div><small id="cnt"></small></div>'
 +'<div class="mt2" style="justify-content:flex-end"><div class="btn" id="btnExp" style="min-height:28px">Xuất gói .rbz tổng</div><div class="btn p" id="btnGo" style="min-height:28px">Chuyển sang bản 2024</div></div>'
 +'<div class="lst" id="plist">'+PLUG.map((n,i)=>`<div class="mr" id="pr${i}"><span class="cbx" id="pc${i}"></span><div class="nm">${n}</div></div>`).join('')+'</div><div class="out" id="out"></div>';
// đặt dấu chọn cho từng plugin và cập nhật dòng "Đã chọn n/4"
function setChecks(on){on.forEach((v,i)=>$('pc'+i).className='cbx'+(v?' on':''));$('cnt').textContent='Đã chọn '+on.filter(Boolean).length+'/'+on.length}
