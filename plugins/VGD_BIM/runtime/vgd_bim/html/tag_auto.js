'use strict';
// Tab Soạn tag: thanh gán tag cố định ở trên, ba tab nhỏ (Bộ tag / Tự động / Thư viện mẫu). Bộ tag gom theo nhóm gập được, có ô tìm và lọc nhóm.
// Thư viện tag mẫu (tick cụm rồi Nhập), gắn tag tự động theo từ khóa tên và xếp tag vào thư mục tag. Hai thẻ luật dùng chung một bộ vẽ:
// bảng luật "đích ← từ khóa", tùy chọn, xem trước, áp dụng, lưu mặc định, đặt lại, nhập / xuất file. Dùng các hàm chung của app.js ($, node, button, card, call...).
// Bộ luật đang sửa nằm ở đây và được gửi kèm mỗi lệnh; phía Ruby kiểm tra lại toàn bộ (TagRules / FolderRules .sanitize), nên giao diện không phải tin được.

// ---- Thư viện tag mẫu (18 cụm của Auto Tag): tick cụm rồi Nhập = thêm vào bộ tag của BIM và tạo sẵn trong model ----
const catalogState={selected:new Set()};
function catalogCard(data,parent){
  const clusters=data.catalog||[];
  if(!clusters.length)return;
  const c=card('Thư viện tag mẫu (Auto Tag)',parent);c.id='tag-catalog-card';
  c.append(node('p','Tick các cụm cần dùng rồi bấm Nhập: tag của cụm được thêm vào bộ tag của BIM và tạo sẵn trong model đang mở (chỉ tên tag, không đổi đối tượng nào). Bấm vào tên cụm để xem các tag trong cụm.','hint'));
  const list=node('div',undefined,'catalog-list');
  const english=typeof VGD_I18N!=='undefined'&&VGD_I18N.language==='en'; // nhãn tiếng Việt chỉ hiện khi giao diện tiếng Việt
  const importBtn=button('Nhập',()=>{call('tag_catalog_import',JSON.stringify({groups:[...catalogState.selected]}));},'primary');importBtn.id='tag-catalog-import';
  const paint=()=>{
    const picked=clusters.filter(x=>catalogState.selected.has(x.group)),tags=picked.reduce((n,x)=>n+x.count,0);
    importBtn.textContent=picked.length?`Nhập ${picked.length} cụm (${tags} tag)`:'Nhập';importBtn.disabled=!picked.length;
  };
  clusters.forEach(cluster=>{
    const row=node('div',undefined,'catalog-row');
    const box=node('input',undefined,'cb');box.type='checkbox';box.checked=catalogState.selected.has(cluster.group);box.setAttribute('aria-label',cluster.group);
    box.onchange=()=>{if(box.checked)catalogState.selected.add(cluster.group);else catalogState.selected.delete(cluster.group);paint();};
    const details=node('details');const summary=node('summary');
    summary.append(node('b',cluster.group),node('span',`${english||!cluster.label_vi?'':cluster.label_vi+' · '}${cluster.count} tag`,'muted'));
    details.append(summary,node('p',cluster.tags.join(', '),'muted'));
    row.append(box,details);list.append(row);
  });
  c.append(list);
  const actions=node('div',undefined,'actions');
  actions.append(button('Chọn tất cả',()=>{clusters.forEach(x=>catalogState.selected.add(x.group));list.querySelectorAll('input.cb').forEach(b=>{b.checked=true;});paint();}),
    button('Bỏ chọn',()=>{catalogState.selected.clear();list.querySelectorAll('input.cb').forEach(b=>{b.checked=false;});paint();}),importBtn);
  c.append(actions);
  paint();
}

// ---- Hai thẻ luật: 'tag' (gắn tag theo tên) và 'folder' (xếp tag vào thư mục) ----
const AUTO_BASED=[['both','Cả tên bản sao và tên component'],['instance','Tên bản sao'],['definition','Tên component']];
const AUTO_SCOPE=[['selection','Đối tượng đang chọn'],['model','Cả model']];
const RULE_KINDS={
  tag:{
    id:'tag-auto',title:'Gắn tag tự động theo tên',target:'tag',targetHeader:'Tên tag',wordsHeader:'Từ khóa trong tên',
    hint:'Mỗi luật là "tên tag ← từ khóa trong tên group / component" (nhiều từ khóa cách nhau dấu phẩy). Luật nằm trên thắng. Không phân biệt hoa thường và dấu tiếng Việt; từ khóa chỉ cần nằm trong tên (ví dụ "door" cũng khớp "Doorway"), nên hãy Xem trước rồi mới Áp dụng.',
    calls:{save:'tag_rules_save',reset:'tag_rules_reset',import:'tag_rules_import',export:'tag_rules_export',preview:'tag_auto_preview',apply:'tag_auto_apply'},
    options:{based:'both',scope:'selection',nested:false,overwrite:false},
    controls:[['select','Dựa theo',AUTO_BASED,'based'],['select','Phạm vi',AUTO_SCOPE,'scope'],
      ['toggle','Gắn cả group / component bên trong (đổi tag của mọi bản sao dùng chung định nghĩa)','nested'],['toggle','Ghi đè tag đã có (mặc định chỉ gắn đối tượng chưa có tag)','overwrite']],
    firstPlan:'Bấm Xem trước để biết sẽ gắn tag cho những đối tượng nào.',planIntro:'Sẽ gắn tag cho các đối tượng sau:',planNone:'Không có đối tượng nào cần gắn tag.',unit:'đối tượng',
    stats:[['Tổng đã xét','total'],['Sẽ gắn','assign'],['Đã đúng tag sẵn','same'],['Giữ nguyên (đã có tag khác)','kept'],['Không khớp luật nào','unmatched'],['Bị khóa','locked']]
  },
  folder:{
    id:'tag-folder',title:'Xếp tag vào thư mục (Auto Tag)',target:'folder',targetHeader:'Tên thư mục',wordsHeader:'Từ khóa trong tên tag',
    hint:'Mỗi luật là "tên thư mục ← từ khóa trong TÊN TAG" (nhiều từ khóa cách nhau dấu phẩy). Luật nằm trên thắng; tag không khớp luật nào giữ nguyên chỗ cũ. Tag được xếp vào thư mục tag của SketchUp (cần SketchUp 2021 trở lên), thư mục chưa có sẽ được tạo. Hãy Xem trước rồi mới Áp dụng.',
    calls:{save:'folder_rules_save',reset:'folder_rules_reset',import:'folder_rules_import',export:'folder_rules_export',preview:'folder_auto_preview',apply:'folder_auto_apply'},
    options:{overwrite:false},
    controls:[['toggle','Ghi đè thư mục đã có (mặc định chỉ xếp tag chưa nằm trong thư mục nào)','overwrite']],
    firstPlan:'Bấm Xem trước để biết sẽ xếp những tag nào vào thư mục nào.',planIntro:'Sẽ xếp các tag sau vào thư mục:',planNone:'Không có tag nào cần xếp vào thư mục.',unit:'tag',
    stats:[['Tổng tag đã xét','total'],['Sẽ xếp','assign'],['Đã đúng thư mục sẵn','same'],['Giữ nguyên (đã ở thư mục khác)','kept'],['Không khớp luật nào','unmatched']]
  }
};
const ruleState={tag:{rules:null,plan:null,planKey:'',pendingKey:'',open:false},folder:{rules:null,plan:null,planKey:'',pendingKey:'',open:false}};
for(const kind of Object.keys(RULE_KINDS))Object.assign(ruleState[kind],RULE_KINDS[kind].options);

