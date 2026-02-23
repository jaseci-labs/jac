# Syntax Quick Reference

This page is a **lookup reference**, not a learning guide. For hands-on learning, start with the [AI Day Planner tutorial](../tutorials/first-app/build-ai-day-planner.md) which teaches these concepts progressively.

**Try it:** [Functions](../tutorials/language/basics.md#functions) | [Objects](../tutorials/language/basics.md#objects) | [Walkers & Graphs](../tutorials/language/osp.md) | [AI Integration](../tutorials/ai/quickstart.md) | [Full Reference](../reference/language/foundation.md)

```jac
# ============================================================
# Learn Jac in Y Minutes
# ============================================================
# Jac is a superset of Python with graph-native programming,
# object-spatial walkers, AI-native constructs, and full-stack
# codespaces -- all with brace-delimited blocks.
# Run a file with: jac <filename>

# ============================================================
# Comments & Docstrings
# ============================================================

# Single-line comment

#*
    Multi-line
    comment
*#

# Module-level docstring (no semicolon needed)
"""This module does something useful."""

# Docstrings go BEFORE the declaration they document
"""Object-level docstring."""
obj Documented {

    """Method docstring."""
    def method() {
    }
}


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

    # Union types
    maybe: str | None = None;

    # F-strings
    msg = f"Value: {x}, Pi: {pi:.2f}";
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

# Cross-codespace imports (see Full-Stack section below)
# sv import from ...main { MyWalker }       # Server import in client
# cl import from "@jac/runtime" { Link }    # npm runtime import


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

# Function with all param types
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

# Public function (becomes API endpoint with `jac start`)
def:pub get_items() -> list {
    return [];
}

# Private function
def:priv internal_helper() -> None { }


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

    # --- ternary expression ---
    label = "high" if x > 5 else "low";
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
    unique_lens = {len(s) for s in ["hi", "hey", "hi"]};

    # Generator expression
    total = sum(x ** 2 for x in range(1000));

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

# Forward declaration (define body later or in another file)
obj UserProfile;


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

# Access modifiers work on obj, class, node, edge, walker,
# def, has -- controlling visibility and API exposure

obj:pub Person {
    has:pub name: str;          # Public (default)
    has:priv ssn: str;          # Private
    has:protect age: int;       # Protected
}

# Public walker becomes REST endpoint with `jac start`
walker:pub GetUsers {
    can get with Root entry {
        report [-->];
    }
}

# Private walker enforces per-user auth
walker:priv MyData {
    can get with Root entry {
        report [-->];
    }
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

    # No-arg lambda
    get_42 = lambda : 42;

    # Void lambda (common in JSX event handlers)
    handler = lambda -> None { print("clicked"); };
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

# Tests can spawn walkers and check reports
test "walker test" {
    root ++> Person(name="Alice", age=30);
    result = root spawn Greeter();
    assert len(result.reports) > 0;
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

# Also works inside objects/enums for Python-specific methods
enum Priority {
    LOW = 1,
    HIGH = 2

    ::py::
    def is_urgent(self):
        return self.value >= 2
    ::py::
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

# Nodes with abilities (triggered by walkers)
node SecureRoom {
    has name: str,
        clearance: int = 0;

    can on_enter with Visitor entry {
        print(f"Welcome to {self.name}");
    }

    can on_exit with Visitor exit {
        print(f"Leaving {self.name}");
    }
}

# Node inheritance
node Employee(Person) {
    has department: str;
}

# Edge with methods
edge Weighted {
    has weight: float = 1.0;

    def normalize(max_w: float) -> float {
        return self.weight / max_w;
    }
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

    # --- Chained connections ---
    root ++> a ++> b ++> c;

    # --- Delete edge ---
    a del --> b;

    # --- Delete node ---
    del c;
}


# ============================================================
# Edge Traversal & Filters
# ============================================================

with entry {
    # Traverse outgoing edges from root
    print([root -->]);                      # All nodes via outgoing edges
    print([root <--]);                      # All nodes via incoming edges
    print([root <-->]);                     # All nodes via any edges

    # Filter by edge type
    print([root ->:Friendship:->]);          # Nodes connected by Friendship edges

    # Filter by edge field values
    print([root ->:Friendship:since > 2018:->]);

    # Filter by node type
    print([root -->](?:Person));             # Only Person nodes

    # Filter by node attribute
    print([root -->](?age >= 18));           # Nodes with age >= 18

    # Combined: type + attribute
    print([root -->](?:Person, age > 25));

    # Get edge objects themselves (not target nodes)
    print([edge root -->]);                  # All edge objects
    print([edge root ->:Friendship:->]);     # Friendship edge objects

    # Chained traversal (multi-hop)
    fof = [root ->:Friendship:-> ->:Friendship:->];
}


# ============================================================
# Assign Comprehensions (spatial update)
# ============================================================

with entry {
    # Filter nodes by attribute
    adults = [root -->](?age >= 18);

    # Assign: update matching nodes in-place
    [root -->](?age >= 18)(=verified=True);
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

    # Spawn a walker at root and collect results
    result = root spawn Greeter();
    print(result.reports);   # ["Alice", "Bob"]
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

        # visit...else runs fallback when no outgoing nodes
        visit [-->] else {
            print("Reached a dead end");
        }
    }
}


# ============================================================
# Visit Statement Variants
# ============================================================

walker VisitDemo {
    can demo with Person entry {
        visit [-->];                    # All outgoing nodes
        visit [<--];                    # All incoming nodes
        visit [<-->];                   # Both directions
        visit [-->](?:Person);          # Type-filtered
        visit [->:Friendship:->];       # Via edge type
        visit [->:Friendship:since > 2020:->];  # Edge condition

        visit [-->] else {              # Fallback if nowhere to go
            print("Dead end");
        }

        visit : 0 : [-->];             # First outgoing node only
        visit : -1 : [-->];            # Last outgoing node only

        visit here;                     # Re-visit current node
    }
}


# ============================================================
# Node & Edge Abilities
# ============================================================
# Nodes and edges can have abilities that trigger
# when specific walker types visit them.

node Gateway {
    has name: str;

    # Triggers for any walker
    can on_any with entry {
        print(f"Someone entered {self.name}");
    }

    # Triggers only for specific walker type
    can on_inspector with Inspector entry {
        if visitor.clearance < 5 {
            print("Access denied");
            disengage;
        }
    }

    # Multiple walker types (union)
    can on_multi with Admin | Inspector entry {
        print("Authorized personnel");
    }

    # Exit ability
    can on_leave with Inspector exit {
        print("Inspector leaving");
    }
}

walker Inspector {
    has clearance: int = 0;

    can visit_gateway with Gateway entry {
        # `here` = current Gateway node
        # `self` = the walker
        print(f"Inspecting: {here.name}");
        visit [-->];
    }
}


# ============================================================
# Typed Context Blocks
# ============================================================
# Handle different subtypes with specialized code paths

node Animal { has name: str; }
node Dog(Animal) { has breed: str; }
node Cat(Animal) { has indoor: bool; }

walker AnimalVisitor {
    can visit_animal with Animal entry {
        ->Dog{print(f"{here.name} is a {here.breed} dog");}
        ->Cat{print(f"{here.name} says meow");}
        ->_{print(f"{here.name} is some animal");}
    }
}


# ============================================================
# Spawn Syntax Variants
# ============================================================

with entry {
    w = Greeter(greeting="Hi");

    # Binary spawn: node spawn walker
    root spawn w;

    # Spawn with params
    root spawn Greeter(greeting="Hey");

    # Spawn returns result object
    result = root spawn Greeter();
    print(result.reports);   # List of reported values
    print(result.returns);   # Return value (if any)

    # Reverse: walker spawn node
    w spawn root;
}


# ============================================================
# Walkers as REST APIs
# ============================================================
# Public walkers become HTTP endpoints with `jac start`

walker:pub add_todo {
    has title: str;          # Becomes request body field

    can create with Root entry {
        new_todo = here ++> Todo(title=self.title);
        report new_todo;     # Becomes response body
    }
}

# Endpoint: POST /walker/add_todo
# Body: {"title": "Learn Jac"}

# Public functions also become endpoints
def:pub health_check() -> dict {
    return {"status": "ok"};
}

# @restspec customizes HTTP method and path
import from http { HTTPMethod }

@restspec(method=HTTPMethod.GET, path="/items/{item_id}")
walker:pub get_item {
    has item_id: str;
    can fetch with Root entry {
        report {"id": self.item_id};
    }
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
# Graph Built-in Functions
# ============================================================

with entry {
    p = Person(name="Alice", age=30);
    root ++> p;

    jid(p);              # Unique Jac ID of object
    save(p);             # Persist node to storage
    commit();            # Commit pending changes
    printgraph(root);    # Print graph for debugging
}


# ============================================================
# AI INTEGRATION (by llm)
# ============================================================
# Jac's Meaning Typed Programming lets the compiler
# extract semantics from your code to construct LLM prompts.


# ============================================================
# by llm() -- Delegate Function to LLM
# ============================================================

# The function signature IS the specification.
# Name, param names, types, and return type become the prompt.

def classify_sentiment(text: str) -> str by llm;

# Enums constrain LLM output to valid values
enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }
def categorize(title: str) -> Category by llm();

# Structured output -- every field must be filled
obj Ingredient {
    has name: str,
        cost: float,
        carby: bool;
}
def plan_shopping(recipe: str) -> list[Ingredient] by llm();

# Model configuration
def summarize(text: str) -> str by llm(
    model_name="gpt-4",
    temperature=0.7,
    max_tokens=2000
);

# Streaming response (returns generator)
def stream_story(prompt: str) -> str by llm(stream=True);

# Inline LLM expression
with entry {
    result = "Explain quantum computing simply" by llm;
}


# ============================================================
# sem -- Semantic Descriptions for AI
# ============================================================
# `sem` attaches descriptions to bindings that the compiler
# includes in the LLM prompt. It's not a comment -- it
# changes what the LLM sees at runtime.

sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if high in carbohydrates";

sem plan_shopping = "Generate a shopping list for the given recipe.";

# Parameter-level semantics
sem summarize.text = "The article or document to summarize";
sem summarize.return = "A 2-3 sentence summary";

# Enum value semantics
enum Priority { LOW, MEDIUM, HIGH, CRITICAL }
sem Priority.CRITICAL = "Requires immediate attention within 1 hour";


# ============================================================
# Tool Calling (Agentic AI)
# ============================================================
# Give the LLM access to functions it can call (ReAct loop)

def get_weather(city: str) -> str {
    return f"Weather data for {city}";
}

def search_web(query: str) -> list[str] {
    return [f"Result for {query}"];
}

# The LLM decides which tools to call and in what order
def answer_question(question: str) -> str by llm(
    tools=[get_weather, search_web]
);

# Additional context injection
glob company_info = "TechCorp, products: CloudDB, SecureAuth";

def support_agent(question: str) -> str by llm(
    incl_info={"company": company_info}
);
sem support_agent = "Answer customer questions about our products.";


# ============================================================
# Multimodal AI
# ============================================================

import from byllm { Image }

def describe_image(image: Image) -> str by llm;

with entry {
    desc = describe_image(Image("photo.jpg"));
    desc = describe_image(Image("https://example.com/img.png"));
}


# ============================================================
# FULL-STACK DEVELOPMENT (Codespaces)
# ============================================================
# Jac code can target different execution environments:
#   sv { } = server (Python/PyPI)
#   cl { } = client (JavaScript/npm)
#   na { } = native (C ABI)


# ============================================================
# Codespace Blocks
# ============================================================

# Server code (default -- code outside any block is server)
node Todo {
    has title: str, done: bool = False;
}

def:pub get_todos() -> list {
    return [{"title": t.title} for t in [root -->](?:Todo)];
}

# Client code (compiles to JavaScript/React)
cl {
    def:pub app() -> JsxElement {
        has items: list = [];

        async can with entry {
            items = await get_todos();
        }

        return <div>
            {[<p key={i.title}>{i.title}</p> for i in items]}
        </div>;
    }
}

# Explicit server block
sv {
    node Secret { has value: str; }
}

# Single-statement form (no braces)
sv import from .database { connect_db }
cl import from react { useState }


# ============================================================
# File Extension Conventions
# ============================================================
# .jac           Default (server codespace)
# .sv.jac        Server-only variant
# .cl.jac        Client-only variant (auto client codespace)
# .na.jac        Native variant
# .impl.jac      Implementation annex (method bodies)
# .test.jac      Test annex


# ============================================================
# Client Components (JSX)
# ============================================================

cl {
    def:pub Counter() -> JsxElement {
        # `has` in client components becomes React useState
        has count: int = 0;

        return <div>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}

# JSX syntax reference:
# <div>text</div>               HTML elements
# <Component prop="val" />      Component with props
# {expression}                  JavaScript expression
# {condition and <p>Show</p>}   Conditional render
# {[<li>...</li> for x in xs]}  List rendering
# <div {...props}>               Spread props
# <div className="cls">         Class name (not "class")
# <div style={{"color": "red"}} Inline styles


# ============================================================
# Client State & Lifecycle
# ============================================================

cl {
    def:pub DataView() -> JsxElement {
        has data: list = [];
        has loading: bool = True;

        # Mount effect (runs once on component mount)
        async can with entry {
            data = await fetch("/api/data").then(
                lambda r: any -> any { return r.json(); }
            );
            loading = False;
        }

        # Dependency effect (runs when userId changes)
        # async can with [userId] entry { ... }

        # Multiple dependencies
        # can with (a, b) entry { ... }

        # Cleanup on unmount
        # can with exit { unsubscribe(); }

        if loading { return <p>Loading...</p>; }
        return <div>{data}</div>;
    }
}


# ============================================================
# Server-Client Communication
# ============================================================

# Import server walkers in client code
sv import from ...main { AddTodo, GetTodos }

cl {
    def:pub TodoApp() -> JsxElement {
        has todos: list = [];

        async can with entry {
            result = root spawn GetTodos();
            if result.reports {
                todos = result.reports[0];
            }
        }

        async def add_todo(text: str) -> None {
            result = root spawn AddTodo(title=text);
            if result.reports {
                todos = todos + [result.reports[0]];
            }
        }

        return <div>...</div>;
    }
}


# ============================================================
# Routing (File-Based)
# ============================================================
# pages/index.jac          -> /
# pages/about.jac          -> /about
# pages/users/[id].jac     -> /users/:id  (dynamic param)
# pages/[...notFound].jac  -> *            (catch-all)
# pages/(auth)/layout.jac  -> route group  (no URL segment)
# pages/layout.jac         -> root layout

# Page files export a `page` function:
# cl { def:pub page() -> JsxElement { ... } }

# Layout files use <Outlet /> for child routes:
# cl import from "@jac/runtime" { Outlet }
# cl { def:pub layout() -> JsxElement {
#     return <><nav>...</nav><Outlet /></>;
# } }


# ============================================================
# Authentication (Client)
# ============================================================

# cl import from "@jac/runtime" {
#     jacLogin,       # (email, pass) -> bool
#     jacSignup,      # (email, pass) -> dict
#     jacLogout,      # () -> void
#     jacIsLoggedIn   # () -> bool
# }


# ============================================================
# Special Variables Reference
# ============================================================
# self     -- the current object/walker/node
# here     -- the current node (in walker abilities)
# visitor  -- the visiting walker (in node/edge abilities)
# root     -- the root node of the graph


# ============================================================
# Keywords Reference
# ============================================================
# Types:    str, int, float, bool, list, tuple, set, dict, bytes, any, type
# Decl:     obj, class, node, edge, walker, enum, has, can, def, impl,
#           glob, test, type
# Modifiers: pub, priv, protect, static, override, abs, async
# Control:  if, elif, else, for, to, by, while, match, switch, case, default
# Flow:     return, yield, break, continue, raise, del, assert, skip
# OSP:      visit, spawn, entry, exit, disengage, report, here, visitor, root
# AI:       by, llm, sem
# Async:    async, await, flow, wait
# Logic:    and, or, not, in, is
# Codespace: sv, cl, na
# Other:    import, include, from, as, try, except, finally, with, lambda,
#           global, nonlocal, self, super, init, postinit
```
