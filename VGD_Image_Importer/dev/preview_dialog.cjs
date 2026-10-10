const fs = require('fs'), path = require('path');
const { pathToFileURL } = require('url'), { resolve } = require('./dependencies.cjs');
const { chromium } = require(resolve('playwright'));
(async () => {
  const root = path.resolve(__dirname, '..'), output = path.join(root, 'outputs', 'preview');
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ headless: true, ...(process.env.VGD_BROWSER_EXECUTABLE ? { executablePath: process.env.VGD_BROWSER_EXECUTABLE } : { channel: 'msedge' }) });
  try {
    const page = await browser.newPage({ viewport: { width: 960, height: 780 }, deviceScaleFactor: 1 });
    page.on('pageerror', error => { throw error; });
    await page.addInitScript(() => { window.sketchup = { vgd_importer: () => {} }; });
    await page.goto(pathToFileURL(path.join(root, 'runtime', 'vgd_image_importer', 'dialog.html')).href);
    await page.evaluate(() => VGDImporter.receive('settings', { theme: 'dark', importType: 'comp_2d', version: '1.1.0-beta.4' }));
    const imagePath = path.join(root, 'runtime', 'vgd_image_importer', 'vgd_icon.png');
    const files = [
      { id: 0, name: 'Cây bóng mát.webp', path: imagePath },
      { id: 1, name: 'Người đi bộ 01.png', path: imagePath },
      { id: 2, name: 'Map đá tự nhiên.png', path: imagePath },
      { id: 3, name: 'Vân gỗ sồi.webp', path: imagePath }
    ];
    await page.evaluate(files => VGDImporter.receive('files', files), files);
    await page.evaluate(() => VGDImporter.receive('status', { message: 'Đã chọn 4 ảnh. Kiểm tra cấu hình rồi nhập.' }));
    await page.waitForTimeout(250);
    await page.screenshot({ path: path.join(output, 'vgd_image_importer_dark.png') });
    await page.click('#theme');
    await page.waitForTimeout(150);
    await page.screenshot({ path: path.join(output, 'vgd_image_importer_light.png') });
    console.log('Preview saved: ' + output);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
