// VITE-CFG-CJS-001: simulate Vite loadConfigFromBundledFile CJS branch

"use strict";

var path = require("path");
var fs = require("fs");
var os = require("os");

var __jacHarness = require("../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/05_integration/test_vite_config_cjs_load.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }

var m = require("node:module");

var tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "jac-vite-cfg-"));
var fileName = path.join(tmpDir, "vite.config.js");
fs.writeFileSync(fileName, "// on-disk stub\n");

var bundledCode = [
    "'use strict';",
    "module.exports = {",
    "  root: process.cwd(),",
    "  build: { outDir: 'dist' },",
    "};",
].join("\n");

var _require = m.createRequire(fileName);
var extension = path.extname(fileName);
var loaderExt = extension in _require.extensions ? extension : ".js";
var defaultLoader = _require.extensions[loaderExt];

_require.extensions[loaderExt] = function (module, filename) {
    if (filename === fileName) {
        module._compile(bundledCode, filename);
    } else {
        defaultLoader(module, filename);
    }
};

delete _require.cache[_require.resolve(fileName)];
var raw = _require(fileName);
_require.extensions[loaderExt] = defaultLoader;

assert(raw && typeof raw === "object", "VITE-CFG-CJS-001: config object returned");
assert(raw.build && raw.build.outDir === "dist", "VITE-CFG-CJS-001: bundled export visible");
assert(typeof raw.root === "string", "VITE-CFG-CJS-001: process.cwd() evaluated in module scope");

try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch (e) { /* ignore */ }

console.log("ok Vite bundled CJS config load (VITE-CFG-CJS-001)");
__jacDone();
