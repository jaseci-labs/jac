---
description: Every function and constant a Jac module has without an import, with its signature and where it differs from Python's.
keywords: builtins, builtin functions, print, len, range, enumerate, zip, map, filter, reversed, sorted, iter, next, all, sum, min, max, abs, round, divmod, pow, input, open, hash, id, callable, getattr, setattr, hasattr, delattr, vars, dir, globals, NotImplemented, Ellipsis
---
# Builtin functions

These names exist in every module without an import. They are Python's builtins, with Python's
meaning unless this page says otherwise.

| Group | Names |
|---|---|
| Output, input, files | `print`, `input`, `open` |
| Making values | `int`, `float`, `complex`, `bool`, `str`, `bytes`, `bytearray`, `list`, `tuple`, `dict`, `set`, `frozenset`, `range`, `slice`, `memoryview`, `object` |
| Text forms | `repr`, `ascii`, `format`, `chr`, `ord`, `bin`, `hex`, `oct` |
| Numbers | `abs`, `round`, `divmod`, `pow`, `min`, `max`, `sum` |
| Iteration | `len`, `iter`, `next`, `enumerate`, `zip`, `map`, `filter`, `reversed`, `sorted`, `all`, `any` |
| Objects and types | `type`, `isinstance`, `issubclass`, `callable`, `id`, `hash`, `getattr`, `setattr`, `hasattr`, `delattr`, `vars`, `dir`, `globals` |
| Constants | `True`, `False`, `None`, `NotImplemented`, `Ellipsis` (also written `...`), `__name__`, `__file__` |

The types `any` and `object`, and narrowing with `isinstance`, are described with
[Types](../language/types.md) (`jac docs isinstance`); `issubclass` with
[Inheritance](../language/inheritance.md); `__name__` and `__file__` with
[Modules](../language/modules.md).

The builtin exception classes (`ValueError`, `OSError`, ...) are on their own page:
[Builtin exceptions](exceptions.md). The functions that make values (`int`, `float`, `str`,
`list`, ...) and give their text (`repr`, `ascii`, `format`, `chr`, `ord`, `bin`, `oct`, `hex`)
are on [Builtin conversions](builtins-conversions.md), with how text is read as a number.

## What differs from Python everywhere

- **`int` is 64 bits.** A result past its range raises `OverflowError` (`2 ** 63`,
  `int("99999999999999999999")`, `round(1e300)`).
- **Arguments are checked when the program is compiled.** `len(5)` is a compile error (E1053),
  not a `TypeError` as the program runs. A value typed `any` is checked as the program runs
  and raises Python's `TypeError`.
- **Element types are never guessed.** `list()`, `set()`, `dict()` and `frozenset()` with no
  argument need a type to build: annotate the variable (`xs: list[int] = list();`), or the call
  is refused (W1051).
