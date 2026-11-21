---
description: How values cross between Jac and Python in a native program - PyObject, what Jac's values become in Python, exceptions both ways, Jac classes deriving from Python classes, threads and async.
keywords: PyObject, jac.JacObject, Python values, Python exception, JacCoroutine, JacAsyncGenerator, switch point
---
# Python values

A native program that imports a Python module ([Python](python.md), `jac docs Python`) holds
Python objects, and passes Jac values to Python. This page says what each side gets.

## Python's values in Jac

What Python gives is a `PyObject`: its attributes, calls (keyword arguments included), items,
operators, comparisons, `with`, `len`, `in` and iteration are Python's. `type(x)` is its Python
type, and `x is y` asks whether they are the same Python object.

A `PyObject` fits wherever a Jac type is wanted, and becomes the Jac value it stands for when it
arrives there: a Python int, float, str, bool, list or dict becomes Jac's. One that is not of the
type wanted is a `TypeError` as it arrives. A Python int fits where a `float` is wanted, and a
number that is neither an int nor a float (numpy's numbers, CPython's own `decimal.Decimal`) converts to a
`float` by its `__float__` and to an `int` by its `__index__`. A `Decimal` has no `__index__`, so
it does not fit where an `int` is wanted.

`int()`, `float()`, `str()` and `bool()` of a Python value are Python's own, and give Jac's value:
`int(d)` of a `Decimal` or a Python float truncates it, as `builtins.int(d)` does, and `int()` and
`float()` read a number's text.

`PyObject` is the runtime's name for such a value, not a type a program writes (`-> PyObject` is
E2018), and a Python class is not a Jac type (`-> ast.Module` is E1163). Declare a Python
value `any`, or convert it to the Jac type it stands for where it arrives:

```jac
import builtins;
import importlib;

def price(text: str) -> any {
    return importlib.import_module("decimal").Decimal(text);
}

with entry {
    d = price("7.5");
    print(d + 1, type(d).__name__);
    n = int(d);
    f: float = d;
    print(n, f, int(price("-7.9")), float(builtins.bytearray(b"2.5")));
    try {
        m: int = d;
        print(m);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
8.5 Decimal
7 7.5 -7 2.5
TypeError: expected int, found Decimal
```

A Python iterator or generator is not a list, so it does not become one where a `list[str]` is
wanted. Convert it by iterating it and converting each element, `[str(l) for l in it]`, or make it
a Python list first with `builtins.list(it)`, which converts as a whole. Jac's own `list(it)` is a
Jac list of Python values, a `list[PyObject]`, which a `list[str]` annotation refuses (E1001).

```jac
import builtins;
import importlib;

with entry {
    pydiff = importlib.import_module("difflib");
    old = ["apple\n", "pear\n"];
    new = ["apple\n", "plum\n"];
    lines = [str(l) for l in pydiff.unified_diff(old, new)];
    print(lines[3:]);
    same: list[str] = builtins.list(pydiff.unified_diff(old, new));
    print(len(same));
}
```

```output
[' apple\n', '-pear\n', '+plum\n']
6
```

## Jac's values in Python

| Jac value | What Python gets |
|---|---|
| `None`, `bool`, `int`, `float`, `str`, `bytes`, `bytearray` | The same value |
| `list` | A Python list that is the Jac list: what Python does to it, Jac sees, and it comes back as itself |
| `tuple`, `dict` | A new tuple or dict of what its items become |
| `int`, `str`, `list` and the other builtin types | Python's builtin of that name |
| A function, lambda or bound method | A callable that calls it, with keyword arguments bound by name |
| A `datetime`, `date`, `time`, `timedelta`, `timezone` or `ZoneInfo` | Python's own `datetime` value; one coming back is Jac's |
| Any other Jac object | An instance of the class's Python class, a subclass of `jac.JacObject`, whose attributes and methods are the Jac object's, callable when the class has `__call__`; it comes back to Jac as the same object |
| A `PyObject` | The object it is |

