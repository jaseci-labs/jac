// Helper module for CJS variable tests.
// When require()'d, exposes its own __filename, __dirname,
// module, and exports references so the caller can verify them.

exports.filename  = __filename;
exports.dirname   = __dirname;
exports.moduleRef = module;
exports.exportsRef = exports;

// Mutating module.exports after the fact should be apparent to the caller.
exports.exportsSameAsModuleExports = (exports === module.exports);