- **A builtin function is a value only where a function is expected.** `map(len, words)`,
  `sorted(xs, key=abs)` and `f: Callable[[str], int] = len;` work. A bare `f = len;` is refused
  (W2001), because nothing says which of `len`'s types is meant. The type names (`int`, `str`,
  `float`, ...) are values anywhere, and so is a builtin type's method taken through the type
  (a function of the receiver and the method's arguments) or through a value:
  `sorted(words, key=str.lower)`, `map(int.bit_length, xs)`, `join = str.join;`,
  `look = counts.get;`.
- **A `*` argument is spread into `print`** (`print(*xs)`), **and into no other builtin
  function**: `max(*xs)` is refused (E0130). The exception classes are classes, not functions,
  and take one: `ValueError(*details)`.

## Output, input and files

### `print(*values, sep=" ", end="\n", file=sys.stdout, flush=False)`

Writes each value's `str()` to `file`, separated by `sep` and followed by `end`. `file` is any
object with a `write(s: str)` method, and by default whatever `sys.stdout` holds at the call.
`sep` and `end` are strs; pass `""` for none. `flush=True` calls the file's `flush()` once the
text is written to it. Every argument, `sep` and `end` included, is
evaluated in the order written before any is converted to text: `print(xs, grow(xs), xs)`,
where `grow` appends to `xs`, shows the appended item both times.

- **`*xs` spreads an iterable's items**, each a value of its own among the others.
- **A file object is written to in pieces**, as CPython writes them: one `write` for each
  value's text, one for each separator, one for the end. `print("a", "b")` is four calls:
  `"a"`, `" "`, `"b"`, `"\n"`.

```jac
import sys;

obj Pieces {
    has calls: list[str] = [];

    def write(s: str) -> int {
        self.calls.append(s);
        return len(s);
    }
}

with entry {
    print("a", 1, 2.5, [1, "x"], None);
    print("a", "b", sep="-", end="!\n");
    print("to stderr", file=sys.stderr);
    print();
    print(*[1, 2], *"xy", "end", sep=", ");
    seen = Pieces();
    print("a", "b", file=seen);
    print(seen.calls);
}
```

```output
a 1 2.5 [1, 'x'] None
a-b!

1, 2, x, y, end
['a', ' ', 'b', '\n']
```

### `input(prompt="") -> str`

Writes `prompt`, reads one line from standard input and returns it without its newline. At the
end of input it raises `EOFError`.

### `open(file, mode="r", buffering=-1, encoding=None, errors=None, newline=None, closefd=True, opener=None)`

Opens a file and returns a file object of [`io`](io.md) (`jac docs io`): `open` is
`io.open`, as in CPython. A program that calls it links `io`; one that does not, does not.

- **With a literal mode the result is statically typed** by that mode, as CPython's is: a mode
  without `b` gives an `io.TextIOWrapper` (reads and writes `str`), `"rb"` an
  `io.BufferedReader`, `"wb"`, `"ab"` and `"xb"` an `io.BufferedWriter`, a `+` mode with `b` an
  `io.BufferedRandom`, and a binary mode with `buffering=0` an `io.FileIO`.
- **A mode known only as the program runs** (a variable, a parameter) gives an `any`: the file
  object is the one that mode opens, and its methods are found as the program runs. An `any`
  is not a context manager, so close such a file with `close()`, or open it with a literal
  mode in each branch.
- The modes are Python's: `r`, `w`, `a`, `x`, each optionally with `+` and `b`. An invalid mode
  raises `ValueError` with CPython's message.
- `encoding` is any text encoding of [`codecs`](codecs.md) (the default is UTF-8), and `errors`
  any error handler. `newline` is Python's: by default `\r\n` and `\r` are read as `\n`; with
  `newline=""` line ends are returned as they are.
- A failure raises the `OSError` subclass CPython raises, with its message
  (`FileNotFoundError: [Errno 2] No such file or directory: 'x'`).

```jac
def read_as(path: str, mode: str) -> any {
    f = open(path, mode);
    data = f.read();
    f.close();
    return data;
}

with entry {
    with open("notes.txt", "w", encoding="latin-1") as f {
        f.write("café\n");
        print("second", file=f);
    }
    with open("notes.txt", encoding="latin-1") as f {
        print(type(f).__name__, f.encoding, [line for line in f]);
    }
    with open("notes.txt", "rb") as raw {
        print(type(raw).__name__, raw.read(5));
    }
    with open("notes.txt", "ab") as out {
        print(type(out).__name__);
    }
    with open("notes.txt", "r+b") as both {
        print(type(both).__name__);
    }
    with open("notes.txt", "rb", buffering=0) as unbuffered {
        print(type(unbuffered).__name__);
    }
    with open("plain.txt", "w") as f {
        f.write("one\ntwo\n");
    }
    print(repr(read_as("plain.txt", "r")), read_as("plain.txt", "rb"));
    try {
        open("notes.txt").read();
    } except UnicodeDecodeError as e {
        print("UnicodeDecodeError:", e);
    }
    try {
        open("missing/notes.txt");
    } except FileNotFoundError as e {
        print(e);
    }
    try {
        read_as("notes.txt", "rw");
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
TextIOWrapper latin-1 ['café\n', 'second\n']
BufferedReader b'caf\xe9\n'
BufferedWriter
BufferedRandom
FileIO
'one\ntwo\n' b'one\ntwo\n'
UnicodeDecodeError: 'utf-8' codec can't decode byte 0xe9 in position 3: invalid continuation byte
[Errno 2] No such file or directory: 'missing/notes.txt'
ValueError: must have exactly one of create/read/write/append mode
```

## Numbers

| Call | Result | Notes |
|---|---|---|
| `abs(x)` | The magnitude of an int, a float or a complex; an object's `__abs__` | `abs` of the smallest int raises `OverflowError` |
| `round(x)`, `round(x, ndigits)` | `x` rounded to the nearest even: an int with one argument, the type of `x` with two; an object's `__round__` | `round(2.5)` is `2`, as in Python. Of an `any`, `round(x)` is an int: an object's `__round__` that gives anything else raises `TypeError` |
| `divmod(a, b)` | `(a // b, a % b)` | `ZeroDivisionError` for a zero divisor |
| `pow(base, exp)`, `pow(base, exp, mod)` | `base ** exp`; with `mod`, modular power (a negative `exp` gives the modular inverse) | `pow(2, -1)` is `0.5` |
| `min(...)`, `max(...)` | The least or greatest of an iterable, or of two or more arguments; `key=` and, for an iterable, `default=` | Of an int and a float, the result is a float: `min(1, 2.5)` is `1.0`. An empty iterable with no default raises `ValueError`. The first item is kept unless a later one is strictly less (greater), as in CPython: `min(0.0, -0.0)` is `0.0`, `min(nan, 1.0)` is `nan` and `min(1.0, nan)` is `1.0` |
| `sum(iterable, start=0)` | The items added to `start`, left to right | Floats are summed with compensation, as in CPython: `sum([0.1] * 10)` is `1.0` |

```jac
with entry {
    print(abs(-3), abs(complex(3, 4)), round(2.5), round(3.5), round(2.675, 2), round(1234, -2));
    print(divmod(-7, 2), pow(2, 10), pow(2, -1), pow(3, -1, 7), pow(3, 4, 5));
    print(max(1, 5, 3), min(["bb", "a"], key=len), max([], default=0), min(1, 2.5));
    print(sum([1, 2, 3], 10), sum(x * x for x in range(4)), sum([[1], [2]], []));
    try {
        print(2 ** 62 * 2);
    } except OverflowError as e {
        print("OverflowError:", e);
    }
}
```

```output
3 5.0 2 4 2.67 1200
(-4, 1) 1024 0.5 5 1
5 a 0 1.0
16 14 [1, 2]
OverflowError: integer overflow
```

## Iteration

| Call | Result |
|---|---|
| `len(x)` | The number of items of a str (in characters), bytes, list, tuple, dict, set or range; an object's `__len__` |
| `iter(x)` | An iterator over `x`. The two-argument form `iter(callable, sentinel)` is refused (E1051) |
| `next(it)`, `next(it, default)` | The iterator's next item; at its end, `default`, or `StopIteration` without one. `default` has the item's type, and is evaluated before the item is asked for, whether it is used or not |
| `enumerate(iterable, start=0)` | Pairs `(index, item)`. `start` is positional: `enumerate(xs, 1)` |
| `zip(a, b, ...)` | Tuples of one item from each iterable, until the shortest ends. There is no `strict=` |
| `map(f, a, ...)` | `f` of each item, or of one item from each iterable |
| `filter(f, iterable)` | The items `f` is true of; with `None` for `f`, the items that are true |
| `reversed(seq)` | The items of a list, tuple, str, bytes, bytearray or range, last first; an object's `__reversed__`. Anything else is refused (E1053): an object is not read by position, and a dict's keys are not reversed |
| `sorted(iterable, key=None, reverse=False)` | A new sorted list. The sort is stable |
| `all(iterable)`, `any(iterable)` | Whether every item, or some item, is true |

`enumerate`, `zip`, `map`, `filter` and `reversed` are lazy, as in Python: each computes an
item when the loop asks for it. `iter` of a value typed `any` iterates whatever the value holds
when the program runs (a list, a str, a dict's keys, a range, bytes as ints, a generator, an
object with `__iter__`), with items typed `any`; a value that does not iterate raises
`TypeError: 'int' object is not iterable` at the `iter()` call.

`sorted`, `min` and `max` compare their items with `<` (`max` with `>`), as `list.sort` does.
Items whose type has no order are refused (E1110) unless a `key=` gives them one: objects of a
class with neither `__lt__` nor `__gt__`, dicts, `None`s, complex numbers. Python raises
`TypeError` for these when the line runs. Sets, and an enum's int members, are not ordered by
these four yet (E5090).

```jac
with entry {
    names = ["cy", "ada", "bob"];
    for (i, name) in enumerate(names, 1) {
        print(i, name);
    }
    print(list(zip(names, [3, 1, 2])), dict(zip("ab", range(2))));
    print(list(map(len, names)), list(map(str.upper, names)));
    print(list(filter(lambda (n: str) -> bool { return len(n) == 3; }, names)));
    print(sorted(names), sorted(names, key=len, reverse=True), list(reversed(names)));
    it = iter(names);
    print(next(it), next(it), next(it), next(it, "done"));
    print(all(len(n) > 1 for n in names), any(n == "bob" for n in names), len("héllo"));
}
```

```output
1 cy
2 ada
3 bob
[('cy', 3), ('ada', 1), ('bob', 2)] {'a': 0, 'b': 1}
[2, 3, 3] ['CY', 'ADA', 'BOB']
['ada', 'bob']
['ada', 'bob', 'cy'] ['ada', 'bob', 'cy'] ['bob', 'ada', 'cy']
cy ada bob done
True True 5
```

## Objects and types

| Call | Result | Differs from Python |
|---|---|---|
| `type(x)` | The class of `x`. It compares with `is` and `==`, has `__name__`, and can be called to make a value | |
| `isinstance(x, T)` | Whether `x` is a `T`; `T` is a class, a builtin type or a tuple of them. A frozenset is not a `set`, nor a set a `frozenset` | A union `int \| str` is refused (E1179): write `(int, str)`. `list[int]` is refused: write `list` |
| `issubclass(C, T)` | Whether class `C` is `T` or derives from it. Of types held as `any`, decided as the program runs; a `T` that is not a type raises `TypeError: issubclass() arg 2 must be a class, a tuple of classes, or a union` | |
| `callable(x)` | Whether `x` can be called: a function, a class, an object with `__call__` | |
| `id(x)` | An int that identifies the object while it lives | |
| `hash(x)` | The hash of a number, str, bytes, tuple, `None`, or an object with `__hash__` | A str's or bytes' hash is the same in every run (CPython seeds it per process). A list, dict or set is refused (E1180). Numbers and tuples hash as in CPython: see below |
| `getattr(o, name)`, `getattr(o, name, default)` | The attribute `name` of `o`; `default`, or `AttributeError`, when it has none. A method is returned bound to `o` (`<bound method Box.area of Box(x=10, y=4)>`); of a class, the class's own method, called with the object first. Of an optional holding `None`, the default | A literal name the class does not have, with no default, is a compile error (E1030) |
| `setattr(o, name, v)`, `hasattr(o, name)`, `delattr(o, name)` | Set, test or remove an attribute by name, through the class's `__setattr__` and `__delattr__` where it defines them. After `delattr`, `hasattr` is `False` and `getattr` gives its default until `setattr` sets the field again; `hasattr(None, name)` is `False` | |
| `vars(o)` | The fields of `o` as a `dict[str, any]`, in the order they are declared: those of `o`'s class as the program runs (a subclass's fields too, whatever `o` is typed); of an object whose class declares a `__dict__` field, that field itself | The dict of fields is a copy: storing into it does not change `o` |
| `dir(o)` | The sorted names of the fields and methods of `o`'s class as the program runs (a subclass's fields too, whatever `o` is typed); `dir(Class)` lists its methods and only the fields that have a default | `dir()` with no argument is refused (E5090) |
| `globals()` | The module's globals as a `dict[str, any]`, with `__name__`, `__file__` and `__doc__` | The dict is for reading |

