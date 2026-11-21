---
description: The whole Jac language in one page, in the order a program is built, each construct in a small program that runs, with the command that prints the detail of each; read it first.
keywords: primer
---
# The language in one page

This page is the whole language at survey depth: enough to write a correct small Jac program for
jac on the first try. Every program on it runs, with its output shown under it, and each
section ends with the command that prints the detail.

Jac looks like Python and is not Python: it is statically typed, its blocks are braces, and it has
a second way to structure a program, as a graph that walkers move over. Readers who know Python or
the reference design's `jac` should also read [Coming from Python](coming-from-python.md)
(`jac docs coming-from-python`) and [Coming from the reference design](coming-from-the-reference-design.md)
(`jac docs coming-from-the-reference-design`): much of what they expect is different here.

## A module

A program is a `.jac` file, its module. The top level holds declarations only; code that runs goes
in a `with entry` block, which runs when the program starts. Statements end with `;`, blocks are in
braces, and indentation means nothing. A string written before a declaration is its docstring;
`#` starts a comment, and `#* ... *#` spans lines.

```jac
"""Greets whoever is named on the command line."""
import sys;

glob greeting: str = "hello";

"""The greeting for one name."""
def greet(name: str) -> str {
    return f"{greeting}, {name}";
}

with entry {
    for n in sys.argv[1:] or ["world"] {
        print(greet(n));
    }
}
```

```output
hello, world
```

`jac build hello.jac -o hello` makes a native executable, and `./hello ann` runs it. A
module-level variable is declared with `glob`. More: `jac docs modules`.

Jac reserves words that Python leaves free, among them names a program reaches for: `root`,
`node`, `edge`, `graph`, `entry`, `exit`, `test`, `obj`, `match`, `default`, `report`, `visit`,
`spawn`, `skip`, `wait`, `flow`, `by` and the type words (`list`, `str`, `type`, ...).
None of them can name a variable, a parameter, a field or a function (E0013): choose another word.
`jac docs keyword` lists them all, and the backtick escape for a name another API fixes.

## Variables and types

Every value has a type the compiler knows. Parameters, fields and return values are annotated; a
local takes the type of its first binding and keeps it. `A | B` is a union and `T | None` an
optional value; a test such as `is not None` or `isinstance` narrows it in the code it guards.

```jac
obj Cat {
    has name: str;
}

with entry {
    count = 3;
    ratio: float = count;
    label: int | str = 1;
    label = "one";
    pet: Cat | None = Cat(name="Tom");
    if pet is not None {
        print(pet.name);
    }
    print(count, ratio, label);
}
```

```output
Tom
3 3.0 one
```

A local bound to a second type is an error (E1452), and so is a first binding that gives no type,
such as `x = None;` (W1051: write `x: Cat | None = None;`). A container type names its element
types: `list[int]`, `dict[str, list[float]]`, never a bare `list`. `any` holds a value of any type,
checked as the program runs; it is slower and catches less, so keep it for data whose shape is
unknown until it is read. More: `jac docs variables`, `jac docs types`.

## Numbers, strings and collections

`int` is 64 bits, and arithmetic past its range raises `OverflowError`. `/` gives a `float` and
`//` floors. Sized types (`u8`, `i32`, `f32`, ...) are types of their own; `+%` wraps and `+|`
saturates. Strings, lists, tuples, dicts and sets are Python's, with the same methods, slices,
f-strings and comprehensions. A tuple always has its parentheses, and so does a tuple of targets:
`(a, b) = pair;`, `for (k, v) in d.items()`.

```jac
with entry {
    print(7 / 2, 7 // 2, 2 ** 10, f"{3.14159:.2f}");
    try {
        print(9223372036854775807 + 1);
    } except OverflowError as e {
        print("OverflowError:", e);
    }
    b: u8 = 250;
    print(b +% u8(10), b +| u8(10), "Ada".upper(), "a,b".split(","));
    xs = [3, 1, 2];
    xs.append(4);
    print(sorted(xs), xs[1:3], len({1, 2, 2}), [x * x for x in xs if x > 1]);
    (first, second) = (1, "a");
    ages = {"ann": 31, "bo": 27};
    for (name, age) in ages.items() {
        print(name, age, first, second);
    }
    empty: dict[str, list[int]] = {};
    print(empty, ages.get("cy", 0), {k: v + 1 for (k, v) in ages.items()});
}
```

