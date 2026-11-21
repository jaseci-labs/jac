---
description: The special methods (dunders) behind operators, subscripts, iteration, calls, conversions and dynamic attributes, what each is asked for, and how they behave on an object typed as its class and on one held in an any.
keywords: operator overloading, special methods, dunder, __str__, __repr__, __eq__, __hash__, __add__, __call__, __iter__, __getattr__, __setattr__, __getitem__, __setitem__, __delitem__, __contains__, __len__, __bool__, __reversed__, __del__, __copy__, __deepcopy__, __instancecheck__, __jac_value__, __jac_callattr__
---
# Special methods

A method with one of the names below is what an operator or a builtin calls
for instances of the class. Each is declared as an ordinary `def` (see
[Methods](methods.md)), without `self` in its parameters. The names and what
they are asked for are Python's, with the exceptions listed at the end.

## The methods

| Used by | Methods |
|---|---|
| `str(x)`, `print`, `f"{x}"`; `repr(x)`; `f"{x:spec}"` | `__str__`, `__repr__`, `__format__(spec: str)` |
| `==`, `!=`; dict keys and set members | `__eq__`, `__ne__`, `__hash__` |
| `<`, `<=`, `>`, `>=`, `sorted`, `min`, `max` | `__lt__`, `__le__`, `__gt__`, `__ge__` |
| `+`, `-`, `*`, `/`, `//`, `%`, `**`, `@` | `__add__`, `__sub__`, `__mul__`, `__truediv__`, `__floordiv__`, `__mod__`, `__pow__`, `__matmul__` |
| `&`, `\|`, `^`, `<<`, `>>` | `__and__`, `__or__`, `__xor__`, `__lshift__`, `__rshift__` |
| The same operators with the object on the right | `__radd__`, `__rsub__`, `__rmul__`, `__rtruediv__`, ... |
| `+=`, `-=`, `*=`, `\|=`, `//=`, ... | `__iadd__`, `__isub__`, `__imul__`, `__ior__`, `__ifloordiv__`, ... |
| `-x`, `+x`, `~x`, `abs(x)` | `__neg__`, `__pos__`, `__invert__`, `__abs__` |
| `bool(x)`, `if x`; `len(x)` | `__bool__`, `__len__` |
| `int(x)`, `float(x)`, `bytes(x)` | `__int__`, `__index__`, `__float__`, `__bytes__` |
| `x[k]`, `x[k] = v`, `del x[k]`, `v in x` | `__getitem__`, `__setitem__`, `__delitem__`, `__contains__` |
| `for v in x`, unpacking, `list(x)`; `next(x)`; `reversed(x)` | `__iter__`, `__next__`, `__reversed__` |
| `x(args)` | `__call__` |
| `with x as y { ... }` | `__enter__`, `__exit__(exc_type, exc, tb)`; see [Context managers](context-managers.md) |
| `x.name` for a name the class lacks; `x.name = v` for one | `__getattr__(name: str)`, `__setattr__(name: str, value)` |
| `x.name(args)` for a method the class lacks, through an `any` | `__jac_callattr__(name: str, args: list[any], kw: dict[str, any] \| None)` |
| `isinstance(v, x)` with an instance `x` as the class | `__instancecheck__(instance)` |
| `copy.copy(x)`; `copy.deepcopy(x)` | `__copy__`; `__deepcopy__(memo)` |
| A Jac type wanted where the object is given | `__jac_value__` |
| The object's last reference going away | `__del__` |

```jac
obj Vec {
    has x: int = 0,
        y: int = 0;

    def __add__(o: Vec) -> Vec {
        return Vec(x=self.x + o.x, y=self.y + o.y);
    }

    def __mul__(k: int) -> Vec {
        return Vec(x=self.x * k, y=self.y * k);
    }

    def __rmul__(k: int) -> Vec {
        return self * k;
    }

    def __neg__ -> Vec {
        return Vec(x=-self.x, y=-self.y);
    }

    def __lt__(o: Vec) -> bool {
        return self.x + self.y < o.x + o.y;
    }

    def __len__ -> int {
        return 2;
    }

    def __getitem__(i: int) -> int {
        return self.x if i == 0 else self.y;
    }

    def __iter__ -> Iterator[int] {
        yield self.x;
        yield self.y;
    }

    def __str__ -> str {
        return f"<{self.x}, {self.y}>";
    }
}

with entry {
    a = Vec(x=1, y=2);
    b = Vec(x=3, y=4);
    print(a + b, a * 3, 2 * b, -a);
    c = a;
    c += b;
    print(c, c is a, a < b, max(a, b), sorted([b, a])[0]);
    (p, q) = b;
    print(len(b), b[1], p + q, list(b), sum(b));
}
```

```output
<4, 6> <3, 6> <6, 8> <-1, -2>
<4, 6> False True <3, 4> <1, 2>
2 4 7 [3, 4] 7
```

## The rules

