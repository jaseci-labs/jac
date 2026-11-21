---
description: Functions: def and its signature, parameters (defaults, *args, **kwargs, positional-only and keyword-only), return types and return, calls and how arguments bind, lambdas, closures, recursion and return tail, and function values.
keywords: def, function, functions, return, parameter, parameters, argument, arguments, keyword argument, default argument, *args, **kwargs, positional-only, keyword-only, lambda, closure, nested function, recursion, return tail, tail call, call
grammar: func_signature, func_params, param, call_args, call_arg, kw_arg, lambda_expr, return_stmt
---
# Functions

A function is declared with `def`, at a module's top level, inside another function, or inside an
archetype (where it is a method; see [Methods](methods.md)). A function is also a value: it can be
passed, stored and returned, and `lambda` writes one inline.

## Declaring a function

```ebnf
func_signature ::= ("(" func_params ")")? ("->" pipe)?

func_params ::= (("*" | "/" | param) ("," ("*" | "/" | param))* ","?)?

param ::= "comptime"? ("*" | "**")? ("self" | NAME) (":" ownership_prefix pipe)? ("=" expression)?

return_stmt ::= "return" "tail"? expression? ";"
```

A declaration is `def`, the name, the parameters in parentheses, `->` and the return type, and the
body in braces. The full rule, with its modifiers, is in [Abilities](abilities.md) and
[Methods](methods.md).

- **No parameters, no parentheses.** `def greet { ... }` and `def answer -> int { ... }`. Empty
  parentheses are an error (W3005).
- **Every parameter has a type**: `def area(w: int, h: int)`.
- **No `->`, no value.** A function without a return type returns `None`, and a value it returns
  is an error (E1003: declare `-> T`). `-> None` may be written; the lint rule
  `unnecessary-none-return` (W3037) flags it where a project selects it.
- **A function that declares a return type returns a value on every path** that reaches its end
  (E1004). A path that ends in `raise`, or a `forever` loop left only by `return`, needs none. A
  return type that includes `None` (`-> int | None`) lets the function end without a `return`, and
  it then returns `None`.
- **`return e;`** gives the value of `e`, which must fit the return type (E1002). **`return;`**
  gives `None`: it ends a function that returns nothing, or one whose return type includes `None`,
  and is an error in any other (E1002).
- **A value is returned with `return`, never by being last.** `def ten -> int { 5 + 5 }` is an
  error (E0159): write `return 5 + 5;`. In a function that returns nothing, a last expression
  without its `;` is E2084.
- A function's docstring is a string written before the `def`; see
  [Docstrings](modules-docstrings.md).

```jac
def area(w: int, h: int = 1) -> int {
    return w * h;
}

def greet {
    print("hello");
}

def find(xs: list[int], target: int) -> int | None {
    for x in xs {
        if x == target {
            return x;
        }
    }
}

with entry {
    greet();
    print(area(3, 4), area(5), area(h=2, w=3));
    print(find([1, 2], 2), find([1, 2], 5), greet());
}
```

```output
hello
12 5 6
hello
2 None None
```

## Parameters

| Form | Kind |
|---|---|
| `x: T` | Positional or keyword: given by position or as `x=...` |
| `x: T = default` | The same, and may be left out |
| `*rest: T` | Takes the extra positional arguments, as a `list[T]` |
| `**opts: T` | Takes the extra keyword arguments, as a `dict[str, T]` |
| `/` | The parameters before it are positional-only |
| `*` | The parameters after it are keyword-only |

The kinds come in this order: positional-only, `/`, positional-or-keyword, `*rest` or a bare `*`,
keyword-only, `**opts`.

```jac
def f(a: int, b: int = 2, /, c: int = 3, *rest: int, key: str = "k", **kw: int) -> str {
    return f"a={a} b={b} c={c} rest={rest} key={key} kw={kw}";
}

def scaled(x: int, *, factor: int = 3) -> int {
    return x * factor;
}

with entry {
    print(f(1));
    print(f(1, 20, 30, 40, 50, key="z", extra=9));
    print(f(1, c=7), scaled(2), scaled(2, factor=5));
}
```

