---
description: The native asyncio package - the event loop, run and Runner, tasks and futures, gather, wait, timeouts and task groups, to_thread, the locks and queues tasks share, streams, transports and protocols, servers, subprocesses and signal handlers - with how it differs from CPython's, what each platform has and what is not written yet.
keywords: asyncio, asyncio.run, asyncio.Runner, asyncio.sleep, asyncio.create_task, asyncio.Task, asyncio.Future, asyncio.gather, asyncio.wait, asyncio.wait_for, asyncio.as_completed, asyncio.shield, asyncio.timeout, asyncio.timeout_at, asyncio.TaskGroup, TaskGroup, asyncio.to_thread, asyncio.run_coroutine_threadsafe, asyncio.get_running_loop, asyncio.new_event_loop, asyncio.AbstractEventLoop, asyncio.CancelledError, asyncio.Lock, asyncio.Event, asyncio.Condition, asyncio.Semaphore, asyncio.BoundedSemaphore, asyncio.Barrier, asyncio.Queue, asyncio.PriorityQueue, asyncio.LifoQueue, asyncio.QueueEmpty, asyncio.QueueFull, asyncio.QueueShutDown, asyncio.staggered, run_until_complete, call_soon, call_later, asyncio.streams, asyncio.open_connection, asyncio.start_server, asyncio.open_unix_connection, asyncio.start_unix_server, asyncio.StreamReader, asyncio.StreamWriter, asyncio.Server, asyncio.IncompleteReadError, asyncio.LimitOverrunError, asyncio.Protocol, asyncio.DatagramProtocol, asyncio.BufferedProtocol, asyncio.SubprocessProtocol, asyncio.Transport, asyncio.DatagramTransport, asyncio.protocols, asyncio.transports, asyncio.subprocess, asyncio.create_subprocess_exec, asyncio.create_subprocess_shell, asyncio.sslproto, asyncio.trsock, asyncio.SelectorEventLoop, loop.create_connection, loop.create_server, loop.create_datagram_endpoint, loop.start_tls, loop.add_signal_handler, loop.sock_recv, loop.sock_sendall
---
# asyncio

The `asyncio` package is native: an event loop written in Jac, with the names and behavior of
CPython 3.15's (see [The library](index.md), `jac docs library`). A coroutine, the call of an
`async def` function ([Async](../language/async.md), `jac docs async`), runs as a task of the
loop, which resumes it when what it awaits is done. A program that imports `asyncio` has no
CPython in it.

| Part | What it has |
|---|---|
| Running | `run`, `Runner`, `new_event_loop`, `get_running_loop`, `get_event_loop`, `set_event_loop`, and the loop itself: `AbstractEventLoop`, `BaseEventLoop`, `SelectorEventLoop`, `EventLoop` |
| Tasks and futures | `Task`, `Future`, `create_task`, `ensure_future`, `current_task`, `all_tasks`, `sleep`, `isfuture`, `wrap_future` |
| Waiting | `gather`, `wait`, `wait_for`, `as_completed`, `shield`, `timeout`, `timeout_at`, `TaskGroup` |
| Threads | `to_thread`, `run_coroutine_threadsafe`, and the loop's `run_in_executor` and `call_soon_threadsafe` |
| Locks | `Lock`, `Event`, `Condition`, `Semaphore`, `BoundedSemaphore`, `Barrier` |
| Queues | `Queue`, `PriorityQueue`, `LifoQueue`, `QueueEmpty`, `QueueFull`, `QueueShutDown` |
| Streams | `open_connection`, `start_server`, `StreamReader`, `StreamWriter`, `StreamReaderProtocol`, `Server`, and on Linux and macOS `open_unix_connection` and `start_unix_server` |
| Transports and protocols | `Protocol`, `BufferedProtocol`, `DatagramProtocol`, `SubprocessProtocol`, `Transport` and its bases, `DatagramTransport`, `SubprocessTransport`, and the loop's `create_connection`, `create_server`, `create_datagram_endpoint`, `start_tls`, `sendfile` and `sock_*` methods |
| Subprocesses | `create_subprocess_exec`, `create_subprocess_shell`, and `asyncio.subprocess`'s `Process`, `PIPE`, `STDOUT` and `DEVNULL`, on Linux and macOS |
| Exceptions | `CancelledError`, `InvalidStateError`, `TimeoutError` (the builtin), `BrokenBarrierError`, `IncompleteReadError`, `LimitOverrunError`, `SendfileNotAvailableError` |

