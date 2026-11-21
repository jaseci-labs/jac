---
name: porting-from-the-reference-design
description: Use when moving a program written for the reference design (jaclang, its `jac run`) to jac, or when Jac code from the reference design's documentation or examples does not compile with jac: the order of work, what jac fmt --fix rewrites, the breaks that need hand edits with their codes, the meanings that changed silently, and what has no counterpart.
---
# Porting a reference-design program to jac

## When to use this

Use it for code written for the reference design's `jac` (the Python-hosted jaclang): a project, a file, or a snippet from the reference design's documentation. jac defines the language and fixes the reference design's warts as clean breaks, so most reference-design code needs edits. It assumes `writing-jac`. For a Python module, use `porting-from-python`; for a reference-design app with a server and pages, port the language here, then continue in `building-an-app` and `pages-and-components`.

## Before you start

```sh
jac docs start/primer                # the language as jac defines it
jac docs start/coming-from-the-reference-design       # every break from jac: the old form, the new one, its code
jac docs search "Differences from jac"   # every page's section on what jac does differently
jac docs toolchain/lint              # the old spellings, and the probable mistakes now refused
```

Every language page ends with how it differs from the reference design; read that section for each construct the program leans on (`jac docs walkers`, `jac docs abilities`, `jac docs connect`).

## Steps

1. **Make it a project.** Put a `jac.toml` (it may be empty) at the program's top directory, so imports resolve and settings apply (`starting-a-project`).
2. **Rewrite the reference design's older import forms by hand:** `import:py os;` and `import:jac util;` (E0003, an import that names no module) are `import os;` and `import util;`.
3. **Check it once to see the size of the job:** `jac check main.jac`. The first report is syntax only; later phases appear as each is cleaned.
4. **Fix by hand the W3010 of an impl that renames a parameter or leaves its parameters out:** copy the declaration's signature into the impl. Step 5 rewrites an impl that differs from its declaration only in a type, a default or the return type.
5. **Let the formatter rewrite the old spellings:** `jac fmt --fix .` (or the files you are porting). It rewrites `def f()`, `def __init__`, `@staticmethod`, `@property`, stray `;`, `case (a, b):`, `sem x is`, missing enum commas, `hasattr`/`getattr` null tests and the rest, then formats.
6. **Check again and fix the rest by hand,** first error first, using the table below and `jac docs <code>`. Repeat until `check` is quiet.
7. **Review the silent changes** (below): code that compiles in both and means something else.
8. **Build, run and compare** with the reference design's output on the same input: `jac build main.jac -o main && ./main`.
9. **Run the program's tests:** `jac test` (`testing-and-formatting`). A test's name is a string: `test adds_up {` is `test "adds up" {`.

A file in the reference design's spellings. Its first report:

```jac
# expect: E0002, W3005 x2, W3013, E0155, E0156
import from math { sqrt }

enum Kind { SMALL, LARGE }

obj Point {
    has x: float = 0.0, y: float = 0.0;

    def __init__(x: float, y: float) {
        self.x = x;
        self.y = y;
    }

    @staticmethod
    def origin() -> Point {
        return Point(0.0, 0.0);
    };

    def norm() -> float {
        return sqrt(self.x * self.x + self.y * self.y);
    }
}

def classify(p: Point) -> Kind {
    match (p.x, p.y) {
        case (0.0, 0.0):
            return Kind.SMALL;
        case _:
            return Kind.LARGE if p.norm() > 1.0 else Kind.SMALL;
    }
}

sem Point.x is "The horizontal coordinate";

with entry {
    print(Point(3.0, 4.0).norm(), classify(Point.origin()));
}
```

After one `jac fmt --fix`, which also rewrote `__init__` and `@staticmethod` (a later phase would have reported them):

```jac
import from math { sqrt }

enum Kind {
    SMALL,
    LARGE,
}

obj Point {
    has x: float = 0.0,
        y: float = 0.0;

    def init(x: float, y: float) {
        self.x = x;
        self.y = y;
    }

    static def origin -> Point {
        return Point(0.0, 0.0);
    }

    def norm -> float {
        return sqrt(self.x * self.x + self.y * self.y);
    }
}

def classify(p: Point) -> Kind {
    match (p.x, p.y) {
        case [0.0, 0.0]:
            return Kind.SMALL;
        case _:
            return Kind.LARGE if p.norm() > 1.0 else Kind.SMALL;
    }
}

sem Point.x = "The horizontal coordinate";

with entry {
    print(Point(3.0, 4.0).norm(), classify(Point.origin()));
}
```

```output
5.0 Kind.SMALL
```

## Breaks that need a hand edit

