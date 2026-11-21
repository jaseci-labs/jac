---
description: Asynchronous code: async def and coroutines, await, async for and async generators, async comprehensions, running a coroutine, and the task expressions flow and wait.
keywords: async, await, async def, async for, coroutine, Coroutine, AsyncIterator, async generator, async comprehension, awaitable, __await__, __aiter__, __anext__, event loop, flow, wait, task
grammar: concurrent, await_expr, async_element
---
# Async

An `async def` function is a coroutine function: calling it makes a coroutine, which runs only
when something awaits it, and which can pause at each `await` and resume later. `flow` and `wait`
are a separate pair: `flow e` makes a task of an expression, and `wait t` takes the task's result.

## Syntax

```ebnf
async_element ::= ability | archetype

await_expr ::= "await" pipe_call | pipe_call

concurrent ::= ("flow" | "wait") walrus | walrus
```

`async` comes right before `def` (and after `static`, `override` or `class` on a method; see
[Methods](methods.md)). `async with` is in [Context managers](context-managers.md), and an `async`
walker in `jac docs walker`.

## `async def` and `await`

- Calling an `async def` function runs none of its body. It gives a coroutine, of type
  `Coroutine[any, any, R]` where `R` is the declared return type.
- `await c` runs the coroutine `c` until it finishes, and gives its return value, or raises what it
  raised. While `c` is paused, the coroutine doing the awaiting is paused too.
- `await` is allowed only inside an `async def` (E2085), and only on something awaitable (E1041):
  a coroutine, or an object whose class defines `__await__`.
- A call of an `async def` whose coroutine is dropped, as in `fetch(1);` on its own, never runs, and
  is an error (E1278).
- `await` binds tightly, like a prefix on what follows: `await f(x) + 1` is `(await f(x)) + 1`.
  Inside a larger expression, the operands to the left of an `await` are evaluated before the
  coroutine pauses and kept while it is paused.
- An exception raised in an awaited coroutine propagates to the awaiter, whose `try` catches it.
- A coroutine keeps its arguments alive until it finishes, temporaries of the statement that
  made it included.
- An `async def` is not a function that returns nothing: given where a `Callable[[int], None]` is
  wanted it is E1053, and assigned to a variable of that type E1001, since its callers would drop
  the coroutine. A lambda whose body is the expression `save(4)`, with no `;`, gives the coroutine
  as its value instead of dropping it; `lambda { save(4); }` is a statement, which drops it (E1278).

A coroutine is run by something that drives it. Two ways to run one from synchronous code are:

- `asyncio.run(main())`, with the standard library's `asyncio`, a native module
  ([asyncio](../library/asyncio.md), `jac docs asyncio`). Its event loop runs each coroutine
  that `asyncio.gather` and `asyncio.create_task` give it as a task, and the tasks take turns
  at their `await`s.
- Driving it by hand: `c.send(None)` runs it to its next pause or to its end, which raises
  `StopIteration` holding the result as `.value`.

A coroutine also has `throw(exc)` and `close()`:

| Call | Effect |
|---|---|
| `c.throw(exc)` | Raises `exc` where `c` is paused. If `c` does not catch it, it propagates out of `throw` and `c` is finished. |
| `c.close()` | Finishes `c`: a paused one silently, one not yet started without running it |
| `c.send(None)` on a finished or closed coroutine | Raises `RuntimeError: cannot reuse already awaited coroutine` |

`str(c)` is `<coroutine object>`, and of an async generator `<async_generator object>`.

```jac
import asyncio;

async def tick(name: str, n: int) -> str {
    for i in range(n) {
        print(name, i);
        await asyncio.sleep(0);
    }
    return name;
}

async def main -> list[str] {
    first = await tick("solo", 1);
    both = await asyncio.gather(tick("a", 2), tick("b", 2));
    return [first] + both;
}

with entry {
    print(asyncio.run(main()));
}
```

```output
solo 0
a 0
b 0
a 1
b 1
['solo', 'a', 'b']
```

