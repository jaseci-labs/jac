// Tests for Object.defineProperties, Object.is, Object.hasOwn, Object.getOwnPropertyDescriptor
var passed = 0;
var failed = 0;
function assert(cond, msg) {
    if (cond) { console.log("OK  " + (passed + failed + 1) + " - " + msg); passed++; }
    else      { console.log("FAIL " + (passed + failed + 1) + " - " + msg); failed++; }
}

// ════════════════════════════════════════════════════════════════════════
// Object.defineProperties
// ════════════════════════════════════════════════════════════════════════

// 1. defineProperties with two data descriptors
var obj1 = {};
Object.defineProperties(obj1, {
    x: { value: 10, writable: true, enumerable: true, configurable: true },
    y: { value: 20, writable: true, enumerable: true, configurable: true }
});
assert(obj1.x === 10, "defineProperties data x=10");
assert(obj1.y === 20, "defineProperties data y=20");

// 2. defineProperties with non-writable descriptor
var obj2 = {};
Object.defineProperties(obj2, {
    ro: { value: "frozen", writable: false, enumerable: true, configurable: false }
});
assert(obj2.ro === "frozen", "defineProperties non-writable value");

// 3. defineProperties with accessor descriptor
var _backing = 0;
var obj3 = {};
Object.defineProperties(obj3, {
    val: {
        get: function() { return _backing; },
        set: function(v) { _backing = v; }
    }
});
obj3.val = 42;
assert(obj3.val === 42, "defineProperties accessor get/set");

// 4. defineProperties mixed data + accessor
var _hidden = 100;
var obj4 = {};
Object.defineProperties(obj4, {
    name: { value: "test", writable: true, enumerable: true, configurable: true },
    computed: {
        get: function() { return _hidden * 2; }
    }
});
assert(obj4.name === "test", "defineProperties mixed: data prop");
assert(obj4.computed === 200, "defineProperties mixed: accessor prop");

// 5. defineProperties returns the target object
var obj5 = {};
var ret = Object.defineProperties(obj5, { a: { value: 1 } });
assert(ret === obj5, "defineProperties returns target object");

// ════════════════════════════════════════════════════════════════════════
// Object.is
// ════════════════════════════════════════════════════════════════════════

// 6. Same values (primitive)
assert(Object.is(1, 1) === true, "Object.is(1, 1) === true");

// 7. Different values
assert(Object.is(1, 2) === false, "Object.is(1, 2) === false");

// 8. String comparison
assert(Object.is("abc", "abc") === true, "Object.is('abc','abc') === true");

// 9. NaN is same as NaN (unlike ===)
assert(Object.is(NaN, NaN) === true, "Object.is(NaN, NaN) === true");

// 10. null vs undefined
assert(Object.is(null, undefined) === false, "Object.is(null, undefined) === false");

// 11. null is null
assert(Object.is(null, null) === true, "Object.is(null, null) === true");

// 12. undefined is undefined
assert(Object.is(undefined, undefined) === true, "Object.is(undefined, undefined) === true");

// 13. boolean same
assert(Object.is(true, true) === true, "Object.is(true, true) === true");
assert(Object.is(false, false) === true, "Object.is(false, false) === true");

// 14. boolean different
assert(Object.is(true, false) === false, "Object.is(true, false) === false");

// 15. Object identity (same ref)
var oref = {};
assert(Object.is(oref, oref) === true, "Object.is(same obj ref) === true");

// 16. Object identity (different refs)
assert(Object.is({}, {}) === false, "Object.is({}, {}) === false");

// 17. String vs Number
assert(Object.is("1", 1) === false, "Object.is('1', 1) === false");

// ════════════════════════════════════════════════════════════════════════
// Object.hasOwn
// ════════════════════════════════════════════════════════════════════════

// 18. Own property exists
var hobj = { a: 1, b: 2 };
assert(Object.hasOwn(hobj, "a") === true, "Object.hasOwn own prop 'a'");

// 19. Own property missing
assert(Object.hasOwn(hobj, "c") === false, "Object.hasOwn missing prop 'c'");

// 20. Inherited property is NOT own
var parent = { inherited: true };
var ch = Object.create(parent);
assert(Object.hasOwn(ch, "inherited") === false, "Object.hasOwn does not find inherited");

// 21. After adding own property
ch.own = 42;
assert(Object.hasOwn(ch, "own") === true, "Object.hasOwn finds own on child");

// 22. After delete
var dobj = { x: 1 };
delete dobj.x;
assert(Object.hasOwn(dobj, "x") === false, "Object.hasOwn false after delete");

// ════════════════════════════════════════════════════════════════════════
// Object.getOwnPropertyDescriptor
// ════════════════════════════════════════════════════════════════════════

// 23. Basic data property descriptor
var gobj = { a: 42 };
var desc = Object.getOwnPropertyDescriptor(gobj, "a");
assert(desc !== undefined, "getOwnPropertyDescriptor returns descriptor");
assert(desc.value === 42, "getOwnPropertyDescriptor .value === 42");
assert(desc.writable === true, "getOwnPropertyDescriptor .writable === true");
assert(desc.enumerable === true, "getOwnPropertyDescriptor .enumerable === true");
assert(desc.configurable === true, "getOwnPropertyDescriptor .configurable === true");

// 24. Non-existent property returns undefined
var desc2 = Object.getOwnPropertyDescriptor(gobj, "missing");
assert(desc2 === undefined, "getOwnPropertyDescriptor undefined for missing key");

// 25. defineProperty then getOwnPropertyDescriptor round-trip
var gobj3 = {};
Object.defineProperty(gobj3, "ro", { value: "readonly", writable: false, enumerable: false, configurable: false });
var desc3 = Object.getOwnPropertyDescriptor(gobj3, "ro");
assert(desc3.value === "readonly", "round-trip .value === 'readonly'");
assert(desc3.writable === false, "round-trip .writable === false");
assert(desc3.enumerable === false, "round-trip .enumerable === false");
assert(desc3.configurable === false, "round-trip .configurable === false");

// 26. Inherited properties are not returned
var pobj = { foo: 1 };
var cobj = Object.create(pobj);
var desc4 = Object.getOwnPropertyDescriptor(cobj, "foo");
assert(desc4 === undefined, "getOwnPropertyDescriptor skips inherited props");

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== object_statics tests: " + passed + " passed, " + failed + " failed ===");
