// Plan: testing_plans/03_ecmascript_language/PROTOTYPES_AND_INHERITANCE_COMPREHENSIVE_TEST_PLAN.md
// Exit-criteria group: ECG-PRT-OPER (PRT-I-*)
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/20_prototypes/test_prototype_inheritance_dispatch.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// PRT-I-001: dynamic this on inherited method
var receiverProto = {
    who: function () {
        return this.name;
    },
};
var r1 = Object.create(receiverProto);
r1.name = "alice";
var r2 = Object.create(receiverProto);
r2.name = "bob";
assertEq(r1.who(), "alice", "PRT-I-001: this is calling object");
assertEq(r2.who(), "bob", "PRT-I-001: same method different receivers");

// PRT-I-002: mutate prototype after instance
function FI2() {}
var fi2inst = new FI2();
FI2.prototype.added = function () {
    return 42;
};
assertEq(fi2inst.added(), 42, "PRT-I-002: late prototype method visible on existing instance");

// PRT-I-003: extends sets prototype links
class BaseI3 {
    constructor() {
        this.t = 1;
    }
}
class SubI3 extends BaseI3 {
    constructor() {
        super();
        this.t = 2;
    }
}
var si3 = new SubI3();
assert(SubI3.prototype instanceof Object, "PRT-I-003: subclass prototype is object");
assertEq(Object.getPrototypeOf(SubI3.prototype), BaseI3.prototype, "PRT-I-003: sub.prototype inherits base.prototype");
assertEq(Object.getPrototypeOf(si3), SubI3.prototype, "PRT-I-003: instance [[Prototype]] is SubI3.prototype");
assert(si3 instanceof SubI3 && si3 instanceof BaseI3, "PRT-I-003: instanceof chain");

// PRT-I-004 / PRT-I-005: super resolves on superclass prototype
class BaseI4 {
    m() {
        return "base";
    }
}
class SubI4 extends BaseI4 {
    m() {
        return super.m() + "-sub";
    }
}
assertEq(new SubI4().m(), "base-sub", "PRT-I-004: super.m uses superclass method");
assertEq(new SubI4().m(), "base-sub", "PRT-I-005: override plus super ordering");

// PRT-I-006: Object.create vs class extends — same dispatch pattern for shared shape
var baseLike = {
    n: function () {
        return this.k + 1;
    },
};
var oc = Object.create(baseLike);
oc.k = 0;
class BaseLikeClass {
    constructor() {
        this.k = 0;
    }
    n() {
        return this.k + 1;
    }
}
class SubLike extends BaseLikeClass {}
var cc = new SubLike();
assertEq(oc.n(), 1, "PRT-I-006: Object.create style n()");
assertEq(cc.n(), 1, "PRT-I-006: class extends same n() semantics");

__jacDone();
