---
description: Declaring a function, method, ability or accessor without a body and giving the body in an impl block, in the same module or in an impl annex file.
keywords: impl, impl block, .impl.jac, declaration, forward declaration
grammar: impl_def, impl_target_name
---
# Impl blocks

A function or method may be declared without a body, as its signature and
a `;`. An `impl` block then gives the body, in the same module or in an
annex file beside it. A module written this way reads as an interface: the
declarations and their docstrings in one file, the code in another.

## Syntax

```ebnf
impl_def ::= decorators "impl" impl_target_name ("." impl_target_name)* ("[" type_params "]")? (func_signature | "(" (atomic_chain ("," atomic_chain)*)? ")" | event_sig)? ("{" ((NAME (":" pipe)? ("=" expression)? ",")* "}" | block_rest) | "by" expression ";")

impl_target_name ::=
    NAME
    | "return"
    | "deleter"
    | "setter"
    | "getter"
    | "default"
    | "exit"
    | "entry"
    | "init"
    | "postinit"
```

`impl_target_name` is a name, or one of the listed keywords where it names
part of a declaration (`init`, `getter`). The same names are the path of a
[`sem`](by-and-sem.md) declaration.

The forms jac compiles:

| Declaration | Its impl |
|---|---|
| `def area(unit: str) -> float;` at module level | `impl area(unit: str) -> float { ... }` |
| `def area -> float;` in archetype `Circle` | `impl Circle.area -> float { ... }` |
| `def init(r: float);`, `def postinit;` in `Circle` | `impl Circle.init(r: float) { ... }`, `impl Circle.postinit { ... }` |
| `static def unit -> Circle;` in `Circle` | `impl Circle.unit -> Circle { ... }` |
| `can tally with Room entry;` in walker `Count` | `impl Count.tally with Room entry { ... }` |
| `getter;` or `setter(v: float);` in property `diameter` of `Circle` | `impl Circle.diameter.getter { ... }`, `impl Circle.diameter.setter(v: float) { ... }` |

The other forms the grammar has are refused for now with E5090: an impl of
an enum's members (`impl Color { RED = 1, }`), an impl with a base list
(`impl A(B) { ... }`), a target of more than three names, and an impl with
a `by` body. An archetype cannot be declared without a body (`obj A;` is
E5090), so there is no impl of a whole archetype.

## Declaring and implementing

```jac
obj Stack {
    has items: list[int] = [];

    """Put `x` on top."""
    def push(x: int);

    """Take the top item off."""
    def pop -> int;

    def peek(fallback: int = -1) -> int;
}

def filled(*xs: int) -> Stack;

impl Stack.push(x: int) {
    self.items.append(x);
}

impl Stack.pop -> int {
    return self.items.pop();
}

impl Stack.peek(fallback: int = -1) -> int {
    return self.items[-1] if self.items else fallback;
}

impl filled(*xs: int) -> Stack {
    s = Stack();
    for x in xs {
        s.push(x);
    }
    return s;
}

with entry {
    s = filled(1, 2, 3);
    print(s.pop(), s.peek(), Stack().peek(), s);
}
```

```output
3 2 -1 Stack(items=[1, 2])
```

- **The declaration is the signature.** Callers, the type checker and
  documentation read it. Docstrings, decorators and access tags go on the
  declaration.
- **The impl is the body.** Inside a method's impl, `self` is the instance,
  exactly as in a body written inline.
- **A declaration has exactly one body.** A declaration that no impl
  completes is E2087, an impl for a declaration that already has an inline
  body is E2016, and a second impl is E2017.
- **An impl names a declaration that exists.** Otherwise it is E2009. An
  impl cannot add a method to an archetype.

## What an impl restates

An impl restates its declaration's signature, and the two must agree
exactly. Any difference is an error (W3010) that says what differs:

| The impl must have | W3010 says |
|---|---|
| The same parameter names, in the same order, with the same `*` and `**` | `its parameters are (k), the declaration's (factor)` |
| The same `/` and bare `*` markers | `it places '/' or '*' differently` |
| The same type for each parameter | `its parameter 'unit' has another type` |
| The same default for each parameter | `its parameter 'step' has another default` |
| The same return type | `its return type differs` |
| The same type parameters | `its type parameters differ` |
| For an ability, the same event | `its event differs` |

An impl with no signature at all is accepted only for a declaration with no
parameters and no return type. A property accessor's impl has the
accessor's own signature (`setter(v: float)`), which names the setter's
parameter.

```jac
# expect: W3010 x3
obj Shape {
    def scale(factor: int) -> int;
    def grow(step: int = 1) -> int;
    def name -> str;
}

impl Shape.scale(k: int) -> int {
    return k;
}

impl Shape.grow(step: int = 2) -> int {
    return step;
}

impl Shape.name {
    return "shape";
}
```

