// One-time migration from the retained beta.1 UI; preserves field IDs and callbacks.
const fs=require('fs');
const {JSDOM}=require('./dependencies.cjs').load('jsdom');
const dom=new JSDOM(fs.readFileSync('cabinet_dev/ui_beta1.html','utf8'));
const d=dom.window.document;
const q=s=>d.querySelector(s);
const el=(tag,attrs={},html='')=>{const e=d.createElement(tag);for(const [k,v]of Object.entries(attrs))e.setAttribute(k,v);e.innerHTML=html;return e};
const originals=Object.fromEntries([...d.querySelectorAll('[id]')].map(e=>[e.id,e]));
const get=id=>originals[id]||d.getElementById(id);
const field=id=>get(id).closest('.form-group,.checkbox-row');
const section=(title)=>el('section',{class:'settings-section'},'<h3>'+title+'</h3>');
const details=(title,id)=>el('details',{class:'advanced',...(id?{id}:{})},'<summary>'+title+'</summary>');
const scripts=[...d.querySelectorAll('script')];
d.body.classList.add('dark');d.documentElement.style.colorScheme='dark';
const header=q('.header');
const brandMark='<svg class="brand-mark" viewBox="0 0 180 180" aria-hidden="true"><rect x="3" y="3" width="174" height="174" rx="25" fill="var(--vgd-brand-tile)" stroke="var(--vgd-border)" stroke-width="1.5"/><path d="M90 18 27 54 90 89Z" fill="var(--vgd-brand-right)"/><path d="M90 18 153 54 90 89Z" fill="var(--vgd-brand-roof)"/><path d="M27 54 90 89V162L27 126Z" fill="var(--vgd-brand-left)"/><path d="M90 89 153 54V101C153 129 126 149 90 162Z" fill="var(--vgd-brand-right)"/><path d="M53 99 90 120V162L53 141Z" fill="var(--vgd-brand-shadow)"/><path d="M53 131 90 152V162L53 141Z" fill="var(--vgd-brand-roof)"/><path d="M90 18 27 54V126L90 162C126 149 153 129 153 101V54Z" fill="none" stroke="var(--vgd-brand-outline)" stroke-width="1.5" stroke-linejoin="round"/><path d="M90 18V89L153 54M27 54 90 89V162M53 99V141L90 162M53 99 90 120V152" fill="none" stroke="var(--vgd-brand-accent)" stroke-width="1.5" stroke-linejoin="round"/><path d="M27 54 90 18 153 54 90 89Z" fill="none" stroke="var(--vgd-brand-accent)" stroke-width="1.5" stroke-linejoin="round"/></svg>';
header.querySelector('.header-left').innerHTML=brandMark+'<span class="brand-copy"><strong class="brand-wordmark">VGD</strong><span class="brand-product">CABINET</span><small class="brand-version">4.5.0 · Beta 2</small></span>';
const themeButton=q('#btn_theme');themeButton.title='Chuyển sang giao diện sáng';themeButton.setAttribute('aria-label',themeButton.title);themeButton.innerHTML='<span id="theme_icon"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.93 4.93l1.42 1.42m11.3 11.3 1.42 1.42M2 12h2m16 0h2M4.93 19.07l1.42-1.42m11.3-11.3 1.42-1.42"/></svg></span>';
const preset=q('.preset-section');const save=details('Lưu / xóa mẫu tủ');save.querySelector('summary').textContent='Lưu / xóa mẫu tủ';save.append(q('.preset-row'));preset.append(save);
save.querySelector('summary').textContent='Lưu / đổi tên / xóa mẫu tủ';
get('preset_name').placeholder='Tên mẫu mới / tên mới';
const dim=q('#card_dim .card-body');
const frame=[...d.querySelectorAll('#card_frame .subsection')];
const bevel=q('.card:not([id]) .card-body');
const doors=q('#card_doors .card-body');
const drawers=q('#card_drawers .card-body');
const over=q('#card_overheight .card-body');
const status=q('#model_status');status.removeAttribute('style');
const live=field('live_update');live.removeAttribute('style');live.querySelector('label').textContent='Tự cập nhật khi sửa thông số';
const update=q('#btn_update');update.textContent='Cập nhật';
const draw=q('[onclick="drawToolCabinet()"]');draw.textContent='Vẽ 3 điểm';
const place=q('[onclick="placeCabinet()"]');place.removeAttribute('style');place.textContent='Đặt tủ mới';place.id='btn_place';
d.body.replaceChildren(header);
const context=el('div',{class:'context-bar'},'<span id="selection_mode">Tạo tủ mới</span><span id="size_summary"></span>');d.body.append(context);
d.body.append(el('div',{id:'description_draft_notice',hidden:'',role:'status'}));
const workspace=el('div',{class:'workspace'}),nav=el('nav',{class:'side-menu','aria-label':'Nhóm thông số'}),content=el('main',{id:'settings_content'});
workspace.append(nav,content);d.body.append(workspace);
const panels={};
const paths={general:'M4 6h16M4 12h16M4 18h16M8 4v4m8 0V4m-8 10v4m8-4v4',frame:'M5 3.5h14v17H5zM5 8h14M5 16h14',compartments:'M5 3.5h14v17H5zM12 3.5v17',doors:'M5 3.5h14v17H5zM12 3.5v17M9 11v2m6-2v2',drawers:'M5 3.5h14v17H5zM5 9h14M5 14.5h14M9 6v1m6-1v1m-6 5.5v1m6-1v1m-6 5.5v1m6-1v1',description:'M7 3.5h8l4 4v13H5v-17h2m7 0v4h4M8 12h8M8 16h5',library:'M3.5 6h6l2 2h9v11h-17zM3.5 10h17'};
const navIcon=name=>'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="'+paths[name]+'"/></svg>';
[['general','Tổng thể'],['frame','Thùng tủ'],['compartments','Chia khoang'],['doors','Cánh tủ'],['drawers','Ngăn kéo']].forEach(([id,title],i)=>{
 const b=el('button',{type:'button',class:'menu-button','data-page':id,'aria-controls':'page_'+id,onclick:"selectPage('"+id+"')"},navIcon(id)+'<span>'+title+'</span>');nav.append(b);
 const p=el('section',{id:'page_'+id,class:'menu-page',hidden:''},'<h2>'+title+'</h2>');panels[id]=p;content.append(p);
});
nav.append(el('div',{class:'menu-note'},'DỰNG HÌNH<br><span>Đơn vị: mm</span>'));
nav.insertBefore(el('button',{type:'button',class:'menu-button','data-page':'description','aria-controls':'page_description',onclick:"selectPage('description')"},navIcon('description')+'<span>Dựng từ mô tả</span>'),nav.lastChild);
const description=el('section',{id:'page_description',class:'menu-page',hidden:''},`<h2>Dựng từ mô tả</h2>
<p>Gửi ảnh và rộng × sâu × cao mong muốn cho ChatGPT cùng hướng dẫn bên dưới. Dán khối JSON trả về, không dán phần giải thích. Không cần API key.</p>
<p>Beta 2 dùng cấu tạo hiện có. Các module dùng chung thiết lập cánh, đợt và hộc; chưa hỗ trợ mỗi module một cấu tạo khác nhau.</p>
<div class="description-actions"><button type="button" class="btn-secondary" onclick="showDescriptionPrompt()">Hướng dẫn cho ChatGPT</button><button type="button" class="btn-secondary" onclick="insertDescriptionExample()">Nạp ví dụ</button></div>
<details id="description_prompt_box" class="advanced"><summary>Hướng dẫn · chọn toàn bộ và copy</summary><textarea id="description_prompt" readonly aria-label="Hướng dẫn cho ChatGPT"></textarea></details>
<label for="description_text">Khối cấu hình JSON</label><textarea id="description_text" spellcheck="false" placeholder="Dán khối VGD_CABINET_DESCRIPTION…" oninput="invalidateDescriptionPreview()"></textarea>
<div class="description-actions"><button type="button" id="btn_description_check" onclick="checkDescription()">Kiểm tra</button><button type="button" id="btn_description_apply" onclick="applyDescription()" disabled>Áp dụng cho tủ mới</button><button type="button" id="btn_description_partial" onclick="applyDescription(true)" hidden disabled>Dựng phần được hỗ trợ</button></div>
<div id="description_review" role="status" aria-live="polite"></div>
<button type="button" id="btn_description_leave" class="btn-secondary" onclick="returnToSelectedCabinet()" hidden>Trở lại tủ đang chọn</button>
<p>Nhập chỉ đổi bản nháp. Không tự dựng, không cập nhật tủ đang chọn, không tự lưu mẫu. Kiểm tra các giá trị ước lượng trước khi bấm Đặt tủ mới.</p>`);
content.append(description);
nav.insertBefore(el('button',{type:'button',class:'menu-button','data-page':'library','aria-controls':'page_library',onclick:"selectPage('library')"},navIcon('library')+'<span>Thư viện</span>'),nav.lastChild);
content.append(el('section',{id:'page_library',class:'menu-page',hidden:''},`<h2>Thư viện tủ</h2>
<p>Lưu tủ đang chọn, gồm cả các chi tiết đã sửa thủ công. Mẫu được giữ trên máy để chọn và đặt lại sau.</p>
<section class="settings-section"><h3>Lưu tủ đang chọn</h3>
<label for="library_name">Tên mẫu tủ</label><input type="text" id="library_name" data-library-control maxlength="80" placeholder="Ví dụ: Tủ áo phòng ngủ">
<div class="description-actions"><button type="button" id="btn_library_save" onclick="saveLibrary(false)" disabled>Lưu mẫu mới</button><button type="button" id="btn_library_replace" class="btn-secondary" onclick="saveLibrary(true)" disabled>Cập nhật mẫu đã chọn</button></div></section>
<label for="library_search">Tìm mẫu</label><input type="search" id="library_search" data-library-control placeholder="Nhập tên mẫu" oninput="renderLibrary()">
<div id="library_list" class="library-list" aria-label="Các mẫu tủ"></div><p id="library_empty" role="status">Chưa có mẫu. Chọn một tủ trong model rồi lưu mẫu mới.</p>
<section id="library_detail" class="settings-section" hidden><h3 id="library_title"></h3><img id="library_thumbnail" alt="Hình mẫu tủ đã lưu" hidden><p id="library_dimensions"></p>
<button type="button" onclick="placeLibrary()">Đặt tủ từ Thư viện</button>
<div class="description-actions"><button type="button" class="btn-secondary" onclick="renameLibrary()">Đổi tên theo ô nhập</button><button type="button" class="btn-secondary" onclick="deleteLibrary()">Xóa khỏi danh sách</button></div></section>
<button type="button" class="btn-secondary" onclick="refreshLibrary()">Nạp lại danh sách</button>`));
const tabs=(parent,group,items)=>{const bar=el('div',{class:'subnav','aria-label':'Mục '+group});parent.append(bar);const out={};items.forEach(([id,title],i)=>{bar.append(el('button',{type:'button','data-subgroup':group,'data-subtab':id,onclick:"selectSubpage('"+group+"','"+id+"')",'aria-controls':'sub_'+group+'_'+id},title));const p=el('div',{id:'sub_'+group+'_'+id,'data-subpanel':group,hidden:''});parent.append(p);out[id]=p});return out};
panels.general.append(preset);
const dimensions=section('Kích thước phủ bì');dimensions.append(dim);panels.general.append(dimensions);
const snap=field('snap_step');snap.remove();
const modules=section('Ghép module');['module_mode','module_widths','module_target_w'].forEach(id=>modules.append(field(id)));const moduleHint=frame[4].querySelector('p');moduleHint.id='module_hint';modules.append(moduleHint);panels.general.append(modules);
const genAdv=details('Nâng cao · bước bắt khi vẽ');genAdv.append(snap);panels.general.append(genAdv);
panels.general.append(el('p',{class:'hint'},'W/D/H gồm cánh và hậu; chiều cao gồm chân và nẹp.'));
const f=tabs(panels.frame,'frame',[['sides','Hông'],['caps','Nóc–đáy'],['back','Hậu'],['base','Chân']]);
f.sides.append(frame[0]);f.caps.append(frame[2]);f.back.append(frame[1]);f.base.append(frame[3]);
f.back.append(el('div',{class:'checkbox-row'},'<input type="checkbox" id="back_groove_auto" checked><label for="back_groove_auto">Ngậm hậu = ½ dày hồi</label>'));
f.back.append(el('div',{class:'form-group'},'<label for="back_groove_depth">Ngậm hậu mỗi bên (mm)</label><input type="number" id="back_groove_depth" value="8.75" min="0" step="0.5">'));
const c=tabs(panels.compartments,'compartments',[['dividers','Vách đứng'],['shelves','Đợt ngang'],['tiers','Chia tầng']]);
['div_count','div_pos','auto_divider_wide','max_compartment_w'].forEach(id=>c.dividers.append(field(id)));
['shelf_count','shelf_type','shelf_side_clearance','shelf_front_setback'].forEach(id=>c.shelves.append(field(id)));c.tiers.append(over);
c.dividers.append(el('p',{class:'hint'},'Vách và đợt áp dụng trong từng module.'));
const dt=tabs(panels.doors,'doors',[['front','Cấu tạo cánh'],['glass','Khung/kính'],['pano','Pano / Shaker'],['division','Chia khung'],['handle','Móc tay / xà chặn']]);dt.front.append(doors);dt.handle.append(bevel);
const doorFields=el('div',{id:'door_fields'});[...doors.children].slice(1).forEach(x=>doorFields.append(x));doors.append(doorFields);
doorFields.prepend(el('div',{class:'form-group'},'<label for="door_style">Kiểu dựng</label><select id="door_style" onchange="refreshContextUI();if(this.value===\'Kính khung kim loại\')selectSubpage(\'doors\',\'glass\');if(this.value===\'Pano khung gỗ\'||this.value===\'Shaker\')selectSubpage(\'doors\',\'pano\')"><option>Ván phẳng</option><option>Kính khung kim loại</option><option>Pano khung gỗ</option><option>Shaker</option></select>'));
dt.division.append(el('div',{class:'form-group'},'<label for="frame_division">Kiểu chia khung</label><select id="frame_division" onchange="document.getElementById(\'pano_panel_count\').value=1;refreshContextUI()"><option>Không chia</option><option>Ngang</option><option>Dọc</option><option>Chéo X</option></select>'));
dt.division.append(el('div',{class:'frame-patterns'},[['Không chia',''],['Ngang','M4 12h16'],['Dọc','M12 4v16'],['Chéo X','M4 4l16 16 M20 4L4 20']].map(([name,path])=>'<button type="button" class="btn-secondary" onclick="chooseFrameDivision(\''+name+'\')" aria-label="'+name+'"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 4h16v16H4z '+path+'"/></svg><span>'+name+'</span></button>').join('')));
dt.division.append(el('div',{class:'form-group'},'<label for="frame_sections">Số ô chia đều</label><input type="number" id="frame_sections" min="2" max="6" step="1" value="2">'));
dt.division.append(el('div',{class:'form-group'},'<label for="frame_bar_width">Bản thanh chia (0 = theo khung)</label><input type="number" id="frame_bar_width" min="0" step="0.5" value="0">'));
dt.division.append(el('p',{class:'hint'},'Ngang/dọc chia đều 2–6 ô. Chéo X: cánh kính chia ô kính; pano/Shaker dùng thanh đắp chéo trên tấm lõm, giao nhau không chồng khối.'));
[['pano_stile_width','Bản đố đứng',60],['pano_rail_width','Bản thanh trên/dưới',60],['pano_depth','Dày khung cánh',20],['pano_panel_thickness','Dày tấm pano',6],['pano_groove_depth','Sâu rãnh ngậm',8],['pano_clearance','Khe co giãn mỗi cạnh',1],['pano_mid_rail','Bản thanh chia giữa',60]].forEach(([id,label,n])=>dt.pano.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+' (mm)</label><input id="'+id+'" type="number" value="'+n+'" min="0" step="0.5">')));
dt.pano.append(el('div',{class:'form-group'},'<label for="pano_panel_count">Số ô pano theo chiều cao</label><input id="pano_panel_count" type="number" value="1" min="1" max="6" step="1">'));
dt.pano.append(el('div',{class:'form-group'},'<label for="shaker_recess">Độ lõm mặt tấm Shaker (mm)</label><input id="shaker_recess" type="number" value="6" min="1" step="0.5">'));
dt.pano.append(el('p',{class:'hint'},'Khung gỗ và pano phẳng riêng; tấm giữa ngậm rãnh và chừa khe co giãn. Mặc định khung 60 × 20, pano 6, ngậm 8, khe 1 mm/cạnh. Chỉnh theo vật liệu; chưa dựng mộng góc hoặc profile soi trang trí.'));
dt.glass.append(el('p',{class:'hint'},'Cánh kính khung kim loại. Khung 4 cạnh và kính giữa chiều dày; dùng chung khe cánh.'));
[['metal_frame_width','Bản khung',20],['metal_frame_depth','Dày khung',20],['glass_thickness','Dày kính',5]].forEach(([id,label,n])=>dt.glass.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+' (mm)</label><input type="number" id="'+id+'" value="'+n+'" min="1" step="0.5">')));
dt.glass.append(el('div',{class:'preset-row'},[20,30,40].map(n=>'<button type="button" class="btn-secondary" onclick="document.getElementById(\'metal_frame_width\').value='+n+';debouncedUpdateCabinet()">Bản '+n+'</button>').join('')));
[['metal_finish','Màu khung',['Đen','Champagne','Inox']],['glass_finish','Màu kính',['Trong','Trà','Xám']]].forEach(([id,label,options])=>dt.glass.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+'</label><select id="'+id+'">'+options.map(v=>'<option>'+v+'</option>').join('')+'</select>')));
dt.glass.append(el('p',{class:'hint'},'Áp dụng cho các cánh mở của tủ đang chỉnh. Màu khung và kính là hai material riêng trong SketchUp.'));
dt.handle.append(el('p',{class:'hint'},'Vát mép chỉ dùng cho cánh ván và mặt ngăn kéo; không áp dụng cho cánh kính khung kim loại.'));
// A commonly used top gap stays available without opening four separate edge gaps.
const topGap=el('div',{class:'form-group',id:'simple_top_gap'},'<label for="door_top_gap">Khe trên / móc tay</label>');
const topInput=get('door_top_gap');topInput.type='number';topInput.step='0.5';topInput.setAttribute('oninput',"document.getElementById('door_gap_top').value=this.value");topGap.append(topInput);get('door_gap_simple_ui').append(topGap);
dt.handle.append(el('p',{class:'hint'},'Móc tay và xà chặn ở đây chỉ áp cho cánh tủ. Ngăn kéo có thông số độc lập trong Mặt hộc.'));
get('front_bevel').closest('.checkbox-row').querySelector('label').textContent='Móc tay cánh · vát 45° mép trên';
get('bevel_lip').closest('.form-group').querySelector('label').textContent='Mép giữ lại cánh (mm)';
bevel.querySelectorAll('p').forEach(e=>e.textContent='Móc tay cánh tủ độc lập với mặt ngăn kéo.');
panels.drawers.append(drawers);
const drawerFields=el('div',{id:'drawer_fields'});[...drawers.children].slice(2).forEach(x=>drawerFields.append(x));drawers.append(drawerFields);
const existingDrawerFields=[...drawerFields.children];
const dr=tabs(drawerFields,'drawers',[['layout','Bố trí'],['frame','Khung két'],['front','Mặt hộc'],['box','Thùng hộc']]);
existingDrawerFields.forEach(x=>dr.layout.append(x));
dr.layout.prepend(el('div',{class:'form-group'},'<label for="drawer_columns">Cụm trong mỗi khoang</label><select id="drawer_columns"><option value="1">1 cụm</option><option value="2">2 cụm cạnh nhau</option></select>'));
get('drawer_count').closest('.form-group').querySelector('label').textContent='Số tầng mỗi cụm';
['group_drawer_inner_offset','group_drawer_hinge_sp','drawer_hinge_sp_hint'].forEach(id=>dr.frame.append(get(id)));
[['drawer_frame_depth','Sâu két phủ bì (0 = tự động)',0],['drawer_frame_rail_width','Bản xà đáy trước/sau',50]].forEach(([id,label,n])=>dr.frame.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+'</label><input type="number" id="'+id+'" value="'+n+'" min="0" step="0.5">')));
dr.frame.append(el('div',{class:'checkbox-row'},'<input type="checkbox" id="drawer_frame_stop_rail" checked><label for="drawer_frame_stop_rail">Xà đón mặt hộc</label>'));
[['drawer_frame_stop_rail_h','Cao xà đón',50],['drawer_frame_stop_rail_drop','Hạ xà so với dưới nóc',0]].forEach(([id,label,n])=>dr.frame.append(el('div',{class:'form-group'},'<label for="'+id+'">'+label+'</label><input type="number" id="'+id+'" value="'+n+'" min="0" step="0.5">')));
dr.box.append(el('div',{class:'form-group'},'<label for="drawer_bottom_mode">Kiểu đáy hộc</label><select id="drawer_bottom_mode"><option>Âm hai bên</option><option>Âm bốn phía</option><option>Phủ dưới</option></select>'));
dr.front.append(get('group_drawer_gap'));
const box=section('Kết cấu và khoảng hở');dr.box.append(box);
['drawer_ray_space','drawer_back_clearance','drawer_box_bottom_lift','drawer_box_top_clearance','drawer_bottom_offset','drawer_box_t','drawer_bottom_t'].forEach(id=>box.append(field(id)));
const rails=details('Xà che khe mặt ngăn kéo');rails.id='drawer_rail_details';['group_drawer_backing_rail','group_drawer_backing_rail_h','drawer_backing_hint'].forEach(id=>rails.append(get(id)));dr.front.append(rails);
dr.front.append(el('div',{class:'checkbox-row'},'<input type="checkbox" id="drawer_bevel"><label for="drawer_bevel">Móc tay mặt hộc · vát 45°</label>'));
dr.front.append(el('div',{class:'form-group'},'<label for="drawer_bevel_lip">Mép giữ lại mặt hộc (mm)</label><input type="number" id="drawer_bevel_lip" value="2" min="0.5" step="0.5">'));
rails.querySelector('summary').textContent='Xà chặn / che khe mặt hộc';
const footer=el('footer',{class:'fixed-actions'});footer.append(status,live);const actions=el('div',{class:'action-bar'});actions.append(place,draw,update);footer.append(actions);d.body.append(footer);
// Associate every existing text label with its original input for easier clicking.
d.querySelectorAll('.form-group').forEach(g=>{const l=g.querySelector('label'),i=g.querySelector('input,select');if(l&&i&&!l.htmlFor)l.htmlFor=i.id});
d.querySelectorAll('.sub-title').forEach(e=>e.remove());
d.querySelectorAll('.card-body').forEach(e=>e.classList.remove('card-body'));
d.body.append(...scripts);
const css=fs.readFileSync('cabinet_dev/menu.css','utf8');d.head.append(el('style',{},css));
const js=fs.readFileSync('cabinet_dev/menu.js','utf8');scripts[0].textContent=js+'\n'+scripts[0].textContent;
let html=dom.serialize();
const values={shadow_gap_h:20,door_gap:0,door_top_gap:0,door_gap_outer:0,door_gap_left:0,door_gap_right:0,door_gap_top:0,door_gap_bottom:0,door_gap_between:0,drawer_gap:25,drawer_gap_outer:0,drawer_gap_left:0,drawer_gap_right:0,drawer_gap_top:0,drawer_gap_bottom:0,drawer_gap_between:25};
for(const [id,value]of Object.entries(values)){
  // Both startup overrides and fallback values must agree with Ruby defaults.
  html=html.replace(new RegExp('(defaultParams\\.'+id+' = )[0-9.]+;','g'),'$1'+value+';');
  html=html.replace(new RegExp("(getNumValue\\('"+id+"',\\s*)[0-9.]+(\\))",'g'),'$1'+value+'$2');
  html=html.replace(new RegExp('(id="'+id+'"[^>]*value=")[0-9.]+','g'),'$1'+value);
}
html=html.replace('VGD_Cabinet UI v4.3.0 beta','VGD Cabinet 4.5.0-beta.3');
html=html.replace("document.getElementById('btn_update').disabled = !selectedPid;","document.getElementById('btn_update').disabled = !selectedPid;\n      document.getElementById('selection_mode').textContent = selectedPid ? 'Đang sửa tủ đã chọn' : 'Tạo tủ mới';\n      refreshContextUI();");
html=html.replace('        renderDrawerGapUI();\n      } finally', '        renderDrawerGapUI();\n        refreshContextUI();\n      } finally');
html=html.replace("      initTheme();", "      initMenu();\n      initTheme();");
html=html.replaceAll('-- Chọn Preset --','-- Chọn mẫu tủ --');
html=html.replace('        back_mode:', `        door_style: document.getElementById('door_style').value,
        handle_split_v1: true,
        drawer_bevel: document.getElementById('drawer_bevel').checked,
        drawer_bevel_lip: getNumValue('drawer_bevel_lip',2),
        frame_division: document.getElementById('frame_division').value,
        frame_sections: getNumValue('frame_sections',2),
        frame_bar_width: getNumValue('frame_bar_width',0),
        shaker_recess: getNumValue('shaker_recess',6),
        ${['pano_stile_width','pano_rail_width','pano_depth','pano_panel_thickness','pano_groove_depth','pano_clearance','pano_panel_count','pano_mid_rail'].map(id=>id+': getNumValue(\''+id+'\','+(id==='pano_depth'?20:id==='pano_panel_thickness'?6:id==='pano_groove_depth'?8:id==='pano_clearance'||id==='pano_panel_count'?1:60)+'),').join('\n        ')}
        metal_frame_width: getNumValue('metal_frame_width',20),
        metal_frame_depth: getNumValue('metal_frame_depth',20),
        glass_thickness: getNumValue('glass_thickness',5),
        metal_finish: document.getElementById('metal_finish').value,
        glass_finish: document.getElementById('glass_finish').value,
        back_mode:`);
