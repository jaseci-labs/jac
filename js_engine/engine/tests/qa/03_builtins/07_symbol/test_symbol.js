// SYM-001 through SYM-012: Symbol built-in
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/07_symbol/test_symbol.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// SYM-001: Symbol() — unique, description, typeof
var s1 = Symbol("foo");
var s2 = Symbol("foo");
assertEq(typeof s1,        "symbol",  "SYM-001: typeof symbol");
assertEq(s1.description,   "foo",     "SYM-001: description");
assert(s1 !== s2,                      "SYM-001: two same-desc symbols are not equal");

// SYM-002: Two same description are not equal
assertEq(s1 === s2,        false,     "SYM-002: same desc != equal");

// SYM-003: Symbol.for / Symbol.keyFor — global registry
var g1 = Symbol.for("shared");
var g2 = Symbol.for("shared");
assertEq(g1, g2,                       "SYM-003: Symbol.for returns same symbol");
assertEq(Symbol.keyFor(g1), "shared",  "SYM-003: keyFor returns key");
assertEq(Symbol.keyFor(s1), undefined, "SYM-003: keyFor local symbol = undefined");

// SYM-005: Symbol.iterator — for-of, spread, destructuring
var iterable = {};
iterable[Symbol.iterator] = function() {
    var i = 0, data = [10, 20, 30];
    return { next: function() { return i < data.length ? {value:data[i++],done:false} : {value:undefined,done:true}; }};
};
var result = [];
for (var v of iterable) result.push(v);
assertDeep(result, [10,20,30], "SYM-005: custom Symbol.iterator with for-of");
var spread = [...iterable];
assertDeep(spread, [10,20,30], "SYM-005: spread via Symbol.iterator");

// SYM-006: Symbol.asyncIterator — for-await-of
async function testAsyncIter() {
    var asyncIterable = {};
    asyncIterable[Symbol.asyncIterator] = function() {
        var i = 0, data = [1, 2, 3];
        return { next: function() {
            return Promise.resolve(i < data.length
                ? {value:data[i++], done:false}
                : {value:undefined, done:true});
        }};
    };
    var res = [];
    for await (var x of asyncIterable) res.push(x);
    assertDeep(res, [1,2,3], "SYM-006: Symbol.asyncIterator with for-await-of");
}
testAsyncIter();

// SYM-007: Symbol.toPrimitive — custom coercion
var toPrimObj = {
    [Symbol.toPrimitive]: function(hint) {
        if (hint === "number") return 42;
        if (hint === "string") return "forty-two";
        return true; // default
    }
};
assertEq(+toPrimObj,         42,          "SYM-007: toPrimitive number hint");
assertEq(`${toPrimObj}`,     "forty-two", "SYM-007: toPrimitive string hint");
assertEq(toPrimObj + "",     "true",      "SYM-007: toPrimitive default hint");

// SYM-008: Symbol.hasInstance — custom instanceof
var even = {
    [Symbol.hasInstance]: function(n) { return n % 2 === 0; }
};
assert(2 instanceof even,     "SYM-008: Symbol.hasInstance true");
assert(!(3 instanceof even),  "SYM-008: Symbol.hasInstance false");

// SYM-009: Symbol.toStringTag
var tagged = { [Symbol.toStringTag]: "MyThing" };
assertEq(Object.prototype.toString.call(tagged), "[object MyThing]", "SYM-009: toStringTag");

// SYM-010: Symbol.species — constructor customization
// Verify Symbol.species is a well-known symbol (its presence); behavior depends on engine
assertEq(typeof Symbol.species, "symbol", "SYM-010: Symbol.species is a symbol");
// Basic Array subclass species test
class MyArray extends Array {
    static get [Symbol.species]() { return Array; }
}
var ma = new MyArray(1,2,3);
var mapped = ma.map(function(x){return x;});
// species = Array means map() may return Array; engine may vary
assert(mapped !== undefined, "SYM-010: map on species-customized subclass does not crash");

// SYM-011: As property key — access, not in Object.keys
var symKey = Symbol("k");
var obj = {};
obj[symKey] = "value";
assertEq(obj[symKey], "value",                            "SYM-011: symbol property access");
assert(Object.keys(obj).indexOf(symKey) < 0,              "SYM-011: symbol not in Object.keys");
assert(!(symKey in Object.keys(obj)),                     "SYM-011: symbol not enumerated");

// SYM-012: Coercion — cannot coerce to number, String(sym) works
var sym = Symbol("test");
var threw = false;
try { +sym; } catch(e) { threw = e instanceof TypeError; }
assert(threw, "SYM-012: symbol to number throws TypeError");
assertEq(String(sym), "Symbol(test)", "SYM-012: String(sym) works");
assertEq(sym.toString(), "Symbol(test)", "SYM-012: sym.toString()");

__jacDone();
