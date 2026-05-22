# Import Anything

Jac compiles one source file to **three targets** -- Python bytecode, JavaScript, and native machine code. Each target is a *codespace*, and each codespace brings its own ecosystem:

| Codespace | Keyword | Compiles to | Ecosystem you can import |
|-----------|---------|-------------|--------------------------|
| **Server** | `sv` | Python bytecode | The entire **PyPI** ecosystem + any `.py` / `.jac` module |
| **Client** | `cl` | JavaScript | The entire **npm** ecosystem + any `.jac` client module |
| **Native** | `na` | Machine code (LLVM) | Any **C-ABI** shared library + native `.jac` modules |

There is exactly **one `import` statement**. Its shape never changes -- the *codespace it lands in* decides which ecosystem the name resolves against. This page walks through every import form, contextualized for each codespace.

---

## The one import statement

Every import follows the same template. Square brackets mark optional parts:

```text
[sv|cl|na]  [import|include]  [type]  [from <path>]  [{ items }]  [;]
```

- **Codespace prefix** (`sv` / `cl` / `na`) -- optional; covered in the next section.
- **`import`** brings names in; **`include`** absorbs *all* of a module's names into the current namespace (like Python's `from x import *`).
- **`type`** marks the import as annotation-only -- it is erased at runtime (lowers to `TYPING.TYPE_CHECKING`). Use it to break circular imports.
- **`from <path>`** selects the source module. A `<path>` is either a dotted name (`os.path`), a leading-dot relative path (`.utils`, `..lib`), or a quoted string (`"react-dom"`, `"libm.so"`).
- **`{ items }`** is the import list. Items can be plain names, `name as alias`, `* as alias`, `default as alias`, or -- for C libraries -- whole declarations.

A plain whole-module import (`import os;`) takes a trailing semicolon. The `import from ... { ... }` brace form does not.

---

## Choosing the codespace

Imports do not carry a codespace by themselves -- they inherit it from their surrounding context. There are four ways to set that context:

```jac
# 1. Default: the top of any .jac file is the SERVER codespace.
import os;

# 2. Braced block -- scopes a group of statements for one codespace.
cl {
    import from react { useState, useRef }
}
```

```jac
# 3. Section header -- everything until the next "to X:" runs in that codespace.
to cl:
import from react { useState }

to na:
import sys;

to sv:
import from json { dumps }
```

```jac
# 4. Single-statement prefix -- tags exactly one statement.
cl import from react { useEffect }
na import from math_utils { square }
sv import from analytics { track }
```

You can also dedicate a whole file to one codespace with a file extension: `.sv.jac` (server), `.cl.jac` (client), `.na.jac` (native). Inside such a file no header or prefix is needed.

!!! tip "Prefer file-based separation, then braced blocks"
    For clean, scalable codebases, dedicating a whole file to one codespace (`.sv.jac` / `.cl.jac` / `.na.jac`) is best -- each file has a single, unambiguous target, nothing in the body to track, and the split is visible from the directory tree. Within a mixed file, `cl { }` / `sv { }` / `na { }` braced blocks are the idiomatic choice -- the braces bracket exactly the tagged region and keep imports grouped. Section headers are a flatter alternative for a file that is mostly one codespace; reserve the single-statement prefix for one-off cases.

---

## Server imports -- full PyPI compatibility

Server code compiles to standard Python bytecode and runs on the Python runtime, so **every package on PyPI works unmodified** -- no wrappers, no interop layer. The server codespace is the default, so the examples below need no `to sv:` header at the top of a file.

```jac
"""Server imports -- the default codespace."""

# Whole-module import
import os;
import os.path;

# Whole-module with alias
import numpy as np;

# Several modules in one statement
import os, sys, json;

# Named imports from a module
import from math { sqrt, pi }

# Named imports with aliases
import from collections { OrderedDict as ODict, defaultdict }

# Deep PyPI package paths work like any Python "from ... import"
import from sklearn.linear_model { LinearRegression }

with entry {
    print(sqrt(pi));
}
```

Importing your own Jac and Python modules uses the *same* syntax -- a `.jac` file and a `.py` file are interchangeable as import targets:

