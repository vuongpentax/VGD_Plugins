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
    await receive('state', state);
    const status = await page.locator('#status').innerText();
    ok(status.includes('2 món') && status.includes('đơn vị file: mm') && status.includes('bỏ qua 1 đối tượng'), 'dòng trạng thái: số món, đơn vị, số đối tượng bị bỏ qua');

    // Ô Tuyệt đối hiện giá trị hiện tại (như 3ds Max)
    ok((await value('move_abs-x')) === '1000' && (await value('move_abs-y')) === '' && (await value('move_abs-z')) === '300', 'Tuyệt đối, tâm điểm gốc: hiện điểm gốc chung, trục khác nhau để trống');
    ok((await page.locator('#move_abs-y').getAttribute('placeholder')) === 'khác nhau', 'trục mà các món khác nhau: ghi "khác nhau"');
    await page.selectOption('#pivot', 'selection');
    ok((await value('move_abs-x')) === '1500' && (await value('move_abs-y')) === '500', 'đổi tâm sang cả lựa chọn: ô Tuyệt đối hiện tâm hộp bao');
    ok((await value('scale_abs-x')) === '2' && (await value('scale_abs-y')) === '1', 'Scale tuyệt đối hiện tỉ lệ hiện tại');
    await receive('state', { ...state, unit_known: false, count: 0, skipped: 0, origin: null, center: null, scale: null });
    ok((await page.locator('#status').innerText()).includes('tạm dùng mm') && (await page.locator('#move_abs-x').getAttribute('placeholder')) === '—', 'đơn vị lạ được báo; không chọn món thì ô Tuyệt đối trống');
    await receive('state', state);

    // Enter ở ô Tuyệt đối: chỉ gửi ô đã sửa
    await page.fill('#move_abs-x', '0');
    await clear();
    await page.press('#move_abs-x', 'Enter');
    const abs = await lastCall('apply');
    ok(abs && abs.tool === 'move_abs' && abs.values.x === '0' && abs.values.y === '' && abs.values.z === '' && abs.pivot === 'selection', 'Enter ở Tuyệt đối: gửi ô đã sửa, ô không sửa để trống (giữ), kèm tâm');
    await receive('done', { moved: 2, skipped: 1, tool: 'move_abs' });
    ok((await page.locator('#message').innerText()) === 'Đã biến đổi 2 món. Bỏ qua 1 đối tượng không phải group / component.', 'sau khi áp dụng: báo số món và số bị bỏ qua');
    await receive('state', { ...state, center: [0, 500, 650] });
    ok((await value('move_abs-x')) === '0', 'sau khi áp dụng: ô Tuyệt đối hiện giá trị mới');

    // Tương đối: hệ trục, Enter, tự về 0
    await page.selectOption('#coord', 'local');
    ok((await page.locator('[data-panel="move_off"] h3').innerText()) === 'Tương đối (riêng)', 'đổi hệ trục: tiêu đề khung ghi rõ (riêng)');
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
    await page.selectOption('#pivot', 'item');
    await receive('state', state);
    await clear();
    await click('move_abs-y', 'up');
    ok((await page.locator('#message').innerText()).includes('khác nhau') && !(await callNames()).includes('live_start'), 'ô Tuyệt đối "khác nhau": ▲▼ không chạy, nhắc gõ số');

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
    await page.click('.tab[data-tab="scale"]');
    ok((await visible('.box[data-panel="scale_abs"]')) && (await visible('#scale-uniform')) && !(await visible('#scale-nonuniform')), 'tab Scale: khung Tuyệt đối và Tương đối (mặc định Đều)');
    await page.fill('#scale_abs-x', '1');
    await clear();
    await page.press('#scale_abs-x', 'Enter');
    const sabs = await lastCall('apply');
    ok(sabs && sabs.tool === 'scale_abs' && sabs.values.x === '1' && sabs.values.y === '', 'scale tuyệt đối: chỉ gửi ô đã sửa');
    await page.click('input[name="scale-mode"][value="nonuniform"]');
    await page.fill('#scale-x', '1000mm');
    await clear();
    await page.press('#scale-x', 'Enter');
    const srel = await lastCall('apply');
    ok(srel && srel.tool === 'scale' && srel.uniform === false && srel.values.x === '1000mm' && srel.coord === 'local', 'scale không đều: kích thước đích có đơn vị, kèm hệ trục');

    // Thông báo
    await receive('message', { text: 'Độ dời bằng 0, không cần dời.' });
    ok(!(await page.locator('#message').getAttribute('class')).includes('error'), '"không có gì để làm" hiện như thông báo thường');
    await receive('message', { error: 'Tủ A đang khóa.' });
    ok((await page.locator('#message').getAttribute('class')).includes('error'), 'lỗi hiện màu đỏ');
    ok((await page.locator('#items').count()) === 0 && (await page.locator('#result').count()) === 0 && (await page.locator('[data-action="preview"]').count()) === 0, 'vẫn gọn: không danh sách món, không bảng kết quả, không nút Xem trước');
    ok(errors.length === 0, 'không có lỗi JavaScript' + (errors.length ? ': ' + errors.join(' | ') : ''));
  } finally {
    await browser.close();
  }
  console.log(failed ? `${failed} lỗi` : 'Done');
})().catch(e => { console.log('FAIL  ' + e.message); process.exit(1); });
