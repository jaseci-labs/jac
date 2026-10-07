// TS-001 through TS-009: TypeScript syntax stripping
// This file contains TypeScript syntax that the engine must strip silently.
// Running it under Node.js requires ts-node or tsx, so the shell-level test
// handles Node (see test_typescript_stripping.sh). The .js file runs under js_engine.

function assert(cond, msg) {
    if (!cond) { console.error("FAIL: " + msg); process.exit(1); }
}
function assertEq(actual, expected, msg) {
    if (actual !== expected) {
        console.error("FAIL: " + msg + " | expected: " + JSON.stringify(expected) + " | actual: " + JSON.stringify(actual));
        process.exit(1);
    }
}

// TS-001: Type annotations on variables and return types
let x: number = 42;
function add(a: number, b: number): number { return a + b; }
assertEq(x, 42,       "TS-001: variable type annotation stripped");
assertEq(add(2, 3), 5,"TS-001: function type annotations stripped");

// TS-002: Interfaces — parsed and ignored
interface Greeter {
    greet(name: string): string;
}
assert(typeof Greeter === "undefined", "TS-002: interface not a runtime value");

// TS-003: Type aliases — parsed and ignored
type StringOrNum = string | number;
assert(typeof StringOrNum === "undefined", "TS-003: type alias not a runtime value");

// TS-004: Generics on functions and classes
function identity<T>(val: T): T { return val; }
assertEq(identity<number>(7), 7, "TS-004: generic function works at runtime");

class Box<T> {
    constructor(public value: T) {}
    get(): T { return this.value; }
}
var b = new Box<string>("hello");
assertEq(b.get(), "hello", "TS-004: generic class works at runtime");

// TS-005: as casts — stripped
var y: unknown = "world";
var s: string = y as string;
assertEq(s, "world", "TS-005: 'as' cast stripped, value unchanged");
var n: number = (y as any) as number;
assertEq(typeof n, "string", "TS-005: cast is a no-op, type unchanged at runtime");

// TS-006: Enum declarations — stripped, no crash
enum Direction { Up, Down, Left, Right }
// In js_engine enums are stripped; runtime value is undefined
assert(typeof Direction === "undefined" || typeof Direction === "object",
    "TS-006: enum stripped or available as object (no crash)");

// TS-007: Non-null assertion x! — stripped
var maybeNull: string | null = "value";
var certain = maybeNull!;
assertEq(certain, "value", "TS-007: non-null assertion stripped");

// TS-008: Optional parameters
function greet(name: string, title?: string): string {
    return title ? title + " " + name : name;
}
assertEq(greet("Alice"),          "Alice",    "TS-008: optional param omitted");
assertEq(greet("Bob", "Dr."),     "Dr. Bob",  "TS-008: optional param provided");

// TS-009: Access modifiers — public/private/protected stripped
class Person {
    public name: string;
    private age: number;
    protected id: number;
    constructor(name: string, age: number, id: number) {
        this.name = name;
        this.age = age;
        this.id = id;
    }
    getAge(): number { return this.age; }
}
var p = new Person("Alice", 30, 1);
assertEq(p.name,       "Alice", "TS-009: public field accessible");
assertEq(p.getAge(),   30,      "TS-009: private field accessible via method");
assertEq(p["age"],     30,      "TS-009: private modifier stripped (JS-accessible)");

process.exit(0);
