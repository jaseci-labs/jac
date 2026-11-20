---
description: The archetype kinds (obj, node, edge, walker, struct, class), how one is declared and constructed, and how its instances print and compare.
keywords: obj, class, archetype, archetypes, constructor, repr of an object, object equality
grammar: archetype, archetype_member
---
# Archetypes

An archetype is a named type with fields and methods: what other languages
call a class. Jac has six kinds, each written with its own keyword. `obj` is
the general one, and the others add or change one thing each.

| Keyword | What its instances are | `==` | Page |
|---|---|---|---|
| `obj` | Objects held by reference | compares fields | this page |
| `node` | Objects that are places in a graph, joined by edges | identity | [Nodes](nodes.md) |
| `edge` | Objects that join two nodes | identity | [Edges](edges.md) |
| `walker` | Objects that travel a graph and run abilities | identity | [Walkers](walkers.md) |
| `struct` | Values held in place and copied on assignment | compares fields | [Structs](structs.md) |
| `class` | Objects held by reference, as Python's plain classes | identity, unless it defines `__eq__` | [below](#classes) |

`jac docs nodes`, `jac docs walkers` and `jac docs structs` print
the other kinds' pages.

## Syntax

```ebnf
archetype ::= decorators "async"? ("struct" | "class" | "walker" | "edge" | "obj" | "node") access_tag NAME ("[" type_params "]")? ("(" inherit_list ")")? (":" pipe "-->" pipe)? where_clause? ("{" archetype_member* "}" | ";")

archetype_member ::= (STRING? (ability | has_stmt | comptime_global | archetype | enum_decl | impl_def | module_code | stmt))?
```

The parts of the header, in order:

| Part | Example | Page |
|---|---|---|
| Decorators | `@align(64)` | [Decorators](decorators.md) |
| Kind | `obj` | this page |
| Access tag | `obj:pub Point` | [Access tags](access.md) |
| Name | `Point` | |
| Type parameters | `obj Box[T]` | [Generic classes](generics-classes.md) |
| Bases | `obj Square(Rect)` | [Inheritance](inheritance.md) |
| Endpoints, of an edge | `edge Road: City --> City` | [Edges](edges.md) |
| `where` clause | `obj Ring[comptime N: int] where N >= 2` | [Where clauses](interfaces-where.md) |

An archetype with no bases is written without parentheses: `obj Point {`.
Empty parentheses are an error (W3005).

A body holds these members:

| Member | Declares | Page |
|---|---|---|
| `has` | Fields, static fields and properties | [Fields](fields.md) |
| `def` | Methods, `init` and `postinit` | [Methods](methods.md) |
| `can` | Abilities, which run when a walker meets a node | [Abilities](abilities.md) |
| `comptime NAME: T = v;` | A compile-time member | [Interfaces](interfaces.md) |

A string before a member, or before the archetype, is its docstring.

An archetype is declared at module level. The grammar also admits the forms
below, and jac refuses each of them for now with E5090: an archetype or an
enum inside an archetype's body or inside a function, a `with entry` block or
any other statement in an archetype's body, a declaration without a body
(`obj Point;`), and `async` before an archetype.

## Declaring and constructing

An `obj` declares its fields with `has`. The compiler gives it a constructor
that takes the fields, a `repr` that shows them, and an `==` that compares
them.

```jac
obj Point {
    has x: int = 0,
        y: int = 0;

    def moved(dx: int) -> Point {
        return Point(x=self.x + dx, y=self.y);
    }
}

with entry {
    p = Point(1, 2);
    q = Point(y=2, x=1);
    print(p, q.moved(5), Point());
    p.x = 10;
    print(p.x, p == q, type(p).__name__);
}
```

```output
Point(x=1, y=2) Point(x=6, y=2) Point(x=0, y=0)
10 False Point
```

Calling the archetype's name constructs an instance:

- **Arguments are the fields**, by position in the order they are declared,
  or by name. A base's fields come before the class's own.
- **A field with a default may be left out.** Its default expression is
  evaluated at each construction that leaves it out, so a default of `[]`
  gives every instance its own list.
- **A field without a default is required**, wherever it is declared: after
  `has x: int = 1, z: int;`, `A(3, 4)` sets both and `A(z=4)` leaves `x` at 1.
- **A class that writes `def init`** is constructed with that method's
  parameters instead. See [Fields](fields.md).

A variable of an archetype's type holds a reference to an object (a `struct`
excepted): `q = p` makes `q` the same object, and a change through one name
is seen through the other. Fields are fixed by the declaration. An object has
exactly the fields its archetype and its bases declare, and reading or
assigning any other name is an error (E1030).

## How an object prints

`repr(x)`, `str(x)`, `print(x)` and an f-string all show an object as its
archetype's name and its fields in declaration order, each value shown by its
own `repr`:

