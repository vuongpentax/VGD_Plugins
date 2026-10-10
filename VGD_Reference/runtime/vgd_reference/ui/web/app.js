(function(){
  const byId=id=>document.getElementById(id);
  const state={items:[],selected_id:null,hidden_all:false,opacity_min:10,toolbar_theme:'light',rangeTimer:null};
  const call=(name,...args)=>{if(window.sketchup&&typeof window.sketchup[name]==='function')window.sketchup[name](...args);};
  const icons={
    visible:'<path d="M3 12s3-6 9-6 9 6 9 6-3 6-9 6-9-6-9-6Z"/><circle cx="12" cy="12" r="2.5"/>',
    hidden:'<path d="M4 10c2 4 4 6 8 6s6-2 8-6M6.5 14.5 5 16.5M12 16v2M17.5 14.5l1.5 2"/>',
    locked:'<rect x="5" y="10" width="14" height="10" rx="1.4"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v2"/>',
    unlocked:'<rect x="5" y="10" width="14" height="10" rx="1.4"/><path d="M8 10V7a4 4 0 0 1 8 0M12 14v2"/>',
    delete:'<path d="M4.5 6.5h15M9 6.5v-3h6v3M6.5 9.5l.8 10h9.4l.8-10M10 10.5V17M14 10.5V17"/>'
  };
  function button(icon,title,action,extra){const el=document.createElement('button');el.type='button';el.innerHTML='<svg class="ui-icon" viewBox="0 0 24 24" aria-hidden="true">'+icons[icon]+'</svg>';el.title=title;el.setAttribute('aria-label',title);if(extra)el.className=extra;el.addEventListener('click',event=>{event.stopPropagation();action();});return el;}
  function render(data){
    Object.assign(state,data||{});const list=byId('items');list.replaceChildren();
    if(!state.items||!state.items.length){const empty=document.createElement('div');empty.className='empty';empty.textContent='Chưa có ảnh tham chiếu nào';list.appendChild(empty);}
    else state.items.forEach(item=>{
      const row=document.createElement('section');row.className='item'+(item.selected?' selected':'');row.addEventListener('click',()=>call('selectReference',item.id));
      const img=document.createElement('img');img.className='thumb';img.alt='';img.src=item.thumbnail;row.appendChild(img);
      const info=document.createElement('div');info.className='item-info';const name=document.createElement('div');name.className='item-name';name.textContent=item.name;const dims=document.createElement('div');dims.className='item-dim';dims.textContent=item.width+' × '+item.height+' px'+(item.locked?' · Đã khóa':'');info.append(name,dims);row.appendChild(info);
      const tools=document.createElement('div');tools.className='tools';
      const visibility=button(item.visible?'visible':'hidden',item.visible?'Ẩn ảnh':'Hiện ảnh',()=>call('toggleVisible',item.id));visibility.setAttribute('aria-pressed',String(item.visible));tools.appendChild(visibility);
      const lock=button(item.locked?'locked':'unlocked',item.locked?'Mở khóa ảnh':'Khóa ảnh',()=>call('toggleLock',item.id));lock.setAttribute('aria-pressed',String(item.locked));tools.appendChild(lock);
      tools.appendChild(button('delete','Xóa ảnh',()=>call('deleteReference',item.id),'delete'));
      row.appendChild(tools);list.appendChild(row);
    });
    const selected=state.items&&state.items.find(item=>item.id===state.selected_id);
    byId('selectedControls').classList.toggle('hidden',!selected);
    byId('emptyHint').classList.toggle('hidden',!!(state.items&&state.items.length));
    const hideLabel=state.hidden_all?'Hiện tất cả':'Ẩn tất cả';
    byId('hideAllLabel').textContent=hideLabel;
    byId('hideAllDescription').textContent=state.hidden_all?'Hiện lại trên khung nhìn':'Tạm ẩn trên khung nhìn';
    byId('hideAll').title=hideLabel+' ảnh tham chiếu';byId('hideAll').setAttribute('aria-label',hideLabel+' ảnh tham chiếu');byId('hideAll').setAttribute('aria-pressed',String(state.hidden_all));
    byId('hideAllGlyph').setAttribute('d',state.hidden_all?'M4 10c2 4 4 6 8 6s6-2 8-6M6.5 14.5 5 16.5M12 16v2M17.5 14.5l1.5 2':'M3 12s3-6 9-6 9 6 9 6-3 6-9 6-9-6-9-6ZM12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5');
    byId('toolbarTheme').value=state.toolbar_theme==='dark'?'dark':'light';
    if(selected){byId('selectedName').textContent=selected.name;byId('opacity').value=selected.opacity;byId('opacityValue').textContent=selected.opacity+'%';}
  }
  function message(text){const el=byId('message');el.textContent=text||'';el.classList.toggle('hidden',!text);if(text)setTimeout(()=>el.classList.add('hidden'),4500);}
  byId('add').addEventListener('click',()=>call('addImage'));
  byId('paste').addEventListener('click',()=>call('pasteImage'));
  function closeAppearance(){byId('appearancePanel').classList.add('hidden');byId('appearanceSettings').setAttribute('aria-expanded','false');}
  byId('appearanceSettings').addEventListener('click',()=>{const open=byId('appearancePanel').classList.toggle('hidden')===false;byId('appearanceSettings').setAttribute('aria-expanded',String(open));if(open)byId('toolbarTheme').focus();});
  byId('toolbarTheme').addEventListener('change',event=>call('setToolbarTheme',event.target.value));
  document.addEventListener('click',event=>{if(!byId('appearancePanel').contains(event.target)&&!byId('appearanceSettings').contains(event.target))closeAppearance();});
  document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!byId('appearancePanel').classList.contains('hidden')){closeAppearance();byId('appearanceSettings').focus();event.preventDefault();}});
  byId('hideAll').addEventListener('click',()=>call('hideAll'));
  byId('editSelected').addEventListener('click',()=>call('editSelected'));
  byId('crop').addEventListener('click',()=>call('startCrop',state.selected_id));
  byId('opacity').addEventListener('input',event=>{
    const selected=state.items&&state.items.find(item=>item.id===state.selected_id);if(!selected)return;
    const value=Number(event.target.value);byId('opacityValue').textContent=value+'%';call('opacityPreview',selected.id,value);
  });
  byId('opacity').addEventListener('change',event=>{
    const selected=state.items&&state.items.find(item=>item.id===state.selected_id);if(selected)call('commitOpacity',selected.id,Number(event.target.value));
  });
  window.VGDReference={render,message,ack:VGDReferenceImport.ack,decodeImage:VGDReferenceImport.decodeImage,importStatus:VGDReferenceImport.importStatus};
  VGDReferenceImport.init(message);
  call('ready');
})();