function rulePayload(kind){
  const spec=RULE_KINDS[kind],state=ruleState[kind],payload={rules:state.rules.filter(r=>r[spec.target].trim()||r.keywords.trim()).map(r=>({[spec.target]:r[spec.target],keywords:r.keywords}))};
  if(kind==='tag')Object.assign(payload,{based_on:state.based,scope:state.scope,nested:state.nested,overwrite:state.overwrite});
  else payload.overwrite=state.overwrite;
  return payload;
}
const ruleKey=kind=>JSON.stringify(rulePayload(kind));
const copyRules=(kind,list)=>(list||[]).map(r=>({[RULE_KINDS[kind].target]:r[RULE_KINDS[kind].target],keywords:r.keywords}));

function ruleCard(kind,data,parent){
  const spec=RULE_KINDS[kind],state=ruleState[kind];
  if(!state.rules)state.rules=copyRules(kind,kind==='tag'?data.rules:data.folder_rules);
  const c=card(spec.title,parent);c.id=`${spec.id}-card`;
  renderRuleCard(kind,c);
}

function renderRuleCard(kind,c){
  const spec=RULE_KINDS[kind],state=ruleState[kind],id=spec.id;
  c.replaceChildren(node('h2',spec.title));
  // Bảng luật gập lại (mặc định): dùng hằng ngày chỉ cần tùy chọn + Xem trước + Áp dụng; bấm "Bảng luật" mới mở ra để sửa.
  const fold=node('details',undefined,'rule-fold');fold.open=state.open;fold.ontoggle=()=>{state.open=fold.open;};
  const summary=node('summary');summary.append(node('b','Bảng luật'),node('span',`${state.rules.length} luật`,'muted'));
  fold.append(summary,node('p',spec.hint,'hint'));c.append(fold);
  const wrap=node('div',undefined,'table-wrap auto-rules'),t=node('table'),head=node('thead'),htr=node('tr');
  ['#',spec.targetHeader,spec.wordsHeader,'Thao tác'].forEach(h=>htr.append(node('th',h)));head.append(htr);t.append(head);
  const tbody=node('tbody');
  state.rules.forEach((rule,index)=>{
    const tr=node('tr');
    const cell=child=>{const td=node('td');td.append(child);tr.append(td);};
    cell(node('span',String(index+1)));
    const target=node('input');target.type='text';target.value=rule[spec.target];target.maxLength=60;target.setAttribute('aria-label',spec.targetHeader);target.oninput=()=>{rule[spec.target]=target.value;paintRulePlan(kind);};
    const words=node('input');words.type='text';words.value=rule.keywords;words.maxLength=400;words.setAttribute('aria-label',spec.wordsHeader);words.oninput=()=>{rule.keywords=words.value;paintRulePlan(kind);};
    cell(target);cell(words);
    const ops=node('div',undefined,'actions');
    const move=(text,title,delta)=>{const b=button(text,()=>{const to=index+delta;if(to<0||to>=state.rules.length)return;[state.rules[index],state.rules[to]]=[state.rules[to],state.rules[index]];renderRuleCard(kind,c);});b.title=title;b.setAttribute('aria-label',title);return b;};
    ops.append(move('↑','Lên trên',-1),move('↓','Xuống dưới',1),button('Xóa',()=>{state.rules.splice(index,1);renderRuleCard(kind,c);}));
    cell(ops);tbody.append(tr);
  });
  t.append(tbody);wrap.append(t);fold.append(wrap);
  const rules=node('div',undefined,'actions');
  rules.append(button('Thêm luật',()=>{state.rules.push({[spec.target]:'',keywords:''});renderRuleCard(kind,c);const inputs=c.querySelectorAll('.auto-rules tbody tr:last-child input');if(inputs[0])inputs[0].focus();}),
    button('Lưu làm mặc định',()=>call(spec.calls.save,JSON.stringify({rules:rulePayload(kind).rules}))),
    button('Đặt lại',()=>call(spec.calls.reset)),
    button('Nhập file luật',()=>call(spec.calls.import)),
    button('Xuất file luật',()=>call(spec.calls.export,JSON.stringify({rules:rulePayload(kind).rules}))));
  fold.append(rules);
  // Tùy chọn của lần chạy
  const opts=node('div',undefined,'auto-opts');
  spec.controls.forEach(control=>{
    const l=node('label',undefined,'auto-opt');
    if(control[0]==='select'){
      const s=node('select');s.setAttribute('aria-label',control[1]);control[2].forEach(([v,text])=>s.append(new Option(text,v)));s.value=state[control[3]];s.onchange=()=>{state[control[3]]=s.value;paintRulePlan(kind);};
      l.append(node('span',control[1]),s);
    }else{
      const b=node('input',undefined,'cb');b.type='checkbox';b.checked=state[control[2]];b.onchange=()=>{state[control[2]]=b.checked;paintRulePlan(kind);};
      l.append(b,node('span',control[1]));
    }
    opts.append(l);
  });
  c.append(opts);
  const run=node('div',undefined,'actions');
  const apply=button('Áp dụng',()=>call(spec.calls.apply,JSON.stringify(rulePayload(kind))),'primary');apply.id=`${id}-apply`;apply.disabled=true;
  run.append(button('Xem trước',()=>{state.pendingKey=ruleKey(kind);call(spec.calls.preview,JSON.stringify(rulePayload(kind)));}),apply);
  c.append(run);
  const box=node('div');box.id=`${id}-plan`;c.append(box);
  paintRulePlan(kind);
}