```output
3.5 3 1024 3.14
OverflowError: integer overflow
4 255 ADA ['a', 'b']
[1, 2, 3, 4] [1, 2] 2 [9, 4, 16]
ann 31 1 a
bo 27 1 a
{} 0 {'ann': 32, 'bo': 28}
```

More: `jac docs numbers`, `jac docs strings`, `jac docs language/collections`, and each
method by name, as `jac docs str.split`.

## Control flow

`if`/`elif`/`else`, `while`, `for x in ...`, `break`, `continue` and a loop's `else` are Python's,
with braces and no `:`. Jac adds a counting loop (`for i = start while cond with step`),
`forever { ... }`, a `switch` that falls through as C's does, and `match` for patterns.

```jac
def kind(n: int) -> str {
    match n {
        case 0:
            return "zero";
        case 1 | 2:
            return "small";
        case x if x < 0:
            return "negative";
        case _:
            return "large";
    }
}

with entry {
    for i = 0 while i < 6 with i += 2 {
        print(i, end=" ");
    }
    print([kind(v) for v in [0, 2, -5, 9]]);
    switch 3 {
        case 3:
            print("falls");
        case 4:
            print("through");
            break;
        default:
            print("not reached");
    }
}
```

```output
0 2 4 ['zero', 'small', 'negative', 'large']
falls
through
```

More: `jac docs control-flow`, `jac docs match`.

## Functions

`def name(params) -> T { ... }`. A function with no parameters has no parentheses
(`def answer -> int`), and one with no `->` returns nothing. Defaults, `*args`, `**kwargs`,
keyword-only and positional-only parameters are Python's, with types; a default is evaluated at
each call that uses it, so `= []` is a new list each time. A `lambda` has typed parameters and a
braced body. A nested function shares the variables of the one around it, and assigns them without
`nonlocal`.

```jac
def area(w: int, h: int = 1) -> int {
    return w * h;
}

def make_counter -> Callable[[], int] {
    count = 0;
    def step -> int {
        count += 1;
        return count;
    }
    return step;
}

with entry {
    print(area(3, 4), area(5), area(h=2, w=3));
    double = lambda (x: int) -> int { return x * 2; };
    print(double(4), sorted(["bb", "a", "ccc"], key=lambda (s: str) -> int { len(s) }));
    c = make_counter();
    print(c(), c());
}
```

```output
12 5 6
8 ['a', 'bb', 'ccc']
1 2
```

A function declared `-> T` returns a `T` on every path (E1004 otherwise), and one that returns a value declares its type (E1003). More: `jac docs functions`.

## Objects: `obj`, `has` and methods

`obj` declares a class. `has` declares its fields, each typed, and the compiler writes the
constructor (fields by position or by name), the `repr`, and an `==` that compares fields. A
default is evaluated for each new object. A method is a `def` in the body; its object is `self`,
which is not written among the parameters.

```jac
obj Account {
    has owner: str,
        balance: float = 0.0,
        history: list[float] = [];

    def deposit(amount: float) -> Account {
        self.balance += amount;
        self.history.append(amount);
        return self;
    }

    static def opening(owner: str) -> Account {
        return Account(owner=owner, balance=10.0);
    }
}

obj Savings(Account) {
    has rate: float = 0.02,
        yearly: float postinit;

    def postinit {
        self.yearly = self.balance * self.rate;
    }
}

with entry {
    a = Account("ann").deposit(5.0).deposit(2.5);
    print(a);
    print(Account.opening("bo").balance, a == Account("ann", 7.5, [5.0, 2.5]));
    s = Savings(owner="cy", balance=100.0);
    print(s.yearly, isinstance(s, Account));
}
```

```output
Account(owner='ann', balance=7.5, history=[5.0, 2.5])
10.0 True
2.0 True
```

- `def postinit` runs after the generated constructor has set the fields. A field declared
  `postinit` in place of a default is left out of the constructor, for `postinit` to set.
- `def init(f: float) { self.c = ...; }` replaces the generated constructor: its parameters are
  the constructor's.
- `static def` has no `self`. A base goes in parentheses; `override def m` replaces a base's
  method, and `super.m()` calls the base's.
- A property is a `has` with accessors: `has f: float { getter { return self.c * 1.8 + 32.0; } }`.
- An object has exactly its declared fields: assigning any other is an error (E1030).
- `node`, `edge`, `walker` (below) and `struct` (a value type) are declared the same way.

