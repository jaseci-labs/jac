---
name: jac-python-interop
description: Using Python from Jac and Jac from Python - PyPI imports (numpy, pandas, sklearn), typing the untyped boundary, inline ::py:: blocks, the class archetype for subclassing metaclass-driven Python types (static has), importing .jac modules into Python scripts, jaclang.lib library mode (Node/Walker/spawn/root), jac2py. Load when mixing .jac and .py code or pulling in any PyPI package.
---

Jac compiles to Python bytecode, so the entire PyPI ecosystem is directly importable - no wrappers, no FFI. The bridge works in both directions: `.jac` files import `.py` modules with normal `import` syntax, and `.py` files import `.jac` modules through an import hook.

## Python → Jac source (use any PyPI package)

Identical syntax for the stdlib, PyPI packages, and your own `.py` files:

```jac
import json;
import from os.path { join, basename }
import from collections { Counter }      # deep dotted paths work too

with entry {
    blob = json.dumps({"src": join("data", "in.txt")});
    print(blob, basename("data/in.txt"), Counter("jacjac").most_common(1));
}
```

```
import numpy as np;                                      # any installed PyPI package
import from sklearn.linear_model { LinearRegression }
```

Local `.py` files import the same way: `import validators;` then `validators.validate_title(t)` - drop the file next to your `.jac` sources, zero config. Note `jac check` can only type what it can resolve: stdlib modules are fully stubbed, while a PyPI package that isn't installed (or ships no types) reports its members as Unknown. **Only the typeshed *stdlib* stubs ship in the `jac` binary** - third-party stubs are no longer bundled. For a typed PyPI package without inline types, install its stub package (`jac install types-requests`) and the checker resolves it via PEP 561 from the project's `.jac/venv`, so types track the installed version.

**The untyped boundary:** untyped Python returns arrive as `any`, and Jac's strict rule blocks `any` from flowing silently into typed destinations (E1001). Three fixes - type the source (`.pyi` stub), accept-and-narrow with `isinstance`, or `value as Type` cast. Full playbook in `jac-types`.

## Inline Python: `::py::` blocks

Paste Python verbatim between `::py::` fences (Python indentation rules inside); names defined there are callable from surrounding Jac:

```jac
::py::
def legacy_validate(title):
    """Kept as-is from an old Python codebase."""
    return len(title) > 3 and title.strip() != ""
::py::

with entry {
    if legacy_validate("Build API") {
        print("valid");
    }
}
```

Use for: preserving tested legacy code during migration, Python-only API shapes (exotic decorators, dynamic class construction). Do NOT use for simple imports (plain `import` works) or new logic that could be Jac - inline Python is invisible to the Jac type checker.

## `class` archetype - subclassing metaclass-driven Python types

Between plain `obj` inheritance and a `::py::` block sits a third option: the `class` archetype. Use `class` (not `obj`) when subclassing a Python type whose **metaclass consumes class attributes** - Pygments' `RegexLexer` compiling its `tokens` table, ORM/serializer base classes, ABCs with registration hooks. `obj` is dataclass-machinery-backed, so its `has` fields become instance fields and would be invisible to such a metaclass; in a `class`, `static has` becomes a genuine class attribute, exactly what the metaclass reads. The body stays full Jac - typed, checked, no `::py::` needed:

```jac
import from pygments.lexer { RegexLexer }
import from pygments.token { Keyword, Name, Whitespace }

class JacLexer(RegexLexer) {
    static has name: str = "Jac";
    static has aliases: list = ["jac"];
    static has filenames: list = ["*.jac"];
    static has tokens: dict = {
        "root": [
            (r"\b(walker|node|edge)\b", Keyword),
            (r"\w+", Name),
            (r"\s+", Whitespace),
        ],
    };
}

with entry {
    for tok in list(JacLexer().get_tokens("walker greeter")) {
        print(tok);
    }
}
```

Default to `obj` for your own types; reach for `class` only when a Python base's metaclass (or class-attribute protocol) demands real class attributes.

## Jac → Python scripts (import hook + `jaclang.lib`)

A `.pth` file installed with jaclang registers the import hook at Python startup, so `.jac` modules import with zero setup. Graph primitives come from `jaclang.lib`:

```python
import jaclang                      # only needed if the auto-hook is missing (editable/dev installs)
from graph_tools import Task, Collector       # graph_tools.jac, imported directly
from jaclang.lib import spawn, root, connect

t1 = Task(name="deploy", priority=1)
connect(root(), t1)                 # root is a FUNCTION here - call it
w = Collector()
spawn(w, root())
print(w.names)
```

Library-mode basics: archetypes subclass `Node` / `Edge` / `Walker` / `Obj`, abilities are `@on_entry` methods, `connect(a, b)` ≈ `a ++> b`, `spawn(walker, node)` ≈ `node spawn walker`. **`root` is a function in library mode** (`root()`), the opposite of `.jac` source where bare `root` is the keyword and `root()` is a hard error (E0049).

`jac tool jac2py file.jac` prints the equivalent library-mode Python - the fastest way to learn the `jaclang.lib` API or to hand a module to a Python-only team.

## Pitfalls

- **Entry scripts can't use `..` relative imports.** A file run directly with `jac run` is a top-level script, so `import from ..lib { helper }` inside it fails with `attempted relative import with no known parent package`. Use relative imports *between* package modules; from the entry script, import by absolute path.
- **`import:py` does not exist** - plain `import numpy as np;` is the Python-import syntax. See `jac-core-cheatsheet`.
- Brace imports take no trailing `;` (`import from x { y }`); module imports do (`import x;`).
- Don't reach into `jaclang.jac0core.jaclib` (what generated code uses internally) - the public, stable surface is `jaclang.lib`.
- In native code the rules differ - only a Python-congruent stdlib subset is available and unsupported imports fail at compile time; see `jac-native`.

## See also

`jac-types` (any-boundary playbook, `.pyi` stubs) · `jac-core-cheatsheet` (import forms, dot semantics) · `jac-packaging` (shipping mixed Jac/Python packages to PyPI) · `jac-concurrency` (asyncio interop)