```jac
obj Point {
    has x: int = 0,
        y: int = 0;

    def norm1 -> int {
        return abs(self.x) + abs(self.y);
    }
}

with entry {
    p = Point(x=3, y=-4);
    print(type(p), type(1) is int, type(2.5).__name__, type(5)("7") + 1);
    print(isinstance(p, Point), isinstance(1, (int, str)), isinstance(True, int));
    print(issubclass(bool, int), issubclass(KeyError, LookupError), callable(p.norm1));
    print(getattr(p, "x"), getattr(p, "z", None), hasattr(p, "y"), vars(p), dir(p));
    setattr(p, "x", 10);
    print(p, hash("a") == hash("a"), hash(7), id(p) == id(p));
}
```

```output
<class 'Point'> True float 8
True True True
True True True
3 None True {'x': 3, 'y': -4} ['norm1', 'x', 'y']
Point(x=10, y=-4) True 7 True
```

A class that keeps its attributes in a dict of its own declares a `__dict__` field and the hooks
that store into it; `setattr`, `delattr` and `vars` then go through them, as in Python. `round`
and `complex` call an object's `__round__` and `__complex__`.

```jac
class Record {
    has __dict__: dict[str, any] = {};

    def __setattr__(name: str, value: any) {
        self.__dict__[name] = value;
    }

    def __delattr__(name: str) {
        self.__dict__.pop(name);
    }
}

obj Money {
    has cents: int = 0;

    def __round__ -> int {
        return (self.cents + 50) // 100;
    }

    def __complex__ -> complex {
        return complex(self.cents, 0);
    }
}

with entry {
    r = Record();
    setattr(r, "color", "red");
    setattr(r, "size", 3);
    delattr(r, "size");
    vars(r)["shape"] = "round";
    print(vars(r), r.__dict__ is vars(r));
    print(round(Money(250)), complex(Money(7)));
}
```