// Bản xem trước chỉ dùng được khi luật và tùy chọn chưa đổi từ lúc xem; Áp dụng mở khóa theo đó (Ruby vẫn tính lại lúc áp dụng).
function paintRulePlan(kind){
  const spec=RULE_KINDS[kind],state=ruleState[kind],box=$(`${spec.id}-plan`),apply=$(`${spec.id}-apply`);
  if(!box)return;
  box.replaceChildren();
  const plan=state.plan,fresh=!!plan&&state.planKey===ruleKey(kind);
  if(apply)apply.disabled=!(fresh&&plan.assign>0);
  if(!plan){box.append(node('p',spec.firstPlan,'muted'));return;}
  if(!fresh)box.append(node('p','Luật hoặc tùy chọn đã đổi: bấm Xem trước lại.','muted'));
  box.append(node('p',plan.assign?spec.planIntro:spec.planNone,'hint'));
  if(plan.rules.length){
    const list=node('ul');
    plan.rules.forEach(rule=>{const li=node('li');li.append(node('b',rule.tag,'tag-name'),node('span',`${rule.count} ${spec.unit} · ${rule.samples.join(', ')}${rule.count>rule.samples.length?'…':''}`));list.append(li);});
    box.append(list);
  }
  const stats=node('div',undefined,'metrics');
  spec.stats.forEach(([text,key])=>{const m=node('div',undefined,'metric');m.append(node('b',String(plan[key])),node('span',text));stats.append(m);});
  box.append(stats);
}

function receiveRulePlan(kind,data){
  const state=ruleState[kind];
  if(data.cleared){state.plan=null;state.planKey='';}
  else{state.plan=data;state.planKey=state.pendingKey||ruleKey(kind);}
  paintRulePlan(kind);
}
// Bộ luật mới từ Ruby (lưu mặc định, đặt lại, nhập file): thay bộ đang sửa và bỏ bản xem trước cũ.
function receiveRules(kind,data){
  const state=ruleState[kind];
  state.rules=copyRules(kind,data.rules);state.plan=null;state.planKey='';
  const c=$(`${RULE_KINDS[kind].id}-card`);if(c)renderRuleCard(kind,c);
}

const autoTagCard=(data,parent)=>ruleCard('tag',data,parent),folderRuleCard=(data,parent)=>ruleCard('folder',data,parent);
const receiveTagAutoPlan=data=>receiveRulePlan('tag',data),receiveTagRules=data=>receiveRules('tag',data);
const receiveFolderAutoPlan=data=>receiveRulePlan('folder',data),receiveFolderRules=data=>receiveRules('folder',data);

// ---- Bố cục tab Soạn tag ----
const tagTab={active:'model'};               // tab nhỏ đang mở, giữ khi tab vẽ lại (sau khi lưu, nhập, gán...)
const tagSetState={open:new Set(),query:'',group:''}; // nhóm đang mở, ô tìm và nhóm đang lọc, giữ khi vẽ lại
const TAG_TABS=[['model','Trong model'],['set','Bộ tag'],['auto','Tự động'],['lib','Thư viện mẫu']];
const foldText=text=>String(text||'').normalize('NFD').replace(/\p{Mn}/gu,'').replace(/[đĐ]/g,'d').toLowerCase();

function selectTagTab(name){
  const changed=tagTab.active!==name;
  tagTab.active=name;
  if(changed&&name==='model')call('tm_refresh'); // danh sách trong model có thể đã đổi trong SketchUp
  TAG_TABS.forEach(([key])=>{
    const tab=$(`tag-tab-${key}`),pane=$(`tag-pane-${key}`);
    if(!tab||!pane)return;
    const on=key===name;tab.setAttribute('aria-selected',String(on));tab.classList.toggle('active',on);pane.hidden=!on;
  });
}

