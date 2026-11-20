---
description: Every operator in an expression, from the loosest-binding to the tightest, with arithmetic, comparison chains, and/or/not and truth values, bitwise operators, is and in, the conditional expression, null-safe access and pipes.
keywords: operator, operators, precedence, expression, and, or, not, in, not in, is, is not, ==, !=, <, >, <=, >=, +, -, /, //, %, **, ~, ^, <<, >>, |>, <|, :>, <:, pipe, atomic pipe, ?., ?[, null-safe, conditional expression, ternary, truth value, truthiness, chained comparison
grammar: expression, pipe, pipe_back, logical_or, logical_and, logical_not, compare, bitwise_or, bitwise_xor, bitwise_and, shift, arithmetic, term, factor, power, atomic_pipe, atomic_pipe_back, pipe_call, atomic_chain, attr_name, atom
---
# Operators

An expression combines values with operators. Each operator has a fixed precedence: an operator
that binds more tightly takes its operands first, so `1 + 2 * 3` is `7`. Parentheses group any
expression.

## Precedence

From the loosest-binding to the tightest. Operators on one row bind equally and group left to
right, except `**`, which groups right to left, and the comparisons, which chain.

| Operators | Meaning | Page |
|---|---|---|
| `lambda`, `x if c else y` | A function value; the conditional expression | [Functions](functions.md), below |
| `flow e`, `wait e` | Start a task; wait for one | [Async](async.md) |
| `:=` | Assignment expression | [Variables](variables.md) |
| `by` | Delegation: what answers a `by` function, and a `visit` statement's chooser. Anywhere else it is E5090 | `jac docs by`, [visit](visit.md#visit--by) |
| `\|>` | Forward pipe | below |
| `<\|` | Backward pipe | below |
| `or` | Logical or | below |
| `and` | Logical and | below |
| `not` | Logical not | below |
| `==` `!=` `<` `>` `<=` `>=` `in` `not in` `is` `is not` | Comparisons | below |
| `as` | Cast | [Types](types.md) |
| `\|` | Bitwise or; set and dict union | below |
| `^` | Bitwise exclusive or | below |
| `&` | Bitwise and | below |
| `<<` `>>` | Shifts | below |
| `+` `-` and `+%` `-%` `+\|` `-\|` | Addition, subtraction; wrapping and saturating forms | below, [Wrapping arithmetic](numbers-wrapping.md) |
| `*` `/` `//` `%` `@` and `*%` `*\|` | Multiplication, division, floor division, remainder, matrix product | below |
| `+x` `-x` `~x` `-%x` | Unary plus, negation, bitwise not | below |
| `**` | Power | below |
| `++>` `<++` `<++>` `+>: :+>` `<+: :<+` `del -->` | Connect and disconnect nodes | [Connecting](connecting.md) |
| `:>` | Atomic forward pipe | below |
| `<:` | Atomic backward pipe | below |
| `spawn` | Start a walker | [Walkers](walkers.md) |
| `*x` | Unpack into a display or a call | [Collections](collections.md) |
| `own` `imm` `&` `&mut` | Ownership and borrows | `jac docs ownership` |
| `await` | Wait for an awaitable | [Async](async.md) |
| `x.a` `x?.a` `x[i]` `x?[i]` `f(...)` | Attribute, index, slice, call | below |

The grammar states the same order, one rule per level:

```ebnf
expression ::= lambda_expr | concurrent ("if" expression "else" expression)?

pipe ::= pipe_back ("|>" pipe_back)*

pipe_back ::= logical_or ("<|" logical_or)*

logical_or ::= logical_and ("or" logical_and)*

logical_and ::= logical_not ("and" logical_not)*

logical_not ::= "not" logical_not | compare

compare ::= cast (("==" | "!=" | "<" | ">" | "<=" | ">=" | "in" | "is" | "not in" | "is not") cast)*

bitwise_or ::= bitwise_xor ("|" bitwise_xor)*

bitwise_xor ::= bitwise_and ("^" bitwise_and)*

bitwise_and ::= shift ("&" shift)*

shift ::= arithmetic (("<<" | ">>") arithmetic)*

arithmetic ::= term (("-|" | "+|" | "-%" | "+%" | "+" | "-") term)*

term ::= factor (("*|" | "*%" | "@" | "%" | "//" | "*" | "/") factor)*

factor ::= ("-%" | "+" | "~" | "-") factor | power

power ::= connect ("**" factor)?

atomic_pipe ::= atomic_pipe_back (":>" atomic_pipe_back)*

atomic_pipe_back ::= spawn_expr ("<:" spawn_expr)*

pipe_call ::= ("|>" | ":>") atomic_chain | atomic_chain

atomic_chain ::= atom ("?" (("<." | "." | ".>")? attr_name | index_slice) | ("<." | "." | ".>") attr_name | "(" ("=" (kw_arg ("," kw_arg)* ","?)? | call_args) ")" | "[" filter_body | index_slice)*

attr_name ::= NAME | KEYWORD

atom ::=
    graph_expr
    | INT
    | FLOAT
    | multistring
    | NAME
    | "None"
    | KEYWORD
    | "..."
    | "*" expression
    | paren_expr
    | bracket_expr
    | brace_expr
    | jsx_element
    | "True"
    | "False"
```

