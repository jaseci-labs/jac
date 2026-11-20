---
description: Interfaces (an obj of abstract methods and compile-time members), how a class conforms to one, and an interface used as a type parameter's bound and as a dyn reference.
keywords: interface, interfaces, conformance, conform, dyn, associated member
grammar: dyn_type
---
# Interfaces

An interface says what a type must provide: methods with no body and
compile-time members with no value. A class conforms to an interface by
listing it among its bases and giving everything it requires, and the
compiler checks that it does. An interface is used in two ways: as the
bound of a type parameter (`[T: Shape]`), where each call is compiled for
the class it is given, and as `dyn Shape`, a reference to a value of any
conforming class, dispatched as the program runs.

Four interfaces of builtin values, `Ordered`, `Number`, `Int` and `Float`,
are described in [Builtin interfaces](interfaces-builtin.md), and the
compile-time conditions a generic declaration may state in
[Where clauses](interfaces-where.md).

## Syntax

An interface is an ordinary `obj` declaration (see
[Archetypes](archetypes.md)). The production this page adds is the type of a
reference to any conforming class:

```ebnf
dyn_type ::= "dyn" await_expr ("&" await_expr)*
```

`dyn` comes before a type's name, and is a word only there: elsewhere it is
an ordinary name (`dyn = 3;` is an assignment).

## What makes an interface

An `obj` is an interface when it has at least one member and every member
is

- an abstract method, `def area -> float abst;` (see [Methods](methods.md)), or
- a compile-time member with no value, `comptime BYTES: int;`,

and it has no fields and no bases but other interfaces. Anything else is an
ordinary class: an `obj` with abstract methods and a field, for example,
which the compiler does not check its subclasses against.

An interface has no instances: `Shape()` is E1280.

## Conforming

A class conforms by listing the interface among its bases. It must then
give every method the interface requires, with the same parameter names and
types and a return type that is the same or a subclass of it. `Self` in an
interface stands for the conforming class itself, so `-> Self` is satisfied
by `-> Self` or by the class's own name. A method a base class gives counts,
and is checked the same way.

A method left out is E1281, and one given with other parameters or another
return type is E1282, both reported at the class. A class may conform to
several interfaces, and an interface may extend others: a class conforming to
it must give what all of them require.

```jac
obj Shape {
    def area -> float abst;
    def scale(k: float) -> Self abst;
}

obj Named {
    def label -> str abst;
}

obj Rect(Shape, Named) {
    has w: float,
        h: float;

    def area -> float {
        return self.w * self.h;
    }

    def scale(k: float) -> Self {
        return Rect(w=self.w * k, h=self.h * k);
    }

    def label -> str {
        return f"rect {self.w}x{self.h}";
    }
}

obj Tri(Shape) {
    has b: float,
        h: float;

    def area -> float {
        return self.b * self.h / 2.0;
    }

    def scale(k: float) -> Tri {
        return Tri(b=self.b * k, h=self.h * k);
    }
}

def total[T: Shape](xs: list[T]) -> float {
    t = 0.0;
    for x in xs {
        t += x.area();
    }
    return t;
}

def grown[T: Shape](x: T) -> T {
    return x.scale(2.0);
}

def described[T: Shape & Named](x: T) -> str {
    return f"{x.label()}: {x.area()}";
}

with entry {
    print(total([Rect(w=1.5, h=2.0), Rect(w=0.5, h=4.0)]), total([Tri(b=3.0, h=1.0)]));
    print(grown(Tri(b=1.0, h=1.0)), described(Rect(w=2.0, h=0.25)));
}
```

```output
5.0 1.5
Tri(b=2.0, h=2.0) rect 2.0x0.25: 0.5
```

## Interfaces as bounds

`[T: Shape]` bounds a type parameter of a function or a generic class (see
[Generics](generics.md)) by an interface; `[T: Shape & Named]` bounds it by
several, joined with `&`.

- **At a call**, the type given for `T` or found from the arguments must
  conform to every bound, else the call is refused (E1283).
- **The body is checked once, where it is declared**, with `T` standing for
  any type that conforms: it may use what the bounds require and nothing
  more. A use they do not provide is E1284, with the error that names the
  use (E1030 for a missing method, E1110 for an operator), never an error in
  one copy for one type.
- **Each call is compiled for its type**, the type's own methods called
  directly, without dispatch. `total([Rect(...)])` above calls `Rect.area`.

