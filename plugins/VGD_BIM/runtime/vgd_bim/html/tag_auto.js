'use strict';
// Gắn tag tự động theo từ khóa tên (tab Soạn tag): bảng luật "tên tag ← từ khóa", tùy chọn, xem trước, áp dụng, lưu mặc định, nhập / xuất file.
// Dùng các hàm chung của app.js ($, node, button, card, call...) vào lúc gọi. Bộ luật đang sửa nằm ở đây và được gửi kèm mỗi lệnh;
// phía Ruby kiểm tra lại toàn bộ (TagRules.sanitize), nên giao diện không phải tin được.
const autoTag={rules:null,plan:null,planKey:'',pendingKey:'',based:'both',scope:'selection',nested:false,overwrite:false};
const AUTO_BASED=[['both','Cả tên bản sao và tên component'],['instance','Tên bản sao'],['definition','Tên component']];
const AUTO_SCOPE=[['selection','Đối tượng đang chọn'],['model','Cả model']];

function autoPayload(){
  return {rules:autoTag.rules.filter(r=>r.tag.trim()||r.keywords.trim()).map(r=>({tag:r.tag,keywords:r.keywords})),based_on:autoTag.based,scope:autoTag.scope,nested:autoTag.nested,overwrite:autoTag.overwrite};
}
const autoKey=()=>JSON.stringify(autoPayload());

function autoTagCard(data){
  if(!autoTag.rules)autoTag.rules=(data.rules||[]).map(r=>({tag:r.tag,keywords:r.keywords}));
  const c=card('Gắn tag tự động theo tên');c.id='tag-auto-card';
  renderAutoTag(c);
}

function renderAutoTag(c){
  c.replaceChildren(node('h2','Gắn tag tự động theo tên'));
  c.append(node('p','Mỗi luật là "tên tag ← từ khóa trong tên group / component" (nhiều từ khóa cách nhau dấu phẩy). Luật nằm trên thắng. Không phân biệt hoa thường và dấu tiếng Việt; từ khóa chỉ cần nằm trong tên (ví dụ "door" cũng khớp "Doorway"), nên hãy Xem trước rồi mới Áp dụng.','hint'));
  const wrap=node('div',undefined,'table-wrap auto-rules'),t=node('table'),head=node('thead'),htr=node('tr');
  ['#','Tên tag','Từ khóa trong tên','Thao tác'].forEach(h=>htr.append(node('th',h)));head.append(htr);t.append(head);
  const tbody=node('tbody');
  autoTag.rules.forEach((rule,index)=>{
    const tr=node('tr');
    const cell=child=>{const td=node('td');td.append(child);tr.append(td);};
    cell(node('span',String(index+1)));
    const tag=node('input');tag.type='text';tag.value=rule.tag;tag.maxLength=60;tag.setAttribute('aria-label','Tên tag');tag.oninput=()=>{rule.tag=tag.value;paintAutoPlan();};
    const words=node('input');words.type='text';words.value=rule.keywords;words.maxLength=400;words.setAttribute('aria-label','Từ khóa trong tên');words.oninput=()=>{rule.keywords=words.value;paintAutoPlan();};
    cell(tag);cell(words);
    const ops=node('div',undefined,'actions');
    const move=(text,title,delta)=>{const b=button(text,()=>{const to=index+delta;if(to<0||to>=autoTag.rules.length)return;[autoTag.rules[index],autoTag.rules[to]]=[autoTag.rules[to],autoTag.rules[index]];renderAutoTag(c);});b.title=title;b.setAttribute('aria-label',title);return b;};
    ops.append(move('↑','Lên trên',-1),move('↓','Xuống dưới',1),button('Xóa',()=>{autoTag.rules.splice(index,1);renderAutoTag(c);}));
    cell(ops);tbody.append(tr);
  });
  t.append(tbody);wrap.append(t);c.append(wrap);
  const rules=node('div',undefined,'actions');
  rules.append(button('Thêm luật',()=>{autoTag.rules.push({tag:'',keywords:''});renderAutoTag(c);const inputs=c.querySelectorAll('.auto-rules tbody tr:last-child input');if(inputs[0])inputs[0].focus();}),
    button('Lưu làm mặc định',()=>call('tag_rules_save',JSON.stringify({rules:autoPayload().rules}))),
    button('Đặt lại',()=>call('tag_rules_reset')),
    button('Nhập file luật',()=>call('tag_rules_import')),
    button('Xuất file luật',()=>call('tag_rules_export',JSON.stringify({rules:autoPayload().rules}))));
  c.append(rules);
  // Tùy chọn của lần gắn
  const opts=node('div',undefined,'auto-opts');
  const choose=(label,list,key)=>{const l=node('label',undefined,'auto-opt');const s=node('select');s.setAttribute('aria-label',label);list.forEach(([v,text])=>s.append(new Option(text,v)));s.value=autoTag[key];s.onchange=()=>{autoTag[key]=s.value;paintAutoPlan();};l.append(node('span',label),s);return l;};
  const toggle=(label,key)=>{const l=node('label',undefined,'auto-opt');const b=node('input',undefined,'cb');b.type='checkbox';b.checked=autoTag[key];b.onchange=()=>{autoTag[key]=b.checked;paintAutoPlan();};l.append(b,node('span',label));return l;};
  opts.append(choose('Dựa theo',AUTO_BASED,'based'),choose('Phạm vi',AUTO_SCOPE,'scope'),
    toggle('Gắn cả group / component bên trong (đổi tag của mọi bản sao dùng chung định nghĩa)','nested'),
    toggle('Ghi đè tag đã có (mặc định chỉ gắn đối tượng chưa có tag)','overwrite'));
  c.append(opts);
  const run=node('div',undefined,'actions');
  const apply=button('Áp dụng',()=>call('tag_auto_apply',JSON.stringify(autoPayload())),'primary');apply.id='tag-auto-apply';apply.disabled=true;
  run.append(button('Xem trước',()=>{autoTag.pendingKey=autoKey();call('tag_auto_preview',JSON.stringify(autoPayload()));}),apply);
  c.append(run);
  const box=node('div');box.id='tag-auto-plan';c.append(box);
  paintAutoPlan();
}