## Impl annexes

An annex is a file of impls that belongs to a module. The compiler loads it
with the module, as part of it: an annex sees the module's imports and
declarations with no import of its own, and what an annex declares is
visible in the module. For a module `geo.jac`, the annexes are, in the
order they load:

| Place | Files |
|---|---|
| The `impl/` directory beside the module | `impl/geo.impl.jac`, then `impl/geo.<part>.impl.jac` in sorted order |
| Beside the module | `geo.impl.jac`, then `geo.<part>.impl.jac` |
| The module's own `geo.impl/` directory | `geo.impl/geo.impl.jac`, then `geo.impl/geo.<part>.impl.jac` |

A part name splits a large module's impls across files:
`check.generic.impl.jac` and `check.struct.impl.jac` are both annexes of
`check.jac`. A file belongs to the module its longest dotted prefix names,
so `fs.windows.impl.jac` is the annex of `fs.windows.jac` when that module
exists, and a part of `fs.jac` when it does not.

The module:

<!-- example: not checked: one program in two files, geo.jac and impl/geo.impl.jac -->
```jac
import math;

obj Circle {
    has r: float = 1.0;

    def area -> float;
    def grow(k: float = 2.0) -> Circle;

    has diameter: float {
        getter;
        setter(v: float);
    }
}

def unit -> Circle;

with entry {
    c = unit().grow();
    c.diameter = 6.0;
    print(c, round(c.area(), 2));
}
```

Its annex, `impl/geo.impl.jac`, which uses the module's `import math`:

<!-- example: not checked: the annex of the module above -->
```jac
impl Circle.area -> float {
    return math.pi * self.r ** 2;
}

impl Circle.grow(k: float = 2.0) -> Circle {
    return Circle(r=self.r * k);
}

impl Circle.diameter.getter {
    return self.r * 2;
}

impl Circle.diameter.setter(v: float) {
    self.r = v / 2;
}

impl unit -> Circle {
    return Circle();
}
```

```sh
jac build geo.jac -o geo && ./geo
```

```text
Circle(r=3.0) 28.27
```

Only the module is named on the command line or in an `import`; an annex is
never imported.

## Lint rules for impls

Two rules of the `clean` group, which a project selects unless its
`jac.toml`'s `[check.lint]` names other rules, make the split a policy.

| Rule | Code | Reports |
|---|---|---|
| `separate-impls` | W3055 | A body written inline that an `impl` could hold |
| `impls-in-annex` | W3056 | An `impl` in its module's own file, or an annex beside its module rather than in `impl/` |

`jac fmt --fix` applies both: it moves each body or impl into
`impl/<module>.impl.jac` with the comments inside it. In every project it
writes the declaration's signature into an impl that restates it with
another type, default or return type (W3010), wherever the impl is; it
leaves an impl whose parameter names differ from its declaration's for its
author.
See `jac docs separate-impls`.

## What is rejected

| Code | When |
|---|---|
| W3010 | An impl whose signature differs from its declaration's |
| E2009 | An impl that matches no declaration |
| E2016 | An impl of a declaration that has an inline body |
| E2017 | A second impl of one declaration |
| E2087 | A declaration with no body and no impl |
| E0047 | An impl with neither a `{ ... }` body nor `by` |
| E1496 | A decorator before an impl; write it before the declaration |
| E5090 | An impl of an enum, an impl with bases, a `by` body, a target of more than three names |

```jac
# expect: E2009, E2016, E2017
def whole -> int {
    return 1;
}

impl whole -> int {
    return 2;
}

def half -> int;

impl half -> int {
    return 1;
}

impl half -> int {
    return 2;
}

impl missing -> int {
    return 0;
}
```

```jac
# expect: E2087 x2
def never(x: int) -> int;

obj Shape {
    def area -> float;
}

with entry {
    print(never(1), Shape().area());
}
```

## Differences from Python and from the reference design

- **Python has no counterpart.** A Python stub file (`.pyi`) declares types
  for code written elsewhere, but is not part of the program; here the
  declaration and its impl are one definition.
- **In the reference design an impl may leave its signature out, and one whose types
  disagree with the declaration's is accepted; here it must match exactly**
  (W3010).
- **In the reference design `impl` also fills in archetypes and enums declared without a
  body; jac refuses those forms for now** (E5090).

## See also

- [Methods](methods.md) and [Fields](fields.md): what is declared.
- [Abilities](abilities.md): the event clause an ability's impl restates.
- [By and sem](by-and-sem.md): `sem` targets use the same dotted names.