html=html.replace('        back_mode:', `        back_groove_auto: document.getElementById('back_groove_auto').checked,
        back_groove_depth: getNumValue('back_groove_depth',8.75),
        drawer_columns: getNumValue('drawer_columns',1),
        drawer_frame_depth: getNumValue('drawer_frame_depth',0),
        drawer_frame_rail_width: getNumValue('drawer_frame_rail_width',50),
        drawer_frame_stop_rail: document.getElementById('drawer_frame_stop_rail').checked,
        drawer_frame_stop_rail_h: getNumValue('drawer_frame_stop_rail_h',50),
        drawer_frame_stop_rail_drop: getNumValue('drawer_frame_stop_rail_drop',0),
        drawer_bottom_mode: document.getElementById('drawer_bottom_mode').value,
        back_mode:`);
// Explicit preset actions never silently overwrite another name.
html=html.replace(/function savePreset\(\) \{[\s\S]*?\n    function deletePreset\(\)/,`function savePreset(action) {
      action=action||'create';
      var source=document.getElementById('preset_select').value;
      var name=action==='update'?source:document.getElementById('preset_name').value.trim();
      if(!name || (action!=='create'&&!source)){showModelStatus('Nhập tên hoặc chọn mẫu cần sửa.',true);return;}
      if(window.sketchup) window.sketchup.save_preset({action:action,name:name,source_name:source||null,params:getFormData()});
    }

    function deletePreset()`);
html=html.replace('>LƯU</button>','>Tạo mới</button>');
html=html.replace('onclick="deletePreset()"','onclick="deletePreset()"');
const actionButtons='<button type="button" class="btn-secondary" onclick="savePreset(\'update\')">Cập nhật mẫu đã chọn</button><button type="button" class="btn-secondary" onclick="savePreset(\'rename\')">Đổi tên mẫu</button>';
html=html.replace('onclick="deletePreset()"', 'onclick="deletePreset()"');
html=html.replace(/(<button[^>]*onclick="deletePreset\(\)"[^>]*>)/,actionButtons+'$1');
html=html.replace("if (name && currentPresets[name])", "if (name && Object.prototype.hasOwnProperty.call(currentPresets,name))");
html=html.replace('      if (!params) return;',`      if (!params) return;
      if (descriptionDraftParams && params.__target_pid != null) return;
      if (!params.handle_split_v1) {
        params=Object.assign({},params,{handle_split_v1:true,drawer_bevel:params.front_bevel||false,drawer_bevel_lip:params.bevel_lip===undefined?2:params.bevel_lip});
      }`);
// Preserve imported fields without editable controls (e.g. shelf_depth_clearance).
html=html.replaceAll("t.id !== 'preset_name' && t.id !== 'preset_select'", "t.id !== 'preset_name' && t.id !== 'preset_select' && !t.closest('#page_library')");
html=html.replaceAll("t.id !== 'preset_name')", "t.id !== 'preset_name' && !t.closest('#page_library'))");
html=html.replace('</script>', `
var baseGetFormData=getFormData;
getFormData=function(){
  var data=baseGetFormData();
  if(descriptionDraftParams)Object.keys(descriptionDraftParams).forEach(function(k){
    if(!document.getElementById(k))data[k]=descriptionDraftParams[k];
  });
  return data;
};
</script>`);
function replaceFunction(name,source){
  const pattern=new RegExp('function '+name+'\\([^)]*\\) \\{[\\s\\S]*?\\n    \\}');
  const next=html.replace(pattern,()=>source);
  if(next===html)throw new Error('Could not replace '+name+' in Cabinet UI source');
  html=next;
}
replaceFunction('initTheme',`function initTheme() {
      var theme='dark';
      try {
        var saved=localStorage.getItem('vgd_cabinet_theme');
        if(saved==='dark'||saved==='light')theme=saved;
        else {
          var legacy=localStorage.getItem('vgd_theme');
          if(legacy==='dark'||legacy==='light') {
            theme=legacy;
            localStorage.setItem('vgd_cabinet_theme',theme);
          }
        }
      } catch(e) {}
      applyTheme(theme);
    }`);
replaceFunction('toggleTheme',`function toggleTheme() {
      var nextTheme=document.body.classList.contains('dark')?'light':'dark';
      applyTheme(nextTheme);
      try { localStorage.setItem('vgd_cabinet_theme',nextTheme); } catch(e) {}
    }`);
replaceFunction('applyTheme',`function applyTheme(theme) {
      theme=theme==='light'?'light':'dark';
      document.body.classList.toggle('dark',theme==='dark');
      document.documentElement.style.colorScheme=theme;
      setThemeButton(theme);
    }`);
html=html.replace("el.style.color = error ? '#c33434' : '';","el.style.color = error ? 'var(--vgd-danger)' : '';");
fs.writeFileSync('cabinet_work/VGD_Cabinet/VGD_Cabinet_UI.html',html.replace(/[ \t]+$/gm,''));
console.log('UI migrated; original control count:',new JSDOM(fs.readFileSync('cabinet_dev/ui_beta1.html','utf8')).window.document.querySelectorAll('input,select').length,'new:',d.querySelectorAll('input,select').length);
