// Test: 13_rollup_audit — R0.2 of docs/ROLLUP_SUPPORT_PLAN.md.
// Audits every rollup@4.63.1-imported NAPI op not covered by suites 01-12.
// assert() => hard failure (op believed working is broken = new finding).
// gap()    => documented known gap; printed but does not fail the suite.
var m = require('./addon.node');

var failures = 0;
function assert(cond, msg) {
    if (!cond) { failures++; console.error('FAIL: ' + msg); }
}
function gap(cond, msg) {
    if (!cond) { console.log('GAP: ' + msg); }
}

// napi_get_prototype
assert(m.getPrototype({}) === Object.prototype, 'get_prototype({}) is Object.prototype');
assert(m.getPrototype([]) === Array.prototype, 'get_prototype([]) is Array.prototype');

// napi_has_own_property (own vs inherited)
var child = Object.create({ inherited: 2 });
child.own = 1;
assert(m.hasOwn(child, 'own') === true, 'has_own_property sees own prop');
assert(m.hasOwn(child, 'inherited') === false, 'has_own_property ignores inherited prop');

// napi_define_class + napi_wrap + napi_unwrap
var p = new m.AuditPoint(3.5);
assert(typeof p === 'object', 'F1 wrapped instance typeof is object, got ' + typeof p);
assert(p instanceof m.AuditPoint, 'F1 wrapped instance instanceof its class');
assert(Object.getPrototypeOf(p) === m.AuditPoint.prototype, 'F1 JS getPrototypeOf(instance) is Class.prototype');
assert(p.getX() === 3.5, 'unwrap inside prototype method: ' + p.getX());
assert(m.unwrapX(p) === 3.5, 'unwrap from external function: ' + m.unwrapX(p));
assert(m.getPrototype(p) === m.AuditPoint.prototype, 'get_prototype(instance) is class prototype');

// F1 minimal repro: a plain create_object + wrap must remain typeof "object"
// (guards the wrap-key vs KEY_CTOR_KIND collision independent of define_class).
var wp = m.wrapPlain();
assert(typeof wp === 'object', 'F1 wrapped plain object typeof is object, got ' + typeof wp);
assert(m.unwrapX(wp) === 99, 'F1 wrapped plain object still unwraps: ' + m.unwrapX(wp));

// napi_create_reference / get_reference_value / reference_unref / delete_reference
var target = { marker: 1 };
var rc = m.refCycle(target);
assert(rc.same === true, 'get_reference_value returns the referenced object');
assert(rc.rc === 0, 'reference_unref 1->0 reports 0, got ' + rc.rc);

// napi_coerce_to_string
assert(m.coerce(123) === '123', 'coerce_to_string(123)');
assert(m.coerce(null) === 'null', 'coerce_to_string(null)');
assert(m.coerce(undefined) === 'undefined', 'coerce_to_string(undefined)');
assert(m.coerce(true) === 'true', 'coerce_to_string(true)');
assert(m.coerce({ toString: function () { return 'X'; } }) === 'X',
    'F2 coerce_to_string calls user toString, got ' + m.coerce({ toString: function () { return 'X'; } }));
assert(m.coerce([1, 2, 3]) === '1,2,3', 'F2 coerce_to_string array join, got ' + m.coerce([1, 2, 3]));
assert(m.coerce({ valueOf: function () { return 5; } }) === '[object Object]',
    'F2 coerce_to_string string-hint ignores valueOf, got ' + m.coerce({ valueOf: function () { return 5; } }));

// napi_get_value_bool (incl. napi_boolean_expected=7 status for non-bools)
assert(m.getBool(true) === true, 'get_value_bool(true)');
assert(m.getBool(false) === false, 'get_value_bool(false)');
assert(m.getBool(1) === 'status:7', 'get_value_bool(1) returns napi_boolean_expected, got ' + m.getBool(1));

// napi_strict_equals
var same = {};
assert(m.strictEq(same, same) === true, 'strict_equals same object');
assert(m.strictEq({}, {}) === false, 'strict_equals distinct objects');
assert(m.strictEq('a', 'a') === true, 'strict_equals equal strings');
assert(m.strictEq(1, '1') === false, 'strict_equals no coercion');
assert(m.strictEq(NaN, NaN) === false, 'strict_equals NaN');

// napi_typeof
assert(m.typeOf(undefined) === 'undefined', 'typeof undefined');
assert(m.typeOf(null) === 'null', 'typeof null');
assert(m.typeOf(true) === 'boolean', 'typeof boolean');
assert(m.typeOf(42) === 'number', 'typeof number');
assert(m.typeOf('s') === 'string', 'typeof string');
assert(m.typeOf(Symbol('t')) === 'symbol', 'typeof symbol');
assert(m.typeOf({}) === 'object', 'typeof object');
assert(m.typeOf(function () {}) === 'function', 'typeof function');
if (typeof BigInt === 'function') {
    assert(m.typeOf(BigInt(1)) === 'bigint', 'typeof bigint');
}

