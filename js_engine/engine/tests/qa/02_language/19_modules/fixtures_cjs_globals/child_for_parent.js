// NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NCJS-MOD-004 / NCJS-MOD-005 / NCJS-REQ-104
exports.parentFilename = module.parent ? module.parent.filename : null;
exports.parentId = module.parent ? String(module.parent.id) : "";
exports.isMain = require.main === module;
exports.sameAsMain = module === require.main;
