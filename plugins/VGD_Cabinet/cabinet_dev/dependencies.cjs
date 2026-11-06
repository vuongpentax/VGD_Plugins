const path=require('path');
const paths=[__dirname,process.env.VGD_NODE_MODULES].filter(Boolean);
exports.resolve=name=>require.resolve(name,{paths});
exports.load=name=>require(exports.resolve(name));
