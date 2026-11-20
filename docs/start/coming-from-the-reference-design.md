---
description: Where jac breaks from the reference design - every old form with its jac form and the code it gets, what carries over unchanged, what the reference design has that jac does not, and how to port a reference-design program.
keywords: reference design differences, coming from the reference design
---
# Coming from the reference design

jac defines the Jac language. It is not the reference design's `jac` (jaclang) with another backend: where
the reference design's design was wrong, jac breaks from it on purpose, as a clean break with no compatibility
mode, so a program written for the reference design will often not compile here. This page lists every break, with
the reference design's form, the jac form, the code jac reports for the reference design's form, and why. Read
[The language in one page](primer.md) (`jac docs primer`) first.

Every code below is an error. The reference design's warning codes (`W...`) are kept for the same conditions, and
jac refuses what the reference design only warned about. `jac docs <code>` explains each one.

## What carries over

Most of a reference-design program reads the same here:

- the archetypes `obj`, `node`, `edge` and `walker`, with `has` fields, `def` methods, `init` and
  `postinit`, `static def`, `override`, `abst`, access tags (`:pub`, `:priv`, `:protect`);
- abilities, `can name with T entry|exit { ... }`, and `here`, `self`, `visitor` and `root`;
- `spawn` in either operand order, `visit`, `visit ... else` and `visit ... by`, `disengage`,
  `report`;
- the connect operators `++>`, `<++`, `+>:E:+>`, `<+:E:<+`, and `del` of a node or an edge;
- edge references (`[-->]`, `[a ->:E:->]`, `[edge a -->]`, chains) and filters `[?:T, f == v]`;
- `with entry` and `with entry:__main__`, `glob`, `import from m { ... }`, `include`, `impl`
  blocks, `enum`, `match`, `test` blocks with `assert`, `sem` and `by` functions;
- Python's expressions, builtins, comprehensions, f-strings and standard-library names.

## Spellings: one for each form

Where the reference design accepted two spellings of one thing, jac accepts one. `jac fmt --fix` rewrites the
rows marked "fix" (see [Lint rules](../toolchain/lint.md), `jac docs lint`).

