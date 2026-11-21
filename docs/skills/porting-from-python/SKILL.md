---
name: porting-from-python
description: Use when translating a Python module or script to Jac for jac, or rewriting Python code as Jac: the mechanical rewrites, typing what Python left untyped, native standard library versus a dependency kept on CPython, what to do with Python features Jac refuses, and checking that the port behaves the same.
---
# Porting Python to Jac

## When to use this

Use it to turn Python source into Jac that jac compiles to a native program. It assumes `writing-jac`. To call a Python package from Jac without porting it, use `using-python-packages`. For code written for the reference design, use `porting-from-the-reference-design`.

## Before you start

```sh
jac docs start/primer               # the language, once
jac docs start/coming-from-python   # every Python form beside Jac's, with the code it gets
jac docs library                    # which standard modules are native
```

Try `jac port stock.py` first (`jac docs port`). It translates a core of Python mechanically, into Jac that behaves as the file does with every name an `any`, and says exactly which constructs it refuses (`jac port --check stock.py`). The steps below are for what it refuses, and for giving a port its types.

Record what the Python does before you change it: run it on inputs that exercise each path and keep the output (`python3 stock.py > py.out`). That file is the port's acceptance test.

## Steps

### 1. Decide where each import comes from

For each `import` in the Python module, look it up with `jac docs <module>` (`jac docs json`, `jac docs os.path`):

| The import is | Then |
|---|---|
| A native module (`os`, `sys`, `json`, `re`, `math`, `random`, `datetime`, `collections`, `itertools`, `functools`, `pathlib`, `subprocess`, ...) | Keep the import; it is compiled into the program |
| CPython's standard library only (`decimal`, `shlex`, `argparse`, ...) | Keep it: it runs on the CPython jac embeds, and gives Python values |
| A PyPI package | Keep it through CPython (`using-python-packages`), or port its use if it is small |
| A name the native module leaves out on purpose (E5142, E5143) | Do what the message says: usually a declared `obj`, or `importlib.import_module(...)` for CPython's |

A program that imports no Python module has no CPython in it. Prefer native code for the core of the port and keep CPython for what has no native counterpart.

### 2. Rewrite the forms

Mechanically, top to bottom: braces and `;`, `class` to `class` with `has` fields (or `obj` for a dataclass), `def __init__` to fields with defaults or `def init`, no `self` parameter, `from m import a` to `import from m { a }`, `if __name__ == "__main__":` to `with entry:__main__ { }`, tuples and unpacking in parentheses, `lambda` to a typed, braced lambda, `pass` to `{}`, `@dataclass` and `field(default_factory=list)` to plain `has` fields (a default is made anew for each object). The full table is in `jac docs start/coming-from-python`.

### 3. Type what Python left untyped

- Every parameter, field and return type gets a type. Read the callers to find it.
- Containers name their elements: `dict[str, Item]`, not `dict`.
- `Optional[T]` is `T | None`; a variable that holds two kinds of value is declared with the union where it is first bound.
- A value from a Python module is a `PyObject`; annotate the local where it should become a Jac value (`words: list[str] = shlex.split(...)`).
- `any` exists, but every use of it gives up checking: prefer a union or an interface.

### 4. Replace what Jac refuses

| Python | Jac |
|---|---|
| Run-time decorators (`@lru_cache`, `@wraps`, your own) | Call the wrapper: `glob fib = lru_cache(maxsize=None)(fib_of);` |
| Attributes added to an object at run time | Declare every field with `has` |
| Integers past 64 bits | `i128`/`u128` when they fit, else `decimal` through CPython |
| `namedtuple`, `type(...)` making classes | A declared `obj` (or a `struct`) |
| A generator | Declare it `-> Iterator[T]` |
| Monkey-patching, `exec`, `eval` (W2001: there are none) | Restructure: code is all compiled ahead of time |

### 5. Check, build and compare

```sh
jac check stock.jac
jac fmt stock.jac
jac build stock.jac -o stock && ./stock > jac.out
diff py.out jac.out
```

Then move the Python tests into `test` blocks (`testing-and-formatting`).

