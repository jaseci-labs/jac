---
description: Raising and handling errors: try with except, else and finally, raise, bare raise and raise from, defining exception classes, assert, and what an exception nothing catches prints.
keywords: exception, exceptions, try, except, finally, raise, raise from, assert, traceback, uncaught exception, exception class, awaiting
grammar: try_stmt, except_clause, raise_stmt, assert_stmt
---
# Exceptions

An exception is an object that a `raise` throws and a `try` catches. A raised exception unwinds the
calls in progress, running their `finally` blocks, until an `except` clause that names its class
takes it. One that nothing catches ends the program.

The builtin exception classes (`ValueError`, `KeyError`, `OverflowError`, ...) and their hierarchy
are those of Python; see `jac docs builtin exceptions`.

## `try`

```ebnf
try_stmt ::= "try" block ("awaiting" block)? except_clause* else_stmt? ("finally" block)?

except_clause ::= "except" expression ("as" NAME)? block
```

1. The `try` block runs.
2. If it raises, the `except` clauses are tried in order. The first whose class the exception is an
   instance of runs, with the exception bound to the name after `as`. A clause may name a tuple of
   classes: `except (KeyError, IndexError) as e`. If no clause matches, the exception goes on
   unwinding.
3. If the `try` block raised nothing, the `else` block runs. An exception the `else` block raises is
   not handled by this `try`'s clauses.
4. The `finally` block runs last, whatever happened: after a handled exception, while an unhandled
   one unwinds, and when a `return`, `break` or `continue` leaves the `try`, `except` or `else`
   block.

```jac
def run(k: int) -> str {
    out: list[str] = [];
    try {
        out.append("try");
        if k == 1 {
            raise ValueError("bad");
        }
        if k == 2 {
            raise KeyError("key");
        }
    } except ValueError as e {
        out.append(f"except {e}");
    } else {
        out.append("else");
    } finally {
        out.append("finally");
    }
    return ",".join(out);
}

with entry {
    print(run(0));
    print(run(1));
    try {
        print(run(2));
    } except (KeyError, IndexError) as e {
        print("escaped:", repr(e));
    }
}
```

```output
try,else,finally
try,except bad,finally
escaped: KeyError('key')
```

`finally` runs before a `return` from the `try` hands back its value:

```jac
def f -> int {
    try {
        return 1;
    } finally {
        print("finally runs");
    }
}

with entry {
    print(f());
}
```

```output
finally runs
1
```

- **An `except` clause always names a class.** To catch every error, write `except Exception`.
  `except BaseException` also catches `SystemExit` and `KeyboardInterrupt`, which `Exception` does
  not.
- **The `as` name belongs to its clause.** Two clauses may bind the same name to different classes.
  A name the function already uses as a local is refused (E1453).
- **The class is checked**: one that is not an exception class is an error (E1206).
- `try ... awaiting { ... }`, which the grammar takes, is refused today (E5090).

## `raise`

```ebnf
raise_stmt ::= "raise" expression? ("from" expression)? ";"
```

| Form | Meaning |
|---|---|
| `raise ValueError("msg");` | Raise an exception object. A class must be called: `raise ValueError;` is an error (E1090). |
| `raise;` | In an `except` clause, raise again the exception that clause is handling, even after a `try` inside the clause has handled another (E2125 outside a clause) |
| `raise E("new") from e;` | Raise `E("new")`, recording `e` as its `__cause__` |
| `raise E("new") from None;` | Raise it with no cause |

```jac
def again -> str {
    try {
        try {
            raise KeyError("k");
        } except KeyError {
            raise;
        }
    } except Exception as e {
        return f"{type(e).__name__}({e})";
    }
    return "";
}

with entry {
    print(again());
    try {
        try {
            raise KeyError("inner");
        } except KeyError as e {
            raise ValueError("outer") from e;
        }
    } except ValueError as e {
        print(e, "caused by", repr(e.__cause__));
    }
}
```

```output
KeyError('k')
outer caused by KeyError('inner')
```

An exception keeps its constructor's positional arguments as `e.args` (`()` for none), however
it is read: directly, through an `any`, or with `getattr`. `str(e)` is its one argument's text, or
the tuple of several; a `KeyError`'s one argument is shown as its `repr` (`str(KeyError("k"))` is
`'k'`, quotes included). A `*` spread is accepted in an exception's construction,
`ValueError(*parts)`, whatever the list's items are typed, as an exception class called through an
`any` is.

## Defining exception classes

An exception class is an `obj` that derives from `Exception` or one of its subclasses. It is an
archetype like any other: it may have fields, methods, an `init` and a `__str__`.

- A class with no fields and no `init` takes any positional arguments, which become its `args`:
  `AppError("plain", 2).args` is `('plain', 2)`.
- A class with fields binds its arguments to them as any `obj` does, by keyword or by position,
  and keeps the positional ones as `args` too: for `obj Fielded(Exception) { has code: int = 0; }`,
  `Fielded(5).code` is `5` and `Fielded(5).args` is `(5,)`. Or write an `init` that sets the
  fields and passes the message on with `super.init(msg)`.
