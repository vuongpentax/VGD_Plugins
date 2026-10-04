const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { resolve } = require('./dependencies.cjs');
const JSZip = require(resolve('jszip'));
async function add(zip, directory, prefix = '') {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((a,b) => a.name.localeCompare(b.name))) {
    if (entry.name === 'node_modules') continue;
    const local = path.join(directory, entry.name), target = prefix + entry.name;
    if (entry.isDirectory()) await add(zip, local, target + '/');
    else zip.file(target, fs.readFileSync(local), { date: new Date('2026-10-04T00:00:00Z'), createFolders: false });
  }
}
(async () => {
  const root = path.resolve(__dirname, '..'), zip = new JSZip(); await add(zip, path.join(root, 'runtime'));
  const content = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE', compressionOptions: { level: 9 } });
  const archive = await JSZip.loadAsync(content), entries = Object.keys(archive.files).filter(name => !archive.files[name].dir);
  if (!entries.includes('vgd_library.rb') || !entries.includes('vgd_library/main.rb') || entries.some(name => /PLUGIN_MAP|plugin_map|\.dll$/.test(name))) throw Error('Invalid package layout');
  const version = fs.readFileSync(path.join(root, 'runtime/vgd_library.rb'), 'utf8').match(/VERSION\s*=\s*'([^']+)'/)[1];
  const name = `VGD_Library_v${version}.rbz`; fs.writeFileSync(path.join(root, name), content);
  fs.writeFileSync(path.join(root, name + '.sha256'), crypto.createHash('sha256').update(content).digest('hex') + '  ' + name + '\n');
  const source = new JSZip(); await add(source, path.join(root, 'runtime'), 'runtime/'); await add(source, path.join(root, 'dev'), 'dev/');
  for (const doc of ['README.md', 'CODEX_HANDOFF.md', 'FEATURE_PARITY.md']) source.file(doc, fs.readFileSync(path.join(root, doc)), { date: new Date('2026-10-04T00:00:00Z') });
  fs.writeFileSync(path.join(root, `VGD_Library_v${version}_source.zip`), await source.generateAsync({ type:'nodebuffer', compression:'DEFLATE' }));
  console.log(name + ': ' + entries.length + ' runtime files, ' + content.length + ' bytes; original code excluded.');
})().catch(error => { console.error(error); process.exitCode = 1; });
