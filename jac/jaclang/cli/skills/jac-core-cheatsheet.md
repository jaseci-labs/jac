---
name: jac-core-cheatsheet
description: Jac-language baseline - Reading this skill is a must. imports, control flow, lambdas, ternary, string formatting, error handling, top-level execution. Load for basic-syntax questions no specific skill covers.
---

**Jac is strict-typed.** Every `def` parameter and return, every `has` field, every typed local needs an explicit type - and the type checker is the authority. The gradual / escape-hatch type is lowercase `any` (never capital `Any`, which warns W2001). **Do NOT fall back to `any` to silence a type error** - it does not remove the error, it only defers it to the next typed boundary (`any + any` rejects `+` with E1055, `len(any)` isn't `Sized` E1053, returning `any` where a concrete type is declared fails E1002). When a value can be missing, declare it explicitly as `T | None` (e.g. `has recipe: Recipe | None = None;`) and guard with `if x is not None { ... }` before accessing attributes. Syntax-wise: Python-flavored, every block is `{ }`-braced, every statement ends with `;`, top-level code runs inside `with entry { ... }`.

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
    meta: dict[str, int] = {"x": 1};
    manager: str | None = None;

    doubled: list[int] = [n * 2 for n in [1, 2, 3]];

    label: str = "adult" if age >= 18 else "minor";   # ternary: A if cond else B

    square = lambda(x: int) -> int { return x * x; }; # typed lambda with braces
    print(square(5));

    greeting = f"hello {name}, {len(tags)} tags";

    for n in doubled {
        if n > 4 {
            print(f"big: {n}");
        } elif n > 2 {
            print(f"mid: {n}");
        } else {
            print(f"small: {n}");
        }
    }

    try {
        value = int("not-a-number");
    } except ValueError as e {
        print(f"parse error: {str(e)}");
    }
}
```

## Import forms

**Plain `.jac` file imports:**

```
import os;                              # module - takes `;`
import from byllm.lib { Model }         # selective - NO `;`
import ".styles/global.css";            # file - takes `;`
```

**Client imports (inside `.cl.jac` files, or inside a `cl { }` block in `main.jac`):**

```
import from .button { Button }                        # relative (dots)
import from "@jac/runtime" { Router, Routes, Route }  # npm (quoted)
```

**`main.jac` is the one mixed-context file.** Server imports go at the top (server is the default context - no block needed). Then a `cl { ... }` block holds the client section: CSS import, top-level component, `def:pub app()`:

```
import from services.recipe { ApiResponse, save_profile }   # server: no leading dot

cl {
    import ".styles.global.css";                            # CSS import
    import from .components.AppShell { AppShell }            # client: relative dots
    def:pub app() -> JsxElement { return <AppShell />; }
}
```

**Relative imports - what each dot means (Python-style):**

Each leading `.` walks ONE folder up from the importing file's directory. Get this wrong and the import resolves to `<Unknown>` → cascading type errors across every use of the imported names. `sv import` carries the same dot semantics as regular `import`.

```
project_root/
├── main.jac                          # no dots - services is at the same level: services.recipes
├── services/recipes.sv.jac
└── components/
    ├── AppShell.cl.jac               # ..services.recipes  (up 1, into services)
    └── pages/
        └── DetailPage.cl.jac         # ...services.recipes (up 2, into services)
