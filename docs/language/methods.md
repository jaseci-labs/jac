---
description: Methods of an archetype (def, self, bound methods, static def, class def, override, abst, super), and how def differs from can.
keywords: method, methods, self, Self, static def, class def, cls, override, abst, abstract method, super, static, bound method
grammar: ability
---
# Methods

A `def` inside an archetype is a method: a function called on an instance,
which it reaches as `self`. This page covers methods and the modifiers they
take; the special method names that give a class its operators are on
[Special methods](methods-special.md).

## Syntax

```ebnf
ability ::= decorators "comptime"? "override"? "class"? "static"? "async"? ("def" | "can") access_tag (NAME | "init" | "postinit")? ("[" type_params "]")? (event_sig | func_signature) where_clause? (block | ("by" expression | "abst")? ";")
```

The same production is a function at module level (see
[Functions](functions.md)) and, with `can`, an ability (see
[Abilities](abilities.md)). In an archetype's body:

| Form | Is |
|---|---|
| `def name(params) -> T { ... }` | A method |
| `def init(params) { ... }`, `def postinit { ... }` | The constructor's hooks; see [Fields](fields.md) |
| `static def name(params) -> T { ... }` | A method of the class, with no `self` |
| `class def name(params) -> T { ... }` | A method of the class, given the class as `cls` |
| `override def ...` | A method that replaces a base's |
| `def name(params) -> T abst;` | A method with no body, for subclasses to give |
| `def name(params) -> T;` | A declaration whose body an `impl` gives; see [Impl blocks](impl.md) |
| `can name with T entry { ... }` | An ability; see [Abilities](abilities.md) |

Modifiers come in one order: `comptime override static|class async def`.
Another order is an error (E0158 for `async` before `static` or `override`).
A method with no parameters is written without parentheses: `def area ->
float`; `def area() -> float` is W3005.

## `self`

`self` is the object the method was called on. It is not written in the
parameter list.

```jac
obj Counter {
    has n: int = 0;

    def bump(step: int = 1) -> Self {
        self.n += step;
        return self;
    }

    def plus(other: Counter) -> Counter {
        return Counter(n=self.n + other.n);
    }
}

with entry {
    c = Counter().bump().bump(5);
    print(c, c.plus(c));
    bound = c.bump;
    print(bound(4).n, Counter.bump(c, 10).n, Counter.plus(c, c).n);
}
```

```output
Counter(n=6) Counter(n=12)
10 20 40
```

- **Fields and other methods are reached through `self`**: `self.n`,
  `self.bump()`. A bare `n` in a method is not the field (W2001).
- **`Self` as a type is the class the method belongs to**, and in a subclass
  that inherits the method, the subclass. Use it for methods that return
  `self` or a new instance of the same class.
- **`x.m` without a call is a bound method**: a function value that
  remembers the object `x` gave when it was read. `x` is evaluated once, at
  the read, and assigning `x` again later does not change the bound method.
  A builtin type's methods bind the same way (`up = "abc".upper;`).
- **`Class.m` is the method as a function** whose first argument is the
  instance: `Counter.bump(c, 10)`. A call through the class runs that
  class's own method, even when the instance's class overrides it. A class
  held in an `any` works the same way (`k: any = Counter; k.bump(c, 1)`).
- **A field that holds a function is called as `x.f(args)`**, and the
  object is not passed to it: the field's type is a `Callable` (or `any`),
  not a method.
- **`self` may be written as the first parameter** to say how the method
  takes its receiver, for example `def joined(self: &Builder) -> str` for a
  method that only borrows it. See [Ownership](ownership.md). Callers still
  write `b.joined()`.

```jac
obj Counter {
    has n: int = 0;

    def bump(step: int) -> int {
        self.n += step;
        return self.n;
    }
}

obj Hook {
    has on: Callable[[int], int];
}

def doubled(x: int) -> int {
    return 2 * x;
}

with entry {
    fresh = [Counter(n=10)];
    fb = fresh.pop().bump;
    print(fb(1), fb(1), len(fresh));
    c = Counter(n=50);
    kb = c.bump;
    c = Counter();
    print(kb(1), c.n);
    up = "abc".upper;
    k: any = Counter;
    print(up(), k.bump(c, 5), Hook(on=doubled).on(21));
}
```

```output
11 12 0
51 0
ABC 5 42
```

`fresh.pop()` ran once, when `fb` was made; `kb` still bumps the first
`Counter` after `c` names another.

## `static def` and `class def`

A `static def` belongs to the class and has no `self`. A `class def` also
belongs to the class, and its body has `cls`, the class.

```jac
obj Temp {
    has c: float = 0.0;

    static def from_f(f: float) -> Temp {
        return Temp(c=(f - 32) * 5 / 9);
    }

    class def zero -> Temp {
        return cls();
    }
}

with entry {
    t = Temp.from_f(212.0);
    print(t, Temp.zero(), t.from_f(32.0));
}
```

```output
Temp(c=100.0) Temp(c=0.0) Temp(c=0.0)
```

Both are called on the class (`Temp.from_f(...)`) or on an instance. Using
`self` in either is E2111. Python's `@staticmethod` is an error that names
the Jac spelling (W3001), and `@classmethod` is refused as any decorator
that is not a compile-time function is (E1490).

`static` and `class` apply only to methods: a `static def` at module level
is a syntax error (E0005).

## `override`

A subclass replaces a base's method by defining one with the same name.
`override` before `def` marks it as doing so. A call on a variable typed as
the base runs the method of the object's own class.

```jac
obj Animal {
    has name: str;

    def speak -> str {
        return "...";
    }

    def intro -> str {
        return f"{self.name} says {self.speak()}";
    }
}

obj Dog(Animal) {
    override def speak -> str {
        return "woof";
    }
}

with entry {
    pets: list[Animal] = [Animal(name="it"), Dog(name="rex")];
    for p in pets {
        print(p.intro());
    }
}
```

