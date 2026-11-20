---
description: What a module is, what its top level may hold, import and include, with entry blocks and when they run, docstrings, how a module's file is found, and impl and test annexes.
keywords: module, import, include, from, import from, relative import, with entry, entry point, __main__, __name__, __file__, __doc__, __init__.jac, test annex, variant
grammar: module, element, import_stmt, from_path, import_items, import_item, module_code, access_tag
---
# Modules

A module is one `.jac` file, together with its annex files. It has its own names: what it declares,
what its `import` statements bring in, and what an `archwire.jac` wires into it. A program is its
main module (the file given to `jac build`) plus every module that one reaches by imports.

## A module's top level

```ebnf
module ::= STRING? element*

element ::=
    type_alias
    | import_stmt
    | archetype
    | enum_decl
    | test_decl
    | docstring_target
    | ability
    | global_vars
    | comptime_element
    | graph_import
    | graph_spaces
    | impl_def
    | sem_def
    | module_code
    | decorated
    | async_element
```

The top level holds declarations only. Code that runs goes in a function or in a `with entry`
block; a bare statement at the top level is an error (E0005).

| Element | What it declares | Page |
|---|---|---|
| `import`, `include` | Names from another module | this page |
| `glob` | Module globals | [Variables](variables.md) |
| `def`, `async def` | Functions | [Functions](functions.md), [Async](async.md) |
| `type` | A type alias | [Types](types.md) |
| `with entry` | Code that runs when the module loads | this page |
| `test` | A test | [Tests](tests.md) |
| `obj`, `class`, `struct`, `node`, `edge`, `walker`, `enum`, `impl`, `sem` | Archetypes and their implementations | `jac docs obj` |
| `comptime` | Compile-time declarations | `jac docs comptime` |
| `graph layers` | The project's layers, in `archwire.jac` only | [Layers](modules-layers.md) |
| `graph import` | Import wiring, in `archwire.jac` only | [Import wiring](modules-wiring.md) |
| `graph spaces` | Spaces and apps, in `archwire.jac` only | `jac docs space` |

```jac
# expect: E0005, E0003
print("at the top level");
import:py os;
```

The second error is an import that names no module: The reference design's `import:py os;` is written `import os;`.

## Importing

```ebnf
import_stmt ::= "comptime"? ("include" | "import" "type"?) ("from" from_path import_items? | (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" NAME)? ("," (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*) ("as" NAME)?)* ";")

from_path ::= ("." | "...")* (STRING | (NAME | KEYWORD) ("." (NAME | KEYWORD))*)?

import_items ::= "{" (element* | import_item ("," import_item)* ","?) "}"

import_item ::= ("*" | "default" | any_word | NAME) ("as" NAME)?
```

| Form | Binds in the importing module |
|---|---|
| `import util;` | `util`, the module. Its members are `util.name`. |
| `import util as u;` | `u`, the module |
| `import os, sys;` | Each module listed |
| `import pkg.part;` | `pkg`, with the member `pkg.part` |
| `import pkg.part as p;` | `p`, the module `pkg.part` |
| `import from util { twice, Tone as Pitch }` | `twice` and `Pitch`. No `;` follows the braces. |
| `import from .sibling { name }` | `name`, from a module found relative to this file |
| `include util;` | Every name `util` declares, as if written here |

- **`import` takes modules; `import from` takes names out of one.** Python's
  `from util import twice` is written `import from util { twice }`.
- **`include`** brings in every top-level name of the module: functions, archetypes, globals. It
  is the form for "all of it"; `import from util { * }` is not (E1145).
- **A module is loaded once**, however many modules import it and under however many names.
- **An imported global is the same variable**, not a copy: an assignment to `util.counter`
  anywhere is seen by every module that imported `counter`.
- **Modules may import each other.** A cycle of imports is allowed. A class may derive from a
  class of a module that imports its own module, and every class of both modules is set up before
  either module's `with entry` code runs.
- **Imports are written at the top level**, anywhere among the declarations: an import after a
  class is as good as one at the top of the file. An import inside a function is refused (E5090).
- **A class belongs to its module.** Two classes of one name in two modules are two types:
  `ma.Item` and `mb.Item` are not equal and neither is an instance of the other.
- **A name is declared once.** Importing a name the module also declares is E2036.

The standard library is imported the same way:

```jac
import os;
import from os { path as p, sep }

with entry {
    print(p.join("a", "b") == "a" + sep + "b");
    print(os.path.basename("/srv/app/main.jac"));
}
```

```output
True
main.jac
```

A project of several modules. `main.jac`:

<!-- example: not checked: needs the files util.jac and pkg/part.jac beside it -->
```jac
import util;
import pkg.part as p;
import from util { twice, Tone as Pitch }

with entry {
    print(util.twice(1), twice(3), Pitch().pitch, p.part_name());
}
```

`util.jac`:

