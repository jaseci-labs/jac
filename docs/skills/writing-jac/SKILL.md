---
name: writing-jac
description: Use when writing or changing Jac code that jac compiles, in any project or file: the loop of looking up, writing, checking, formatting, building and testing, and the rules that prevent most first-try errors.
---
# Writing Jac with jac

## When to use this

Use it for any Jac you write or edit: a new module, a fix, a feature. Every other jac skill builds on it. For narrower tasks continue in the sibling skill:

| Task | Skill |
|---|---|
| An error you do not understand | `resolving-diagnostics` |
| Data as nodes, edges and walkers | `modelling-with-graphs` |
| A new project from an empty directory | `starting-a-project` |
| Tests, formatting, lint rules | `testing-and-formatting` |
| Code written for the reference design | `porting-from-the-reference-design` |
| A Python module to translate | `porting-from-python` |

## Before you start

What you know of Python and of the reference design (jaseci's jaclang) is partly wrong here. jac's documentation ships with the binary and describes the jac you run. Read the overview once per session, then look up each construct before you use it:

```sh
jac docs start/primer               # the language in one page: read it once
jac docs start/coming-from-python   # what a Python habit gets wrong here, with its code
jac docs                            # the map: every section and its pages
jac docs section <heading>          # a section's pages, each with what it covers
jac docs <word>                     # the page that defines a keyword, builtin, module or code
jac docs search "<text>"            # pages and sections that mention a text
```

Look up, do not guess: `jac docs lambda`, `jac docs glob`, `jac docs init`, `jac docs import`, `jac docs os.path`.

## Steps

1. **Find the project's root.** The nearest directory at or above your file that holds `jac.toml`. Its settings (lint rules, test directories, memory profile) apply to your code. `jac docs toolchain/projects`.
2. **Write the code** by the rules below. Annotate every parameter and field, and the return type of every function that returns a value.
3. **Check it.** `jac check <main.jac>` checks that module, everything it imports, and the main module's own tests. It prints nothing and exits 0 when the program is right.
4. **Resolve every error**, first to last, with `jac docs <code>` for each code you do not know. Run `check` again until it is quiet. The skill `resolving-diagnostics` has the method.
5. **Format what you changed:** `jac fmt <files>`. Never hand-format; `fmt` decides all spacing.
6. **Build and run:** `jac run main.jac` builds the program and runs it; `jac build main.jac -o main && ./main` keeps the executable.
7. **Test:** `jac test <module.jac>` for the module you changed (`testing-and-formatting`).

A program that shows most of the rules at once:

```jac
import from math { sqrt }

glob runs: int = 0;

obj Point {
    has x: float,
        y: float,
        norm: float postinit;

    def postinit {
        self.norm = sqrt(self.x * self.x + self.y * self.y);
    }

    def scaled(k: float) -> Point;
}

impl Point.scaled(k: float) -> Point {
    return Point(self.x * k, self.y * k);
}

def farthest(points: list[Point]) -> Point | None {
    runs += 1;
    best: Point | None = None;
    for p in points {
        if best is None or p.norm > best.norm {
            best = p;
        }
    }
    return best;
}

with entry:__main__ {
    pts = [Point(3.0, 4.0), Point(1.0, 1.0)];
    far = farthest(pts + [pts[1].scaled(10.0)]);
    if far is not None {
        print(far.x, round(far.norm, 2));
    }
    names: dict[str, int] = {};
    for (i, p) in enumerate(pts) {
        names[f"p{i}"] = int(p.norm);
    }
    (first, second) = (pts[0].norm, pts[1].norm);
    print(names, first > second, runs);
    print(sorted(names, key=lambda (k: str) -> int { -names[k] }));
}

test "farthest picks the longest" {
    far = farthest([Point(1.0, 0.0), Point(0.0, 2.0)]);
    assert far is not None and far.y == 2.0;
}
```

```output
10.0 14.14
{'p0': 5, 'p1': 1} True 1
['p0', 'p1']
```

## The rules

1. **Statements end with `;`, blocks are in braces.** `if x > 0 {`, never `if x > 0:`. Indentation means nothing.
2. **A module's top level holds declarations only.** Code that runs goes in an entry block. A program's main code goes in `with entry:__main__ { ... }`, which runs when the module is the program, and not when it is imported or under `jac test`; a plain `with entry { ... }` runs in all three, before the tests, so keep it for setup the tests rely on. A module variable is `glob name: T = value;`, and a function assigns it directly: there is no `global` or `nonlocal`. Names bound in an entry block are locals of that block, not globals.
3. **No empty parentheses in a declaration:** `def total -> int`, `obj Cart {`, `lambda { ... }`. A call keeps them: `cart.total()`.
4. **Methods do not list `self`.** It is there in every method; write it only to state how the receiver is taken.
5. **Data types are `obj` with `has` fields.** The constructor comes from the fields, positional or by name. `def init(...)` replaces it and `def postinit` runs after it; not `__init__`. `class` is not built yet: write `obj`.
6. **A local has one type,** its first binding's. A local that may hold two kinds of value is declared with a union where it is first bound: `best: Point | None = None;`.
7. **Unpacking takes parentheses:** `(a, b) = pair;`, `for (k, v) in d.items() { ... }`.
8. **Many everyday words are reserved.** The type words (`list`, `str`, `type`, `dict`, `bytes`, `any`, the number types) and `root`, `node`, `edge`, `graph`, `entry`, `exit`, `test`, `obj`, `match`, `default`, `report`, `visit`, `spawn`, `skip`, `wait`, `flow`, `by` cannot name a variable, a parameter, a field or a function (E0013): choose another word. `jac docs keyword` lists them all.
9. **A lambda is typed and braced:** `lambda (x: int) -> int { x * 2 }`. A body of one expression, with no `;`, is its value.
10. **A declared return type is returned on every path.** Falling off the end is an error, unless the type admits `None`.
11. **Bodies may live in impl blocks.** Declare `def scaled(k: float) -> Point;` and write `impl Point.scaled(k: float) -> Point { ... }` with the same signature, in the module or in its annex `impl/<module>.impl.jac` (`jac docs language/impl`).
12. **Imports are declarations at the top:** `import os;`, `import from os.path { join, basename }`, `include util;` for every name. A name resolves to the project's own module first, then jac's runtime, then the native standard library, then CPython's (`jac docs library`). Python packages are `using-python-packages`.
13. **`int` is 64 bits** and raises `OverflowError` past that. A decorator is a compile-time call, not a run-time wrapper.

## What a correct result looks like

```sh
jac check main.jac              # no output, exit status 0
jac fmt --check main.jac        # no output, exit status 0
jac build main.jac -o main      # no output off a terminal, exit status 0
./main                             # what the program prints
jac test main.jac               # "N passed" for each module, exit status 0
```

## Mistakes to expect

| Code | What it means | Fix |
|---|---|---|
| E0002 | A `;` (or `}`, `,`) is missing | Add it at the place shown |
| E0001 | Python's `if x:` or `for k, v in` | Braces; `for (k, v) in` |
| E0005 | A statement at the top level, or `from x import y` | Move it into `with entry`; `import from x { y }` |
| W3005 | `def f()`, `obj A()` | `def f`, `obj A` |
| W3004 | `def __init__`, `def __post_init__` | `def init`, `def postinit` |
| E5090 | Something jac does not build yet: an import inside a function, a module-level `can`, a `class` deriving from an `obj` | The form the entry's fix names |
| E1452 | A local bound to a second type | Declare the union where it is first bound, or use a second name |
| W1051 | A type that cannot be inferred: `x = None`, `{}` never used, `defaultdict(list)` | Annotate it; `defaultdict(list[int])` |
| E0013 | A keyword or type word used as a name | Rename it |
| W2001 | An unknown name, often a `with entry` local read from a function | Make it a `glob`, or pass it |
| E1004 | A function may end without returning its declared type | Return on every path |
| E1003 | A function returns a value and declares no return type | Declare `-> T` |
| E1002 | A `return` value, or a bare `return;`, does not fit the declared return type | Return a value of that type, or widen it (`-> int \| None`) |
| W1100 | No module of that name | Check the spelling and the project's root |
| E1490 | A run-time decorator such as `@lru_cache` | Call it: `glob fib = lru_cache(maxsize=32)(fib_of);` |
| W3035 | `x is 1`, `s is "a"` | `==` |

Every `W` code is an error here. `jac docs <code>` gives the entry, its example and its fix.

```jac
# expect: W3004
obj Point {
    has x: int = 0;

    def __init__(x: int) {
        self.x = x;
    }
}
```

`jac fmt --fix <file>` rewrites spellings like W3004 and W3005 by itself.

## Where to look things up

| Question | Command |
|---|---|
| The language in one page | `jac docs start/primer` |
| Variables, scope, `glob`, unpacking | `jac docs language/variables` |
| Types, unions, `any`, inference | `jac docs language/types` |
| Functions, parameters, lambdas | `jac docs language/functions` |
| `obj`, fields, `init`, properties | `jac docs language/archetypes`, `jac docs language/fields` |
| Impl blocks and annexes | `jac docs language/impl` |
| Imports and how a module is found | `jac docs language/modules` |
| The standard library | `jac docs library` |
| A command's options | `jac docs toolchain/check`, `toolchain/test`, `toolchain/fmt` |