```output
a=1 b=2 c=3 rest=[] key=k kw={}
a=1 b=20 c=30 rest=[40, 50] key=z kw={'extra': 9}
a=1 b=2 c=7 rest=[] key=k kw={} 6 10
```

### Defaults are evaluated at each call

A default is an expression evaluated each time a call leaves its parameter out, in the function's
own module, when the call is made. A default of `[]` is a new list for each call, a default that
reads a global reads its value at that moment, and a default may be any call (`step: int =
inc(0)`). A call missing a required argument fails before any default is evaluated.

```jac
glob base: int = 1;

def gather(x: int, into: list[int] = [], b: int = base) -> list[int] {
    into.append(x + b);
    return into;
}

with entry {
    print(gather(1), gather(2));
    base = 10;
    print(gather(3), gather(4, [0], 0));
}
```

```output
[2] [3]
[13] [0, 4]
```

In Python a default is evaluated once, when the `def` runs, so a list default is shared between
calls. Here it is not. The same holds for a lambda: a default that reads a variable the lambda
captures reads it as it is at the call.

## Calls

```ebnf
call_args ::= (call_arg ("," call_arg)* ","?)?

call_arg ::= kw_arg | ("**" | "*") expression | expression compr_clauses?

kw_arg ::= any_word "=" expression
```

A call `f(args)` binds its arguments to the parameters, then runs the body.

- **Positional arguments** fill the positional parameters in order; extra ones go to `*rest`.
- **Keyword arguments** `name=value` fill the parameter of that name; unknown names go to
  `**opts`. The name is any word, reserved or not: `f(type="x")` fills a parameter declared
  `` `type ``. See [Lexical structure](lexical-structure.md#the-backtick-escape).
- **`*xs`** spreads the items of an iterable as positional arguments, and **`**d`** the entries of
  a dict as keyword arguments. A spread never changes the list or dict it spreads, and
  **`**opts` is a new dict at each call**: what a call adds to it is gone at the next.
- **Arguments are evaluated before the body runs, left to right as they are written**, keyword
  arguments among them, whatever order the parameters come in: `three(c=next(it), a=next(it),
  b=0)` gives `c` the first item. `print("x", xs.sort(), xs)` prints the list already sorted.
- A generator expression that is the only argument needs no parentheses of its own:
  `sum(x * x for x in xs)`.
- **Arguments are passed by reference.** Assigning a parameter rebinds it in the function only;
  changing the object it refers to (`xs.append(1)`) is seen by the caller.

Binding is checked at compile time; the codes are in the table below.

```jac
def three(a: int, b: int, c: int) -> int {
    return a * 100 + b * 10 + c;
}

def describe(head: str, *rest: int, **opts: str) -> str {
    return f"{head} {rest} {sorted(opts.items())}";
}

def grow(xs: list[int], n: int) {
    xs.append(n);
    n = 99;
}

def tick(log: list[int], n: int) -> int {
    log.append(n);
    return n;
}

