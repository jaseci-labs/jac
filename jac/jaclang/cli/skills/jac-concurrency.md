---
name: jac-concurrency
description: Choose and implement async calls, walkers, flow/wait tasks, and lent loops. Use for concurrent work and backend-specific execution constraints.
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

## `flow for` - the disjoint-partition loop

`flow for x in &xs { }` / `flow for m in &mut xs { }` applies the `flow` modifier to a loop: the body is declared per-element over a lent collection and the closing brace is the join. The checker proves the shape race-free (lent collection required, no `break`/`return` across the join, no shared mutation in the body - E1313/E1308; write through the `&mut` element instead). Int accumulators in the reduction shapes (`acc += x`, `acc = min(acc, x)`, `acc = max(acc, x)`) are licensed: each task folds a private partial and the join combines them, so the result equals the sequential fold. In a zero-RC enforced native build (`jac build --native --memory nogc`) it runs genuinely parallel - element ranges fan out over pthreads and join at the brace (`[native] threads` sets the width, default 4; `JAC_THREADS` overrides at run time). `--memory rc` builds fan out the same way with atomic refcounts; `--memory managed`, Python, and wasm run it sequentially with identical results. Full rules live in the `jac-native-memory` guide.

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
- On the client, **imported server-endpoint calls are async - always `await` them** or you get a `Promise`, not data (see `jac-fullstack-patterns`).
- `wait` in a loop body that also contains the `flow` = accidental serial execution. Two passes: launch-all, then wait-all.
- Ownership-annotated payloads must be **sendable** across `flow` (E1308): scalars, `imm`, or an `own` moved into the boundary - a live borrow crosses only through join-bounded lending: `h = flow f(&x); ... wait h;` in the same block, with no intervening owner access or side exit. Otherwise `&`/`&mut` is rejected. Moving an `own Region` handle transfers its whole region subgraph zero-copy, legal only while no borrows of the handle are live. Unannotated code is unaffected. See `jac-native-memory`.

## See also

`jac-python-interop` (asyncio and other Python libs) · `jac-walker-patterns` (walkers, spawn) · `jac-sv-endpoints` (async server endpoints) · `jac-native-memory` (sendability rules, regions)

Chunked lending uses `flow for c in &mut xs.chunks(n)` (or shared `&xs.chunks(n)`). Chunks stay local to the joined loop and may not grow or escape. `lin` payloads move like `own` but must be consumed on every path. For region partitions, freezing, view restrictions, and full borrowing rules, load `jac-native-memory`.