```output
{'color': 'red', 'shape': 'round'} True
3 (7+0j)
```

`hash` gives CPython's values for numbers and tuples, so a program that prints or stores a hash
agrees with CPython. An int hashes to itself modulo the prime 2\*\*61 - 1, except that
`hash(-1)` is `-2`; a float or a complex equal to an int hashes as that int (`hash(2.0) ==
hash(2)`, so `2`, `2.0` and `complex(2, 0)` find the same dict entry); other floats, and tuples,
by CPython's formulas. `hash("")` is `0`.

```jac
with entry {
    print(hash(-1), hash(2 ** 61 - 1), hash(2 ** 61), hash(0.5), hash(-0.0), hash(""));
    print(hash(()), hash((1, 2)), hash((1, 2.0)) == hash((1, 2)), hash(True));
}
```

```output
-2 0 1 1152921504606846976 0 0
5740354900026072187 -3550055125485641917 True 1
```

Comparing two values typed `any` asks the left one's method, then the right one's reflected
method (`p < q` asks `q > p`), as Python does. Two values with no order between them raise
`TypeError: '<' not supported between instances of 'str' and 'int'`, naming the operator as
written. A NaN is neither less than, equal to nor greater than anything.

## Python builtins that are not here

| Python's | Here |
|---|---|
| `exit()`, `quit()` | `exit` is a Jac keyword. Call `sys.exit(status)`: see [sys](sys.md) |
| `eval`, `exec`, `compile`, `__import__` | Not available: a native program has no interpreter. `importlib.import_module` reaches CPython's modules: see [The library](index.md) |
| `classmethod`, `staticmethod`, `property` | Not functions here. A static method is declared with `static def` |
| `super()` | `super` is a keyword: `super.init(...)`, `super.method(...)` |
| `locals`, `help`, `breakpoint`, `aiter`, `anext` | Not available (W2001, `unknown name`) |
| `__debug__`, `copyright`, `credits`, `license` | Not available |

