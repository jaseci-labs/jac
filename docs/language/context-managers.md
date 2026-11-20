---
description: The with statement and context managers: __enter__ and __exit__, binding with as, several managers in one with, suppressing an exception, and async with.
keywords: with, context manager, __enter__, __exit__, async with, __aenter__, __aexit__
grammar: with_stmt, with_item
---
# Context managers

A `with` statement runs a block between a setup and a cleanup that a value, the context manager,
defines. The cleanup runs however the block ends: normally, by `return`, `break` or `continue`, or
by an exception. Files are the usual example: `with open(path) as f { ... }` closes the file.

## Syntax

```ebnf
with_stmt ::= "async"? "with" with_item ("," with_item)* block

with_item ::= expression ("as" expression)?
```

The `with` at a module's top level, `with entry { ... }`, is module code, a different construct; see
[Modules](modules.md).

## What `with` does

For `with m as name { body }`:

1. `m` is evaluated, and its `__enter__()` is called.
2. What `__enter__` returns is bound to `name`. Without `as`, it is dropped.
3. The body runs.
4. `m.__exit__(exc_type, exc, tb)` is called. If the body raised, `exc` is the exception,
   `exc_type` its class and `tb` its traceback, `exc.__traceback__` (see
   [Builtin exceptions](../library/exceptions.md)); otherwise all three are `None`.
5. If the body raised and `__exit__` returns a true value, the exception is suppressed and the
   program goes on after the `with`. Otherwise it goes on unwinding. An `__exit__` declared without
   a return type, or `-> None`, never suppresses.

- If `__enter__` raises, the body does not run and `__exit__` is not called.
- The `as` name is a local of the enclosing function, and stays bound after the block.
- `with a as x, b as y { ... }` enters `a`, then `b`, and exits them in the reverse order, as two
  nested `with` statements would.

A context manager is any object whose class defines `__enter__` and `__exit__`; see
[Special methods](methods-special.md). Using another value is an error (E1091).

```jac
obj Resource {
    has name: str,
        log: list[str] = [];

    def __enter__ -> Resource {
        self.log.append(f"enter {self.name}");
        return self;
    }

    def __exit__(exc_type: any, exc: any, tb: any) -> bool {
        self.log.append(f"exit {self.name} {repr(exc)}");
        if tb is not None {
            self.log.append(f"{exc_type.__name__} from line {tb.tb_lineno}");
        }
        return exc_type is KeyError;
    }
}

with entry {
    r = Resource(name="a");
    with r as res {
        res.log.append("body");
    }
    print(r.log);
    with r {
        raise KeyError("k");
    }
    print(r.log[-2:]);
    try {
        with r {
            raise ValueError("v");
        }
    } except ValueError as e {
        print("escaped", e, r.log[-2:]);
    }
}
```

```output
['enter a', 'body', 'exit a None']
["exit a KeyError('k')", 'KeyError from line 26']
escaped v ["exit a ValueError('v')", 'ValueError from line 31']
```

The `KeyError` is suppressed because `__exit__` returns `True` for it; the `ValueError` is not.

### Several managers, and leaving early

```jac
obj Step {
    has name: str;

    def __enter__ -> str {
        print("enter", self.name);
        return self.name.upper();
    }

    def __exit__(exc_type: any, exc: any, tb: any) {
        print("exit", self.name);
    }
}

def first -> str {
    with Step(name="a") as x, Step(name="b") as y {
        return x + y;
    }
}

with entry {
    print(first());
}
```

```output
enter a
enter b
exit b
exit a
AB
```

### Files

`open(path, mode)` returns a file, which is its own context manager: leaving the `with` closes it.

```jac
import os;

with entry {
    path = "notes.txt";
    with open(path, "w") as f {
        f.write("one\ntwo\n");
    }
    with open(path) as f {
        print(f.read().split());
    }
    os.remove(path);
}
```

```output
['one', 'two']
```

## `async with`

`async with m as name { ... }` is the form for an asynchronous context manager, whose class defines
`async def __aenter__` and `async def __aexit__(exc_type, exc, tb)`. Each is awaited, so the setup
and the cleanup may themselves `await`. Otherwise it behaves as `with` does, suppression included.
It is allowed only inside an `async` function (E2192). See [Async](async.md).

```jac
obj Session {
    has log: list[str] = [];

    async def __aenter__ -> Session {
        self.log.append("open");
        return self;
    }

    async def __aexit__(exc_type: any, exc: any, tb: any) -> bool {
        self.log.append("close");
        return False;
    }
}

async def use(s: Session) -> str {
    async with s as t {
        t.log.append("work");
    }
    return ",".join(s.log);
}

with entry {
    c = use(Session());
    try {
        c.send(None);
    } except StopIteration as done {
        print(done.value);
    }
}
```

```output
open,work,close
```

## What is rejected

| Code | Condition |
|---|---|
| E1091 | A `with` on a value whose type has no `__enter__` and `__exit__` |
| E2192 | `async with` outside an `async` function |
| E5090 | An `as` target that is not a name, such as a field: `with m as box.v` |

```jac
# expect: E1091
with entry {
    with 5 as x {
        print(x);
    }
}
```

## Differences from Python

- A block is in braces, and `with a as x, b as y` needs no parentheses around its items.
- The `as` target is a name.