| The reference design | jac | Code | |
|---|---|---|---|
| `def __init__`, `def __post_init__` | `def init`, `def postinit` | W3004 | fix |
| `def f()`, `obj A()`, `enum E()`, `lambda ()` | no parentheses: `def f -> int`, `obj A {` | W3005 | fix |
| `@staticmethod` | `static def` | W3001 | fix |
| `@property` | `has x: T { getter { ... } }` | W3043 | fix |
| `import from __future__ { annotations }` | nothing | W3009 | fix |
| A `;` standing for nothing | no `;` | W3013 | fix |
| `case (a, b):` | `case [a, b]:` | E0155 | fix |
| `sem x is "...";` | `sem x = "...";` | E0156 | fix |
| `async static def` | `static async def` (`comptime override static\|class async def`) | E0158 | fix |
| `def f -> int { e }`: a body's last expression as its value | `return e;` | E0159 | fix |
| A block's last expression statement with no `;` | with `;` | E2084 | fix |
| `lambda (x: int) { x * 3; }`: a lambda of one expression that only computes a value | `lambda (x: int) { x * 3 }`, the expression alone | E0160 | fix |
| `x = (yield v);`, `(yield v);` | `x = yield v;`, `yield v;`: parentheses only inside a larger expression | E0161 | fix |
| `R"..."`, `B"..."`, `br"..."` | `r"..."`, `b"..."`, `rb"..."` | E0162 | fix |
| `0XFF`, `0B1`, `0O7`, `1E3` | `0xFF`, `0b1`, `0o7`, `1e3` | E0163 | fix |
| `visit [-->]` with no `;` | `visit [-->];` | E0002 | fix |
| The last enum member with no `,` | every member ends with `,` | E0002 | fix |
| `[?:Task done == False]` | `[?:Task, done == False]` | E0002 | fix |
| `[root -->](?:Task, done == False)` | `[root -->][?:Task, done == False]` | E0048 | by hand |
| `` [root -->](`?Task) `` | `[root -->][?:Task]` | E0048, E0105 | by hand |
| `a +:E:+> b` | `a +>:E:+> b` | E0005 | by hand |
| `a <+:E:+ b` | `a <+:E:<+ b` | E0005 | by hand |
| `import:py os;`, `import:jac util;` | `import os;`, `import util;` | E0003 | by hand |
| A backtick on a keyword where any word is taken, as after a dot (``x.`type``) | the bare word | E0157 | fix |
| A backtick on a word that is no keyword (`` `name ``) | the bare name | E0014 | by hand |
| An `impl` whose signature has another type, default or return type than its declaration's | the declaration's signature, restated exactly | W3010 | fix |
| An `impl` that renames a parameter, or leaves its parameters out | the declaration's signature, restated exactly | W3010 | by hand |
| Two `impl`s of one function; an `impl` of a function written with a body | one body | E2017, E2016 | by hand |

Two forms keep their spelling and mean what they mean in Python, which is not what the reference design makes of
them. `case (a):` is a group, matching what `case a:` matches; the reference design reads it as a sequence of one
item. `y[a,]` indexes with the one-tuple `(a,)`; the reference design reads it as `y[a]`.

A reference-design `impl` may leave out its signature or restate it with other types, and the reference design compiles it against
the declaration; here the `impl` repeats the declaration's parameters, their types and defaults, and
its return type, so the two cannot drift apart.

```jac
# expect: W3005 x3, W3013, E0155, E0156, E0158, E0002 x3
enum Status() {
    OPEN,
    DONE
}

obj Board() {
    has name: str = "";

    async static def load() -> int {
        return 1;
    }
}

sem Board.name is "The board's name.";

node Task {}

walker Sweep {
    can go with Task entry {
        visit [-->]
    }
}

with entry {
    print(Board().name);;
    match [1, 2] {
        case (x, y):
            print(x, y);
    }
    print(len([root -->][?:Task done == False]));
}
```

## Forms jac refuses

| The reference design | jac | Code | Why |
|---|---|---|---|
| `can f -> int { ... }` as a method | `def f -> int { ... }` | E0034 | `can` is only an ability, with a trigger |
| `edge Road { ... }` | `edge Road: City --> City { ... }` | E2086 | The endpoints type the edge references |
| ``can start with `root entry`` | `can start with Root entry` | E2018 | The root's type is `Root` |
| `lambda x: int : x * 2` | `lambda (x: int) -> int { return x * 2; }` | E0022 | A lambda's body is a block |
| `for i = 0 to i < 10 by i += 1` | `for i = 0 while i < 10 with i += 1` | E0001 | |
| `has y: int by postinit;` | `has y: int postinit;` | E0002 | |
| `test my_test { ... }` | `test "my test" { ... }` | E0001 | A test's name is a string |
| `global x;`, `nonlocal x;` | assign `x` | E0002 | Assigning a global's or an enclosing function's name rebinds it |
| `[node a -->]` | `[a -->]` | E5090 | One spelling |
| `spawn W();` | `root spawn W();` | E5090 | A walk starts at a node |
| `a ++> [b, c];` | a loop, connecting one node at a time | E1097 | Each operand is one node |
| `can` at module level | an ability in a walker, node or edge | E5090 | An ability is triggered by a walk |
| An enum member equal to another's value; `A = 1 + 1` | distinct int or str literals | E5090 | A member is one value, written as a literal |
| `impl Color { RED = 1, }`, `obj A;` | the body in the declaration | E5090 | |
| `async walker W`, `with entry:setup` | a plain archetype; `with entry` or `with entry:__main__` | E5090 | |
| `def answer(q: str) -> str by llm();` in an `obj` | a module-level function that takes the object, with its methods as tools: `def answer(a: Agent, q: str) -> str by llm(tools=[a.search]);` | E5090 | Only a function may be `by` |
| A decorator that wraps at run time (`@lru_cache`) | a call: `glob f = lru_cache(maxsize=None)(f_impl);` | E1490 | A decorator is a compile-time call |
| `type`, `list` and other keywords as names | another name | E0013 | Keywords and type words are reserved |
| `jid(x)` of an `obj` | `jid` of a node or an edge | E1053 | Only nodes and edges have ids |
| An `obj` of only `abst` methods constructed | a class conforming to it | E1280 | It is an interface |
| An interface as a type, `s: Shape` | `dyn Shape`, or `[T: Shape]` | E1482 | An interface has no values of its own |
| `Optional[int]`, `List[int]` | `int \| None`, `list[int]` | E5090 | |
| `cl { ... }`, `cl import ...`, `sv { ... }` | spaces declared in `archwire.jac` | E0005 | Where code runs is the project's to say |

```jac
# expect: E2086, E2018
edge Road {
    has km: int = 0;
}

walker Tour {
    can start with `root entry {
        visit [-->];
    }
}