Python calling a Jac function passes its arguments as Jac code's values arrive: each becomes the
parameter's type by the rules above, and one of another type is a `TypeError`
(`expected int, found str`).

```jac
import builtins;
import importlib;

with entry {
    pydecimal = importlib.import_module("decimal");
    jobs: list[int] = [5, 1, 4];
    builtins.list.sort(jobs);
    builtins.list.append(jobs, 9);
    print(jobs);
    d = {"a": 1};
    builtins.dict.update(d, {"b": 2});
    print(d);
    n: int = builtins.len("abc");
    s: str = builtins.str(pydecimal.Decimal("2.50"));
    half: float = pydecimal.Decimal("0.5");
    count: float = builtins.len("ab");
    print(n + 1, s.upper(), half, count);
    try {
        bad: str = pydecimal.Decimal(3);
        print(bad);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
[1, 4, 5, 9]
{'a': 1}
4 2.50 0.5 2.0
TypeError: expected str, found Decimal
```

A Jac object is the same object on both sides: Python's `getattr`, `setattr`, `len`, `iter` and
`sorted` reach its fields and its methods (`__len__`, `__iter__`, `__lt__`), and a Jac function
keeps its signature and types for `inspect` and `typing`:

```jac
import builtins;
import inspect;

obj Item {
    has name: str,
        n: int;

    def size -> int {
        return self.n * 2;
    }
}

def scaled(a: int, scale: int = 1) -> int {
    return a * scale;
}

with entry {
    print(builtins.list(builtins.map(scaled, [1, 2, 3])));
    print(inspect.signature(scaled), builtins.callable(scaled));
    it = Item(name="pen", n=3);
    print(builtins.getattr(it, "name"), builtins.type(it).__mro__);
    builtins.setattr(it, "n", 5);
    print(it.size(), builtins.getattr(it, "size")());
    print(builtins.sorted(["bb", "a", "ccc"], key=builtins.len));
}
```

```output
[1, 2, 3]
(a: int, scale: int = 1) -> int True
pen (<class 'main.Item'>, <class 'jac.JacObject'>, <class 'object'>)
10 10
['a', 'bb', 'ccc']
```