- **An operation on an object whose class lacks the method is a
  compile-time error**: E1110 for a binary operator, E1010 for a unary one,
  E1053 for `len`, E1021 for iterating, E1040 for indexing and E1023 for
  calling. Through an `any` the same mistake raises `TypeError` when the
  code runs (see [Through an any](#through-an-any)).
- **`a += b` calls `__iadd__` when the class has it**, and binds what it
  returns; otherwise it is `a = a + b`, a new object (as `c is a` shows
  above).
- **`!=` is the negation of `==`** unless the class defines `__ne__`.
- **Defining `__eq__` replaces the generated field comparison.** The class
  is then hashable only with a `__hash__` of its own. See
  [Archetypes](archetypes.md).
- **`__iter__` returns an `Iterator[T]`**: write it as a generator, or
  return `self` and define `__next__`, which raises `StopIteration` at the
  end.
- **`reversed(x)` calls `__reversed__`**, of an object held in an `any`
  too. It does not fall back to reading the items by position: of an object
  whose class has `__len__` and `__getitem__` and no `__reversed__`, which
  Python reverses, it is refused (E1053, `reversed() expects a sequence or
  an object with __reversed__`).
- **A comparison or `__eq__` may return an object** rather than a `bool`; its
  truth is then that object's `__bool__`. An `__eq__` declared `-> any` may
  return `NotImplemented`, and `==` is then `False`.
- **One ordering method is enough.** `sorted`, `min` and `list.sort` ask
  `<`, `max` asks `>`, and `b > a` of a class with only `__lt__` is `a < b`,
  as in Python. A class with neither method has no order: `a < b` of two of
  its objects is refused (E1110), and so is each of those four given them
  without a `key`, where Python raises `TypeError` as the line runs.
- **Fallbacks:** `bool(x)` asks `__len__` when the class has no `__bool__`
  (an empty object is false), and `float(x)` asks `__index__` when it has no
  `__float__`. `copy.copy(x)` without a `__copy__` makes a new object whose
  fields hold what the original's hold: a shallow copy.
- **An object with `__call__` given where a function is wanted is that
  object**: after `c: Callable[[], int] = s;`, `c is s` is `True`, also when
  `s` arrives through an `any`.
- **`__jac_value__ -> any`** makes the object stand for another value: where
  a Jac type is wanted (an annotated local, an argument), the object is
  replaced by what `__jac_value__` returns, checked against that type as it
  arrives (`TypeError` when it does not fit).
- **`__getattr__` is asked only for names the class does not declare**, and
  `__setattr__` likewise for assignments.
- **`__del__` runs when the object's last reference goes**, not at the end
  of a scope, and once for an object; see [Memory](memory.md).
- **Names with two leading underscores are ordinary names.** `has __coins:
  int;` and `def __count` are reached as `x.__coins` and `x.__count()` from
  anywhere; there is no name mangling.

## Subscripts

`__getitem__`, `__setitem__` and `__delitem__` are given the subscript as it
is written, as Python gives it:

| Written | The key passed |
|---|---|
| `x[1]` | `1` |
| `x[1:3]`, `x[::2]`, `x[:]` | a `slice`, with `None` for each part left out: `slice(1, 3, None)` |
| `x[1:3, :]`, `x[0, 1:]` | a `tuple` of the items, each slice a `slice` |
| `x[1,]`, `x[1:3,]` | a `tuple` of the one item, as a comma makes one in Python: `(1,)` |
| `x[..., 0]` | a `tuple` holding `Ellipsis` and `0` |

A single slice is passed as the `slice` itself, not as a tuple of one. The
value of `x[k] = v` is passed as written: a list, a str, `None`, anything.

```jac
obj Grid {
    has log: list[str] = [];

    def __getitem__(key: any) -> str {
        self.log.append(f"get {key!r}");
        return "v";
    }

    def __setitem__(key: any, value: any) {
        self.log.append(f"set {key!r} {value!r}");
    }

    def __delitem__(key: any) {
        self.log.append(f"del {key!r}");
    }
}

def grid_of(g: Grid) -> Grid {
    g.log.append("object");
    return g;
}

def place(g: Grid, i: int) -> int {
    g.log.append("index");
    return i;
}

with entry {
    g = Grid();
    g[1];
    g[1:3];
    g[::2] = [7];
    g[1:3, :];
    g[..., 0];
    g[0, 1:] += "!";
    del g[1:3], g[::-1];
    del grid_of(g)[place(g, 4)];
    for line in g.log {
        print(line);
    }
}
```

```output
get 1
get slice(1, 3, None)
set slice(None, None, 2) [7]
get (slice(1, 3, None), slice(None, None, None))
get (Ellipsis, 0)
get (0, slice(1, None, None))
set (0, slice(1, None, None)) 'v!'
del slice(1, 3, None)
del slice(None, None, -1)
object
index
del 4
```

- **`x[k] op= v` is one get and one set** with the same key, evaluated once.
- **`del a[i], b[j]` deletes each target in turn**, one `__delitem__` call
  each.
- **The object is evaluated before the subscript**, in reads, stores and
  deletes alike (`object` before `index` above).
- **A key's type is checked against the method's parameter.** A class whose
  `__getitem__` takes an `int` refuses `x[1:3]` (E1053); declare the
  parameter `any`, or a union, to take slices and tuples.

## Through an `any`

An object held in an `any` (see [Types](types.md)) has the same special
methods, found as the program runs. What would be a compile-time error on a
typed object is then a `TypeError`, with Python's message:

```jac
obj Shelf {
    has items: list[str] = [];

    def __len__ -> int {
        return len(self.items);
    }

    def __getitem__(i: int) -> str {
        return self.items[i];
    }

    def __contains__(x: str) -> bool {
        return x in self.items;
    }

    def __reversed__ -> Iterator[str] {
        for i in range(len(self.items) - 1, -1, -1) {
            yield self.items[i];
        }
    }
}

obj Plain {
    has n: int = 0;
}

obj Hooked {
    has on: Callable[[int], int];

    def __getattr__(name: str) -> any {
        return lambda (x: int, k: int = 0) -> int { return x * 100 + k; };
    }
}

obj Remote {
    has calls: int = 0;

    def ping -> str {
        return "pong";
    }

    def __jac_callattr__(name: str, args: list[any], kw: dict[str, any] | None) -> any {
        self.calls += 1;
        return f"{name} {args} {kw}";
    }
}

def inc(x: int) -> int {
    return x + 1;
}

with entry {
    s: any = Shelf(items=["a", "b"]);
    print(len(s), s[1], "a" in s, bool(s), list(reversed(s)));
    h: any = Hooked(on=inc);
    print(h.on(4), h.go(1, k=2));
    r: any = Remote();
    print(r.ping(), "|", r.fetch(1, 2), "|", r.store("k", value=3), "|", r.calls);
    for v in [Plain(), Shelf()] {
        x: any = v;
        try {
            print(len(x));
        } except TypeError as e {
            print("TypeError:", e);
        }
    }
}
```

```output
2 b True True ['b', 'a']
5 102
pong | fetch [1, 2] None | store ['k'] {'value': 3} | 2
TypeError: object of type 'Plain' has no len()
0
```

- **`len`, subscripts, `in`, iteration, `reversed`, unpacking and
  comprehensions** call the class's methods as they do on a typed object. A
  missing one raises `TypeError` (`object of type 'Plain' has no len()`);
  `hash(x)` of an `obj` without `__hash__` raises `TypeError: unhashable
  type: 'Point'`.
- **`x.m(args)` of a method the class has** calls it. Of a name the class
  has no method for, it calls what reading `x.m` gives: a field that holds a
  function (`h.on(4)`), or what `__getattr__` returns (`h.go(1, k=2)`), with
  the arguments and keywords given.
- **`__jac_callattr__(name, args, kw)`** takes over that second case in one
  step: a class that defines it is called with the method's name, the
  positional arguments as a list and the keyword arguments as a dict
  (`None` when there are none), and what it returns is the call's value. It
  is not asked for methods the class has (`r.ping()`), and it is asked only
  through an `any`: on a typed object a method the class lacks is E1030. It
  is how a class stands for an object whose methods are known only as the
  program runs, such as a JavaScript object.

## What is rejected

| Code | When |
|---|---|
| E1110, E1010 | A binary or unary operator the class has no special method for; `sorted`, `min`, `max` or `list.sort` of objects whose class has no `__lt__` or `__gt__` |
| E1053 | `len` of an object without `__len__`; `reversed` of one without `__reversed__`; a key the subscript method's parameter does not take |
| E1021 | Iterating an object without `__iter__` |
| E1040 | Subscripting an object without `__getitem__` |
| E1023 | Calling an object without `__call__` |
| E1001 | A tuple subscript on a list, which takes an `int` or a slice |

```jac
# expect: E1040, E1001, E1110 x5, E1053 x2
obj Plain {
    has n: int = 0;
}

obj Deck {
    has cards: list[int] = [1, 2, 3];

    def __len__ -> int {
        return len(self.cards);
    }

    def __getitem__(i: int) -> int {
        return self.cards[i];
    }
}

with entry {
    p = Plain();
    print(p[0, 1]);
    print(list(reversed(p)), list(reversed(Deck())));
    xs = [1, 2, 3];
    print(xs[0, 1:]);
    ps = [Plain(n=2), Plain(n=1)];
    print(p < ps[0], sorted(ps), min(ps), max(p, ps[0]));
    ps.sort();
}
```

## Differences from Python and from the reference design

- **In Python a missing special method is found only when the code runs;
  here, on an object typed as its class, it is a compile-time error.**
  Through an `any` it is Python's `TypeError`.
- **In Python a special method takes `self` first; here it is implicit**, as
  for every method: `def __len__ -> int`.
- **In Python `x.m(...)` of a missing method is always `getattr(x, "m")`
  followed by a call; here a class may answer it in one step with
  `__jac_callattr__`.** Python has no such hook.
- **In Python a name with two leading underscores is mangled inside a class;
  here it is not.**

## See also

- [Methods](methods.md): `def`, `self`, `static def`, `override`, `super`.
- [Archetypes](archetypes.md): the generated `repr`, `==` and hashing.
- [Context managers](context-managers.md): `__enter__` and `__exit__`.
- [Generators](generators.md): writing `__iter__` as a generator.
