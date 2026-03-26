"""Covers stdlib star re-export resolution.

asyncio.Queue is defined in asyncio.queues but re-exported via
`from .queues import *` in asyncio/__init__.pyi.  The type checker
must follow star imports to resolve it.
"""
import from asyncio { Queue }
import from queue { SimpleQueue }

with entry {
    q: Queue = Queue();
    q.put_nowait(42);
    empty: bool = q.empty();

    sq: SimpleQueue = SimpleQueue();
    sq.put(1);
    val: object = sq.get();
}
