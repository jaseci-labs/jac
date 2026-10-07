// Phase 2.7 — Private Fields (#name)
// Private fields are stored internally under a mangled key (__priv_#name).
// Bracket notation c["#count"] returns undefined, matching real JS engine behaviour.
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

// === Basic private field with initializer ===
class Counter {
  #count = 0;
  increment() {
    this.#count = this.#count + 1;
  }
  getCount() {
    return this.#count;
  }
}
var c = new Counter();
assert(c.getCount() === 0, "private: initial value");
c.increment();
c.increment();
assert(c.getCount() === 2, "private: after 2 increments");
assert(c["#count"] === undefined, "private: bracket notation returns undefined");

// === Private field without initializer ===
class Bare {
  #x;
  getX() { return this.#x; }
}
var b = new Bare();
assert(b.getX() === undefined, "private bare: undefined");

// === Private field set in constructor ===
class Point {
  #x;
  #y;
  constructor(x, y) {
    this.#x = x;
    this.#y = y;
  }
  getX() { return this.#x; }
  getY() { return this.#y; }
  toString() { return this.#x + "," + this.#y; }
}
var p = new Point(3, 4);
assert(p.getX() === 3, "private ctor: x");
assert(p.getY() === 4, "private ctor: y");
assert(p.toString() === "3,4", "private ctor: toString");
assert(p["#x"] === undefined, "private ctor: #x not accessible externally");
assert(p["#y"] === undefined, "private ctor: #y not accessible externally");

// === Private field with initializer expression ===
class Computed {
  #base = 10;
  #double = 20;
  sum() { return this.#base + this.#double; }
}
var cp = new Computed();
assert(cp.sum() === 30, "private expr: sum");

// === Multiple instances are independent ===
var c1 = new Counter();
var c2 = new Counter();
c1.increment();
assert(c1.getCount() === 1, "private isolation: c1");
assert(c2.getCount() === 0, "private isolation: c2");

// === Inheritance with private fields ===
class Animal {
  #name;
  constructor(name) { this.#name = name; }
  getName() { return this.#name; }
}
class Dog extends Animal {
  #breed;
  constructor(name, breed) {
    super(name);
    this.#breed = breed;
  }
  describe() { return this.getName() + " (" + this.#breed + ")"; }
}
var d = new Dog("Rex", "Labrador");
assert(d.getName() === "Rex", "private inheritance: name");
assert(d.describe() === "Rex (Labrador)", "private inheritance: describe");

// === Static private field ===
class Registry {
  static #count = 0;
  constructor() { Registry.#count = Registry.#count + 1; }
  static getCount() { return Registry.#count; }
}
new Registry();
new Registry();
assert(Registry.getCount() === 2, "static private: count");
console.log("\n=== Private Field tests:" + passed + " passed, " + failed + " failed ===");
