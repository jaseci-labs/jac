---
name: using-python-packages
description: Use when a native Jac program needs a PyPI package (numpy, tabulate, requests...) or a CPython standard-library module jac has no native version of (pickle, ast, tokenize...) - jac install --pypi, importing, converting Python values, catching Python exceptions, and building the program.
---
# Using Python packages

## When to use this

Use it when native Jac code should call Python: a PyPI package, or a module of CPython's
standard library that the native library lacks.

- Load `writing-jac` first.
- Translating Python source into Jac is `porting-from-python`, not this.
- Code whose whole space runs on CPython (a `cpython` space of an app, with the project's own
  `.py` files) is `jac docs interop/python-modules` and `building-an-app`.

## Before you start

```sh
jac docs library          # which imports are native, and the order an import resolves in
jac docs Python           # imports, stubs, jac install, the interpreter
jac docs PyObject         # how values cross, both ways
```

**Prefer the native module.** `json`, `re`, `os`, `os.path`, `math`, `datetime`, `random`,
`csv`, `sqlite3` and the rest that `jac docs library` lists are compiled Jac, faster and
checked; `import json` always gets the native one. Use CPython only for what is not native.
Do not name a project file after a module you import (`json.jac` shadows `json`).

## Steps

1. **Install the package** from the project's root (the directory with `jac.toml`):

```sh
jac install --pypi tabulate      # adds tabulate = "~=0.10" to [dependencies.pypi], installs into .jac/venv
jac install                      # later, or on another machine: install what jac.toml lists
jac install --frozen             # exactly what jac.lock pins
jac remove --pypi tabulate
```

Commit `jac.toml` and `jac.lock`, never `.jac/`. Name packages from PyPI only: avoid
`jac install --pypi ./some/path` for now (a known defect writes an invalid `jac.toml`).

2. **Import and call it** as a Jac module. CPython's standard library needs no install:

```jac
import ast;
import importlib;
import pickle;

def port_of(data: bytes) -> int {
    conf = pickle.loads(data);
    return conf["port"];
}

with entry {
    (name, addr) = ast.literal_eval("('Ada', 'ada@example.org')");
    print(name, addr);
    print(port_of(pickle.dumps({"port": 8080})) + 1);
    pydecimal = importlib.import_module("decimal");
    cents: int = int(pydecimal.Decimal("7.80") * 100);
    print(cents + 1);
    try {
        pickle.loads(b"not a pickle");
    } except pickle.UnpicklingError as e {
        print("bad pickle:", type(e).__name__);
    }
}
```

```output
Ada ada@example.org
8081
781
bad pickle: UnpicklingError
```

A module the native library has (`decimal` above) is native when imported by name;
`importlib.import_module` reaches CPython's, whose values are Python's.

A PyPI package is imported the same way once installed:

<!-- example: not checked: needs tabulate installed in the project's .jac/venv -->
```jac
import from tabulate { tabulate }

with entry {
    table: str = tabulate([["pen", 3], ["pad", 2]], headers=["item", "qty"]);
    print(table);
}
```

3. **Convert at the boundary.** What Python gives is a `PyObject`; it becomes a Jac value where
   a Jac type is wanted (`words: list[str] = ...`), and is a `TypeError` there if it is not one.
   - A Python class is not a Jac type: `-> ast.Module` is E1163. Return a Jac value
     (`str(t)`), or leave a local unannotated.
   - A Python number that is not an int (a `Decimal`, a float) does not fit where an `int` is
     wanted (`n: int = x` is a `TypeError`); convert it with `int(x)`, which truncates it as
     Python's `int()` does, as above.
   - A Python iterator or generator (what CPython's `difflib.unified_diff(...)` returns) is not
     a list: iterate it and convert each element, `lines = [str(l) for l in it];`, or convert
     Python's own list of it, `lines: list[str] = builtins.list(it);`. Jac's `list(it)` is a list
     of `PyObject`s, which a `list[str]` annotation refuses (E1001).
   - A Jac `list` passed to Python is shared (Python's changes show); a `dict` is copied.
   - Python's exceptions are caught by their Python class (`except pickle.UnpicklingError`)
     or by the builtin they derive from (`except ValueError`).

4. **Check, build, run:**

```sh
jac check main.jac
jac build main.jac -o main && ./main
```

The program embeds CPython and reads its standard library from the toolchain and the packages
from the project's `.jac/venv`, at the paths they had at build time: it runs on this machine.

5. **Ship it** as an app when it must run elsewhere: a native space with the program as its
   `entry` (`jac docs graph spaces`); `jac build <app>` writes
   `dist/<app>-<platform>/` with CPython's library in `lib/`. Avoid importing a PyPI package
   in an app's native space for now: a known defect makes the app build report W1100 for it,
   though `jac build main.jac` finds it. Standard-library modules (`pickle`) ship fine.

6. **Try things in Python itself** with the project's environment:
   `.jac/venv/bin/python -c 'import tabulate'`. Avoid `jac python` for that for now: it does
   not see the project's packages yet.

## What a correct result looks like

- `jac check main.jac` prints nothing; the program prints what the example's output shows.
- `jac.toml` has a `[dependencies.pypi]` table, `jac.lock` pins each distribution, and
  `.jac/venv/lib/python3.15/site-packages/` holds the package.

## Mistakes to expect

```jac
# expect: E1030, E1001
import ast;

def statements(source: str) -> int {
    tree = ast.parse(source);
    ast.NodeVisitor().vist(tree);
    return len(tree.body);
}

with entry {
    label: int = ast.unparse(ast.parse("1 + 2"));
    print(statements("a = 1\n"), label);
}
```

| Code | Means | Fix |
|---|---|---|
| W1100 `cannot find module` | Not native, not CPython's, not in `.jac/venv` | `jac install --pypi <name>`; check the spelling |
| E1030 | The stubs say the module or object has no such name | Read the package's API; mind the spelling |
| E1050, E1051, E1052 | A call the stubs' signature does not bind | Match the signature |
| E1001 | The stubbed result type is not the type annotated | Annotate what it returns, or convert |
| E1163 | A Python class written as a Jac type | Convert to a Jac type, or leave it unannotated |
| E5142 | A name the native module leaves out (`collections.namedtuple`) | Do what the message says (an `obj`), or `importlib.import_module("collections")` |
| E5143 | A submodule the native package lacks (`json.tool`) | `importlib.import_module("json.tool")` |
| E2191 | A class deriving from a Python class and something else | Derive from the Python class alone |
| `TypeError: expected int, found Decimal` at run time | A Python value that is not the Jac type wanted | Convert explicitly (`int`, `str`) |

A package with no stubs is dynamic: nothing about it is checked, and a mistake is Python's
exception at run time.

## Where to look things up

- `jac docs PyObject`: values both ways, `jac.JacObject`, threads, `asyncio`.
- `jac docs Python`: stubs, `jac.lock`, `--monitor`, C extensions.
- `jac docs library`: the native modules, and how `import X` resolves.
- `jac docs install`: the command's options.
