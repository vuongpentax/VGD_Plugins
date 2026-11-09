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
const tagTab={active:'set'};               // tab nhỏ đang mở, giữ khi tab vẽ lại (sau khi lưu, nhập, gán...)
const tagSetState={open:new Set(),query:'',group:''}; // nhóm đang mở, ô tìm và nhóm đang lọc, giữ khi vẽ lại
const TAG_TABS=[['set','Bộ tag'],['auto','Tự động'],['lib','Thư viện mẫu']];
const foldText=text=>String(text||'').normalize('NFD').replace(/\p{Mn}/gu,'').replace(/[đĐ]/g,'d').toLowerCase();

function selectTagTab(name){
  tagTab.active=name;
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
  go.id='tag-assign';go.disabled=!data.selection||!(data.tags||[]).length;
  go.title='Nếu tag đang tắt hiển thị, các đối tượng gán vào sẽ bị ẩn.';
  assign.append(info,pick,go);
  const tabs=node('div',undefined,'tag-tabs');tabs.setAttribute('role','tablist');
  TAG_TABS.forEach(([key,text])=>{const b=node('button',text);b.type='button';b.id=`tag-tab-${key}`;b.setAttribute('role','tab');b.onclick=()=>selectTagTab(key);tabs.append(b);});
  head.append(assign,tabs);
  const panes={};
  TAG_TABS.forEach(([key])=>{const pane=node('div',undefined,'tag-pane');pane.id=`tag-pane-${key}`;pane.setAttribute('role','tabpanel');panes[key]=pane;});
  $('content').append(head,panes.set,panes.auto,panes.lib);
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
