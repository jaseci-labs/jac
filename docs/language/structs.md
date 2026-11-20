---
description: The struct archetype, a value held in place and copied where it goes: how it is declared and made, what copying means, how fields and methods reach it in place, equality, and how it conforms to interfaces.
keywords: struct, value type, held in place, temporary copy
---
# Structs

`struct` declares a value. A struct is held in place where it is stored,
copied where it is assigned, passed, returned or stored, and laid out as C
lays it out. The other archetypes (`obj`, `node`, `edge`, `walker`, see
[Archetypes](archetypes.md)) declare references: assigning one of those
gives a second name for the same object, and assigning a struct gives a
second struct.

```jac
struct P {
    has x: float = 0.0,
        y: f32 = 0.0;

    def norm2 -> float {
        return self.x * self.x + float(self.y * self.y);
    }

    def shift(d: float) {
        self.x += d;
    }
}

obj Body {
    has at: P = P(),
        name: str = "";
}

def moved(p: P) -> P {
    p.x += 1.0;
    return p;
}

with entry {
    a = P(x=1.0);
    b = a;
    b.x = 5.0;
    a.shift(0.5);
    o = Body();
    o.at.y = 2.0;
    print(a, b);
    print(moved(a).x, a.x);
    print(o.at, a.norm2());
}
```

```output
P(x=1.5, y=0.0) P(x=5.0, y=0.0)
2.5 1.5
P(x=0.0, y=2.0) 2.25
```

`b = a` copied the struct, so `b.x = 5.0` left `a` as it was. `moved(a)`
changed its own copy. `o.at.y = 2.0` wrote into the object `o`, where its
`P` is held.

## Syntax

A struct is an archetype whose keyword is `struct`:

```ebnf
archetype ::= decorators "async"? ("struct" | "class" | "walker" | "edge" | "obj" | "node") access_tag NAME ("[" type_params "]")? ("(" inherit_list ")")? (":" pipe "-->" pipe)? where_clause? ("{" archetype_member* "}" | ";")
```

Its body has fields (`has`, see [Fields](fields.md)) and methods, as an
`obj`'s does. `struct` is a keyword only where a declaration starts
(`struct P {`, `struct:pub P {`). Anywhere else it is a name, so Python's
`struct` module imports and is used as before, and a variable may be called
`struct`.

## Making one

A struct is made by calling its name with its fields, by name or in order;
the rest take their defaults. It declares no `init` and no `postinit`
(E1502): a struct is made from its fields and nothing else.

```jac
struct P {
    has x: float = 0.0,
        y: f32 = 0.0;
}

with entry {
    print(P(1.0, 2.0), P(y=3.0), P());
}
```

```output
P(x=1.0, y=2.0) P(x=0.0, y=3.0) P(x=0.0, y=0.0)
```

## Layout

Each field is at the first offset its alignment allows, as in a C struct
with the same fields in the same order: a `bool` is a byte, an `f32` four
bytes, an `i16` two, a `float` eight. A struct field of a struct type is
held inside it. So `P` above is 16 bytes: `x` at 0, `y` at 8, and padding
to its 8-byte alignment. `@align(n)` raises a struct's alignment (see
[Decorators](decorators.md)).

A struct never holds itself (E1501): a field of its own type would have no
size.

## Copies

A struct is copied when it is

- assigned to a variable (`b = a`) or a field (`o.at = a`),
- passed as an argument: the parameter is the callee's own copy,
- returned: the caller gets a value of its own,
- stored in a container or taken out of one (see
  [Where structs are held](structs-storage.md) and
  [Packed lists](packed-lists.md)).

A copy of a struct that holds references (`has name: str`, a list, an
object) refers to what the original does, as a copy of an object's field
would: the struct is copied, and what it points to is shared.

```jac
struct Named {
    has name: str = "",
        tags: list[str] = [];
}

with entry {
    n = Named(name="a");
    m = n;
    m.name = "b";
    m.tags.append("t");
    print(n, m);
}
```

```output
Named(name='a', tags=['t']) Named(name='b', tags=['t'])
```

## Places

A field of a struct is reached in place. `o.at.y = 2.0` writes into the
object `o`; `p.at.y += 1.0` into the variable `p`; `ps[1].x = 5.0` into a
list's element.

- **A method takes `self` as the place it is called on.** A method that
  assigns to a field of `self` changes that variable, field or element:
  `a.shift(0.5)` changes `a`.
- **`&mut p` lends the variable itself** to a parameter declared `&mut P`,
  which then changes the caller's struct. See [Borrows and owned places](ownership-borrows.md).
- **A temporary copy is no place.** What a call gives, an item of a tuple
  and a struct read out of an `any` are copies nothing else holds. Writing
  a field of one, calling a method that changes it on one, or lending it
  with `&mut` would change only the copy, and is an error (E1504). Assign
  it to a variable and change that.

```jac
struct P {
    has x: float = 0.0;
}

def reset(p: &mut P) {
    p = P(x=-1.0);
}

def bump(p: &mut P) {
    p.x += 1.0;
}

with entry {
    a = P(x=1.0);
    bump(&mut a);
    print(a);
    reset(&mut a);
    print(a);
}
```