```jac
with entry {
    x = 2;
    print(1 + 2 * 3, (1 + 2) * 3, 2 ** 3 ** 2, -2 ** 2, (-2) ** 2);
    print(1 << 2 + 1, 6 & 3 == 2, not 1 == 2, True or False and False);
    print(1 if x > 1 else 2 if x > 0 else 3);
}
```

```output
7 9 512 -4 4
8 True True True
1
```

`-2 ** 2` is `-(2 ** 2)`, as in Python, and `6 & 3 == 2` is `(6 & 3) == 2`: here the bitwise
operators bind more tightly than the comparisons, where in C they bind more loosely.

## Arithmetic

| Expression | Result |
|---|---|
| `a + b`, `a - b`, `a * b` | Sum, difference, product. An `int` and a `float` give a `float`. |
| `a / b` | True division: always a `float`. `7 / 2` is `3.5`, `10 / 5` is `2.0`. |
| `a // b` | Floor division: the quotient rounded toward negative infinity. `-7 // 2` is `-4`. |
| `a % b` | Remainder, with the sign of `b`: `-7 % 3` is `2`, `7 % -3` is `-2`. |
| `a ** b` | Power. A negative `int` exponent gives a `float`: `2 ** -1` is `0.5`. |
| `-a`, `+a`, `~a` | Negation, the value itself, bitwise not (`~5` is `-6`) |
| `a @ b` | Matrix product, through the operand's `__matmul__` |

- An `int` is 64 bits. An `int` result that does not fit raises `OverflowError`; it never wraps
  and never grows. The sized types and the wrapping (`+%`) and saturating (`+|`) operators are in
  [Numbers](numbers.md) and [Wrapping arithmetic](numbers-wrapping.md).
- Division and remainder by zero raise `ZeroDivisionError`, for `float`s too: `1.0 / 0.0` raises.
- A `bool` in arithmetic counts as `0` or `1`: `True + 1` is `2`, `sum([True, True, False])` is `2`.
- `+` joins two strings, two lists or two tuples, and `*` repeats a string, list or tuple:
  `"ab" * 2`, `2 * [0]`.
- On an object, each operator calls its special method (`__add__`, `__neg__`, `__matmul__`,
  ...); see [Special methods](methods-special.md). When the left operand's type has no method for
  the right one, the right one's reflected method is called: `1 + Turn(deg=45)` calls `__radd__`.
- On an `any`, each operator, unary ones too, is decided by what the value holds as the program
  runs (`-v` of a held `True` is `-1`, of a complex `(-1-2j)`); one the value does not support
  raises `TypeError: bad operand type for unary -: 'str'`.

```jac
with entry {
    print(7 / 2, 7 // 2, -7 // 2, 7 % 3, -7 % 3, 7 % -3, 2 ** -1, 7.5 // 2);
    print(1 + 2.5, 10 / 5, ~5, "ab" * 2, [1] + [2], (1,) + (2,));
    try {
        print(1.0 / 0.0);
    } except ZeroDivisionError as e {
        print("ZeroDivisionError:", e);
    }
    try {
        print(9223372036854775807 + 1);
    } except OverflowError as e {
        print("OverflowError:", e);
    }
}
```

```output
3.5 3 -4 1 2 -2 0.5 3.0
3.5 2.0 -6 abab [1, 2] (1, 2)
ZeroDivisionError: division by zero
OverflowError: integer overflow
```

## Bitwise operators

`&`, `|`, `^`, `~`, `<<` and `>>` work on `int`s (and on `bool`s and the sized integer types). `&`,
`|` and `^` of two `bool`s give a `bool` (`True ^ True` is `False`); `~True` is the `int` `-2`.
`>>` of a negative `int` keeps its sign: `-16 >> 2` is `-4`.

- `1 << 64` raises `OverflowError`, since the result does not fit in 64 bits.
- A negative shift count raises `ValueError`.
- On sets, `|`, `&`, `-` and `^` are union, intersection, difference and symmetric difference.
  On dicts, `|` merges, the right side winning a shared key.

```jac
with entry {
    print(0b1100 & 0b1010, 0b1100 | 0b1010, 0b1100 ^ 0b1010, 1 << 4, 256 >> 2, -16 >> 2);
    print({1, 2} | {3}, {1, 2} & {2}, {1, 2} - {1}, {1, 2} ^ {2, 3}, {"a": 1} | {"b": 2});
    try {
        print(1 << -1);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
8 14 6 16 64 -4
{1, 2, 3} {2} {2} {1, 3} {'a': 1, 'b': 2}
ValueError: negative shift count
```

