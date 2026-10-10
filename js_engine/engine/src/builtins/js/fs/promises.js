// node:fs/promises — re-exports the fs.promises namespace built by fs.js
// Vite imports: import fsp, { constants } from "node:fs/promises"
//   fsp      → default export = the promises object
//   constants → named export = fs.constants
'use strict';
var fs = require('fs');
module.exports = fs.promises;
