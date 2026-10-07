// Object integrity statics: freeze/isFrozen/seal/isSealed/preventExtensions/isExtensible/
// getPrototypeOf/setPrototypeOf
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_object_statics_integrity.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// ═══════════════════════════════════════════════════════════════════════════
// Object.freeze()
// ═══════════════════════════════════════════════════════════════════════════

// Frozen: existing properties not writable
var fr1 = {x: 1, y: 2};
Object.freeze(fr1);
fr1.x = 999;
assertEq(fr1.x, 1, "freeze: existing prop not writable");

// No new properties can be added
fr1.z = 3;
assertEq(fr1.z, undefined, "freeze: no new properties");

// Existing properties cannot be deleted
delete fr1.x;
assertEq(fr1.x, 1, "freeze: cannot delete");

// Cannot reconfigure
var fr1threw = false;
try {
    Object.defineProperty(fr1, "x", {writable: true});
} catch(e) {
    fr1threw = true;
}
assert(fr1threw, "freeze: cannot reconfigure frozen property");

// Returns the same object
var fr2 = {a: 1};
var fr2ret = Object.freeze(fr2);
assertEq(fr2ret, fr2, "freeze: returns same object");

// Shallow: nested objects are NOT frozen
var fr3 = {inner: {v: 1}};
Object.freeze(fr3);
fr3.inner.v = 99;
assertEq(fr3.inner.v, 99, "freeze: shallow — nested not frozen");

// Already-frozen: idempotent
Object.freeze(fr1);
assertEq(fr1.x, 1, "freeze: re-freeze is idempotent");

// Freezing primitives: no-op, returns value
assertEq(Object.freeze(42), 42,         "freeze: primitive number returns value");
assertEq(Object.freeze("str"), "str",   "freeze: primitive string returns value");
assertEq(Object.freeze(true), true,     "freeze: primitive boolean returns value");

// ═══════════════════════════════════════════════════════════════════════════
// Object.isFrozen() — may be absent in js_engine
// ═══════════════════════════════════════════════════════════════════════════

if (typeof Object.isFrozen === "function") {
    // Frozen object
    var ifr1 = Object.freeze({a: 1});
    assert(Object.isFrozen(ifr1), "isFrozen: frozen object is true");

    // Regular object
    assert(!Object.isFrozen({a: 1}), "isFrozen: regular object is false");

    // Empty non-extensible object is frozen
    var ifr2 = {};
    if (typeof Object.preventExtensions === "function") {
        Object.preventExtensions(ifr2);
        assert(Object.isFrozen(ifr2), "isFrozen: empty non-extensible is frozen");
    }

    // Primitives are frozen
    assert(Object.isFrozen(42),    "isFrozen: number is frozen");
    assert(Object.isFrozen("str"), "isFrozen: string is frozen");
    assert(Object.isFrozen(true),  "isFrozen: boolean is frozen");
}

// ═══════════════════════════════════════════════════════════════════════════
// Object.seal() — may be absent in js_engine
// ═══════════════════════════════════════════════════════════════════════════

if (typeof Object.seal === "function") {
    // Sealed: existing properties writable but not deletable
    var sl1 = {x: 1, y: 2};
    Object.seal(sl1);

    // CAN change property values
    sl1.x = 99;
    assertEq(sl1.x, 99, "seal: can change values");

    // No new properties
    sl1.z = 3;
    assertEq(sl1.z, undefined, "seal: no new properties");

    // Cannot delete
    delete sl1.x;
    assertEq(sl1.x, 99, "seal: cannot delete");

    // Cannot change configurability
    var sl1threw = false;
    try {
        Object.defineProperty(sl1, "x", {configurable: true});
    } catch(e) {
        sl1threw = true;
    }
    assert(sl1threw, "seal: cannot reconfigure");

    // Returns same object
    var sl2 = {a: 1};
    var sl2ret = Object.seal(sl2);
    assertEq(sl2ret, sl2, "seal: returns same object");

    // isSealed
    if (typeof Object.isSealed === "function") {
        assert(Object.isSealed(sl1), "isSealed: sealed object is true");
        assert(!Object.isSealed({a: 1}), "isSealed: regular object is false");
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Object.preventExtensions() / Object.isExtensible() — may be absent
// ═══════════════════════════════════════════════════════════════════════════

if (typeof Object.preventExtensions === "function") {
    // Prevents adding new properties
    var pe1 = {x: 1};
    Object.preventExtensions(pe1);
    pe1.y = 2;
    assertEq(pe1.y, undefined, "preventExtensions: no new properties");

    // Existing properties still modifiable
    pe1.x = 99;
    assertEq(pe1.x, 99, "preventExtensions: existing modifiable");

    // Existing properties still deletable
    delete pe1.x;
    assertEq(pe1.x, undefined, "preventExtensions: existing deletable");

    // Returns same object
    var pe2 = {};
    var pe2ret = Object.preventExtensions(pe2);
    assertEq(pe2ret, pe2, "preventExtensions: returns same object");
}

if (typeof Object.isExtensible === "function") {
    // Normal object is extensible
    assert(Object.isExtensible({}), "isExtensible: normal object is true");

    // After preventExtensions
    if (typeof Object.preventExtensions === "function") {
        var ie1 = {};
        Object.preventExtensions(ie1);
        assert(!Object.isExtensible(ie1), "isExtensible: after preventExtensions is false");
    }

    // Frozen is not extensible
    var ie2 = Object.freeze({a: 1});
    assert(!Object.isExtensible(ie2), "isExtensible: frozen is false");

    // Sealed is not extensible
    if (typeof Object.seal === "function") {
        var ie3 = Object.seal({a: 1});
        assert(!Object.isExtensible(ie3), "isExtensible: sealed is false");
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Object.getPrototypeOf()
// ═══════════════════════════════════════════════════════════════════════════

// Constructor-created object
function Animal() {}
Animal.prototype.kind = "animal";
var dog = new Animal();
assertEq(Object.getPrototypeOf(dog), Animal.prototype, "getPrototypeOf: constructor-created");

// Plain object
assertEq(Object.getPrototypeOf({}), Object.prototype, "getPrototypeOf: plain object");

// null-prototype
var npObj = Object.create(null);
assertEq(Object.getPrototypeOf(npObj), null, "getPrototypeOf: null-prototype");

// ═══════════════════════════════════════════════════════════════════════════
// Object.setPrototypeOf()
// ═══════════════════════════════════════════════════════════════════════════

// Changes prototype — inherited properties change
var sp1 = {x: 1};
var sp1proto = {greet: function(){ return "hello"; }};
Object.setPrototypeOf(sp1, sp1proto);
assertEq(sp1.greet(), "hello", "setPrototypeOf: inherits new method");

// Set to null — removes all inherited methods
var sp2 = {a: 1};
Object.setPrototypeOf(sp2, null);
assertEq(typeof sp2.toString, "undefined", "setPrototypeOf(null): no toString");
assertEq(typeof sp2.hasOwnProperty, "undefined", "setPrototypeOf(null): no hasOwnProperty");
assertEq(sp2.a, 1, "setPrototypeOf(null): own props retained");

// Returns the same object
var sp3 = {};
var sp3ret = Object.setPrototypeOf(sp3, {});
assertEq(sp3ret, sp3, "setPrototypeOf: returns same object");

// Circular prototype should throw TypeError
var sp4a = {};
var sp4b = Object.create(sp4a);
var sp4threw = false;
try {
    Object.setPrototypeOf(sp4a, sp4b);
} catch(e) {
    sp4threw = true;
}
assert(sp4threw, "setPrototypeOf: circular proto throws TypeError");

__jacDone();