```jac
# Relative imports -- Jac uses leading dots, like Python
import from .utils { helper }            # sibling module
import from ..lib.helpers { format_date }  # parent package
import from ...config { settings }        # grandparent package

# Import a whole local module (.jac or .py -- resolved automatically)
import models;
import from models { Task }
```

!!! note "Relative imports follow package rules"
    Just like Python, `.` / `..` / `...` resolve relative to the *package* a module belongs to. A `..` import only works when a real parent package sits above the current module. A file run directly with `jac run` is treated as a top-level script, so `..`-style imports *inside that entry file* fail with *"relative import beyond top-level package."* Use relative imports between modules inside nested package directories; from an entry script, reach other modules by their absolute path.

Two server-only forms round out the set:

```jac
# Type-only import -- erased at runtime, lowers to TYPE_CHECKING.
# Use it to break circular imports between modules.
import type from typing { Protocol }
import type from .models { Task }

# include -- absorbs every public name from the module into this namespace.
include math_helpers;
```

!!! note "Inline Python escape hatch"
    For Python-only APIs or legacy code, you can embed raw Python in a `::py:: ... ::py::` block instead of importing. Prefer a normal `import` for anything new.

---

## Client imports -- full npm compatibility

Client code compiles to JavaScript, so the import list maps directly onto ECMAScript `import` declarations -- giving you **the entire npm ecosystem**. Client imports must live in the client codespace (`to cl:`, a `cl` prefix, a `cl { }` block, or a `.cl.jac` file).

```jac
to cl:

# Named imports -- the most common form
import from react { useState, useEffect }

# Named imports with aliases
import from lodash { map as mapArray, filter }

# Default import -- "default as Name". Requires the client codespace,
# because Python has no concept of a default export.
import from react { default as React }

# Namespace import -- "* as Name"
import from react { * as React }

# Mixed: default + named in one statement (default listed first)
import from react { default as React, useRef }
```

npm package names often contain hyphens or `@scope/` prefixes that are not valid Jac identifiers. Quote them as **string literals** -- this works for every import form:

```jac
to cl:

import from "react-dom" { render, hydrate }
import from "react-router-dom" { BrowserRouter, Route }
import from "styled-components" { default as styled }
import from "date-fns" { * as DateFns }

# @jac/runtime -- built-in client runtime helpers
import from "@jac/runtime" { Link, useNavigate, JacForm }
```

Relative client modules and configured path aliases:

```jac
to cl:

# Relative imports between .jac client modules
import from .components.Button { default as Button }
import from ..lib.helpers { formatDate }

# Path aliases -- prefixes defined in jac.toml under [plugins.client.paths]
import from "@components/Button" { default as Button }
import from "@shared" { constants }
```

A path alias is declared once in `jac.toml`:

```toml
[plugins.client.paths]
"@components/*" = "./components/*"
"@shared" = "./shared/index"
```

### Side-effect imports & stylesheets

Some imports bind no names -- they exist purely for their side effects. **Stylesheets are the most common case:** importing a `.css` or `.scss` file applies its styles to the bundle. Drop the `{ items }` list entirely and import the path as a bare string literal:

```jac
to cl:

# Stylesheets -- applied to the bundle, no names bound
import "./styles.css";
import "./theme.scss";

# A font package whose CSS you want applied globally
import "@fontsource/roboto/400.css";

# A polyfill or any import-for-its-effects-only package
import "core-js/stable";
```

Each lowers to a side-effect-only ECMAScript import -- `import "./styles.css";` stays `import "./styles.css";` in the generated JavaScript. Asset files (`.css`, `.scss`, `.sass`, `.less`, `.svg`, images, fonts) are detected by the client bundler and emitted into the built `styles.css` / asset output automatically.

---

## Native imports -- full C-ABI compatibility

Native code compiles to machine code through LLVM. It has no Python interpreter, so PyPI packages are unavailable -- instead, the native codespace can call into **any C-ABI shared library** and import other native Jac modules.

```jac
to na:

# Import from another native Jac module
import from math_utils { square, cube }

# A small slice of the standard library is available natively
import sys;   # sys.argv, sys.exit()
```

The headline native feature is **C library interop**. Point `import from` at a shared library path and declare the foreign functions you need right inside the braces -- the compiler generates the C-ABI bridge:

