---
description: Single and multiple inheritance between archetypes, what a subclass inherits, method resolution order, virtual dispatch, isinstance and narrowing.
keywords: inheritance, base class, subclass, multiple inheritance, method resolution order, MRO, virtual dispatch
grammar: inherit_list
---
# Inheritance

An archetype names its bases in parentheses after its name. It then has
every field and method of each base, may add its own, and may replace a
method with an override. A value of the subclass goes wherever a value of a
base is wanted.

## Syntax

```ebnf
inherit_list ::= (call_arg ("," call_arg)* ","?)?
```

The list sits in the archetype's header: `obj Square(Rect) {`, `obj
Duck(Walks, Swims) {`. Each item is the name of an archetype, plain or
through its module (`shapes.Rect`). The first may be a generic archetype
given its type arguments (`obj IntBox(Box[int])`); see
[Generic classes](generics-classes.md). An archetype with no bases is written with no
parentheses (W3005 for `obj A() {`).

## What may be a base

| The archetype is | Its bases are |
|---|---|
| `obj` | Other `obj`s and `class`es, including the builtin exception classes |
| `class` | Other `class`es and the builtin exception classes; not an `obj` (E5090) |
| `node` | Other `node`s |
| `edge` | Other `edge`s |
| `walker` | Other `walker`s |
| `struct` | [Interfaces](interfaces.md) only: a struct inherits no fields or code (E1500) |

A base of another kind is E2106, so a `node` cannot extend an `obj`. A base
that is not a name is E2101, an unknown one E2018, and an archetype among
its own bases E2105. Bases may be declared later in the module, or in a
module that imports this one.

An `obj` whose base is an exception class is an exception, raised and
caught like any other:

```jac
obj AppError(Exception) {}

obj NotFound(AppError) {}

def find(key: str) -> str {
    if key == "" {
        raise NotFound("no key");
    }
    return key;
}

with entry {
    try {
        find("");
    } except AppError as e {
        print(type(e).__name__, e, isinstance(e, Exception));
    }
}
```

```output
NotFound no key True
```

## What a subclass inherits

```jac
obj Shape {
    has name: str = "shape";

    def area -> float {
        return 0.0;
    }

    def describe -> str {
        return f"{self.name} with area {self.area()}";
    }
}

obj Rect(Shape) {
    has w: float = 1.0,
        h: float = 1.0;

    override def area -> float {
        return self.w * self.h;
    }
}

obj Square(Rect) {
    override def describe -> str {
        return "a " + super.describe();
    }
}

with entry {
    r = Rect("rect", 2.0, 3.0);
    s = Square(name="square", w=4.0, h=4.0);
    print(r, r.describe());
    print(s, s.describe());
    shapes: list[Shape] = [Shape(), r, s];
    print([x.area() for x in shapes]);
}
```

```output
Rect(name='rect', w=2.0, h=3.0) rect with area 6.0
Square(name='square', w=4.0, h=4.0) a square with area 16.0
[0.0, 6.0, 16.0]
```

- **Fields.** The subclass has its bases' fields followed by its own, in
  that order in the constructor and in `repr`. With several bases, the
  last-listed base's fields come first. A subclass may declare a base's
  field again with the same type to change its default; see
  [Fields](fields.md).
- **Methods, static methods and properties.** Each is found on the subclass
  unless it defines one of the same name.
- **Static fields.** A base's static field is the same single value seen
  through the subclass.
- **`init` and `postinit`.** A subclass with no `init` of its own is
  constructed by the nearest base's written `init`, or by its fields when
  no base has one. See [Fields](fields.md).
- **Abilities.** How a node's or walker's abilities combine with its
  bases' is described in [Abilities](abilities.md).

## Overriding and dispatch

A method defined in a subclass with a base method's name overrides it. A
call `x.m()` runs the method of the class of the object `x` refers to,
whatever the type of the variable: `describe` above is declared in `Shape`
and calls `Rect`'s or `Square`'s `area` through `self`. This is true for
methods called through `self`, through a variable or field typed as a base,
and through a container of the base type.

Two calls do not dispatch:

- `super.m()` runs the next class's `m`, described below.
- `Base.m(x)`, the method taken from a class, runs that class's own `m`
  even when `x` is of a subclass that overrides it.

An override has the same parameters and return type as the method it
replaces. It may add parameters after them, each with a default: a call
through the base leaves them out, and they take their defaults. What it
returns may be narrower: a subclass of the base method's result, or fewer
members of its union. Anything else is E2199, at the override: a call
through the base passes what the base method declares, so an override that
takes another type would be handed a value it does not expect. A method
with type parameters of its own keeps the same number of them in an
override (E2195). A constructor's `init` and `postinit` are each class's
own, with whatever parameters it needs.

## Several bases and the method resolution order

When a name is defined by more than one base, the method resolution order
(MRO) decides which one a subclass gets. It is Python's (C3 linearization):
the class itself, then its bases left to right, each before its own bases,
with a shared base after every class that derives from it. `super.m()` in a
class runs `m` of the next class in the MRO of the object's class that
defines it.

```jac
obj Base {
    def who -> str {
        return "base";
    }
}

obj Left(Base) {
    override def who -> str {
        return "left>" + super.who();
    }
}

obj Right(Base) {
    override def who -> str {
        return "right>" + super.who();
    }
}

obj Diamond(Left, Right) {
    override def who -> str {
        return "diamond>" + super.who();
    }
}

obj Walks {
    has legs: int = 2;

    def move -> str {
        return f"walks on {self.legs}";
    }
}

obj Swims {
    has fins: int = 0;

    def move -> str {
        return "swims";
    }

    def dive -> str {
        return "dives";
    }
}

obj Duck(Walks, Swims) {}

with entry {
    print(Diamond().who());
    d = Duck();
    print(d.move(), d.dive(), d, isinstance(d, Walks), isinstance(d, Swims));
    swimmers: list[Swims] = [d, Swims()];
    print([s.move() for s in swimmers]);
}
```

```output
diamond>left>right>base
walks on 2 dives Duck(fins=0, legs=2) True True
['walks on 2', 'swims']
```

`Diamond`'s order is Diamond, Left, Right, Base, so `super.who()` in `Left`
reaches `Right` when the object is a `Diamond`. `Duck` takes `move` from
`Walks`, its first base, also when it is held as a `Swims`.

Bases that admit no consistent order are E5030 (`obj Z(X, Y)` where `Y`
already derives from `X`). Two bases that each declare a field of the same
name are not built yet (E5090).

## `isinstance`, `issubclass` and narrowing

`isinstance(x, C)` is true when the object is of class `C` or of a subclass
of it. The second argument is a class, a builtin type, or a tuple of them
(E1179 otherwise). `issubclass(D, C)` asks the same of two classes; when
either is a class held in an `any` (`type(x)`, a class passed as a value),
it is decided as the program runs, and a first argument that is not a class
raises `TypeError: issubclass() arg 1 must be a class`. `type(x) is C` is
true only for `C` exactly.

A subclass value converts to a base type without being asked. The other
direction needs a test: assigning a `Shape` to a `Rect` variable is E1001,
and reading a subclass's field through a base-typed variable is E1030. An
`isinstance` test narrows the variable, or a field path such as `f.shape`,
to the class it tests for, wherever the test is known to hold:

```jac
obj Shape {
    has name: str = "shape";
}

obj Rect(Shape) {
    has w: float = 1.0,
        h: float = 1.0;
}

obj Square(Rect) {}

def measure(s: Shape) -> str {
    if isinstance(s, Square) {
        return f"square of side {s.w}";
    } elif isinstance(s, Rect) and s.h > 1.0 {
        return f"tall rect {s.w}x{s.h}";
    }
    if not isinstance(s, Rect) {
        return "not a rect";
    }
    return f"rect {s.w}x{s.h}";
}

def kind(v: int | str | Shape | None) -> str {
    if isinstance(v, (int, str)) {
        return "scalar";
    }
    match v {
        case Rect(w=w):
            return f"rect {w} wide";
        case Shape():
            return "shape";
    }
    return "nothing";
}

with entry {
    print(measure(Square(w=3.0)), "|", measure(Rect(h=5.0)), "|", measure(Shape()));
    print(kind(7), kind(Rect(w=4.0)), kind(Shape()), kind(None));
    print(issubclass(Square, Shape), type(Square()) is Rect);
}
```

```output
square of side 3.0 | tall rect 1.0x5.0 | not a rect
scalar rect 4.0 wide shape nothing
True False
```

Narrowing applies in the branch a test guards, on the right of `and` after
it, in the code after an `if not isinstance(...)` that returns, and on the
right of `or` after a negated test. A class pattern in `match` narrows the
same way; see [Pattern matching](pattern-matching.md).

A branch that assigns the variable anywhere in it is not narrowed at all,
not even before the assignment. For a field path such as `f.shape`, the same
holds when the branch assigns the path itself (`f.shape = ...`) or anything
it reads through (`f = ...`). Read the narrowed value into a new local first
when the branch needs to rebind the name:

```jac
# expect: E1030 x2
obj Shape {
    has name: str = "shape";
}

obj Rect(Shape) {
    has w: float = 1.0;
}

obj Frame {
    has shape: Shape = Shape();
}

def widths(s: Shape, f: Frame) -> float {
    total = 0.0;
    if isinstance(s, Rect) {
        total += s.w;
        s = Shape();
    }
    if isinstance(f.shape, Rect) {
        total += f.shape.w;
        f = Frame();
    }
    return total;
}

with entry {
    print(widths(Rect(), Frame()));
}
```

`isinstance(x, Box[int])`, a generic class with type arguments, is E1560:
an object is of the class whatever its arguments, so test `isinstance(x,
Box)`.

## Abstract archetypes

A base may declare methods with `abst` and no body, for subclasses to
define; see [Methods](methods.md). An `obj` made only of abstract methods
is an interface, which the compiler checks every conforming class against;
see [Interfaces](interfaces.md).

## What is rejected

| Code | When |
|---|---|
| W3005 | Empty parentheses: `obj A() {` |
| E2101 | A base that is not the name of an archetype |
| E2018 | A base name that is not declared |
| E2105 | An archetype among its own bases |
| E2106 | A base of another archetype kind |
| E1500 | A struct listing a base that is not an interface |
| E5030 | Bases with no consistent method resolution order |
| E2195 | An override with a different number of type parameters |
| E2199 | An override whose parameters or return type differ from the method it replaces |
| E1230, E1231 | A field declared again with another type; a field with no default under an inherited `init`. See [Fields](fields.md) |
| E1001, E1030 | A base value used as a subclass without a test |
| E1179, E1560 | `isinstance` with something that is not a class, or with a generic class's type arguments |
| E5090 | One field name declared by two bases; a `class` deriving from an `obj` |

```jac
# expect: E2105, E2106, E5030, E2018, E2101
obj A(B) {}

obj B(A) {}

node Place {}

obj Office(Place) {}

obj X {}

obj Y(X) {}

obj Z(X, Y) {}

obj U(Missing) {}

obj V(1 + 2) {}
```

```jac
# expect: E1030, E1001, E1179, E2199 x2
obj Shape {
    def scaled(k: int) -> str {
        return f"shape x{k}";
    }

    def name -> str {
        return "shape";
    }
}

obj Rect(Shape) {
    has w: float = 1.0;

    override def scaled(k: str) -> str {
        return k;
    }

    override def name(prefix: str) -> str {
        return prefix + "rect";
    }
}

with entry {
    s: Shape = Rect();
    print(s.w);
    r: Rect = s;
    print(isinstance(s, "Rect"));
}
```

## Differences from Python and from the reference design

- **In Python any class can extend any other; here a base is of the same
  archetype kind** (an `obj` may also extend a `class`), and a `struct`
  extends nothing.
- **In Python an attribute missing from the static type is found when the
  code runs; here it is a compile-time error** until an `isinstance` test
  or a `match` narrows the variable.
- **In Python `super().m()`; here `super.m()`.**
- **The method resolution order and the order of inherited fields are
  Python's** (a dataclass's, for fields), and the reference design's.

## See also

- [Methods](methods.md): `override`, `abst`, `super`.
- [Fields](fields.md): inherited fields, `init` and `postinit`.
- [Interfaces](interfaces.md): conformance checked by the compiler, and `dyn`.
- [Generic classes](generics-classes.md): generic bases.