```jac
obj Tone {
    has pitch: int = 440;
}

def twice(n: int) -> int {
    return 2 * n;
}

with entry {
    print("util loads");
}
```

`pkg/part.jac`:

<!-- example: not checked: a relative import needs the file util.jac in the directory above -->
```jac
import from ..util { twice }

def part_name -> str {
    return "part" + str(twice(2));
}
```

```sh
jac build main.jac -o main && ./main
```

```text
util loads
2 6 440 part4
```

### Relative imports

Dots before the path of an `import from` make it relative to the importing file, as in Python:

| Path | Looked for |
|---|---|
| `.name` | In the importing file's directory |
| `..name` | In the directory above it |
| `...name` | Two directories above it |

A relative import looks in that one place only. One that finds nothing is E1134.

### Other import forms

- `import from "<library file>" { def ...; }` declares functions of a C library, and an import of a
  Python or npm package reaches code in another language. See `jac docs interop`.
- `import type` names a type of a JavaScript package or of another space, for annotations.
- `comptime import` makes a module available to compile-time code. See `jac docs comptime`.
- `default` as an import item is a JavaScript module's default export.

### What is rejected

```jac
# expect: W1100, E1134
import nowhere;
import from .gone { x }

with entry {
    print(1);
}
```

```jac
# expect: E1145
import from os { no_such_name }

with entry {
    print(1);
}
```

```jac
# expect: E5090
def cwd -> str {
    import os;
    return os.getcwd();
}
```

| Code | Condition |
|---|---|
| E0003 | An import that names no module: `import;`, `import from { x }`, the reference design's `import:py os;` |
| W1100 | No module of that name is found |
| E1134 | A relative import names no module |
| E1145 | The module has no such name, as an import item or as `module.name` |
| E2036 | The imported name is already declared in this module |
| E5090 | An import inside a function |
| E0157 | A backtick in a module path, where every word is taken as it stands |
| E1144, E2094 | The import is written in a module that takes its imports from wires; see [Import wiring](modules-wiring.md) |

## How a module is found

`import X` and a non-relative `import from X` resolve nearest-first:

1. `X.jac` beside the importing file.
2. `X.jac` in each directory above it, up to and including the project's root, the directory that
   holds `jac.toml`.
3. jac's own runtime modules (such as `sys` and `os`).
4. The native standard library.

So a project's module named like a standard one (`random.jac`) is the one its modules get, and a
module in a subdirectory imports a module at the project's root by its plain name.

A dotted path names directories: `import app.deep.x` is `app/deep/x.jac`, looked for from each of
the places above.

**Packages.** A directory `X` with an `__init__.jac` is the module `X`: `import X` loads
`X/__init__.jac`, which is preferred to a file `X.jac` beside the directory. A directory needs no
`__init__.jac` for the modules inside it to be imported by dotted path.

**Variants.** A module may have a file per target. For a module `X`, the first of these that exists
is used, and the others are not compiled:

| File | Used when building for |
|---|---|
| `X.<os>.<arch>.jac` | that system and processor |
| `X.<arch>.jac` | that processor: `aarch64`, `x86_64`, `wasm32` |
| `X.<os>.jac` | that system: `darwin`, `linux`, `windows`, `wasi` |
| `X.jac` | anything else |

Every variant declares the same public names; each holds the code, and the imports, that differ on
its target. A module may also exist only as a variant: with `win.windows.jac` and no `win.jac`,
`win` is a module when building for Windows, and importing it for another target is W1100. In a space that runs on another host, the variant is named by the host instead
(`X.cpython.jac`, `X.node.jac`); see `jac docs space`.

## Module code: `with entry`

```ebnf
module_code ::= "with" ("entry" | "exit")? (":" NAME)? block
```

A `with entry` block is code the module runs when it starts. A module may have any number of them.
The main module starts when the program does. Every other module starts the first time the program
uses it, and one the program never uses never starts: its code is not in the executable.

- **What starts a module:** the first of a call of one of its functions, a read or write of one of
  its globals, or making an instance of one of its classes (or of a class derived from one).
  Importing it does not. Its code then runs once, before that use goes ahead.
- **Order within a module:** globals are given their values in the order written, and `with entry`
  blocks run in the order written. Declare a global above the entry blocks that read it.
- **A module imported for what its code does** is started by calling a function of it. The
  convention is a function named `start`, which may be empty: `registry.start();`.
- **Modules that use each other:** a use of a module from inside that module's own starting code,
  on the same thread, goes ahead with the module as far as it has got, as a cycle of imports does
  in Python.
- **An exception** from a module's code is raised at the use that started it. The module has not
  started, and its next use runs its code again from the top.
- **Threads:** one thread runs a module's code. Another that uses the module meanwhile waits for
  it to end.
- **Constant globals are there from the start.** A global whose value is a constant or a display
  of constants, functions and classes has its value before any code runs.