## Comparisons

`==` and `!=` compare values; `<`, `>`, `<=` and `>=` order them; `in` and `not in` test
membership; `is` and `is not` test whether two operands are the same object. Every comparison gives
a `bool`.

- **Comparisons chain.** `a < b < c` means `a < b and b < c`, with `b` evaluated once. Evaluation
  stops at the first comparison that is false.
- **Both sides must be comparable.** Comparing a `str` with an `int`, or a list with an `int`, is a
  compile error (E1110), not `False`. An `int` compares with a `float` (`1 == 1.0`).
- **Sequences compare item by item:** `[1, 2] < [1, 3]`, `(1, "a") < (1, "b")`, and strings by
  code point. On sets, `<` and `<=` are the subset tests.
- **`in`** looks for an item in a list, tuple, set or `range`, a key in a dict, and a substring in
  a string. The right side must be a container (E1111). An `any` on the left of a typed
  container is compared with its items as the program runs, and one of another type is not
  among them: `held in ["a", "b"]` is `False` for `held: any = 3`, as in Python.
- **`is`** compares identity. Use it with `None` and with objects. `x is 0` or `s is "a"`, an
  identity test against a literal, is an error (W3035): write `==`.
- `not in` and `is not` are each one operator: `x not in xs` is `not (x in xs)`.

```jac
def side(n: int) -> int {
    print("side", n);
    return n;
}

with entry {
    print(side(1) < side(2) < side(3));
    print(side(3) < side(1) < side(2));
    xs = [1, 2, 3];
    print(2 in xs, 5 not in xs, "a" in {"a": 1}, "bc" in "abcd", 3 in range(5));
    a = [1];
    b = a;
    print(a is b, a is [1], a == [1], a is not None);
    print([1, 2] < [1, 3], (1, "a") < (1, "b"), "abc" < "abd", 1 == 1.0, {1} < {1, 2});
}
```

```output
side 1
side 2
side 3
True
side 3
side 1
False
True True True True True
True False True True
True True True True True
```

In the second chain `3 < 1` is false, so `side(2)` is never called.

On an object, the comparisons call `__eq__`, `__lt__` and the rest; without `__eq__`, `==` compares
an `obj`'s fields. See [Special methods](methods-special.md) and [Archetypes](archetypes.md).

## `and`, `or`, `not`

`a and b` evaluates `a`, and gives `a` if it is false, else `b`. `a or b` gives `a` if it is true,
else `b`. The right operand is evaluated only when needed. `not a` gives a `bool`.

**Truth values.** Every value is true or false where a condition is wanted (`if`, `while`, `and`,
`or`, `not`, `bool(v)`):

| False | True |
|---|---|
| `False`, `None`, `0`, `0.0` | Every other number |
| `""`, `[]`, `()`, `{}`, `set()`, an empty `range` | Every non-empty one |
| An object whose `__bool__` returns `False`, or whose `__len__` returns `0` | Every other object |

```jac
obj Flag {
    has on: bool = False;

    def __bool__ -> bool {
        return self.on;
    }
}

def side(n: int) -> bool {
    print("side", n);
    return n > 0;
}

with entry {
    print(0 or 5, "" or "default", [1] and [2, 3], not 0, not "x");
    print(bool(Flag()), bool(Flag(on=True)), bool(range(0)), bool([0]));
    print(side(0) and side(1));
    print(side(1) or side(2));
    n: int | None = None;
    print(n or 7);
}
```

```output
5 default [2, 3] True False
False True False True
side 0
False
side 1
True
7
```

When the two operands have different types, the result has their union type, `int | str` for
`0 or "five"`, which is checked as it reaches a place of one type.

## The conditional expression

`x if c else y` evaluates `c`, then `x` if `c` is true and `y` otherwise. It binds more loosely
than every other operator, so `a + 1 if c else b` is `(a + 1) if c else b`. Conditional expressions
nest to the right: `a if p else b if q else c`.

- The result's type is the type both branches fit, or their union.
- Both branches have a value. A branch that has none, a call of a function that returns nothing,
  is E1175; an `if` statement is the form for that.
- A test in the condition narrows in the branches: in `5 if n is None else n`, `n` is an `int` in
  the `else` branch.

```jac
def label(n: int | None) -> str {
    return "none" if n is None else "small" if n < 10 else "big";
}

with entry {
    print(label(None), label(3), label(50));
}
```

```output
none small big
```

## Null-safe access: `?.` and `?[`

`x?.name` reads `x.name`, and gives `None` when `x` is `None`. `x?[i]` indexes or slices the same
way. They chain: `n?.next?.val` is `None` as soon as one link is `None`.

