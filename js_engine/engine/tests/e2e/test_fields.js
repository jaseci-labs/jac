// Phase 2.7 — Instance & Static Field Initializers
var passed = 0;
var failed = 0;

function assert(condition, label) {
    if (condition) {
        passed++;
    } else {
        console.log("FAIL: " + label);
        failed++;
    }
}

// === Instance field with initializer ===
class Counter {
    count = 0;
    name = "default";
    constructor(name) {
        this.name = name;
    }
    increment() {
        this.count = this.count + 1;
    }
}

var c1 = new Counter("c1");
assert(c1.count === 0, "instance field: default value");
assert(c1.name === "c1", "instance field: overridden by constructor");
c1.increment();
assert(c1.count === 1, "instance field: mutated");

var c2 = new Counter("c2");
assert(c2.count === 0, "instance field: separate instance");

// === Instance field without initializer ===
class Bare {
    x;
}
var b = new Bare();
assert(b.x === undefined, "field without initializer: undefined");

// === Static field ===
class Config {
    static MAX = 100;
    static label = "settings";
    get() { return Config.MAX; }
}
assert(Config.MAX === 100, "static field: MAX");
assert(Config.label === "settings", "static field: label");
var cfg = new Config();
assert(cfg.get() === 100, "static field: accessible via class name");

// === Static and instance fields mixed ===
class Mixed {
    static count = 0;
    id = 0;
    constructor() {
        Mixed.count = Mixed.count + 1;
        this.id = Mixed.count;
    }
}
var m1 = new Mixed();
var m2 = new Mixed();
assert(m1.id === 1, "mixed: first id");
assert(m2.id === 2, "mixed: second id");
assert(Mixed.count === 2, "mixed: static count");

// === Field with expression initializer ===
class Computed {
    x = 2 + 3;
    arr = [];
}
var cp = new Computed();
assert(cp.x === 5, "computed field: 2+3");

// === Inheritance + fields ===
class Base {
    kind = "base";
    constructor(v) { this.v = v; }
}
class Derived extends Base {
    extra = 42;
    constructor(v) { super(v); }
}
var dr = new Derived("hello");
assert(dr.v === "hello", "inheritance field: constructor arg");
assert(dr.extra === 42, "inheritance field: own field");
assert(dr.kind === "base", "inheritance field: inherited field init");
console.log("\n=== Field tests:" + passed + " passed, " + failed + " failed ===");