- **Hosts:** this is how a native or wasm program starts its modules. A JavaScript or CPython
  space starts a module when it is imported, as that host does.
- **`with entry:__main__`** runs only when its module is the program's main module. It does not run
  when the module is imported, nor under `jac test`.
- **Names assigned in an entry block** are the module code's locals. Later entry blocks of the same
  module see them, and so does a `lambda` or a `def` written inside a block, which may assign them
  too; the module's top-level functions do not (W2001). State that functions share is a `glob`.
- **`return;`** in an entry block ends its module's code there: the rest of the block, and the
  module's entry blocks after it, do not run. The modules that import it run on.
- **A module with no entry block** runs nothing; a program whose main module has none starts and
  exits.

```jac
glob greeting: str = "hello";

def greet(name: str) -> str {
    return f"{greeting}, {name}";
}

with entry {
    who = "world";
    print("first block:", greet(who));
}

with entry:__main__ {
    print("main module:", __name__);
}

with entry {
    print("last block:", who);
    if who == "world" {
        return;
    }
    print("after the return");
}

with entry {
    print("a block after the return");
}
```

```output
first block: hello, world
main module: __main__
last block: world
```

```jac
# expect: W2001
with entry {
    count = 1;
}

def read -> int {
    return count;
}
```

`with exit` and an entry block named anything but `__main__` are refused (E5090).

### Module variables

| Name | Value |
|---|---|
| `__name__` | `"__main__"` in the program's main module, and another string in every other module |
| `__file__` | The absolute path of the module's file |
| `__doc__` | The module's docstring, `""` when it has none |

These are names inside the module. `othermodule.__name__` is not a member (E1145).

## Docstrings

A docstring is a string literal written immediately before the declaration it documents; a string
that opens the file is the module's `__doc__`. The rules are in [Docstrings](modules-docstrings.md)
(`jac docs docstring`).

## Annexes

A module's code may be split over annex files, which are part of the module: they share its names
and are compiled with it. They are found by file name; nothing imports them.

**Impl annexes** hold `impl` blocks, the bodies of functions and methods the module declares
without one (`def area -> int;`). For a module `X.jac`, the compiler loads, in this order:

1. `impl/X.impl.jac`
2. `X.impl.jac` beside it
3. `X.impl/X.impl.jac`

and, in each of those three places, any number of parts `X.<part>.impl.jac`
(`impl/scene.faces.impl.jac` is a part of `scene.jac`), sorted by name.

A part belongs to the module its longest dotted prefix names: where `fs.windows.jac` exists,
`impl/fs.windows.impl.jac` is the annex of that variant, not a part of `fs.jac`.

`shapes.jac`:

<!-- example: not checked: the bodies are in the annex impl/shapes.impl.jac -->
```jac
obj Square {
    has side: int = 1;

    def area -> int;
}

def describe(s: Square) -> str;
```

`impl/shapes.impl.jac`:

<!-- example: not checked: an annex of shapes.jac, which declares what it implements -->
```jac
impl Square.area -> int {
    return self.side * self.side;
}

impl describe(s: Square) -> str {
    return f"square of area {s.area()}";
}
```

**Test annexes** hold `test` blocks. When `jac test` runs a module `X.jac`, it also loads
`X.test.jac` beside it and `test/X.test.jac`. A test annex is not part of the module in a build.
See [Tests](tests.md).

## Access tags

```ebnf
access_tag ::= (":" ("protect" | "pub" | "priv"))?
```

A declaration's keyword may carry a tag: `def:pub run`, `glob:priv cache`, `obj:protect Account`.
A tag says who may call the declaration from another space of an app (`:pub` anyone, `:protect` a
signed-in caller); see `jac docs space`. It does not hide a name from other modules: within one
program, every top-level name of a module can be imported, whatever its tag.

## Differences from Python

- `from m import a, b as c` is `import from m { a, b as c }`, and `from m import *` is `include m;`.
- Importing is declarative and happens before the program runs: a missing module or name is a
  compile error, not an `ImportError`, and there is no import inside a function.
- A module's top level holds no statements. What Python runs at import time is written in
  `with entry`, and `if __name__ == "__main__":` is `with entry:__main__`.
- A module's code runs at its first use, not where it is imported, and never for a module the
  program does not use. A module imported only for its side effects needs a call: `m.start();`.
  In a serving app a module that serves an endpoint, or declares a node or an edge type the app
  [keeps](../apps/data.md), starts with the program, which reads what it kept as it starts.
- Names assigned in `with entry` are not module globals; a global is declared with `glob`.
- Lookup is nearest-first from the importing file, not along a search path.
- A module has no `__dict__` and is not an object a program can add names to.

## Differences from the reference design

- A module's code runs at the module's first use; the reference design runs it when the module is imported.
- A reserved word in a module path or an import item is taken as it stands; a backtick there is an
  error (E0157).
- A missing module is an error (W1100) where the reference design warns.
