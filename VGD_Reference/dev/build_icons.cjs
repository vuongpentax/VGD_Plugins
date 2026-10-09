const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
const version=fs.readFileSync(path.join(root,'runtime','vgd_reference.rb'),'utf8').match(/extension\.version = '([^']+)'/)[1];
const folder=path.join(root,'runtime','vgd_reference','assets','toolbar');
// A photo with an open top edge for the pin. The same paths serve every size/theme.
const paths=[
  {role:'outline',d:'M7 6.5H4.7a1.2 1.2 0 0 0-1.2 1.2v11.6a1.2 1.2 0 0 0 1.2 1.2h14.6a1.2 1.2 0 0 0 1.2-1.2V7.7a1.2 1.2 0 0 0-1.2-1.2H17'},
  {role:'outline',d:'m6 17 3.5-3.5 4 3.5 2.5-2.5 2 2.5'},
  {role:'accent',d:'M10 3.5h4v3l1.5 2h-7l1.5-2zM12 8.5v3'}
];
const colors={light:'#292B2D',dark:'#F1EDE6'},accent='#A67C58';
fs.mkdirSync(folder,{recursive:true});
for(const theme of ['light','dark']){
  const name=theme==='light'?'vgd_reference.svg':'vgd_reference_dark.svg';
  const svg='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">\n'+paths.map(({role,d})=>`  <path stroke="${role==='accent'?accent:colors[theme]}" d="${d}"/>`).join('\n')+'\n</svg>\n';
  fs.writeFileSync(path.join(folder,name),svg);
}
const manifest={
  schema_version:1,plugin:'VGD Reference',version,
  rules:'shared/VGD_ICON_SYSTEM_RULES.md',reference:'shared/VGD_ICON_SYSTEM_PREVIEW.html',
  view_box:'0 0 24 24',stroke_width:1.8,linecap:'round',linejoin:'round',transparent:true,
  preview_sizes:[16,24,32],
  colors:{light:{outline:colors.light,accent,toolbar:'#D8D7D4'},dark:{outline:colors.dark,accent,toolbar:'#292B2D'}},
  icons:{reference:{meaning:'Ảnh tham chiếu được ghim trên khung nhìn',files:{light:'vgd_reference.svg',dark:'vgd_reference_dark.svg'}}},
  theme_policy:{manager:'prefers-color-scheme',native_toolbar:{default:'light',preferences_section:'VGD.Reference',preferences_key:'ToolbarTheme',values:['light','dark'],setting:'Chọn màu icon thanh công cụ → Icon thanh công cụ SketchUp',apply:'on change and extension startup'}}
};
fs.writeFileSync(path.join(folder,'icon_manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log('Generated VGD Reference SVG pair and manifest for '+version);
