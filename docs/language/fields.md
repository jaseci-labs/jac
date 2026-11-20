---
description: Declaring an archetype's fields with has (types, defaults, static fields, postinit fields), the init and postinit constructors, and properties with getters and setters.
keywords: has, static has, init, postinit, getter, setter, deleter, property, properties, field, fields, default value, static field
grammar: has_stmt, has_var, accessor
---
# Fields

`has` declares the data an archetype's instances hold: per-instance fields,
fields of the class itself (`static has`) and properties computed by a
getter and a setter. The fields also define the constructor, unless the
archetype writes its own with `def init`.

## Syntax

```ebnf
has_stmt ::= "static"? "has" access_tag has_var ("," has_var)* ";"?

has_var ::= NAME ":" pipe ("=" expression | "postinit")? ("{" accessor* "}")?

accessor ::= ("deleter" | "getter" | "setter") func_signature? (block | ";")
```

- Every field has a type. `has x = 1;` is a syntax error (E0001).
- One `has` declares several fields, separated by commas.
- The statement ends with `;`, except after a property's closing `}`, where
  a `;` is an error (W3013).
- `has` takes an [access tag](access.md): `has:priv token: str;`.
- A field's name follows the rules for names: a reserved word is written
  with a backtick where it is declared (`` has `type: str; ``) and read as
  an ordinary attribute (`x.type`).

## Fields and their defaults

```jac
glob issued: int = 0;

def next_id -> int {
    issued += 1;
    return issued;
}

obj Ticket {
    has title: str,
        id: int = next_id(),
        tags: list[str] = [],
        owner: str | None = None;
}

with entry {
    a = Ticket("first");
    b = Ticket(title="second", tags=["x"]);
    a.tags.append("mine");
    print(a);
    print(b);
    print(Ticket("third", 50), issued);
}
```

```output
Ticket(title='first', id=1, tags=['mine'], owner=None)
Ticket(title='second', id=2, tags=['x'], owner=None)
Ticket(title='third', id=50, tags=[], owner=None) 2
```

- **A default is an expression evaluated at each construction that leaves
  the field out**, not once when the archetype is declared. `tags` above is
  a new list for each ticket, and `next_id()` runs only for the tickets
  that are not given an id.
- **A default is converted to the field's type as an assigned value is**: an
  `int` default for a `float` field, `None` for a `T | None` field. A default
  of another type is E1001.
- **A default sees module-level names, not other fields.** `has b: int = a
  + 1;` where `a` is another field is an unknown name (W2001); compute such
  a field in `postinit`.
- **A field without a default must be given** when the object is
  constructed (E1050).

The generated constructor takes the fields in declaration order, a base's
first. See [Archetypes](archetypes.md) for how arguments bind.

## Static fields

`static has` declares a field of the class: one value, shared by every
instance and by every subclass.

```jac
obj Counter {
    has n: int = 0;

    static has made: int = 0,
               names: list[str] = [];

    def postinit {
        Counter.made += 1;
    }
}

obj Special(Counter) {}

with entry {
    a = Counter();
    b = Special(n=5);
    Counter.names.append("a");
    print(Counter.made, Special.made, a.made, b.names);
    Special.made = 10;
    print(Counter.made, a);
}
```

```output
2 2 2 ['a']
10 Counter(n=0)
```

- A static field needs a value (E2103).
- It is read as `Class.name`, or through an instance (`a.made`). It is
  assigned as `Class.name = v`; assigning through an instance is E1030.
- It is not a constructor argument and is not shown by `repr`.
- Static fields are initialized when the program starts, with the module's
  `glob`s, in the order they are written, and before its `with entry` code. A
  static's value may read a `glob` or a static declared above it; one declared
  below has no value yet (E2200). See [Variables](variables.md#initialization-order).
- A static property (a `static has` with accessors) is not built yet (E5090).

## `init`

An archetype that defines `def init` is constructed with that method's
parameters, and the method sets the fields.

```jac
obj Account {
    has owner: str,
        balance: float = 0.0,
        log: list[str] = [];

    def init(owner: str, opening: float = 0.0) {
        self.owner = owner.title();
        self.balance = opening;
        self.log.append(f"opened with {opening}");
    }
}

with entry {
    a = Account("ann lee", 5.0);
    print(a);
    print(Account(owner="bo").balance);
}
```

```output
Account(owner='Ann Lee', balance=5.0, log=['opened with 5.0'])
0.0
```

- **`init` is the constructor's whole signature.** `Account("ann", 5.0)`
  binds `init`'s parameters, with their defaults, `*args` and keyword-only
  markers as for any function. The fields are no longer arguments.
- **A field with a default has that default before `init` runs.** `init`
  must set every field that has none.
- **`init` returns nothing.** The new object is the result of the call.
- **A written `init` does not run `postinit`.** Call `self.postinit()` from
  it when both are wanted.
- **A subclass without an `init` of its own is constructed by its nearest
  base's written `init`**, with that method's parameters. Each field the
  subclass adds then needs a default (E1231). A subclass that writes `init`
  calls its base's with `super.init(...)`; see [Inheritance](inheritance.md).

The name is `init`. `def __init__` is an error (W3004).

## `postinit`

`def postinit`, declared without parameters, runs at the end of the
generated constructor, after every field is set. Use it to compute what
depends on other fields.

A field declared with the word `postinit` in place of a default is left out
of the constructor's parameters. `postinit` sets it.

```jac
obj Rect {
    has w: float,
        h: float,
        area: float postinit;

    def postinit {
        self.area = self.w * self.h;
    }
}

with entry {
    r = Rect(2.0, 3.0);
    print(r, r.area);
}
```

```output
Rect(w=2.0, h=3.0, area=6.0) 6.0
```

A subclass inherits its base's `postinit`. One that defines its own runs
only its own, and calls the base's with `super.postinit()`. The name is
`postinit`; `def __post_init__` is an error (W3004).

## Properties

A `has` followed by a block of accessors is a property: it stores nothing,
and reading or assigning it calls the accessor.

```jac
obj Temp {
    has _c: float = 0.0;

    has celsius: float {
        getter {
            return self._c;
        }
        setter(v: float) {
            if v < -273.15 {
                raise ValueError("below absolute zero");
            }
            self._c = v;
        }
    }

    has fahrenheit: float {
        getter {
            return self._c * 9 / 5 + 32;
        }
    }
}

with entry {
    t = Temp();
    t.celsius = 100.0;
    print(t.celsius, t.fahrenheit, t);
    try {
        t.celsius = -300.0;
    } except ValueError as e {
        print("refused:", e);
    }
}
```

```output
100.0 212.0 Temp(_c=100.0)
refused: below absolute zero
```

- **`getter`** takes no parameters and returns a value of the property's
  type. `x.name` calls it, each time it is read.
- **`setter(v: T)`** names its parameter. Written without a signature
  (`setter { ... }`), the parameter is named `value`. `x.name = e` calls it,
  and `e` must be of the property's type (E1001).
- **`deleter`** is in the grammar and not built yet (E5090).
- A property with a getter and no setter is read-only: assigning it is
  E1005. One with a setter and no getter cannot be read (E1209).
- A property is not a constructor argument (E1052) and is not shown by
  `repr`. It keeps its state in ordinary fields, such as `_c` above.
- A property has no default (E0080) and at least one accessor (E0081).
- An accessor written with `;` in place of its block is declared here and
  implemented by `impl Temp.celsius.getter { ... }`; see [Impl blocks](impl.md).

`hasattr(x, "celsius")` is true and `getattr(x, "celsius")` calls the getter.

## Fields and inheritance

A subclass has its bases' fields followed by its own. It may declare a
base's field again with the same type to give it another default; the field
stays one field, which the base's methods read too.

```jac
obj Plan {
    has sep: str = "?",
        width: int = 7;

    def show -> str {
        return f"{self.sep}/{self.width}";
    }
}

obj CommaPlan(Plan) {
    has sep: str = ",";
}

with entry {
    print(CommaPlan().show(), CommaPlan(sep=";").show(), CommaPlan());
}
```

```output
,/7 ;/7 CommaPlan(sep=',', width=7)
```

Declaring it again with another type is E1230. Two bases that each declare
a field of the same name are not built yet (E5090).

A property a base declares may be declared again in a subclass, with its own
accessors. The subclass's property is the one its objects have: reading or
assigning it through a variable typed as the base, and in the base's own
methods, calls the subclass's accessors, as Python's properties do. A subclass
that declares it again without a setter has none, and assigning it raises
`AttributeError`, even through the base.

```jac
class Handler {
    has level: int {
        getter {
            return 0;
        }
        setter(v: int) {
            print("Handler sets", v);
        }
    }

    def describe -> str {
        return f"level {self.level}";
    }
}

class Loud(Handler) {
    has _level: int = 30;

    has level: int {
        getter {
            return self._level;
        }
        setter(v: int) {
            self._level = v * 10;
        }
    }
}

class Fixed(Handler) {
    has level: int {
        getter {
            return 50;
        }
    }
}

with entry {
    h: Handler = Loud();
    print(h.describe(), h.level);
    h.level = 4;
    print(h.level);
    f: Handler = Fixed();
    print(f.level);
    try {
        f.level = 1;
    } except AttributeError as e {
        print("AttributeError:", e);
    }
}
```

```output
level 30 30
40
50
AttributeError: property 'level' of 'Fixed' object has no setter
```

A base's field is read where it is stored, by the base's methods and through
the base, so a subclass cannot declare it again as a property (E1230): make it
a property in the base, and give the subclass its own accessors.

## What is rejected

| Code | When |
|---|---|
| E0001 | A field without a type: `has x = 1;` |
| E1001 | A default, or a value assigned to a field or property, of the wrong type |
| E2103 | A `static has` without a value |
| E0077 | A field named as another member of the archetype is |
| E1230 | A subclass declares a base's field again with another type, or as a property |
| E1231 | A subclass adds a field with no default and takes its `init` from a base |
| E1005 | Assigning a property that has no setter |
| E1209 | Reading a property that has no getter |
| E0080 | A property with a default value |
| E0081 | A property with no accessor |
| W3004 | `def __init__` or `def __post_init__` |
| W3043 | `@property` on a method |
| W3013 | A `;` after a property's `}` |
| E5090 | A `deleter`, a static property, one field name in two bases |

```jac
# expect: E2103, E0077
obj Config {
    static has limit: int;

    has name: str = "";

    has name: int = 0;
}
```

```jac
# expect: E1005, E1209, E1052
obj Temp {
    has _c: float = 0.0;

    has kelvin: float {
        getter {
            return self._c + 273.15;
        }
    }

    has reset: float {
        setter(v: float) {
            self._c = v;
        }
    }
}

