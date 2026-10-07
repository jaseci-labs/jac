// Entry `.cjs` inside a "type": "module" package: CommonJS (Node).
const path = require("path");
console.log("CJS-ENTRY " + [typeof path.join, typeof module, typeof exports, typeof __filename].join(","));
