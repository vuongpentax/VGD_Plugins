const fs=require('fs'), path=require('path'), crypto=require('crypto');
const {resolve}=require('./dependencies.cjs'), JSZip=require(resolve('jszip'));
async function add(zip,directory,prefix='') {
  for(const entry of fs.readdirSync(directory,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
    if(entry.name==='node_modules') continue;
    const local=path.join(directory,entry.name), target=prefix+entry.name;
    if(entry.isDirectory()) await add(zip,local,target+'/');
    else zip.file(target,fs.readFileSync(local),{date:new Date('2026-10-05T00:00:00Z'),createFolders:false});
  }
}
(async()=>{
  const root=path.resolve(__dirname,'..'), zip=new JSZip(); await add(zip,path.join(root,'runtime'));
  const bytes=await zip.generateAsync({type:'nodebuffer',compression:'DEFLATE',compressionOptions:{level:9}});
  const archive=await JSZip.loadAsync(bytes), names=Object.keys(archive.files).filter(name=>!archive.files[name].dir);
  if(!names.includes('vgd_image_importer.rb') || !names.includes('vgd_image_importer/main.rb') || names.some(name=>!/^vgd_image_importer(?:\.rb$|\/)/.test(name))) throw Error('Invalid RBZ paths');
  for(const name of names) if(!(await archive.file(name).async('nodebuffer')).equals(fs.readFileSync(path.join(root,'runtime',name)))) throw Error('RBZ byte mismatch: '+name);
  const version=fs.readFileSync(path.join(root,'runtime/vgd_image_importer.rb'),'utf8').match(/VERSION = '([^']+)'/)[1];
  const name=`VGD_Image_Importer_v${version}.rbz`; fs.writeFileSync(path.join(root,name),bytes);
  fs.writeFileSync(path.join(root,name+'.sha256'),crypto.createHash('sha256').update(bytes).digest('hex')+'  '+name+'\n');
  const source=new JSZip(); await add(source,path.join(root,'runtime'),'runtime/'); await add(source,path.join(root,'dev'),'dev/');
  for(const doc of ['README.md','CODEX_HANDOFF.md']) source.file(doc,fs.readFileSync(path.join(root,doc)),{date:new Date('2026-10-05T00:00:00Z')});
  fs.writeFileSync(path.join(root,`VGD_Image_Importer_v${version}_source.zip`),await source.generateAsync({type:'nodebuffer',compression:'DEFLATE'}));
  console.log(`${name}: ${names.length} runtime files, ${bytes.length} bytes; archive content verified.`);
})().catch(error=>{console.error(error);process.exitCode=1;});
