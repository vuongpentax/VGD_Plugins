const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {resolve}=require('./dependencies.cjs'),JSZip=require(resolve('jszip'));
require('./build_icons.cjs');
const archiveDate=new Date('2026-10-11T00:00:00Z');
async function add(zip,directory,prefix=''){
  for(const entry of fs.readdirSync(directory,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))){
    if(entry.name==='node_modules')continue;
    const local=path.join(directory,entry.name),target=prefix+entry.name;
    if(entry.isDirectory())await add(zip,local,target+'/');
    else zip.file(target,fs.readFileSync(local),{date:archiveDate,createFolders:false});
  }
}
(async()=>{
  const root=path.resolve(__dirname,'..'),runtime=path.join(root,'runtime'),loader='vgd_reference.rb';
  const zip=new JSZip();
  zip.file(loader,fs.readFileSync(path.join(runtime,loader)),{date:archiveDate});
  await add(zip,path.join(runtime,'vgd_reference'),'vgd_reference/');
  const bytes=await zip.generateAsync({type:'nodebuffer',compression:'DEFLATE',compressionOptions:{level:9}});
  const archive=await JSZip.loadAsync(bytes),names=Object.keys(archive.files).filter(name=>!archive.files[name].dir);
  if(!names.includes(loader)||!names.includes('vgd_reference/main.rb')||names.some(name=>!/^vgd_reference(?:\.rb$|\/)/.test(name)))throw Error('Invalid RBZ paths');
  for(const name of names){const actual=await archive.file(name).async('nodebuffer');if(!actual.equals(fs.readFileSync(path.join(runtime,name))))throw Error('RBZ byte mismatch: '+name);}
  const version=fs.readFileSync(path.join(runtime,loader),'utf8').match(/extension\.version = '([^']+)'/)[1];
  const constantVersion=fs.readFileSync(path.join(runtime,'vgd_reference/core/constants.rb'),'utf8').match(/VERSION = '([^']+)'/)[1];
  const iconVersion=JSON.parse(fs.readFileSync(path.join(runtime,'vgd_reference/assets/toolbar/icon_manifest.json'),'utf8')).version;
  if(version!==constantVersion||version!==iconVersion)throw Error('Runtime/icon manifest version mismatch');
  const filename=`VGD_Reference_v${version}.rbz`;
  fs.writeFileSync(path.join(root,filename),bytes);
  fs.writeFileSync(path.join(root,filename+'.sha256'),crypto.createHash('sha256').update(bytes).digest('hex')+'  '+filename+'\n');
  const source=new JSZip();
  await add(source,runtime,'runtime/');await add(source,path.join(root,'dev'),'dev/');
  for(const doc of ['README.md','CODEX_HANDOFF.md',`RELEASE_NOTES_v${version}.md`])source.file(doc,fs.readFileSync(path.join(root,doc)),{date:archiveDate});
  const sourceFilename=`VGD_Reference_v${version}_source.zip`,sourceBytes=await source.generateAsync({type:'nodebuffer',compression:'DEFLATE'});
  const sourceArchive=await JSZip.loadAsync(sourceBytes),sourceNames=Object.keys(sourceArchive.files).filter(name=>!sourceArchive.files[name].dir);
  for(const name of sourceNames){const actual=await sourceArchive.file(name).async('nodebuffer');if(!actual.equals(fs.readFileSync(path.join(root,name))))throw Error('Source byte mismatch: '+name);}
  fs.writeFileSync(path.join(root,sourceFilename),sourceBytes);
  fs.writeFileSync(path.join(root,sourceFilename+'.sha256'),crypto.createHash('sha256').update(sourceBytes).digest('hex')+'  '+sourceFilename+'\n');
  const minimum=Number(fs.readFileSync(path.join(runtime,'vgd_reference/core/constants.rb'),'utf8').match(/MIN_SKETCHUP_VERSION = (\d+)/)[1]);
  const info={version,minimum_sketchup_major:minimum,sketchup_2022_supported:false,runtime_files:names.length,source_files:sourceNames.length,
    artifacts:[{filename,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')},{filename:sourceFilename,bytes:sourceBytes.length,sha256:crypto.createHash('sha256').update(sourceBytes).digest('hex')}],
    verification:{archive_bytes_match_source:true,runtime_syntax:'Ruby 3.2 WASM / Node syntax compilation',current_feature_tests:'not run',native_browser_drop:'not run',native_su2022:'not run',native_image_rendering:'user confirmed SU24 beta.5 UV fix',previous_beta6_icon_and_manager_checks:'Edge headless and Ruby fixtures'}};
  fs.writeFileSync(path.join(root,`BUILD_INFO_v${version}.json`),JSON.stringify(info,null,2)+'\n');
  console.log(`${filename}: ${names.length} runtime files, ${bytes.length} bytes; archive content verified.`);
  console.log(`${sourceFilename}: ${sourceNames.length} source files, ${sourceBytes.length} bytes; archive content verified.`);
  console.log('SHA-256 sidecars written for both archives. Version: '+version);
})().catch(error=>{console.error(error);process.exitCode=1;});