// error flow: create_error / throw / is_exception_pending /
// get_and_clear_last_exception / napi_is_error
var ef = m.errorFlow();
assert(ef.pending === true, 'is_exception_pending after throw');
assert(ef.pendingAfter === false, 'exception cleared after get_and_clear');
assert(ef.sameErr === true, 'get_and_clear returns the thrown error object');
assert(ef.isErrBefore === true, 'napi_is_error(created error) is true');
assert(ef.isErrAfter === true, 'napi_is_error(cleared exception) is true');

// napi_is_error positive/negative cases from JS-side values.
assert(m.isError(new Error('x')) === true, 'napi_is_error(new Error) true');
assert(m.isError(new TypeError('x')) === true, 'napi_is_error(new TypeError) true');
assert(m.isError({}) === false, 'napi_is_error(plain object) false');
assert(m.isError('not an error') === false, 'napi_is_error(string) false');
assert(m.isError(null) === false, 'napi_is_error(null) false');

// napi_throw_error with code — JS-visible message/name/code/instanceof
var caught = null;
try { m.throwError(); } catch (e) { caught = e; }
assert(caught !== null, 'throw_error reaches JS catch');
assert(caught instanceof Error, 'thrown value instanceof Error');
assert(caught && caught.message === 'kaboom',
    'F3 throw_error message preserved, got "' + (caught && caught.message) + '"');
assert(caught && caught.name === 'Error',
    'F3 throw_error name = "Error", got "' + (caught && caught.name) + '"');
assert(caught && caught.code === 'E_KABOOM',
    'F3 throw_error .code preserved (napi-rs reads err.code), got "' + (caught && caught.code) + '"');

// F3 create path: napi_create_type_error returned to JS must carry the right
// name/message/code (exercises _make_napi_error name + prototype).
var te = m.makeTypeError();
assert(te instanceof TypeError, 'F3 create_type_error is instanceof TypeError');
assert(te.name === 'TypeError', 'F3 create_type_error .name, got "' + te.name + '"');
assert(te.message === 'bad type', 'F3 create_type_error .message, got "' + te.message + '"');
assert(te.code === 'E_TYPE', 'F3 create_type_error .code, got "' + te.code + '"');

// get_value_string_utf8 double-call pattern (napi-rs reads all strings this way)
var sr = m.strRoundtrip('héllo→');
assert(sr.len === 9, 'F4 utf8 length probe (NULL buf) = 9 bytes, got ' + sr.len);
assert(sr.copied === 9, 'F4 utf8 copied = 9 bytes, got ' + sr.copied);
assert(sr.echoed === 'héllo→', 'utf8 roundtrip preserved, got ' + sr.echoed);
var sr0 = m.strRoundtrip('');
assert(sr0.len === 0 && sr0.echoed === '', 'empty string roundtrip');

// F4 regression pins: byte lengths across the UTF-8 size classes.
assert(m.utf8Len('abc') === 3, 'utf8 len ASCII = 3, got ' + m.utf8Len('abc'));
assert(m.utf8Len('é') === 2, 'utf8 len 2-byte = 2, got ' + m.utf8Len('é'));
assert(m.utf8Len('→') === 3, 'utf8 len 3-byte = 3, got ' + m.utf8Len('→'));
assert(m.utf8Len('😀') === 4, 'utf8 len 4-byte (emoji) = 4, got ' + m.utf8Len('😀'));
assert(m.strRoundtrip('😀🎉').echoed === '😀🎉', '4-byte roundtrip preserved');

// Truncation: with an undersized buffer Node copies cap-1 bytes + NUL and
// reports the COPIED count (not the full length; that is the NULL-buf probe).
var tr = m.utf8Truncate('abcdef', 4); // cap 4 -> 3 bytes + NUL
assert(tr.copied === 3, 'truncate copies cap-1 bytes, got ' + tr.copied);
assert(tr.reported === 3, 'truncate reports copied count, got ' + tr.reported);

// napi_call_function + napi_get_global
assert(m.callFn(function (a, b) { return a + b; }) === 42, 'call_function(global, fn, 19, 23)');

// napi_define_properties: value + method + getter
var dp = m.defineProps();
assert(dp.answer === 42, 'define_properties value prop');
assert(dp.twice(21) === 42, 'define_properties method prop');
assert(dp.seven === 7, 'F5 define_properties getter prop, got ' + dp.seven);
var sevenDesc = Object.getOwnPropertyDescriptor(dp, 'seven');
assert(typeof sevenDesc.get === 'function', 'F5 seven is an accessor (has a getter)');
assert(sevenDesc.enumerable === true, 'F5 accessor honors napi_enumerable flag');
// getter+setter round-trip: setter must run, getter must observe the write.
assert(dp.cell === 10, 'F5 accessor getter initial value, got ' + dp.cell);
dp.cell = 25;
assert(dp.cell === 25, 'F5 accessor setter ran and getter observed it, got ' + dp.cell);

// wrap finalizer + env cleanup hook: observational (GC/teardown timing)
for (var i = 0; i < 100; i++) { new m.AuditPoint(i); }
console.log('note: finalizeCount after 100 dropped instances = ' + m.finalizeCount());
m.registerCleanup();
console.log('note: CLEANUP_HOOK_RAN should appear on stderr at exit (known no-op in shim)');

if (failures > 0) { process.exit(1); }
console.log('OK: 13_rollup_audit');
