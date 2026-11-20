// A `hermes` space's bundle: its Jac as `jac emit-js` compiled it, under src/.
const fs = require("fs");
const path = require("path");
const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);
const src = path.join(__dirname, "src");
const { aliases } = JSON.parse(fs.readFileSync(path.join(src, "@jac", "bundle.json"), "utf8"));
const resolve = config.resolver.resolveRequest;
config.resolver.resolveRequest = (context, name, platform) => {
    if (name in aliases) return { type: "sourceFile", filePath: path.join(src, aliases[name]) };
    return (resolve || context.resolveRequest)(context, name, platform);
};
module.exports = config;
