// Object property descriptor statics: defineProperty/defineProperties/
// getOwnPropertyDescriptor/getOwnPropertyDescriptors/getOwnPropertyNames/getOwnPropertySymbols
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_object_statics_property.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertDeep(actual, expected, msg) { __reg.assertDeep(actual, expected, msg); }

// ═══════════════════════════════════════════════════════════════════════════
// Object.defineProperty()
// ═══════════════════════════════════════════════════════════════════════════

// Data descriptor: value, writable, enumerable, configurable
var dp1 = {};
Object.defineProperty(dp1, "x", {value:42, writable:true, enumerable:true, configurable:true});
assertEq(dp1.x, 42, "defineProperty: sets value");

// writable:false — assignment silently fails
var dp2 = {};
Object.defineProperty(dp2, "ro", {value:10, writable:false, enumerable:true, configurable:false});
dp2.ro = 999;
assertEq(dp2.ro, 10, "defineProperty: writable:false blocks assignment");

// enumerable:false — excluded from Object.keys and for..in
var dp3 = {};
Object.defineProperty(dp3, "hidden", {value:1, writable:true, enumerable:false, configurable:true});
dp3.visible = 2;
var dp3keys = Object.keys(dp3);
assertEq(dp3keys.length, 1, "defineProperty: enumerable:false excluded from keys");
assertEq(dp3keys[0], "visible", "defineProperty: only visible in keys");
var foundHiddenInForIn = false;
for (var k in dp3) { if (k === "hidden") foundHiddenInForIn = true; }
assert(!foundHiddenInForIn, "defineProperty: enumerable:false excluded from for..in");

// configurable:false — cannot delete
var dp4 = {};
Object.defineProperty(dp4, "locked", {value:1, writable:false, enumerable:true, configurable:false});
var deleted = delete dp4.locked;
assertEq(dp4.locked, 1, "defineProperty: configurable:false not deletable");

// configurable:false — cannot redefine with different flags
var dp4threw = false;
try {
    Object.defineProperty(dp4, "locked", {value:1, writable:true, enumerable:true, configurable:false});
} catch(e) {
    dp4threw = true;
}
assert(dp4threw, "defineProperty: configurable:false blocks redefinition");

// Accessor descriptor: get/set
var dp5 = {};
var dp5backing = 0;
Object.defineProperty(dp5, "acc", {
    get: function() { return dp5backing * 2; },
    set: function(v) { dp5backing = v; },
    enumerable: true,
    configurable: true
});
dp5.acc = 5;
assertEq(dp5backing, 5,    "defineProperty: setter receives value");
assertEq(dp5.acc, 10,      "defineProperty: getter returns computed value");

// Cannot mix data and accessor descriptors — value + get should throw TypeError
var dp6threw = false;
try {
    Object.defineProperty({}, "bad", {value:1, get: function(){return 1;}});
} catch(e) {
    dp6threw = true;
}
assert(dp6threw, "defineProperty: mixing value+get throws TypeError");

// Redefine writable data prop to read-only
var dp7 = {x: 1};
Object.defineProperty(dp7, "x", {writable: false});
dp7.x = 999;
assertEq(dp7.x, 1, "defineProperty: redefine to read-only");

// Returns the same object
var dp8 = {};
var dp8ret = Object.defineProperty(dp8, "a", {value:1, writable:true, enumerable:true, configurable:true});
assertEq(dp8ret, dp8, "defineProperty: returns same object");

// Missing descriptor fields default to false/undefined
var dp9 = {};
Object.defineProperty(dp9, "minimal", {value: 42});
var dp9desc = Object.getOwnPropertyDescriptor(dp9, "minimal");
assertEq(dp9desc.value, 42,          "defineProperty: minimal value");
assertEq(dp9desc.writable, false,    "defineProperty: default writable false");
assertEq(dp9desc.enumerable, false,  "defineProperty: default enumerable false");
assertEq(dp9desc.configurable, false,"defineProperty: default configurable false");

// ═══════════════════════════════════════════════════════════════════════════
// Object.defineProperties()
// ═══════════════════════════════════════════════════════════════════════════

