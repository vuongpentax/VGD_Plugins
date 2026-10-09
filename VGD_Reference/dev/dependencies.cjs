const fs = require('fs'), path = require('path');
exports.resolve = name => {
  const roots = [
    process.env.VGD_NODE_MODULES,
    path.resolve(__dirname, 'node_modules'),
    path.resolve(__dirname, '../../VGD_Image_Importer/dev/node_modules'),
    path.resolve(__dirname, '../../VGD_Scenes/dev/node_modules'),
    process.env.USERPROFILE && path.join(process.env.USERPROFILE, '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules')
  ].filter(Boolean);
  for (const root of roots) if (fs.existsSync(path.join(root, name))) return path.join(root, name);
  return name;
};
