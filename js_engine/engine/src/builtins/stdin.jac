"""Stdin reader — polls fd 0 for input and pushes data into process.stdin.

When process.stdin gains a "data" listener (via stream_on), the streams
module calls stdin_start() to begin polling fd 0 with uv_poll_t.
When data is available, the poll callback reads from fd 0 via libc read()
and pushes the chunk into process.stdin's data listeners.

Architecture:
  1. stdin_init(loop_ptr, async_ptr) — called once from el_run to store
     the event loop and async handle pointers.
  2. stdin_start() — creates a uv_poll_t on fd 0 and starts watching
     UV_READABLE.  Called from stream_on when the first data listener is
     added to process.stdin (fd == 0).
  3. _stdin_poll_cb(handle, status, events) — C callback fired by libuv
     when fd 0 is readable.  Reads up to 4096 bytes, converts to a JSValue
     string, and pushes into the pending-emit queue for the stdin stream.
  4. stdin_drain() — called from el_tick to fire any pending stdin
     callbacks via the VM.

Bun reference:
  bun/src/bun.js/bindings/PosixReadStream.zig — async fd reading
  bun/src/io/io_uring.zig                     — I/O polling
"""

import from engine.src.ffi.libuv {
    UVLoop,
    UVHandle,
    uvloop_create,
    uvpoll_create,
    uvpoll_start,
    uvpoll_stop,
    uvpoll_close,
    uvhandle_unref,
    uvhandle_ref,
    uvasync_send,
    UV_READABLE
}
import from engine.src.ffi.libc { read, calloc }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.jsvalue { JSValue, js_undefined }

# ── Module state ─────────────────────────────────────────────────────────────

glob _STDIN_LOOP_PTR: int = 0,
     _STDIN_ASYNC_PTR: int = 0,
     _STDIN_POLL_HDL: UVHandle = UVHandle(),
     _STDIN_STARTED: bool = False,
     _STDIN_INITED: bool = False;  # raw uv_loop_t*

# raw uv_async_t* for wakeup
# Pending data chunks read from fd 0, waiting to be pushed into process.stdin
glob:pub _STDIN_CHUNKS: list[str] = [],
     _STDIN_EOF: bool = False;

# When True, EOF was received (read returned 0)
# Reference to the process.stdin JS object (set when first data listener is added)
glob _STDIN_STREAM_OBJ: JSValue = js_undefined();

"""Store the process.stdin JS object reference.  Called from stream_on when
the first data listener is added to a stream with fd == 0."""
def:pub stdin_set_stream(js_obj: JSValue) {
    _STDIN_STREAM_OBJ = js_obj;
    gc_pin_value(js_obj);  # glob-held singleton — invisible to the GC root walk
}

"""Return the stored process.stdin JS object."""
def:pub stdin_get_stream -> JSValue {
    return _STDIN_STREAM_OBJ;
}

# ── Init ─────────────────────────────────────────────────────────────────────

"""Initialise the stdin subsystem.  Called once from el_run after the event
loop and async handle are created."""
def:pub stdin_init(loop_ptr: int, async_ptr: int) {
    _STDIN_LOOP_PTR = loop_ptr;
    _STDIN_ASYNC_PTR = async_ptr;
    _STDIN_INITED = True;
}

# ── Poll callback (C ABI) ───────────────────────────────────────────────────

"""libuv poll callback — fired when fd 0 has data to read.

C signature: void (*uv_poll_cb)(uv_poll_t* handle, int status, int events)
"""
def _stdin_poll_cb(handle: int, status: int, events: int) -> None {
    if status < 0 {
        # Error on fd 0 — treat as EOF
        _STDIN_EOF = True;
        uvpoll_stop(_STDIN_POLL_HDL);
        return;
    }
    # Read up to 4096 bytes from fd 0
    buf_size: int = 4096;
    buf: int = calloc(1, buf_size + 1);
    n: int = read(0, buf, buf_size);
    if n <= 0 {
        # EOF or error
        _STDIN_EOF = True;
        uvpoll_stop(_STDIN_POLL_HDL);
        return;
    }
    # buf is a null-terminated C string (calloc zeroed the rest).
    # Cast int → str to get the Jac string.
    chunk: str = buf;  # jac:ignore[E1001] pointer reinterpret
    _STDIN_CHUNKS.append(chunk);
    # Wake the event loop so el_tick picks up the chunk
    if _STDIN_ASYNC_PTR != 0 {
        ah: UVHandle = UVHandle();
        ah.handle_ptr = _STDIN_ASYNC_PTR;
        uvasync_send(ah);
    }
}

# ── Start / Stop ─────────────────────────────────────────────────────────────

"""Start polling fd 0 for readable data.

Called from stream_on when the first "data" listener is registered on a
stream with fd == 0 (i.e. process.stdin).  Idempotent — calling more
than once is safe.
"""
def:pub stdin_start -> None {
    if _STDIN_STARTED or not _STDIN_INITED {
        return;
    }
    _STDIN_STARTED = True;
    # Create the poll handle using the stored loop pointer
    lp: UVLoop = UVLoop();
    lp.loop_ptr = _STDIN_LOOP_PTR;
    _STDIN_POLL_HDL = uvpoll_create(lp, 0);
    uvpoll_start(_STDIN_POLL_HDL, UV_READABLE, _stdin_poll_cb);
}

"""Stop polling fd 0.  Called when process.stdin is destroyed or closed."""
def:pub stdin_stop -> None {
    if not _STDIN_STARTED {
        return;
    }
    uvpoll_stop(_STDIN_POLL_HDL);
    _STDIN_STARTED = False;
}

"""Return True if stdin polling has been started."""
def:pub stdin_is_started -> bool {
    return _STDIN_STARTED;
}

"""Return the number of pending chunks."""
def:pub stdin_chunk_count -> int {
    return len(_STDIN_CHUNKS);
}

"""Return the i-th pending chunk."""
def:pub stdin_chunk_get(idx: int) -> str {
    return _STDIN_CHUNKS[idx];
}

"""Clear the first n chunks from the pending list.

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain)."""
def:pub stdin_chunk_clear(n: int) -> None {
    if n <= 0 {
        return;
    }
    sc_kept: list[str] = [];
    sc_i: int = n;
    sc_len: int = len(_STDIN_CHUNKS);
    while sc_i < sc_len {
        sc_kept.append(_STDIN_CHUNKS[sc_i]);
        sc_i = sc_i + 1;
    }
    _STDIN_CHUNKS = sc_kept;
}

"""Return True if EOF was received."""
def:pub stdin_eof -> bool {
    return _STDIN_EOF;
}

"""Unref the stdin poll handle so it doesn't keep the event loop alive."""
def:pub stdin_unref {
    if _STDIN_STARTED {
        uvhandle_unref(_STDIN_POLL_HDL);
    }
}

"""Ref the stdin poll handle so it keeps the event loop alive."""
def:pub stdin_ref {
    if _STDIN_STARTED {
        uvhandle_ref(_STDIN_POLL_HDL);
    }
}