with entry {
    root spawn Tour();
}
```

## Checks the reference design does not make, and warnings that are errors here

| The reference design | Code | Why |
|---|---|---|
| `x is 1`, `s is "a"` | W3035 | `is` compares identity; compare values with `==` |
| An `if`/`elif` chain repeating a condition that only reads | W3024 | The second branch never runs |
| An `if` whose branches are the same | W3025 | The condition decides nothing |
| `tasks[?:Task, owner == owner]` | W3040 | In the reference design both sides are the item's field and the filter is always true; here the right side is the `owner` in scope, so the text means two things and is refused |
| `hasattr(x, "a") and x.a` where `x`'s class has `a` | W3007 | Write `x is not None and x.a` |
| `getattr(x, "a", None)` where `x`'s class has `a` | W3039 | Write `x?.a` |
| A name nothing declares | W2001 | |
| A module that cannot be found | W1100 | |
| A type that cannot be inferred (`x = None;`, `d = {};`, `list()`) | W1051 | Annotate it |
| A docstring before something that is no declaration | W0060 | A warning here too: it fails nothing |
| A local bound to a second type | E1452 | A local has one type: declare `x: int \| str` |
| `except E as e` where `e` is a local | E1453 | The clause binds a name of its own |
| A bare container type, `xs: list` | E1036 | Write `list[int]` |
| A function with a return type that may end without returning | E1004 | |
| A function that returns a value and declares no return type | E1003 | |
| `save(3);` for `async def save` | E1278 | A coroutine made and dropped never runs |
| `x: u64 = -1` | E1126 | It does not fit |
| `a * b` of an `f32` and a `float` | E1128 | Float types never mix silently |
| `a < b` in `def m[T](a: T, b: T)` | E1110 | A generic body is checked against its bound: write `[T: Ordered]` |
| `Pair(a=1, b="x")` for `obj Pair[T] { has a: T, b: T; }` | E1053 | A generic class keeps its type arguments |

`jac check` also checks `test` blocks, which the reference design's `check` leaves out.

## Same code, another meaning

These compile in both and mean different things. None has a diagnostic.

| Subject | In the reference design | Here |
|---|---|---|
| `[a -->]` | Untyped: any field can be read from an item | A `list[Node]`; reading a field needs a typed reference (`[a ->:E:->]`), a type filter (`[a --> [?:T]]`) or `isinstance` (E1030 otherwise) |
| `a <++> b`, `a <+:E:+> b` | One edge, seen from both ends | Two edges, one each way |
| An ability with the same name in a sub-walker or sub-node | Replaces the base's | Both run, the base's first |
| `skip;` | Ends the ability; the node's other abilities still run | Ends every ability still to run at that node, the walker's and the node's |
| `report v;` | Prints `v` and adds it to the reports; a second spawn starts the list again | Only adds to the reports; a walker spawned again adds to the same list |
| `root` in a program run twice | `jac run` keeps the graph between runs | A native program starts with an empty `root` every run; only an app's served space keeps its graph |
| `del d["k"]` of a dict entry holding a node | Deletes the node from the graph | Removes the entry only; `del n` of a variable typed as a node deletes the node |
| `-2 ** 2` | `4` in the reference design's native code | `-4`, as in Python |
| A parameter default | Evaluated once | Evaluated at each call that leaves the parameter out |
| `def drop` | The native finalizer | An ordinary method; the finalizer is `__del__` |
| Reading a `:priv` member from outside | A warning (W2034) | Not reported |

```jac
node Stop {
    has name: str;

    can greet with Bus entry {
        print("  Stop.greet at", self.name);
    }
}

walker Bus {
    can arrive with Stop entry {
        print("Bus.arrive at", here.name);
        report here.name;
        if here.name == "b" {
            skip;
        }
        visit [-->];
    }
}

walker Express(Bus) {
    can arrive with Stop entry {
        print("Express.arrive at", here.name);
    }
}

with entry {
    a = Stop(name="a");
    b = Stop(name="b");
    a <++> b;
    print(len([edge a <-->]), [s.name for s in [b --> [?:Stop]]]);
    w = a spawn Express();
    print(w.reports);
    a spawn w;
    print(w.reports);
}
```

```output
2 ['a']
Bus.arrive at a
Express.arrive at a
  Stop.greet at a
Bus.arrive at b
['a', 'b']
Bus.arrive at a
Express.arrive at a
  Stop.greet at a
