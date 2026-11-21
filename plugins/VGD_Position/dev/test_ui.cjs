// Test giao diện VGD Position (html/index.html, app.js): hiển thị món, món khóa, xem trước trước khi áp dụng.
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

    ok(await page.evaluate(() => window.calls.some(c => c.name === 'ready')), 'mở cửa sổ: gửi ready để Ruby gửi danh sách món');

    await receive('items', {
      items: [{ index: 0, name: 'Tủ A', origin: [1000, 2000, 300], locked: false }, { index: 1, name: 'Tủ khóa', origin: [0, 0, 0], locked: true }],
      count: 2,
    });
    ok((await page.locator('#count').innerText()) === '2 món', 'hiển thị số món đang chọn');
    ok((await page.locator('#items li').count()) === 2 && (await page.locator('#items li.locked .badge').innerText()) === 'khóa', 'món khóa được đánh dấu');
    ok((await page.locator('#mode').count()) === 0, 'không còn ô chọn chế độ');
    ok(await page.locator('#apply').isDisabled(), 'chưa xem trước: nút Áp dụng bị khóa');

    // Xem trước đúng với ô nhập hiện tại
    await page.fill('#x', '1500');
    await clear();
    await page.click('#preview');
    const sent = await lastCall('preview');
    ok(sent && !('mode' in sent) && sent.values.x === '1500' && sent.values.y === '' && sent.values.z === '', 'xem trước gửi đúng các ô X, Y, Z');
    await receive('preview', { moves: [{ index: 0, name: 'Tủ A', delta: [500, 0, 0], target: [1500, 2000, 300] }, { index: 1, name: 'Tủ B', delta: [500, 0, 0], target: [500, 0, 0] }] });
    ok(!(await page.locator('#apply').isDisabled()), 'sau khi xem trước: nút Áp dụng được bật');
    ok((await page.locator('#result').innerText()).includes('ΔX 500') && (await page.locator('#result').innerText()).includes('Tủ B'), 'kết quả xem trước hiện độ dời của từng món');

    // Đổi ô nhập thì phải xem trước lại
    await page.fill('#y', '10');
    ok(await page.locator('#apply').isDisabled(), 'đổi ô nhập sau khi xem trước: Áp dụng bị khóa lại');

    // Áp dụng: gửi đúng chế độ và ô nhập lúc xem trước
    await page.click('#preview');
    await receive('preview', { moves: [{ index: 0, name: 'Tủ A', delta: [500, 10, 0], target: [1500, 2010, 300] }] });
    await clear();
    await page.click('#apply');
    const applied = await lastCall('apply');
    ok(applied && applied.values.x === '1500' && applied.values.y === '10', 'áp dụng gửi đúng các ô đã xem trước');
    await receive('done', { moved: 1 });
    ok((await page.locator('#message').innerText()).startsWith('Đã dời 1 món.'), 'sau khi dời: báo số món đã dời');
    ok(await page.locator('#apply').isDisabled(), 'sau khi dời: Áp dụng lại bị khóa cho đến khi xem trước lại');

    // Lỗi nhập: báo đỏ, không làm gì
    await receive('message', { error: 'Tọa độ "abc" không phải số.' });
    ok((await page.locator('#message').innerText()).includes('không phải số') && (await page.locator('#message').getAttribute('class')).includes('error'), 'lỗi nhập hiện thông báo đỏ');

    ok(errors.length === 0, 'không có lỗi JavaScript' + (errors.length ? ': ' + errors.join(' | ') : ''));
  } finally {
    await browser.close();
  }
  console.log(failed ? `${failed} lỗi` : 'Done');
})().catch(e => { console.log('FAIL  ' + e.message); process.exit(1); });
