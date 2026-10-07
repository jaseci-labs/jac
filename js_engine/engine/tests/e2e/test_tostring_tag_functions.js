// test_tostring_tag_functions.js — Object.prototype.toString.call(fn)
//
// Object.prototype.toString.call(x) must return "[object Function]" for all
// callable values: arrow functions, regular function expressions, named
// function declarations, async functions, and generator functions.
// Before the fix, user-defined closures (arrow + regular functions) fell
// through to the generic "[object Object]" branch.

var passed = 0;
var failed = 0;

function test(name, fn) {
    try {
        fn();
        passed++;
    } catch (e) {
        failed++;
        console.log("FAIL: " + name + " — " + e.message);
    }
}
function eq(a, b, msg) {
    if (a !== b) throw new Error((msg || "") + ": expected " + JSON.stringify(b) + " got " + JSON.stringify(a));
}

var ots = Object.prototype.toString;

// Arrow function
test("arrow fn → [object Function]", function() {
    var arrow = (x) => x * 2;
    eq(ots.call(arrow), "[object Function]", "arrow");
});

// Regular function expression
test("function expression → [object Function]", function() {
    var fn = function named() {};
    eq(ots.call(fn), "[object Function]", "function expression");
});

// Function declaration
test("function declaration → [object Function]", function() {
    function decl() {}
    eq(ots.call(decl), "[object Function]", "function declaration");
});

// Async function
test("async function → [object AsyncFunction]", function() {
    async function asyncFn() {}
    eq(ots.call(asyncFn), "[object AsyncFunction]", "async function");
});

// Generator function
test("generator function → [object GeneratorFunction]", function() {
    function* gen() { yield 1; }
    eq(ots.call(gen), "[object GeneratorFunction]", "generator function");
});

// Built-in function
test("built-in Math.abs → [object Function]", function() {
    eq(ots.call(Math.abs), "[object Function]", "Math.abs");
});

// Object must remain Object
test("plain object → [object Object]", function() {
    eq(ots.call({}), "[object Object]", "plain object");
    eq(ots.call({ a: 1 }), "[object Object]", "object with props");
});

// Other types must not regress
test("null → [object Null]", function() {
    eq(ots.call(null), "[object Null]", "null");
});
test("undefined → [object Undefined]", function() {
    eq(ots.call(undefined), "[object Undefined]", "undefined");
});
test("array → [object Array]", function() {
    eq(ots.call([1, 2, 3]), "[object Array]", "array");
});
test("number → [object Number]", function() {
    eq(ots.call(42), "[object Number]", "number");
});
test("string → [object String]", function() {
    eq(ots.call("hi"), "[object String]", "string");
});
test("boolean → [object Boolean]", function() {
    eq(ots.call(true), "[object Boolean]", "boolean");
});

// Rolldown's plugin-normalisation pattern: distinguish fn from object
test("plugin factory (fn) vs plugin object (obj)", function() {
    var pluginFn = function() { return { name: "p" }; };
    var pluginObj = { name: "p", buildStart: function() {} };
    eq(ots.call(pluginFn), "[object Function]", "plugin factory fn");
    eq(ots.call(pluginObj), "[object Object]", "plugin object");
});

// Async generator function
test("async generator fn → [object AsyncGeneratorFunction]", function() {
    async function* agen() { yield 1; }
    eq(ots.call(agen), "[object AsyncGeneratorFunction]", "async generator");
});

console.log("=== Object.prototype.toString function tag: " + passed + " passed, " + failed + " failed ===");
