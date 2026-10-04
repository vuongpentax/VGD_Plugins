const fs = require('fs'), path = require('path');
const { resolve } = require('./dependencies.cjs');
const { chromium } = require(resolve('playwright'));
const { pathToFileURL } = require('url');
(async () => {
  const out = path.resolve(__dirname, '../outputs'); fs.mkdirSync(out, { recursive: true });
  const source = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../runtime/vgd_library/drive_source.json'), 'utf8'));
  const response = await fetch(source.url, { signal: AbortSignal.timeout(20000) });
  const raw = await response.text();
  fs.writeFileSync(path.join(out, 'drive_response.html'), raw);
  console.log(JSON.stringify({ status: response.status, type: response.headers.get('content-type'), bytes: Buffer.byteLength(raw), html: /^\s*<(?:!doctype|html)/i.test(raw) }));
  let error; try { JSON.parse(raw); } catch (e) { error = e.message; }
  if (!error) throw Error('Expected folder web page, not a JSON catalog');
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1120, height: 760 } });
    await page.addInitScript(() => { window.sketchup = { vgd() {} }; });
    await page.goto(pathToFileURL(path.resolve(__dirname, '../runtime/vgd_library/dialog.html')).href);
    // Ruby JSON::ParserError can include the entire response, as in the user's screenshot.
    await page.evaluate(text => { VGD.begin({ roots: ['G:/03 MTL'], favorites: [], version: 'reproducer' }); VGD.append([], true, ['Nguồn online: unexpected token at ' + text]); }, raw);
    console.log(JSON.stringify(await page.evaluate(() => ({ footer: document.querySelector('footer').getBoundingClientRect().height, workspace: document.querySelector('.workspace').getBoundingClientRect().height, statusChars: document.querySelector('#status').textContent.length }))));
    await page.screenshot({ path: path.join(out, 'drive_error_reproduced.png') });
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
