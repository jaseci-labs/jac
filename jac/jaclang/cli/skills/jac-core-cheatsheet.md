---
name: jac-core-cheatsheet
description: Jac-language baseline - Reading this skill is a must. imports, control flow, match statements, enums, lambdas, glob, entry points, reserved keywords, null-safe operators, string formatting, error handling. Load for basic-syntax questions no specific skill covers.
---

**Jac is strict-typed.** Every `def` parameter and return, every `has` field needs an explicit type; the escape hatch is lowercase `any` plus the `as` cast - full rules, narrowing patterns, and error codes in `jac-types`. Syntax-wise: Python-flavored, every statement ends with `;`, every block is `{ }`-braced - **except `match`/`case` bodies, which use Python indentation** (see below). Top-level code runs inside `with entry { ... }`.

```jac
import os;
import from math { pi }


def double(x: int) -> int {
    return x * 2;
}


with entry {
    name: str = "alice";
    age: int = 30;
    tags: list[str] = ["a", "b"];
    manager: str | None = None;

    doubled: list[int] = [n * 2 for n in [1, 2, 3]];
    label: str = "adult" if age >= 18 else "minor";   # ternary: A if cond else B

    inc = lambda x: int : x + 1;                      # typed expression lambda
    square = lambda(x: int) -> int { return x * x; }; # typed block lambda
    print(inc(4), square(5));

    greeting = f"hello {name}, {len(tags)} tags";
    print(greeting, label, manager);

    for n in doubled {
        if n > 4 { print(f"big: {n}"); }
        elif n > 2 { print(f"mid: {n}"); }
        else { print(f"small: {n}"); }
    }

    try {
        _ = int("not-a-number");      # discard with `_` - unread names warn W2003
    } except ValueError as e {
        print(f"parse error: {str(e)}");
    }
}
```

## Match statements - the ONE indentation-sensitive construct

`case` arms take a **colon + indented body**, NOT braces. `case 0 { ... }` is a parse error (E0001 `Expected ':', got '{'`). Guards (`case x if cond:`) and destructuring work as in Python:

```jac
obj Point { has x: int = 0; has y: int = 0; }

def describe(value: any) -> str {
    match value {
        case 0:
            return "zero";
        case int() as n if n < 0:           # guard clause
            return f"negative: {n}";
        case [x, y]:                        # sequence destructure
            return f"pair: {x}, {y}";
        case {"kind": k}:                   # dict pattern
            return f"kind={k}";
        case Point(x=px, y=py):             # class pattern
            return f"point {px},{py}";
        case _:
            return "other";
    }
}
```

There is also a C-style `switch value { case 1: ... default: ... }` - it **falls through** like C; end each case with `break;`.

## Globals and entry points

```jac
glob counter: int = 0;          # module-level variable - `glob`, not bare assignment

def increment {
    global counter;             # declare intent to modify a glob (Python-style)
    counter += 1;
}                               # inside nested defs, use `nonlocal x;`

with entry { print("runs on EVERY import of this module"); }
with entry:__main__ { increment(); }   # only when run directly (= Python __main__)
```

**Pitfall for importable libraries:** plain `with entry` executes every time the module is imported. Put demo/CLI code in `with entry:__main__` or importing your module will run it.

## Import forms

**Plain `.jac` file imports:**

```
import os;                              # module - takes `;`
import numpy as np;                     # aliased - full PyPI access (see jac-python-interop)
import from jaclang.byllm.lib { Model }         # selective - NO `;`
import type from billing { Invoice }    # annotation-only - breaks circular imports (see jac-types)
import ".styles/global.css";            # file - takes `;`
```

**Client imports (inside `.cl.jac` files, or inside a `cl { }` block in `main.jac`):**

```
import from .button { Button }                        # relative (dots)
import from "@jac/runtime" { Router, Routes, Route }  # npm (quoted)
```

**`main.jac` is the one mixed-context file.** Server imports go at the top (server is the default context - no block needed). Then a `cl { ... }` block holds the client section: CSS import, top-level component, `def:pub app` (no-arg for manual routing; `app(children)` that renders `children` for file-based routing - see `jac-cl-routing`).

**No-dot imports are project-root absolute.** In server/native code (`.jac`, `.na.jac`, `.sv.jac`), `import from engine.math.vec3 { Vec3 }` resolves against the **project root** (the nearest `jac.toml` dir) from *anywhere* in the project - the importing file may sit at the root, under `tests/`, or any depth, and the import is identical. This is the idiomatic form; prefer it over dot-counting. A test in `tests/` imports the modules it exercises with the same no-dot path it would use at the root.

**Relative (dotted) imports** walk up from the importing file's own directory - each leading `.` is one folder. They are mainly needed in **client** code (`.cl.jac` files / `cl { }` blocks), where the bundler resolves them. `sv import` carries the same dot semantics.