More: `jac docs archetypes`, `jac docs fields`, `jac docs methods`, `jac docs inheritance`.

## Declarations and `impl`

A function or method may be declared with `;` in place of its body. An `impl` then restates the
signature and gives the body, in the same module or in an annex file `impl/<module>.impl.jac`, so
the module itself reads as its interface.

```jac
obj Stack {
    has items: list[int] = [];

    """Put x on top."""
    def push(x: int);
}

impl Stack.push(x: int) {
    self.items.append(x);
}

with entry {
    s = Stack();
    s.push(1);
    print(s.items);
}
```

```output
[1]
```

More: `jac docs impl`.

## Enums

Every member ends with a comma. A member without a value takes one more than the one before it.
`enum Status: int { ... }` makes members that are ints too.

```jac
enum Color {
    RED = 1,
    GREEN,
    BLUE,
}

with entry {
    c = Color.GREEN;
    print(c, c.name, c.value, Color(3), Color["RED"], [m.name for m in Color]);
}
```

```output
Color.GREEN GREEN 2 Color.BLUE Color.RED ['RED', 'GREEN', 'BLUE']
```

More: `jac docs enums`.

## Exceptions

An exception class is an `obj` deriving from `Exception`. `try` takes `except`, `else` and
`finally` blocks, and an `except` names a class or a tuple of classes. `raise` takes an instance.

```jac
obj InsufficientFunds(Exception) {}

def withdraw(balance: int, amount: int) -> int {
    if amount > balance {
        raise InsufficientFunds(f"need {amount - balance} more");
    }
    return balance - amount;
}

with entry {
    try {
        withdraw(10, 25);
    } except (InsufficientFunds, ValueError) as e {
        print("refused:", e);
    } finally {
        print("done");
    }
    assert withdraw(10, 3) == 7, "arithmetic";
}
```

```output
refused: need 15 more
done
```

An exception nothing catches prints a traceback and ends the program with status 1.
`with x as y { ... }` uses a context manager, as Python's `with` does. More: `jac docs exceptions`,
`jac docs context-managers`.

## Object-spatial programming

This is Jac's second way to structure a program, and nothing in Python prepares a reader for it.
Data is a graph: **nodes** joined by directed **edges**, both objects with fields. Computation is a
**walker**, an object sent to a node that moves only where its own code sends it. The code that runs
is an **ability**, `can name with T entry { ... }`, triggered by a walker arriving at a `T`.

### Nodes, edges and connecting

`node` and `edge` are declared like `obj`; an edge names the node types it leads from and to.
`a ++> b` connects `a` to `b` with a plain edge, and `a +>:E(f=1):+> b` with an edge of type `E`.
A connect expression's value is its right operand, so `x = root ++> Node(...)` makes a node,
connects it and keeps it. `root` is the node every program starts with.

An **edge reference** in brackets is a list of the nodes reached: `[a -->]` follows `a`'s outgoing
edges, `[a <--]` its incoming ones, `[a ->:E:->]` only edges of type `E`, `[a ->:E:f > 1:->]` those
whose field `f` is over 1, and `[edge a ->:E:->]` gives the edges themselves. A filter
`xs[?:T, f == v]` keeps the items that are `T`s meeting the conditions.

```jac
node Person {
    has name: str,
        age: int = 0;
}

edge Knows: Person --> Person {
    has since: int = 2020;
}

with entry {
    ann = root ++> Person(name="Ann", age=31);
    bo = Person(name="Bo", age=27);
    cy = Person(name="Cy", age=45);
    ann +>:Knows(since=2015):+> bo;
    ann +>:Knows:+> cy;
    bo ++> cy;
    print([p.name for p in [ann ->:Knows:->]], [p.name for p in [ann ->:Knows:since < 2020:->]]);
    print(len([ann -->]), len([cy <--]), [e.since for e in [edge ann ->:Knows:->]]);
    print([p.name for p in [ann ->:Knows:->][?age > 30]], [p.name for p in [root --> [?:Person]]]);
}
```

```output
['Bo', 'Cy'] ['Bo']
2 2 [2015, 2020]
['Cy'] ['Ann']
```

`[a -->]` is a `list[Node]`, whose items have no fields until they are typed: use a typed reference
(`[a ->:Knows:->]` is a `list[Person]`), a type filter (`[a --> [?:Person]]`) or `isinstance`.
`a <++> b` makes two edges, one each way. `a del --> b` removes the edges from `a` to `b`, and
`del n;` of a node takes it out of the graph. Connect an edge only between nodes of the types it
names. More: `jac docs node`, `jac docs edge`, `jac docs connect`,
`jac docs edge-references`.