Driven by hand, with no library:

```jac
async def add(a: int, b: int) -> int {
    return a + b;
}

async def total -> str {
    x = await add(1, 2);
    y = await add(x, 10);
    return f"result {y}";
}

with entry {
    c = total();
    try {
        c.send(None);
    } except StopIteration as done {
        print(done.value);
    }
}
```

```output
result 13
```

### Awaitable objects

An object is awaitable when its class defines `__await__`, written as a generator method. What it
yields goes out to whatever drives the outermost coroutine; when it ends, the `await` is done.
The value of the `await` is what the generator returns, where it is declared
`-> Generator[Y, S, R]` and ends with `return value;` (a future's `__await__` returns its
result this way); it is `None` otherwise.

```jac
obj Ticks {
    has n: int;

    def __await__ -> Iterator[any] {
        for i in range(self.n) {
            yield f"tick {i}";
        }
    }
}

async def waits -> str {
    await Ticks(n=2);
    return "done";
}

with entry {
    c = waits();
    out: list[any] = [];
    try {
        while True {
            out.append(c.send(None));
        }
    } except StopIteration as e {
        out.append(e.value);
    }
    print(out);
}
```

```output
['tick 0', 'tick 1', 'done']
```

## Async iteration

`async for x in it { ... }` iterates an asynchronous iterator: an object whose class defines
`__aiter__` (returning the iterator) and `async def __anext__`, which returns the next item or
raises `StopAsyncIteration()`. Each step awaits `__anext__`. It takes an `else` block, `break` and
`continue` as `for` does, and is allowed only inside an `async def` (E2192).

An **async generator** is an `async def` declared to return `AsyncIterator[T]` that contains
`yield`. It may both `await` and `yield`. `return;` ends it; `return value;` is an error (E2193),
and `yield` in an `async def` declared otherwise is too (E2194).

An **async comprehension** has an `async for` clause: `[s async for s in ticker(3)]`, and the same
in dict and set comprehensions. It too belongs inside an `async def`.