function tagEditor(data){
  $('content').replaceChildren();
  const head=node('div',undefined,'tag-head');
  // Gán tag cho đối tượng đang chọn: luôn thấy ở đầu trang, không phải cuộn tới.
  const assign=node('div',undefined,'tag-assign');
  const info=node('span',`Đang chọn ${data.selection} đối tượng hoặc mặt trong SketchUp.`,'tag-selection');info.id='tag-selection-text';
  const pick=node('select');pick.id='tag-pick';pick.setAttribute('aria-label','Chọn tag');
  (data.tags||[]).forEach(tag=>pick.append(new Option(tag.name,tag.name)));
  const go=button('Gán tag',()=>{if(!pick.value)throw Error('Hãy lưu bộ tag trước, rồi chọn tag để gán.');call('assign_tag',JSON.stringify({name:pick.value}));},'primary');
  go.id='tag-assign';go.dataset.count=String(data.selection);go.disabled=!data.selection||!(data.tags||[]).length;
  go.title='Nếu tag đang tắt hiển thị, các đối tượng gán vào sẽ bị ẩn.';
  assign.append(info,pick,go);
  const tabs=node('div',undefined,'tag-tabs');tabs.setAttribute('role','tablist');
  TAG_TABS.forEach(([key,text])=>{const b=node('button',text);b.type='button';b.id=`tag-tab-${key}`;b.setAttribute('role','tab');b.onclick=()=>selectTagTab(key);tabs.append(b);});
  head.append(assign,tabs);
  const panes={};
  TAG_TABS.forEach(([key])=>{const pane=node('div',undefined,'tag-pane');pane.id=`tag-pane-${key}`;pane.setAttribute('role','tabpanel');panes[key]=pane;});
  $('content').append(head,panes.model,panes.set,panes.auto,panes.lib);
  if(data.tree)treeState.data=data.tree;
  tagTreePane(panes.model);
  tagSetPane(data,panes.set);
  autoTagCard(data,panes.auto);
  folderRuleCard(data,panes.auto);
  catalogCard(data,panes.lib);
  if(!panes.lib.firstChild)panes.lib.append(node('p','Chưa có thư viện tag mẫu.','muted'));
  selectTagTab(tagTab.active);
}

// Bộ tag: gom theo nhóm (gập được), ô tìm, lọc theo nhóm, dòng thấp. Lưu / nhập / xuất ở thanh trên cùng của tab.
function tagSetPane(data,pane){
  const groups=data.groups||[],rows=[]; // rows: thứ tự gốc của bộ tag (thứ tự lưu); mỗi phần tử {name, group, tr, removed}
  const bar=node('div',undefined,'tag-toolbar');
  const search=node('input');search.type='search';search.placeholder='Tìm tag...';search.value=tagSetState.query;search.setAttribute('aria-label','Tìm tag');
  const filter=node('select');filter.setAttribute('aria-label','Lọc theo nhóm');filter.append(new Option('Tất cả nhóm',''));
  groups.forEach(g=>filter.append(new Option(g,g)));filter.value=groups.includes(tagSetState.group)?tagSetState.group:'';
  const counter=node('span',undefined,'muted tag-count');
  bar.append(search,filter,counter);
  const actions=node('div',undefined,'tag-toolbar');
  actions.append(button('Thêm tag',()=>{
    const group=filter.value||groups[0];addRow({name:'',group});tagSetState.open.add(group);paint();
    const last=rows[rows.length-1];last.name.focus();
  }),button('Lưu bộ tag',()=>{
    const list=rows.filter(r=>!r.removed).map(r=>({name:r.name.value.trim(),group:r.group.value})).filter(r=>r.name!=='');
    call('save_tags',JSON.stringify(list));
  },'primary'),
  button('Nhập Excel (CSV)',()=>call('import_tags','csv')),button('Nhập JSON',()=>call('import_tags','json')),button('Xuất Excel (CSV)',()=>call('export_tags','csv')),button('Xuất JSON',()=>call('export_tags','json')));
  actions.querySelectorAll('button').forEach(b=>b.classList.add('sm'));
  const list=node('div',undefined,'tag-groups');
  const blocks={};
  groups.forEach(group=>{
    const block=node('details',undefined,'tag-group');block.dataset.group=group;
    const summary=node('summary');summary.append(node('b',group),node('span',undefined,'muted'));
    const table=node('table'),tbody=node('tbody');table.append(tbody);block.append(summary,table);
    summary.onclick=()=>{if(block.open)tagSetState.open.delete(group);else tagSetState.open.add(group);}; // chỉ ghi nhớ khi người dùng bấm, không ghi khi tự mở lúc tìm / bộ tag nhỏ
    blocks[group]={block,tbody,summary:summary.lastChild};list.append(block);
  });
  const empty=node('p','Chưa có tag nào. Bấm Thêm tag, nhập file, hoặc nhập cụm tag ở tab Thư viện mẫu.','muted');
  function addRow(tag){
    const group=groups.includes(tag.group)?tag.group:groups[0];
    const tr=node('tr'),name=node('input');name.type='text';name.value=tag.name||'';name.setAttribute('aria-label','Tên tag');
    const select=node('select');groups.forEach(g=>select.append(new Option(g,g)));select.value=group;select.setAttribute('aria-label','Nhóm');
    const status=tag.in_model===undefined?'Mới':tag.in_model?(tag.visible?'Có trong model':'Có trong model · đang ẩn'):'Chưa có trong model';
    const row={name,group:select,tr,removed:false};
    name.oninput=()=>paint();
    select.onchange=()=>{blocks[select.value].tbody.append(tr);tagSetState.open.add(select.value);paint();};
    cell(tr,name);cell(tr,select);cell(tr,node('span',status,'muted tag-status'));
    cell(tr,button('Xóa',()=>{row.removed=true;tr.remove();paint();},'sm'));
    blocks[group].tbody.append(tr);rows.push(row);
  }
  (data.tags||[]).forEach(addRow);
  // Hiện / ẩn theo ô tìm và nhóm đang lọc, cập nhật số tag của từng nhóm. Đang tìm thì tự mở nhóm có kết quả; bộ tag nhỏ thì mở sẵn hết.
  function paint(){
    tagSetState.query=search.value;tagSetState.group=filter.value;
    const q=foldText(search.value.trim()),live=rows.filter(r=>!r.removed);
    let shown=0;
    groups.forEach(group=>{
      const entry=blocks[group],mine=live.filter(r=>r.group.value===group);
      let visible=0;
      mine.forEach(r=>{const match=(!q||foldText(r.name.value).includes(q))&&(!filter.value||filter.value===group);r.tr.hidden=!match;if(match)visible+=1;});
      shown+=visible;
      entry.block.hidden=!visible;
      entry.summary.textContent=visible===mine.length?`${mine.length} tag`:`${visible} / ${mine.length} tag`;
      entry.block.open=visible>0&&(!!q||live.length<=12||tagSetState.open.has(group));
    });
    empty.hidden=live.length>0;
    counter.textContent=live.length?`${shown} / ${live.length} tag`:'';
  }
  search.oninput=paint;filter.onchange=paint;
  const scroll=node('div',undefined,'tag-scroll');scroll.append(list,empty);
  pane.append(bar,actions,scroll,node('p','Bộ tag lưu trên máy này, dùng lại cho mọi model; tên không phân biệt chữ hoa, chữ thường. Excel dùng file CSV; nếu Excel báo lỗi, hãy lưu lại dưới dạng CSV UTF-8.','muted tag-note'));
  paint();
}

