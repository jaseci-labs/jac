// Phase 2.7: Classes
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

// === Basic class ===
class Animal {
    constructor(name) {
        this.name = name;
        this.alive = true;
    }
    speak() {
        return this.name + " speaks";
    }
    toString() {
        return "Animal(" + this.name + ")";
    }
}

var a = new Animal("Cat");
assert(a.name === "Cat", "basic constructor field");
assert(a.alive === true, "boolean field");
assert(a.speak() === "Cat speaks", "basic method");

// === extends + super() in constructor ===
class Dog extends Animal {
    constructor(name, breed) {
        super(name);
        this.breed = breed;
    }
    speak() {
        return super.speak() + " and barks";
    }
    info() {
        return this.name + " (" + this.breed + ")";
    }
}

var d = new Dog("Rex", "Labrador");
assert(d.name === "Rex", "extends: inherited field via super()");
assert(d.breed === "Labrador", "extends: own field");
assert(d.alive === true, "extends: inherited boolean field via super()");
assert(d.speak() === "Rex speaks and barks", "extends: super.method()");
assert(d.info() === "Rex (Labrador)", "extends: own method using inherited field");

// === Method inheritance (no override) ===
class Cat extends Animal {
    constructor(name) {
        super(name);
    }
}

var c = new Cat("Whiskers");
assert(c.name === "Whiskers", "method inheritance: field");
assert(c.speak() === "Whiskers speaks", "method inheritance: inherited method without override");

// === Static methods ===
class MathHelper {
    static add(a, b) {
        return a + b;
    }
    static PI() {
        return 3.14159;
    }
}

assert(MathHelper.add(2, 3) === 5, "static method: add");
assert(MathHelper.PI() === 3.14159, "static method: PI");

// === instanceof ===
assert(d instanceof Dog, "instanceof: direct");
assert(d instanceof Animal, "instanceof: via prototype chain");
assert(!(a instanceof Dog), "instanceof: not subclass");
assert(a instanceof Animal, "instanceof: base class");
assert(c instanceof Cat, "instanceof: Cat direct");
assert(c instanceof Animal, "instanceof: Cat extends Animal");

// === typeof class ===
assert(typeof Animal === "function", "typeof class === function");
assert(typeof Dog === "function", "typeof subclass === function");

// === Three-level inheritance ===
class GuideDog extends Dog {
    constructor(name, breed, owner) {
        super(name, breed);
        this.owner = owner;
    }
    speak() {
        return super.speak() + " (guide)";
    }
}

var g = new GuideDog("Buddy", "Golden", "Alice");
assert(g.name === "Buddy", "3-level: name from top");
assert(g.breed === "Golden", "3-level: breed from mid");
assert(g.owner === "Alice", "3-level: own field");
assert(g.speak() === "Buddy speaks and barks (guide)", "3-level: super.speak chain");
assert(g instanceof GuideDog, "3-level instanceof GuideDog");
assert(g instanceof Dog, "3-level instanceof Dog");
assert(g instanceof Animal, "3-level instanceof Animal");

// === Class expression ===
var Shape = class {
    constructor(sides) {
        this.sides = sides;
    }
    describe() {
        return "Shape with " + this.sides + " sides";
    }
};

var tri = new Shape(3);
assert(tri.sides === 3, "class expression: field");
assert(tri.describe() === "Shape with 3 sides", "class expression: method");

// === Computed method names ===

// Computed method with a variable key (string)
var methodName = "greet";
class Greeter {
    [methodName]() { return "hello"; }
}
var gr = new Greeter();
assert(typeof gr.greet === "function", "computed method: string key installed");
assert(gr.greet() === "hello", "computed method: string key callable");

// Computed method with Symbol key
var sym = Symbol("myMethod");
class WithSym {
    [sym]() { return 99; }
}
var ws = new WithSym();
assert(typeof ws[sym] === "function", "computed method: Symbol key installed");
assert(ws[sym]() === 99, "computed method: Symbol key callable");

// Computed method with expression
class WithExpr {
    ["get" + "Value"]() { return 42; }
}
var we = new WithExpr();
assert(typeof we.getValue === "function", "computed method: concat expr installed");
assert(we.getValue() === 42, "computed method: concat expr callable");

// Computed method with Symbol.iterator (well-known symbol)
class Rangeable {
    constructor(n) { this.n = n; }
    [Symbol.iterator]() {
        var i = 0;
        var max = this.n;
        return {
            next: function() {
                if (i < max) { return { value: i++, done: false }; }
                return { value: undefined, done: true };
            }
        };
    }
}
var r = new Rangeable(3);
assert(typeof r[Symbol.iterator] === "function", "computed method: Symbol.iterator installed");
var items = [];
for (var x of r) { items.push(x); }
assert(items.length === 3, "computed method: Symbol.iterator for-of length");
assert(items[0] === 0 && items[1] === 1 && items[2] === 2, "computed method: Symbol.iterator for-of values");

// Static computed method
var staticKey = "create";
class Factory {
    static [staticKey](val) { return new Factory(val); }
    constructor(v) { this.v = v; }
}
assert(typeof Factory.create === "function", "computed method: static string key installed");
assert(Factory.create(7).v === 7, "computed method: static callable");

// Computed getter
class WithGetter {
    constructor() { this._x = 10; }
    get ["value"]() { return this._x; }
}
var wg = new WithGetter();
assert(wg.value === 10, "computed getter: string key works");

// Computed setter
class WithSetter {
    constructor() { this._x = 0; }
    get x() { return this._x; }
    set ["x"](v) { this._x = v * 2; }
}
var wset = new WithSetter();
wset.x = 5;
assert(wset.x === 10, "computed setter: string key works");

console.log("\n=== Class tests:" + passed + " passed, " + failed + " failed ===");