### Walkers, `spawn` and `visit`

`walker` declares a walker; its fields are the walk's state. `n spawn W()` starts a `W` at node `n`,
runs the whole walk, and returns the walker. `visit` adds nodes to the end of the walker's queue.
When the abilities for the current node are done, the walker moves to the front of the queue, and
when the queue is empty the walk ends. Inside an ability:

| Name | In a walker's ability | In a node's or an edge's ability |
|---|---|---|
| `self` | the walker | the node or edge |
| `here` | the node the walker is at | the same node or edge |
| `visitor` | not available | the walker |

`report v;` appends `v` to the walker's `reports` and carries on. An edge reference with no
source, such as `[-->]`, starts at `here`. The abilities run in this order:

1. The walker's abilities written `with entry` (no type) run once, at the start.
2. At each node, the walker's abilities for that node's type run, then the node's abilities for
   that walker's type. A subtype matches its base's abilities, and the base's run first.
3. When the queue is empty, the exit abilities (`with T exit`) run for every node visited, the
   latest first: the node's, then the walker's. They do not run as the walker moves on.
4. The walker's `with exit` abilities run once, and `spawn` returns.

```jac
node Room {
    has name: str;

    can count with Explorer entry {
        visitor.rooms += 1;
        print("  counted", self.name);
    }
}

walker Explorer {
    has rooms: int = 0;

    can start with Root entry {
        visit [-->];
    }

    can enter with Room entry {
        print("enter", here.name);
        report here.name;
        visit [-->];
    }

    can leave with Room exit {
        print("leave", here.name);
    }

    can done with exit {
        print("done after", self.rooms, "rooms");
    }
}

with entry {
    hall = root ++> Room(name="hall");
    kitchen = hall ++> Room(name="kitchen");
    hall ++> Room(name="cellar");
    kitchen ++> Room(name="pantry");
    w = root spawn Explorer();
    print(w.reports);
}
```

```output
enter hall
  counted hall
enter kitchen
  counted kitchen
enter cellar
  counted cellar
enter pantry
  counted pantry
leave pantry
leave cellar
leave kitchen
leave hall
done after 4 rooms
['hall', 'kitchen', 'cellar', 'pantry']
```

From `hall` the walker queued `kitchen` and `cellar`; at `kitchen` it queued `pantry` behind
`cellar`. `visit [-->]` everywhere makes a walk breadth-first; `visit :0: [-->]` queues at the
front and makes it depth-first. Nothing stops a walker visiting a node twice: a graph with cycles
needs its own record of where the walker has been.

Two statements cut a walk short. `skip;` ends the abilities still to run at the current node, the
walker's and the node's, and the walk goes on. `disengage;` ends the walk at once: no more nodes,
no exit abilities, and `spawn` returns the walker as it is, so a search sets a field and disengages.

`root` is new in every run of a native program; a graph is kept between runs only in an app's
served space. More: `jac docs walkers`, `jac docs visit`, `jac docs abilities`,
`jac docs report`, `jac docs root`, `jac docs graph-queries`.

## Imports and the standard library

`import json;` binds a module. `import from os.path { join }` binds names out of one, with no `;`
after the braces; `import from .util { helper }` is relative to this file, and `include util;`
brings in every name `util` declares. Imports are written at the top level, and a missing module or
name is a compile error.

```jac
import json;
import from math { sqrt }
import from os.path { join, basename }

with entry {
    print(json.dumps({"side": [3, 4]}), sqrt(16.0), basename(join("docs", "a.txt")));
}
```

```output
{"side": [3, 4]} 4.0 a.txt
```

In a native program `import os` does not load CPython's `os`. The standard-library modules jac
has natively (`os`, `json`, `re`, `math` and many more) are written in Jac and compiled into the
program, with Python's names and behavior. A module it does not have natively (`decimal`,
`argparse`, an installed PyPI package) comes from CPython, which the program then embeds, and its
values are Python objects. More: `jac docs library`, `jac docs stdlib`.

## Functions a language model answers: `by` and `sem`