### Compile-time members

A compile-time member is an `int`, `bool` or `str` that the interface names
and each conforming class gives a value (`comptime BYTES: int = 4;`). It is
read as `Word.BYTES` from the class, or as `T.BYTES` from a type parameter
bounded by the interface, and it is a compile-time value: it may decide a
`comptime if`, be a type's argument, or be used where code runs as its
literal.

```jac
obj Sized {
    comptime BYTES: int;
    comptime TAG: str;
}

obj Word(Sized) {
    comptime BYTES: int = 4;
    comptime TAG: str = "w";
}

obj Byte(Sized) {
    comptime BYTES: int = 1;
    comptime TAG: str = "b";
}

obj Buf[comptime N: int] {
    has data: list[int] = [];

    def size -> int {
        return N;
    }
}

def width[T: Sized] -> str {
    comptime if T.BYTES >= 4 {
        return f"{T.TAG}: wide";
    } else {
        return f"{T.TAG}: narrow";
    }
}

def buffer_size[T: Sized] -> int {
    b = Buf[T.BYTES]();
    return b.size();
}

def buffer_for[T: Sized] -> Buf[T.BYTES] {
    return Buf[T.BYTES]();
}

def pair_size[T: Sized](pair: Buf[T.BYTES * 2]) -> int {
    return pair.size();
}

with entry {
    print(width[Word](), width[Byte](), Word.BYTES + Byte.BYTES);
    print(buffer_size[Word](), buffer_size[Byte]());
    print(buffer_for[Word]().size(), pair_size[Byte](Buf[2]()));
}
```

```output
w: wide b: narrow 5
4 1
4 2
```

A class that leaves a compile-time member out is E1281. In a body that
branches on a member with `comptime if`, each branch is checked where the
function is declared, and the branch a copy picks is checked again in that
copy, where the member's value is known. A type whose argument is a member
(`Buf[T.BYTES]`), in a body or in the function's own signature, is checked
only in each copy: `pair_size[Byte](Buf[3]())` is E1053 there, where the
parameter is a `Buf[2]`.

## `dyn` references

An interface is not a type of its own: a value is always of a class, so
`s: Shape` is an error (E1482). `dyn Shape` is the type of a reference to a
value of any class that conforms to `Shape`.

- A value of a conforming class converts to `dyn Shape` without being
  asked, as a subclass converts to its base.
- A conforming [struct](structs.md) converts too, as a copy in a box: later
  changes to the struct do not reach the box.
- A method called through a `dyn` runs the method of the value's class,
  chosen as the program runs.
- `list[dyn Shape]` holds values of several conforming classes.
- An `isinstance` test or a `match` class pattern narrows a `dyn` to a class,
  whose own fields and methods it then reaches.
