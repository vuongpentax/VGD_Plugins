// Test giao diện VGD Position (html/index.html, app.js): tab Dời / Xoay / Scale, ô số (▲▼, kéo), xem trước trước khi áp dụng.
// Chạy: node dev/test_ui.cjs (từ plugins/VGD_Position). Đặt VGD_PLAYWRIGHT_MODULE nếu Playwright không cài local.
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
    await page.goto(pathToFileURL(path.resolve(__dirname, '../runtime/vgd_position/html/index.html')).href);
    const receive = (event, data) => page.evaluate(([e, d]) => window.VGD.receive(e, d), [event, data]);
    const calls = name => page.evaluate(n => window.calls.filter(c => c.name === n).map(c => JSON.parse(c.args[0] || '""')), name);
    const lastCall = async name => (await calls(name)).pop();
    const clear = () => page.evaluate(() => { window.calls.length = 0; });
    const visible = sel => page.locator(sel).isVisible();
    const applyDisabled = panel => page.locator(`button[data-action="apply"][data-panel="${panel}"]`).isDisabled();
    // Nút ▲▼ nằm trong khung .spin ngay cạnh ô nhập
    const arrow = (inputId, which) => page.locator(`#${inputId}`).locator('xpath=..').locator(`button.${which}`);

    ok(await page.evaluate(() => window.calls.some(c => c.name === 'ready')), 'mở cửa sổ: gửi ready để Ruby gửi danh sách món');

    await receive('items', {
      items: [{ index: 0, name: 'Tủ A', origin: ['1000', '2000', '300'], locked: false }, { index: 1, name: 'Tủ khóa', origin: ['0', '0', '0'], locked: true }],
      count: 2, unit: 'mm',
    });
    ok((await page.locator('#count').innerText()) === '2 món đang chọn', 'hiển thị số món đang chọn');
    ok((await page.locator('#unit').innerText()).includes('Đơn vị của file: mm'), 'hiển thị đơn vị của file');
    ok((await page.locator('#items li').count()) === 2 && (await page.locator('#items li.locked .badge').innerText()) === 'khóa', 'món khóa được đánh dấu');
    ok((await page.locator('.tab[aria-selected="true"]').getAttribute('data-tab')) === 'move', 'mặc định chọn công cụ Dời');
    ok((await page.locator('button.up').count()) >= 8, 'mọi ô số có nút ▲▼');

    // Tab: chuyển công cụ, tâm xoay chỉ hiện với Xoay và Scale
    ok(!(await visible('#pivot-row')) && (await visible('section[data-tool="move"]')) && !(await visible('section[data-tool="rotate"]')), 'công cụ Dời: hiện khung Dời, ẩn tâm xoay');
    await page.click('.tab[data-tab="rotate"]');
    ok((await visible('section[data-tool="rotate"]')) && !(await visible('section[data-tool="move"]')) && (await visible('#pivot-row')), 'công cụ Xoay: hiện khung Xoay và tâm xoay');
    await page.click('.tab[data-tab="scale"]');
    ok((await visible('section[data-tool="scale"]')) && (await visible('#scale-uniform')) && !(await visible('#scale-nonuniform')), 'công cụ Scale mặc định là Đều: chỉ một ô hệ số');
    await page.click('.tab[data-tab="move"]');

    // Dời: xem trước rồi mới áp dụng; đổi ô thì khóa lại
    ok(await applyDisabled('move_abs') && await applyDisabled('move_off'), 'chưa xem trước: cả hai nút Áp dụng đều bị khóa');
    await page.fill('#move_abs-x', '1500');
    await clear();
    await page.click('button[data-action="preview"][data-panel="move_abs"]');
    const sent = await lastCall('preview');
    ok(sent && sent.tool === 'move_abs' && sent.values.x === '1500' && sent.values.y === '' && sent.values.z === '', 'xem trước gửi đúng công cụ Dời tuyệt đối và các ô X, Y, Z');
    await receive('preview', { moves: [{ index: 0, name: 'Tủ A', text: 'dời ΔX 500 mm → điểm gốc (1500 mm, 2000 mm, 300 mm)' }] });
    ok(!(await applyDisabled('move_abs')) && (await applyDisabled('move_off')), 'sau xem trước: chỉ khung vừa xem trước được bật Áp dụng');
    ok((await page.locator('#result').innerText()).includes('ΔX 500 mm'), 'kết quả xem trước hiện độ dời');
    await page.fill('#move_abs-y', '10');
    ok(await applyDisabled('move_abs'), 'đổi ô nhập sau khi xem trước: Áp dụng bị khóa lại');

    await page.click('button[data-action="preview"][data-panel="move_abs"]');
    await receive('preview', { moves: [{ index: 0, name: 'Tủ A', text: 'dời ΔX 500 mm, ΔY 10 mm' }] });
    await clear();
    await page.click('button[data-action="apply"][data-panel="move_abs"]');
    const applied = await lastCall('apply');
    ok(applied && applied.tool === 'move_abs' && applied.values.x === '1500' && applied.values.y === '10', 'áp dụng gửi đúng các ô đã xem trước');
    await receive('done', { moved: 1 });
    ok((await page.locator('#message').innerText()).startsWith('Đã biến đổi 1 món.'), 'sau khi biến đổi: báo số món đã biến đổi');
    ok(await applyDisabled('move_abs'), 'sau khi biến đổi: Áp dụng bị khóa cho đến khi xem trước lại');

    // Dời tương đối có đơn vị gõ thêm
    await page.fill('#move_off-x', '1m');
    await clear();
    await page.click('button[data-action="preview"][data-panel="move_off"]');
    const off = await lastCall('preview');
    ok(off && off.tool === 'move_off' && off.values.x === '1m', 'ô nhập có đơn vị (1m) được gửi nguyên văn để Ruby đổi');

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

    // Xoay: góc và tâm xoay được gửi đi
    await page.click('.tab[data-tab="rotate"]');
    await page.fill('#rotate-z', '90');
    await page.selectOption('#pivot', 'selection');
    await clear();
    await page.click('button[data-action="preview"][data-panel="rotate"]');
    const rot = await lastCall('preview');
    ok(rot && rot.tool === 'rotate' && rot.values.z === '90' && rot.pivot === 'selection', 'xoay: gửi góc Z và tâm cả lựa chọn');
    await receive('preview', { moves: [{ index: 0, name: 'Tủ A', text: 'xoay 90° quanh Z' }] });
    ok(!(await applyDisabled('rotate')), 'xoay: sau xem trước thì Áp dụng được bật');
    await page.selectOption('#pivot', 'world');
    ok(await applyDisabled('rotate'), 'xoay: đổi tâm xoay sau khi xem trước thì Áp dụng bị khóa');

    // Scale: đều (một ô) và không đều (ba ô)
    await page.click('.tab[data-tab="scale"]');
    await page.fill('#scale-u', '2');
    await clear();
    await page.click('button[data-action="preview"][data-panel="scale"]');
    const uni = await lastCall('preview');
    ok(uni && uni.tool === 'scale' && uni.uniform === true && uni.values.x === '2', 'scale đều: gửi một hệ số');
    await page.click('input[name="scale-mode"][value="nonuniform"]');
    ok((await visible('#scale-nonuniform')) && !(await visible('#scale-uniform')), 'chọn Không đều: hiện ba ô X, Y, Z');
    await page.fill('#scale-x', '2');
    await page.fill('#scale-z', '0.5');
    await clear();
    await page.click('button[data-action="preview"][data-panel="scale"]');
    const non = await lastCall('preview');
    ok(non && non.uniform === false && non.values.x === '2' && non.values.z === '0.5' && non.values.y === '', 'scale không đều: gửi ba ô X, Y, Z');
    ok(await applyDisabled('scale'), 'scale: đổi kiểu sau khi xem trước thì Áp dụng bị khóa');

    // Lỗi nhập: báo đỏ
    await receive('message', { error: 'Tọa độ "abc" không phải số hoặc đơn vị không hỗ trợ.' });
    ok((await page.locator('#message').innerText()).includes('không phải số') && (await page.locator('#message').getAttribute('class')).includes('error'), 'lỗi nhập hiện thông báo đỏ');

    ok(errors.length === 0, 'không có lỗi JavaScript' + (errors.length ? ': ' + errors.join(' | ') : ''));
  } finally {
    await browser.close();
  }
  console.log(failed ? `${failed} lỗi` : 'Done');
})().catch(e => { console.log('FAIL  ' + e.message); process.exit(1); });
