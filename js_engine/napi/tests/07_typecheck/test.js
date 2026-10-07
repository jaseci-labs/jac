// Test: 07_typecheck — napi_typeof inspection and guarded coercion
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}

// getType
assert(m.getType(undefined)  === 'undefined', 'getType undefined');
assert(m.getType(null)       === 'null',       'getType null');
assert(m.getType(true)       === 'boolean',    'getType boolean');
assert(m.getType(42)         === 'number',     'getType number');
assert(m.getType('hello')    === 'string',     'getType string');
assert(m.getType({})         === 'object',     'getType object');
assert(m.getType([])         === 'object',     'getType array is object');
assert(m.getType(function(){}) === 'function', 'getType function');

// assertNumber — pass-through for numbers
assert(m.assertNumber(3.14) === 3.14, 'assertNumber returns value');
assert(m.assertNumber(0) === 0, 'assertNumber 0');

// assertString — pass-through for strings
assert(m.assertString('ok') === 'ok', 'assertString returns value');

// isIntLike
assert(m.isIntLike(5) === true,     'isIntLike(5) = true');
assert(m.isIntLike(5.0) === true,   'isIntLike(5.0) = true');
assert(m.isIntLike(5.5) === false,  'isIntLike(5.5) = false');
assert(m.isIntLike('5') === false,  'isIntLike("5") = false');
assert(m.isIntLike(0) === true,     'isIntLike(0) = true');
assert(m.isIntLike(-3) === true,    'isIntLike(-3) = true');

console.log('OK: 07_typecheck');