```jac
to na:

# Pull a math function out of libm
import from "/usr/lib/libm.so.6" {
    def sqrt(x: f64) -> f64;
}

# C signatures use fixed-width types -- carry those types through code
# that feeds values into the C call.
def hypotenuse(a: f64, b: f64) -> f64 {
    return sqrt(a * a + b * b);
}
```

The same mechanism works for any third-party C library, and a C `import from` block can declare structs (as `obj`) alongside functions:

```jac
to na:

import from "libgeometry.so" {
    obj Point { has x: f64; has y: f64; }
    def make_point(x: f64, y: f64) -> Point;
    def distance(a: Point, b: Point) -> f64;
}
```

!!! info "Fixed-width types at the C boundary"
    The `import from` declaration uses fixed-width types (`f64`, `i32`, `u8`, `c_void`, …) so the signature matches the C ABI exactly. Carry those same fixed-width types through any function that passes values into a C call -- the native backend coerces, but mixing plain `float`/`int` with `f64`/`i32` at a call site is best avoided. Library paths are platform-specific -- `.so` on Linux, `.dylib` on macOS, and system libraries live in different locations per platform.

---

## Crossing codespaces

A single file can mix all three codespaces, and imports can reach *across* the boundary. The most important cross-codespace import is **`sv import` inside client code**: it pulls a server walker or `def:pub` function into the client, and the compiler rewrites the call into an HTTP request automatically.

```jac
to cl:

# Import a server walker into client code -- calls become HTTP requests.
sv import from .main { create_task }

import from react { useState }

def TaskForm() -> JsxElement {
    has title: str = "";
    return <button onClick={lambda e: ChangeEvent {
        create_task(title=title);
    }}>Add</button>;
}
```

Server and native code interoperate the same way -- a native `to na:` function can be called directly from server code in the same file, with the compiler generating the interop stubs:

```jac
"""One file, three codespaces."""

# Server is the default -- no header needed at the top.
import from datetime { datetime }

def now_iso() -> str {
    return datetime.now().isoformat();
}

to na:

def fib(n: int) -> int {
    if n <= 1 { return n; }
    return fib(n - 1) + fib(n - 2);
}

to sv:

with entry {
    print(now_iso());
    print(fib(10));   # native function called from the server codespace
}
```

---

## Quick reference

| Goal | Syntax | Codespace |
|------|--------|-----------|
| Whole module | `import os;` | any |
| Module with alias | `import numpy as np;` | sv |
| Multiple modules | `import os, sys, json;` | any |
| Named imports | `import from math { sqrt, pi }` | any |
| Aliased item | `import from x { name as alias }` | any |
| Relative import | `import from ..lib { helper }` | any |
| Type-only import | `import type from x { T }` | sv |
| Absorb all names | `include helpers;` | any |
| Default export | `import from react { default as React }` | cl |
| Namespace export | `import from react { * as React }` | cl |
| Side-effect / stylesheet | `import "./styles.css";` | cl |
| Hyphenated package | `import from "react-dom" { render }` | cl |
| Path alias | `import from "@shared" { c }` | cl |
| C library function | `import from "libm.so" { def sqrt(x: f64) -> f64; }` | na |
| Server walker into client | `sv import from .main { walker }` | cl |

---

## Validating your imports

Syntax-check any snippet before running it -- the Jac compiler parses imports without resolving them, so this catches mistakes fast:

```bash
jac check --parse-only myfile.jac   # syntax only -- works for sv, cl, and na
jac check myfile.jac                # full type-check (server / client code)
```

`--parse-only` is the universally safe check for all three codespaces. For **native (`na`) code that calls C libraries**, the most reliable verification is to compile it -- `jac run myfile.na.jac` or `jac nacompile myfile.na.jac` -- since the native backend, not the general type checker, owns C-ABI coercion.

If you have the [`jac-mcp`](../reference/mcp.md) server connected, the `check_syntax` and `validate_jac` tools do the same thing from your AI assistant.

---

**Related:** [Syntax Cheatsheet](syntax-cheatsheet.md) · [Code Organization](../reference/code-organization.md) · [Python Integration](../reference/language/python-integration.md) · [Native Compilation](../reference/language/native-pathway.md)
