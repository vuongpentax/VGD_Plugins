(function(){
  'use strict';
  const MAX_BYTES=20*1024*1024,MAX_PNG=64*1024*1024,MAX_PIXELS=32000000,CHUNK=192*1024;
  const extensions=/\.(jpe?g|jfif|jpe|png|apng|bmp|dib|tiff?|tga|webp|gif|avif|ico|cur|svg|heic|heif|jp2|j2k|jxr|wdp|hdp)$/i;
  const pending=new Map();
  let notify=()=>{},serial=Promise.resolve(),dragDepth=0;
  function call(name,...args){
    if(!window.sketchup||typeof window.sketchup[name]!=='function')throw new Error('Hãy mở VGD Reference trong SketchUp để nhận ảnh.');
    window.sketchup[name](...args);
  }
  const key=(method,token,index)=>method+'|'+token+'|'+String(index);
  function ack(method,token,index,result){const item=pending.get(key(method,token,index));if(!item)return;pending.delete(key(method,token,index));clearTimeout(item.timer);result?item.resolve():item.reject(new Error('Không nhận được dữ liệu ảnh.'));}
  function request(method,token,index,args){
    return new Promise((resolve,reject)=>{
      const id=key(method,token,index),timer=setTimeout(()=>{pending.delete(id);reject(new Error('Truyền ảnh quá thời gian. Hãy thả lại ảnh.'));},20000);
      pending.set(id,{resolve,reject,timer});
      try{call(method,...args);}catch(error){pending.delete(id);clearTimeout(timer);reject(error);}
    });
  }
  function base64(bytes){let binary='';for(let i=0;i<bytes.length;i+=0x8000)binary+=String.fromCharCode.apply(null,bytes.subarray(i,Math.min(i+0x8000,bytes.length)));return btoa(binary);}
  async function transfer(blob,token,name,converted){
    const limit=converted?MAX_PNG:MAX_BYTES;
    if(!blob.size||blob.size>limit)throw new Error(converted?'Ảnh sau chuyển đổi vượt dung lượng 64 MiB.':'Ảnh phải có dung lượng không quá 20 MiB.');
    const chunks=Math.ceil(blob.size/CHUNK),start=converted?'convertedStart':'dropStart',part=converted?'convertedChunk':'dropChunk',end=converted?'convertedFinish':'dropFinish';
    await request(start,token,null,converted?[token,blob.size,chunks]:[token,name,blob.size,chunks,blob.type]);
    for(let index=0;index<chunks;index++){
      const bytes=new Uint8Array(await blob.slice(index*CHUNK,Math.min((index+1)*CHUNK,blob.size)).arrayBuffer());
      await request(part,token,index,[token,index,base64(bytes)]);
    }
    await request(end,token,null,[token]);
  }
  function normalizeUrl(value,base){
    value=(value||'').trim();
    if(!value)return null;
    if(/^data:image\//i.test(value))return value;
    try{const url=new URL(value,base||undefined);return /^https?:$/.test(url.protocol)?url.href:null;}catch(_){return null;}
  }
  function collectDrop(transferData){
    // Read strings synchronously: the browser closes the drag data store after drop.
    const files=Array.from(transferData.files||[]),html=transferData.getData('text/html')||'';
    const texts=[transferData.getData('text/uri-list'),transferData.getData('text/x-moz-url'),transferData.getData('text/plain'),transferData.getData('URL')];
    const links=[];texts.forEach(text=>(text||'').split(/\r?\n/).forEach(line=>{if(!line.startsWith('#')){const url=normalizeUrl(line);if(url)links.push(url);}}));
    const urls=[];let name='';
    if(html){
      const template=document.createElement('template');template.innerHTML=html.slice(0,1024*1024);
      const anchor=template.content.querySelector('a[href]');
      const base=links.find(url=>/^https?:/i.test(url))||(anchor&&normalizeUrl(anchor.getAttribute('href')));
      const image=template.content.querySelector('img');
      if(image){
        name=(image.getAttribute('alt')||'').trim().slice(0,200);
        ['data-original','data-src','src'].forEach(attribute=>{const url=normalizeUrl(image.getAttribute(attribute),base);if(url)urls.push(url);});
        const srcset=(image.getAttribute('srcset')||'').split(/\s*,\s*(?=(?:https?:)?\/\/)/).map(part=>{const match=part.trim().match(/^(.*?)\s+(\d+(?:\.\d+)?)[wx]$/);return {url:normalizeUrl(match?match[1]:part,base),size:match?Number(match[2]):0};}).filter(item=>item.url).sort((a,b)=>b.size-a.size);
        urls.unshift(...srcset.map(item=>item.url));
      }
    }
    urls.push(...links);
    const candidates=[];
    urls.forEach(address=>{
      if(/^https?:/i.test(address)){
        const url=new URL(address);
        if(url.hostname==='i.pinimg.com'&&/^\/\d+x(?:\d+)?(?:_[a-z]+)?\//i.test(url.pathname)){
          const original=new URL(address);original.pathname=original.pathname.replace(/^\/[^/]+\//,'/originals/');candidates.push(original.href);
        }
      }
      candidates.push(address);
    });
    return {files,urls:Array.from(new Set(candidates)).slice(0,8),name};
  }
  async function dataImage(value,name){
    if(value.length>MAX_BYTES*4/3+8192)throw new Error('Ảnh phải có dung lượng không quá 20 MiB.');
    const match=value.match(/^data:(image\/[a-z0-9.+-]+)(;base64)?,([\s\S]*)$/i);
    if(!match)throw new Error('Dữ liệu ảnh kéo thả không hợp lệ.');
    let bytes;
    if(match[2]){const binary=atob(match[3]);bytes=new Uint8Array(binary.length);for(let i=0;i<binary.length;i++)bytes[i]=binary.charCodeAt(i);}
    else bytes=new TextEncoder().encode(decodeURIComponent(match[3]));
    const file=new Blob([bytes],{type:match[1]});
    await transfer(file,'drop-'+Date.now()+'-'+Math.random().toString(16).slice(2),name||'ảnh-trên-web',false);
  }
  async function processDrop(payload){
    const images=payload.files.filter(file=>file.size>0&&(/^image\//i.test(file.type)||extensions.test(file.name)||(!file.type&&!/\.(url|webloc|html?|txt|pdf)$/i.test(file.name))));
    if(images.length){
      for(const file of images){
        const token='drop-'+Date.now()+'-'+Math.random().toString(16).slice(2);
        try{await transfer(file,token,file.name,false);}catch(error){try{call('dropCancel',token);}catch(_){}notify(error.message);}
      }
    }else if(payload.urls.length){
      const embedded=payload.urls.find(url=>/^data:image\//i.test(url));
      if(embedded)await dataImage(embedded,payload.name);
      else call('dropUrl',JSON.stringify(payload.urls),payload.name);
    }else notify(payload.files.length?'File ảnh rỗng hoặc định dạng được thả vào không phải ảnh.':'Hãy kéo trực tiếp ảnh, link ảnh hoặc file ảnh vào bảng này.');
  }
  function decodeImage(data){
    const image=new Image();let finished=false,canvas=null;
    const release=()=>{image.onload=image.onerror=null;image.src='';if(canvas)canvas.width=canvas.height=0;};
    const fail=error=>{if(finished)return;finished=true;clearTimeout(timer);release();try{call('convertedError',data.token,error);}catch(_){};};
    const timer=setTimeout(()=>fail('Quá thời gian giải mã ảnh.'),45000);
    image.onerror=()=>fail('Trình duyệt không giải mã được ảnh.');
    image.onload=()=>{
      try{
        if(!image.naturalWidth||!image.naturalHeight)throw new Error('Ảnh có kích thước không hợp lệ.');
        if(image.naturalWidth*image.naturalHeight>MAX_PIXELS)throw new Error('Ảnh vượt giới hạn 32 triệu pixel.');
        canvas=document.createElement('canvas');canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;
        const context=canvas.getContext('2d');if(!context)throw new Error('Không tạo được bộ chuyển đổi ảnh.');
        context.drawImage(image,0,0);
        canvas.toBlob(async blob=>{
          if(finished)return;
          if(!blob){fail('Không chuyển được ảnh sang PNG.');return;}
          finished=true;clearTimeout(timer);release();
          try{await transfer(blob,data.token,data.name,true);}catch(error){try{call('convertedError',data.token,error.message);}catch(_){};}
        },'image/png');
      }catch(error){fail(error.message);}
    };
    image.src='data:'+data.mime+';base64,'+data.base64;
  }
  function importStatus(busy,text){const element=document.getElementById('importStatus');element.textContent=text||'';element.classList.toggle('hidden',!busy);document.body.classList.toggle('importing',!!busy);}
  function init(message){
    notify=message;const root=document.body;
    root.addEventListener('dragenter',event=>{event.preventDefault();dragDepth++;root.classList.add('drop-target');});
    root.addEventListener('dragover',event=>{event.preventDefault();if(event.dataTransfer)event.dataTransfer.dropEffect='copy';});
    root.addEventListener('dragleave',()=>{dragDepth=Math.max(0,dragDepth-1);if(!dragDepth)root.classList.remove('drop-target');});
    root.addEventListener('drop',event=>{event.preventDefault();dragDepth=0;root.classList.remove('drop-target');let payload;try{payload=collectDrop(event.dataTransfer);}catch(error){notify(error.message);return;}serial=serial.then(()=>processDrop(payload)).catch(error=>notify(error.message));});
    window.addEventListener('beforeunload',()=>{pending.forEach(item=>{clearTimeout(item.timer);item.reject(new Error('Bảng quản lý đã đóng.'));});pending.clear();});
  }
  window.VGDReferenceImport={init,ack,decodeImage,importStatus};
})();
