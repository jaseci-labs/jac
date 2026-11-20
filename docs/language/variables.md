---
description: Binding names: assignment and its targets, annotations, augmented assignment, unpacking, module globals (glob), scope rules, the assignment expression :=, and del.
keywords: variable, assignment, =, glob, global, nonlocal, scope, :=, walrus, del
grammar: assignment, value_or_yield, global_vars, global_var, walrus, delete_stmt
---
# Variables

A variable is a name bound to a value. A local is created by its first assignment in a function or
in module code; a module global is declared with `glob`. There is no declaration keyword for
locals and no `global` or `nonlocal` statement.

## Assignment

```ebnf
assignment ::= (":" ownership_prefix pipe)? ("=" value_or_yield ("=" value_or_yield)* | ("+=" | "-=" | "*=" | "/=" | "//=" | "%=" | "**=" | "@=" | "&=" | "|=" | "^=" | "<<=" | ">>=" | "+%=" | "-%=" | "*%=" | "+|=" | "-|=" | "*|=") value_or_yield)? ";"?

value_or_yield ::= yield_expr | expression
```

An assignment statement is an expression (the target) followed by `assignment`.

| Form | Meaning |
|---|---|
| `x = e;` | Bind `x` to the value of `e` |
| `x: T = e;` | The same, and declare that `x` has type `T` |
| `x: T;` | Declare `x`'s type without binding it |
| `a = b = e;` | Evaluate `e` once and bind every target to that one value |
| `(a, b) = e;` | Unpack: bind `a` and `b` to the two items of `e` |
| `obj.field = e;` | Set a field |
| `xs[i] = e;`, `d[k] = e;` | Set an item of a list or a dict |
| `x += e;` | Augmented assignment: `x = x + e` |

A target is a name, a field, an item, or a parenthesized tuple of targets. Anything else is E0142.

Assignment binds a name to a value; it never copies the value. After `ys = xs`, both names refer to
the same list.

```jac
obj Point {
    has x: int = 0;
}

with entry {
    count = 1;
    ratio: float = 2;
    xs = ys = [0];
    ys.append(1);
    p = Point();
    p.x = 4;
    xs[0] = 7;
    print(count, ratio, xs, ys, p.x);
}
```

```output
1 2.0 [7, 1] [7, 1] 4
```

### A local has one type

A local's type is the one it is declared with (`x: T = ...`), or else the type of its first
binding. Every later binding must give a value of that type, or one that converts to it as a value
does wherever that type is wanted (an `int` where a `float` is declared). Anything else is an
error: E1452, or E1001 against a declaration. This holds wherever the binding is: a later
assignment, a branch, a loop's target, an unpacking, `:=`, `with ... as`, or after a `del`.

- A local that holds either of two types is declared as their union: `v: int | str = 1`.
- One that holds an `int` and a `float` is declared `x: float`.
- `x = None` alone gives `x` no type (W1051). Declare it: `x: Point | None = None`.
- An empty `{}` gives no element types (W1051). Declare them: `d: dict[str, int] = {}`.
- A second annotation of a different type is E1196.

Unions, narrowing and inference are covered in [Types](types.md).

```jac
# expect: E1452 x2, E1001, W1051
def branch(c: bool) {
    x = 1;
    if c {
        x = "a";
    }
    v = 1;
    v = 2.5;
    n: int = "s";
    z = None;
    print(x, v, n, z);
}
```

### Unpacking

A parenthesized tuple of targets takes the items of a value, one each. Targets nest.

- The parentheses are required. Python's bare `a, b = b, a` is written `(a, b) = (b, a);`.
- A tuple's length is checked at compile time (E1020).
- A list, an `Iterable[T]`, an object whose class defines `__iter__`, and an `any` unpack when the
  statement runs: too many items raise `ValueError: too many values to unpack`, too few
  `ValueError: not enough values to unpack (expected 3, got 2)`. An `Iterable[str]` holding a
  `str` unpacks its characters.
- A value typed `str`, `dict`, `set`, `range` or `Iterator[T]` (a generator among them) does not
  unpack (E1020). Make a tuple or a list of it first: `(a, b) = tuple(g);`.
- A `for` loop's target unpacks the same way: `for (k, v) in d.items() { ... }`.
- Each target is assigned as it would be on its own: an item is converted to the type its
  target holds (an `int` into a `float` field), a property's setter runs, and an item target
  calls the object's `__setitem__`.