```output
P(x=2.0)
P(x=-1.0)
```

## Equality, hashing and None

- `==` compares fields. A NaN equals nothing, so a struct with a NaN field
  does not equal itself.
- `is` compares references, and a struct is none: `a is b` is an error
  (E1503). Compare with `==`.
- A struct compared by its fields (one with no `__eq__` of its own) is
  hashed by them, as the tuple of its fields is, so it is a dict's key or a
  set's member. A field that is not hashable (a list) raises `TypeError`
  where the struct is hashed, as a tuple's item does. A struct with a NaN
  field equals nothing, so it is never found again.
- A struct is never `None`. `P | None` is an optional struct: an `any`
  holding a struct or `None`.

```jac
struct P {
    has x: float = 0.0,
        y: int = 0;
}

with entry {
    a = P(x=1.0);
    print(a == P(x=1.0), a != P(x=2.0));
    nan = P(x=float("nan"));
    print(nan == nan, nan in {nan: 1});
    seen = {a: "first"};
    print(seen[P(x=1.0)], hash(a) == hash(P(x=1.0)));
    q: P | None = None;
    print(q);
    q = a;
    print(q);
}
```

```output
True True
False False
first True
None
P(x=1.0, y=0)
```

## Interfaces

A struct lists the interfaces it conforms to in its parentheses
(`struct Circle(Shape)`) and inherits nothing: a base that is a struct, or
an archetype with fields or code, is an error (E1500). See
[Interfaces](interfaces.md).

A struct is not a reference to an object, so it is not given where an
object type is wanted (E1505). It reaches an interface it conforms to in two
ways:

- **Through a compile-time type parameter bounded by the interface**
  (`def total[T: Shape](s: T)`), its methods called directly.
- **As a `dyn` of the interface** (`s: dyn Shape = c`): a copy of it in a
  box, as an `any` holds one, with the interface's methods dispatched on
  that copy. Nothing changes the copy, so a struct whose method the
  interface requires changes it is no `dyn` of that interface (E1562).

```jac
obj Shape {
    def area -> float abst;
}

struct Circle(Shape) {
    has r: float = 1.0;

    def area -> float {
        return 3.0 * self.r * self.r;
    }
}

def total[T: Shape](s: T) -> float {
    return s.area();
}

with entry {
    c = Circle(r=2.0);
    s: dyn Shape = c;
    print(total(c), s.area());
}
```

```output
12.0 12.0
```

## Ownership marks

`own`, `lin` and `imm` mark the owner of a reference (see
[Ownership](ownership.md)). A struct is a value its place holds, so they
mark no binding of one (E1507), and no field of a struct owns what it holds
(E1506): every copy would own it. `&` and `&mut` lend a struct's place as
they lend any.

## What is rejected

A declaration's errors are reported first, as the program's declarations are
read:

```jac
# expect: E1500, E1501, E1502, E1506
obj Base {
    has y: int = 0;
}

struct FromObj(Base) {
    has z: int = 0;
}

struct Nest {
    has inner: Nest;
}

struct WithInit {
    has x: int = 0;

    def init(x: int) {
        self.x = x;
    }
}

struct Owning {
    has name: own str = "";
}
```

Then the errors of its uses:

```jac
# expect: E1503, E1504 x3, E1505, E1507
obj Base {
    has y: int = 0;
}

struct P {
    has x: float = 0.0;

    def shift(d: float) {
        self.x += d;
    }
}

def made -> P {
    return P();
}

def lend(p: &mut P) {
    p.x = 0.0;
}

def kept(p: own P) -> float {
    return p.x;
}

with entry {
    a = P();
    b = P();
    print(a is b);
    made().x = 3.0;
    made().shift(2.0);
    lend(&mut made());
    k: Base = a;
}
```

| Code | Meaning |
|---|---|
| E1500 | A struct lists a base that is not an interface. |
| E1501 | A struct has a field of its own type. |
| E1502 | A struct declares `init` or `postinit`. |
| E1503 | `is` or `is not` is applied to a struct. |
| E1504 | A field write, a changing method or `&mut` is applied to a temporary copy. |
| E1505 | A struct is given where a reference to an object is wanted. |
| E1506 | A struct's field is marked `own`. |
| E1507 | A binding of a struct is marked `own`, `lin` or `imm`. |
| E1562 | A struct is made a `dyn` of an interface that requires a method changing it. |

## Differences from Python and the reference design

- In Python every class instance is a reference: `b = a` then `b.x = 5`
  changes `a`. Here that is what `obj` does, and a `struct` is copied.
- The reference design has no `struct`: the word is an unexpected token there.
- In Python `import struct` names the standard module. It still does here:
  `struct` is a keyword only at the start of a declaration.

More on what holds a struct (an `any`, a tuple, a dict, C memory, a closure,
another host) is in [Where structs are held](structs-storage.md), and lists
of structs are in [Packed lists](packed-lists.md).
