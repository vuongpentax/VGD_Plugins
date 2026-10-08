const path=require('path');
const paths=[__dirname,process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,path.resolve(__dirname,'../../TPlus_Cabinet_Codex_Handoff_2026-10-01/cabinet_dev')].filter(Boolean);
exports.resolve=name=>require.resolve(name,{paths});
exports.load=name=>require(exports.resolve(name));
