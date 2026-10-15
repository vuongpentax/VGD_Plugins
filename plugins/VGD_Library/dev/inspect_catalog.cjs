// Read metadata only. No file contents, hydration, extraction or reorganization.
const fs=require('fs'), path=require('path');
const root=path.resolve(process.argv[2] || '');
if(!process.argv[2] || !fs.statSync(root).isDirectory()) throw Error('Pass a library folder');
const formats={}, groups={}, archives=[], errors=[], seen=new Set(), stack=[root];
let files=0, dirs=0;
while(stack.length) {
  const directory=stack.pop();
  if(seen.has(directory)) continue;
  seen.add(directory); dirs++;
  let entries;
  try { entries=fs.readdirSync(directory,{withFileTypes:true}); } catch(error) { errors.push({path:directory,message:error.message}); continue; }
  for(const entry of entries) {
    if(entry.isSymbolicLink() || entry.name.startsWith('.')) continue;
    const absolute=path.join(directory,entry.name);
    if(entry.isDirectory()) {stack.push(absolute);continue;}
    if(!entry.isFile()) continue;
    files++;
    const ext=path.extname(entry.name).toLowerCase();
    const relative=path.relative(root,absolute);
    if(['.rar','.zip','.7z'].includes(ext)) {archives.push(relative);continue;}
    if(!['.jpg','.jpeg','.png','.bmp','.tif','.tiff','.skm','.skp'].includes(ext)) continue;
    formats[ext]=(formats[ext]||0)+1;
    const group=relative.split(path.sep).length>1 ? relative.split(path.sep)[0] : 'Chưa phân nhóm';
    groups[group]=(groups[group]||0)+1;
  }
}
const result={root,files,dirs,formats,groups,archives,errors,metadata_only:true};
const out=path.resolve(__dirname,'../outputs');fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'drive_catalog_inventory.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));
