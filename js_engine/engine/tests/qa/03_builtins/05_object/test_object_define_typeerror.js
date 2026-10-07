// Object.defineProperty / defineProperties / Reflect.defineProperty —
// TypeError on non-object target and non-object property descriptor (ES §20.1.2.3,
// §28.1.3, ToPropertyDescriptor §6.2.5.5). Regression coverage for the A11 fix:
// previously these silently no-op'd instead of throwing, and the defineProperties
// descriptor loop had to keep working for exotic `props` (Array/String wrappers)
// whose internal/length keys must not be mistaken for primitive descriptors.
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_object_define_typeerror.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrowsTypeError(fn, msg) { __reg.assertThrowsTypeError(fn, msg); }

// ═══════════════════════════════════════════════════════════════════════════
// Object.defineProperty — non-object target throws TypeError
// ═══════════════════════════════════════════════════════════════════════════

assertThrowsTypeError(function () { Object.defineProperty(1, "x", {value: 1}); },
    "defineProperty: number target throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty("str", "x", {value: 1}); },
    "defineProperty: string target throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty(true, "x", {value: 1}); },
    "defineProperty: boolean target throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty(null, "x", {value: 1}); },
    "defineProperty: null target throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty(undefined, "x", {value: 1}); },
    "defineProperty: undefined target throws TypeError");

// ═══════════════════════════════════════════════════════════════════════════
// Object.defineProperty — non-object descriptor (ToPropertyDescriptor) throws
// ═══════════════════════════════════════════════════════════════════════════

assertThrowsTypeError(function () { Object.defineProperty({}, "x", 5); },
    "defineProperty: number descriptor throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty({}, "x", "str"); },
    "defineProperty: string descriptor throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty({}, "x", true); },
    "defineProperty: boolean descriptor throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty({}, "x", null); },
    "defineProperty: null descriptor throws TypeError");
assertThrowsTypeError(function () { Object.defineProperty({}, "x", undefined); },
    "defineProperty: undefined descriptor throws TypeError");

// ═══════════════════════════════════════════════════════════════════════════
// Object.defineProperties — non-object target throws TypeError
// ═══════════════════════════════════════════════════════════════════════════

assertThrowsTypeError(function () { Object.defineProperties(1, {}); },
    "defineProperties: number target throws TypeError");
assertThrowsTypeError(function () { Object.defineProperties(null, {}); },
    "defineProperties: null target throws TypeError");
assertThrowsTypeError(function () { Object.defineProperties(undefined, {}); },
    "defineProperties: undefined target throws TypeError");

// ═══════════════════════════════════════════════════════════════════════════
// Object.defineProperties — non-object descriptor entry throws TypeError
// (the enumerable own value of `props` must be run through ToPropertyDescriptor)
// ═══════════════════════════════════════════════════════════════════════════

assertThrowsTypeError(function () { Object.defineProperties({}, {a: 1}); },
    "defineProperties: number descriptor entry throws TypeError");
assertThrowsTypeError(function () { Object.defineProperties({}, {a: "str"}); },
    "defineProperties: string descriptor entry throws TypeError");
assertThrowsTypeError(function () { Object.defineProperties({}, {a: false}); },
    "defineProperties: boolean descriptor entry throws TypeError");
assertThrowsTypeError(function () { Object.defineProperties({}, {a: null}); },
    "defineProperties: null descriptor entry throws TypeError");

// ═══════════════════════════════════════════════════════════════════════════
// Reflect.defineProperty — non-object target / descriptor throws TypeError
// ═══════════════════════════════════════════════════════════════════════════

assertThrowsTypeError(function () { Reflect.defineProperty(1, "x", {value: 1}); },
    "Reflect.defineProperty: number target throws TypeError");
assertThrowsTypeError(function () { Reflect.defineProperty({}, "x", 5); },
    "Reflect.defineProperty: number descriptor throws TypeError");

// ═══════════════════════════════════════════════════════════════════════════
// Valid usage still works (the guard must not break the happy path)
// ═══════════════════════════════════════════════════════════════════════════

var ok1 = {};
Object.defineProperty(ok1, "x", {value: 42});
assertEq(ok1.x, 42, "defineProperty: valid data descriptor still works");

var ok2 = {};
Object.defineProperties(ok2, {y: {value: 7}, z: {value: 9}});
assertEq(ok2.y, 7, "defineProperties: valid descriptor y still works");
assertEq(ok2.z, 9, "defineProperties: valid descriptor z still works");

assert(Reflect.defineProperty(ok2, "w", {value: 3}),
    "Reflect.defineProperty: valid descriptor returns true");
assertEq(ok2.w, 3, "Reflect.defineProperty: valid descriptor applied");

// ═══════════════════════════════════════════════════════════════════════════
// Exotic `props` must NOT mis-throw — internal/length keys are skipped, real
// enumerable descriptor properties are still applied (Array & String wrappers).
// ═══════════════════════════════════════════════════════════════════════════

var arrProps = [];
Object.defineProperty(arrProps, "p", {value: {value: 8}, enumerable: true});
var fromArr = {};
Object.defineProperties(fromArr, arrProps);   // must not throw on the array's `length`
assertEq(fromArr.p, 8, "defineProperties: array props — descriptor applied, length skipped");

var strProps = new String();
Object.defineProperty(strProps, "q", {value: {value: 9}, enumerable: true});
var fromStr = {};
Object.defineProperties(fromStr, strProps);   // must not throw on the wrapper's internal/length keys
assertEq(fromStr.q, 9, "defineProperties: String-wrapper props — descriptor applied, internals skipped");

// Accessor-valued descriptor entry: the getter cannot be invoked from the native
// path, so the entry is handled leniently (property created) rather than mis-thrown.
var accProps = {};
Object.defineProperty(accProps, "r", {get: function () { return {value: 1}; }, enumerable: true});
var fromAcc = {};
var accThrew = false;
try { Object.defineProperties(fromAcc, accProps); } catch (e) { accThrew = true; }
assert(!accThrew, "defineProperties: accessor-valued descriptor entry does not mis-throw");
assert(fromAcc.hasOwnProperty("r"), "defineProperties: accessor-valued descriptor entry defines the property");

__jacDone();