// Multiple properties at once
var dpM = {};
Object.defineProperties(dpM, {
    a: {value: 1, enumerable: true, writable: true, configurable: true},
    b: {value: 2, enumerable: true, writable: true, configurable: true},
    c: {value: 3, enumerable: false, writable: true, configurable: true}
});
assertEq(dpM.a, 1, "defineProperties: a");
assertEq(dpM.b, 2, "defineProperties: b");
assertEq(dpM.c, 3, "defineProperties: c (non-enum)");
assertEq(Object.keys(dpM).length, 2, "defineProperties: only 2 enumerable in keys");

// Mix of data and accessor
var dpMix = {};
var dpMixBacking = 0;
Object.defineProperties(dpMix, {
    data: {value: 100, enumerable: true, writable: true, configurable: true},
    acc: {
        get: function() { return dpMixBacking; },
        set: function(v) { dpMixBacking = v; },
        enumerable: true,
        configurable: true
    }
});
assertEq(dpMix.data, 100, "defineProperties: data prop");
dpMix.acc = 7;
assertEq(dpMix.acc, 7,    "defineProperties: accessor");

// Returns same object
var dpRet = {};
var dpRetResult = Object.defineProperties(dpRet, {x: {value: 1, writable:true, enumerable:true, configurable:true}});
assertEq(dpRetResult, dpRet, "defineProperties: returns same object");

// ═══════════════════════════════════════════════════════════════════════════
// Object.getOwnPropertyDescriptor()
// ═══════════════════════════════════════════════════════════════════════════

// Data property
var gd1 = {x: 42};
var gd1desc = Object.getOwnPropertyDescriptor(gd1, "x");
assertEq(gd1desc.value, 42,           "getOwnPropDesc: data value");
assertEq(gd1desc.writable, true,      "getOwnPropDesc: data writable");
assertEq(gd1desc.enumerable, true,    "getOwnPropDesc: data enumerable");
assertEq(gd1desc.configurable, true,  "getOwnPropDesc: data configurable");

// Accessor property
var gd2 = {};
Object.defineProperty(gd2, "acc", {
    get: function() { return 99; },
    set: function(v) {},
    enumerable: false,
    configurable: true
});
var gd2desc = Object.getOwnPropertyDescriptor(gd2, "acc");
assertEq(typeof gd2desc.get, "function",  "getOwnPropDesc: accessor get");
assertEq(typeof gd2desc.set, "function",  "getOwnPropDesc: accessor set");
assertEq(gd2desc.enumerable, false,       "getOwnPropDesc: accessor enumerable");
assertEq(gd2desc.configurable, true,      "getOwnPropDesc: accessor configurable");
assertEq(gd2desc.value, undefined,        "getOwnPropDesc: accessor no value");
assertEq(gd2desc.writable, undefined,     "getOwnPropDesc: accessor no writable");

// Non-existent property → undefined
var gd3desc = Object.getOwnPropertyDescriptor({}, "nope");
assertEq(gd3desc, undefined, "getOwnPropDesc: non-existent → undefined");

// Inherited property → undefined
var gd4 = Object.create({inherited: 1});
var gd4desc = Object.getOwnPropertyDescriptor(gd4, "inherited");
assertEq(gd4desc, undefined, "getOwnPropDesc: inherited → undefined");

// Non-enumerable → still returns descriptor
var gd5 = {};
Object.defineProperty(gd5, "ne", {value: 5, enumerable: false, writable:true, configurable:true});
var gd5desc = Object.getOwnPropertyDescriptor(gd5, "ne");
assertEq(gd5desc.value, 5,          "getOwnPropDesc: non-enum value");
assertEq(gd5desc.enumerable, false, "getOwnPropDesc: non-enum enumerable");

// ═══════════════════════════════════════════════════════════════════════════
// Object.getOwnPropertyDescriptors() — may be absent in js_engine
// ═══════════════════════════════════════════════════════════════════════════