// ---- Tab nhỏ "Trong model": cây thư mục tag / tag của model đang mở, mắt ẩn / hiện, cô lập, tìm kiếm ----
const treeState={data:null,open:new Set(),query:'',focus:'',dragging:null};
const TREE_ICONS={
  eye:'<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>',
  eyeOff:'<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7c2.4 0 4.4.8 6 1.8M23 12s-4 7-11 7c-2.4 0-4.4-.8-6-1.8"/><path d="M3 3l18 18"/></svg>',
  pin:'<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5M9 3h6l-1 6 3 4H7l3-4z"/></svg>',
  pinOn:'<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5M9 3h6l-1 6 3 4H7l3-4z"/></svg>',
  trash:'<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14M10 10v6M14 10v6"/></svg>',
  target:'<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.5" fill="currentColor"/></svg>'
};
function treeButton(icon,title,handler,cls){
  const b=node('button',undefined,'tm-btn'+(cls?' '+cls:''));b.type='button';b.innerHTML=TREE_ICONS[icon]; // chuỗi SVG cố định trong mã, không chứa dữ liệu người dùng
  b.title=title;b.setAttribute('aria-label',title);b.onclick=()=>{try{handler()}catch(error){message(error.message,true)}};return b;
}
const byName=(a,b)=>a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:'base'});

function tagTreePane(pane){
  const bar=node('div',undefined,'tag-toolbar');
  const search=node('input');search.type='search';search.placeholder='Tìm tag hoặc thư mục...';search.value=treeState.query;search.setAttribute('aria-label','Tìm tag hoặc thư mục');
  search.oninput=()=>{treeState.query=search.value;paintTagTree();};
  const expand=button('Mở hết',()=>{(treeState.data?treeState.data.folders:[]).forEach(f=>treeState.open.add(f.id));paintTagTree();},'sm');
  const collapse=button('Gập hết',()=>{treeState.open.clear();paintTagTree();},'sm');
  const refresh=button('Làm mới',()=>call('tm_refresh'),'sm');
  const colorByTag=button('Tô màu theo tag',()=>call('tm_color_by_tag',JSON.stringify({enabled:!(treeState.data&&treeState.data.color_by_tag)})),'sm');colorByTag.id='tag-tree-colorbytag';
  colorByTag.title='Bật / tắt chế độ tô màu theo tag của SketchUp (Color by Tag)';colorByTag.setAttribute('aria-pressed','false');
  const excel=button('Nhập Excel',()=>call('tm_excel_open'),'sm');excel.id='tag-tree-excel';excel.title='Nhập tag (kèm màu, kiểu nét, thư mục) từ file Excel .xlsx';
  const sample=button('Lấy mẫu',()=>call('tm_sample'),'sm');sample.id='tag-tree-sample';sample.title='Bấm vào một đối tượng trong view để lấy tag của nó (Esc để hủy)';
  bar.append(search,expand,collapse,refresh,sample,excel,colorByTag);
  const chips=node('div',undefined,'tm-chip-area');chips.id='tag-tree-chips';
  const rootDrop=node('div','Thả vào đây để đưa tag ra ngoài thư mục (gốc)','tm-root-drop');rootDrop.id='tag-tree-rootdrop';rootDrop.hidden=true;
  acceptTagDrop(rootDrop,null);
  const banner=node('div',undefined,'tm-banner');banner.id='tag-tree-banner';banner.hidden=true;
  const del=node('div',undefined,'tm-delete');del.id='tag-tree-delete';del.hidden=true;
  const excelCard=node('div',undefined,'tm-excel');excelCard.id='tag-excel-card';excelCard.hidden=true;
  const list=node('div',undefined,'tag-scroll tm-list');list.id='tag-tree-list';
  pane.append(bar,chips,rootDrop,banner,del,excelCard,list,node('p','Mắt ẩn / hiện tag hoặc cả thư mục trong model; nút tròn cô lập: chỉ hiện mục đó, ẩn mọi thứ còn lại, bấm lại để trả hiển thị như cũ. Mỗi thao tác là một bước hoàn tác.','muted tag-note'));
  paintTagTree();
}

