// CLS-060 through CLS-064: subclass field/static lists must be OWN, not
// appended to the parent's via the class prototype chain. Regression: the
// DEFINE_FIELD append path used a proto-walking get for __FIELDS__ /
// __STATIC_FIELDS__, so (a) `new Parent()` also ran the SUBCLASS's instance
// initializers, and (b) a subclass whose parent had static fields never ran
// its own static initializers (Child.type stayed "parent").
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/14_classes/test_classes_inherited_field_lists.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// CLS-060: parent instances must NOT gain subclass fields
class ParentF { p = 1; }
class ChildF extends ParentF { c = 2; }
var pf = new ParentF();
var cf = new ChildF();
assertEq(pf.p, 1, "CLS-060: parent field on parent");
assert(!Object.prototype.hasOwnProperty.call(pf, "c"),
    "CLS-060: new Parent() does not run subclass initializers");
assertEq(cf.p, 1, "CLS-060: child gets inherited field");
assertEq(cf.c, 2, "CLS-060: child gets own field");

// CLS-061: derived static field overrides parent's
class ParentS { static type = "parent"; }
class ChildS extends ParentS { static type = "child"; }
assertEq(ChildS.type, "child", "CLS-061: derived static field overrides");
assertEq(ParentS.type, "parent", "CLS-061: parent static untouched");
assert(Object.prototype.hasOwnProperty.call(ChildS, "type"),
    "CLS-061: own static property on subclass");

// CLS-062: derived static fields run even when they don't shadow
var ranTag = "";
function tag(v) { ranTag += v; return v; }
class ParentS2 { static a = tag("A"); }
class ChildS2 extends ParentS2 { static b = tag("B"); }
assertEq(ChildS2.b, "B", "CLS-062: non-shadowing derived static runs");
assertEq(ranTag, "AB", "CLS-062: initializers ran once each, in order");

// CLS-063: three-level chain keeps lists separate
class A3 { x = "a"; }
class B3 extends A3 { y = "b"; }
class C3 extends B3 { z = "c"; }
var a3 = new A3(), b3 = new B3(), c3 = new C3();
assert(!("y" in a3) && !("z" in a3), "CLS-063: base instance clean");
assert(b3.x === "a" && b3.y === "b" && !("z" in b3), "CLS-063: middle instance");
assert(c3.x === "a" && c3.y === "b" && c3.z === "c", "CLS-063: leaf instance complete");

// CLS-064: explicit derived ctor path unaffected
class P4 { static type = "p4"; }
class C4 extends P4 {
    static type = "c4";
    constructor() { super(); this.built = true; }
}
assertEq(C4.type, "c4", "CLS-064: static override with explicit ctor");
assert(new C4().built, "CLS-064: ctor still runs");

__jacDone();
