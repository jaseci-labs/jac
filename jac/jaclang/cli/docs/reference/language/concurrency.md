# Concurrency

**On this page:**

- [Async/Await](#asyncawait) - Async functions, async walkers, async for
- [Concurrent Expressions](#concurrent-expressions) - flow/wait for parallel tasks

---

Most real-world applications need to do multiple things at once -- fetching data from several APIs, processing independent tasks in parallel, or keeping a UI responsive while background work runs. Jac provides two distinct concurrency models to handle these scenarios:

1. **`async/await`** -- cooperative concurrency on a single-threaded event loop, ideal for I/O-bound work like HTTP requests, database queries, and file operations. Tasks voluntarily yield control while waiting, allowing other tasks to progress. This is the same model used by Python's `asyncio`, JavaScript's promises, and Rust's `async` -- if you've used any of those, the concepts transfer directly.

2. **`flow/wait`** -- thread-based concurrency, suited for overlapping *blocking* work (blocking I/O libraries that have no async API, or calls into C/native extensions that release the GIL). `flow` launches a function as a background task on a worker thread and immediately returns a future; `wait` blocks until the result is available. Think of it as structured, explicit concurrency -- you control exactly when work starts and when you synchronize.

!!! warning "`flow` does not parallelize pure-Jac CPU work"
    `flow` runs on real OS threads, but CPython's Global Interpreter Lock (which
    is enabled in the shipped runtime) serializes pure-Jac/Python bytecode, so
    two `flow` tasks doing arithmetic in a loop run in *sequence*, not in
    parallel -- two CPU-bound tasks take the same wall-clock time whether you run
    them with `flow` or one after another. `flow` gives a real speedup only when
    the work **releases the GIL**: blocking I/O (network, disk, `time.sleep`) or
    native/C extensions. For pure-Jac number crunching that must run truly in
    parallel, use separate processes.

The key distinction: `async/await` multiplexes tasks on one thread (cooperative), while `flow/wait` dispatches tasks to worker threads. Choose `async` when your bottleneck is waiting on external services through an async API, and `flow` when you need to overlap blocking calls that release the GIL.

## Async/Await

!!! note
    Async functions must be `await`ed from an async context. A `with entry`
    block is **not** async, so `await` cannot appear there directly -- it fails
    to compile with `error[E5043]: ... 'await' outside function`. To drive a
    coroutine from `with entry`, hand it to `asyncio.run()`; only use `await`
    inside an `async def`/`async can`:

    ```jac
    import asyncio;

    async def fetch_all() -> list[dict] {
        return await process_multiple(["/a", "/b"]);
    }

    with entry {
        results = asyncio.run(fetch_all());
    }
    ```

The `async/await` syntax works like Python's -- `async` marks a function as a coroutine, and `await` suspends execution until the awaited operation completes. This enables non-blocking I/O: while one coroutine waits on a network response, others can run. Walkers can also be async, enabling non-blocking graph traversal that performs I/O at each node without stalling the event loop.

### 1 Async Functions

Prefix a function definition with `async` to declare it as a coroutine. Inside an async function, use `await` to pause execution until an asynchronous operation completes. The function returns control to the event loop during the pause, allowing other coroutines to run. This makes async functions ideal for operations that involve waiting -- network requests, database queries, file reads -- because the program stays productive instead of blocking.

!!! note "Conceptual Examples"
    The examples below use `http_get` as a placeholder for an async HTTP client. In practice, import an async library (e.g., `import from aiohttp { ClientSession }`) or define your own async helper.

```jac
async def fetch_data(url: str) -> dict {
    response = await http_get(url);
    return await response.json();
}

async def process_multiple(urls: list[str]) -> list[dict] {
    results = [];
    for url in urls {
        data = await fetch_data(url);
        results.append(data);
    }
    return results;
}
```

### 2 Async Walkers

Walkers can be declared `async` to perform non-blocking I/O during graph traversal. This is particularly useful when each node in your graph requires an external call -- for example, fetching data from an API for each node, or running an LLM query at each step. Without `async`, each I/O call would block the entire traversal; with it, the walker yields during each `await` and stays responsive.

```jac
async walker DataFetcher {
    has url: str;

    async can fetch with Root entry {
        data = await http_get(self.url);
        report data;
    }
}
```

### 3 Async For Loops

Use `async for` to iterate over async iterators -- objects that produce values asynchronously, such as streaming responses from an API, reading chunks from a file, or consuming messages from a queue. Each iteration may `await` internally, so the loop yields to the event loop between items.

```jac
async def process_stream(stream: AsyncIterator) -> None {
    async for item in stream {
        print(item);
    }
}
```

---

## Concurrent Expressions

The `flow/wait` pattern provides explicit concurrency control for running functions concurrently on worker threads. Unlike `async/await` (which is cooperative and single-threaded), `flow` dispatches work to separate threads, making it suitable for overlapping blocking calls that release the GIL (blocking I/O, native extensions). See the warning above: under CPython's GIL it does **not** speed up pure-Jac CPU-bound loops.

The mental model is simple: `flow` says "start this work now, in the background" and hands you a future (a handle to the pending result). `wait` says "I need the result now" and blocks until it's ready. Between `flow` and `wait`, you're free to do other work -- or launch more `flow` tasks -- making it easy to overlap independent operations.

### 1 flow Keyword

The `flow` keyword launches a function call as a background task and returns a future immediately. The function runs on a separate worker thread, so it can overlap with your main code while that thread is blocked (waiting on I/O) or running GIL-releasing native code. Use it when you have independent blocking operations -- such as file processing, network calls made through a blocking client, or work delegated to a C extension -- that don't depend on each other's results.

!!! warning "`flow` evaluates its call on the worker thread -- pin loop variables"
    `flow f(x)` does **not** evaluate `x` at the point of the `flow`; the whole
    call `f(x)` is deferred and evaluated on the worker thread. If you write
    `flow f(i)` inside a `for i in ...` loop, every task reads whatever `i`
    happens to be when it runs, so the tasks race the loop variable. For example,
    `[wait f for f in [flow sq(i) for i in range(5)]]` yields something like
    `[0, 4, 4, 16, 16]`, not `[0, 1, 4, 9, 16]`. Pin the value by routing the
    `flow` through a helper whose parameter captures it by value:

    ```jac
    def sq(n: int) -> int { return n * n; }

    def launch(n: int) -> object {
        return flow sq(n);   # `n` is a fresh binding per call -- pinned
    }

    with entry {
        futs = [launch(i) for i in range(5)];
        print([wait f for f in futs]);   # [0, 1, 4, 9, 16]
    }
    ```

```jac
def expensive_computation -> int {
    return 42;
}

def do_something_else -> int {
    return 1;
}

with entry {
    future = flow expensive_computation();

    # Do other work while computation runs
    other_result = do_something_else();

    # Wait for result when needed
    result = wait future;
}
```

### 2 Parallel Operations

The real power of `flow/wait` emerges when you launch multiple tasks that each spend their time *blocked*. Each `flow` call starts a new background task immediately, so all tasks run concurrently. You then collect results with `wait` -- when the tasks are blocked on I/O (like the fetches below), the total wall-clock time is roughly the duration of the slowest task, not the sum of all tasks. (If the tasks were instead crunching numbers in pure Jac, the GIL would serialize them and you would get the sum, not the max -- see the warning above.)

```jac
def fetch_users -> list {
    return [];
}

def fetch_orders -> list {
    return [];
}

def fetch_inventory -> list {
    return [];
}

def process_local_data {
    # Process local data here
}

with entry {
    # Launch multiple operations in parallel
    future1 = flow fetch_users();
    future2 = flow fetch_orders();
    future3 = flow fetch_inventory();

    # Continue with other work
    process_local_data();

    # Collect all results
    users = wait future1;
    orders = wait future2;
    inventory = wait future3;
}
```

### 3 flow vs async

Choosing between the two concurrency models depends on what your code spends its time doing:

| Feature | async/await | flow/wait |
|---------|-------------|-----------|
| **Model** | Event loop (cooperative) | Worker threads |
| **Best for** | I/O-bound work through an async API (HTTP, DB, files) | Overlapping *blocking* calls that release the GIL (blocking I/O clients, native/C extensions) |
| **Blocking** | Non-blocking -- yields to event loop | Each task gets its own thread; a blocked thread lets others run |
| **Parallel CPU?** | No (single thread) | No for pure-Jac work -- the GIL serializes it; use processes for that |
| **Scalability** | Thousands of concurrent tasks | Limited by thread pool size |
| **Syntax** | `async def` / `await` | `flow` / `wait` |
| **Use when** | Waiting on external services via async libraries | Overlapping blocking calls with no async equivalent |

In practice, many applications use both: `async/await` for the I/O layer served by async libraries, and `flow/wait` to overlap blocking calls that lack an async API. Neither speeds up pure-Jac CPU work under the GIL -- reach for separate processes when you need true CPU parallelism.

---

## Learn More

**Related Reference:**

- [Control Flow](control-flow.md) - Conditionals, loops, pattern matching
- [byLLM Reference](../plugins/byllm.md) - Async LLM calls