```jac
with entry {
    (a, b) = (1, "two");
    (a, b) = (a + 1, b.upper());
    (m, (n, o)) = (1, (2, 3));
    print(a, b, m, n, o);

    xs = [1, 2, 3];
    (xs[0], xs[2]) = (xs[2], xs[0]);
    print(xs);

    try {
        (c, d) = xs;
    } except ValueError as e {
        print(e);
    }
    letters: Iterable[str] = "ab";
    (c1, c2) = letters;
    print(c1, c2);
    try {
        (p, q, r) = letters;
    } except ValueError as e {
        print(e);
    }
}
```

```output
2 TWO 1 2 3
[3, 2, 1]
too many values to unpack (expected 2, got 3)
a b
not enough values to unpack (expected 3, got 2)
```

```jac
obj Pos {
    has x: float = 0.0,
        tag: any = None,
        _n: int = 0;

    has n: int {
        getter {
            return self._n;
        }
        setter(v: int) {
            self._n = v * 2;
        }
    }
}

obj Grid {
    has cells: dict[str, int] = {};

    def __setitem__(k: str, v: int) {
        self.cells[k.upper()] = v;
    }
}

with entry {
    p = Pos();
    g = Grid();
    d: dict[str, int] = {};
    (p.x, p.tag, p.n, d["k"], g["a"]) = (3, 7, 5, 1, 2);
    print(p.x, p.tag, p.n, d, g.cells);
}
```

```output
3.0 7 10 {'k': 1} {'A': 2}
```

```jac
# expect: E1020 x2
with entry {
    (a, b) = (1, 2, 3);
    (c, d) = "hi";
}
```

```jac
# expect: E0002
with entry {
    c, d = 1, 2;
}
```

### Augmented assignment

`x op= e` computes `x op e` and assigns the result to `x`: `n += 1`. What each operator does to a
list, a tuple, an object or an item, and in what order the target is evaluated, is in
[Augmented assignment](variables-augmented.md) (`jac docs +=`).

## Globals: `glob`

```ebnf
global_vars ::= "glob" access_tag global_var ("," global_var)* ";"

global_var ::= NAME (":" ownership_prefix pipe)? ("=" expression ("=" expression)*)?
```

`glob` declares module globals, at the top level of a module. Each has a type, a value or both
(E2118 with neither). A global declared with only a type has no value until something assigns it;
reading it first raises `NameError`.

- One `glob` may declare several globals, separated by commas.
- `glob a = b = 7;` declares `a` and `b` with the same value.
- A global has one type, like a local: its declared type, else its initial value's. Assigning
  another type is E1001.
- A name is declared once in a module (E2036).
- An access tag may follow the keyword (`glob:pub limit = 10;`); see [Modules](modules.md).
- Another module reaches a global by importing it or as `module.name`; it is one variable, shared.

```jac
glob limit: int = 10,
     label = "n";
glob total: int;
glob low = high = 7;

def bump {
    limit += 1;
}

with entry {
    bump();
    total = limit * 2;
    print(limit, label, total, low, high);
}
```

```output
11 n 22 7 7
```

### Initialization order

A module's globals and the static fields of its archetypes (see [Fields](fields.md)) are given
their values when the program starts, in the order they are written in the module, before its
`with entry` code runs. An initializer may call functions and construct objects, and whatever it
reads must already have its value: a global or static declared above it, or one that only a
function reads when it is called later.

```jac
class Style {
    static has pattern: str = "%(message)s";

    def width -> int {
        return len(Style.pattern);
    }
}

glob width: int = Style().width();

with entry {
    print(width);
}
```

```output
11
```

An initializer that reads a global or a static declared below it is refused (E2200): that
value is not there yet.

```jac
# expect: E2200
glob first: int = second + 1;
glob second: int = 2;
```

## Scope

Three kinds of scope hold names: a module, a function, and a comprehension.

| A name assigned in... | is... |
|---|---|
| a function, when the module has a global of that name | **that global**. The assignment rebinds it. |
| a nested function, when an enclosing function has a local of that name | **that enclosing local**, shared with the enclosing function |
| a function, with an annotation (`count: str = "a"`) | a new local of that function, even where a global or an enclosing local has the name; those keep their values |
| a function, otherwise | a local of that function, visible in all of it |
| a `with entry` block, when the module has a global of that name | that global |
| a `with entry` block, otherwise | a local of the module's code: later entry blocks see it, functions do not |
| a comprehension's `for` | a variable of the comprehension only |

- **Blocks do not make scopes.** A name first assigned inside an `if`, a loop or a `try` is a local
  of the whole function and is still bound after the block.
- **Reading looks outward:** the function's locals and parameters, then those of enclosing
  functions, then the module's globals and imports, then the builtins. A name found nowhere is
  W2001.
