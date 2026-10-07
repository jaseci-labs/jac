// Test Object.defineProperty with accessor descriptors (get/set)
var passed = 0;
var failed = 0;
function assert(cond, msg) {
    if (cond) { console.log("ok " + (passed + failed + 1) + " - " + msg); passed++; }
    else { console.log("FAIL " + (passed + failed + 1) + " - " + msg); failed++; }
}

// 1. Basic getter
var obj = {};
Object.defineProperty(obj, 'x', {
    get: function() { return 42; }
});
assert(obj.x === 42, "getter returns 42");

// 2. Basic setter
var stored = 0;
var obj2 = {};
Object.defineProperty(obj2, 'val', {
    get: function() { return stored; },
    set: function(v) { stored = v * 2; }
});
obj2.val = 10;
assert(obj2.val === 20, "setter doubles value: " + obj2.val);

// 3. Getter-only (no setter)
var obj3 = {};
Object.defineProperty(obj3, 'ro', {
    get: function() { return "readonly"; }
});
assert(obj3.ro === "readonly", "getter-only property");

// 4. Getter on prototype
var proto = {};
Object.defineProperty(proto, 'inherited', {
    get: function() { return "from proto"; }
});
var child = Object.create(proto);
assert(child.inherited === "from proto", "accessor inherited via prototype");

// 5. Multiple accessor properties
var obj5 = {};
var _a = 1;
var _b = 2;
Object.defineProperty(obj5, 'a', { get: function() { return _a; }, set: function(v) { _a = v; } });
Object.defineProperty(obj5, 'b', { get: function() { return _b; }, set: function(v) { _b = v; } });
assert(obj5.a === 1, "multi accessor a=1");
assert(obj5.b === 2, "multi accessor b=2");
obj5.a = 100;
obj5.b = 200;
assert(obj5.a === 100, "multi accessor a=100 after set");
assert(obj5.b === 200, "multi accessor b=200 after set");

// 6. Computed getter (depends on other property)
var obj6 = { firstName: "John", lastName: "Doe" };
Object.defineProperty(obj6, 'fullName', {
    get: function() { return obj6.firstName + " " + obj6.lastName; }
});
assert(obj6.fullName === "John Doe", "computed getter: " + obj6.fullName);

// 7. Data descriptor still works
var obj7 = {};
Object.defineProperty(obj7, 'data', { value: 99, writable: true });
assert(obj7.data === 99, "data descriptor still works");

console.log("=== accessor_descriptors tests: " + passed + " passed, " + failed + " failed ===");