```

| Dots | Meaning | Use when |
|---|---|---|
| `services.X`   | project-root absolute  | importing file is AT the root (e.g. `main.jac`) |
| `.services.X`  | same folder            | rare - `services/` is a sibling file in this same folder |
| `..services.X` | one folder up          | importing file is one level deep (`components/X.cl.jac`) |
| `...services.X`| two folders up         | importing file is two levels deep (`components/pages/X.cl.jac`) |

If your file gets moved to a different depth, **the dot count must change** to match. Wrong dot count = silent import resolution failure = every imported name becomes `<Unknown>`.

## Pitfalls

- **Reserved keywords cannot be used as variable or parameter names.** This includes declaration words (`node`, `edge`, `walker`, `obj`, `def`, `impl`), OSP / control words (`visit`, `disengage`, `report`, `spawn`, `flow`, `wait`, `skip`, `del`), and `with`, `can`, `has`. (`entry` is *not* reserved - it is fine as an identifier.) To use a reserved keyword as an identifier anyway, escape it with a single **leading** backtick: `` `visit `` (backtick prefix only - no closing backtick; `` `visit` `` is a lexer error).
- Type system (annotations, unions, optional `T | None`, the `any` escape hatch, inference, type-error codes) - see `jac-types`.
- Concatenating a string with an Exception fails - wrap with `str(e)`: `"error: " + str(e)`.
- `import from X { Y };` fails with E0030. **Brace imports take NO trailing semicolon.** Plain module form `import X;` does.
- Statements end with `;`; blocks use `{ }`. No significant indentation (Python-style).
- **There is no `pass` statement** (`E0010`). For an intentionally empty block - an empty `except`, a stub branch - write empty braces: `{}`.
- **Unused names warn (`W2003`), and a clean check then fails.** Any local, parameter, or `except ... as e` binding you never read triggers `W2003: '<name>' is defined but never used`. Silence an intentionally-unused name by prefixing it with `_` (`_x`, or bare `_`). For an exception you don't inspect, drop the clause entirely - `except ValueError { ... }`, NOT `except ValueError as e`. A value bound only to *validate* (e.g. `age = int(s)` just to detect a bad number) still counts as unused - discard it with `_ = int(s);` or actually use the value. This is the #1 reason otherwise-correct parsing/validation code fails `jac check`.
- **Booleans are `True`/`False`, null is `None` - capitalized (Python-style).** Lowercase `true`/`false`/`null` are NOT keywords - they parse as undefined names, so a `-> bool` body doing `return false;` fails with the *misleading* `E1002: Cannot return <Unknown>, expected bool` (it never tells you `false` is undefined). Always write `True` / `False` / `None`.
- **Docstrings go immediately before a declaration, never inside its body.** A `"""..."""` inside a function body is rejected - `W0060` always, plus an `E0002` parse error when written without a trailing `;` (the usual docstring form). Put the docstring on the line above the declaration instead.
- Always use the typed brace lambda: `lambda(x: int) -> int { return x; }` (zero-arg form: `lambda -> int { return 5; }`). The Python form `lambda x: x` parses but is **untyped** - it triggers W1051 type warnings, so don't use it. The invented forms `:x: x` and `<lambda x: x>` are hard parse errors.
- Ternary is **Python-style**: `A if cond else B`. NOT `cond ? A : B` (JS/C-style) - that's a parse error in Jac.
- **Python stdlib needs explicit import - Jac auto-imports nothing.** `datetime.now()`, `os.environ`, `json.dumps`, `math.pi`, `random.randint`, etc. ALL need a top-of-file `import from <mod> { name }` or `import <mod>;` first. Common slip: using `datetime.now()` for `created_at` fields without `import from datetime { datetime }` → `NameError: name 'datetime' is not defined` at runtime.
- **`sv import` calls are `async` -- always `await` them.** `items = fetch_items()` assigns a `Promise`, not the data. Write `items = await fetch_items()`.
- **`import:py` does not exist in Jac.** Use `import from datetime { datetime }` or `import json;`. LLMs commonly hallucinate the `:py` suffix - it causes a parse error.
- **Enums use Jac form, NOT Python `class X(Enum)`.** Write `enum Color { RED, GREEN }` - the Python form `class Color(Enum) { ... }` is wrong (and `class` is a Jac archetype with different semantics). When members need to BE `int`/`str` instances (flowing into `list[int]`, JSON, LSP wire formats), use the typed-base shorthand `enum HttpStatus: int { OK = 200, NOT_FOUND = 404 }` (desugars to `IntEnum`) or `enum Tag: str { OPEN = "open" }` (desugars to `StrEnum`); any other `: T` is mixin `class X(T, Enum)`. With typed-base, `[HttpStatus.OK, HttpStatus.NOT_FOUND]` is already `list[int]` - **do NOT add `.value`**.