with entry {
    args = [4, 5, 6];
    kw = {"b": 2, "c": 3};
    print(three(*args), three(1, *[2, 3]), three(1, **kw), three(c=9, b=8, a=7));
    print(describe("h", 1, 2, x="1", y="2"));
    xs = [1];
    k = 5;
    grow(xs, k);
    print(xs, k);
    order: list[int] = [];
    print(three(tick(order, 1), c=tick(order, 3), b=tick(order, 2)), order);
}
```

```output
456 123 123 789
h [1, 2] [('x', '1'), ('y', '2')]
[1, 5] 5
123 [1, 3, 2]
```

## Lambdas

```ebnf
lambda_expr ::= "lambda" ("(" func_params ")")? ("->" expression)? ("{" expression "}" | block)
```

`lambda` makes a function value in an expression. Its parameters are written as a `def`'s, in
parentheses and typed, and its body is a block.

- **A body of one expression is the lambda's value**: `lambda (s: str) -> str { s.upper() }`
  returns the upper-cased string. The expression stands alone, with no `;` after it. This is the
  one body whose value needs no `return`: a longer body returns with `return` (E1004 otherwise),
  and its last expression without one is E0159.
- **With a `;`, the one expression is a statement**, and the lambda gives nothing, as a body that
  ends without a `return` does: `lambda (m: str) { print(m); }` prints and gives `None`. The
  statement is one that does something: a call (a pipe too), an `await`, a `spawn`, a `yield`, a
  walrus, a connect or a disconnect, a `flow` or a `wait`. One that only computes a value, such as
  `lambda (x: int) { x * 3; }`, is E0160: the value would be dropped.
- The return type may be left out: `lambda (x: int) { x * 3 }`. The lambda then takes its result
  type from where it is given, and where that type admits `None` (a parameter typed
  `Callable[[], Scope | None]`) a longer body may end without a `return`, and gives `None`.
- A lambda with no parameters has no parentheses (W3005 for `lambda ()`): `lambda { print("hi") }`,
  `lambda -> int { return 7; }`.
- A lambda takes every parameter kind a `def` does, defaults included.

```jac
with entry {
    add = lambda (a: int, b: int = 10) -> int { return a + b; };
    shout = lambda (s: str) -> str { s.upper() + "!" };
    triple = lambda (x: int) { x * 3 };
    seven = lambda -> int { return 7; };
    hello = lambda { print("hello") };
    hello();
    log = lambda (m: str) { print(m); };
    print(log("logged"));
    print(add(1), add(b=5, a=1), shout("hi"), triple(4), seven());
    pairs = [(3, "c"), (1, "a"), (2, "b")];
    print(sorted(pairs, key=lambda (p: tuple[int, str]) -> int { p[0] }));
}
```

```output
hello
logged
None
11 6 HI! 12 7
[(1, 'a'), (2, 'b'), (3, 'c')]
```

## Nested functions and closures

A `def` or a `lambda` inside a function is a closure: it can read and assign the enclosing
function's variables.

- **It shares the variables, it does not copy them.** It sees assignments the enclosing function
  makes after it was created, and an assignment in it changes the enclosing function's variable.
  There is no `nonlocal`; see [Variables](variables.md#scope).
- **Each pass of a `for` loop has its own target variable.** A closure made in the body shares
  that pass's variable, and sees what the rest of the pass assigns to it (an item of a nested
  target such as `(a, (b, c))` too). The last pass's variable is the one code after the loop goes
  on assigning: `i = 99` after the loop changes what the last closure returns. A comprehension's
  variable is new at each item too: `[lambda -> int { return x; } for x in range(3)]` holds three
  functions returning 0, 1 and 2.
- **A variable the body assigns, other than the target, is one variable of the function.**
  Closures made in successive passes all see its last value.
- A `lambda` or a `def` inside a module's `with entry` block reads and assigns that block's
  locals.
- A closure outlives the call that made it: what it captured lives as long as it does.
- Nested functions may call each other, including one declared after its caller.

```jac
def make_counter -> Callable[[], int] {
    count = 0;
    def step -> int {
        count += 1;
        return count;
    }
    return step;
}

def make_adder(k: int) -> Callable[[int], int] {
    return lambda (x: int) -> int { return x + k; };
}

with entry {
    c = make_counter();
    d = make_counter();
    print(c(), c(), d(), make_adder(5)(1));
    fs: list[Callable[[], int]] = [];
    for i in range(3) {
        fs.append(lambda -> int { return i; });
    }
    print([f() for f in fs]);
    i = 99;
    gs: list[Callable[[], int]] = [];
    for j in range(3) {
        b = j * 2;
        gs.append(lambda -> int { return b; });
    }
    print([f() for f in fs], [g() for g in gs]);
}
```

```output
1 2 1 6
[0, 1, 2]
[0, 1, 99] [4, 4, 4]
```

## Recursion and `return tail`

A function may call itself, directly or through others. Each call takes stack space; a recursion
too deep for the stack raises `RecursionError: maximum recursion depth exceeded`. The limit is the
thread's stack, not a count of calls: there is no recursion limit to set.

`return tail f(args);` returns the result of a call that reuses the current call's frame, so a
recursion written with it runs in constant stack space at any depth. What follows `tail` must be a
call (E0097); one that cannot reuse the frame is refused with the reason (E5114).

```jac
def fact(n: int) -> int {
    return 1 if n <= 1 else n * fact(n - 1);
}