The package builds for Linux, macOS and Windows. Subprocesses, pipes, signal handlers and Unix
sockets are for Linux and macOS: see [Platforms](#platforms).

```jac
import asyncio;

async def tick(name: str, n: int) -> str {
    for i in range(n) {
        print(name, i);
        await asyncio.sleep(0);
    }
    return name;
}

def square(n: int) -> int {
    return n * n;
}

async def main -> str {
    both = await asyncio.gather(tick("a", 2), tick("b", 2));
    print(both);
    task = asyncio.create_task(tick("c", 1), name="ticker");
    print(task.get_name(), task.done());
    print(await task, task.done(), task.result());
    async with asyncio.TaskGroup() as group {
        x = group.create_task(tick("x", 1));
        y = group.create_task(tick("y", 1));
    }
    print(x.result(), y.result());
    print(await asyncio.to_thread(square, 12));
    try {
        await asyncio.wait_for(asyncio.sleep(30), timeout=0.01);
    } except TimeoutError {
        print("timed out");
    }
    return "done";
}

with entry {
    print(asyncio.run(main()));
}
```

```output
a 0
b 0
a 1
b 1
['a', 'b']
ticker False
c 0
c True c
x 0
y 0
x y
144
timed out
done
```

`asyncio.run(main())` makes a loop, runs `main()` in it to its end, cancels the tasks still
pending, closes the loop and returns what `main()` returned. `await asyncio.sleep(0)` lets the
loop's other tasks take a step, which is how `a` and `b` interleave above.

## How the loop runs

The loop runs in one thread, the one that called `run`. It keeps a queue of callbacks that are
ready and a heap of timers; one turn of it waits for the next timer or for a descriptor to be
ready, with a selector of [selectors](socket.md) (`epoll` on Linux, `kqueue` on macOS, `select`
on Windows), then runs what is due. A task is such a callback: each of its steps runs its
coroutine to the next `await` of something not done yet.

So tasks take turns only at an `await`, and code between two of them is one step to every other
task. A call that waits without `await` (`time.sleep`, a blocking read, a long computation)
holds the whole loop: hand it to a thread with `to_thread`. While the loop waits, the program's
other threads run ([threading](threading.md)).

The loop's interface names `ssl`'s contexts, so a program that imports `asyncio` loads OpenSSL
where it runs on Linux, as one that imports `ssl` does
([Platform limits](stdlib.md#platform-limits)).

## Running a coroutine

| Name | What it is |
|---|---|
| `run(main, *, debug=None, loop_factory=None)` | Runs the coroutine `main` in a new loop and returns its result. Called while a loop is running in the thread, it raises `RuntimeError` |
| `Runner(*, debug=None, loop_factory=None)` | A loop kept for several calls: `run(coro, *, context=None)`, `get_loop()`, `close()`, `with` |
| `new_event_loop()`, `get_running_loop()`, `get_event_loop()`, `set_event_loop(loop)` | A loop of the program's own, the loop running in this thread (`RuntimeError: no running event loop` outside one), and the thread's current loop |
| `sleep(delay, result=None)` | Waits `delay` seconds and gives `result`; `sleep(0)` gives way for one turn of the loop |

The loop's own methods are CPython's:

| Method | What it does |
|---|---|
| `run_until_complete(future)`, `run_forever()`, `stop()`, `close()`, `is_running()`, `is_closed()` | Run the loop until a future or a coroutine is done, or until `stop()`; close it |
| `call_soon(callback, *args, context=None)`, `call_later(delay, callback, *args)`, `call_at(when, callback, *args)`, `time()` | Schedule a call, giving a `Handle` or a `TimerHandle` with `cancel()`, `cancelled()` and `when()`; the loop's clock |
| `create_future()`, `create_task(coro, *, name=None, context=None)`, `set_task_factory(factory)`, `get_task_factory()` | Futures and tasks of this loop |
| `call_soon_threadsafe(callback, *args)`, `run_in_executor(executor, func, *args)`, `set_default_executor(executor)`, `shutdown_default_executor(timeout=None)` | The calls other threads make, and calls handed to a `concurrent.futures` executor |
| `add_reader(fd, callback, *args)`, `remove_reader(fd)`, `add_writer(fd, callback, *args)`, `remove_writer(fd)` | A callback for when a descriptor, or a socket, can be read or written |
| `set_exception_handler(handler)`, `get_exception_handler()`, `call_exception_handler(context)`, `default_exception_handler(context)`, `set_debug(enabled)`, `get_debug()` | What happens to an exception a callback raises (logged to the `asyncio` logger unless a handler is set), and debug mode |

Its methods for connections and servers are under
[Transports and protocols](#transports-and-protocols), and those for child processes and
signals under [Subprocesses and signals](#subprocesses-and-signals).

```jac
import asyncio;
import threading;

glob steps: list[str] = [];

def note(what: str) -> None {
    steps.append(what);
}

def add(a: int, b: int) -> int {
    return a + b;
}

async def answer -> int {
    await asyncio.sleep(0);
    return 42;
}

async def with_threads -> None {
    loop = asyncio.get_running_loop();
    print(await loop.run_in_executor(None, add, 2, 3), await asyncio.to_thread(add, 4, 5));
    told = loop.create_future();

    def tell -> None {
        loop.call_soon_threadsafe(told.set_result, "from a thread");
    }

    t = threading.Thread(target=tell);
    t.start();
    print(await told);
    t.join();
    asked = loop.create_future();

    def ask -> None {
        reply = asyncio.run_coroutine_threadsafe(answer(), loop).result(30);
        loop.call_soon_threadsafe(asked.set_result, reply);
    }

    t = threading.Thread(target=ask);
    t.start();
    print(await asked);
    t.join();
}

with entry {
    loop = asyncio.new_event_loop();
    loop.call_soon(note, "first");
    late = loop.call_later(30, note, "never");
    loop.call_later(0.01, note, "later");
    loop.call_later(0.02, loop.stop);
    late.cancel();
    loop.run_forever();
    print(steps, late.cancelled(), loop.is_running());
    print(loop.run_until_complete(answer()));
    loop.close();
    print(loop.is_closed());
    with asyncio.Runner() as runner {
        print(runner.run(answer()), runner.run(answer()) + 1);
        runner.run(with_threads());
    }
}
```

```output
['first', 'later'] True False
42
True
42 43
5 9
from a thread
42
```

A loop is not shared between threads. Another thread reaches it with
`loop.call_soon_threadsafe(callback, *args)`, which also wakes the loop, or with
`run_coroutine_threadsafe(coro, loop)`, which gives a `concurrent.futures.Future` to wait on.
`to_thread(func, *args, **kwargs)` goes the other way: it runs a blocking call on a thread of
the loop's default executor, with a copy of the current context, and awaits its result.

## Tasks and futures

A `Future` is a result the loop will have later; a `Task` is a future that runs a coroutine.
`await` of either waits for it and gives its result, or raises what it raised.

| Name | What it is |
|---|---|
| `create_task(coro, *, name=None, context=None, eager_start=None)` | A task of the running loop, started at the loop's next turn (at once with `eager_start=True`) |
| `Task` | `result()`, `exception()`, `done()`, `cancel(msg=None)`, `cancelled()`, `cancelling()`, `uncancel()`, `add_done_callback(fn)`, `remove_done_callback(fn)`, `get_name()`, `set_name(name)`, `get_coro()`, `get_context()`, `get_loop()` |
| `Future` | The same without the task's own: `set_result(value)`, `set_exception(exception)`, `result()`, `exception()`, `done()`, `cancel(msg=None)`, `cancelled()`, the callbacks, `get_loop()`. Made by `loop.create_future()` |
| `ensure_future(coro_or_future)`, `isfuture(obj)`, `wrap_future(future)` | A coroutine as a task; whether a value is a future; a `concurrent.futures.Future` as a future of the loop |
| `current_task()`, `all_tasks()` | The task running, and the tasks not done yet |
| `eager_task_factory`, `create_eager_task_factory(constructor)` | Task factories whose tasks start as they are made |

`task.cancel()` raises `CancelledError` in the task's coroutine at the `await` it is paused at.
A coroutine that catches it to clean up raises it again; the task then ends cancelled, and
awaiting it raises `CancelledError` too. The messages are CPython's: `result()` of a future
that is not done raises `InvalidStateError: Result is not set.`, and setting a task's result
`RuntimeError: Task does not support set_result operation`.

## Waiting for several

| Name | What it does |
|---|---|
| `gather(*coros_or_futures, return_exceptions=False)` | Runs them together and gives their results in the order given. The first exception is raised to the awaiter, or, with `return_exceptions=True`, takes its place among the results |
| `wait(fs, *, timeout=None, return_when=ALL_COMPLETED)` | Waits for tasks or futures and gives two sets, `(done, pending)`; `return_when` is `FIRST_COMPLETED`, `FIRST_EXCEPTION` or `ALL_COMPLETED`. It raises nothing and cancels nothing when the time runs out |
| `wait_for(fut, timeout)` | Waits for one, cancelling it and raising `TimeoutError` when the time runs out |
| `as_completed(fs, *, timeout=None)` | Gives them as they finish: the futures themselves to `async for`, coroutines to await to a plain `for` |
| `shield(arg)` | Awaits a task that a cancellation of the awaiter does not reach |
| `timeout(delay)`, `timeout_at(when)` | An `async with` block cancelled and ended with `TimeoutError` when its time runs out; the `Timeout` has `when()`, `reschedule(when)` and `expired()` |
| `TaskGroup()` | An `async with` block whose tasks, made with its `create_task`, are all waited for as it ends. When one fails, the others and the block are cancelled, and the errors leave the block together as an `ExceptionGroup` |

```jac
import asyncio;

async def nap(name: str, seconds: float) -> str {
    try {
        await asyncio.sleep(seconds);
    } except asyncio.CancelledError {
        print(name, "was cancelled");
        raise;
    }
    return name;
}

async def fail(what: str) -> str {
    await asyncio.sleep(0);
    raise ValueError(what);
}

def names(tasks: set[asyncio.Task[any]]) -> list[str] {
    return sorted([t.get_name() for t in tasks]);
}

async def main -> None {
    quick: asyncio.Task[any] = asyncio.create_task(nap("quick", 0.01), name="quick");
    slow: asyncio.Task[any] = asyncio.create_task(nap("slow", 30), name="slow");
    (done, pending) = await asyncio.wait([quick, slow], return_when=asyncio.FIRST_COMPLETED);
    print(names(done), names(pending), quick.result());
    slow.cancel();
    try {
        await slow;
    } except asyncio.CancelledError {
        print(slow.cancelled(), slow.done());
    }
    results = await asyncio.gather(nap("kept", 0), fail("bad"), return_exceptions=True);
    print([repr(r) for r in results]);
    try {
        async with asyncio.timeout(0.01) {
            await nap("under a timeout", 30);
        }
    } except TimeoutError {
        print("TimeoutError");
    }
    order: list[str] = [];
    async for first in asyncio.as_completed([nap("later", 0.05), nap("sooner", 0)]) {
        order.append(first.result());
    }
    print(order);
    inner = asyncio.create_task(nap("shielded", 0.01));
    outer = asyncio.shield(inner);
    await asyncio.sleep(0);
    print(outer.cancel(), inner.cancelled(), await inner);
    try {
        async with asyncio.TaskGroup() as group {
            group.create_task(fail("first"));
            group.create_task(nap("in the group", 30));
        }
    } except ExceptionGroup as eg {
        print(eg.message, [repr(e) for e in eg.exceptions]);
    }
}

with entry {
    asyncio.run(main());
}
```

```output
['quick'] ['slow'] quick
slow was cancelled
True True
["'kept'", "ValueError('bad')"]
under a timeout was cancelled
TimeoutError
['sooner', 'later']
True False shielded
in the group was cancelled
unhandled errors in a TaskGroup ["ValueError('first')"]
```

## Locks and queues

They are for the tasks of one loop, not for threads: a task that has to wait is paused at its
`await` and woken in the order it came. Threads share a `threading.Lock` and a `queue.Queue`
([threading](threading.md)).

| Name | What it is |
|---|---|
| `Lock` | `await acquire()`, `release()`, `locked()`, `async with` |
| `Event` | `set()`, `clear()`, `is_set()`, `await wait()` |
| `Condition(lock=None)` | `await wait()`, `await wait_for(predicate)`, `notify(n=1)`, `notify_all()`, with its lock held |
| `Semaphore(value=1)`, `BoundedSemaphore(value=1)` | A counter `await acquire()` takes from and `release()` gives to; the bounded one raises `ValueError` when released past its start |
| `Barrier(parties)` | `await wait()` holds tasks until `parties` of them are there; `await reset()`, `await abort()`, `parties`, `n_waiting`, `broken`, `BrokenBarrierError` |
| `Queue(maxsize=0)`, `PriorityQueue`, `LifoQueue` | `await put(item)` waits for room and `await get()` for an item; `put_nowait` and `get_nowait` raise `QueueFull` and `QueueEmpty` instead; `qsize`, `empty`, `full`, `maxsize`, `task_done`, `await join()`, and `shutdown(immediate=False)`, after which both raise `QueueShutDown` |

A queue is written with the type of its items: `asyncio.Queue[int](maxsize=2)`.

```jac
import asyncio;

async def worker(
    name: str, jobs: asyncio.Queue[int], gate: asyncio.Semaphore, log: list[str]
) -> None {
    while True {
        job = await jobs.get();
        async with gate {
            await asyncio.sleep(0);
            log.append(f"{name}:{job}");
        }
        jobs.task_done();
    }
}

async def waiter(ready: asyncio.Event, lock: asyncio.Lock, log: list[str]) -> None {
    await ready.wait();
    async with lock {
        log.append("waiter has the lock");
    }
}

async def main -> None {
    jobs = asyncio.Queue[int](maxsize=2);
    gate = asyncio.Semaphore(1);
    log: list[str] = [];
    workers = [asyncio.create_task(worker(f"w{i}", jobs, gate, log)) for i in range(2)];
    for job in range(5) {
        await jobs.put(job);
    }
    await jobs.join();
    print(log, jobs.qsize(), jobs.empty());
    for w in workers {
        w.cancel();
    }
    print(await asyncio.gather(*workers, return_exceptions=True));
    ready = asyncio.Event();
    lock = asyncio.Lock();
    log.clear();
    t = asyncio.create_task(waiter(ready, lock, log));
    async with lock {
        ready.set();
        await asyncio.sleep(0);
        log.append(f"main holds it: {lock.locked()}");
    }
    await t;
    print(log, lock.locked(), ready.is_set());
    ranked = asyncio.PriorityQueue[tuple[int, str]]();
    for item in [(2, "build"), (1, "fetch"), (3, "test")] {
        ranked.put_nowait(item);
    }
    print(await ranked.get(), ranked.qsize());
    try {
        asyncio.Queue[int]().get_nowait();
    } except asyncio.QueueEmpty {
        print("QueueEmpty");
    }
}

with entry {
    asyncio.run(main());
}
```

```output
['w0:0', 'w1:1', 'w0:2', 'w1:3', 'w0:4'] 0 True
[CancelledError(''), CancelledError('')]
['main holds it: True', 'waiter has the lock'] False True
(1, 'fetch') 2
QueueEmpty
```

## Streams

A stream is a connection read and written with coroutines: `open_connection` and `start_server`
give a `StreamReader`, whose reads wait for the bytes to arrive, and a `StreamWriter`.

| Name | What it is |
|---|---|
| `open_connection(host=None, port=None, *, limit=65536, **kwds)` | Connects, and gives `(reader, writer)`. The other keywords are `loop.create_connection`'s: `ssl`, `sock`, `family`, `local_addr`, `server_hostname`, ... |
| `start_server(client_connected_cb, host=None, port=None, *, limit=65536, **kwds)` | Listens, and gives a `Server`. `client_connected_cb(reader, writer)` is called for each client that connects: a plain function, or an `async def`, whose coroutine the loop runs as a task. The other keywords are `loop.create_server`'s |
| `open_unix_connection(path=None, *, limit=65536, **kwds)`, `start_unix_server(client_connected_cb, path=None, *, limit=65536, **kwds)` | The same over a Unix socket, on Linux and macOS |
| `StreamReader` | `await read(n=-1)`, `await readline()`, `await readexactly(n)`, `await readuntil(separator=b"\n")`, `async for line in reader`, `at_eof()`, `exception()`; and what feeds it: `feed_data(data)`, `feed_eof()`, `set_exception(exc)`, `set_transport(transport)` |
| `StreamWriter` | `write(data)`, `writelines(data)`, `await drain()`, `write_eof()`, `can_write_eof()`, `close()`, `is_closing()`, `await wait_closed()`, `get_extra_info(name, default=None)`, `transport`, `await start_tls(sslcontext, *, server_hostname=None, ssl_handshake_timeout=None, ssl_shutdown_timeout=None)` |
| `Server` | `sockets`, `is_serving()`, `close()`, `await wait_closed()`, `await start_serving()`, `await serve_forever()`, `close_clients()`, `abort_clients()`, `get_loop()` |

```jac
import asyncio;

async def echo(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None {
    while True {
        line = await reader.readline();
        if not line {
            break;
        }
        writer.write(b"echo: " + line);
        await writer.drain();
    }
    writer.close();
    await writer.wait_closed();
}

async def ask(port: int, words: list[str]) -> list[str] {
    (reader, writer) = await asyncio.open_connection("127.0.0.1", port);
    replies: list[str] = [];
    for word in words {
        writer.write(word.encode() + b"\n");
        await writer.drain();
        replies.append((await reader.readline()).decode().rstrip());
    }
    writer.write(b"no newline");
    writer.write_eof();
    replies.append((await reader.read()).decode());
    writer.close();
    await writer.wait_closed();
    return replies;
}

async def main -> None {
    server = await asyncio.start_server(echo, "127.0.0.1", 0);
    port: int = server.sockets[0].getsockname()[1];
    print(server.is_serving(), len(server.sockets), port > 0);
    print(await ask(port, ["one", "two"]));
    print(await asyncio.gather(ask(port, ["a"]), ask(port, ["b"])));
    server.close();
    await server.wait_closed();
    print(server.is_serving());
    reader = asyncio.StreamReader();
    reader.feed_data(b"head\r\n\r\nbody");
    reader.feed_eof();
    print(await reader.readuntil(b"\r\n\r\n"), await reader.readexactly(2), reader.at_eof());
    try {
        await reader.readexactly(10);
    } except asyncio.IncompleteReadError as e {
        print("IncompleteReadError:", e.partial, e.expected);
    }
}

with entry {
    asyncio.run(main());
}
```

```output
True 1 True
['echo: one', 'echo: two', 'echo: no newline']
[['echo: a', 'echo: no newline'], ['echo: b', 'echo: no newline']]
False
b'head\r\n\r\n' b'bo' False
IncompleteReadError: b'dy' 10
```

`write` only adds to the transport's buffer, and `await writer.drain()` waits while that buffer
is over its limit, so a writer that drains cannot outrun the other side. `read()` with no size
reads to the end of the stream, which the other side marks with `write_eof()` or by closing.
A line or a `readuntil` longer than `limit` raises `ValueError` from `readline` and
`LimitOverrunError` from `readuntil`; a stream that ends first gives `readline` what there
was, and raises `IncompleteReadError`, with the bytes read as its `partial`, from `readuntil`
and `readexactly`.

With `ssl=` an `ssl.SSLContext`, the connection is TLS ([socket](socket.md)): a client's
`open_connection(host, port, ssl=context)`, a server's `start_server(..., ssl=context)`, or
`await writer.start_tls(context)` on a connection that began in plain text.

## Transports and protocols

Under a stream are a transport, which moves the bytes, and a protocol, a class of the program's
whose methods the loop calls as things happen to the connection. The loop's methods make the
pair from a function that gives the protocol:

| Method of the loop | What it does |
|---|---|
| `create_connection(protocol_factory, host=None, port=None, *, ssl=None, family=0, proto=0, flags=0, sock=None, local_addr=None, server_hostname=None, ssl_handshake_timeout=None, ssl_shutdown_timeout=None, happy_eyeballs_delay=None, interleave=None, all_errors=False)` | Connects a stream socket and gives `(transport, protocol)`. A host with several addresses is tried one after another, or with `happy_eyeballs_delay` each a delay after the one before |
| `create_server(protocol_factory, host=None, port=None, *, family=0, flags=AI_PASSIVE, sock=None, backlog=100, ssl=None, reuse_address=None, reuse_port=None, keep_alive=None, ssl_handshake_timeout=None, ssl_shutdown_timeout=None, start_serving=True)` | Listens, on every address of `host` or of each host in a list, and gives a `Server`; each client gets a protocol of its own |
| `create_datagram_endpoint(protocol_factory, local_addr=None, remote_addr=None, *, family=0, proto=0, flags=0, reuse_port=None, allow_broadcast=None, sock=None)` | A datagram socket, bound to `local_addr`, connected to `remote_addr`, or both: `(transport, protocol)` |
| `connect_accepted_socket(protocol_factory, sock, *, ssl=None, ssl_handshake_timeout=None, ssl_shutdown_timeout=None)` | A transport for a socket the program accepted itself |
| `start_tls(transport, protocol, sslcontext, *, server_side=False, server_hostname=None, ssl_handshake_timeout=None, ssl_shutdown_timeout=None)` | Upgrades a connection to TLS and gives the new transport |
| `sendfile(transport, file, offset=0, count=None, *, fallback=True)` | Sends a file opened in binary mode over a transport, with the system's `sendfile` on Linux and macOS, and gives the number of bytes sent |
| `sock_recv(sock, nbytes)`, `sock_recv_into(sock, buf)`, `sock_recvfrom(sock, bufsize)`, `sock_recvfrom_into(sock, buf, nbytes=0)`, `sock_sendall(sock, data)`, `sock_sendto(sock, data, address)`, `sock_connect(sock, address)`, `sock_accept(sock)`, `sock_sendfile(sock, file, offset=0, count=None, *, fallback=True)` | A non-blocking socket's own operations as coroutines, with no transport |
| `getaddrinfo(host, port, *, family=0, type=0, proto=0, flags=0)`, `getnameinfo(sockaddr, flags=0)` | `socket`'s lookups, run on a thread of the default executor |
| `create_unix_connection(protocol_factory, path=None, ...)`, `create_unix_server(protocol_factory, path=None, ...)`, `connect_read_pipe(protocol_factory, pipe)`, `connect_write_pipe(protocol_factory, pipe)` | Unix sockets and pipes, on Linux and macOS |

| Class | What it has |
|---|---|
| `BaseProtocol` | `connection_made(transport)`, `connection_lost(exc)`, `pause_writing()`, `resume_writing()` |
| `Protocol` | And `data_received(data)`, `eof_received()` |
| `BufferedProtocol` | And `get_buffer(sizehint)`, `buffer_updated(nbytes)`, `eof_received()`: the data is read into a buffer of the protocol's |
| `DatagramProtocol` | And `datagram_received(data, addr)`, `error_received(exc)` |
| `SubprocessProtocol` | And `pipe_data_received(fd, data)`, `pipe_connection_lost(fd, exc)`, `process_exited()` |
| `BaseTransport` | `get_extra_info(name, default=None)`, `is_closing()`, `close()`, `set_protocol(protocol)`, `get_protocol()` |
| `ReadTransport`, `WriteTransport`, `Transport` (both) | `is_reading()`, `pause_reading()`, `resume_reading()`; `write(data)`, `writelines(list_of_data)`, `write_eof()`, `can_write_eof()`, `abort()`, `get_write_buffer_size()`, `get_write_buffer_limits()`, `set_write_buffer_limits(high=None, low=None)` |
| `DatagramTransport` | `sendto(data, addr=None)`, `abort()` |
| `SubprocessTransport` | `get_pid()`, `get_returncode()`, `get_pipe_transport(fd)`, `send_signal(signal)`, `terminate()`, `kill()` |

`get_extra_info` knows `"socket"`, `"sockname"` and `"peername"`, and over TLS `"sslcontext"`,
`"ssl_object"`, `"peercert"`, `"cipher"` and `"compression"`. The socket it gives, like those of
`Server.sockets`, is an `asyncio.trsock.TransportSocket`: the socket's state and options, with
no way to read, write or close it under its transport.

```jac
import asyncio;
import socket;

"""A server's side of a connection: it answers what it is sent in upper
case, and closes."""
class Shout(asyncio.Protocol) {
    has transport: asyncio.Transport | None = None;

    override def connection_made(transport: asyncio.BaseTransport) -> None {
        self.transport = transport as asyncio.Transport;
    }

    override def data_received(data: bytes) -> None {
        to = self.transport;
        if to is not None {
            to.write(data.upper());
            to.close();
        }
    }
}

"""A client's side: it keeps what it is sent, and says when the connection
is lost."""
class Listen(asyncio.Protocol) {
    has lost: asyncio.Future[any],
        got: bytearray = bytearray();

    override def data_received(data: bytes) -> None {
        self.got += data;
    }

    override def connection_lost(exc: Exception | None) -> None {
        self.lost.set_result(exc);
    }
}

"""A datagram socket's protocol: it sends each datagram back."""
class Back(asyncio.DatagramProtocol) {
    has transport: asyncio.DatagramTransport | None = None;

    override def connection_made(transport: asyncio.BaseTransport) -> None {
        self.transport = transport as asyncio.DatagramTransport;
    }

    override def datagram_received(data: bytes, addr: any) -> None {
        to = self.transport;
        if to is not None {
            to.sendto(b"back: " + data, addr);
        }
    }
}

async def main -> None {
    loop = asyncio.get_running_loop();
    server = await loop.create_server(
        lambda -> asyncio.BaseProtocol { return Shout(); }, "127.0.0.1", 0
    );
    port: int = server.sockets[0].getsockname()[1];
    client = Listen(lost=loop.create_future());
    (transport, protocol) = await loop.create_connection(
        lambda -> asyncio.BaseProtocol { return client; }, "127.0.0.1", port
    );
    print(protocol is client, transport.get_extra_info("peername") == ("127.0.0.1", port));
    transport.write(b"hello");
    print(await client.lost, bytes(client.got), transport.is_closing());
    server.close();
    await server.wait_closed();
    (answering, _) = await loop.create_datagram_endpoint(
        lambda -> asyncio.BaseProtocol { return Back(); }, local_addr=("127.0.0.1", 0)
    );
    plain = socket.socket(socket.AF_INET, socket.SOCK_DGRAM);
    plain.setblocking(False);
    await loop.sock_sendto(plain, b"ping", answering.get_extra_info("sockname"));
    print(await loop.sock_recv(plain, 64));
    plain.close();
    answering.close();
}

with entry {
    asyncio.run(main());
}
```

```output
True True
None b'HELLO' True
b'back: ping'
```

A protocol's methods are plain functions the loop calls between two steps of the tasks, so one
does not wait: it hands what it learned to a coroutine through a future or a queue, as `lost`
does above. The factory is a function with no parameters, here a lambda that makes the
protocol or gives one already made.

## Subprocesses and signals

On Linux and macOS the loop starts child processes, with each of the child's standard streams
that is a pipe as a stream, and calls a handler when a signal arrives.

| Name | What it is |
|---|---|
| `create_subprocess_exec(program, *args, stdin=None, stdout=None, stderr=None, limit=65536, **kwds)` | Starts a program with its arguments and gives a `Process`. The other keywords are `subprocess.Popen`'s (`cwd`, `env`, `start_new_session`, ...); the streams are bytes and unbuffered, so `text`, `encoding`, `errors`, `universal_newlines` and a `bufsize` other than 0 raise `ValueError` |
| `create_subprocess_shell(cmd, stdin=None, stdout=None, stderr=None, limit=65536, **kwds)` | The same for a command line the shell runs |
| `asyncio.subprocess.PIPE`, `STDOUT`, `DEVNULL` | What a stream is given as, as in [subprocess](subprocess.md) |
| `asyncio.subprocess.Process` | `pid`, `returncode`, `stdin` (a `StreamWriter`), `stdout` and `stderr` (`StreamReader`s), each `None` unless it is a pipe; `await wait()`, `await communicate(input=None)`, `send_signal(signal)`, `terminate()`, `kill()` |
| `loop.subprocess_exec(protocol_factory, program, *args, ...)`, `loop.subprocess_shell(protocol_factory, cmd, ...)` | The same with a `SubprocessProtocol` of the program's own: `(transport, protocol)` |
| `loop.add_signal_handler(sig, callback, *args)`, `loop.remove_signal_handler(sig)` | Calls `callback(*args)` in the loop, as any other callback, each time the signal arrives; removing gives whether there was a handler |

```jac
import asyncio;
import asyncio.subprocess;
import os;
import signal;

async def main -> None {
    proc = await asyncio.create_subprocess_exec(
        "sh",
        "-c",
        "read line; echo got $line; echo oops >&2; exit 3",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    );
    (out, err) = await proc.communicate(b"input\n");
    print(out, err, proc.returncode);
    cat = await asyncio.create_subprocess_exec(
        "cat", stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE
    );
    cat.stdin.write(b"one\ntwo\n");
    await cat.stdin.drain();
    print(await cat.stdout.readline());
    cat.stdin.close();
    print(await cat.stdout.read(), await cat.wait());
    sh = await asyncio.create_subprocess_shell(
        "echo out; echo err >&2", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT
    );
    print(await sh.communicate(), sh.returncode);
    slow = await asyncio.create_subprocess_exec("sleep", "30");
    print(slow.returncode);
    slow.terminate();
    print(await slow.wait(), signal.SIGTERM.value);
    loop = asyncio.get_running_loop();
    told = loop.create_future();
    loop.add_signal_handler(signal.SIGUSR1, told.set_result, "SIGUSR1 arrived");
    os.kill(os.getpid(), signal.SIGUSR1);
    print(await told);
    print(loop.remove_signal_handler(signal.SIGUSR1), loop.remove_signal_handler(signal.SIGUSR1));
}

with entry {
    asyncio.run(main());
}
```

```output
b'got input\n' b'oops\n' 3
b'one\n'
b'two\n' 0
(b'out\nerr\n', None) 0
None
-15 15
SIGUSR1 arrived
True False
```

The loop learns that a child has exited from a descriptor of the process on Linux (a pidfd),
and from a thread that waits for it on macOS and where the kernel has no pidfds, so no
`SIGCHLD` handler is involved. A signal handler set with `add_signal_handler` runs as a callback
of the loop, where it may do anything a callback may; the loop must be the main thread's.

## The package's modules

The package is laid out as CPython's, and each module is imported by its name
(`import asyncio.staggered;`):

| Module | What it has |
|---|---|
| `asyncio.events`, `asyncio.base_events`, `asyncio.selector_events` | The loop's interface, `Handle` and `TimerHandle`; the loop's machinery and `Server`; the loop over a selector, with its socket transports |
| `asyncio.unix_events`, `asyncio.windows_events` | The loop of Linux and macOS, with its signal handlers, Unix sockets, pipes and child processes; the loop of Windows. Each has names only on its own systems |
| `asyncio.futures`, `asyncio.tasks`, `asyncio.base_futures`, `asyncio.base_tasks` | `Future`, `Task` and the functions over them; how they are shown |
| `asyncio.runners`, `asyncio.timeouts`, `asyncio.taskgroups`, `asyncio.threads`, `asyncio.staggered` | `run` and `Runner`; `timeout`; `TaskGroup`; `to_thread`; `staggered_race`, which starts each coroutine a delay after the one before it and gives the first to succeed |
| `asyncio.locks`, `asyncio.queues`, `asyncio.mixins` | The locks and the queues |
| `asyncio.streams`, `asyncio.protocols`, `asyncio.transports`, `asyncio.trsock` | `StreamReader`, `StreamWriter` and the functions that make them; `Protocol`, `DatagramProtocol`, `BufferedProtocol`, `SubprocessProtocol`; `Transport` and its bases; `TransportSocket`, the socket a transport gives out |
| `asyncio.sslproto` | TLS over a transport: `SSLProtocol`, which passes a connection's bytes through an `ssl` object over two `ssl.MemoryBIO`s |
| `asyncio.subprocess`, `asyncio.base_subprocess` | `Process`, `PIPE`, `STDOUT`, `DEVNULL` and the two functions that start a process; the transport of a child process |
| `asyncio.exceptions`, `asyncio.constants`, `asyncio.coroutines`, `asyncio.format_helpers`, `asyncio.log` | The exceptions, the shared numbers, debug mode's switch, how a callback is shown, and the `asyncio` logger |

## Differences from CPython

- **What can be awaited together is a coroutine or a future.** `gather`, `wait_for`, `shield`,
  `ensure_future` and `as_completed` take coroutines, `Future`s and `Task`s. An object of the
  program's own with an `__await__` is awaited with `await`, from a coroutine.
- **The results of several are `any`s.** `gather` gives a `list[any]`, and `wait_for`, `shield`
  and `sleep` an `any`: declare the type where one is wanted (`n: int = await wait_for(...)`).
  `run`, `Runner.run`, `create_task` and `await` of one task keep the coroutine's own type.
- **`wait` takes tasks of one type.** Tasks of coroutines with different results are declared
  `asyncio.Task[any]`, as above, and so are the sets it gives.
- **`run` and `create_task` take a coroutine**, by their types: anything else is a compile
  error (E1053) where CPython raises `ValueError` or `TypeError` as the program runs.
- **`Future.set_exception` takes an exception**, not a class to make one of (E1053).
- **`Task.get_stack` and `print_stack`, and `capture_call_graph`, `format_call_graph`,
  `print_call_graph`, `FrameCallGraphEntry` and `FutureCallGraph`, are left out** (E5142): they
  give the frames of a task's coroutine, and a native program has no frame objects.
  `repr(task)` says what a task waits for, and `Future._asyncio_awaited_by` holds the futures
  awaiting one. For the same reason a handle and a future have no source traceback in debug
  mode, and a task's `repr` does not name its coroutine.
- **A pending task nothing else holds is kept by the loop** until it is done, where CPython
  drops it and logs `Task was destroyed but it is pending!`.
- **A loop dropped unclosed is closed silently.** No `ResourceWarning` is issued, as nothing
  issues warnings ([The library](index.md)), nor for a transport or a `StreamWriter` dropped
  unclosed.
- **A transport a program drops without closing stays open until its loop is closed**: the
  loop holds each transport until its connection is lost, where CPython's holds it weakly.
  Close what you open.
- **`connection_lost` is given an `Exception` or `None`.** When what ended the connection is
  not an `Exception` (a callback of the protocol raised `SystemExit`, say), the loop's exception
  handler is given it and `connection_lost` is given `None`.
- **`add_signal_handler` does not refuse an `async def` function** with `TypeError`, as a
  function value does not say whether it is one. A coroutine object is refused when the
  program is compiled, since it is not a function.
- **`shutdown_asyncgens()` has nothing to close**: the loop is not told of the asynchronous
  generators a program starts. Close one with `await gen.aclose()`.
- **A `TaskGroup` whose errors are not all `Exception`s raises `NotImplementedError`**:
  CPython's raises a `BaseExceptionGroup`, which does not exist natively.

```jac
# expect: E5142
import asyncio;

async def work -> None {
    asyncio.current_task().print_stack();
}

with entry {
    asyncio.run(work());
}
```

## What is not written yet

Each is refused when a program names it, or noted:

- **`async with server`** does not compile yet (E1041): close a `Server` with `close()` and
  `await wait_closed()`, as the streams example does.
- **A protocol's class as its factory**: `loop.create_server(Echo, host, port)` is E1053, as
  a class is not yet taken where a function of a declared type is wanted. Pass a function
  that makes the protocol, `lambda -> asyncio.BaseProtocol { return Echo(); }`.
- **Ctrl-C ends the program at once**, where CPython's `run` cancels the main task and raises
  `KeyboardInterrupt`. A program that must clean up sets a handler of its own with
  `loop.add_signal_handler(signal.SIGINT, ...)`.
- **`iscoroutine` and `iscoroutinefunction`** (E1145): a parameter typed
  `Coroutine[any, any, T]` takes only a coroutine.
- **The event loop policies**: `get_event_loop_policy` and `set_event_loop_policy` are there;
  the policy classes are not (E1145). Pass `loop_factory=` to `run` or to a `Runner`.
- **The modules `asyncio.graph`, `asyncio.tools`, `asyncio.proactor_events` and
  `asyncio.windows_utils`** (E5143): the first reads the frames of tasks, the second is the
  command line that shows another Python process's tasks, and the others are the proactor loop
  of Windows, below.
- **A method handed over with fewer arguments than it declares** fails with `TypeError` when
  the loop or a thread calls it: `to_thread(t.join)` and `loop.call_soon(q.shutdown)` do not
  fill in the method's defaults yet. Pass every argument (`loop.call_soon(q.shutdown, False)`),
  or a function of the program's own that makes the call.

## Platforms

| | Linux, macOS | Windows |
|---|---|---|
| The loop | `SelectorEventLoop` and `EventLoop`, over `epoll` and `kqueue` | `SelectorEventLoop`, over Winsock's `select`; `EventLoop` and `ProactorEventLoop` are not names (E1145) |
| Tasks, futures, timeouts, locks, queues, threads | Yes | Yes |
| Streams, transports and protocols, servers, datagrams, TLS, the `sock_*` methods | Yes | Yes |
| Unix sockets: `open_unix_connection`, `start_unix_server`, `create_unix_connection`, `create_unix_server` | Yes | The two functions are not names (E1145), and the loop's methods raise `NotImplementedError` |
| Subprocesses: `create_subprocess_exec`, `create_subprocess_shell`, `subprocess_exec`, `subprocess_shell` | Yes | They raise `NotImplementedError` |
| Pipes: `connect_read_pipe`, `connect_write_pipe` | Yes | They raise `NotImplementedError` |
| `add_signal_handler`, `remove_signal_handler` | Yes | They raise `NotImplementedError`, as CPython's do there |

CPython's default loop on Windows is the proactor loop, over I/O completion ports, which is
what runs subprocesses and pipes there. It is not written, so the default loop is the selector
loop, CPython's other loop for Windows, with that loop's limits: no subprocesses and no pipes.
Run a child process with [subprocess](subprocess.md)'s calls and `to_thread`.

The package does not build for WASI, where `ssl`, whose contexts the loop names, is not
available ([Platform limits](stdlib.md#platform-limits)).

## CPython's asyncio

`importlib.import_module("asyncio")` is CPython's `asyncio`, in a program that embeds CPython.
Its loop runs Jac coroutines too, and Python coroutines await them: see
[Python values](../interop/python-values.md) (`jac docs interop/python-values`).

## Where to go next

- `async def`, `await`, `async for` and `async with`: [Async](../language/async.md).
- Threads, and the queues and locks they share: [threading](threading.md).
- Sockets, selectors and TLS contexts, which the loop waits on and its transports carry:
  [socket](socket.md).
- Child processes run with blocking calls: [subprocess](subprocess.md).
- Every native module: [Standard-library modules](stdlib.md).
