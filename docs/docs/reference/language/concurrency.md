# Part VI: Concurrency

**In this part:**

- [Async/Await](#asyncawait) - Async functions, async walkers, async for
- [Concurrent Expressions](#concurrent-expressions) - flow/wait for parallel tasks

---

Most real-world applications need to do multiple things at once -- fetching data from several APIs, processing independent tasks in parallel, or keeping a UI responsive while background work runs. Jac provides two distinct concurrency models to handle these scenarios:

1. **`async/await`** -- cooperative concurrency on a single-threaded event loop, ideal for I/O-bound work like HTTP requests, database queries, and file operations. Tasks voluntarily yield control while waiting, allowing other tasks to progress. This is the same model used by Python's `asyncio`, JavaScript's promises, and Rust's `async` -- if you've used any of those, the concepts transfer directly.

2. **`flow/wait`** -- parallel execution using a thread pool, suited for CPU-bound work and cases where you want true simultaneous execution. `flow` launches a function as a background task and immediately returns a future; `wait` blocks until the result is available. Think of it as structured, explicit parallelism -- you control exactly when work starts and when you synchronize.

The key distinction: `async/await` multiplexes tasks on one thread (cooperative), while `flow/wait` runs tasks on separate threads (parallel). Choose `async` when your bottleneck is waiting for external services, and `flow` when your bottleneck is computation.

## Async/Await

!!! note
    Async functions must be `await`ed in an async context. In `with entry` blocks, use `await` directly or wrap calls in an async ability.

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

The `flow/wait` pattern provides explicit concurrency control for running functions in parallel on a thread pool. Unlike `async/await` (which is cooperative and single-threaded), `flow` dispatches work to separate threads, making it suitable for CPU-bound computations that benefit from true parallelism.

The mental model is simple: `flow` says "start this work now, in the background" and hands you a future (a handle to the pending result). `wait` says "I need the result now" and blocks until it's ready. Between `flow` and `wait`, you're free to do other work -- or launch more `flow` tasks -- making it easy to overlap independent operations.

### 1 flow Keyword

The `flow` keyword launches a function call as a background task and returns a future immediately. The function runs on a separate thread, so it truly executes in parallel with your main code. Use it when you have independent operations -- such as computations, file processing, or data transformations -- that don't depend on each other's results.

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

The real power of `flow/wait` emerges when you launch multiple tasks simultaneously. Each `flow` call starts a new background task immediately, so all tasks run concurrently. You then collect results with `wait` -- the total wall-clock time is roughly the duration of the slowest task, not the sum of all tasks.

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
| **Model** | Event loop (cooperative) | Thread pool (parallel) |
| **Best for** | I/O-bound work (HTTP, DB, files) | CPU-bound work (computation, data processing) |
| **Blocking** | Non-blocking -- yields to event loop | Can block threads -- each task gets its own thread |
| **Scalability** | Thousands of concurrent tasks | Limited by thread pool size |
| **Syntax** | `async def` / `await` | `flow` / `wait` |
| **Use when** | Waiting on external services | Crunching numbers or processing data |

In practice, many applications use both: `async/await` for the I/O layer (API calls, database queries) and `flow/wait` for compute-heavy operations that benefit from parallelism.

---

## Learn More

**Related Reference:**

- [Part I: Foundation](foundation.md) - Control flow basics
- [Part V: AI Integration](../plugins/byllm.md) - Async LLM calls