def total(n: int, acc: int) -> int {
    if n == 0 {
        return acc;
    }
    return tail total(n - 1, acc + n);
}

with entry {
    print(fact(20), total(1000000, 0));
}
```

```output
2432902008176640000 500000500000
```

## Functions as values

A function's name, a lambda and a bound method (`counter.bump`) are values of a `Callable` type,
such as `Callable[[int], int]`: they can be passed, stored and returned. What fits which
`Callable`, how a call through a value binds its arguments, and objects and classes used as
functions are in [Function values](functions-values.md) (`jac docs Callable`).

Type parameters (`def first[T](xs: list[T]) -> T`) are in `jac docs generics`, compile-time
parameters (`comptime n: int`) in `jac docs comptime`, decorators in `jac docs decorators`,
`async def` in [Async](async.md), and generator functions in [Generators](generators.md).

## What is rejected

| Code | Condition |
|---|---|
| E1050 | A required argument is missing |
| E1051 | Too many positional arguments |
| E1052 | A keyword argument that names no parameter, with no `**opts` to take it |
| E1053 | An argument of the wrong type |
| E1056 | A positional-only parameter given by keyword |
| E1057 | A parameter given twice, by position and by keyword |
| E1023 | A call of something that is not callable |
| E1002 | A `return` value of the wrong type, or a bare `return;` where the return type does not include `None` |
| E1003 | A value returned from a function that declares no return type |
| E1004 | A function, or a lambda with a multi-statement body, that may end without returning its value |
| E0159 | A body's last expression written as its value, without `return`: `def f -> int { e }` |
| E0160 | A lambda whose one statement only computes a value, with a `;` after it: `lambda (x: int) { x * 3; }` |
| W3005 | `def f()` or `lambda ()`: empty parentheses |
| E0050 | `/` or a bare `*` twice in one parameter list, or two parameters of one name |
| E0052 | A parameter of a `def` without a type |
| E0120 | `/` with no parameter before it |
| E0121 | A default on `*rest` or `**opts` |
| E0122 | A bare `*` with no parameter after it |
| E0022 | A lambda without a braced body |
| E0097 | `return tail` of something that is not a call |

```jac
# expect: E1050, E1051, E1052, E1053, E1056
def f(a: int, b: int, /, *, k: int = 0) -> int {
    return a + b + k;
}

with entry {
    f(1);
    f(1, 2, 3);
    f(1, 2, z=3);
    f("x", 2);
    f(a=1, b=2);
}
```

```jac
# expect: E1004, E1057, E1002 x2, E1003
def sign(x: int) -> int {
    if x > 0 {
        return 1;
    }
}

def half(x: int) -> int {
    if x % 2 == 1 {
        return;
    }
    return x / 2;
}

def twice(x: int) {
    return x * 2;
}

def add(a: int, b: int = 1) -> int {
    return a + b;
}

with entry {
    add(1, a=2);
}
```

```jac
# expect: E0050 x2, E0052
def f(a: int, /, b: int, /) -> int {
    return a;
}

def g(a: int, a: int, scale) -> int {
    return a;
}
```

## Differences from Python

- A function with no parameters is written without parentheses: `def greet { ... }`.
- Parameters are typed, and argument binding is checked at compile time.
- `*rest` is a `list`, not a `tuple`.
- A default is evaluated at each call that needs it, not once.
- There is no `nonlocal` or `global`: a nested function assigns the variable it names.
- A closure in a loop keeps its own pass's variable.
- A lambda has typed parameters and a braced body, and may hold statements.
- `return tail` guarantees a tail call.
