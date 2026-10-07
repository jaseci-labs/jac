"use strict";
// Mimics tsc/esbuild __toCommonJS: named exports defined as enumerable GETTERS
// on module.exports (not plain value props).
function transform(code) { return "T:" + code; }
function build(opts) { return "B:" + opts; }
var ns = {};
Object.defineProperty(ns, "transform", { get: function () { return transform; }, enumerable: true });
Object.defineProperty(ns, "build",     { get: function () { return build; },     enumerable: true });
module.exports = ns;