Bus.arrive at b
['a', 'b', 'a', 'b']
```

`a <++> b` made two edges, both of which `[edge a <-->]` lists. Both `arrive` abilities ran, the
base's first. At `b`, `skip` cancelled `Express.arrive` and `Stop.greet`. `report` printed nothing,
and the second walk added to the first walk's reports.

## What the reference design has that jac does not

**Commands.** jac compiles to native executables; nothing runs a `.jac` file in place.

| The reference design | jac |
|---|---|
| `jac run main.jac` | `jac build main.jac -o main`, then `./main` |
| `jac serve main.jac`, `jac start` | declare the app in `archwire.jac`, then `jac run <app>` ([Apps](../apps/index.md), `jac docs apps`) |
| `jac check`, `jac test`, `jac format` | `jac check`, `jac test`, `jac fmt` (`--fix` rewrites old spellings) |
| `pip install byllm`, `jac-client`, `jac-scale` | nothing to install: `by llm()`, the server and the UI are part of jac, each with a standard plugin behind it; Python packages are `jac install --pypi <name>` |

**Plugins.** A reference-design plugin is a Python package a program finds installed, which adds what it likes.
A jac [plugin](../apps/plugins.md) fills one abstraction the language has (where `root` is
kept, who a caller is, which model answers, which UI library a component becomes), a project
names it in `jac.toml`, and no module imports it (`jac docs plugins`). What the reference design's plugins add
is the language's, with a standard plugin behind it:

- **`by llm()`** comes from `stdjac.llm`, not from `byllm` or `mtllm`: `import from stdjac.llm { llm }`, then
  `def f(text: str) -> Ticket by llm();`. Which model answers is not said in source: it is the
  project's `llm` plugin and its settings (`[llm.anthropic] model`, `JAC_LLM_MODEL` where the
  program runs, the key from `ANTHROPIC_API_KEY`). Only a module-level function may be `by`, its
  return type is required and must have a JSON schema, and the reply is decoded and checked as
  that type. Any class conforming to `stdjac.by`'s `By` interface may answer a `by` function. See
  `jac docs by`.
- **What byllm's `by llm(...)` does besides** has its form here. A tool may be a method of one of
  the function's parameters (`tools=[r.read_file]`), and a class, a method and a method's
  parameter take a `sem`. A function declared `-> Iterator[ByEvent]` is answered as the model
  goes: the pieces of its text, its tool calls and their results, each an event. `llm` takes a
  `system_prompt` and a `conversation`, a list of `Message` the call adds its turn to. What a
  request used is given to the function `on_usage` registers.
- **`visit [-->] by llm(...);`** carries over, with two differences. The nodes are a list of one
  node type (E1574 otherwise), and the chooser is any class conforming to `stdjac.by`'s
  `ByChooser`, `llm` among them: `visit [-->] by llm(select=(1, 3), intent="...");`. The walker
  visits the nodes chosen, in the order chosen, and `else` runs when none is. See
  `jac docs visit`.
- **`cl` code** has no keyword. A project's `archwire.jac` declares spaces (a `browser` space for
  pages, a `native` or `cpython` space for the server) and which modules each holds; a page that
  calls a server function makes a request. A component takes its attributes as typed keyword
  parameters, not a `props` object, and a page's route comes from its module's path and its
  `page` function's parameters, not from file names such as `[id].jac`. Which UI library a
  component becomes (React unless `jac.toml` says otherwise) and what bundles the page are the
  space's `ui` and `bundler` plugins, named in `jac.toml` and in no module. See
  `jac docs space`, `jac docs apps/pages` and `jac docs apps/ui-bindings`.
- **jac-scale's decorators** (`@schedule`, `@restspec`, `@job`) are `stdjac.server`'s
  decorators, which record a note on the function as the program compiles:
  `@schedule(interval=60.0)`, `@restspec(method=HTTPMethod.GET, path="/status")`, and `@job`,
  whose function is started with `flow f(x)` and its result taken with `wait`. See
  `jac docs apps/stdjac-server`.

## Porting a program

1. **Fix what stops the fixer by hand.** `jac fmt --fix` writes nothing to a file that still has
   a syntax error it cannot rewrite. Run `jac check main.jac`, and fix the "by hand" rows of
   [the first table](#spellings-one-for-each-form) and the syntax rows of
   [the second](#forms-jac-refuses): `(?:...)` and `` (`?T) `` filters, `+:E:+>` and
   `<+:E:+` connects, `can` methods, the reference design's counting `for`, the reference design's lambdas, `by postinit`, `test`
   names, `global` and `nonlocal`.
2. **Run `jac fmt --fix` on the program's files.** It rewrites every spelling marked "fix" and
   lays the files out.
3. **Run `jac check` again and fix what remains, phase by phase.** Errors of a later phase
   (types, after syntax) show only once the earlier phase is clean. The usual work: give every
   parameter and field a type, give containers their element types, declare a local that holds two
   types as a union, give every edge its endpoints, and type the edge references whose items'
   fields are read.
4. **Review the walkers.** Look for abilities that override a base's by name, `skip` that relied on
   the node's abilities still running, `report` relied on for printing, and graphs expected to
   persist between runs (see [Same code, another meaning](#same-code-another-meaning)).
5. **Replace the reference design's plugins** with `stdjac.llm` and an `archwire.jac`, then `jac build` and
   `jac test`. `jac test` runs a module's plain `with entry` blocks before its tests, and
   not its `with entry:__main__`, so a module with tests keeps the program's main code in
   `with entry:__main__` ([Tests](../language/tests.md#a-programs-main-code-and-its-tests)).

`jac docs <code>` gives the fix for each code `check` reports.
