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

  // ---- Khung 3D: vẽ mô hình, tách rời, phát lắp ráp theo thứ tự ----
  const scene = {
    truncated: false,
    parts: [
      { id: 51, name: 'Đáy', order: 1, positions: [0, 0, 0, 100, 0, 0, 0, 100, 0] },
      { id: 52, name: 'Cánh', order: 2, positions: [500, 0, 0, 600, 0, 0, 500, 100, 0] },
      { id: 200, name: 'Chân', order: null, positions: [0, 500, 0, 100, 500, 0, 0, 600, 0] }
    ]
  };
  await page.evaluate((data) => window.VGD.onScene(data), scene);
  const dbg = () => page.evaluate(() => window.VGD.__debug());
  let state = await dbg();
  check('3D: vẽ đủ 3 mảnh', state.parts === 3);
  check('3D: canvas có kích thước', await page.locator('#view').evaluate((el) => el.clientWidth > 0 && el.clientHeight > 0));
  check('3D: nút Phát lắp ráp mở khi có cấu kiện có thứ tự', !(await page.locator('#play').isDisabled()));

  const centerOf = (positions) => positions.map((p) => Math.hypot(p[0], p[1], p[2]));
  await page.locator('#explode').fill('0');
  const assembled = await dbg();
  await page.locator('#explode').fill('100');
  const exploded = await dbg();
  const grew = exploded.positions.every((p, i) => Math.hypot(...p) > Math.hypot(...assembled.positions[i]) - 1e-6);
  check('3D: kéo tách rời làm các mảnh ra xa tâm', grew && exploded.slider === 100);
  check('3D: tách rời 0 đưa mảnh về vị trí lắp', assembled.slider === 0);

  await page.locator('#explode').fill('0');
  await page.locator('#play').click();
  state = await dbg();
  check('phát lắp ráp: đang chạy', state.playing === true);
  await page.waitForTimeout(2500);
  state = await dbg();
  check('phát lắp ráp: kết thúc và thanh trượt về 0', state.playing === false && state.slider === 0);
  const afterPlay = await dbg();
  check('phát lắp ráp: các mảnh đã về đúng vị trí lắp',
    afterPlay.positions.every((p, i) => Math.hypot(...p) - Math.hypot(...assembled.positions[i]) < 1e-3));

  // Không có mảnh nào có thứ tự: nút phát bị khóa
  await page.evaluate(() => window.VGD.onScene({ truncated: false, parts: [{ id: 1, name: 'A', order: null, positions: [0, 0, 0, 1, 0, 0, 0, 1, 0] }] }));
  check('không có thứ tự: nút Phát lắp ráp bị khóa', await page.locator('#play').isDisabled());
  await page.evaluate(() => window.VGD.onScene({ truncated: true, parts: [] }));
  check('mô hình rỗng: thông báo không có hình học',
    (await page.locator('#view-msg').textContent()).includes('chưa có hình học'));

  // ---- Số nhãn: trên cây (badge) và trên mô hình 3D (tag), khớp nhau ----
  const numbered = {
    nodes: [
      { key: 100, name: 'Tủ', count: 1, ids: [100], order: null, mixed: false, number: null, children: [
        { key: 51, name: 'Đáy', count: 1, ids: [51], order: 1, mixed: false, number: 1, children: [] },
        { key: 52, name: 'Cánh', count: 1, ids: [52], order: 2, mixed: false, number: 2, children: [] }
      ] },
      { key: 200, name: 'Chân', count: 1, ids: [200], order: null, mixed: false, number: 3, children: [] }
    ]
  };
  await page.evaluate((data) => window.VGD.onTree(data), numbered);
  await page.evaluate((data) => window.VGD.onScene(data), scene);
  check('số nhãn: cây có 3 badge (nhóm không có hình học không có số)', (await page.locator('.badge').count()) === 3);
  const tagTexts = await page.locator('#labels .tag').allTextContents();
  check('số nhãn: trên mô hình có 3 nhãn 1, 2, 3', tagTexts.join(',') === '1,2,3');
  const tagPos = async () => page.locator('#labels .tag').evaluateAll((els) => els.map((el) => el.style.left + ' ' + el.style.top));
  // Nhãn đổi vị trí ở vòng lặp khung hình, nên chờ vài khung trước khi đọc.
  await page.locator('#explode').fill('0');
  await page.waitForTimeout(300);
  const before = await tagPos();
  await page.locator('#explode').fill('100');
  await page.waitForTimeout(300);
  const after = await tagPos();
  check('số nhãn: nhãn di chuyển khi tách rời', before.join('|') !== after.join('|'));
  check('số nhãn: nhãn có toạ độ hợp lệ', after.every((p) => /^-?[\d.]+px -?[\d.]+px$/.test(p) || p === ' '));

  // ---- Đề xuất thứ tự, phạm vi trống, xuất ảnh các góc ----
  await page.evaluate((data) => window.VGD.onTree(data), sample);
  await page.evaluate(() => { window.__calls = []; });
  await page.locator('button', { hasText: 'Đề xuất thứ tự' }).click();
  check('đề xuất: gửi suggest_orders về Ruby', (await page.evaluate(() => window.__calls)).some((c) => c.name === 'suggest_orders'));
  await page.evaluate(() => window.VGD.onSuggested({ changes: [{ key: 51, order: 1 }, { key: 52, order: 2 }] }));
  const values = await page.locator('input.order').evaluateAll((els) => els.map((el) => el.value));
  check('đề xuất: điền số vào ô nhập (Đáy = 1, Cánh = 2)', values[1] === '1' && values[2] === '2');
  check('đề xuất: chưa lưu, nút Lưu thứ tự mở để kiểm tra', !(await page.locator('#save').isDisabled()));
  check('đề xuất: báo số nhóm đã điền', (await page.locator('#status').textContent()).includes('cho 2 nhóm'));

  await page.evaluate(() => window.VGD.onTree({ nodes: [], message: 'Hãy chọn đối tượng trong model rồi bấm Làm mới.' }));
  check('phạm vi trống: hiện hướng dẫn chọn đối tượng',
    (await page.locator('#empty').textContent()).includes('Hãy chọn đối tượng') && (await page.locator('#empty').isVisible()));
  await page.evaluate((data) => window.VGD.onTree(data), sample);

  // Xuất: 4 góc chuẩn, theo cụm, theo bước lắp. Cây có số nhãn để có nhãn trên ảnh.
  const exportTree = {
    nodes: [
      { key: 100, name: 'Tủ', count: 1, ids: [100], order: null, mixed: false, number: null, children: [
        { key: 51, name: 'Đáy', count: 1, ids: [51], order: 1, mixed: false, number: 1, children: [] },
        { key: 52, name: 'Cánh', count: 1, ids: [52], order: 2, mixed: false, number: 2, children: [] }
      ] },
      { key: 200, name: 'Chân', count: 1, ids: [200], order: null, mixed: false, number: 3, children: [] }
    ]
  };
  await page.evaluate((data) => window.VGD.onTree(data), exportTree);
  await page.evaluate((data) => window.VGD.onScene(data), scene);
  await page.evaluate(() => { window.__calls = []; });
  await page.evaluate(() => window.VGD.onExport({ base: 'thu' }));
  const shots = (await page.evaluate(() => window.__calls)).filter((c) => c.name === 'save_image').map((c) => JSON.parse(c.args[0]));
  const keys = shots.map((s) => s.key).join(',');
  check('xuất: đủ ảnh 4 góc, theo cụm (cum-01, cum-02) và theo bước (buoc-01, buoc-02)',
    keys === 'truoc,phai,tren,iso,cum-01,cum-02,buoc-01,buoc-02');
  check('xuất: mỗi ảnh là PNG có dữ liệu',
    shots.every((s) => s.data.startsWith('data:image/png;base64,') && s.data.length > 5000));
  const bySteps = shots.filter((s) => s.key.startsWith('buoc-'));
  check('xuất: ảnh các bước khác nhau (mỗi bước hiện thêm cấu kiện)', bySteps.length === 2 && bySteps[0].data !== bySteps[1].data);
  check('xuất: báo xong (export_done)', (await page.evaluate(() => window.__calls)).some((c) => c.name === 'export_done'));
  check('xuất: không lỗi khi vẽ', !(await page.locator('#status').textContent()).includes('thất bại'));

  // Kiểm tra: Chân chưa có thứ tự lắp -> cảnh báo
  await page.evaluate(() => window.VGD.checkDiagram());
  check('kiểm tra: cảnh báo nhóm chưa có thứ tự', (await page.locator('#status').textContent()).includes('chưa có thứ tự lắp'));

  // ---- Xuất video lắp ráp: quay thật trong trình duyệt, rồi kiểm tra dữ liệu ----
  await page.evaluate((data) => window.VGD.onTree(data), exportTree);
  await page.evaluate((data) => window.VGD.onScene(data), scene);
  await page.evaluate(() => { window.__calls = []; });
  await page.evaluate(() => window.VGD.onVideo({ base: 'thu' }));
  let video = null;
  for (let i = 0; i < 80 && !video; i++) {
    await page.waitForTimeout(250);
    video = (await page.evaluate(() => window.__calls)).find((c) => c.name === 'save_video');
  }
  const videoPayload = video ? JSON.parse(video.args[0]) : null;
  check('video: quay xong và gửi về Ruby', !!videoPayload);
  check('video: dữ liệu là video (mp4 hoặc webm) có nội dung',
    !!videoPayload && /^data:video\/(mp4|webm)/.test(videoPayload.data) && videoPayload.data.length > 5000);
  check('video: đuôi file hợp lệ', !!videoPayload && ['mp4', 'webm'].includes(videoPayload.ext));
  check('video: báo đã quay (có số cấu kiện có thứ tự)', (await page.locator('#status').textContent()).includes('2 cấu kiện'));
  const orderedIds = (await dbg()).ordered;
  check('video: thứ tự bay giống khung 3D (51 trước 52)', JSON.stringify(orderedIds) === JSON.stringify([51, 52]));

  // Không có bước lắp: không quay, báo rõ
  await page.evaluate(() => window.VGD.onScene({ truncated: false, parts: [{ id: 1, name: 'A', order: null, positions: [0, 0, 0, 1, 0, 0, 0, 1, 0] }] }));
  await page.evaluate(() => { window.__calls = []; });
  await page.evaluate(() => window.VGD.onVideo({ base: 'thu' }));
  check('video: không có bước lắp thì báo và không quay',
    (await page.locator('#status').textContent()).includes('Chưa có bước lắp') &&
    !(await page.evaluate(() => window.__calls)).some((c) => c.name === 'save_video'));

  // ---- Định dạng khi lưu: JPG cho ảnh, WebM cho video, MP4 khi trình duyệt không hỗ trợ ----
  await page.evaluate((data) => window.VGD.onScene(data), scene);
  await page.evaluate(() => { window.__calls = []; });
  await page.evaluate(() => window.VGD.onExport({ format: 'jpg' }));
  const jpgShots = (await page.evaluate(() => window.__calls)).filter((c) => c.name === 'save_image').map((c) => JSON.parse(c.args[0]));
  check('định dạng: xuất JPG cho ảnh', jpgShots.length > 0 && jpgShots.every((s) => s.data.startsWith('data:image/jpeg;base64,')));

  await page.evaluate(() => { window.__calls = []; });
  await page.evaluate(() => window.VGD.onVideo({ format: 'webm' }));
  let webm = null;
  for (let i = 0; i < 80 && !webm; i++) {
    await page.waitForTimeout(250);
    webm = (await page.evaluate(() => window.__calls)).find((c) => c.name === 'save_video');
  }
  check('định dạng: quay WebM khi chọn WebM', !!webm && JSON.parse(webm.args[0]).ext === 'webm');

  await page.evaluate(() => { window.__calls = []; window.MediaRecorder.isTypeSupported = () => false; });
  await page.evaluate(() => window.VGD.onVideo({ format: 'mp4' }));
  check('định dạng: MP4 không được hỗ trợ thì báo rõ, không tự đổi sang WebM',
    (await page.locator('#status').textContent()).includes('không quay được MP4') &&
    !(await page.evaluate(() => window.__calls)).some((c) => c.name === 'save_video'));

  // ---- Chuỗi khung hình PNG (để đổi sang MP4 bằng ffmpeg trên máy) ----
  await page.evaluate((data) => window.VGD.onScene(data), scene);
  await page.evaluate(() => { window.__calls = []; });
  await page.evaluate(() => window.VGD.onVideo({ format: 'png' }));
  let frameDone = null;
  for (let i = 0; i < 480 && !frameDone; i++) {
    await page.waitForTimeout(250);
    frameDone = (await page.evaluate(() => window.__calls)).find((c) => c.name === 'video_done');
  }
  const frameCalls = (await page.evaluate(() => window.__calls)).filter((c) => c.name === 'save_frame').map((c) => JSON.parse(c.args[0]));
  // Cùng công thức với "Phát lắp ráp": (số cấu kiện có thứ tự - 1) * 0.35 + 0.7 giây, cộng 2 giây giữ hình cuối.
  const expectedFrames = Math.ceil(((2 - 1) * 0.35 + 0.7 + 2) * 30);
  check('khung hình: số khung đúng (thời lượng × 30 khung/giây)', frameCalls.length === expectedFrames);
  check('khung hình: đánh số 1, 2, 3... và là PNG',
    frameCalls.every((f, i) => f.index === i + 1) && frameCalls.every((f) => f.data.startsWith('data:image/png;base64,')));
  check('khung hình: báo xong với số khung và fps', !!frameDone && JSON.parse(frameDone.args[0]).fps === 30);

  // ---- Ô đường dẫn ffmpeg: hiện giá trị đã lưu, lưu/chọn gửi về Ruby ----
  await page.evaluate(() => { window.__calls = []; window.VGD.onSettings({ ffmpegPath: 'C:/ffmpeg/bin/ffmpeg.exe' }); });
  check('ffmpeg: hiện đường dẫn đã lưu', (await page.locator('#ffmpeg-path').inputValue()) === 'C:/ffmpeg/bin/ffmpeg.exe');
  await page.locator('#ffmpeg-path').fill('D:/tools/ffmpeg.exe');
  await page.locator('button', { hasText: 'Lưu' }).first().click();
  const saveCall = (await page.evaluate(() => window.__calls)).find((c) => c.name === 'save_ffmpeg');
  check('ffmpeg: nút Lưu gửi đường dẫn về Ruby', !!saveCall && JSON.parse(saveCall.args[0]).path === 'D:/tools/ffmpeg.exe');
  await page.evaluate(() => { window.__calls = []; });
  await page.locator('button', { hasText: 'Chọn' }).first().click();
  check('ffmpeg: nút Chọn gửi yêu cầu mở hộp thoại', (await page.evaluate(() => window.__calls)).some((c) => c.name === 'pick_ffmpeg'));

  // ---- Số phiên bản dưới logo: Ruby gửi onVersion khi sẵn sàng ----
  await page.evaluate(() => window.VGD.onVersion({ version: '0.10.2-beta.1' }));
  check('phiên bản: hiện số phiên bản dưới logo', (await page.locator('#ver').textContent()) === 'Phiên bản 0.10.2-beta.1');
  check('phiên bản: nhãn nằm dưới dòng logo VGD Diagram',
    await page.evaluate(() => {
      const brand = document.querySelector('.brand').getBoundingClientRect();
      const ver = document.getElementById('ver').getBoundingClientRect();
      return ver.top >= brand.bottom - 1;
    }));

  check('không có lỗi JavaScript trên trang', errors.length === 0);
  await browser.close();
  console.log('');
  console.log(failed.length === 0 ? `TẤT CẢ ĐẠT (${pass})` : `CÓ ${failed.length} LỖI: ${failed.join(' | ')}`);
  process.exit(failed.length === 0 ? 0 : 1);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