```output
it says ...
rex says woof
```

An override keeps the parameters and return type of the method it replaces,
and may add parameters after them that have defaults. The word `override` is for the reader: the compiler accepts an overriding
method without it. See [Inheritance](inheritance.md) for dispatch and for
methods found through several bases.

## `abst`

`abst;` in place of a body declares a method that the class does not
implement.

- **In an [interface](interfaces.md)** (an `obj` that has only abstract
  methods), every conforming class must define the method with the same
  signature. The compiler checks it (E1281, E1282), and an interface has no
  instances (E1280).
- **In any other archetype**, `abst` marks a method whose body subclasses
  are meant to supply. The compiler does not check that they do, so give
  the method a body in every class you construct, or declare the
  requirement as an interface.

```jac
obj Shape {
    has name: str = "shape";

    def area -> float abst;

    def describe -> str {
        return f"{self.name} of area {self.area()}";
    }
}

obj Square(Shape) {
    has side: float = 1.0;

    override def area -> float {
        return self.side * self.side;
    }
}

with entry {
    print(Square(name="sq", side=3.0).describe());
}
```

```output
sq of area 9.0
```

## `super`

`super.m(args)` in a method calls `m` as the next class after this one
defines it: the base's version of a method this class overrides.

```jac
obj Base {
    has name: str;

    def init(name: str) {
        self.name = name;
    }

    def who -> str {
        return "base " + self.name;
    }
}

obj Leaf(Base) {
    has level: int = 0;

    def init(name: str, level: int) {
        super.init(name=name);
        self.level = level;
    }

    override def who -> str {
        return f"leaf {self.level} > " + super.who();
    }
}

with entry {
    print(Leaf("x", 2).who());
}
```

```output
leaf 2 > base x
```

`super` is followed by a method call. Python's `super().m()` and a field
read `super.x` are refused (E5090), `super` outside a method or in a static
method is E2127, and a method no base has is E1030. With several bases,
"next" follows the method resolution order; see
[Inheritance](inheritance.md).

## Special methods

A method with one of Python's special names (`__add__`, `__eq__`,
`__getitem__`, `__iter__`, ...) is what an operator or a builtin calls for
the class's instances. They are described, with what each is asked for, on
[Special methods](methods-special.md) (`jac docs dunder`).

## `def` or `can`

`def` declares a method: code that runs when it is called. `can` declares
an ability: code that runs when a walker arrives at or leaves a node, named
by an event clause (`can greet with Room entry`). An ability is never
called by name. A `can` without `with` is an error (E0034):

```jac
# expect: E0034
obj Greeter {
    can hello -> str {
        return "hello";
    }
}
```

Abilities, `here`, `visitor` and the order they run in are described in
[Abilities](abilities.md) (`jac docs abilities`).

## What is rejected

| Code | When |
|---|---|
| W3005 | Empty parentheses: `def area() -> float` |
| W3004 | `def __init__`, `def __post_init__` |
| W3001 | `@staticmethod` |
| W3043 | `@property` |
| E1490 | `@classmethod`, or any decorator that is not a compile-time function |
| E0158 | Modifiers out of order: `async static def` |
| E2111 | `self` in a `static def` or `class def` |
| E2127 | `super` outside a method, or in a static method |
| E1030 | A method the class or its bases do not have; `super.m` that no base has |
| E1110, E1010 | An operator the class has no special method for |
| E1053, E1021, E1040, E1023 | `len`, iteration, indexing or a call of an object whose class has no method for it |
| E0034 | `can` without an event clause |
| E2087 | A method declared with `;` that no `impl` gives a body |
| E5090 | `comptime def` in an archetype; `super()` or `super.field`; a method with type parameters taken as a value |

```jac
# expect: W3004, W3001
obj Account {
    has owner: str = "";

    def __init__(owner: str) {
        self.owner = owner;
    }

    @staticmethod
    def make -> Account {
        return Account();
    }
}
```

```jac
# expect: W3005, E0158
obj Job {
    def name() -> str {
        return "job";
    }

    async static def make -> Job {
        return Job();
    }
}
```

```jac
# expect: E2111, E2127, E1110
obj Money {
    has cents: int = 0;

    static def zero -> int {
        return self.cents;
    }
}

def total -> int {
    return super.total();
}

with entry {
    print(Money() + Money());
}
```

## Differences from Python and from the reference design

- **In Python `self` is the first parameter of every method; here it is
  implicit.** `def area -> float`, not `def area(self) -> float`.
- **In Python `def f():` takes empty parentheses; here they are an error**
  (W3005), on methods, functions and lambdas alike.
- **In Python the constructor is `__init__`; here it is `init`.** The other
  special methods keep Python's names.
- **In Python `super().m()` is a call; here `super` is a word followed by
  the method:** `super.m()`.
- **In Python a name starting with two underscores is mangled inside a
  class; here it is not.**
- **In Python `@staticmethod`, `@classmethod` and `@property` are
  decorators; here they are `static def`, `class def` and a `has` with a
  getter.** A decorator is a compile-time function; see
  [Decorators](decorators.md).
- **In the reference design `def f()` and `def __init__` are accepted; here each has one
  spelling.**

## See also

- [Special methods](methods-special.md): operators, subscripts, iteration
  and the other special names.
- [Fields](fields.md): `init`, `postinit` and properties.
- [Inheritance](inheritance.md): which method a call runs.
- [Interfaces](interfaces.md): abstract methods that are checked.
- [Generics](generics.md): methods with type parameters.
- [Impl blocks](impl.md): a method's body written apart from its declaration.
