// Kiểm tra giao diện cửa sổ Đổi tên (html/rename.html) bằng trình duyệt headless, không cần SketchUp: dữ liệu đưa vào qua window.VGD.receive,
// lệnh gửi Ruby được ghi lại qua window.sketchup giả. Chạy từ plugins/VGD_BIM: node dev/test_ui_rename.cjs [thư mục lưu ảnh]
const path=require('path'),{pathToFileURL}=require('url');
const {chromium}=require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
const fail=m=>{console.log('FAIL  '+m);process.exitCode=1;},pass=m=>console.log('PASS  '+m);
const ok=(name,cond)=>cond?pass(name):fail(name);
const VIET=/[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]/i;
const shots=process.argv[2];
const ITEMS=[
  {id:11,name:'',definition:'Tủ bếp',def_id:1,locked:false},{id:12,name:'',definition:'Tủ bếp',def_id:1,locked:false},{id:13,name:'',definition:'Tủ bếp',def_id:1,locked:false},
  {id:21,name:'Kệ tivi',definition:'Component#4',def_id:2,locked:false},
  {id:31,name:'Ban an 1m6',definition:'Group#7',def_id:3,locked:false},
  {id:41,name:'Cửa D1',definition:'Cửa',def_id:4,locked:true}
];
const TEMPLATES={prefix:['PK'],name:['Tủ bếp trên','Bàn ăn'],suffix:['gỗ sồi']};
(async()=>{
  const browser=await chromium.launch({headless:true,channel:process.env.VGD_BROWSER_CHANNEL||undefined});
  try{
    for(const lang of ['vi','en']){
      const page=await browser.newPage({viewport:{width:640,height:640}}),errors=[];
      page.on('pageerror',e=>errors.push(e.message));
      await page.addInitScript(()=>{window.__calls=[];window.sketchup=new Proxy({},{get:(_,name)=>(...args)=>window.__calls.push([name,...args])});try{localStorage.clear();}catch(_){}});
      await page.goto(pathToFileURL(path.resolve(__dirname,'../runtime/vgd_bim/html/rename.html')).href);
      const receive=(event,data)=>page.evaluate(([e,d])=>window.VGD.receive(e,d),[event,data]);
      const calls=()=>page.evaluate(()=>window.__calls);
      const last=async name=>{const list=(await calls()).filter(c=>c[0]===name);return list.length?list[list.length-1]:null;};
      ok(`[${lang}] gửi ready khi mở`,(await calls()).some(c=>c[0]==='ready'));
      await receive('config',{version:'test',language:lang,templates:TEMPLATES});
      await receive('items',{total:ITEMS.length,items:ITEMS});
      const rowsText=()=>page.locator('.rn-row').allInnerTexts();
      ok(`[${lang}] 3 món cùng định nghĩa gom thành một dòng, tổng 4 dòng`,(await page.locator('.rn-row').count())===4);
      ok(`[${lang}] Áp dụng tắt khi chưa có tên mới`,await page.locator('#apply').isDisabled());
      if(lang==='vi'){
        ok('dòng bị khóa ghi Bị khóa',(await rowsText()).some(t=>t.includes('Cửa D1')&&t.includes('Bị khóa')));
        // Chưa chọn dòng: bấm mẫu tên đặt cho mọi món không khóa.
        await page.locator('.set').nth(1).locator('.chip',{hasText:'Bàn ăn'}).click();
        ok('chưa chọn dòng: bấm mẫu Tên đặt cho 5 món không khóa, trùng tên được đánh số',(await page.locator('#apply').innerText())==='Áp dụng (5)');
        await page.locator('#reset').click();
        ok('↺ bỏ hết tên mới chưa áp dụng',await page.locator('#apply').isDisabled());
        // Chọn dòng Tủ bếp (3 món): chọn luôn 3 món đó trong SketchUp; đặt tiền tố + tên + hậu tố.
        await page.locator('.rn-row').first().click();
        const picked=await last('rename_pick');
        ok('bấm dòng: gửi Ruby chọn các món của dòng trong SketchUp',picked&&JSON.stringify(JSON.parse(picked[1]).ids)==='[11,12,13]');
        await page.locator('.set').nth(0).locator('.chip',{hasText:'PK'}).click();
        await page.locator('.set').nth(1).locator('.chip',{hasText:'Tủ bếp trên'}).click();
        await page.locator('.set').nth(2).locator('.chip',{hasText:'gỗ sồi'}).click();
        await page.locator('.rn-row .fold').first().click();
        const kids=await page.locator('.rn-row.kid .c-new').allInnerTexts();
        ok('tiền tố - tên - hậu tố cách nhau dấu cách, 3 món trùng tên có số 01 02 03',JSON.stringify(kids)===JSON.stringify(['PK Tủ bếp trên gỗ sồi 01','PK Tủ bếp trên gỗ sồi 02','PK Tủ bếp trên gỗ sồi 03']));
        await page.locator('#numbered').click();
        ok('tắt 123: không đánh số',(await page.locator('.rn-row.kid .c-new').first().innerText())==='PK Tủ bếp trên gỗ sồi');
        await page.locator('#numbered').click();
        ok('chip đang dùng cho mọi món chọn được tô',await page.locator('.set').nth(2).locator('.chip.on').count()===1);
        await page.locator('.set').nth(2).locator('.chip',{hasText:'gỗ sồi'}).click();
        ok('bấm lại mẫu đang dùng thì bỏ',(await page.locator('.rn-row.kid .c-new').first().innerText())==='PK Tủ bếp trên 01');
        // Ô nhập: hiện phần của dòng đang chọn, gõ là đổi ngay, × xóa chữ trong ô, + lưu vào mẫu.
        const box=i=>page.locator('.set').nth(i).locator('.entry');
        ok('ô Tiền tố / Tên hiện giá trị của các món đang chọn',(await box(0).locator('input').inputValue())==='PK'&&(await box(1).locator('input').inputValue())==='Tủ bếp trên');
        ok('ô không có chữ "Thêm", + và × có sẵn trong ô',(await box(0).locator('input').getAttribute('placeholder'))==='Tiền tố'&&(await box(0).locator('button.add').count())===1&&(await box(0).locator('button.clr').count())===1);
        ok('+ tắt khi chữ đã có trong mẫu',await box(0).locator('button.add').isDisabled());
        await box(0).locator('input').fill('PB');
        ok('gõ tiền tố: tên mới đổi ngay',(await page.locator('.rn-row.kid .c-new').first().innerText())==='PB Tủ bếp trên 01');
        ok('đang gõ: con trỏ vẫn ở ô',await box(0).locator('input').evaluate(e=>document.activeElement===e));
        await box(0).locator('button.add').click();
        let savedPrefix=JSON.parse((await last('rename_templates'))[1]);
        ok('+ lưu chữ trong ô vào mẫu',savedPrefix.prefix.includes('PB'));
        await box(0).locator('button.clr').click();
        ok('× xóa chữ trong ô và bỏ tiền tố',(await box(0).locator('input').inputValue())===''&&(await page.locator('.rn-row.kid .c-new').first().innerText())==='Tủ bếp trên 01');
        await box(0).locator('input').fill('PK');
        // Nhấp đúp sửa tay phần tên của một món.
        await page.locator('.rn-row',{hasText:'Ban an 1m6'}).dblclick();
        await page.locator('input.edit').fill('Bàn ăn 1m6');await page.locator('input.edit').press('Enter');
        ok('nhấp đúp gõ tay tên mới',(await rowsText()).some(t=>t.includes('Ban an 1m6')&&t.includes('Bàn ăn 1m6')));
        // Thay → Bằng áp lên tên hiện tại khi chưa có tên.
        await page.fill('#find','Kệ');await page.fill('#repl','Tủ');
        ok('Thay → Bằng đổi trên tên hiện tại',(await rowsText()).some(t=>t.includes('Kệ tivi')&&t.includes('Tủ tivi')));
        await page.locator('#upper').click();
        ok('AA viết hoa tên mới',(await rowsText()).some(t=>t.includes('TỦ TIVI')));
        await page.locator('#upper').click();
        await page.locator('#auto-hide').click();
        ok('bật Ẩn',(await page.getAttribute('#auto-hide','aria-checked'))==='true');
        await page.locator('#apply').click();
        const sent=await last('rename_apply');
        const payload=sent&&JSON.parse(sent[1]);
        ok('Áp dụng gửi đúng tên và cờ ẩn, không gửi món khóa',payload&&payload.hide===true&&JSON.stringify(payload.changes)===JSON.stringify([
          {id:11,name:'PK Tủ bếp trên 01'},{id:12,name:'PK Tủ bếp trên 02'},{id:13,name:'PK Tủ bếp trên 03'},{id:21,name:'Tủ tivi'},{id:31,name:'Bàn ăn 1m6'}]));
        await receive('items',{total:1,items:[ITEMS[5]]}); // Ruby: món đã ẩn rời vùng chọn, gửi lại danh sách trước khi báo xong
        await receive('applied',{count:5,hidden:5,text:'Đã đổi tên 5 món và ẩn đi (Edit > Unhide để hiện lại). Bấm Ctrl+Z để hoàn tác.'});
        ok('sau Áp dụng: bỏ tên mới đã ghi, báo kết quả',(await page.locator('#apply').isDisabled())&&(await page.locator('#status').innerText()).startsWith('Đã đổi tên 5 món'));
        await receive('items',{total:ITEMS.length,items:ITEMS});
        // Mẫu tên: thêm, trùng, xóa; gửi Ruby lưu.
        await page.locator('.rn-row',{hasText:'Ban an 1m6'}).click();
        await page.fill('.set:nth-child(3) .entry input','sơn trắng');await page.locator('.set:nth-child(3) .entry button.add').click();
        let saved=JSON.parse((await last('rename_templates'))[1]);
        ok('thêm mẫu hậu tố gửi Ruby lưu',JSON.stringify(saved.suffix)===JSON.stringify(['gỗ sồi','sơn trắng']));
        await page.locator('.set').nth(0).locator('.chip',{hasText:'PK'}).locator('.x').click();
        saved=JSON.parse((await last('rename_templates'))[1]);
        ok('xóa mẫu tiền tố gửi Ruby lưu',!saved.prefix.includes('PK'));
        await page.locator('.rn-row',{hasText:'Kệ tivi'}).hover();await page.locator('.rn-row',{hasText:'Kệ tivi'}).locator('.copy').click();
        saved=JSON.parse((await last('rename_templates'))[1]);
        ok('biểu tượng lưu tên hiện tại vào mẫu Tên',saved.name.includes('Kệ tivi'));
        // Vùng chọn đổi: tên mới chưa áp dụng của món còn chọn được giữ.
        await page.fill('#find','');
        await page.locator('.rn-row',{hasText:'Kệ tivi'}).click();
        await page.locator('.set').nth(1).locator('.chip',{hasText:'Bàn ăn'}).click();
        await receive('items',{total:2,items:[ITEMS[3],ITEMS[4]]});
        ok('chọn lại trong SketchUp: danh sách cập nhật, giữ tên mới chưa áp dụng',(await page.locator('.rn-row').count())===2&&(await rowsText()).some(t=>t.includes('Kệ tivi')&&t.includes('Bàn ăn')));
        await receive('message',{error:'Có món bị khóa, không đổi tên được.'});
        ok('lỗi từ Ruby hiện ở dòng trạng thái màu đỏ',await page.locator('#status.err').count()===1);
        await receive('items',{total:0,items:[]});
        ok('không chọn gì: hướng dẫn chọn trong SketchUp',(await page.locator('.rn-empty').count())===1);
        await receive('items',{total:ITEMS.length,items:ITEMS});
        // Chọn sâu: gửi Ruby, nhớ trên máy; món bên trong thụt cấp, món trong bản sao dùng chung được đánh dấu.
        await page.locator('#auto-deep').click();
        ok('bật Chọn sâu: gửi Ruby đọc lại danh sách',(await last('rename_deep'))[1]==='true');
        await receive('items',{total:2,deep:true,items:[{id:70,name:'Tủ',definition:'Tủ',def_id:7,level:0,locked:false,shared:false},{id:71,name:'Cánh',definition:'Cánh',def_id:8,level:1,locked:false,shared:true}]});
        ok('chọn sâu: dòng phạm vi ghi gồm cả món bên trong',(await page.locator('#scope').innerText())==='2 món, gồm cả món bên trong');
        ok('món trong bản sao dùng chung có nhãn dùng chung',(await page.locator('.rn-row',{hasText:'Cánh'}).locator('.shared').count())===1);
        await receive('items',{total:2000,more:true,deep:true,items:ITEMS});
        ok('quá nhiều món: báo đang hiện các món đầu',(await page.locator('#scope').innerText())==='Đang hiện 6 món đầu tiên');
        await page.locator('#auto-deep').click();
        await receive('items',{total:ITEMS.length,items:ITEMS});
      }else{
        await page.locator('.rn-row').first().click();
        await page.locator('.set').nth(1).locator('.chip').first().click();
        await page.waitForTimeout(50);
        const texts=await page.evaluate(()=>{const out=[];const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);while(w.nextNode()){const n=w.currentNode;if(n.parentElement.closest('script,style'))continue;out.push(n.nodeValue.trim());}
          document.querySelectorAll('[placeholder],[title],[aria-label]').forEach(e=>['placeholder','title','aria-label'].forEach(a=>{if(e.hasAttribute(a))out.push(e.getAttribute(a));}));return out;});
        const data=new Set([...ITEMS.flatMap(i=>[i.name,i.definition]),...Object.values(TEMPLATES).flat(),'Tủ bếp trên 01','Tủ bếp trên 02','Tủ bếp trên 03']);
        const left=[...new Set(texts.filter(t=>t&&VIET.test(t)&&!data.has(t)&&![...data].some(d=>d&&t.includes(d))))];
        ok('[en] không còn chữ tiếng Việt của giao diện'+(left.length?': '+left.join(' | '):''),left.length===0);
        for(const text of ['Đã đổi tên 5 món và ẩn đi (Edit > Unhide để hiện lại). Bấm Ctrl+Z để hoàn tác.','Đã đổi tên 2 món. Bấm Ctrl+Z để hoàn tác.','Danh sách đã cũ. Hãy chọn lại các món trong SketchUp.',
          'Có món bị khóa, không đổi tên được. Hãy mở khóa hoặc bỏ chọn món đó.','Có món không còn trong model. Hãy chọn lại các món cần đổi tên.','Đã mở file SketchUp khác. Hãy chọn lại các món cần đổi tên.',
          'Tên mới không được để trống.','Tên mới dài quá 200 ký tự.','Tên mới có ký tự điều khiển.','Dữ liệu đổi tên không hợp lệ.','Không có món nào cần đổi tên.','Không lưu được mẫu tên trên máy này.',
          'Không thực hiện được thao tác. Hãy chọn lại các món và thử lại.','Các món nằm ở cấp lồng khác nhau nên SketchUp chỉ chọn món cuối.','Dữ liệu chọn món không hợp lệ.']){
          await receive('message',{text});await page.waitForTimeout(10);
          const shown=await page.locator('#status').innerText();
          if(VIET.test(shown))fail('[en] chưa dịch thông báo: '+shown);
        }
        pass('[en] đã thử dịch các thông báo của Ruby');
        await receive('items',{total:3000,more:true,items:ITEMS});await page.waitForTimeout(20);
        ok('[en] dịch dòng phạm vi khi bị cắt bớt',!VIET.test(await page.locator('#scope').innerText()));
        await receive('items',{total:2,deep:true,items:[{id:70,name:'Tủ',definition:'Tủ',def_id:7,level:0,locked:false,shared:false},{id:71,name:'Cánh',definition:'Cánh',def_id:8,level:1,locked:false,shared:true}]});
        await page.locator('#auto-deep').click();await page.locator('#auto-deep').click();await page.waitForTimeout(20);
        ok('[en] dịch phạm vi chọn sâu, nhãn dùng chung, thông báo chọn sâu',!VIET.test(await page.locator('#scope').innerText())&&!VIET.test(await page.locator('#status').innerText())&&!VIET.test(await page.locator('.shared').innerText())&&!VIET.test(await page.locator('.shared').getAttribute('title')));
        await receive('items',{total:ITEMS.length,items:ITEMS});
      }
      ok(`[${lang}] không có lỗi JavaScript`+(errors.length?': '+errors.join(' | '):''),errors.length===0);
      if(shots){
        for(const theme of ['light','dark']){
          await page.evaluate(t=>document.documentElement.setAttribute('data-theme',t),theme);
          await page.waitForTimeout(400); // chờ hiệu ứng đổi màu (150 / 180 / 220 ms) xong
          await page.screenshot({path:path.join(shots,`rename_${lang}_${theme}.png`)});
        }
      }
      await page.close();
    }
  }finally{await browser.close();}
})();