## Builtins that are Jac's own

These names are builtin too, and have no Python counterpart. Each is defined on the page that
`jac docs <name>` prints.

| Names | What they are for |
|---|---|
| `i8`, `i16`, `i32`, `i64`, `i128`, `u8`, `u16`, `u32`, `u64`, `u128`, `f32`, `f64` | Conversion to a sized number type: `u8(200)` |
| `popcount`, `clz`, `ctz`, `bswap`, `bitrev`, `rotl`, `rotr`, `wrapping_shl` | Bit operations on ints |
| `jid` | The identity of a node or an edge (of anything else E1053, or, through an `any`, `TypeError: jid() takes a node or an edge`) |
| `take`, `swap` | Taking a value out of a place, and exchanging two places, under the ownership rules |
| `pin`, `addressof` | Native memory: addresses given to C |
| `select`, `join`, `interleave` | Lanes of SIMD vectors |
| `managed` | A value that leaves the ownership checker's rules for the managed heap |

## Where to go next

- Methods of the values these functions make: [str](str-methods.md), [list](list-methods.md),
  [dict](dict-methods.md), [set](set-methods.md), [bytes](bytes-methods.md),
  [tuple, range and slice](tuple-methods.md), [numbers](number-methods.md).
- Modules: [Standard-library modules](stdlib.md).
