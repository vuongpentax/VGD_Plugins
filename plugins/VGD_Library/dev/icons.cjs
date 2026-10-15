const fs = require('fs'), path = require('path');
const icons = {
  library: 'M5 5h9v9H5zM18 5h9v9h-9zM5 18h9v9H5zM18 18h9v9h-9z',
  reapply: 'M6 8h13l7 7-11 11-9-9zM10 12h5M21 6v8m-4-4h8',
  rotate: 'M25 12a10 10 0 1 0 1 9M25 5v8h-8',
  random_rotate: 'M5 9h5l12 14h5m-5-4 5 4-5 4M5 23h5l12-14h5m-5-4 5 4-5 4',
  shuffle: 'M5 10h22m-5-5 5 5-5 5M27 22H5m5-5-5 5 5 5',
  fit: 'M5 12V5h7m8 0h7v7m0 8v7h-7m-8 0H5v-7M10 10h12v12H10z',
  restore: 'M6 12a10 10 0 1 1 0 9M6 5v8h8M16 10v7l5 3',
  clear: 'm5 21 14-16 9 8-14 16H9zM13 12l9 8M4 28h24',
  models: 'm16 3 12 7v13l-12 6L4 23V10zM4 10l12 7 12-7M16 17v12',
  rotate_face: 'M6 8h15v15H6zM25 15a7 7 0 1 1-5-8m0-4v5h5',
  swap_pick: 'M4 8h21m-5-5 5 5-5 5M28 24H7m5-5-5 5 5 5M6 15v3m20-3v3',
  replace_pick: 'M4 4h10v10H4zM18 18h10v10H18zM18 4h10v10m-8-3 8 3-3-8M4 18v10h10',
  auto_scale: 'M4 11V4h7m10 0h7v7m0 10v7h-7m-10 0H4v-7M9 9h14v14H9z',
  audit: 'M4 6h17v17H4zM11 13h17v17H11zM20 4v7m0 3v1',
  flow: 'M4 25c0-22 24-22 24 0M4 22h5m14 0h5M9 25c0-14 14-14 14 0M16 6v6',
  trace: 'M4 5h24v23H4zM8 22l7-11 9 11zM10 8h1M15 11v11M8 22h16',
  seamless: 'M4 4h24v24H4zM12 4v24M20 4v24M4 12h24M4 20h24',
  aux: 'm16 3 12 7-12 7L4 10zM4 16l12 7 12-7M4 22l12 7 12-7',
  refresh: 'M27 12a11 11 0 0 0-19-6L4 10m0-6v6h6M5 20a11 11 0 0 0 19 6l4-4m0 6v-6h-6'
};
for (const [name, d] of Object.entries(icons)) fs.writeFileSync(path.resolve(__dirname, '../runtime/vgd_library', `icon_${name}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><path d="${d}" fill="none" stroke="#a78968" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>\n`);
