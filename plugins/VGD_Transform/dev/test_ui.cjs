// Test giao diện VGD Transform (html/index.html, app.js) theo hộp Transform Type-In của 3ds Max:
// ô Tuyệt đối hiện giá trị hiện tại và chỉ gửi ô đã sửa, ô Tương đối về 0 sau khi áp dụng, tâm và hệ trục,
// nút ▲▼ (bấm, kéo, Ctrl / Alt, chuột phải), kéo trực tiếp (live_start / live / live_end), Enter áp dụng luôn.
// Chạy: node dev/test_ui.cjs (từ plugins/VGD_Transform). Đặt VGD_PLAYWRIGHT_MODULE nếu Playwright không cài local.
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
let failed = 0;
const ok = (cond, msg) => { console.log((cond ? 'PASS  ' : 'FAIL  ') + msg); if (!cond) { failed++; process.exitCode = 1; } };

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.VGD_BROWSER_CHANNEL || undefined, ignoreDefaultArgs: ['--hide-scrollbars'] });
  try {
    const page = await browser.newPage({ viewport: { width: 460, height: 640 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      window.calls = [];
      window.sketchup = new Proxy({}, { get: (_, name) => (...args) => window.calls.push({ name, args }) });
    });
    await page.goto(pathToFileURL(path.resolve(__dirname, '../runtime/vgd_transform/html/index.html')).href);
    const receive = (event, data) => page.evaluate(([e, d]) => window.VGD.receive(e, d), [event, data]);
    const callNames = () => page.evaluate(() => window.calls.map(c => c.name));
    const lastCall = name => page.evaluate(n => { const c = window.calls.filter(x => x.name === n).pop(); return c ? JSON.parse(c.args[0] || '""') : null; }, name);
    const clear = () => page.evaluate(() => { window.calls.length = 0; });
    const visible = sel => page.locator(sel).isVisible();
    const value = id => page.locator(`#${id}`).inputValue();
    // Bấm / kéo trên nút ▲▼ cạnh ô nhập (sự kiện con trỏ giả lập)
    const pointer = (id, which, type, init = {}) => page.evaluate(([i, w, t, o]) => {
      const button = document.getElementById(i).parentElement.querySelector(`button.${w}`);
      button.dispatchEvent(new PointerEvent(t, Object.assign({ bubbles: true, pointerId: 1, button: t === 'pointerdown' ? 0 : -1, buttons: t === 'pointerup' ? 0 : 1, clientY: 100 }, o)));
    }, [id, which, type, init]);
    const click = async (id, which, init = {}) => { await pointer(id, which, 'pointerdown', init); await pointer(id, which, 'pointerup', init); };
    const rightClick = (id, which) => page.evaluate(([i, w]) => {
      document.getElementById(i).parentElement.querySelector(`button.${w}`).dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true, button: 2 }));
    }, [id, which]);
    const state = { unit: 'mm', unit_known: true, count: 2, skipped: 1, origin: [1000, null, 300], center: [1500, 500, 650], scale: [2, 1, 1] };

    ok((await callNames()).includes('ready'), 'mở cửa sổ: gửi ready để Ruby gửi trạng thái');
    ok((await page.locator('#note').innerText()) === '', 'đáy bảng không có chữ mặc định');
    ok((await page.locator('[title]:not(#theme)').count()) === 0, 'không còn chú thích title (ghi chú chuyển xuống đáy bảng; nút theme do theme chung đặt)');
    ok(await page.locator('#lock').isDisabled(), 'chưa có trạng thái lựa chọn: nút khóa bị tắt');
    ok((await page.locator('.tabs .tab svg').count()) === 3 && (await page.locator('.tab[aria-label="Dời (Move)"]').count()) === 1 && (await page.locator('.tab[aria-label="Xoay (Rotate)"]').count()) === 1, 'ba nút công cụ là icon (Dời, Xoay, Scale), có tên cho trình đọc màn hình');
    await receive('tool', { tool: 'scale' });
    ok((await visible('section[data-tool="scale"]')) && (await page.locator('.tab[aria-selected="true"]').getAttribute('data-tab')) === 'scale', 'mở từ nút Scale trên thanh công cụ: cửa sổ chọn sẵn Scale');
    await receive('tool', { tool: 'move' });
    await page.click('#live-label');
    const liveOff = await page.locator('#live').getAttribute('aria-checked');
    await page.click('#live-label');
    ok(liveOff === 'false' && (await page.locator('#live').getAttribute('aria-checked')) === 'true', 'bấm chữ "Trực tiếp" cũng bật / tắt nút gạt');
    await receive('state', state);
    const status = await page.locator('#status').innerText();
    const statusTitle = await page.locator('#status').getAttribute('data-note');
    ok(status === 'mm · 2 món · bỏ 1' && statusTitle.includes('2 món đang chọn') && statusTitle.includes('bỏ qua 1 đối tượng'), 'dòng trạng thái ngắn (mm · 2 món · bỏ 1), câu đầy đủ khi rê chuột');

    // Ghi chú ở đáy bảng: rê chuột hiện ghi chú, rời đi thì về thông báo
    await page.hover('.box[data-panel="move_off"] h3');
    ok((await page.locator('#note').innerText()).startsWith('Tương đối: dời thêm') && (await page.locator('#note').getAttribute('class')).includes('hint'), 'rê chuột lên khung: đáy bảng hiện ghi chú của khung');
    await page.hover('#pivot');
    ok((await page.locator('#note').innerText()).startsWith('Tâm:'), 'rê chuột lên ô chọn Tâm: hiện ghi chú Tâm');
    await page.hover('#move_abs-x');
    await page.evaluate(() => window.VGD.receive('message', { text: 'Đã biến đổi 1 món.' }));
    ok((await page.locator('#note').innerText()) === 'Đã biến đổi 1 món.', 'thông báo mới hiện ngay cả khi chuột đang trên khung');
    await page.hover('.box[data-panel="move_off"] h3');
    await page.mouse.move(2, 2);
    ok((await page.locator('#note').innerText()) === 'Đã biến đổi 1 món.', 'rời chuột khỏi chỗ có ghi chú: về thông báo gần nhất');

    // Nút khóa (như Lock của SketchUp)
    await receive('state', { ...state, lock: 'all' });
    ok(!(await page.locator('#lock').isDisabled()) && (await page.locator('#lock').getAttribute('aria-pressed')) === 'true' && (await page.locator('#lock').getAttribute('data-state')) === 'all', 'lựa chọn đã khóa hết: nút khóa bật, ổ đóng');
    await receive('state', { ...state, lock: 'mixed' });
    ok((await page.locator('#lock').getAttribute('aria-pressed')) === 'mixed', 'lựa chọn lẫn lộn: nút khóa ở trạng thái lẫn lộn');
    await clear();
    await page.click('#lock');
    ok((await callNames()).join(',') === 'lock' && (await visible('section[data-tool="move"]')), 'bấm nút khóa: gửi lệnh lock xuống Ruby, không đổi công cụ đang mở');
    await receive('state', { ...state, lock: 'none' });
    ok((await page.locator('#lock').getAttribute('aria-pressed')) === 'false' && (await page.locator('#lock .shackle-open').isVisible()) && !(await page.locator('#lock .shackle-closed').isVisible()), 'không món nào khóa: ổ mở');
    await page.mouse.move(2, 2);

    // Ô Tuyệt đối hiện giá trị hiện tại (như 3ds Max)
    ok((await value('move_abs-x')) === '1000' && (await value('move_abs-y')) === '' && (await value('move_abs-z')) === '300', 'Tuyệt đối, tâm điểm gốc: hiện điểm gốc chung, trục khác nhau để trống');
    ok((await page.locator('#move_abs-y').getAttribute('placeholder')) === 'khác nhau', 'trục mà các món khác nhau: ghi "khác nhau"');
    await page.selectOption('#pivot', 'selection');
    ok((await value('move_abs-x')) === '1500' && (await value('move_abs-y')) === '500', 'đổi tâm sang cả lựa chọn: ô Tuyệt đối hiện tâm hộp bao');
    ok((await value('scale_abs-x')) === '2' && (await value('scale_abs-y')) === '1', 'Scale tuyệt đối hiện tỉ lệ hiện tại');
    await receive('state', { ...state, unit_known: false, count: 0, skipped: 0, origin: null, center: null, scale: null });
    ok((await page.locator('#status').getAttribute('data-note')).includes('tạm dùng mm') && (await page.locator('#status').innerText()).startsWith('mm?') && (await page.locator('#move_abs-x').getAttribute('placeholder')) === '—', 'đơn vị lạ được báo; không chọn món thì ô Tuyệt đối trống');
    await receive('state', state);

    // Enter ở ô Tuyệt đối: chỉ gửi ô đã sửa
    await page.fill('#move_abs-x', '0');
    await clear();
    await page.press('#move_abs-x', 'Enter');
    const abs = await lastCall('apply');
    ok(abs && abs.tool === 'move_abs' && abs.values.x === '0' && abs.values.y === '' && abs.values.z === '' && abs.pivot === 'selection', 'Enter ở Tuyệt đối: gửi ô đã sửa, ô không sửa để trống (giữ), kèm tâm');
    await receive('done', { moved: 2, skipped: 1, tool: 'move_abs' });
    ok((await page.locator('#note').innerText()) === 'Đã biến đổi 2 món. Bỏ qua 1 đối tượng không phải group / component.', 'sau khi áp dụng: báo số món và số bị bỏ qua');
    await receive('state', { ...state, center: [0, 500, 650] });
    ok((await value('move_abs-x')) === '0', 'sau khi áp dụng: ô Tuyệt đối hiện giá trị mới');

    // Nhập số, Enter, rồi gõ số khác: số mới thay hẳn số cũ (200 Enter, gõ 300 Enter -> 300, không phải 200300)
    await page.fill('#move_abs-x', '200');
    await page.keyboard.press('Enter');
    await receive('done', { moved: 2, skipped: 0, tool: 'move_abs' });
    await receive('state', { ...state, center: [200, 500, 650] });
    ok((await value('move_abs-x')) === '200', 'sau Enter: ô Tuyệt đối hiện giá trị đã áp dụng (200)');
    await page.keyboard.type('300');
    ok((await value('move_abs-x')) === '300', 'gõ số mới ngay sau Enter: thay hẳn số cũ (300, không phải 200300)');
    await clear();
    await page.keyboard.press('Enter');
    const again = await lastCall('apply');
    ok(again && again.values.x === '300', 'Enter lần hai gửi đúng số mới (300)');
    await receive('done', { moved: 2, skipped: 0, tool: 'move_abs' });
    await receive('state', { ...state, center: [300, 500, 650] });
    await page.keyboard.press('Backspace');
    ok((await value('move_abs-x')) === '', 'bấm Backspace ngay sau Enter: xóa cả số cũ để nhập lại');
    await page.fill('#move_abs-x', '300');
    await page.keyboard.press('Enter');
    await receive('done', { moved: 2, skipped: 0, tool: 'move_abs' });
    await receive('state', { ...state, center: [300, 500, 650] });
    await page.keyboard.press('End');
    await page.keyboard.type('5');
    ok((await value('move_abs-x')) === '3005', 'đã điều hướng bằng phím (End) sau Enter: giữ số cũ để sửa tiếp (3005)');
    await receive('state', { ...state, center: [0, 500, 650] });
    await page.evaluate(() => { const input = document.getElementById('move_abs-x'); delete input.dataset.dirty; input.value = '0'; input.blur(); });

    // Tương đối: hệ trục, Enter, tự về 0
    await page.selectOption('#coord', 'local');
    ok((await page.locator('[data-panel="move_off"] h3').innerText()) === 'Tương đối · Local', 'đổi hệ trục: tiêu đề khung ghi Local');
    await page.fill('#move_off-x', '1m');
    await clear();
    await page.press('#move_off-x', 'Enter');
    const off = await lastCall('apply');
    ok(off && off.tool === 'move_off' && off.values.x === '1m' && off.coord === 'local', 'Enter ở Tương đối: gửi ô có đơn vị nguyên văn và hệ trục');
    await receive('done', { moved: 2, skipped: 0, tool: 'move_off' });
    ok((await value('move_off-x')) === '', 'sau khi áp dụng: ô Tương đối về 0 (Enter lần nữa không dời thêm)');
    await page.selectOption('#coord', 'world');

    // Nút ▲▼ (xem trực tiếp tắt)
    await page.click('#live');
    ok((await page.locator('#live').getAttribute('aria-checked')) === 'false', 'tắt "Xem trực tiếp khi kéo"');
    await clear();
    await click('move_off-y', 'up');
    ok((await value('move_off-y')) === '1', '▲ trên ô trống: thành 1 (bước 1 mm)');
    await click('move_off-y', 'down'); await click('move_off-y', 'down');
    ok((await value('move_off-y')) === '-1', '▼ hai lần: -1');
    await click('move_off-y', 'up', { ctrlKey: true });
    ok((await value('move_off-y')) === '9', 'Ctrl + ▲: bước ×10');
    await click('move_off-y', 'up', { altKey: true });
    ok((await value('move_off-y')) === '9.1', 'Alt + ▲: bước ×0,1');
    ok(!(await callNames()).some(n => n.startsWith('live')), 'xem trực tiếp tắt: ▲▼ chỉ đổi số, không gửi gì xuống Ruby');
    await page.fill('#move_off-z', '5mm');
    await click('move_off-z', 'up');
    ok((await value('move_off-z')) === '6mm', '▲ giữ đơn vị đã gõ: 5mm thành 6mm');
    await pointer('move_off-z', 'up', 'pointerdown', { clientY: 100 });
    await pointer('move_off-z', 'up', 'pointermove', { clientY: 80 });
    await pointer('move_off-z', 'up', 'pointerup', { clientY: 80 });
    ok((await value('move_off-z')) === '16mm', 'kéo lên 20 px trên ▲▼: tăng 10 bước từ giá trị lúc nhấn (6mm thành 16mm)');
    await page.evaluate(() => {
      const input = document.getElementById('move_off-z');
      input.dispatchEvent(new PointerEvent('pointerdown', { clientY: 100, buttons: 1, bubbles: true }));
      input.dispatchEvent(new PointerEvent('pointermove', { clientY: 50, buttons: 1, bubbles: true }));
    });
    ok((await value('move_off-z')) === '16mm', 'kéo trên ô chữ không đổi số (ô chữ để gõ, kéo trên ▲▼ như 3ds Max)');
    await rightClick('move_off-y', 'up');
    ok((await value('move_off-y')) === '', 'chuột phải ▲▼ ở ô Tương đối: về 0');
    await rightClick('move_abs-z', 'down');
    ok((await value('move_abs-z')) === '0', 'chuột phải ▲▼ ở ô Tuyệt đối: về 0');
    await receive('state', { ...state, unit: 'm' });
    await page.fill('#move_off-x', '');
    await click('move_off-x', 'up');
    ok((await value('move_off-x')) === '0.001', 'file đơn vị m: bước của ô độ dài là 0,001 m (1 mm)');
    await page.fill('#move_off-x', '');
    await receive('state', state);

    // Kéo trực tiếp (bật lại)
    await page.click('#live');
    await clear();
    await click('move_off-x', 'up');
    const names = await callNames();
    const live = await lastCall('live');
    ok(names.join(',') === 'live_start,live,live_end' && live.tool === 'move_off' && live.values.x === '1', 'xem trực tiếp: bấm ▲ gửi live_start, live (giá trị mới), live_end');
    ok((await value('move_off-x')) === '', 'xem trực tiếp: thả nút thì ô Tương đối về 0 (món đã ở chỗ mới)');
    await clear();
    await click('move_abs-x', 'up');
    const liveAbs = await lastCall('live');
    ok(liveAbs && liveAbs.tool === 'move_abs' && liveAbs.values.x === '1501' && liveAbs.values.y === '', 'xem trực tiếp ở Tuyệt đối (tâm cả lựa chọn 1500): gửi 1501, chỉ ô đang kéo');
    // Kéo trực tiếp: nhiều giá trị trong cùng một nhịp chỉ gửi giá trị mới nhất (Ruby cũng gộp lại), không chờ xác nhận từng nhịp
    await clear();
    await pointer('move_off-x', 'up', 'pointerdown');
    await page.waitForTimeout(100);
    await page.evaluate(() => {
      const arrow = document.getElementById('move_off-x').parentElement.querySelector('button.up');
      for (const y of [90, 80]) arrow.dispatchEvent(new PointerEvent('pointermove', { bubbles: true, pointerId: 1, buttons: 1, clientY: y }));
    });
    await page.waitForTimeout(100);
    const liveCount = () => page.evaluate(() => window.calls.filter(c => c.name === 'live').length);
    const latest = await lastCall('live');
    ok((await liveCount()) === 2 && latest.values.x === '10', 'hai giá trị kéo trong một nhịp: chỉ gửi một cập nhật với giá trị mới nhất (10)');
    ok(!(await callNames()).includes('live_ack'), 'không có xác nhận từng nhịp giữa giao diện và Ruby');
    await pointer('move_off-x', 'up', 'pointerup');
    ok((await callNames()).slice(-2).join(',') === 'live,live_end', 'thả nút: gửi giá trị cuối rồi live_end');
    // Ctrl+Z / Ctrl+Y trong cửa sổ: giao cho SketchUp (phím tắt không tới SketchUp khi tiêu điểm ở cửa sổ này); ô đang gõ dở thì để trình duyệt hoàn tác chữ
    await clear();
    await page.keyboard.press('Control+z');
    await page.keyboard.press('Control+y');
    await page.keyboard.press('Control+Shift+z');
    ok((await callNames()).join(',') === 'undo,redo,redo', 'Ctrl+Z gửi undo, Ctrl+Y và Ctrl+Shift+Z gửi redo');
    await clear();
    await page.focus('#move_off-x');
    await page.keyboard.type('5');
    await page.keyboard.press('Control+z');
    ok(!(await callNames()).includes('undo'), 'đang gõ dở trong ô số: Ctrl+Z để cho trình duyệt hoàn tác chữ, không gửi undo');
    await page.fill('#move_off-x', '');
    await page.evaluate(() => { const input = document.getElementById('move_off-x'); delete input.dataset.dirty; input.blur(); });
    await page.selectOption('#pivot', 'item');
    await receive('state', state);
    await clear();
    await click('move_abs-y', 'up');
    ok((await page.locator('#note').innerText()).includes('khác nhau') && !(await callNames()).includes('live_start'), 'ô Tuyệt đối "khác nhau": ▲▼ không chạy, nhắc gõ số');

    // Xoay và Scale
    await page.click('.tab[data-tab="rotate"]');
    ok((await visible('section[data-tool="rotate"]')) && (await visible('.settings')), 'tab Xoay: hiện khung Xoay; tâm và hệ trục luôn hiện');
    await page.fill('#rotate-z', '90');
    await page.selectOption('#pivot', 'world');
    await page.selectOption('#coord', 'local');
    await clear();
    await page.press('#rotate-z', 'Enter');
    const rot = await lastCall('apply');
    ok(rot && rot.tool === 'rotate' && rot.values.z === '90' && rot.pivot === 'world' && rot.coord === 'local', 'xoay: Enter gửi góc, tâm, hệ trục');
    // Xoay tuyệt đối: hiện góc hiện tại của món; gõ 0 hoặc bấm chuột phải ▲▼ để quay về hướng gốc
    ok(await visible('.box[data-panel="rotate_abs"]'), 'tab Xoay: có khung Tuyệt đối (góc hiện tại của món)');
    await receive('state', { ...state, angles: [30, 20, 40] });
    ok((await value('rotate_abs-x')) === '30' && (await value('rotate_abs-y')) === '20' && (await value('rotate_abs-z')) === '40', 'xoay tuyệt đối: ô hiện góc X, Y, Z hiện tại của món');
    await receive('state', { ...state, angles: [30, null, 40] });
    ok((await page.locator('#rotate_abs-y').getAttribute('placeholder')) === 'khác nhau', 'xoay tuyệt đối: các món khác nhau ở trục nào thì ô trục đó ghi "khác nhau"');
    await receive('state', { ...state, angles: [30, 20, 40] });
    await page.fill('#rotate_abs-z', '0');
    await clear();
    await page.press('#rotate_abs-z', 'Enter');
    const rabs = await lastCall('apply');
    ok(rabs && rabs.tool === 'rotate_abs' && rabs.values.z === '0' && rabs.values.x === '' && rabs.values.y === '' && rabs.pivot === 'world', 'xoay tuyệt đối: Enter chỉ gửi ô đã sửa (Z = 0), ô khác để trống = giữ góc');
    await receive('done', { moved: 1, skipped: 0, tool: 'rotate_abs' });
    await receive('state', { ...state, angles: [30, 20, 0] });
    await clear();
    await rightClick('rotate_abs-x', 'up');
    const rabsReset = await lastCall('apply');
    ok((await value('rotate_abs-x')) === '0' && rabsReset && rabsReset.tool === 'rotate_abs' && rabsReset.values.x === '0', 'chuột phải ▲▼ ở ô Xoay tuyệt đối: về 0 và áp dụng ngay (quay về hướng gốc theo trục đó)');
    await receive('done', { moved: 1, skipped: 0, tool: 'rotate_abs' });
    await receive('state', { ...state, angles: [0, 20, 0] });
    await page.click('.tab[data-tab="scale"]');
    ok((await visible('.box[data-panel="scale_abs"]')) && (await visible('#scale-one')) && !(await visible('#scale-xyz')), 'tab Scale: khung Tuyệt đối và Tương đối (mặc định Đều)');
    await page.fill('#scale_abs-x', '1');
    await clear();
    await page.press('#scale_abs-x', 'Enter');
    const sabs = await lastCall('apply');
    ok(sabs && sabs.tool === 'scale_abs' && sabs.values.x === '1' && sabs.values.y === '', 'scale tuyệt đối: chỉ gửi ô đã sửa');
    await page.uncheck('#scale-uniform');
    ok((await visible('#scale-xyz')) && !(await visible('#scale-one')), 'bỏ Đều: hiện ba ô X, Y, Z');
    await page.fill('#scale-x', '1000mm');
    await clear();
    await page.press('#scale-x', 'Enter');
    const srel = await lastCall('apply');
    ok(srel && srel.tool === 'scale' && srel.uniform === false && srel.values.x === '1000mm' && srel.coord === 'local', 'scale không đều: kích thước đích có đơn vị, kèm hệ trục');

    // Thông báo
    await receive('message', { text: 'Độ dời bằng 0, không cần dời.' });
    ok(!(await page.locator('#note').getAttribute('class')).includes('error'), '"không có gì để làm" hiện như thông báo thường');
    await receive('message', { error: 'Tủ A đang khóa.' });
    ok((await page.locator('#note').getAttribute('class')).includes('error'), 'lỗi hiện màu đỏ');
    ok((await page.locator('#items').count()) === 0 && (await page.locator('#result').count()) === 0 && (await page.locator('[data-action]').count()) === 0, 'gọn: không danh sách món, không bảng kết quả, không nút Xem trước / Áp dụng');
    ok(errors.length === 0, 'không có lỗi JavaScript' + (errors.length ? ': ' + errors.join(' | ') : ''));
  } finally {
    await browser.close();
  }
  console.log(failed ? `${failed} lỗi` : 'Done');
})().catch(e => { console.log('FAIL  ' + e.message); process.exit(1); });