with entry {
    t = Temp();
    t.kelvin = 5.0;
    print(t.reset);
    u = Temp(kelvin=1.0);
}
```

```jac
# expect: E1230
obj Base {
    has x: int = 1;
}

obj Sub(Base) {
    has x: str = "s";
}
```

```jac
# expect: E1230
class Handler {
    has stream: any = None;
}

class Fixed(Handler) {
    has stream: any {
        getter {
            return "fixed";
        }
    }
}
```

```jac
# expect: E1231
obj Pair {
    has total: int = 0;

    def init(x: int, y: int) {
        self.total = x + y;
    }
}

obj Tagged(Pair) {
    has tag: str;
}
```

```jac
# expect: W3043
obj Circle {
    has r: float = 1.0;

    @property
    def area -> float {
        return 3.14159 * self.r * self.r;
    }
}
```

A project may also select the lint rule `combine-has` (W3002), which reports
a `has` directly after another with the same modifiers; `jac fmt --fix`
joins them. See `jac docs combine-has`.

## Differences from Python and from the reference design

- **In Python a default in a class body is evaluated once and shared; here
  it is evaluated for each object.** `has items: list[int] = [];` is safe.
- **In Python `__init__` is the constructor; here it is `init`**, declared
  without `self` in its parameters (see [Methods](methods.md)), and
  `__init__` is refused (W3004). Likewise `postinit` for `__post_init__`.
- **In Python a property is a decorated method; here it is a `has` with
  accessors**, and `@property` is refused (W3043).
- **In Python an attribute assigned on an instance shadows a class
  attribute; here a static field is assigned only through the class.**
- **`has` declares the fields of a `class` too.** A `class` is Python's plain class, constructed
  as an `obj` is but printed and compared by what it defines (see
  [Archetypes](archetypes.md#classes)).

## See also

- [Archetypes](archetypes.md): construction, `repr` and equality.
- [Methods](methods.md): `def`, `self`, `static def`.
- [Access tags](access.md): `has:priv`, `has:pub`.
- [Reflection](reflection.md): reading a type's fields at compile time.
