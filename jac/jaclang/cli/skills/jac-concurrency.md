---
name: jac-concurrency
description: Running Jac code in parallel - flow/wait concurrent expressions (thread pool), async def/await, async walkers, and when to use which. Load for any parallel, background, threaded, or async work.
---

Jac has two concurrency models. `flow expr()` launches the call on a **thread pool** and returns a future immediately; `wait future` blocks for the result. `async def`/`await` is Python asyncio - cooperative, single-threaded, for I/O waits. Don't reach for `import threading` - `flow`/`wait` is the idiomatic form.

## `flow` / `wait` - launch many, then collect

```jac
import from time { sleep, time }

def slow_square(n: int) -> int {
    sleep(0.5);
    return n * n;
}

with entry {
    t0 = time();
    futures = [flow slow_square(n) for n in [1, 2, 3, 4]];  # all 4 start NOW
    results = [wait f for f in futures];                    # collect in order
    print(results);                # [1, 4, 9, 16]
    print(time() - t0 < 1.5);      # True - ~0.5s wall clock, not 2s serial
}
```

Launch everything first, `wait` afterwards - a `wait` directly after each `flow` serializes the work. Between launch and collect you can run other code.

## `async def` / `await` - asyncio interop

```jac
import asyncio;

async def fetch_one(n: int) -> int {
    await asyncio.sleep(0.1);          # stand-in for an HTTP/DB call
    return n * 10;
}

async def fetch_all() -> list[int] {
    results = await asyncio.gather(fetch_one(1), fetch_one(2), fetch_one(3));
    return list(results);
}

with entry {
    print(asyncio.run(fetch_all()));   # [10, 20, 30]
}
```

**Async walkers** work too: declare `async walker W { async can step with Item entry { data = await fetch(...); } }`, then `await (root spawn W())` from an async context - the traversal yields at each `await` instead of blocking.

## Choosing

| | `flow`/`wait` | `async`/`await` |
|---|---|---|
| Model | thread pool (true parallelism) | event loop (cooperative, one thread) |
| Best for | CPU-bound work, parallelizing blocking calls | I/O-bound: HTTP, DB, LLM calls |
| Scale | limited by threads | thousands of tasks |

Rule of thumb: blocking/synchronous functions you want overlapped → `flow`. An async library (aiohttp, async LLM clients) → `async`/`await`. Many apps use both.

## Pitfalls

- `flow`/`wait` are **reserved keywords** - can't be variable names (see `jac-core-cheatsheet`).
- `await` outside an `async def` is invalid - from `with entry`, drive async code with `asyncio.run(main())`.
- On the client, **`sv import` endpoint calls are async - always `await` them** or you get a `Promise`, not data (see `jac-fullstack-patterns`).
- `wait` in a loop body that also contains the `flow` = accidental serial execution. Two passes: launch-all, then wait-all.

## See also

`jac-python-interop` (asyncio and other Python libs) · `jac-walker-patterns` (walkers, spawn) · `jac-sv-endpoints` (async server endpoints)