A function declared `by llm()` in place of a body is answered by a language model. The model is
sent the function's arguments as JSON, the schema of its result type and what the `sem` strings
say of the function, its parameters and the type's fields, and its reply is decoded and checked as
that type. `llm(tools=[f, g])` lets the model call the program's functions before it answers, and
a function declared `-> Iterator[ByEvent]` gives the answer as it is written.

```jac
obj Contact {
    has name: str,
        email: str = "";
}

sem Contact.email = "Empty when the text gives none.";

def read_contact(text: str) -> Contact by llm();

sem read_contact = "Find the person the text is about.";

with entry {
    print(read_contact("Mail Ann Lee at ann@example.com about the trip."));
}
```

With `ANTHROPIC_API_KEY` set, it prints `Contact(name='Ann Lee', email='ann@example.com')`;
without it the call raises `ByError`. A docstring is for the code's reader, and the model never
sees it. More: `jac docs by-and-sem`, and `jac skills language-models-and-agents` for an
agent with tools and a chat that streams.

## Tests

A `test` block at a module's top level holds checks, and a failed `assert` fails it. `jac test`
builds and runs the tests; a built program leaves them out. Tests may also live in an annex,
`<module>.test.jac`, which sees the module's names.

```jac
def double(n: int) -> int {
    return n * 2;
}

test "doubling" {
    assert double(2) == 4;
    assert double(-1) == -2, "negatives double too";
}
```

More: `jac docs test`, `jac docs toolchain/test`.

## What to read next

None of these is needed for a small program; each command prints where its part starts.

- **Generics and interfaces.** `def first[T](xs: list[T]) -> T` takes a type parameter, checked in
  its body against its bound (`[T: Ordered]`) and compiled for each type it is called with. An
  interface is an `obj` of abstract methods (`def area -> float abst;`); a class conforms by naming
  it as a base, and a reference to any conforming class is a `dyn Shape`. More:
  `jac docs generics`, `jac docs interfaces`.
- **Structs and sized numbers.** `struct P { has x: float; }` declares a value type: held in place,
  copied on assignment, packed in a list. `i8` to `u64`, `i128`, `f32`, `f16` and `bf16` are types
  that never mix silently. More: `jac docs structs`, `jac docs numbers`.
- **Compile time.** `comptime` code runs as the program compiles: constants, `comptime if` and
  `comptime for`, `comptime assert`, value parameters (`[comptime N: int]`), and decorators, which
  are compile-time calls. More: `jac docs comptime`, `jac docs decorators`.
- **Memory.** A native program counts references and collects cycles (the default `managed`
  profile); `rc` has no collector, and `nogc` proves at compile time that every value has one owner.
  Ownership (`own`, `&`, `&mut`) and regions say who holds a value. More: `jac docs memory`,
  `jac docs ownership`.
- **Apps and spaces.** A project's `archwire.jac` declares its spaces (native, browser, cpython,
  ...) and the apps that run them; a page's call of a server function becomes a request. More:
  `jac docs apps`.
- **Other languages.** `import from c { def strlen(s: str) -> u64; }` binds a C library; C, C++ and
  Rust source compile in as modules; PyPI packages (`jac install --pypi <name>`) and npm
  packages (`import from "lodash" { default as _ }`) run in the program's process. More:
  `jac docs interop`.
- **Kernels and tensors.** The `accel` module's `tensor` holds numbers on a device, and
  `kernel(f).run(n, ...)` runs `f` over them on the processor or an NVIDIA accelerator. `simd[T, N]`
  is a vector of numbers side by side. More: `jac docs accel`.

## The working loop

```sh
jac check app.jac            # every error, each with a code; builds nothing
jac docs E1452               # what a code means, and the fix
jac build app.jac -o app     # a native executable
./app
jac test app.jac             # the module's test blocks
jac fmt app.jac              # the one layout; --fix also rewrites old spellings
```

`check` reports every error it finds, each as `file:line:col: error[CODE]: message`; a code that
starts with `W` is an error too. `jac docs <code>` prints what the code means, an example and the
fix. Once `check` is clean, build and run. `jac docs <word>` prints the page for any keyword,
builtin, module or command, and `jac docs search <text>` finds the rest.

Unless a project's `jac.toml` selects other lint rules, `check` holds the code to the `"clean"`
rules, by design: no comment, no docstring, and every body in its module's `impl` annex (W3050,
W3051, W3055 on a first check). `jac fmt --fix` rewrites a file to them; `jac docs
toolchain/lint` says where a comment's words go instead, and how to select other rules.
