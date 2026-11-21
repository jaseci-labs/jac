---
description: Where clauses, the compile-time conditions a generic function or archetype states on its compile-time parameters, evaluated at each call or instance.
keywords: where, where clause, constraint, constraints
grammar: where_clause
---
# Where clauses

A `where` clause is a condition on a declaration's compile-time parameters,
with an optional message after a comma, as a
[`comptime assert`](compile-time.md) has. It may name compile-time value
parameters (`[comptime N: int]`) and the compile-time members of bounded type
parameters (`T.BYTES`).

## Syntax

```ebnf
where_clause ::= "where" expression ("," expression)?
```

A `where` clause comes after a function's or a method's signature
(`def f[comptime N: int](x: int) -> int where N > 0 {`) or after an
archetype's header (`obj Ring[comptime N: int] where N >= 2 {`), before the
body. The expression after the comma, when there is one, is the message.
`where` is a word only there: elsewhere it is an ordinary name.

## What it means

- **It is evaluated at each call, or each instance of an archetype**, with
  the arguments that call or instance gives, before anything is compiled for
  them. One that does not hold is E1285 at the call, with its message.
- **A type parameter is a compile-time value in it**, as a `comptime`
  parameter is: `where T != str` is evaluated with each call's type for `T`,
  found from the arguments or written (`f[int](3)`). A function whose clause
  reads one is compiled for each type it is called with.
- **On a declaration with no compile-time parameters** it is evaluated once,
  where it is declared.
- **It names only what is known at compile time.** A parameter given as the
  program runs is E0033.
- **It is a check, not an assumption.** Nothing reasons from it inside the
  body: it holds there as a `comptime assert` of it would hold in each copy.

```jac
def doubled[comptime N: int](x: int) -> int where N >= 0, "N counts doublings" {
    r = x;
    comptime for _ in range(N) {
        r = r * 2;
    }
    return r;
}

obj Ring[comptime N: int] where N >= 2, "a ring has two slots or more" {
    has items: list[int] = [];

    def slot(i: int) -> int {
        return i % N;
    }
}

obj Sized {
    comptime BYTES: int;
}

obj Word(Sized) {
    comptime BYTES: int = 4;
}

def wide[T: Sized](x: int) -> int where T.BYTES >= 4, "T must be four bytes or more" {
    return x * T.BYTES;
}

def not_str[T](x: T) -> T where T != str, "not a str" {
    return x;
}

with entry {
    print(doubled[3](5), doubled[0](5), Ring[3]().slot(7), wide[Word](2));
    print(not_str[int](3), not_str(2.5));
}
```

```output
40 5 1 8
3 2.5
```

## What is rejected

| Code | When |
|---|---|
| E1285 | A `where` clause that does not hold, at the call or instance that gives the values |
| E0033 | A `where` clause that names a value given as the program runs |

```jac
# expect: E1285 x3, E0033
def doubled[comptime N: int](x: int) -> int where N >= 0, "N counts doublings" {
    return x * (2 ** N);
}

def not_str[T](x: T) -> T where T != str, "not a str" {
    return x;
}

obj Ring[comptime N: int] where N >= 2, "a ring has two slots or more" {
    has items: list[int] = [];
}

def positive(x: int) -> int where x > 0 {
    return x;
}

with entry {
    print(doubled[-1](5));
    r = Ring[1]();
    print(not_str("s"));
}
```

## Differences from Python and from the reference design

- **Python and the reference design have no `where` clauses.** In Python the same check is
  an `assert` that runs when the code does; here it runs as the program
  compiles, once for each set of compile-time arguments.

## See also

- [Generics](generics.md) and [Compile-time parameters](comptime-parameters.md):
  the parameters a clause names.
- [Interfaces](interfaces.md): compile-time members, which a clause may name
  through a bounded type parameter.
- [Compile-time evaluation](compile-time.md): `comptime assert`, whose
  meaning a clause shares.