- **A nested function shares its enclosing function's variables**, it does not copy them. It sees
  later assignments, and its own assignments are seen outside. See [Functions](functions.md).
- **Parameters are locals.** Assigning one rebinds it inside the function only; changing the object
  it refers to (`xs.append(1)`) is seen by the caller.
- **An `except ... as e` name belongs to its clause.** Two clauses may use the same name for two
  classes, and a name the function already uses as a local is refused there (E1453).

```jac
glob calls = 0;

def counter -> Callable[[], int] {
    count = 0;
    def step -> int {
        count += 1;
        calls += 1;
        return count;
    }
    return step;
}

with entry {
    c = counter();
    d = counter();
    print(c(), c(), d(), calls);

    for i in range(3) {
        last = i * 2;
    }
    print(i, last);
    print([j * j for j in range(3)]);
}
```

```output
1 2 1 3
2 4
[0, 1, 4]
```

- **A name is one variable in a function.** An annotation makes a local of a name the function
  has not used yet. After the function has read or assigned the global of that name, or the
  enclosing function's local, the annotation is refused (E1454): the name would be the outer
  variable above it and the local below.

```jac
# expect: W2001 x2, E1454 x2
glob count = 0;

def tally {
    count = 4;
    count: int = 9;
    step = 1;
    def bump {
        step += 1;
        step: int = 5;
    }
    bump();
}

with entry {
    tally();
    print([j for j in range(2)]);
    print(j);
    print(never_assigned);
}
```

## Assignment expressions: `:=`

```ebnf
walrus ::= by_expr (":=" by_expr)?
```

`name := e` evaluates `e`, binds `name` to it and gives the value as the expression's result. It
binds in the enclosing function (not in a comprehension that contains it), under the same one-type
rule as any assignment. The target is a name only (E0020). Where the result is used inside a
larger expression, write parentheses around it: `:=` binds more loosely than the arithmetic,
comparison and logical operators (see [Operators](operators.md)).

```jac
with entry {
    data = [3, 8, 1];
    if (n := len(data)) > 2 {
        print("long", n);
    }
    print([y for x in data if (y := x * 2) > 4]);
    while (k := len(data)) > 1 {
        data.pop();
    }
    print(k, data);
}
```

```output
long 3
[6, 16]
1 [3]
```

```jac
# expect: E0020
with entry {
    xs = [1];
    if (xs[0] := 2) {
        print(xs);
    }
}
```

## `del`

```ebnf
delete_stmt ::= "del" expression ("," expression)* ";"
```

| Statement | Effect |
|---|---|
| `del x;` | Unbind the local `x`. Reading it before it is assigned again raises `UnboundLocalError`. |
| `del d[k];` | Remove a key from a dict (`KeyError` when absent) |
| `del xs[i];`, `del xs[a:b];`, `del xs[::2];` | Remove an item, or the items of a slice, from a list |
| `del obj.field;` | Remove a field's value; reading it then raises `AttributeError` |

An item of an object is deleted with its class's `__delitem__`. Through an `any`, `del v[k]`
does what the value it holds does when the program runs: a list removes an item or a slice, a
dict a key, and a tuple raises `TypeError: 'tuple' object doesn't support item deletion`.

`del` of anything else is E0083: a literal, a call's result, a module global. A name deleted and
assigned again keeps its type.

```jac
with entry {
    x = 1;
    del x;
    try {
        print(x);
    } except UnboundLocalError {
        print("x is unbound");
    }
    x = 2;

    d = {"a": 1, "b": 2};
    xs = [0, 1, 2, 3, 4];
    del d["a"], xs[0];
    del xs[::2];
    print(x, d, xs);
}
```

```output
x is unbound
2 {'b': 2} [2, 4]
```

```jac
# expect: E0083 x2
glob g = 1;

with entry {
    del g;
    del 3;
}
```

## Differences from Python

- **No `global` or `nonlocal`.** Assigning a global's name in a function assigns the global, and
  assigning an enclosing function's local in a nested function assigns that local. To have a
  local of a global's name instead, declare it with its type: `count: str = "a";`.
- **A local has one type** for its whole life; `x = 1; x = "a"` is an error.
- **Unpacking needs parentheses**, on the target and on a tuple value: `(a, b) = (b, a);`.
- **Module globals are declared** with `glob`. An assignment at a module's top level is not a
  statement the grammar has.
- An `except ... as` name does not replace a local of the same name; it is refused.
- `int`, `str`, `list` and the other type words cannot be assigned (they are keywords).