| Code | The reference design accepted | Write |
|---|---|---|
| W2001, W1100, W1051 | As warnings | They are errors: fix each |
| W0060 | As a warning | Still a warning, which fails nothing: delete the stray string, or let `jac fmt --fix` |
| E1490 | `@lru_cache def f`, any run-time decorator | `glob f = lru_cache(maxsize=32)(f_of);` |
| E1452 | A local rebound to another type | Declare the union where it is first bound, or use a second name |
| W1051 | `x = None` then a value; `defaultdict(list)`; `list()` | Annotate; `defaultdict(list[int])`; `list[int]()` |
| E0013 | `list`, `type`, `str` as names | Rename |
| E0002 | `nonlocal n;` or `global n;` | Delete it: assignment rebinds the enclosing local or the `glob` |
| E0001 | `test adds_up { ... }`, a test named by an identifier | `test "adds up" { ... }` |
| E0034 | `can twice() -> int { ... }` as a method | `def twice -> int { ... }`; `can` is only an ability with a trigger |
| E1145 | `import from m { * }` | `include m;` |
| E1479 | `def f[comptime T]` | `def f[T]` |
| E1110 | `a > b` on an unbounded `T` | `[T: Ordered]` |
| E1482 | An all-abstract `obj` used as a type | `dyn Shape`, or a bound `[T: Shape]` |
| E1004 | A function falling off its end | Return on every path |
| E1003 | A function that returns a value with no `->` | Declare the return type |
| E1278 | `save(3);` of an `async def` | `await save(3);` |
| W3035, W3024, W3025, W3040 | `x is 1`, a repeated `elif`, identical branches, `[?:T, f == f]` | `==`; remove the dead code; rename the variable |
| E5090 | A `class` deriving from an `obj`, an enum alias or computed value, `can` outside an archetype, `spawn W()` alone, `[node a -->]` | Both `class` or both `obj` (a `class` is Python's plain class: `jac docs archetypes`); literal values; abilities on a walker or node; `root spawn W()`; `[a -->]` |
| E1277 | A typed walker's reports filled from a node's untyped ability | Report from the walker |
| W2001 | `wrapping_add(a, b)` and the other `wrapping_*` builtins | The operators `a +% b`, `-%`, `*%` |

## Changed silently

These compile in both and mean something else. Search the code for each:

- `-x ** 2` is `-(x ** 2)`, as in Python: `-2 ** 2` is `-4`.
- A parameter's default is evaluated at every call that omits it: `def f(xs: list[int] = [])` gets a new list each time.
- `int` is 64 bits and raises `OverflowError`; `i64` is a sized type of its own.
- `def drop` is an ordinary method; a finalizer is `def __del__`.
- `report x;` does not print. A second spawn of one walker adds to the same reports.
- `a <++> b` makes two edges, one each way.
- An ability with the same name in a sub-walker runs after the base's instead of replacing it; `skip` ends every ability still to run at that node.
- `root` is new in every run of a built program: nothing persists between runs outside an app.
- `[a -->]` is a `list[Node]`: read fields through `[a ->:E:->]` or a filter (E1030 otherwise).
- An `obj` without `__eq__` compares by fields.

## What a correct result looks like

`jac check main.jac` and `jac fmt --check .` are quiet, `jac test` passes, and the built program prints what the reference design's run printed, except where a silent change above explains the difference.

## Mistakes to expect

- Running `fmt --fix` before reading the first report: fine, but read the second report in full; the hand edits are there.
- Editing to restore the reference design's meaning (a shim, a flag): port the program to jac's meaning instead.
- Porting the reference design's server decorators (`@schedule`, `@job`, `@restspec`) as they were: they are built-in decorators here, said without an import, with other arguments (`@schedule(interval=60.0)`), and a job is started with `flow` (`jac docs apps/stdjac-server`).
- Porting a `by llm()` method as a method: only a function may be `by`. Make it a function that takes the object, with the object's methods as its tools (`tools=[r.read_file]`), described by `sem Reviewer.read_file = "...";`.
- Porting `visit [-->] by llm(...)` over mixed nodes: the nodes are a list of one node type (E1574), so filter them (`[-->][?:City]`); `llm` is built in, and takes `select` and `intent`.
- Porting a streamed model answer as polling: a `by` function declared `-> Iterator[ByEvent]` gives the answer as it is written, and a server function that returns an iterator sends it on as a stream.

## Where to look things up

| Question | Command |
|---|---|
| The language as jac defines it | `jac docs start/primer` |
| Every break from the reference design, with its code | `jac docs start/coming-from-the-reference-design` |
| Old spellings and probable mistakes | `jac docs toolchain/lint` |
| One code | `jac docs <code>` |
| Walkers, abilities, reports in jac | `jac docs walkers`, `jac docs abilities`, `jac docs report` |
| `by`, `sem`, `llm`, `visit ... by` | `jac docs by`, `jac docs visit by` |
| Decorators | `jac docs language/decorators` |
| Interfaces and `dyn` | `jac docs language/interfaces` |
| Generics and bounds | `jac docs language/generics` |