| Dots | Meaning | Use when |
|---|---|---|
| `services.X`   | project-root absolute  | **default** - resolves from any depth in the project (server/native) |
| `.services.X`  | same folder            | `services` is a sibling file in this same folder |
| `..services.X` | one folder up          | importing file is one level deep (`components/X.cl.jac`) |
| `...services.X`| two folders up         | importing file is two levels deep (`components/pages/X.cl.jac`) |

A no-dot import is depth-independent: moving a file between directories never changes it. Dot-counted forms (`..`, `...`) DO break when a file moves to a different depth - wrong dot count = silent resolution failure = imported names become `<Unknown>` → cascading type errors. Prefer no-dot imports to avoid this.

## Also available (Python semantics, brace bodies)

Generators (`yield` / `yield from`), decorators (`@deco` above `def`), walrus `(n := len(items))`, context managers (`with open(f) as fh { ... }`), C-style loops `for i = 0 to i < 10 by i += 1 { }`, null-safe access `user?.profile?.name`, `cfg?["key"]` (returns `None` instead of raising - even for missing keys/out-of-range indices), and the default idiom `name = user?.name or "Anonymous";`.

## Pitfalls

- **Reserved keywords cannot be used as variable or parameter names** - declaration words (`node`, `edge`, `walker`, `obj`, `def`, `impl`), OSP / control words (`visit`, `disengage`, `report`, `spawn`, `flow`, `wait`, `skip`, `del`), and `with`, `can`, `has`. (`entry` and `exit` are *not* reserved - fine as identifiers.) Escape with a single **leading** backtick: `` `visit `` (no closing backtick; `` `visit` `` is a lexer error).
- **Backtick escape does NOT work in `has` declarations.** A backtick-escaped keyword as a field name (e.g. a field named `class`) passes `jac check` but raises `SyntaxError` at runtime inside Python's dataclass machinery. Pick a non-keyword field name (`kind`, `cls`) instead.
- **`` `any `` vs `any`:** bare `any` is the gradual *type*; backticked `` `any(...) `` calls the builtin truthiness *function*.
- `import from X { Y };` fails with E0030. **Brace imports take NO trailing semicolon.** Plain module form `import X;` does.
- **There is no `pass` statement** (`E0010`). For an intentionally empty block write empty braces: `{}`.
- **Unused names warn (`W2003`).** Prefix intentionally-unused names with `_`, or for unread exception bindings drop the clause: `except ValueError { ... }`, not `except ValueError as e`. A value bound only to *validate* still counts as unused - discard with `_ = int(s);`. This is the #1 reason otherwise-correct parsing/validation code fails `jac check`.
- **Booleans are `True`/`False`, null is `None` - capitalized.** Lowercase `false` parses as an undefined name, so `return false;` fails with the *misleading* `E1002: Cannot return <Unknown>, expected bool`.
- **Docstrings go immediately before a declaration, never inside its body** (`W0060`, often + `E0002`).
- **Lambdas must be typed.** Expression form `lambda x: int : x + 1` (note the space before the body colon), parenthesized form `lambda (x: int, y: int) -> int : x * y`, or block form `lambda(x: int) -> int { return x; }`. Block-lambda params don't need parens and the return type is optional - all idiomatic: zero-arg `lambda { onSign(); }`, single typed param `lambda v: str { gbName = v; }` (in client code also `lambda e: ChangeEvent { ... }`), multi-param `lambda exports: any, fps: int { ... }`. The bare Python form `lambda x: x` parses but is untyped (W1051 fallout); `:x: x` and `<lambda x: x>` are hard parse errors.
- Ternary is **Python-style**: `A if cond else B`. NOT `cond ? A : B` - parse error.
- **Python stdlib needs explicit import - Jac auto-imports nothing.** `datetime.now()` without `import from datetime { datetime }` = runtime `NameError`.
- **`sv import` calls are `async` - always `await` them.** `items = fetch_items()` assigns a `Promise`, not the data.
- **`import:py` does not exist** - LLMs hallucinate it; use `import json;` / `import from datetime { datetime }`.
- **Enums use Jac form, NOT Python `class X(Enum)`.** Write `enum Color { RED, GREEN }`. When members must BE `int`/`str` instances (JSON, wire formats), use typed-base `enum HttpStatus: int { OK = 200 }` (desugars to `IntEnum`) or `enum Tag: str { OPEN = "open" }` (`StrEnum`) - then **do NOT add `.value`**, members already are the base type.
- Concatenating a string with an Exception fails - wrap with `str(e)`.

## See also

`jac-types` (type system, `as` casts, `any` boundaries) · `jac-has-fields` (fields) · `jac-impl-files` (file layout) · `jac-python-interop` (PyPI, `::py::`, calling Jac from Python) · `jac-concurrency` (`flow`/`wait`, async)
