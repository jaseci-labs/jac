---
description: Generic archetypes (obj Box[T], struct Duo[T]): how they are checked, what a construction infers, how the type keeps its arguments, value-type arguments held in place, generic bases, and classes bounded by interfaces.
keywords: generic class, generic classes, Box[T], generic struct, generic base
---
# Generic classes

An archetype with type parameters in brackets after its name is a generic
class: `obj Box[T]`, `struct Duo[T]`. Its fields and methods use `T` as a
type, and each use of the class gives `T` a type. Type parameters, their
bounds and what a `T` provides in a body are as for a generic function: see
[Generics](generics.md) (`jac docs type parameter`). An archetype whose
brackets hold values (`obj Vec[comptime N: int]`) is described on
[Compile-time parameters](comptime-parameters.md).

## Syntax

The brackets follow the archetype's name, before its bases (see
[Archetypes](archetypes.md)), and hold [type parameters](generics.md):

```ebnf
archetype ::= decorators "async"? ("struct" | "class" | "walker" | "edge" | "obj" | "node") access_tag NAME ("[" type_params "]")? ("(" inherit_list ")")? (":" pipe "-->" pipe)? where_clause? ("{" archetype_member* "}" | ";")
```

## What a generic class means

The class is checked once, where it is declared, with `T` standing for any
type its bound admits: `obj Shelf[T: Named]` may read a `T`'s `Named`
fields, `obj Sorted[T: Ordered]` may compare two `T`s with `<`, and an
unbounded `T` provides only what every value has.

```jac
struct P {
    has x: float = 0.0;
}

obj Box[T] {
    has item: T,
        seen: list[T] = [];

    def swap(v: T) -> T {
        old = self.item;
        self.item = v;
        self.seen.append(old);
        return old;
    }

    static def of(v: T) -> Box[T] {
        return Box[T](item=v);
    }
}

struct Duo[T] {
    has a: T,
        b: T;
}

with entry {
    b = Box(item=3);
    n = b.swap(4) + b.item;
    print(n, b, type(b).__name__, isinstance(b, Box));
    s = Box[str](item="a");
    print(s.item.upper(), Box[float].of(1.5).item + 1.0);
    xs: list[int] = b.seen;
    xs.append(9);
    print(xs, b.seen);
    c = Box(item=P());
    c.item.x = 2.0;
    c.seen.append(P(x=1.0));
    ps: list[P] = c.seen;
    print(c, ps is c.seen);
    anything: Box = Box(item=1);
    anything.item = "now a str";
    print(anything, Duo(a=1, b=2), Duo[str](a="x", b="y"));
}
```

```output
7 Box(item=4, seen=[3]) Box True
A 2.5
[3, 9] [3]
Box(item=P(x=2.0), seen=[P(x=1.0)]) True
Box(item='now a str', seen=[]) Duo(a=1, b=2) Duo(a='x', b='y')
```

- **A construction finds the type arguments from what it is given**
  (`Box(item=3)` is a `Box[int]`), or takes them as written
  (`Box[str](item="a")`). Fields that give one parameter two types are an
  error (E1053), as a generic function's call giving `T` two types is.
- **The type keeps its arguments.** `Box[int]` is not `Box[str]`: assigning
  one to the other is E1001, and passing one for the other E1053. Through a
  `Box[int]`, a field or a method's result of type `T` is an `int`, and a
  method's parameter of type `T` takes an `int`.
- **An argument outside the bound** is an error where it is written or found
  (E1053 for a class bound, E1283 for an interface).
- **The name alone is the class with `any` arguments**: `Box` is `Box[any]`,
  and holds a value of any type. A generic class of another module is
  named through the module in a type, as any class is (`shapes.Crate[int]`).
- **Every instance is its class** to `isinstance(b, Box)`, `repr` and
  `type(b).__name__`, which name `Box` whatever the arguments.
  `isinstance(b, Box[int])` is an error (E1560): a value of the class is one
  whatever its arguments are.
- **A static method or field** is the class's: `Box[float].of(1.5)` calls
  `of` with `T` as `float`, and a `static has` is one value shared by every
  instance, whatever its arguments.

### How its instances hold their values