The result's type is the attribute's or the item's, with `None`: `n?.val` on a `Node | None` is an
`int | None`. Narrow it (`is not None`) before giving it to a place that takes an `int`.

```jac
obj Node {
    has val: int,
        next: Node | None = None;
}

with entry {
    n: Node | None = None;
    print(n?.val, n?.next?.val);
    n = Node(val=1, next=Node(val=2));
    print(n?.val, n?.next?.val, n?.next?.next?.val);
    xs: list[int] | None = None;
    print(xs?[0], xs?[1:]);
    xs = [7, 8];
    d: dict[str, int] | None = {"k": 3};
    print(xs?[0], xs?[1:], d?["k"]);
}
```

```output
None None
1 2 None
None None
7 [8] 3
```

A method call through `?.` (`n?.show()`) is refused today (E5090). So are the attribute operators
`.>` and `<.`, and the form `x(= a=1)`, which the grammar takes.

## Pipes

A pipe passes a value to a function: `x |> f` is `f(x)`, and `f <| x` is also `f(x)`. A pipe of
several stages reads in the order the data flows: `3 |> dbl |> inc` is `inc(dbl(3))`.

| Operator | Means | Binds |
|---|---|---|
| `x \|> f` | `f(x)` | Looser than `or`: `x + 1 \|> f` is `f(x + 1)` |
| `f <\| x` | `f(x)` | Looser than `or` |
| `x :> f` | `f(x)` | Tighter than every arithmetic operator: `2 :> f * 10` is `f(2) * 10` |
| `f <: x` | `f(x)` | Tighter than `:>` |

- The right side of `|>` (the left side of `<|`) is anything callable: a function, a bound method
  (`5 |> counter.bump`), a builtin such as `sorted`, a parenthesized lambda.
- The function is called with the one argument; its other parameters take their defaults.
- Every pipe groups left to right. `f <| g <| x` is `(f <| g) <| x`, which calls `f` with the
  function `g`; write `f <| (g <| x)`.
- `|>` binds more loosely than the comparisons: `2 |> f == 4` is `2 |> (f == 4)`. Write
  `(2 |> f) == 4`, or use `:>`.
- `|>` and `:>` written before a value with nothing to their left are refused today (E5090).

```jac
def dbl(x: int) -> int {
    return x * 2;
}

def inc(x: int) -> int {
    return x + 1;
}

with entry {
    print(3 |> dbl, 3 |> dbl |> inc, dbl <| 4, inc <| (dbl <| 4));
    print(5 :> dbl, dbl <: 6, 2 :> dbl * 10, 1 + 2 |> dbl);
    print([3, 1, 2] |> sorted, "abc" |> len, (2 |> dbl) == 4);
    print(4 |> (lambda (x: int) -> int { return x + 1; }));
}
```

```output
6 7 8 9
10 12 40 6
[1, 2, 3] 3 True
5
```

## Attributes, indexes and calls

The tightest-binding forms follow a value, left to right: `x.name` reads an attribute, `x[i]` an
item or a slice, and `f(args)` calls. `xs[0][1]`, `"abc".upper().lower()` and `f(x)(y)` apply in
order. After `.` any word is taken, reserved or not (`r.type`); see
[Lexical structure](lexical-structure.md). Indexes and slices are in
[Collections](collections.md); calls and argument binding in [Functions](functions.md).

## What is rejected

| Code | Condition |
|---|---|
| E1110 | A binary operator its operand types do not support, such as `"a" - "b"`, `"a" == 1` or `1 < "a"` |
| E1010 | A unary operator its operand's type does not support: `-"a"`, `~1.5` |
| E1111 | `in` with something that is not a container on the right |
| W3035 | `is` or `is not` against a literal |
| E1175 | A conditional expression one of whose branches has no value |
| E5090 | `?.` followed by a call, `.>`, `<.`, `x(= ...)`, a prefix `\|>` or `:>`, `@` on a type without `__matmul__` |

```jac
# expect: E1010 x2, E1110 x2, E1111, W3035, E1175
def log(m: str) {
    print(m);
}

with entry {
    code = 3;
    print(-"a", ~1.5);
    print("a" - "b", "a" == 1);
    print(1 in 5, code is 0);
    print([log("a") if code > 0 else 2]);
}
```

## Differences from Python

- Comparing values of unrelated types (`"a" == 1`, `1 < "a"`) is a compile error.
- `int` arithmetic that overflows 64 bits raises `OverflowError`.
- `@` applies only to objects that define `__matmul__`.
- An identity test against a literal (`x is 0`) is an error, where Python warns.
- `|>`, `<|`, `:>`, `<:`, `?.` and `?[` have no Python counterpart.
- There is no bare tuple: `a, b` is not an expression. See [Collections](collections.md).