## A port, start to finish

The Python, `stock.py`:

```python
from dataclasses import dataclass, field


class OutOfStock(Exception):
    pass


@dataclass
class Item:
    name: str
    price: float
    tags: list = field(default_factory=list)


class Store:
    def __init__(self):
        self.items = {}
        self.stock = {}

    def add(self, item, n=1):
        self.items[item.name] = item
        self.stock[item.name] = self.stock.get(item.name, 0) + n

    def take(self, name):
        if self.stock.get(name, 0) <= 0:
            raise OutOfStock(name)
        self.stock[name] -= 1
        return self.items[name]

    def value(self):
        return sum(self.items[k].price * n for k, n in self.stock.items())


if __name__ == "__main__":
    s = Store()
    s.add(Item("pen", 1.5, ["office"]), 4)
    s.add(Item("ink", 3.0))
    s.take("ink")
    try:
        s.take("ink")
    except OutOfStock as e:
        print("out of", e)
    print(f"{s.value():.2f}", sorted(s.stock, key=lambda k: -s.stock[k]))
```

The Jac, `stock.jac`, which prints exactly what the Python prints:

```jac
obj OutOfStock(Exception) {}

obj Item {
    has name: str,
        price: float,
        tags: list[str] = [];
}

obj Store {
    has items: dict[str, Item] = {},
        stock: dict[str, int] = {};

    def add(item: Item, n: int = 1) {
        self.items[item.name] = item;
        self.stock[item.name] = self.stock.get(item.name, 0) + n;
    }

    def take(name: str) -> Item {
        if self.stock.get(name, 0) <= 0 {
            raise OutOfStock(name);
        }
        self.stock[name] -= 1;
        return self.items[name];
    }

    def value -> float {
        return sum(self.items[k].price * n for (k, n) in self.stock.items());
    }
}

with entry:__main__ {
    s = Store();
    s.add(Item("pen", 1.5, ["office"]), 4);
    s.add(Item("ink", 3.0));
    s.take("ink");
    try {
        s.take("ink");
    } except OutOfStock as e {
        print("out of", e);
    }
    print(f"{s.value():.2f}", sorted(s.stock, key=lambda (k: str) -> int { -s.stock[k] }));
}
```

```output
out of ink
6.00 ['pen', 'ink']
```

## Mistakes to expect

| Code | Python habit | Fix |
|---|---|---|
| E0001 | `if x:`, `for k, v in` | Braces; `for (k, v) in` |
| E0002 | `a, b = ...`, `global x`, `except:` | `(a, b) = ...`; delete `global`; `except Exception` |
| E0005 | `x = 1` or `from m import a` at the top level | `glob x = 1;`; `import from m { a }` |
| E0001 | `class P:` | `class P { ... }`, or `obj P { ... }` for a dataclass |
| E1490 | `@dataclass`, `@lru_cache` | A plain `obj`; call the wrapper |
| E1036, W1051 | `xs: list`, `x = None` | Name the element types; annotate the first binding with a union with `None` |
| E1030 | `obj.new_attr = 1` | Declare the field |
| E1110 | `"a" == 1`, comparing unrelated types | Compare values of one type |
| E0013 | `list`, `type`, `str` as names | Rename |
| E2225 | `pass` | `{}` |
| W2001 | `eval` | Restructure |
| E1202 | A generator with no declared type | `-> Iterator[int]` |

Watch for meanings that differ with no error: `int` raises `OverflowError` past 64 bits; a default is evaluated at each call (Python's shared mutable default is gone); an `obj` compares by fields, so two equal objects are `==`.

## Where to look things up

| Question | Command |
|---|---|
| Python's forms and Jac's, with codes | `jac docs start/coming-from-python` |
| What the native library has | `jac docs library`, `jac docs <module>` |
| Python values in Jac | `jac docs PyObject` |
| Calling CPython and PyPI | `jac docs interop/python` |
| Types, unions, `any` | `jac docs language/types` |
| Generators | `jac docs language/generators` |
| Big integers | `jac docs language/numbers-128` |