if (typeof Object.getOwnPropertyDescriptors === "function") {
    var gds = {a: 1};
    Object.defineProperty(gds, "b", {value: 2, enumerable: false, writable:true, configurable:true});
    var allDescs = Object.getOwnPropertyDescriptors(gds);

    assertEq(allDescs.a.value, 1,           "getOwnPropDescs: a value");
    assertEq(allDescs.a.enumerable, true,   "getOwnPropDescs: a enumerable");
    assertEq(allDescs.b.value, 2,           "getOwnPropDescs: b value");
    assertEq(allDescs.b.enumerable, false,  "getOwnPropDescs: b non-enumerable");

    // No inherited
    var gdsChild = Object.create({inherited: 99});
    gdsChild.own = 1;
    var gdsChildDescs = Object.getOwnPropertyDescriptors(gdsChild);
    assertEq(gdsChildDescs.own.value, 1,              "getOwnPropDescs: own present");
    assertEq(gdsChildDescs.inherited, undefined,       "getOwnPropDescs: inherited absent");
}

// ═══════════════════════════════════════════════════════════════════════════
// Object.getOwnPropertyNames()
// ═══════════════════════════════════════════════════════════════════════════

// Includes non-enumerable
var gn1 = {a: 1};
Object.defineProperty(gn1, "b", {value: 2, enumerable: false, writable:true, configurable:true});
var gn1names = Object.getOwnPropertyNames(gn1);
assert(gn1names.indexOf("a") >= 0, "getOwnPropNames: includes enumerable");
assert(gn1names.indexOf("b") >= 0, "getOwnPropNames: includes non-enumerable");

// Does NOT include symbol keys
if (typeof Symbol === "function") {
    var gn2 = {};
    gn2[Symbol("s")] = 1;
    gn2.str = 2;
    var gn2names = Object.getOwnPropertyNames(gn2);
    assertEq(gn2names.length, 1, "getOwnPropNames: excludes symbols");
    assertEq(gn2names[0], "str", "getOwnPropNames: only string keys");
}

// Array indices as strings
var gn3 = Object.getOwnPropertyNames([10, 20]);
assert(gn3.indexOf("0") >= 0, "getOwnPropNames: array index '0'");
assert(gn3.indexOf("1") >= 0, "getOwnPropNames: array index '1'");
assert(gn3.indexOf("length") >= 0, "getOwnPropNames: array 'length'");

// Empty object
assertEq(Object.getOwnPropertyNames({}).length, 0, "getOwnPropNames: empty object");

// Excludes inherited
var gn4 = Object.create({fromProto: 1});
gn4.own = 2;
var gn4names = Object.getOwnPropertyNames(gn4);
assert(gn4names.indexOf("own") >= 0,        "getOwnPropNames: includes own");
assert(gn4names.indexOf("fromProto") < 0,   "getOwnPropNames: excludes inherited");

// ═══════════════════════════════════════════════════════════════════════════
// Object.getOwnPropertySymbols() — may be absent in js_engine
// ═══════════════════════════════════════════════════════════════════════════

if (typeof Object.getOwnPropertySymbols === "function" && typeof Symbol === "function") {
    var gs1 = {};
    var gs1sym1 = Symbol("a");
    var gs1sym2 = Symbol("b");
    gs1[gs1sym1] = 1;
    gs1[gs1sym2] = 2;
    gs1.str = 3;

    var gs1syms = Object.getOwnPropertySymbols(gs1);
    assertEq(gs1syms.length, 2, "getOwnPropSymbols: 2 symbol keys");
    assert(gs1syms.indexOf(gs1sym1) >= 0, "getOwnPropSymbols: includes sym1");
    assert(gs1syms.indexOf(gs1sym2) >= 0, "getOwnPropSymbols: includes sym2");

    // Non-enumerable symbol still included
    var gs2 = {};
    var gs2sym = Symbol("hidden");
    Object.defineProperty(gs2, gs2sym, {value:42, enumerable:false, writable:true, configurable:true});
    var gs2syms = Object.getOwnPropertySymbols(gs2);
    assertEq(gs2syms.length, 1, "getOwnPropSymbols: non-enum symbol included");

    // No symbol keys → empty array
    assertEq(Object.getOwnPropertySymbols({a:1}).length, 0, "getOwnPropSymbols: no symbols → empty");
}

__jacDone();
