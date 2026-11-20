---
description: The native threading, queue, concurrent.futures, contextvars, sched and _thread modules - threads of the program's own, the locks and queues they share, thread pools and futures, context variables and a scheduler - how threads take turns, and the native ways to run code in parallel.
keywords: threading, threading.Thread, threading.Lock, threading.RLock, threading.Condition, threading.Semaphore, threading.Event, threading.Barrier, threading.Timer, threading.local, threads, multithreading, queue, queue.Queue, queue.SimpleQueue, queue.LifoQueue, queue.PriorityQueue, queue.Empty, queue.Full, queue.ShutDown, concurrent, concurrent.futures, ThreadPoolExecutor, concurrent.futures.Future, as_completed, contextvars, contextvars.ContextVar, contextvars.Context, copy_context, sched, sched.scheduler, _thread
---
# threading, queue and concurrent.futures

Six native modules start threads and let them work together, each with the names and behavior of
CPython 3.15's module of the same name (see [The library](index.md), `jac docs library`):

| Module | What it has |
|---|---|
| `threading` | `Thread`, `Timer`, `Lock`, `RLock`, `Condition`, `Semaphore`, `BoundedSemaphore`, `Event`, `Barrier`, `local`, and the functions that name the threads running |
| `queue` | `Queue`, `LifoQueue`, `PriorityQueue` and `SimpleQueue`, which hand items from thread to thread |
| `concurrent.futures` | `ThreadPoolExecutor`, `Future`, `wait`, `as_completed` |
| `contextvars` | `ContextVar`, `Context`, `Token`, `copy_context` |
| `sched` | `scheduler`, a queue of events run in the order of their times |
| `_thread` | What `threading` is written over: `start_new_thread`, `allocate_lock`, `get_ident` |

A program that imports them has no CPython in it: the threads are the system's own, started by
the program's runtime.

```jac
import threading;
import queue;
import from concurrent.futures { ThreadPoolExecutor }

glob results: list[int] = [],
     lock: threading.Lock = threading.Lock();

def work(n: int) -> None {
    with lock {
        results.append(n * n);
    }
}

def consume(jobs: queue.Queue[int | None], totals: list[int]) -> None {
    total = 0;
    while True {
        job = jobs.get();
        if job is None {
            break;
        }
        total += job;
        jobs.task_done();
    }
    totals.append(total);
}

def cube(n: int) -> int {
    return n * n * n;
}

with entry {
    threads = [threading.Thread(target=work, args=(i,), name=f"square-{i}") for i in range(4)];
    for t in threads {
        t.start();
    }
    for t in threads {
        t.join();
    }
    print(sorted(results), threads[0].name, threads[0].is_alive());
    jobs: queue.Queue[int | None] = queue.Queue(maxsize=2);
    totals: list[int] = [];
    consumer = threading.Thread(target=consume, args=(jobs, totals));
    consumer.start();
    for n in range(10) {
        jobs.put(n);
    }
    jobs.join();
    jobs.put(None);
    consumer.join();
    print(totals, jobs.qsize());
    with ThreadPoolExecutor(max_workers=3) as pool {
        future = pool.submit(cube, 5);
        print(list(pool.map(cube, [1, 2, 3])), future.result());
    }
    done = threading.Event();
    timer = threading.Timer(0.01, done.set);
    timer.start();
    print(done.wait(5.0), threading.current_thread().name, threading.main_thread().name);
    timer.join();
    print(threading.active_count());
}
```

```output
[0, 1, 4, 9] square-0 False
[45] 0
[1, 8, 27] 125
True MainThread MainThread
1
```

## How threads take turns

Threads run Jac code one at a time, as CPython's run Python under its GIL. Each thread holds one
lock of the runtime while it runs, and gives it up:

- while it waits: for a `Lock`, a `Condition`, a `Queue` or a `join`; in `time.sleep`; in a read
  or a write of a file, a pipe or a socket; in `select`; for a child process;
- at its loops, when another thread is waiting for its turn.

So what a thread does between two such points is one step to every other thread: an operation of
a builtin type (`xs.append(x)`, `d[k] = v`, `n += 1`) is never seen half done. A sequence of
steps (read a global, then write it) still needs a `Lock`, as in Python.