// Bản xem trước chỉ dùng được khi luật và tùy chọn chưa đổi từ lúc xem; Áp dụng mở khóa theo đó (Ruby vẫn tính lại lúc áp dụng).
function paintAutoPlan(){
  const box=$('tag-auto-plan'),apply=$('tag-auto-apply');
  if(!box)return;
  box.replaceChildren();
  const plan=autoTag.plan,fresh=!!plan&&autoTag.planKey===autoKey();
  if(apply)apply.disabled=!(fresh&&plan.assign>0);
  if(!plan){box.append(node('p','Bấm Xem trước để biết sẽ gắn tag cho những đối tượng nào.','muted'));return;}
  if(!fresh)box.append(node('p','Luật hoặc tùy chọn đã đổi: bấm Xem trước lại.','muted'));
  box.append(node('p',plan.assign?'Sẽ gắn tag cho các đối tượng sau:':'Không có đối tượng nào cần gắn tag.','hint'));
  if(plan.rules.length){
    const list=node('ul');
    plan.rules.forEach(rule=>{const li=node('li');li.append(node('b',rule.tag,'tag-name'),node('span',`${rule.count} đối tượng · ${rule.samples.join(', ')}${rule.count>rule.samples.length?'…':''}`));list.append(li);});
    box.append(list);
  }
  const stats=node('div',undefined,'metrics');
  [['Tổng đã xét',plan.total],['Sẽ gắn',plan.assign],['Đã đúng tag sẵn',plan.same],['Giữ nguyên (đã có tag khác)',plan.kept],['Không khớp luật nào',plan.unmatched],['Bị khóa',plan.locked]].forEach(([text,n])=>{
    const m=node('div',undefined,'metric');m.append(node('b',String(n)),node('span',text));stats.append(m);
  });
  box.append(stats);
}

function receiveTagAutoPlan(data){
  if(data.cleared){autoTag.plan=null;autoTag.planKey='';}
  else{autoTag.plan=data;autoTag.planKey=autoTag.pendingKey||autoKey();}
  paintAutoPlan();
}
// Bộ luật mới từ Ruby (lưu mặc định, đặt lại, nhập file): thay bộ đang sửa và bỏ bản xem trước cũ.
function receiveTagRules(data){
  autoTag.rules=(data.rules||[]).map(r=>({tag:r.tag,keywords:r.keywords}));
  autoTag.plan=null;autoTag.planKey='';
  const c=$('tag-auto-card');if(c)renderAutoTag(c);
}
