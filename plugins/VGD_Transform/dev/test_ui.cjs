// Test giao diện VGD Transform (html/index.html, app.js): ba tab, Enter áp dụng luôn, không còn xem trước / danh sách / bảng kết quả,
// ô số (▲▼, kéo), scale đều / không đều, ô có đơn vị.
// Chạy: node dev/test_ui.cjs (từ plugins/VGD_Transform). Đặt VGD_PLAYWRIGHT_MODULE nếu Playwright không cài local.
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require(process.env.VGD_PLAYWRIGHT_MODULE || 'playwright');
let failed = 0;
const ok = (cond, msg) => { console.log((cond ? 'PASS  ' : 'FAIL  ') + msg); if (!cond) { failed++; process.exitCode = 1; } };

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.VGD_BROWSER_CHANNEL || undefined, ignoreDefaultArgs: ['--hide-scrollbars'] });
  try {
    const page = await browser.newPage({ viewport: { width: 460, height: 600 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    // Ghi lại mọi lệnh gửi xuống Ruby (window.sketchup[name](json))
    await page.addInitScript(() => {
      window.calls = [];
      window.sketchup = new Proxy({}, { get: (_, name) => (...args) => window.calls.push({ name, args }) });
    });
    await page.goto(pathToFileURL(path.resolve(__dirname, '../runtime/vgd_transform/html/index.html')).href);
    const receive = (event, data) => page.evaluate(([e, d]) => window.VGD.receive(e, d), [event, data]);
    const calls = name => page.evaluate(n => window.calls.filter(c => c.name === n).map(c => JSON.parse(c.args[0] || '""')), name);
    const lastCall = async name => (await calls(name)).pop();
    const clear = () => page.evaluate(() => { window.calls.length = 0; });
    const visible = sel => page.locator(sel).isVisible();
    // Nút ▲▼ nằm trong khung .spin ngay cạnh ô nhập
    const arrow = (inputId, which) => page.locator(`#${inputId}`).locator('xpath=..').locator(`button.${which}`);

    ok(await page.evaluate(() => window.calls.some(c => c.name === 'ready')), 'mở cửa sổ: gửi ready để Ruby gửi đơn vị của file');
    await receive('unit', { unit: 'mm' });
    ok((await page.locator('#unit').innerText()).includes('Đơn vị của file: mm'), 'hiển thị đơn vị của file');

    // Bố cục gọn: không còn danh sách món, bảng kết quả hay nút xem trước
    ok((await page.locator('#items').count()) === 0 && (await page.locator('#count').count()) === 0, 'không còn danh sách món đang chọn');
    ok((await page.locator('#result').count()) === 0, 'không còn bảng kết quả');
    ok((await page.locator('button[data-action="preview"]').count()) === 0, 'không còn nút Xem trước');
    ok((await page.locator('button.up').count()) >= 8, 'mọi ô số có nút ▲▼');

    // Tab
    ok((await visible('section[data-tool="move"]')) && !(await visible('section[data-tool="rotate"]')) && !(await visible('#pivot-row')), 'mặc định Dời: hiện khung Dời, ẩn tâm xoay');
    await page.click('.tab[data-tab="rotate"]');
    ok((await visible('section[data-tool="rotate"]')) && (await visible('#pivot-row')), 'công cụ Xoay: hiện khung Xoay và tâm xoay');
    await page.click('.tab[data-tab="scale"]');
    ok((await visible('#scale-uniform')) && !(await visible('#scale-nonuniform')), 'công cụ Scale mặc định Đều: chỉ một ô hệ số');
    await page.click('.tab[data-tab="move"]');

    // Enter trong ô là áp dụng luôn
    await page.fill('#move_abs-x', '1500');
    await clear();
    await page.press('#move_abs-x', 'Enter');
    const applied = await lastCall('apply');
    ok(applied && applied.tool === 'move_abs' && applied.values.x === '1500' && applied.values.y === '' && applied.values.z === '', 'Enter trong ô Tuyệt đối: áp dụng ngay, gửi đúng X và các ô trống');
    await receive('done', { moved: 1 });
    ok((await page.locator('#message').innerText()).startsWith('Đã biến đổi 1 món.'), 'sau khi biến đổi: báo số món');

    // Nút Áp dụng cũng làm ngay
    await page.fill('#move_off-x', '1m');
    await clear();
    await page.click('button[data-action="apply"][data-panel="move_off"]');
    const off = await lastCall('apply');
    ok(off && off.tool === 'move_off' && off.values.x === '1m', 'nút Áp dụng Dời tương đối: gửi ô có đơn vị (1m) nguyên văn để Ruby đổi');

    // Ô số: nút ▲ tăng một bước, ▼ giảm, giữ đơn vị đã gõ, kéo lên xuống trên ô
    await page.fill('#move_off-y', '');
    await arrow('move_off-y', 'up').dispatchEvent('pointerdown');
    await arrow('move_off-y', 'up').dispatchEvent('pointerup');
    ok((await page.locator('#move_off-y').inputValue()) === '1', 'nút ▲: ô trống thành 1 (một bước)');
    await arrow('move_off-y', 'down').dispatchEvent('pointerdown');
    await arrow('move_off-y', 'down').dispatchEvent('pointerup');
    await arrow('move_off-y', 'down').dispatchEvent('pointerdown');
    await arrow('move_off-y', 'down').dispatchEvent('pointerup');
    ok((await page.locator('#move_off-y').inputValue()) === '-1', 'nút ▼: giảm xuống -1 sau hai lần');
    await page.fill('#move_off-z', '5mm');
    await arrow('move_off-z', 'up').dispatchEvent('pointerdown');
    await arrow('move_off-z', 'up').dispatchEvent('pointerup');
    ok((await page.locator('#move_off-z').inputValue()) === '6mm', 'nút ▲ giữ đơn vị đã gõ: 5mm thành 6mm');
    await page.evaluate(() => {
      const input = document.getElementById('move_off-z');
      input.dispatchEvent(new PointerEvent('pointerdown', { clientY: 100, buttons: 1, bubbles: true }));
      input.dispatchEvent(new PointerEvent('pointermove', { clientY: 80, buttons: 1, bubbles: true }));
      input.dispatchEvent(new PointerEvent('pointerup', { clientY: 80, buttons: 0, bubbles: true }));
    });
    ok((await page.locator('#move_off-z').inputValue()) === '16mm', 'kéo lên 20 px trên ô: tăng 10 bước (6mm thành 16mm)');

    // Xoay: Enter áp dụng với góc và tâm xoay
    await page.click('.tab[data-tab="rotate"]');
    await page.fill('#rotate-z', '90');
    await page.selectOption('#pivot', 'selection');
    await clear();
    await page.press('#rotate-z', 'Enter');
    const rot = await lastCall('apply');
    ok(rot && rot.tool === 'rotate' && rot.values.z === '90' && rot.pivot === 'selection', 'xoay: Enter áp dụng với góc Z và tâm cả lựa chọn');

    // Scale đều: một hệ số; Không đều: ba ô, có thể nhập kích thước đích có đơn vị
    await page.click('.tab[data-tab="scale"]');
    await page.fill('#scale-u', '2');
    await clear();
    await page.press('#scale-u', 'Enter');
    const uni = await lastCall('apply');
    ok(uni && uni.tool === 'scale' && uni.uniform === true && uni.values.x === '2', 'scale đều: Enter gửi một hệ số');
    await page.click('input[name="scale-mode"][value="nonuniform"]');
    ok((await visible('#scale-nonuniform')) && !(await visible('#scale-uniform')), 'chọn Không đều: hiện ba ô X, Y, Z');
    await page.fill('#scale-x', '1000mm');
    await clear();
    await page.press('#scale-x', 'Enter');
    const non = await lastCall('apply');
    ok(non && non.tool === 'scale' && non.uniform === false && non.values.x === '1000mm' && non.values.y === '' && non.values.z === '', 'scale không đều: Enter gửi kích thước đích 1000mm trên X, các ô trống để giữ');

    // Lỗi nhập: báo đỏ
    await receive('message', { error: 'Hệ số bằng 1 ở mọi trục, không đổi kích thước.' });
    ok((await page.locator('#message').innerText()).includes('không đổi kích thước') && (await page.locator('#message').getAttribute('class')).includes('error'), 'lỗi hiện thông báo đỏ');

    ok(errors.length === 0, 'không có lỗi JavaScript' + (errors.length ? ': ' + errors.join(' | ') : ''));
  } finally {
    await browser.close();
  }
  console.log(failed ? `${failed} lỗi` : 'Done');
})().catch(e => { console.log('FAIL  ' + e.message); process.exit(1); });