Threads make a program that waits on several things at once simpler and faster: connections,
child processes, timers. They do not make computing faster, since one thread computes at a time.
For that, see [Running in parallel](#running-in-parallel).

As the program ends, the threads that are not daemons are waited for, then the functions
`atexit` registered run. A thread's uncaught exception is reported on stderr by
`threading.excepthook`, with its traceback, and ends that thread only.

## threading

| Name | What it is |
|---|---|
| `Thread(group=None, target=None, name=None, args=(), kwargs=None, *, daemon=None, context=None)` | A thread: `start`, `run`, `join(timeout=None)`, `is_alive`, `name`, `ident`, `native_id`, `daemon`. A subclass overrides `run` |
| `Timer(interval, function, args=None, kwargs=None)` | A thread that calls `function` after `interval` seconds, unless `cancel()` comes first |
| `Lock`, `RLock` | A lock one thread holds at a time, and one its holder may take again: `acquire(blocking=True, timeout=-1)`, `release`, `locked`, `with` |
| `Condition(lock=None)` | `wait(timeout=None)`, `wait_for(predicate, timeout=None)`, `notify(n=1)`, `notify_all`, with its lock held |
| `Semaphore(value=1)`, `BoundedSemaphore(value=1)` | A counter `acquire` takes from and `release(n=1)` gives to |
| `Event` | A flag: `set`, `clear`, `is_set`, `wait(timeout=None)` |
| `Barrier(parties, action=None, timeout=None)` | A point threads `wait` at until all are there; `reset`, `abort`, `BrokenBarrierError` |
| `local` | An object whose attributes each thread has its own of |
| `current_thread`, `main_thread`, `enumerate`, `active_count`, `get_ident`, `get_native_id` | The threads running |
| `excepthook`, `ExceptHookArgs`, `stack_size`, `TIMEOUT_MAX`, `ThreadError` | As CPython's |
| `serialize_iterator`, `synchronized_iterator`, `concurrent_tee` | Python 3.15's iterators shared between threads |

The messages are CPython's: starting a thread twice raises
`RuntimeError: threads can only be started once`, releasing a lock that is not held
`RuntimeError: release unlocked lock`, and waiting on a condition whose lock is not held
`RuntimeError: cannot wait on un-acquired lock`.

A thread starts in an empty `contextvars.Context` unless `context=` gives it one, as in CPython.

## queue

`Queue(maxsize=0)` is first in, first out; `LifoQueue` gives the last item first, and
`PriorityQueue` the lowest. `put(item, block=True, timeout=None)` waits for room and
`get(block=True, timeout=None)` for an item, raising `Full` and `Empty` when the time runs out;
`task_done` and `join` count the items worked through, and `shutdown(immediate=False)` makes
both raise `ShutDown`. `SimpleQueue` is an unbounded queue with `put`, `get`, `empty` and
`qsize` only. A queue is written with the type of its items: `queue.Queue[int]`.

## concurrent.futures

`ThreadPoolExecutor(max_workers=None, thread_name_prefix="", initializer=None, initargs=())`
runs calls on a pool of threads: `submit(fn, *args, **kwargs)` gives a `Future`,
`map(fn, *iterables, timeout=None, chunksize=1, buffersize=None)` the results in order, and
`shutdown(wait=True, cancel_futures=False)`, or leaving its `with` block, ends it. A `Future`
has `result(timeout=None)`, `exception`, `done`, `running`, `cancel`, `cancelled` and
`add_done_callback`; `wait(fs, timeout=None, return_when=ALL_COMPLETED)` and
`as_completed(fs, timeout=None)` wait for several. `result()` raises what the call raised.

## contextvars and sched

A `ContextVar` holds a value for the current context: each thread has its own, and
`Context.run` makes another current for one call. `sched.scheduler(timefunc, delayfunc)` runs
events at their times, by `time.monotonic` and `time.sleep` unless given others, so a clock of
the program's own schedules too:

```jac
import contextvars;
import queue;
import sched;
import threading;

glob request: contextvars.ContextVar[str] = contextvars.ContextVar("request", default="none"),
     clock: float = 0.0;

def show(label: str) -> None {
    print(label, request.get());
}

def now -> float {
    return clock;
}

def advance(delay: float) -> None {
    clock += delay;
}

def at(what: str) -> None {
    print(what, "at", clock);
}

with entry {
    token = request.set("first");
    saved = contextvars.copy_context();
    request.set("second");
    saved.run(show, "in the copy:");
    show("here:");
    request.reset(token);
    t = threading.Thread(target=show, args=("in a new thread:",));
    t.start();
    t.join();
    print(request.get(), saved[request], len(saved));
    s = sched.scheduler(now, advance);
    s.enter(5.0, 1, at, ("backup",));
    late = s.enter(9.0, 1, at, ("never",));
    s.enter(2.0, 2, at, ("report",));
    s.enter(2.0, 1, at, ("rotate",));
    s.cancel(late);
    print(len(s.queue), s.run(), s.empty());
    lifo: queue.LifoQueue[str] = queue.LifoQueue();
    ranked: queue.PriorityQueue[tuple[int, str]] = queue.PriorityQueue();
    for (n, word) in [(2, "b"), (1, "a"), (3, "c")] {
        lifo.put(word);
        ranked.put((n, word));
    }
    print(lifo.get(), ranked.get(), ranked.qsize());
    try {
        lifo.get(timeout=0.01);
        lifo.get(timeout=0.01);
        lifo.get(block=False);
    } except queue.Empty {
        print("Empty");
    }
}
```

```output
in the copy: first
here: second
in a new thread: none
none first 1
rotate at 2.0
report at 2.0
backup at 5.0
3 None True
c (1, 'a') 2
Empty
```

| Name | What it is |
|---|---|
| `ContextVar(name, *, default)` | `get(default)`, `set(value)` giving a `Token`, `reset(token)`, `name`; `get` with no value and no default raises `LookupError` |
| `Token` | `var`, `old_value`, `Token.MISSING`; used once, by `reset` or as a context manager (a second time raises `RuntimeError`) |
| `Context`, `copy_context()` | A mapping of variables to values: `run(callable, *args, **kwargs)`, `copy`, `get`, indexing, `in`, `len`, iteration, `keys`, `values`, `items` |
| `sched.scheduler(timefunc=time.monotonic, delayfunc=time.sleep)` | `enter(delay, priority, action, argument=(), kwargs={})`, `enterabs(time, ...)`, `cancel(event)`, `empty`, `run(blocking=True)`, `queue`; `run(blocking=False)` runs what is due and returns the delay until the next event |
| `sched.Event` | An event: `time`, `priority`, `sequence`, `action`, `argument`, `kwargs`, ordered by time and then priority |

## Differences from CPython

- **`threading.settrace`, `setprofile` and their `_all_threads` forms are left out** (E5142):
  they hook the tracing of Python frames, which a native program does not have. `gettrace()` and
  `getprofile()` return `None`.
- **`concurrent.futures.ProcessPoolExecutor` and `InterpreterPoolExecutor` are left out**
  (E5142): they send Python functions to other processes and interpreters by pickling them. Use
  `ThreadPoolExecutor` or [`flow`](../language/async.md#tasks-flow-and-wait) for calls that
  wait, `flow for` for work on the processors, or [subprocess](subprocess.md) for another
  program.
- **`threading.serialize_iterator` has no `send`** (E5142): a Jac generator takes no value. Its
  `throw` and `close` reach the generator it wraps, one thread at a time.
- **A `ThreadPoolExecutor` dropped without `shutdown()` keeps its threads until the program
  ends**, when they are stopped and joined; CPython's end when the executor is collected. Use
  `with`, or call `shutdown()`.
- **A thread's target is called with the types it declares.** `args` holding a value of
  another type raises `TypeError: expected int, found str` in the thread, as a call through any
  function value does.
- **A `collections.deque` shared between threads needs a `Lock`.** Its `append` and `popleft`
  are not yet one step to other threads, as CPython's are. `queue.Queue` and `queue.SimpleQueue`
  are made to be shared.

```jac
# expect: E5142
import from concurrent.futures { ProcessPoolExecutor }

with entry {
    print("unreachable");
}
```

## Running in parallel

To run Jac code on several processors at once, use the language's own forms:

| Form | What it does | Page |
|---|---|---|
| `flow for` | Runs a loop's iterations in chunks on a pool of threads (`JAC_THREADS` wide, 4 unless set) and joins them before the loop ends; the compiler checks what the body may touch | [Control flow](../language/control-flow.md), [Parallel loops over tensors](../accel/parallel-loops.md) |
| `atomics.Atomic[T]` | An integer that threads change in one step | [Atomics](../language/numbers-atomics.md) (`jac docs atomics`) |

`JAC_THREADS` is described with the other environment variables in
[Environment](../reference/environment.md) (`jac docs JAC_THREADS`).

## Python's threads

`importlib.import_module("threading")` is CPython's `threading`, in a program that embeds
CPython: its threads are Python's, and may call Jac functions, which then take turns under the
same lock. See [Python values](../interop/python-values.md)
(`jac docs interop/python-values`).

## Where to go next

- Sockets and servers, which threads usually wait on: [socket](socket.md).
- Tasks of one thread, which take turns at each `await`: [asyncio](asyncio.md).
- Child processes: [subprocess](subprocess.md).
- Every native module: [Standard-library modules](stdlib.md).