function paintTagTree(){
  const list=$('tag-tree-list'),banner=$('tag-tree-banner');
  if(!list)return;
  const data=treeState.data,scroll=list.scrollTop;
  const cbt=$('tag-tree-colorbytag');if(cbt)cbt.setAttribute('aria-pressed',String(!!(data&&data.color_by_tag)));
  list.replaceChildren();banner.replaceChildren();banner.hidden=true;
  if(!data){list.append(node('p','Model chưa có tag nào.','muted'));return;}
  if(data.isolated){
    banner.hidden=false;
    banner.append(node('span',`Đang cô lập: ${data.isolated.name}`),button('Khôi phục hiển thị',()=>call('tm_isolate',JSON.stringify({restore:true})),'sm'));
  }
  if(!data.supported)list.append(node('p','Phiên bản SketchUp này chưa có thư mục tag (cần SketchUp 2021 trở lên). Chỉ hiện danh sách tag.','muted'));
  paintTreeChips(data);
  const q=foldText(treeState.query.trim());
  const folderById=new Map(data.folders.map(f=>[f.id,f]));
  const childFolders=new Map(),childLayers=new Map();
  data.folders.forEach(f=>{const key=f.parent_id===null||!folderById.has(f.parent_id)?null:f.parent_id;(childFolders.get(key)||childFolders.set(key,[]).get(key)).push(f);});
  data.layers.forEach(l=>{const key=l.folder_id===null||!folderById.has(l.folder_id)?null:l.folder_id;(childLayers.get(key)||childLayers.set(key,[]).get(key)).push(l);});
  const countTags=id=>(childLayers.get(id)||[]).length+(childFolders.get(id)||[]).reduce((n,f)=>n+countTags(f.id),0);
  // Mục nào hiện khi tìm: tag khớp tên, thư mục khớp tên (hiện cả nội dung), hoặc thư mục có mục con khớp.
  const shows=new Map();
  const folderShows=(folder,parentMatch)=>{
    const self=!q||foldText(folder.name).includes(q)||parentMatch;
    const kids=(childFolders.get(folder.id)||[]).map(f=>folderShows(f,self));
    const mine=(childLayers.get(folder.id)||[]).filter(l=>self||foldText(l.name).includes(q));
    const visible=self||kids.some(Boolean)||mine.length>0;
    shows.set(`f${folder.id}`,visible);mine.forEach(l=>shows.set(`l${l.id}`,true));
    return visible;
  };
  (childFolders.get(null)||[]).forEach(f=>folderShows(f,false));
  let rows=0;
  const addRow=(kind,item,depth,hiddenByParent)=>{
    const isFolder=kind==='folder',id=item.id,opened=!!q||treeState.open.has(id);
    const row=node('div',undefined,'tm-row'+(hiddenByParent||!item.visible?' dim':'')+(data.isolated&&data.isolated.kind===kind&&data.isolated.id===id?' isolated':''));
    row.dataset.kind=kind;row.dataset.id=String(id);row.style.paddingLeft=`${8+depth*16}px`;
    if(isFolder){
      const caret=node('button',opened?'▾':'▸','tm-caret');caret.type='button';caret.setAttribute('aria-label',opened?'Gập':'Mở');caret.setAttribute('aria-expanded',String(opened));
      caret.onclick=()=>{if(treeState.open.has(id))treeState.open.delete(id);else treeState.open.add(id);paintTagTree();};
      row.append(caret);
    }else row.append(node('span',undefined,'tm-caret'));
    const noun=isFolder?'thư mục':'tag';
    row.append(treeButton(item.visible?'eye':'eyeOff',item.visible?`Ẩn ${noun}`:`Hiện ${noun}`,()=>call('tm_visible',JSON.stringify({kind,id,visible:!item.visible})),item.visible?'on':'off'));
    const name=node('span',item.name,'tm-name'+(isFolder?' folder':''));name.title=item.name;row.append(name);
    if(!isFolder&&data.supported)row.title='Bấm tên để chọn tag cho nút Gán tag · kéo thả vào thư mục để chuyển';
    if(!isFolder){
      name.onclick=()=>selectAssignTag(item.name);
      if(treeState.focus&&treeState.focus===item.name)row.classList.add('focus');
      if(data.supported&&!UNTAGGED_TREE.includes(item.name)){
        row.draggable=true;
        row.ondragstart=e=>{e.dataTransfer.setData('text/plain',`vgd-tag:${id}`);e.dataTransfer.effectAllowed='move';treeState.dragging=id;row.classList.add('drag-src');const zone=$('tag-tree-rootdrop');if(zone)zone.hidden=false;};
        row.ondragend=()=>{treeState.dragging=null;row.classList.remove('drag-src');const zone=$('tag-tree-rootdrop');if(zone)zone.hidden=true;list.querySelectorAll('.drop').forEach(el=>el.classList.remove('drop'));};
      }
    }
    if(data.supported)acceptTagDrop(row,isFolder?id:(item.folder_id===undefined?null:item.folder_id));
    if(isFolder)row.append(node('span',`${countTags(id)} tag`,'muted tm-count'),node('span',undefined,'tm-pad'),node('span',undefined,'tm-pad-style'));
    else{
      // Màu và kiểu nét của tag. Màu đổi khi đóng bảng chọn màu (sự kiện change), không gửi liên tục lúc kéo.
      const color=node('input',undefined,'tm-color');color.type='color';color.value=item.color||'#000000';color.title='Màu tag';color.setAttribute('aria-label','Màu tag');
      color.onchange=()=>call('tm_color',JSON.stringify({id,color:color.value}));
      row.append(color);
      if(data.styles_supported){
        const style=node('select',undefined,'tm-style');style.setAttribute('aria-label','Kiểu nét');style.title='Kiểu nét';
        const styles=data.line_styles.includes(item.line_style)||!item.line_style?data.line_styles:[item.line_style,...data.line_styles];
        if(!item.line_style)style.append(new Option('(mặc định)',''));
        styles.forEach(name=>style.append(new Option(name,name)));style.value=item.line_style||'';
        style.onchange=()=>{if(style.value)call('tm_line_style',JSON.stringify({id,style:style.value}));};
        row.append(style);
      }else row.append(node('span',undefined,'tm-pad-style'));
    }
    if(!isFolder){
      const pinned=pinnedKeys(data).has(foldText(item.name));
      row.append(treeButton(pinned?'pinOn':'pin',pinned?'Bỏ ghim tag':'Ghim tag',()=>call('tm_pin',JSON.stringify({name:item.name,pinned:!pinned})),pinned?'on':''));
    }
    if(!isFolder&&!UNTAGGED_TREE.includes(item.name))row.append(treeButton('trash','Xóa tag (các đối tượng đang dùng sẽ chuyển sang tag khác)',()=>call('tm_delete_preview',JSON.stringify({id})),'del'));
    row.append(treeButton('target',data.isolated&&data.isolated.kind===kind&&data.isolated.id===id?'Bỏ cô lập':`Cô lập ${noun}`,()=>call('tm_isolate',JSON.stringify({kind,id})),'iso'));
    list.append(row);rows+=1;
  };
  const addFolder=(folder,depth,hiddenByParent)=>{
    if(!shows.get(`f${folder.id}`))return;
    addRow('folder',folder,depth,hiddenByParent);
    if(!q&&!treeState.open.has(folder.id))return;
    const hidden=hiddenByParent||!folder.visible;
    (childFolders.get(folder.id)||[]).slice().sort(byName).forEach(f=>addFolder(f,depth+1,hidden));
    (childLayers.get(folder.id)||[]).filter(l=>shows.get(`l${l.id}`)).slice().sort(byName).forEach(l=>addRow('tag',l,depth+1,hidden));
  };
  (childFolders.get(null)||[]).slice().sort(byName).forEach(f=>addFolder(f,0,false));
  (childLayers.get(null)||[]).filter(l=>!q||foldText(l.name).includes(q)).slice().sort(byName).forEach(l=>addRow('tag',l,0,false));
  if(!rows)list.append(node('p',data.layers.length?'Không có tag hoặc thư mục nào khớp.':'Model chưa có tag nào.','muted'));
  list.scrollTop=scroll;
}
const UNTAGGED_TREE=['Untagged','Layer0'];
const pinnedKeys=data=>new Set((data.pinned||[]).map(foldText));
// Chọn tag cho nút Gán tag (ô chọn tag ở đầu tab): thêm vào ô nếu tag chưa có trong bộ tag đã lưu; đánh dấu dòng trong danh sách.
function selectAssignTag(name){
  treeState.focus=name;
  const pick=$('tag-pick'),go=$('tag-assign');
  if(pick){
    if(![...pick.options].some(o=>o.value===name))pick.insertBefore(new Option(name,name),pick.firstChild);
    pick.value=name;
    if(go)go.disabled=go.dataset.count==='0'||!pick.options.length;
  }
  paintTagTree();
}
// Hàng chip phía trên danh sách: tag đã ghim (có nút bỏ ghim) và tag gán gần đây (có nút ghim). Bấm tên chip để chọn tag cho nút Gán tag.
function paintTreeChips(data){
  const box=$('tag-tree-chips');
  if(!box)return;
  box.replaceChildren();
  const exists=new Set(data.layers.map(l=>foldText(l.name))),keys=pinnedKeys(data);
  const pinned=data.pinned||[],recent=(data.recent||[]).filter(n=>!keys.has(foldText(n)));
  const group=(label,names,isPinned)=>{
    if(!names.length)return;
    const row=node('div',undefined,'tm-chips');row.append(node('span',label,'muted tm-chips-label'));
    names.forEach(name=>{
      const chip=node('span',undefined,'tm-chip'+(exists.has(foldText(name))?'':' missing')+(treeState.focus===name?' focus':''));
      const pick=node('button',name,'tm-chip-name');pick.type='button';pick.title='Chọn tag này cho nút Gán tag';pick.onclick=()=>selectAssignTag(name);
      const pin=treeButton(isPinned?'pinOn':'pin',isPinned?'Bỏ ghim tag':'Ghim tag',()=>call('tm_pin',JSON.stringify({name,pinned:!isPinned})),isPinned?'on':'');
      chip.append(pick,pin);row.append(chip);
    });
    box.append(row);
  };
  group('Đã ghim',pinned,true);
  group('Gần đây',recent,false);
}
// Thả tag vào hàng này: chuyển tag vào thư mục folderId (null = ra ngoài thư mục). Dùng cho dòng thư mục, dòng tag (cùng thư mục với nó) và vùng "gốc".
function acceptTagDrop(el,folderId){
  el.addEventListener('dragover',e=>{if(treeState.dragging===null)return;e.preventDefault();e.dataTransfer.dropEffect='move';el.classList.add('drop');});
  el.addEventListener('dragleave',()=>el.classList.remove('drop'));
  el.addEventListener('drop',e=>{
    e.preventDefault();el.classList.remove('drop');
    const id=treeState.dragging;treeState.dragging=null;
    const zone=$('tag-tree-rootdrop');if(zone)zone.hidden=true;
    if(id!==null)call('tm_move',JSON.stringify({id,folder_id:folderId}));
  });
}
// Lấy mẫu: Ruby gửi tên tag của đối tượng vừa bấm trong view. Chọn tag đó cho nút Gán tag, mở các thư mục chứa nó và sáng dòng.
function receiveTagSample(data){
  const name=data.name||'';
  if(!name)return message('Không bấm trúng đối tượng nào.',true);
  if(UNTAGGED_TREE.includes(name))return message('Đối tượng này chưa có tag (Untagged).',true);
  selectTagTab('model');
  const tree=treeState.data;
  if(tree){
    const layer=tree.layers.find(l=>l.name===name);
    let folder=layer?tree.folders.find(f=>f.id===layer.folder_id):null;
    while(folder){treeState.open.add(folder.id);folder=tree.folders.find(f=>f.id===folder.parent_id);}
  }
  selectAssignTag(name);
  const row=document.querySelector('#tag-tree-list .tm-row.focus');if(row&&row.scrollIntoView)row.scrollIntoView({block:'nearest'});
  message(`Đã lấy tag "${name}". Chọn đối tượng rồi bấm Gán tag để gán.`);
}
// Xóa tag có gán lại: Ruby đếm số đối tượng đang dùng tag (tag_delete_preview), rồi người dùng chọn tag nhận và xác nhận ở đây.
function receiveTagDeletePreview(data){
  const box=$('tag-tree-delete'),tree=treeState.data;
  if(!box)return;
  box.hidden=false;box.replaceChildren();
  const head=node('p',undefined,'tm-delete-head');head.append(node('span','Xóa tag'),node('b',data.name),node('span',`: ${data.count} đối tượng đang dùng tag này`));
  const pick=node('select');pick.setAttribute('aria-label','Chuyển các đối tượng sang tag');
  pick.append(new Option('Untagged (không có tag)',''));
  ((tree&&tree.layers)||[]).filter(l=>l.id!==data.id&&!UNTAGGED_TREE.includes(l.name)).sort(byName).forEach(l=>pick.append(new Option(l.name,String(l.id))));
  const row=node('label',undefined,'tm-delete-row');row.append(node('span','Chuyển các đối tượng sang tag:'),pick);
  const actions=node('div',undefined,'actions');
  const confirm=button('Xóa tag',()=>{box.hidden=true;box.replaceChildren();call('tm_delete',JSON.stringify({id:data.id,to_id:pick.value===''?null:Number(pick.value)}));},'danger');confirm.id='tag-delete-confirm';
  actions.append(confirm,button('Hủy',()=>{box.hidden=true;box.replaceChildren();}));
  box.append(head,row,node('p','Không đối tượng nào bị xóa: chỉ đổi tag của chúng rồi gỡ tag.','muted'),actions);
}
// Nhập tag từ Excel: Ruby đọc file .xlsx và gửi bản xem trước (tag_excel); người dùng tick dòng cần nhập rồi bấm Nhập.
const excelState={data:null,selected:new Set(),overwrite:false};
function receiveTagExcel(data){
  const box=$('tag-excel-card');
  if(!box)return;
  if(data.cleared){excelState.data=null;box.hidden=true;box.replaceChildren();return;}
  excelState.data=data;excelState.selected=new Set(data.rows.map((_,i)=>i));excelState.overwrite=false;
  selectTagTab('model');
  paintTagExcel();
}
function paintTagExcel(){
  const box=$('tag-excel-card'),data=excelState.data;
  if(!box||!data)return;
  box.hidden=false;box.replaceChildren();
  const existing=data.rows.filter(r=>r.exists).length;
  const head=node('div',undefined,'tm-excel-head');head.append(node('b','Nhập tag từ Excel'),node('span',data.file,'muted tm-excel-file'),node('span',`${data.rows.length} dòng · ${existing} đã có trong model`,'muted'));
  box.append(head);
  (data.warnings||[]).forEach(text=>box.append(node('p',text,'muted tm-excel-warning')));
  if(data.more_warnings)box.append(node('p',`… và ${data.more_warnings} cảnh báo khác`,'muted tm-excel-warning'));
  const wrap=node('div',undefined,'tag-scroll tm-excel-scroll'),table=node('table'),thead=node('thead'),htr=node('tr');
  ['','Tên tag','Màu','Kiểu nét','Thư mục','Trạng thái'].forEach(h=>htr.append(node('th',h)));thead.append(htr);table.append(thead);
  const tbody=node('tbody');
  data.rows.forEach((row,i)=>{
    const tr=node('tr',undefined,row.exists?'exists':'');
    const box1=node('input',undefined,'cb');box1.type='checkbox';box1.checked=excelState.selected.has(i);box1.setAttribute('aria-label',row.name);
    box1.onchange=()=>{if(box1.checked)excelState.selected.add(i);else excelState.selected.delete(i);paintTagExcelActions();};
    cell(tr,box1);cell(tr,row.name);
    const swatch=node('span',undefined,'tm-swatch');if(row.color)swatch.style.background=row.color;
    const colorCell=node('span');colorCell.append(swatch,node('span',row.color||'—','muted'));cell(tr,colorCell);
    cell(tr,row.style||'—');cell(tr,row.folder||'—');
    cell(tr,node('span',row.exists?'Đã có':'Mới',row.exists?'muted':''));
    tbody.append(tr);
  });
  table.append(tbody);wrap.append(table);box.append(wrap);
  const opts=node('div',undefined,'auto-opts');
  const over=node('label',undefined,'auto-opt'),overBox=node('input',undefined,'cb');overBox.type='checkbox';overBox.checked=excelState.overwrite;overBox.onchange=()=>{excelState.overwrite=overBox.checked;};
  over.append(overBox,node('span','Cập nhật cả tag đã có (màu, kiểu nét, thư mục); mặc định chỉ tạo tag mới'));opts.append(over);box.append(opts);
  const actions=node('div',undefined,'actions');actions.id='tag-excel-actions';box.append(actions);
  paintTagExcelActions();
}
function paintTagExcelActions(){
  const actions=$('tag-excel-actions'),data=excelState.data;
  if(!actions||!data)return;
  actions.replaceChildren();
  const n=excelState.selected.size;
  const go=button(n?`Nhập ${n} tag`:'Nhập',()=>{
    const rows=data.rows.filter((_,i)=>excelState.selected.has(i)).map(r=>({name:r.name,color:r.color,style:r.style,folder:r.folder}));
    call('tm_excel_apply',JSON.stringify({rows,overwrite:excelState.overwrite}));
  },'primary');go.id='tag-excel-import';go.disabled=!n;
  actions.append(go,button('Chọn tất cả',()=>{data.rows.forEach((_,i)=>excelState.selected.add(i));paintTagExcel();}),button('Bỏ chọn',()=>{excelState.selected.clear();paintTagExcel();}),
    button('Hủy',()=>{excelState.data=null;const box=$('tag-excel-card');box.hidden=true;box.replaceChildren();}));
}
function receiveTagTree(data){treeState.data=data;paintTagTree();}
