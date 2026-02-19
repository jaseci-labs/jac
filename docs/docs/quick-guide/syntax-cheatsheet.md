# Syntax Quick Reference

```jac
# ============================================================
# Learn Jac in Y Minutes
# ============================================================
# Jac is a superset of Python with graph-native programming,
# object-spatial walkers, and brace-delimited blocks.
# Run a file with: jac <filename>

# ============================================================
# Comments
# ============================================================

# Single-line comment

#*
    Multi-line
    comment
*#


# ============================================================
# Entry Point
# ============================================================

# Every Jac program starts from a `with entry` block.
# You can have multiple; they run in order.

with entry {
    print("Hello, world!");
}

# Use :__main__ to run only when this is the main module
with entry:__main__ {
    print("Only when run directly");
}


# ============================================================
# Variables & Types
# ============================================================

with entry {
    x: int = 42;                 # Typed variable
    name = "Jac";                # Type inferred
    pi: float = 3.14;
    flag: bool = True;
    nothing: None = None;

    # Jac has the same built-in types as Python:
    # int, float, str, bool, list, tuple, set, dict, bytes, any
}


# ============================================================
# Imports
# ============================================================

# Simple import
import os;
import sys, json;

# Import with alias
import datetime as dt;

# Import specific items from a module
import from math { sqrt, pi, log as logarithm }

# Relative imports
import from .sibling { helper_func }
import from ..parent.mod { SomeClass }

# Include merges a module's namespace into the current scope
include random;


# ============================================================
# Functions (def)
# ============================================================

# Functions use `def`, braces for body, and semicolons
def greet(name: str) -> str {
    return f"Hello, {name}!";
}

# Default parameters and multiple return values
def divmod_example(a: int, b: int = 2) -> tuple[int, int] {
    return (a // b, a % b);
}

# No-arg functions still need parentheses
def say_hi() {
    print("Hi!");
}

# Abstract function (declaration only, no body)
def area() -> float abs;

# Function with all param types (positional-only, regular, *args, kw-only, **kwargs)
def kitchen_sink(
    pos_only: int,
    /,
    regular: str = "default",
    *args: int,
    kw_only: bool = True,
    **kwargs: any
) -> str {
    return "ok";
}


# ============================================================
# Control Flow
# ============================================================

with entry {
    x = 9;

    # --- if / elif / else (no parens needed, braces required) ---
    if x < 5 {
        print("low");
    } elif x < 10 {
        print("medium");
    } else {
        print("high");
    }

    # --- for-in loop ---
    for item in ["a", "b", "c"] {
        print(item);
    }

    # --- for-to-by loop (C-style iteration) ---
    # Syntax: for VAR = START to CONDITION by STEP { ... }
    for i = 0 to i < 10 by i += 2 {
        print(i);   # 0, 2, 4, 6, 8
    }

    # --- while loop (with optional else) ---
    n = 5;
    while n > 0 {
        n -= 1;
    } else {
        print("Loop completed normally");
    }

    # --- break, continue, skip ---
    for i in range(10) {
        if i == 3 { continue; }
        if i == 7 { break; }
        print(i);
    }
}


# ============================================================
# Match (Python-style pattern matching)
# ============================================================

with entry {
    value = 10;
    match value {
        case 1:
            print("one");
        case 2 | 3:
            print("two or three");
        case x if x > 5:
            print(f"big: {x}");
        case _:
            print("other");
    }
}


# ============================================================
# Switch (C-style, with fall-through)
# ============================================================

def check_fruit(fruit: str) {
    switch fruit {
        case "apple":
            print("It's an apple");
            break;
        case "banana":
        case "orange":
            print("banana or orange (fall-through)");
        default:
            print("unknown fruit");
    }
}


# ============================================================
# Collections
# ============================================================

with entry {
    # Lists
    fruits = ["apple", "banana", "cherry"];
    print(fruits[0]);       # apple
    print(fruits[1:3]);     # ["banana", "cherry"]
    print(fruits[-1]);      # cherry

    # Dictionaries
    person = {"name": "Alice", "age": 25};
    print(person["name"]);

    # Tuples (immutable)
    point = (10, 20);
    (x, y) = point;         # Tuple unpacking

    # Sets
    colors = {"red", "green", "blue"};

    # Comprehensions
    squares = [i ** 2 for i in range(5)];
    evens = [i for i in range(10) if i % 2 == 0];
    name_map = {name: len(name) for name in ["alice", "bob"]};

    # Star unpacking
    (first, *rest) = [1, 2, 3, 4];
    print(first);   # 1
    print(rest);    # [2, 3, 4]
}


# ============================================================
# Objects (obj) vs Classes (class)
# ============================================================

# `obj` is like a Python dataclass -- fields are per-instance,
# auto-generates __init__, __eq__, __repr__, etc.
obj Dog {
    has name: str = "Unnamed",
        age: int = 0;

    def bark() {
        print(f"{self.name} says Woof!");
    }
}

# `class` follows standard Python class behavior
class Cat {
    has name: str = "Unnamed";

    def meow() {
        print(f"{self.name} says Meow!");
    }
}

# Inheritance
obj Puppy(Dog) {
    has parent_name: str = "Unknown";

    override def bark() {
        print(f"Puppy of {self.parent_name} yips!");
    }
}

# Generic types with type parameters
obj Result[T, E = Exception] {
    has value: T | None = None,
        error: E | None = None;

    def is_ok() -> bool {
        return self.error is None;
    }
}


# ============================================================
# Has Declarations (fields)
# ============================================================

obj Example {
    # Basic typed fields with defaults
    has name: str,
        count: int = 0;

    # Static (class-level) field
    static has instances: int = 0;

    # Deferred initialization (set in postinit)
    has computed: int by postinit;

    def postinit() {
        self.computed = self.count * 2;
    }
}


# ============================================================
# Access Modifiers
# ============================================================

# At module level creates auth, export, and extern semantics
obj:pub Person {
    has:pub name: str;          # Public (default)
    has:priv ssn: str;          # Private
    has:protect age: int;       # Protected
}


# ============================================================
# Enums
# ============================================================

enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

# Auto-valued enum members
enum Status { PENDING, ACTIVE, DONE }

with entry {
    print(Color.RED.value);      # "red"
    print(Status.ACTIVE.value);  # 2
}


# ============================================================
# Type Aliases
# ============================================================

type JsonPrimitive = str | int | float | bool | None;
type Json = JsonPrimitive | list[Json] | dict[str, Json];

# Generic type alias
type NumberList = list[int | float];


# ============================================================
# Global Variables (glob)
# ============================================================

glob MAX_SIZE: int = 100;
glob greeting: str = "Hello";

def use_global() {
    global greeting;          # Reference module-level glob
    greeting = "Hola";
}


# ============================================================
# Impl Blocks (separate declaration from definition)
# ============================================================

obj Calculator {
    has value: int = 0;

    # Declare methods (no body)
    def add(n: int) -> int;
    def multiply(n: int) -> int;
}

# Define methods separately (can be in a .impl.jac file)
impl Calculator.add(n: int) -> int {
    self.value += n;
    return self.value;
}

impl Calculator.multiply(n: int) -> int {
    self.value *= n;
    return self.value;
}


# ============================================================
# Lambdas
# ============================================================

with entry {
    # Simple lambda (untyped params, colon body)
    add = lambda x, y: x + y;
    print(add(3, 4));

    # Typed lambda with return type
    mul = lambda (x: int, y: int) -> int : x * y;
    print(mul(3, 4));

    # Multi-statement lambda (brace body)
    classify = lambda (score: int) -> str {
        if score >= 90 { return "A"; }
        elif score >= 80 { return "B"; }
        else { return "F"; }
    };
    print(classify(85));
}


# ============================================================
# Pipe Operators
# ============================================================

with entry {
    # Forward pipe: value |> function
    "hello" |> print;
    5 |> str |> print;

    # Backward pipe: function <| value
    print <| "world";

    # Chained pipes
    [3, 1, 2] |> sorted |> list |> print;
}


# ============================================================
# Decorators
# ============================================================

@classmethod
def my_class_method(cls: type) -> str {
    return cls.__name__;
}


# ============================================================
# Try / Except / Finally
# ============================================================

with entry {
    try {
        result = 10 // 0;
    } except ZeroDivisionError as e {
        print(f"Caught: {e}");
    } except Exception {
        print("Some other error");
    } else {
        print("No error occurred");
    } finally {
        print("Always runs");
    }
}


# ============================================================
# With Statement (context managers)
# ============================================================

with entry {
    with open("file.txt") as f {
        data = f.read();
    }

    # Multiple context managers
    with open("a.txt") as a, open("b.txt") as b {
        print(a.read(), b.read());
    }
}


# ============================================================
# Assert
# ============================================================

with entry {
    x = 42;
    assert x == 42;
    assert x > 0, "x must be positive";
}


# ============================================================
# Walrus Operator (:=)
# ============================================================

with entry {
    # Assignment inside expressions
    if (n := len("hello")) > 3 {
        print(f"Long string: {n} chars");
    }
}


# ============================================================
# Test Blocks
# ============================================================

def fib(n: int) -> int {
    if n <= 1 { return n; }
    return fib(n - 1) + fib(n - 2);
}

test "fibonacci base cases" {
    assert fib(0) == 0;
    assert fib(1) == 1;
}

test "fibonacci recursive" {
    for i in range(2, 10) {
        assert fib(i) == fib(i - 1) + fib(i - 2);
    }
}


# ============================================================
# Async / Await
# ============================================================

import asyncio;

async def fetch_data() -> str {
    await asyncio.sleep(1);
    return "data";
}

async def main() {
    result = await fetch_data();
    print(result);
}


# ============================================================
# Flow / Wait (concurrent tasks)
# ============================================================

import from time { sleep }

def slow_task(n: int) -> int {
    sleep(1);
    return n * 2;
}

with entry {
    # `flow` launches a concurrent task, `wait` collects results
    task1 = flow slow_task(1);
    task2 = flow slow_task(2);
    task3 = flow slow_task(3);

    r1 = wait task1;
    r2 = wait task2;
    r3 = wait task3;
    print(r1, r2, r3);   # 2 4 6
}


# ============================================================
# Null-Safe Access (?. and ?[])
# ============================================================

with entry {
    x: list | None = None;
    print(x?.append);      # None (no crash)
    print(x?[0]);           # None (no crash)

    y = [1, 2, 3];
    print(y?[1]);           # 2
    print(y?[99]);          # None (out of bounds returns None)
}


# ============================================================
# Inline Python (::py::)
# ============================================================

with entry {
    result: int = 0;
    ::py::
import sys
result = sys.maxsize
    ::py::
    print(f"Max int: {result}");
}


# ============================================================
# OBJECT SPATIAL PROGRAMMING (OSP)
# ============================================================
# Jac extends the type system with graph-native constructs:
# nodes, edges, walkers, and spatial abilities.


# ============================================================
# Nodes and Edges
# ============================================================

# Nodes are objects that can exist in a graph
node Person {
    has name: str,
        age: int;
}

# Edges connect nodes and can carry data
edge Friendship {
    has since: int;
}


# ============================================================
# Connection Operators
# ============================================================

with entry {
    a = Person(name="Alice", age=25);
    b = Person(name="Bob", age=30);
    c = Person(name="Charlie", age=28);

    # --- Untyped connections ---
    root ++> a;             # Connect root -> a
    a ++> b;                # Connect a -> b
    c <++ a;                # Connect a -> c (backward syntax)
    a <++> b;               # Bidirectional a <-> b

    # --- Typed connections (with edge data) ---
    a +>: Friendship(since=2020) :+> b;
    a +>: Friendship(since=1995) :+> c;

    # --- Typed connection with field assignment ---
    a +>: Friendship : since=2018 :+> b;
}


# ============================================================
# Edge Traversal & Filters (inside [...])
# ============================================================

with entry {
    # Traverse outgoing edges from root
    print([root -->]);                      # All nodes via outgoing edges
    print([root <--]);                      # All nodes via incoming edges
    print([root <-->]);                     # All nodes via any edges

    # Filter by edge type
    print([root ->:Friendship:->]);          # Nodes connected by Friendship edges

    # Filter by edge field values
    print([root ->:Friendship:since > 2018:->]);    # Nodes with since > 2018

    # Get edges themselves (not nodes)
    print([edge root ->:Friendship:->]);    # Friendship edge objects
}


# ============================================================
# Walkers
# ============================================================
# Walkers are objects that traverse graphs.
# They have abilities that trigger on entry/exit of nodes.

walker Greeter {
    has greeting: str = "Hello";

    # Runs when walker enters the root node
    can greet_root with Root entry {
        print(f"{self.greeting} from root!");
        visit [-->];        # Move to connected nodes
    }

    # Runs when walker visits any Person node
    can greet_person with Person entry {
        # `here` = current node, `self` = the walker
        print(f"{self.greeting}, {here.name}!");
        report here.name;   # Collect a value (returned as list)
        visit [-->];         # Continue traversal
    }
}

with entry {
    root ++> Person(name="Alice", age=25);
    root ++> Person(name="Bob", age=30);

    # Spawn a walker at root
    root spawn Greeter();
}


# ============================================================
# Walker Control Flow
# ============================================================

walker SearchWalker {
    has target: str;

    can search with Person entry {
        if here.name == self.target {
            print(f"Found {self.target}!");
            disengage;       # Stop traversal immediately
        }
        report here.name;
        visit [-->] else {
            # Runs when there are no more outgoing nodes
            print("Reached a dead end");
        }
    }
}


# ============================================================
# Node & Edge Abilities
# ============================================================
# Nodes and edges can also have abilities that trigger
# when specific walker types visit them.

node SecureRoom {
    has name: str,
        clearance: int = 0;

    # Triggers when any Visitor walker enters this node
    can on_enter with Visitor entry {
        print(f"Welcome to {self.name}");
    }
}

walker Visitor {
    has clearance: int = 0;

    can visit_room with SecureRoom entry {
        if here.clearance > self.clearance {
            print("Access denied");
            disengage;
        }
        visit [-->];
    }
}


# ============================================================
# Spawn Syntax Variants
# ============================================================

with entry {
    w = Greeter(greeting="Hi");

    # Binary spawn: node spawn walker
    root spawn w;

    # Reverse: walker spawn node
    w spawn root;

    # Spawn returns reported values
    results = root spawn Greeter();
}


# ============================================================
# Async Walkers
# ============================================================

async walker AsyncCrawler {
    has depth: int = 0;

    async can crawl with Root entry {
        print(f"Crawling at depth {self.depth}");
        visit [-->];
    }
}


# ============================================================
# Anonymous Abilities
# ============================================================
# Abilities without names (auto-named by compiler)

node AutoNode {
    has val: int = 0;

    can with entry {
        print(f"Entered node with val={self.val}");
    }
}

walker AutoWalker {
    can with Root entry {
        visit [-->];
    }

    can with AutoNode entry {
        print(f"Visiting: {here.val}");
    }
}


# ============================================================
# Special Variables
# ============================================================
# self     -- the current object/walker
# here     -- the current node (in walker abilities)
# visitor  -- the visiting walker (in node/edge abilities)
# root     -- the root node of the graph


# ============================================================
# Keywords Reference
# ============================================================
# Types:    str, int, float, bool, list, tuple, set, dict, bytes, any, type
# Decl:     obj, class, node, edge, walker, enum, has, can, def, impl, glob, test
# Modifiers: pub, priv, protect, static, override, abs, async
# Control:  if, elif, else, for, to, by, while, match, switch, case, default
# Flow:     return, yield, break, continue, raise, del, assert, skip
# OSP:      visit, spawn, entry, exit, disengage, report, here, visitor, root
# Async:    async, await, flow, wait
# Logic:    and, or, not, in, is
# Other:    import, include, from, as, try, except, finally, with, lambda,
#           global, nonlocal, self, super, init, postinit, type
```
