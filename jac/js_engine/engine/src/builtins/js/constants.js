// Node's deprecated legacy `constants` module: a flat merge of
// os.constants (errno/signals/priority flattened to the top level, matching
// Node's lib/constants.js) plus fs.constants. Still required in the wild —
// graceful-fs (via fixturify/fs-extra) reads O_* flags off it.
'use strict';
const os = require('os');
const fs = require('fs');

const merged = {};
const osConstants = os.constants || {};
for (const key of Object.keys(osConstants)) {
    const value = osConstants[key];
    if (value !== null && typeof value === 'object') {
        Object.assign(merged, value); // errno / signals / priority groups
    } else {
        merged[key] = value;
    }
}
Object.assign(merged, fs.constants || {});

module.exports = merged;
