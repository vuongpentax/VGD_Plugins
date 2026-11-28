// Kiểm tra giao diện hộp thoại VGD Diagram trong Chromium (không có SketchUp).
// Chạy từ plugins/VGD_Diagram: node dev/test_ui.cjs
const path = require('path');
const { chromium } = require('playwright');

const dialog = 'file://' + path.resolve(__dirname, '../runtime/vgd_diagram/dialog.html');
const sample = {
  nodes: [
    {
      key: 100, name: 'Tủ', count: 2, ids: [100, 103], order: null, mixed: false,
      children: [
        { key: 51, name: 'Đáy', count: 1, ids: [51], order: 1, mixed: false, children: [] },
        { key: 52, name: 'Cánh', count: 2, ids: [52, 54], order: null, mixed: true, children: [] }
      ]
    },
    { key: 200, name: 'Chân', count: 4, ids: [200, 201, 202, 203], order: 3, mixed: false, children: [] }
  ]
};

let pass = 0;
const failed = [];
function check(name, ok) {
  ok ? pass++ : failed.push(name);
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${name}`);
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  // Giả lập đối tượng sketchup của SketchUp: ghi lại mọi lời gọi từ giao diện.
  await page.addInitScript(() => {
    window.__calls = [];
    window.sketchup = new Proxy({}, {
      get: (_t, name) => (...args) => window.__calls.push({ name, args })
    });
  });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(dialog);
  await page.evaluate((data) => window.VGD.onTree(data), sample);

  const calls = await page.evaluate(() => window.__calls);
  check('khi mở, giao diện báo sẵn sàng (ready)', calls.some((c) => c.name === 'ready'));
  check('vẽ đúng 2 nhóm cấp đầu', (await page.locator('#tree > li').count()) === 2);
  check('nhóm con hiện đúng (Đáy, Cánh)', (await page.locator('#tree ul li .name').allTextContents()).join(',') === 'Đáy,Cánh');
  check('nhóm không đồng nhất hiện ô trống với gợi ý "nhiều số"',
    (await page.locator('input.order').nth(2).getAttribute('placeholder')) === 'nhiều số');
  check('nút Lưu thứ tự ban đầu bị khóa', await page.locator('#save').isDisabled());

  // Nhập không hợp lệ: đánh dấu đỏ, báo lỗi, không cho lưu.
  const chainInput = page.locator('input.order').nth(3);
  await chainInput.fill('0');
  check('nhập 0: ô đỏ (invalid)', await chainInput.evaluate((el) => el.classList.contains('invalid')));
  check('nhập 0: báo lỗi phạm vi', (await page.locator('#status').textContent()).includes('từ 1 đến 9999'));
  check('nhập 0: vẫn không cho lưu', await page.locator('#save').isDisabled());

  // Nhập đúng số khác: đánh dấu đã đổi, cho lưu.
  await chainInput.fill('5');
  check('nhập 5: ô được đánh dấu đã đổi', await chainInput.evaluate((el) => el.classList.contains('changed')));
  check('nhập 5: cho phép lưu', !(await page.locator('#save').isDisabled()));

  // Đưa về đúng giá trị cũ: không còn thay đổi, nút lưu khóa lại.
  await chainInput.fill('3');
  check('nhập lại 3 (giá trị cũ): nút lưu khóa lại', await page.locator('#save').isDisabled());

  // Nhập thứ tự cho nhóm Đáy rồi lưu: gửi đúng khóa và số.
  await page.locator('input.order').nth(0).fill('');
  await page.locator('input.order').nth(1).fill('7');
  await page.evaluate(() => { window.__calls = []; });
  await page.locator('#save').click();
  const saved = (await page.evaluate(() => window.__calls)).find((c) => c.name === 'save_orders');
  const payload = saved ? JSON.parse(saved.args[0]) : null;
  check('lưu: gửi save_orders', !!saved);
  // Chỉ Đáy đổi (1 → 7); Tủ để trống nhưng vốn trống, Chân đã đưa về 3 nên không còn là thay đổi.
  check('lưu: chỉ gửi đúng thay đổi Đáy: khóa 51, số 7',
    !!payload && payload.changes.length === 1 && payload.changes[0].key === 51 && payload.changes[0].order === 7);

  // Bấm tên: gửi select với khóa nhóm.
  await page.evaluate(() => { window.__calls = []; });
  await page.locator('#tree .name').first().click();
  const sel = (await page.evaluate(() => window.__calls)).find((c) => c.name === 'select');
  check('bấm tên: gửi select đúng khóa nhóm', sel && JSON.parse(sel.args[0]).key === 100);

  // Ruby báo lỗi: hiện thông báo lỗi.
  await page.evaluate(() => window.VGD.onError({ message: 'Thứ tự 3 trùng.' }));
  check('onError: hiện thông báo lỗi', (await page.locator('#status').textContent()) === 'Thứ tự 3 trùng.');

  // Chữ không phải số bị chặn ở giao diện.
  await page.evaluate((data) => window.VGD.onTree(data), sample);
  await page.locator('input.order').nth(0).fill('abc');
  check('nhập chữ: ô đỏ', await page.locator('input.order').nth(0).evaluate((el) => el.classList.contains('invalid')));

  check('không có lỗi JavaScript trên trang', errors.length === 0);
  await browser.close();
  console.log('');
  console.log(failed.length === 0 ? `TẤT CẢ ĐẠT (${pass})` : `CÓ ${failed.length} LỖI: ${failed.join(' | ')}`);
  process.exit(failed.length === 0 ? 0 : 1);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