- `s as Circle` asserts the class of a `dyn`'s value, and raises `TypeError`
  when the value is of another class (see [Casts](types.md#casts-as)). A
  struct read this way is a copy of the one in the box.

```jac
obj Shape {
    def area -> float abst;
}

obj Rect(Shape) {
    has w: float,
        h: float;

    def area -> float {
        return self.w * self.h;
    }
}

obj Circle(Shape) {
    has r: float;

    def area -> float {
        return 3.0 * self.r * self.r;
    }
}

struct Seg(Shape) {
    has lo: float = 0.0,
        hi: float = 1.0;

    def area -> float {
        return self.hi - self.lo;
    }
}

def kind(s: dyn Shape) -> str {
    match s {
        case Rect():
            return f"rect {s.w} wide";
        case Circle():
            return f"circle of radius {s.r}";
    }
    return "other";
}

with entry {
    sg = Seg(hi=3.0);
    shapes: list[dyn Shape] = [Rect(w=1.0, h=3.0), Circle(r=1.0), sg];
    sg.hi = 10.0;
    print(sum([s.area() for s in shapes]), [kind(s) for s in shapes]);
    print(isinstance(shapes[2], Seg), isinstance(shapes[0], Shape));
    held = shapes[2] as Seg;
    held.hi = 5.0;
    print(held, shapes[2], (shapes[1] as Circle).r);
    try {
        print((shapes[0] as Circle).r);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
9.0 ['rect 1.0 wide', 'circle of radius 1.0', 'other']
True True
Seg(lo=0.0, hi=5.0) Seg(lo=0.0, hi=3.0) 1.0
TypeError: expected Circle, found Rect
```

The `Seg` in the list is the copy made when the list was built, before
`sg.hi` changed, so its area is 3.0.

A bound and a `dyn` are the two ways to take any conforming value. A function
with a bounded type parameter is compiled for each class it is called with
and its calls are direct; a `dyn` parameter is one function whose calls are
dispatched as it runs, and is the only way to hold values of several classes
in one list. The two meet: `dyn Shape` itself satisfies the bound `T:
Shape`, so a `list[dyn Shape]` may be passed to `def total[T: Shape](xs:
list[T])`, whose copy for `dyn Shape` dispatches each call.

`dyn` takes an interface: `dyn Plain` of a class is E1483. It does not take
an interface that builtin values conform to (`dyn Number`, `dyn Ordered`:
E1484), since a reference to a number would box it and dispatch its
operators as the program runs; bound a type parameter by it instead. A `dyn`
of several interfaces (`dyn Shape & Named`) is not built yet (E5090).

## On other hosts

An interface is a class and conformance is inheritance on every host. In a
`cpython` or `node` [space](../apps/archwire.md), an interface is emitted as an
ordinary class with its abstract methods, a conforming class as its
subclass, and the checks are the compiler's: nothing of them runs in the
program.

## What is rejected

| Code | When |
|---|---|
| E1280 | An interface is constructed, or a type parameter standing for one is |
| E1281 | A conforming class leaves out a method or compile-time member |
| E1282 | A conforming class gives a method with other parameters or another return type |
| E1283 | A call or a construction gives a type parameter a type that does not conform to its bound |
| E1284 | A body uses what its bounds do not provide (with the error naming the use) |
| E1482 | An interface used as a type of its own |
| E1483 | `dyn` of a class that is not an interface |
| E1484 | `dyn` of an interface builtin values conform to |
| E5090 | `dyn` of several interfaces |

```jac
# expect: E1281, E1282, E1280, E1283
obj Shape {
    def area -> float abst;
    def scale(k: float) -> Self abst;
}

obj Missing(Shape) {
    def area -> float {
        return 1.0;
    }
}

obj Renamed(Shape) {
    def area -> float {
        return 1.0;
    }

    def scale(factor: float) -> Self {
        return self;
    }
}

obj Plain {
    has n: int = 0;
}

def total[T: Shape](xs: list[T]) -> float {
    t = 0.0;
    for x in xs {
        t += x.area();
    }
    return t;
}

with entry {
    s = Shape();
    print(total([Plain()]));
}
```

```jac
# expect: E1284, E1030
obj Shape {
    def area -> float abst;
}

def named[T: Shape](x: T) -> str {
    return x.name();
}
```

```jac
# expect: E1482, E1483, E1484, E5090
obj Shape {
    def area -> float abst;
}

obj Named {
    def label -> str abst;
}

obj Plain {
    has n: int = 0;
}

def a(s: Shape) -> float {
    return 1.0;
}

def b(s: dyn Plain) -> float {
    return 1.0;
}

def c(s: dyn Number) -> float {
    return 1.0;
}

def d(s: dyn Shape & Named) -> float {
    return 1.0;
}
```

## Differences from Python and from the reference design

- **In Python an abstract base class is checked when it is instantiated, and
  a `Protocol` by a separate type checker; here conformance is checked by
  the compiler, at the class**, and a missing method is an error before the
  program runs.
- **In Python a class need not list a `Protocol` it satisfies; here a class
  conforms only by listing the interface** among its bases.
- **Python has no `dyn`; a variable of any class type may hold any
  subclass.** Here an interface is not a type, and a reference to any
  conforming class is written `dyn Shape`.
- **In the reference design `abst` methods are not checked, and a class missing one can be
  constructed; here an interface's are checked** (E1281). An `obj` with
  fields and abstract methods is an ordinary class in both.
- **The reference design has no `dyn`.**

## See also

- [Builtin interfaces](interfaces-builtin.md): `Ordered`, `Number`, `Int`
  and `Float`.
- [Where clauses](interfaces-where.md): compile-time conditions on generic
  declarations.
- [Generics](generics.md): type parameters, inference and bounds by a class.
- [Methods](methods.md): `abst` and `Self`.
- [Compile-time evaluation](compile-time.md): `comptime if` and compile-time
  members.
- [Inheritance](inheritance.md): bases, `isinstance` and dispatch.
