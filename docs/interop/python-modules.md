---
description: A project's own .py files used from its Jac code - wired into a cpython space by name, shipped as they are, and refused in a native program.
keywords: .py module, project Python module, Python file
---
# A project's own Python modules

A project may keep some of its code in `.py` files beside its Jac. A space whose host is `cpython`
(its Jac lowered to Python and run on jac's CPython) takes those files as modules of its own:
its Jac code calls them, and its app ships them as they are. A native program does not: its Python
is CPython's standard library and the project's PyPI packages, described in [Python](python.md)
(`jac docs python`).

## The shortest example

A project of four files:

`jac.toml`:

```toml
[project]
name = "shop"
```

`helper.py`:

```python
def shout(s):
    return s.upper() + "!"


class Counter:
    def __init__(self, n):
        self.n = n

    def bump(self):
        self.n += 1
        return self.n
```

`archwire.jac`:

<!-- example: not checked: an archwire of a project with a .py module -->
```jac
graph layers {
    layer python { helper; }
    layer program { main; }
}

graph import {
    edge Helper: python --> program;

    helper ++> main { shout, Counter }
}

graph spaces {
    space s: cpython {
        entry main;
    }

    app s {
        run s;
    }
}
```

`main.jac`:

<!-- example: not checked: needs the project's helper.py and archwire.jac -->
```jac
with entry {
    print(shout("hi"));
    c = Counter(41);
    print(c.bump(), type(c).__name__);
}
```

```sh
jac check --space s     # check the space's program on its host
jac build               # build the app: dist/s/
./dist/s/s
```

```text
HI!
42 Counter
```

## How it works

- **A `.py` file is a module of the project**, named by its path from the project's root as a
  `.jac` file is: `helper.py` is `helper`, `tools/mathy.py` is `tools.mathy`. A file with more
  than one dot in its name (`helper.test.py`) is not one.
- **The archwire wires its names in.** A project with an `archwire.jac` takes every import between
  its own modules from wires, so a `.py` module is used through a wire that lists the names it
  gives (`helper ++> main { shout, Counter }`). It is in a
  [layer](../language/modules-layers.md) as a `.jac` module is, and an edge rule admits the wire
  from its layer into the consumer's. The wire syntax is in
  [Import wiring](../language/modules-wiring.md) (`jac docs graph import`); the spaces block in
  [The archwire's spaces](../apps/archwire.md) (`jac docs graph spaces`).
- **Its names are Python's.** What a wire binds from a `.py` module is the Python object of that
  name, used as any Python value is in a cpython space: a function called, a class instantiated, an
  attribute read. CPython itself, inside jac, reads the file for the names its top level binds,
  so a wire that names one it lacks is E1145. What is done with a name is not checked: a wrong
  call is Python's exception as the program runs. A module that defines `__getattr__`, or takes
  another's names with `*`, gives names no reading can list, and its wires are not checked.
- **Its own imports are wires too.** A `.py` file that imports another file of the project keeps
  the import in its source, and `archwire.jac` declares it with `-->`:
  `words --> helper { loud }` for `from words import loud`, and `marks --> helper;` for
  `import marks`. CPython's reading of the file holds the two to each other: an import with no
  wire is E1575, and a wire the source does not write is E1147. An import of the standard library
  or a PyPI package is no wire.
- **It is shipped as it is.** `jac build` copies each `.py` module into the app's directory,
  beside the space's compiled Jac (`dist/s/helper.py`, `dist/s/tools/mathy.py`), and
  `jac emit-py s -o <dir>` writes it there too.
- **It may import the space's Jac modules.** A Jac module of the space is a Python module of the
  same name at run time, so `helper.py` may `import util` and call `util.twice(2)` for a `util.jac`
  of the space.

## What goes wrong

| Code | Cause |
|---|---|
| E5090 | A `.py` module wired into a native space's program: `jac does not support Python modules yet` |
| W1100 | `import helper;` in a native program of a project with no archwire: no Jac module, native module or Python package has the name |
| E1144 | `import helper;` in a module under an `archwire.jac`: the import must be a wire |
| E2099 | A wire between two layers that no rule admits |
| E1145 | A wire names something the `.py` module's top level does not bind |
| E1575 | A `.py` file imports another file of the project, and no `-->` wire declares it |
| E1147 | A `-->` wire declares an import the `.py` file does not write |
| E1142 | A `++>` wire into a `.py` file: its own source writes its imports |

`jac check main.jac` checks a module as a native program, so in a cpython space's project it
reports E5090 for each `.py` wire; check the space instead, with `jac check --space <space>`.

## Differences from Python and from the reference design

- In Python, a `.py` file beside the program is importable because its directory is on `sys.path`.
  Here a native program's `sys.path` holds the toolchain's standard library and the project's
  `.jac/venv` only, and a cpython space takes a project's `.py` modules through the archwire.
- The reference design imports a `.py` module with a plain `import`. Here a project's modules, `.py` ones included,
  reach each other through the archwire's wires.