One compiled class serves every type argument that is not a value type,
holding each value of `T` as an `any`. Inside another type the class gives
(a `list[T]` field read through a `Box[int]`, a `dict[K, V]`), what the
class holds is seen as it holds it: a `list[any]`, since the one class makes
its lists of `any`s, and a `list[int]` view of one would read them as ints.
Assigning it to a `list[int]` converts it, which makes a copy, so
`xs.append(9)` above leaves `b.seen` as it was.

A type argument that is a value type (a [struct](structs.md), an
[array or a vector](../accel/vectors.md), a 128-bit int) makes an instance
of the class of its own, whose fields are of its types. It holds a struct in
place: the `P` in `c` above is part of `c`, so `c.item.x = 2.0` writes the
field. `c.seen` of a `Box[P]` is the packed `list[P]` it holds, so `ps` is
the same list. A generic `struct` such as `Duo[T]` is an instance for each
type, laid out as C lays each out.

On a `cpython` or a JavaScript space one class serves every type argument,
a struct included, which it holds as its record; each instance is that class
to `isinstance`, `repr` and `type(c).__name__` there too.

### Reflection and sending

Compile-time [reflection](reflection.md) sees the type as its arguments say:
`fields(Box[int])` gives `item` as an `int`, and `restore(Box[int])` makes
one. So [stdjac's codec](../apps/stdjac.md#the-codec) sends a `Box[int]` typed, and it
is sendable where its arguments are.

```jac
import from jaclang.comptime { fields, kind, set_field, restore }
import from stdjac { CodecError, decode, encode }

obj Box[T] {
    has item: T;
}

def kinds -> list[str] {
    out: list[str] = [];
    comptime for f in fields(Box[int]) {
        out.append(f"{f.name}: {kind(f.type).name.lower()}");
    }
    return out;
}

def seven -> Box[int] {
    b = restore(Box[int]);
    set_field(b, "item", 7);
    return b;
}

with entry {
    print(kinds(), seven());
    print(encode(Box[int](item=3)), decode[Box[int]]({"item": 4}).item + 1);
    try {
        decode[Box[int]]({"item": "x"});
    } except CodecError as e {
        print("CodecError:", e);
    }
}
```

```output
['item: int'] Box(item=7)
{'item': 3} 5
CodecError: .item: expected an int, got 'x'
```

## Generic bases

A generic class may have a base and be one.

- `obj Stack[T](Base)`: each `Stack` is a `Base`, dispatched to through it.
  An instance for a value type (a `Stack[P]`) inherits from the class's base
  too.
- `obj IntStack(Stack[int])`: a class's first base may be a generic class
  given its type arguments. Through it, the base's members of type `T` are
  of the type it gives (the instance for a value type, when it is one).
- `obj Twin[T](Stack[T])`: a generic subclass passes its parameter on.
- `obj Loose(Stack)`: a generic base with no arguments has them as `any`.

```jac
struct P {
    has x: int = 0;
}

obj Base {
    def hello -> str {
        return "base";
    }
}

obj Stack[T](Base) {
    has items: list[T] = [];

    def push(x: T) -> Self {
        self.items.append(x);
        return self;
    }

    def top -> T {
        return self.items[-1];
    }

    override def hello -> str {
        return f"stack of {len(self.items)}";
    }
}

obj IntStack(Stack[int]) {
    def total -> int {
        t = 0;
        for x in self.items {
            t += x;
        }
        return t;
    }
}

obj Twin[T](Stack[T]) {
    has other: T;

    def both -> list[T] {
        return [self.top(), self.other];
    }
}

obj Loose(Stack) {}

with entry {
    s = Stack[int]().push(1).push(2);
    held: Base = s;
    ps: Base = Stack[P]().push(P(x=5));
    print(s.top() + 1, held.hello(), ps.hello(), isinstance(s, Base));
    i = IntStack(items=[3, 4]);
    print(i.total(), i.top() * 10, Twin[str](other="b").push("a").both());
    print(Loose().push(1).push("two").items);
}
```

```output
3 stack of 2 stack of 1 True
7 40 ['a', 'b']
[1, 'two']
```

A subclass that gives the parameter a type may not override a method of the
base that takes or gives `T` (`override def get -> int` in a subclass of
`Pair[int]`): this is not built yet (E5090), since the base holds `T`'s
values as `any`s, which a call through it passes.

## Classes bounded by interfaces

A generic class whose type parameter is bounded by an interface, or by
several bounds (`obj Sorted[T: Ordered]`, `obj Shelf[T: Shape & Named]`), is
copied for each type it is given, as such a function is for each call (see
[How generic code is compiled](generics-compiling.md)). It is checked once where it is declared (E1284 for
a use the bounds do not provide), and each type argument makes an instance
of its own, on every host, in which the bound's operations are that type's
own (`<` of an int, `+` and the literals of an `f32`, a class's methods).
Each instance is its class to `isinstance`, `repr` and `type(c).__name__`.

- The type given must conform (E1283), where it is written or found from a
  construction.
- The class's name alone gives each parameter `any` (`Sorted` is a
  `Sorted[any]`), which conforms to `Ordered` alone.
- A body that makes a `T` from a number (`has total: T = 0`) takes number
  types alone: a class of the program's own, even one conforming to
  `Number`, is refused there (E1478; see
  [Builtin interfaces](interfaces-builtin.md)).

```jac
obj Tally[T: Number] {
    has total: T = 0;

    def add(v: T) {
        self.total = self.total + v;
    }
}

obj Sorted[T: Ordered] {
    has items: list[T] = [];

    def put(v: T) {
        i = 0;
        while i < len(self.items) and self.items[i] < v {
            i += 1;
        }
        self.items.insert(i, v);
    }
}

with entry {
    t = Tally[f32]();
    t.add(1.5);
    t.add(f32(0.1));
    s = Sorted();
    s.put(3);
    s.put(1);
    print(t, type(t).__name__, s.items);
}
```

```output
Tally(total=1.6) Tally [1, 3]
```

## What is rejected

| Code | When |
|---|---|
| E1053 | Fields give `T` two types; a `Box[int]` passed where a `Box[str]` is wanted; a type argument outside a class bound |
| E1001 | A `Box[int]` assigned where a `Box[str]` is wanted; a field of type `T` assigned another type |
| E1283 | A type argument that does not conform to an interface bound |
| E1284 | A body bounded by interfaces uses what its bounds do not provide |
| E1560 | `isinstance(x, Box[int])`: a generic class given type arguments |
| E1164 | A generic class given the wrong number of type arguments |
| E1478 | A class given to a body that makes a `T` from a number |
| E5090 | An override of a generic base's method taking or giving `T`, in a class giving `T` a type |

```jac
# expect: E1053 x3, E1001 x2, E1560, E1164, E1283
obj Pair[T] {
    has a: T,
        b: T;
}

obj Named {
    has label: str = "";
}

obj Shelf[T: Named] {
    has items: list[T] = [];
}

obj Sorted[T: Ordered] {
    has items: list[T] = [];
}

obj Thing {
    has n: int = 0;
}

def take(p: Pair[str]) -> str {
    return p.a;
}

with entry {
    p = Pair(a=1, b="x");
    q: Pair[int] = Pair(a="s", b="t");
    r = Pair[int](a=1, b=2);
    r.a = "s";
    take(r);
    print(isinstance(q, Pair[int]));
    w: Pair[int, str] = Pair(a=1, b=2);
    h = Shelf[int]();
    o = Sorted[Thing]();
}
```

```jac
# expect: E5090 x2
obj Pair[T] {
    has a: T;

    def get -> T {
        return self.a;
    }

    def put(v: T) {
        self.a = v;
    }
}

obj Ints(Pair[int]) {
    override def get -> int {
        return 0;
    }

    override def put(v: int) {
        self.a = v * 2;
    }
}
```

## Differences from Python and from the reference design

- **In Python a generic class's arguments are erased: `Box[int]` and
  `Box[str]` are one class to the program, and nothing checks what a
  `Box[int]` holds. Here they are different types**, and a `Box[int]`'s
  field of type `T` is checked as an `int`. A type argument that is a value
  type makes an instance of its own that holds it in place.
- **In Python `isinstance(x, Box[int])` raises `TypeError` when it runs;
  here it is a compile-time error** (E1560).

## See also

- [Generics](generics.md): type parameters, bounds and inference.
- [Compile-time parameters](comptime-parameters.md): archetypes with value
  parameters (`obj Vec[comptime N: int]`).
- [Structs](structs.md): values held in place.
- [Inheritance](inheritance.md): bases and dispatch.