```jac
obj Tag {
    has name: str,
        weight: float = 1.0;
}

obj Post {
    has title: str,
        tags: list[Tag] = [];
}

obj Money {
    has cents: int;

    def __str__ -> str {
        return f"${self.cents // 100}.{self.cents % 100:02}";
    }
}

with entry {
    p = Post(title="hi", tags=[Tag(name="a")]);
    print(p);
    m = Money(cents=1250);
    print(m, str(m), repr(m), [m]);
}
```

```output
Post(title='hi', tags=[Tag(name='a', weight=1.0)])
$12.50 $12.50 Money(cents=1250) [Money(cents=1250)]
```

A class changes this by defining `__repr__` or `__str__` (see
[Special methods](methods-special.md)):

- `repr(x)` is the `__repr__` the object's `obj` declares itself, else the
  generated one. An `obj` that declares no `__repr__` gets the generated one
  even when a base defines `__repr__`, as a Python dataclass does: a base's
  `__repr__` is not inherited. (A `class` inherits it; see [Classes](#classes).)
- `str(x)`, `print(x)` and `f"{x}"` are its `__str__`. A class with no
  `__str__`, its own or inherited, uses its `repr`.
- Both are found by the class of the object, not by the type of the variable
  that holds it.
- A container shows its items by `repr`, as Python does.

```jac
obj Reading {
    has v: int = 1;

    def __repr__ -> str {
        return "Reading()";
    }
}

obj Labeled(Reading) {
    has tag: str = "t";
}

with entry {
    print(repr(Reading()), repr(Labeled()), Labeled());
}
```

```output
Reading() Labeled(v=1, tag='t') Labeled(v=1, tag='t')
```

`type(x)` prints as `<class 'Point'>`, and `type(x).__name__` is the name.

## Equality and hashing

| Kind | `a == b` | Usable as a dict key or set member |
|---|---|---|
| `obj` | True when both are of the same class and every field is equal | Only with a `__hash__` of its own (E1180 otherwise) |
| `class` | Its `__eq__`, its own or a base's; else only for the same object | By its `__hash__`, else by identity; not when it defines `__eq__` without `__hash__` (E1180) |
| `node`, `edge`, `walker` | True only for the same object | Yes, by identity |
| `struct` | True when every field is equal | Yes, hashed by its fields |

`is` compares identity for every kind held by reference. Field comparison
uses each field's own `==`, so it reaches into nested objects and
containers. An `obj` and an instance of its subclass are never equal, even
when the fields they share are. The same comparison is what `in`,
`list.index` and the `==` of lists and dicts use, also on values held in an
`any`.

```jac
obj Point {
    has x: int = 0,
        y: int = 0;
}

obj Point3(Point) {
    has z: int = 0;
}

node Spot {
    has x: int = 0;
}

obj Key {
    has id: int;

    def __eq__(other: Key) -> bool {
        return self.id == other.id;
    }

    def __hash__ -> int {
        return hash(self.id);
    }
}

with entry {
    p = Point(x=1);
    print(p == Point(x=1), p is Point(x=1), p != Point(x=2));
    print(Point(x=3) in [Point(x=3)], p == Point3(x=1));
    s = Spot(x=1);
    print(s == Spot(x=1), s == s, len({s, Spot(x=1)}));
    print(len({Key(id=1), Key(id=1)}), {Key(id=2): "two"}[Key(id=2)]);
}
```

```output
True False True
True False
False True 2
1 two
```

A class that defines `__eq__` decides its own equality, and is hashable when
it also defines `__hash__`. An object is equal to itself without its fields
being compared, so `a == a` holds even when `a` refers to itself. Comparing
two objects whose fields lead back to themselves (two separate cycles of the
same shape) raises `RecursionError`.

- **A dict or set compares hashes first**, and asks `==` only of keys whose
  hashes are equal: objects that `__eq__` calls equal but that hash apart
  are separate keys, as in Python.
- **E1180 is reported where the key's type is known.** An `obj` without a
  `__hash__` held in an `any` raises `TypeError: unhashable type: 'Point'`
  when `hash` is called on it or it is used as a key or a set member.

```jac
obj Point {
    has x: int = 0;
}

obj Loose {
    has n: int = 0;

    def __eq__(other: any) -> bool {
        return True;
    }

    def __hash__ -> int {
        return self.n;
    }
}

with entry {
    pts = [Point(x=1), Point(x=2)];
    held: any = pts;
    print(
        pts.index(Point(x=2)),
        held == [Point(x=1), Point(x=2)],
        {"p": Point(x=1)} == {"p": Point(x=1)},
    );
    print(len({Loose(n=1), Loose(n=2), Loose(n=1)}));
    p: any = Point(x=1);
    try {
        print(hash(p));
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
1 True True
2
TypeError: unhashable type: 'Point'
```

## Classes

`class` declares Python's plain class. A class is laid out and constructed as
an `obj` is (its `has` fields are the constructor's arguments, or its `init`'s
parameters are), but nothing is generated for it:

- **`repr` and `str`** are the class's own `__repr__` and `__str__`, or its
  nearest base's. A class that defines neither prints as `<Name object>`.
- **`==`** is the class's `__eq__`, its own or its nearest base's, else
  identity: two instances are equal only when they are the same object.
- **`hash`** is its `__hash__`, its own or its nearest base's, else identity,
  so an instance is a dict key or a set member. As in Python, a class that
  defines `__eq__` and no `__hash__` is not hashable (E1180).

```jac
class Handler {
    has name: str = "h",
        level: int = 0;

    def __repr__ -> str {
        return f"<{type(self).__name__} {self.name}>";
    }
}

class Null(Handler) {}

class Counter {
    has n: int = 0;
}

obj Entry(Handler) {
    has text: str = "";
}

with entry {
    a = Null();
    print(a, Null("x", 5), a == Null(), a == a);
    c = Counter(3);
    print(c, c.n, len({c, Counter(3), c}));
    print(Entry("e", 1, "hi"), Entry(text="t") == Entry(text="t"));
}
```

```output
<Null h> <Null x> False True
<Counter object> 3 2
Entry(name='e', level=1, text='hi') True
```

`Null` inherits `Handler`'s `__repr__`, where an `obj` would not. A class's
bases are classes, or the builtin exception classes (`class Problem(Exception)
{}` is an exception). An `obj` may derive from a class, and is then a value
again: `Entry` above prints and compares by its fields, as every `obj` does. A
class cannot derive from an `obj` (E5090), whose generated `repr` and `==`
are made for the `obj`'s own fields:

```jac
# expect: E5090
obj Point {
    has x: int = 0;
}

class Named(Point) {
    has name: str = "";
}
```

Write `class` where Python code has a class whose instances are things with an
identity (a handler, a connection, a parser), and `obj` where it has a
dataclass. The standard library's classes are declared `class`. The word is
also a method modifier (`class def`); see [Methods](methods.md).

## What is rejected

| Code | When |
|---|---|
| E1050 | A construction leaves out a field that has no default |
| E1051 | A construction gives more positional arguments than there are fields |
| E1052 | A construction names a keyword that is no field |
| E1057 | A field is given both by position and by name |
| E1030 | A field or method is read or assigned that the archetype does not have |
| E1180 | An `obj` without a `__hash__` is used as a dict key or a set member |
| E0077 | Two members of one archetype have the same name |
| E2036 | The archetype's name is already declared in the module |
| W3005 | Empty parentheses after the name: `obj Point() {` |
| E5090 | A `class` deriving from an `obj`, a nested archetype, a statement in the body, a declaration without a body, an `async` archetype |

```jac
# expect: E1050, E1051, E1052, E1057, E1030
obj Point {
    has x: int,
        y: int = 0;
}

with entry {
    a = Point();
    b = Point(1, 2, 3);
    c = Point(1, z=3);
    d = Point(1, x=2);
    d.z = 3;
}
```

```jac
# expect: E1180
obj Point {
    has x: int = 0;
}

with entry {
    seen = {Point(x=1): True};
}
```

## Differences from Python and from the reference design

- **In Python a class body assigns attributes and `__init__` creates the
  instance's; here `has` declares the fields** and the constructor, `repr`
  and `==` are generated, as for a Python dataclass.
- **In Python any attribute can be added to an instance; here it cannot.**
  `p.z = 3` on an object whose archetype has no `z` is E1030.
- **In Python a dataclass with a mutable default is an error; here
  `has items: list[int] = [];` is the normal form**, and each instance gets a
  new list.
- **In Python `type(p)` prints `<class '__main__.Point'>`; here it prints
  `<class 'Point'>`.**
- **A `class` is Python's plain class**: printed as `<Point object>` (CPython adds the module
  and the address, `<__main__.Point object at 0x...>`), equal only to itself unless it
  defines `__eq__`.
- **In the reference design `obj Point() {` is accepted; here it is W3005.**
- **Python's spellings are errors**: `def __init__` is `def init` (W3004),
  `@staticmethod` is `static def` (W3001), `@property` is a `has` with a
  getter (W3043). See [Methods](methods.md) and [Fields](fields.md).

## See also

- [Fields](fields.md): `has`, defaults, `static has`, `init`, `postinit`, properties.
- [Methods](methods.md): `def`, `self`, `static def`, `override`, `abst`.
- [Special methods](methods-special.md): operators, `__repr__`, `__eq__`, `__hash__` and the rest.
- [Inheritance](inheritance.md): bases, method resolution, `super`, `isinstance`.
- [Impl blocks](impl.md): declaring a member here and writing its body elsewhere.
- [Reflection](reflection.md): `type`, `getattr`, and a type's fields at compile time.