The Jac class's Python class is named as the class and its module, here `main`. A Jac module is
importable from Python by its name (`importlib.import_module("main")`), its classes callable with
keyword arguments to make Jac objects. A function named by an escaped reserved word
(``def `skip(n: int)``) is `skip` to Python. Python code cannot derive a class of its own from a
Jac class: defining one raises `TypeError`.

A Python decorator that registers a function (a web framework's `@app.route("/hi")`) is applied
to a Jac function by calling it, `app.route("/hi")(hello);`: in Jac, `@` takes only decorators that
run as the program compiles (E1490).

`datetime`'s values cross as each side's own, as an int or a str does, so a Jac `datetime` is a
`datetime.datetime` to a Python library, and one Python gives (of a subclass too) is Jac's where Jac
code wants one. Each side keeps its own implementation; the values are immutable, so neither keeps
the other's identity:

```jac
import builtins;
import datetime;
import pickle;

with entry {
    when = datetime.datetime(2026, 11, 7, 12, 30, tzinfo=datetime.timezone.utc);
    print(builtins.type(when), builtins.format(when, "%a, %d %b %Y %H:%M"));
    back: datetime.datetime = pickle.loads(pickle.dumps(when));
    print(back == when, back.isoformat());
}
```

```output
<class 'datetime.datetime'> Sat, 07 Nov 2026 12:30
True 2026-11-07T12:30:00+00:00
```

`memoryview(x)` of a Python object that exports its memory (CPython's `array.array`, a numpy
array) views and writes it without a copy, as it does the native `array.array`.

## Exceptions

A Python exception reaching Jac is the Jac exception of the nearest built-in class it is an
instance of, its message prefixed with its own class's name when that is another. An `except`
clause naming a Python class catches that class's exceptions, and its subclasses', as they are in
Python:

```jac
import importlib;
import pickle;

with entry {
    pydecimal = importlib.import_module("decimal");
    try {
        pydecimal.Decimal(1) / pydecimal.Decimal(0);
    } except ZeroDivisionError as e {
        print(type(e).__name__, "|", e);
    }
    try {
        pickle.loads(b"no pickle");
    } except pickle.UnpicklingError as e {
        print(type(e).__name__, "|", e);
    }
    try {
        pickle.loads(b"no pickle");
    } except pickle.PickleError as e {
        print("base class");
    }
}
```

```output
ZeroDivisionError | decimal.DivisionByZero: [<class 'decimal.DivisionByZero'>]
UnpicklingError | invalid load key, 'n'.
base class
```

A Jac exception raised in a Jac function that Python called reaches Python as a Python exception
of the Jac class's name, deriving from its base's, and comes back to Jac as itself. An uncaught
exception's report lists the Jac frames it passed through, then Python's, then Python's own last
line.

The built-in exception classes are one on both sides: Jac's `ValueError` is Python's
`builtins.ValueError`. So an `except` naming either catches the exceptions of both, a Python
context manager that suppresses `KeyError` suppresses Jac's, and one `except` may list Python's
and Jac's classes together. A Python generator's return value is its `StopIteration`'s `value`:

```jac
import builtins;
import contextlib;
import pickle;

with entry {
    try {
        raise ValueError("bad");
    } except builtins.ValueError as e {
        print("caught", e, isinstance(e, builtins.ValueError));
    }
    with contextlib.suppress(KeyError) {
        print({"a": 1}["b"]);
    }
    for text in [b"x", b""] {
        try {
            if text == b"x" {
                pickle.loads(text);
            }
            print({"a": 1}["y"]);
        } except (KeyError, pickle.UnpicklingError) as e {
            print("either", type(e).__name__);
        }
    }
    gen = builtins.eval("(lambda: ((yield 1), 'done')[1])", {})();
    print(next(gen));
    try {
        next(gen);
    } except StopIteration as e {
        print("returned", e.value);
    }
}
```

```output
caught bad True
either UnpicklingError
either KeyError
1
returned done
```

## Classes, threads and async

A Jac class may derive from a Python class. Its objects are that Python class's instances; its
`init`, its methods and its overrides are Jac's, and `super.init(...)` calls the Python base's
`__init__`. Python calls the Jac methods as it calls a Python subclass's: here
`ast.NodeVisitor.visit` finds `visit_Name` by its name.

```jac
import ast;
import importlib;
import typing;

glob pyasyncio: any = importlib.import_module("asyncio");

obj Names(ast.NodeVisitor) {
    has ignore: str = "",
        found: list[str] = [];

    def init(ignore: str) {
        super.init();
        self.ignore = ignore;
    }

    def visit_Name(n: any) {
        if n.id != self.ignore {
            self.found.append(n.id);
        }
        self.generic_visit(n);
    }
}

async def twice(n: int) -> int {
    await pyasyncio.sleep(0);
    return n * 2;
}

async def both -> list[int] {
    return await pyasyncio.gather(twice(2), twice(3));
}

with entry {
    v = Names("print");
    v.visit(ast.parse("print(a + b * a)"));
    print(v.found, isinstance(v, ast.NodeVisitor));
    print(typing.get_type_hints(Names), Names.__mro__[1]);
    print(pyasyncio.run(both()));
}
```

```output
['a', 'b', 'a'] True
{'ignore': <class 'str'>, 'found': <class 'list'>} <class 'ast.NodeVisitor'>
[4, 6]
```

- The class, used as a value, is its Python class. Its `has` fields are that class's
  annotations, and their defaults its class attributes, so a base whose metaclass collects a
  class's fields from its annotations (a dataclass-like or pydantic model) sees them; its methods
  are the class's functions. A name the class does not declare (`Names.__mro__`, a base's class
  attribute) is the Python class's.
- A class without an `init` of its own is made by its base's `__init__`, with the arguments the
  call passes. `super.m(...)` is Python's `super(C, self).m(...)`.
- A class deriving from a Python class derives from nothing else (E2191).

Python's threads may call Jac functions, and Jac coroutines are Python's to run. `threading`,
`concurrent.futures` and `asyncio` are native modules, whose threads and event loop are the
program's own ([threading](../library/threading.md), [asyncio](../library/asyncio.md)). A Python
thread is one CPython's `threading` starts, or one a Python package starts, and Python's event
loop is that of CPython's `asyncio`; `importlib.import_module` reaches both modules:

```jac
import builtins;
import importlib;

glob ready: bool = False,
     pyasyncio: any = importlib.import_module("asyncio");

def flip {
    ready = True;
}

def square(n: int) -> int {
    return n * n;
}

async def twice(n: int) -> int {
    await pyasyncio.sleep(0);
    return n * 2;
}

with entry {
    pythreading = importlib.import_module("threading");
    pyfutures = importlib.import_module("concurrent.futures");
    pythreading.Timer(0.01, flip).start();
    spins = 0;
    while not ready {
        spins += 1;
    }
    print("ready", ready);
    pool = pyfutures.ThreadPoolExecutor(max_workers=4);
    print(builtins.list(pool.map(square, builtins.range(5))));
    pool.shutdown();
    c = twice(3);
    print(builtins.type(c).__name__, pyasyncio.run(c));
}
```

```output
ready True
[0, 1, 4, 9, 16]
JacCoroutine 6
```

- Jac code holds no GIL while it computes, so a thread Python started runs alongside it.
- Python's threads, a thread pool's among them, may call Jac functions. They run Jac code one at a
  time, under one lock of Jac's runtime. A thread waiting for it gets its turn at a switch point,
  and the switch points are the program's own loops: a Jac loop waiting on what such a thread sets
  (the timer's `flip` above) sees it.
- A Jac coroutine reaching Python is a `JacCoroutine`, a `collections.abc.Coroutine`, which
  CPython's `asyncio.run` and `asyncio.gather` take and a Python coroutine awaits. A Jac async
  generator is a `JacAsyncGenerator`, a `collections.abc.AsyncGenerator`; an exception its
  `athrow` throws in arrives as the Jac exception it is. Jac coroutines `await` Python's, and
  `async for` and `async with` work across the two.
- A cycle through Jac objects and Python objects (a Jac object holding a Python object that holds
  it) is collected by Python's collector once nothing else holds it, and kept while Jac code holds
  one of its Jac objects. A cycle whose Jac part has more than 100,000 objects is not collected.
- Python's output and Jac's keep the program's order on one stream.

## What is rejected

```jac
# expect: E2191
import ast;

obj Base {
    has n: int = 0;
}

obj Both(ast.NodeVisitor, Base) {}

with entry {
    print(Both);
}
```

```jac
# expect: E2018, E1163
import ast;

def total -> PyObject {
    return ast.parse("1");
}

def unit -> ast.Module {
    return ast.parse("1");
}

with entry {
    print(total(), unit());
}
```

| Code | Condition |
|---|---|
| E2191 | A class deriving from a Python class derives from something else too |
| E2018 | `PyObject` written as a type |
| E1163 | A Python class written as a type |

Misusing a Python value that its stubs describe is a compile error too; see
[Python](python.md#checking).

## Differences from Python and from the reference design

- A Jac `list` crosses as itself, but a `dict` crosses as a copy: what Python does to a dict it was
  given is not seen by Jac.
- Python code cannot derive a class from a Jac class.
- In the reference design, every value is a Python object. Here only Python's are; Jac's own values cross at the
  boundary.