`async for` is also how a page, or any code on a JavaScript host, reads a stream of another
space: a call of a function there that gives an iterator gives an `AsyncIterator[T]` here
([Crossings](../apps/crossings.md#calling-a-stream)).

```jac
async def ticker(n: int) -> AsyncIterator[str] {
    for i in range(n) {
        yield f"item {i}";
    }
}

obj Countdown {
    has n: int;

    def __aiter__ -> Countdown {
        return self;
    }

    async def __anext__ -> int {
        if self.n == 0 {
            raise StopAsyncIteration();
        }
        self.n -= 1;
        return self.n;
    }
}

async def collect -> str {
    got: list[str] = [];
    async for s in ticker(2) {
        got.append(s);
    }
    async for k in Countdown(n=2) {
        got.append(str(k));
    } else {
        got.append("end");
    }
    lengths = {s: len(s) async for s in ticker(2)};
    return f"{got} {lengths}";
}

with entry {
    c = collect();
    try {
        c.send(None);
    } except StopIteration as e {
        print(e.value);
    }
}
```

```output
['item 0', 'item 1', '1', '0', 'end'] {'item 0': 6, 'item 1': 6}
```

An async generator also has `__anext__()`, `athrow(exc)` and `aclose()`, each awaited.
`await g.athrow(exc)` raises `exc` at the paused `yield`; uncaught, it propagates out of `athrow`
and finishes the generator. `await g.aclose()` closes it. A finished or closed async generator's
`__anext__()` raises `StopAsyncIteration`.

```jac
async def ticker(n: int) -> AsyncIterator[str] {
    for i in range(n) {
        yield f"item {i}";
    }
}

async def consume -> list[str] {
    out: list[str] = [];
    g = ticker(3);
    out.append(await g.__anext__());
    try {
        await g.athrow(ValueError("thrown"));
    } except ValueError as e {
        out.append("athrow " + str(e));
    }
    try {
        await g.__anext__();
    } except StopAsyncIteration {
        out.append("finished");
    }
    h = ticker(3);
    out.append(await h.__anext__());
    await h.aclose();
    try {
        await h.__anext__();
    } except StopAsyncIteration {
        out.append("closed");
    }
    return out;
}

with entry {
    c = consume();
    try {
        c.send(None);
    } except StopIteration as e {
        print(e.value);
    }
}
```

```output
['item 0', 'athrow thrown', 'finished', 'item 0', 'closed']
```

## Tasks: `flow` and `wait`

`flow e` evaluates the expression `e` as a task and gives a handle to it. `wait t` gives the task's
value; if evaluating `e` raised, `wait t` raises that exception. A task may be waited for more than
once, and gives the same value each time.

A task of a call, `flow f(a, b)`, runs beside the code that made it:

- **The callee and the arguments are evaluated where the `flow` is written.** So is the object of
  a method call (`flow r.review(f)`). The call itself is the task. A local changed after the
  `flow` does not change what the task was given, so `[flow f(x) for x in xs]` gives each task
  its own `x`.
- **In a native program and in a cpython space the call runs on a thread of the program's**, one
  of a pool the runtime keeps (as many threads as the tasks that wait for one or run, at most
  32). It runs as every thread does,
  [one at a time](../library/threading.md#how-threads-take-turns): tasks that wait (for a model,
  a socket, a lock, `time.sleep`) overlap, and tasks that compute take turns.
- **`wait t` on a task no thread has taken yet runs it on the waiting thread.** So tasks that
  wait for tasks never wait for a thread the pool has no room for, and a task waited for at once
  costs little more than a call.
- **A task runs as its maker was at the `flow`**: with a copy of its context variables, and in a
  server for the same caller, so `root` in the task is the root of the call that made it.
- **A program ends once its tasks are done**, whether or not it waited for them.
- **A task that is lent a borrow is done before the borrow is.** `flow read_it(&a)` runs beside
  its maker like any task, and the function that made it waits for it at the first of: its
  `wait`; the next statement that uses `a` once no loan to a task is live (so a write the checker
  allows never races it); the drop of an owner it was lent; and the function's end, however it
  ends. A method of an owner (`flow a.size()`) borrows `a` the same way.
- **Under `--memory nogc` a task runs to its end at its `flow`.** A task that runs beside its
  maker is held by two things at once, its handle and the thread running it, which takes a
  count; under nogc nothing is counted and every value has one owner. That profile's concurrency
  is [`flow for`](flow-for.md), whose threads are joined before the loop ends.
- **In a generator, a coroutine and module-level code**, which the borrow checker does not
  follow, a task that is lent a borrow is done when the statement that made it ends: the tasks
  one statement makes run at once (`[wait t for t in [flow read(&a) for i in range(3)]]`), and
  none outlasts it.
- **Elsewhere the call also runs to its end at the `flow`**: in a JavaScript or a wasm space,
  which has one thread. A `flow` of an expression that is not a call (`flow a + b`) is evaluated
  where it is written everywhere.

```jac
import time;

def fetch(page: int) -> str {
    time.sleep(0.3);
    return f"page {page}";
}

with entry {
    began = time.time();
    tasks = [flow fetch(n) for n in range(4)];
    print([wait t for t in tasks]);
    print("together:", time.time() - began < 0.9);
}
```

```output
['page 0', 'page 1', 'page 2', 'page 3']
together: True
```

- `flow` and `wait` bind more loosely than every operator but the conditional expression and
  `lambda`: `wait a + wait b` does not parse. Write `(wait a) + (wait b)`.
- `wait` takes a task that `flow` made (E1208); a coroutine is awaited, not waited for.
- A task's type is `Task[T]`, `T` the type of its value (`Task[None]` for a call that gives
  none): a field, a container's items, a parameter and a result may be one. `type(t)` is the one
  type of every task, named `Task`, whatever its value's type. A task does not cross between
  spaces (E1308).
- A program must not rely on when a task's code runs relative to the code after its `flow`: only
  that `wait` delivers its outcome, and that the program does not end before the task has.
  State that tasks share is guarded as threads' is, with a `threading.Lock`.
- What a task's expression is given follows [ownership](ownership.md): `flow read_it(&a)` lends
  `a` to the task for as long as the task is still to be waited for: writing `a` meanwhile is
  E1303, and borrowing it with `&mut` E1302. Once `wait` has given the result `a` may be written
  again;
  `flow consume(a)` moves an owner into the task, and using `a` after it is E1301; an `imm` value
  may be sent. A borrow held in a local (`v = &a; flow read_it(v)`) is not sendable (E1308). A
  task of an owner's method (`t = flow a.size()`) borrows `a` until it is waited for: shared, or
  exclusive if the method changes its object.

```jac
obj Buffer {
    has n: int = 0;
}

def read_it(x: &Buffer) -> int {
    return x.n;
}

def consume(b: own Buffer) -> int {
    return b.n;
}

with entry {
    a: own Buffer = Buffer(n=5);
    h = flow read_it(&a);
    r = wait h;
    a.n = 7;
    print(r, a.n);
    moved = flow consume(a);
    print(wait moved);
}
```

```output
5 7
7
```

```jac
def square(x: int) -> int {
    return x * x;
}

def failing -> int {
    raise ValueError("in the task");
}

with entry {
    a = flow square(6);
    b = flow square(7);
    print((wait a) + (wait b));
    tasks = [flow square(i) for i in range(5)];
    total = 0;
    for t in tasks {
        total += wait t;
    }
    print(total);
    f = flow failing();
    try {
        wait f;
    } except ValueError as e {
        print("from the task:", e);
    }
    print(type(a).__name__, type(a) is type(f), type(a) is type(None));
}
```

```output
85
30
from the task: in the task
Task True False
```

`flow for` is a different construct, the parallel loop; see
[Parallel loops](flow-for.md) (`jac docs flow for`).

## What is rejected

| Code | Condition |
|---|---|
| E2085 | `await` outside an `async def` |
| E2192 | `async for`, `async with` or an async comprehension outside an `async def` |
| E1041 | `await` of something that is not awaitable |
| E1278 | A call of an `async def` whose coroutine is dropped |
| E2193 | `return value;` in an async generator |
| E2194 | `yield` in an `async def` not declared to return `AsyncIterator[T]` |
| E1208 | `wait` of something that is not a task |
| E5090 | An `async def` nested inside a function |

```jac
# expect: E2085, E1041, E1278
async def add(a: int, b: int) -> int {
    return a + b;
}

async def bad -> int {
    return await 5;
}

def sync_caller -> int {
    add(1, 2);
    return await add(1, 2);
}
```

```jac
# expect: E2193, E2194, E1208
async def gen -> AsyncIterator[int] {
    yield 1;
    return 2;
}

async def plain -> int {
    yield 1;
    return 2;
}

with entry {
    x = 5;
    print(wait x);
}
```

```jac
# expect: E1303, E1302
obj Buffer {
    has n: int = 0;
}

def read_it(x: &Buffer) -> int {
    return x.n;
}

def early {
    a: own Buffer = Buffer(n=5);
    h = flow read_it(&a);
    a.n = 7;
    print(wait h);
    k = flow read_it(&a);
    b = &mut a;
    b.n = 3;
    print(wait k);
}
```

## Differences from Python

- `asyncio` is a native module, with its event loop written in Jac
  ([asyncio](../library/asyncio.md)). CPython's `asyncio`, which runs Jac coroutines too, is
  `importlib.import_module("asyncio")` ([Python values](../interop/python-values.md)).
- An async generator and a coroutine declare their types: `-> AsyncIterator[T]`, `-> R`.
- A coroutine that is made and dropped is a compile error, not a runtime warning.
- `flow` and `wait` have no Python counterpart.
