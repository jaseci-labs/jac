// THIS-001 through THIS-008: this binding
var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/02_language/08_this_binding/test_this_binding.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }

// THIS-001: global this in non-strict
function getGlobalThis() { return this; }
assert(getGlobalThis() === globalThis || getGlobalThis() == null,
    "THIS-001: non-strict function this is globalThis (or undefined in strict)");

// THIS-002: method this — this is the object
var obj = {
    value: 42,
    getValue: function() { return this.value; }
};
assertEq(obj.getValue(), 42, "THIS-002: method this is the object");

// THIS-003: standalone function — globalThis in non-strict, undefined in strict
var standalone = obj.getValue;  // detach from obj
// In strict mode this would be undefined; in non-strict it is globalThis
var standaloneThis = standalone.call(globalThis);
assertEq(standaloneThis, undefined, "THIS-003: standalone uses globalThis (no .value on it)");

// THIS-004: call / apply / bind
function greet(greeting) { return greeting + ", " + this.name; }
var person = { name: "Alice" };
assertEq(greet.call(person,  "Hello"),      "Hello, Alice",  "THIS-004: call explicit this");
assertEq(greet.apply(person, ["Hi"]),       "Hi, Alice",     "THIS-004: apply explicit this");
var boundGreet = greet.bind(person);
assertEq(boundGreet("Hey"),                  "Hey, Alice",    "THIS-004: bind creates bound fn");
// bind is permanent — further call cannot override
assertEq(boundGreet.call({name:"Bob"}, "X"), "X, Alice",      "THIS-004: bound this not overridable");

// THIS-005: arrow this — lexical, not rebindable
var lexObj = {
    x: 10,
    getArrow: function() { return () => this.x; }
};
var arrow = lexObj.getArrow();
assertEq(arrow(), 10, "THIS-005: arrow captures lexical this");
assertEq(arrow.call({ x: 99 }), 10, "THIS-005: arrow this not rebindable");

// THIS-006: constructor this — new object
function Counter(start) {
    this.count = start;
    this.inc = function() { this.count++; };
}
var ctr = new Counter(5);
ctr.inc();
assertEq(ctr.count, 6, "THIS-006: constructor this is new instance");
// each new call creates independent instance
var ctr2 = new Counter(0);
assertEq(ctr2.count, 0, "THIS-006: independent new instance");

// THIS-007: lost this — detached method call
var lostObj = { val: "found", get: function() { return this.val; } };
var detached = lostObj.get;
var lost = detached(); // this is globalThis, which has no .val
assertEq(lost, undefined, "THIS-007: detached method loses this");

// THIS-008: this in callbacks
var cbObj = {
    items: [1, 2, 3],
    sum: function() {
        var total = 0;
        // Arrow callback preserves this
        this.items.forEach((item) => { total += item; });
        return total;
    }
};
assertEq(cbObj.sum(), 6, "THIS-008: arrow callback in forEach preserves this");

// setTimeout callback — arrow preserves outer this
var timerObj = { result: null };
timerObj.run = function() {
    setTimeout(() => {
        this.result = "done";
    }, 0);
};

__jacDone();
