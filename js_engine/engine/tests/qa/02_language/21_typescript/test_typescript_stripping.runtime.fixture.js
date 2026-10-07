// Node-semantics baseline: same runtime checks as test_typescript_stripping.fixture.js after TS strip.
function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error("FAIL: " + msg + " | expected: " + JSON.stringify(expected) + " | actual: " + JSON.stringify(actual));
        process.exit(1);
    }
}

let x = 42;
function add(a, b) { return a + b; }
assertEq(x, 42,       "TS-001: variable type annotation stripped");
assertEq(add(2, 3), 5,"TS-001: function type annotations stripped");

assert(typeof Greeter === "undefined", "TS-002: interface not a runtime value");

assert(typeof StringOrNum === "undefined", "TS-003: type alias not a runtime value");

function identity(val) { return val; }
assertEq(identity(7), 7, "TS-004: generic function works at runtime");

class Box {
    constructor(value) { this.value = value; }
    get() { return this.value; }
}
var b = new Box("hello");
assertEq(b.get(), "hello", "TS-004: generic class works at runtime");

var y = "world";
var s = y;
assertEq(s, "world", "TS-005: 'as' cast stripped, value unchanged");
var n = y;
assertEq(typeof n, "string", "TS-005: cast is a no-op, type unchanged at runtime");

assert(typeof Direction === "undefined" || typeof Direction === "object",
    "TS-006: enum stripped or available as object (no crash)");

var maybeNull = "value";
var certain = maybeNull;
assertEq(certain, "value", "TS-007: non-null assertion stripped");

function greet(name, title) {
    return title ? title + " " + name : name;
}
assertEq(greet("Alice"),          "Alice",    "TS-008: optional param omitted");
assertEq(greet("Bob", "Dr."),     "Dr. Bob",  "TS-008: optional param provided");

class Person {
    constructor(name, age, id) {
        this.name = name;
        this.age = age;
        this.id = id;
    }
    getAge() { return this.age; }
}
var p = new Person("Alice", 30, 1);
assertEq(p.name,       "Alice", "TS-009: public field accessible");
assertEq(p.getAge(),   30,      "TS-009: private field accessible via method");
assertEq(p["age"],     30,      "TS-009: private modifier stripped (JS-accessible)");

process.exit(0);
