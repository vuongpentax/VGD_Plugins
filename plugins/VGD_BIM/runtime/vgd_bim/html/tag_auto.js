'use strict';
// Thư viện tag mẫu (tick cụm rồi Nhập), gắn tag tự động theo từ khóa tên và xếp tag vào thư mục tag (tab Soạn tag). Hai thẻ luật dùng chung một bộ vẽ:
// bảng luật "đích ← từ khóa", tùy chọn, xem trước, áp dụng, lưu mặc định, đặt lại, nhập / xuất file. Dùng các hàm chung của app.js ($, node, button, card, call...).
// Bộ luật đang sửa nằm ở đây và được gửi kèm mỗi lệnh; phía Ruby kiểm tra lại toàn bộ (TagRules / FolderRules .sanitize), nên giao diện không phải tin được.

// ---- Thư viện tag mẫu (18 cụm của Auto Tag): tick cụm rồi Nhập = thêm vào bộ tag của BIM và tạo sẵn trong model ----
const catalogState={selected:new Set()};
function catalogCard(data){
  const clusters=data.catalog||[];
  if(!clusters.length)return;
  const c=card('Thư viện tag mẫu (Auto Tag)');c.id='tag-catalog-card';
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
const ruleState={tag:{rules:null,plan:null,planKey:'',pendingKey:''},folder:{rules:null,plan:null,planKey:'',pendingKey:''}};
for(const kind of Object.keys(RULE_KINDS))Object.assign(ruleState[kind],RULE_KINDS[kind].options);

function rulePayload(kind){
  const spec=RULE_KINDS[kind],state=ruleState[kind],payload={rules:state.rules.filter(r=>r[spec.target].trim()||r.keywords.trim()).map(r=>({[spec.target]:r[spec.target],keywords:r.keywords}))};
  if(kind==='tag')Object.assign(payload,{based_on:state.based,scope:state.scope,nested:state.nested,overwrite:state.overwrite});
  else payload.overwrite=state.overwrite;
  return payload;
}
const ruleKey=kind=>JSON.stringify(rulePayload(kind));
const copyRules=(kind,list)=>(list||[]).map(r=>({[RULE_KINDS[kind].target]:r[RULE_KINDS[kind].target],keywords:r.keywords}));

function ruleCard(kind,data){
  const spec=RULE_KINDS[kind],state=ruleState[kind];
  if(!state.rules)state.rules=copyRules(kind,kind==='tag'?data.rules:data.folder_rules);
  const c=card(spec.title);c.id=`${spec.id}-card`;
  renderRuleCard(kind,c);
}

function renderRuleCard(kind,c){
  const spec=RULE_KINDS[kind],state=ruleState[kind],id=spec.id;
  c.replaceChildren(node('h2',spec.title),node('p',spec.hint,'hint'));
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
  t.append(tbody);wrap.append(t);c.append(wrap);
  const rules=node('div',undefined,'actions');
  rules.append(button('Thêm luật',()=>{state.rules.push({[spec.target]:'',keywords:''});renderRuleCard(kind,c);const inputs=c.querySelectorAll('.auto-rules tbody tr:last-child input');if(inputs[0])inputs[0].focus();}),
    button('Lưu làm mặc định',()=>call(spec.calls.save,JSON.stringify({rules:rulePayload(kind).rules}))),
    button('Đặt lại',()=>call(spec.calls.reset)),
    button('Nhập file luật',()=>call(spec.calls.import)),
    button('Xuất file luật',()=>call(spec.calls.export,JSON.stringify({rules:rulePayload(kind).rules}))));
  c.append(rules);
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

const autoTagCard=data=>ruleCard('tag',data),folderRuleCard=data=>ruleCard('folder',data);
const receiveTagAutoPlan=data=>receiveRulePlan('tag',data),receiveTagRules=data=>receiveRules('tag',data);
const receiveFolderAutoPlan=data=>receiveRulePlan('folder',data),receiveFolderRules=data=>receiveRules('folder',data);