- `str(e)` is the class's own `__str__` when it has one, however `e` is typed (an `OSError`
  variable holding a subclass included). A class that defines only `__repr__` still prints its
  message.
- `except AppError` catches every subclass of `AppError`.

```jac
obj AppError(Exception) {}

obj HttpError(AppError) {
    has status: int,
        reason: str = "";

    def __str__ -> str {
        return f"{self.status} {self.reason}";
    }
}

obj Coded(AppError) {
    has code: int = 0;

    def init(msg: str, code: int) {
        super.init(msg);
        self.code = code;
    }
}

with entry {
    try {
        raise HttpError(status=404, reason="not found");
    } except AppError as e {
        print("caught:", e, type(e).__name__);
    }
    try {
        raise Coded("bad thing", 7);
    } except AppError as e {
        print(e, e.args);
    }
    parts = ["disk", "full"];
    print(AppError(*parts).args, ValueError(*parts));
}
```

```output
caught: 404 not found HttpError
bad thing ('bad thing',)
('disk', 'full') ('disk', 'full')
```

Construction, `init` and `super` are in [Archetypes](archetypes.md) and [Methods](methods.md).
`ExceptionGroup("several", [a, b])` prints as `several (2 sub-exceptions)`; the builtin classes
are listed in [Builtin exceptions](../library/exceptions.md) (`jac docs builtin exceptions`).

## `assert`

```ebnf
assert_stmt ::= "comptime"? "assert" expression ("," expression)? ";"
```

`assert cond;` raises `AssertionError` when `cond` is false. `assert cond, msg;` gives the error
`msg` as its argument; `msg` is evaluated only when the assertion fails. The message is a str: a
tuple or a number there is refused (E1001), so write an f-string, `assert n == 1, f"{path}: {n}";`.
In a `test` block, a failed `assert` fails the test; see [Tests](tests.md). `comptime assert` is
checked while the program compiles; see `jac docs comptime`.

```jac
with entry {
    x = 3;
    assert x > 0, "positive";
    try {
        assert x < 0, f"x is {x}";
    } except AssertionError as e {
        print("AssertionError:", e);
    }
}
```

```output
AssertionError: x is 3
```

## An exception nothing catches

When an exception leaves the program's entry code, the program prints a traceback on its standard
error and exits with status 1. The traceback lists the calls the exception passed through, the
outermost first, by file, line and function, and ends with the exception's class and message:

- Each frame appears once, at the line of the call or statement the exception left it from. A
  `try` whose handlers did not match adds nothing but that frame's line.
- Under each frame is its source line, as CPython shows it, when the program can read the file
  from where it runs; a program run elsewhere shows the frames alone.
- Module code is named `<module>`. The runtime's own frames are left out.

```jac
def inner(n: int) -> int {
    if n > 1 {
        raise ValueError(f"too big: {n}");
    }
    return n;
}

def middle(n: int) -> int {
    try {
        x = inner(n);
    } except KeyError {
        x = 0;
    }
    return x;
}

def outer(n: int) -> int {
    return middle(n) + 1;
}

with entry {
    print(outer(5));
}
```

```text
Traceback (most recent call last):
  File "main.jac", line 22, in <module>
    print(outer(5));
  File "main.jac", line 18, in outer
    return middle(n) + 1;
  File "main.jac", line 10, in middle
    x = inner(n);
  File "main.jac", line 3, in inner
    raise ValueError(f"too big: {n}");
ValueError: too big: 5
```

`SystemExit` is the exception: an uncaught `SystemExit(n)`, which `sys.exit(n)` raises, ends the
program with status `n` and prints nothing.

## What is rejected

| Code | Condition |
|---|---|
| E1090 | `raise` of something that is not an exception object (`raise 5;`, `raise ValueError;`) |
| E1206 | `except` naming something that is not an exception class |
| E1161 | `from` with something that is neither an exception nor `None` |
| E0150 | `raise from e;` with nothing to raise |
| E2125 | A bare `raise;` outside an `except` clause |
| E1453 | `except ... as name` where `name` is already a local |
| E5090 | `try ... awaiting` |

```jac
# expect: E1090, E1206, E2125
obj NotAnError {}

with entry {
    try {
        raise 5;
    } except NotAnError {
        print(1);
    }
    raise;
}
```

```jac
# expect: E1161, E1453
with entry {
    e = 1;
    try {
        raise ValueError("x") from 5;
    } except ValueError as e {
        print(e);
    }
}
```

## Differences from Python

- An `except` clause names a class; there is no bare `except:`.
- `raise ValueError` without a call is refused; write `raise ValueError()`.
- `except ... as e` cannot reuse the name of a local.
- An uncaught exception's traceback names the file, line and function of each call, without the
  source lines, and does not print the exceptions it was raised from.
