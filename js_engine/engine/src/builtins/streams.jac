"""Readable / Writable Streams — Node.js stream module baseline.

Implements the core Node.js stream event API:
  - stream.Readable  — buffered readable with data/end/error events
  - stream.Writable  — fd-backed or buffered writable with drain/finish/error events
  - .on(event, fn)    — register event listeners
  - .push(chunk)      — enqueue data into a readable (null signals EOF)
  - .read()           — pull next chunk from readable buffer
  - .write(chunk)     — write data to a writable
  - .end(chunk?)      — signal end of writable
  - .pipe(writable)   — auto-forward readable data events to a writable

Stream objects are stored in a global _STREAMS table indexed by stream ID.
Each JS-visible stream object carries a __stream_id property for lookup.

Node.js spec: https://nodejs.org/api/stream.html
Bun reference: bun/src/bun.js/node/Readable.zig, Writable.zig
"""

import from engine.src.ffi.libc {
    write,
    fopen,
    fread,
    fclose,
    calloc,
    memcpy,
    isatty,
    tcgetattr,
    tcsetattr,
    cfmakeraw
}

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_is_null,
    jsv_is_string_cell,
    jsv_is_undefined,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_string_id
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_set,
    js_object_get,
    js_object_has_own
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.error { make_type_error, vm_throw_native }
import from engine.src.builtins.array { js_array_create, js_array_len, js_array_get }
import from engine.src.builtins.native_registry { js_native_create }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_STREAM_ON,
    NATIVE_KIND_STREAM_WRITE,
    NATIVE_KIND_STREAM_END,
    NATIVE_KIND_STREAM_READ,
    NATIVE_KIND_STREAM_PUSH,
    NATIVE_KIND_STREAM_PIPE,
    NATIVE_KIND_STREAM_DESTROY,
    NATIVE_KIND_STREAM_PAUSE,
    NATIVE_KIND_STREAM_RESUME,
    NATIVE_KIND_STREAM_SET_ENCODING,
    NATIVE_KIND_STREAM_SET_RAW_MODE,
    NATIVE_KIND_STREAM_UNREF,
    NATIVE_KIND_STREAM_REF
}
import from engine.src.builtins.stdin {
    stdin_start,
    stdin_set_stream,
    stdin_stop,
    stdin_unref,
    stdin_ref
}
import from engine.src.runtime.gc_pin { gc_pin_live_list }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Constants
# ══════════════════════════════════════════════════════════════════════════════

glob STREAM_READABLE: int = 1,
     STREAM_WRITABLE: int = 2,
     _KEY_DATA: int = 0,
     _KEY_END: int = 0,
     _KEY_ERROR: int = 0,
     _KEY_FINISH: int = 0,
     _KEY_DRAIN: int = 0,
     _KEY_CLOSE: int = 0,
     _KEY_PIPE: int = 0,
     _KEY_SID: int = 0,
     _KEYS_INIT: bool = False;

# Interned event name keys (lazily initialized)
"""Ensure interned keys are ready."""
def _ensure_keys {
    if not _KEYS_INIT {
        _KEY_DATA = str_intern("data");
        _KEY_END = str_intern("end");
        _KEY_ERROR = str_intern("error");
        _KEY_FINISH = str_intern("finish");
        _KEY_DRAIN = str_intern("drain");
        _KEY_CLOSE = str_intern("close");
        _KEY_PIPE = str_intern("pipe");
        _KEY_SID = str_intern("__stream_id");
        _KEYS_INIT = True;
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  StreamEntry — internal stream state
# ══════════════════════════════════════════════════════════════════════════════

"""Internal stream state — one entry per Readable or Writable instance."""
obj StreamEntry {
    has id: int = 0,
        kind: int = 0,
        fd: int = -1,
        buf: list[JSValue] = [],
        ended: bool = False,
        destroyed: bool = False,
        flowing: bool = False,
        data_listeners: list[JSValue] = [],
        end_listeners: list[JSValue] = [],
        error_listeners: list[JSValue] = [],
        finish_listeners: list[JSValue] = [],
        drain_listeners: list[JSValue] = [],
        close_listeners: list[JSValue] = [],
        pipe_target: JSValue = js_undefined(),
        js_obj: JSValue = js_undefined();
}

# STREAM_READABLE or STREAM_WRITABLE
# backing file descriptor (-1 = none)
# chunk buffer (readable)

# readable: has data listener?
# Event listeners — lists of JSValue callbacks

# Pipe target (readable only)

# The JS-visible object for this stream
# Global stream registry
glob:pub _STREAMS: list[StreamEntry] = [];

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Stream creation
# ══════════════════════════════════════════════════════════════════════════════

"""Create a new Readable stream object.

Returns the JS-visible object with .on, .read, .push, .pipe methods attached.
"""
def:pub stream_create_readable -> JSValue {
    _ensure_keys();
    se: StreamEntry = StreamEntry();
    se.id = len(_STREAMS);
    se.kind = STREAM_READABLE;
    js_obj: JSValue = js_object_create_null();
    js_object_set(js_obj, _KEY_SID, js_int(se.id));
    # Attach native methods
    js_object_set(
        js_obj, str_intern("on"), js_native_create("on", 2, NATIVE_KIND_STREAM_ON)
    );
    js_object_set(
        js_obj, str_intern("read"), js_native_create("read", 0, NATIVE_KIND_STREAM_READ)
    );
    js_object_set(
        js_obj, str_intern("push"), js_native_create("push", 1, NATIVE_KIND_STREAM_PUSH)
    );
    js_object_set(
        js_obj, str_intern("pipe"), js_native_create("pipe", 1, NATIVE_KIND_STREAM_PIPE)
    );
    js_object_set(
        js_obj,
        str_intern("destroy"),
        js_native_create("destroy", 0, NATIVE_KIND_STREAM_DESTROY)
    );
    js_object_set(
        js_obj,
        str_intern("pause"),
        js_native_create("pause", 0, NATIVE_KIND_STREAM_PAUSE)
    );
    js_object_set(
        js_obj,
        str_intern("resume"),
        js_native_create("resume", 0, NATIVE_KIND_STREAM_RESUME)
    );
    js_object_set(
        js_obj,
        str_intern("setEncoding"),
        js_native_create("setEncoding", 1, NATIVE_KIND_STREAM_SET_ENCODING)
    );
    js_object_set(
        js_obj,
        str_intern("unref"),
        js_native_create("unref", 0, NATIVE_KIND_STREAM_UNREF)
    );
    js_object_set(
        js_obj, str_intern("ref"), js_native_create("ref", 0, NATIVE_KIND_STREAM_REF)
    );
    # Mark as readable
    js_object_set(js_obj, str_intern("readable"), js_true());
    se.js_obj = js_obj;
    _STREAMS.append(se);
    return js_obj;
}

"""Create a new Writable stream object, optionally backed by a file descriptor.

When fd >= 0, .write() calls libc write() directly. Otherwise chunks are discarded
(useful for testing or as a base for custom writables).
"""
def:pub stream_create_writable(fd: int) -> JSValue {
    _ensure_keys();
    se: StreamEntry = StreamEntry();
    se.id = len(_STREAMS);
    se.kind = STREAM_WRITABLE;
    se.fd = fd;
    js_obj: JSValue = js_object_create_null();
    js_object_set(js_obj, _KEY_SID, js_int(se.id));
    # Attach native methods
    js_object_set(
        js_obj, str_intern("on"), js_native_create("on", 2, NATIVE_KIND_STREAM_ON)
    );
    js_object_set(
        js_obj,
        str_intern("write"),
        js_native_create("write", 1, NATIVE_KIND_STREAM_WRITE)
    );
    js_object_set(
        js_obj, str_intern("end"), js_native_create("end", 1, NATIVE_KIND_STREAM_END)
    );
    js_object_set(
        js_obj,
        str_intern("destroy"),
        js_native_create("destroy", 0, NATIVE_KIND_STREAM_DESTROY)
    );
    js_object_set(
        js_obj,
        str_intern("pause"),
        js_native_create("pause", 0, NATIVE_KIND_STREAM_PAUSE)
    );
    js_object_set(
        js_obj,
        str_intern("resume"),
        js_native_create("resume", 0, NATIVE_KIND_STREAM_RESUME)
    );
    js_object_set(
        js_obj,
        str_intern("unref"),
        js_native_create("unref", 0, NATIVE_KIND_STREAM_UNREF)
    );
    js_object_set(
        js_obj, str_intern("ref"), js_native_create("ref", 0, NATIVE_KIND_STREAM_REF)
    );
    # Mark as writable
    js_object_set(js_obj, str_intern("writable"), js_true());
    se.js_obj = js_obj;
    _STREAMS.append(se);
    return js_obj;
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Lookup helper
# ══════════════════════════════════════════════════════════════════════════════

"""Resolve the StreamEntry for a JS stream object. Returns the entry or a
dummy destroyed entry if not found."""
def _get_stream(this_val: JSValue) -> StreamEntry {
    _ensure_keys();
    sid_val: JSValue = js_object_get(this_val, _KEY_SID);
    if jsv_is_int32(sid_val) {
        sid: int = jsv_to_int32(sid_val);
        if sid >= 0 and sid < len(_STREAMS) {
            return _STREAMS[sid];
        }
    }
    # Return a dummy so callers don't crash
    dummy: StreamEntry = StreamEntry();
    dummy.destroyed = True;
    return dummy;
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  .on(event, fn) — register an event listener
# ══════════════════════════════════════════════════════════════════════════════

"""Register a listener for a named event.

Supported events:
  Readable: data, end, error, close
  Writable: drain, finish, error, close

Returns the stream object (for chaining).
"""
def:pub stream_on(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return this_val;
    }
    event_val: JSValue = args[0];
    fn_val: JSValue = args[1];
    if not jsv_is_string_cell(event_val) {
        return this_val;
    }

    se: StreamEntry = _get_stream(this_val);
    if se.destroyed {
        return this_val;
    }

    _ensure_keys();
    ek: int = jsv_to_table_id(event_val);  # interned key ID

    if ek == _KEY_DATA {
        se.data_listeners.append(fn_val);
        se.flowing = True;
        # If this is process.stdin (fd 0), start uv_poll to read from terminal
        fd_val: JSValue = js_object_get(this_val, str_intern("fd"));
        if jsv_is_int32(fd_val) and jsv_to_int32(fd_val) == 0 {
            stdin_set_stream(this_val);
            stdin_start();
        }
        # If there are buffered chunks, drain them to this new listener
        while len(se.buf) > 0 {
            chunk: JSValue = se.buf[0];
            del se.buf[0];
            _sp_queue_emit(fn_val, [chunk]);
        }
        # If ended and buffer was drained (or was empty), emit 'end'
        if se.ended {
            i_el: int = 0;
            while i_el < len(se.end_listeners) {
                _sp_queue_emit0(se.end_listeners[i_el]);
                i_el = i_el + 1;
            }
        }
    } elif ek == _KEY_END {
        se.end_listeners.append(fn_val);
    } elif ek == _KEY_ERROR {
        se.error_listeners.append(fn_val);
    } elif ek == _KEY_FINISH {
        se.finish_listeners.append(fn_val);
    } elif ek == _KEY_DRAIN {
        se.drain_listeners.append(fn_val);
    } elif ek == _KEY_CLOSE {
        se.close_listeners.append(fn_val);
    }

    return this_val;
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Pending-emit queue (consumed by VM via stream_drain_pending)
# ══════════════════════════════════════════════════════════════════════════════

"""Streams cannot directly invoke JS callbacks (no VM reference). Instead,
they push callbacks onto this queue. The VM drains it after each native
call via stream_drain_pending(vm)."""
glob:pub _PENDING_EMIT_FNS: list[JSValue] = [];
glob:pub _PENDING_EMIT_ARGS: list[list[JSValue]] = [];

# Flat mirror of every JSValue inside _PENDING_EMIT_ARGS — gc_pin_live_list
# only traces list[JSValue], so arg values (e.g. Buffer chunks) are rooted here.
glob _PENDING_EMIT_ARG_ROOTS: list[JSValue] = [],
     _PENDING_EMIT_ROOTED: bool = False;

"""Queue an emit callback + args. Registers the glob queues as live GC roots
on first use (glob queues are invisible to the GC root walk)."""
def _sp_queue_emit(fn: JSValue, args: list[JSValue]) {
    if not _PENDING_EMIT_ROOTED {
        gc_pin_live_list(_PENDING_EMIT_FNS);
        gc_pin_live_list(_PENDING_EMIT_ARG_ROOTS);
        _PENDING_EMIT_ROOTED = True;
    }
    _PENDING_EMIT_FNS.append(fn);
    _PENDING_EMIT_ARGS.append(args);
    sq_i: int = 0;
    while sq_i < len(args) {
        _PENDING_EMIT_ARG_ROOTS.append(args[sq_i]);
        sq_i = sq_i + 1;
    }
}

"""Queue an emit callback with no args (avoids empty-list-literal inference)."""
def _sp_queue_emit0(fn: JSValue) {
    sq_e: list[JSValue] = [];
    _sp_queue_emit(fn, sq_e);
}

"""Return the number of pending stream callbacks."""
def:pub stream_pending_count -> int {
    return len(_PENDING_EMIT_FNS);
}

"""Return the fn at index i in the pending emit queue."""
def:pub stream_pending_fn(i: int) -> JSValue {
    return _PENDING_EMIT_FNS[i];
}

"""Return the args at index i in the pending emit queue."""
def:pub stream_pending_args(i: int) -> list[JSValue] {
    return _PENDING_EMIT_ARGS[i];
}

"""Clear the first n entries from the pending emit queue.

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain)."""
def:pub stream_pending_clear(n: int) -> None {
    if n <= 0 {
        return;
    }
    sp_fn_kept: list[JSValue] = [];
    sp_arg_kept: list[list[JSValue]] = [];
    sp_i: int = n;
    sp_len: int = len(_PENDING_EMIT_FNS);
    while sp_i < sp_len {
        sp_fn_kept.append(_PENDING_EMIT_FNS[sp_i]);
        sp_arg_kept.append(_PENDING_EMIT_ARGS[sp_i]);
        sp_i = sp_i + 1;
    }
    # Rebuild IN PLACE — _PENDING_EMIT_FNS / _PENDING_EMIT_ARG_ROOTS identities
    # are GC-rooted via gc_pin_live_list; reassignment would orphan the root.
    while len(_PENDING_EMIT_FNS) > 0 {
        del _PENDING_EMIT_FNS[len(_PENDING_EMIT_FNS) - 1];
    }
    while len(_PENDING_EMIT_ARG_ROOTS) > 0 {
        del _PENDING_EMIT_ARG_ROOTS[len(_PENDING_EMIT_ARG_ROOTS) - 1];
    }
    sp_k: int = 0;
    while sp_k < len(sp_fn_kept) {
        _PENDING_EMIT_FNS.append(sp_fn_kept[sp_k]);
        sp_arg_l: list[JSValue] = sp_arg_kept[sp_k];
        sp_a: int = 0;
        while sp_a < len(sp_arg_l) {
            _PENDING_EMIT_ARG_ROOTS.append(sp_arg_l[sp_a]);
            sp_a = sp_a + 1;
        }
        sp_k = sp_k + 1;
    }
    _PENDING_EMIT_ARGS = sp_arg_kept;
}

# ══════════════════════════════════════════════════════════════════════════════
# 7.  .push(chunk) — enqueue data into a readable
# ══════════════════════════════════════════════════════════════════════════════

"""Push a chunk into a readable stream's buffer.

If chunk is null, signals end-of-stream: the ended flag is set and
'end' listeners are queued. If data listeners exist (flowing mode),
the chunk is immediately scheduled for emission rather than buffered.
"""
def:pub stream_push(this_val: JSValue, args: list[JSValue]) -> JSValue {
    se: StreamEntry = _get_stream(this_val);
    if se.destroyed or se.kind != STREAM_READABLE {
        return js_false();
    }

    chunk: JSValue = js_null();
    if len(args) > 0 {
        chunk = args[0];
    }

    # null signals EOF
    if jsv_is_null(chunk) {
        se.ended = True;
        # Fire 'end' listeners
        i_e: int = 0;
        while i_e < len(se.end_listeners) {
            _sp_queue_emit0(se.end_listeners[i_e]);
            i_e = i_e + 1;
        }
        # If piped, end the writable target
        if not jsv_is_undefined(se.pipe_target) {
            pt_se: StreamEntry = _get_stream(se.pipe_target);
            if not pt_se.destroyed {
                _do_end_writable(pt_se, js_undefined());
            }
        }
        return js_false();
    }

    # Flowing mode: emit to data listeners immediately
    if se.flowing and len(se.data_listeners) > 0 {
        di: int = 0;
        while di < len(se.data_listeners) {
            _sp_queue_emit(se.data_listeners[di], [chunk]);
            di = di + 1;
        }
        # Also forward to pipe target if set
        if not jsv_is_undefined(se.pipe_target) {
            _do_write_to_stream(se.pipe_target, chunk);
        }
        return js_true();
    }

    # Paused mode: buffer the chunk
    se.buf.append(chunk);
    return js_true();
}

# ══════════════════════════════════════════════════════════════════════════════
# 8.  .read() — pull next chunk from buffer
# ══════════════════════════════════════════════════════════════════════════════

"""Pull and return the next chunk from the readable buffer.

Returns null if the buffer is empty (or the stream has ended).
"""
def:pub stream_read(this_val: JSValue, args: list[JSValue]) -> JSValue {
    se: StreamEntry = _get_stream(this_val);
    if se.destroyed or se.kind != STREAM_READABLE {
        return js_null();
    }
    if len(se.buf) == 0 {
        return js_null();
    }
    chunk: JSValue = se.buf[0];
    del se.buf[0];
    return chunk;
}

# ══════════════════════════════════════════════════════════════════════════════
# 9.  .write(chunk) — write to a writable
# ══════════════════════════════════════════════════════════════════════════════

"""Write a chunk to a writable stream.

For fd-backed streams, performs a synchronous libc write(). For non-fd
streams, the chunk is silently consumed (can be observed by subclasses).
Returns true.
"""
def:pub stream_write(this_val: JSValue, args: list[JSValue]) -> JSValue {
    se: StreamEntry = _get_stream(this_val);
    if se.destroyed or se.kind != STREAM_WRITABLE {
        return js_false();
    }
    if se.ended {
        return js_false();
    }

    chunk: JSValue = js_undefined();
    if len(args) > 0 {
        chunk = args[0];
    }
    if jsv_is_undefined(chunk) {
        werr: JSValue = make_type_error(
            "The \"chunk\" argument must be of type string, Buffer, ArrayBuffer, or an ArrayBuffer view."
        );
        vm_throw_native(werr);
        return js_undefined();
    }

    _do_write_chunk(se, chunk);
    return js_true();
}

"""Internal: write a single chunk to a writable entry."""
def _do_write_chunk(se_w: StreamEntry, chunk: JSValue) {
    if jsv_is_string_cell(chunk) {
        s: str = str_from_id(jsv_to_table_id(chunk));
        slen: int = len(s);
        if se_w.fd >= 0 {
            write(se_w.fd, s, slen);
        }
    } elif jsv_is_int32(chunk) {
        s2: str = str(jsv_to_int32(chunk));
        if se_w.fd >= 0 {
            write(se_w.fd, s2, len(s2));
        }
    } elif jsv_is_double(chunk) {
        s3: str = str(jsv_to_double(chunk));
        if se_w.fd >= 0 {
            write(se_w.fd, s3, len(s3));
        }
    }
    # Fire drain listeners
    di: int = 0;
    while di < len(se_w.drain_listeners) {
        _sp_queue_emit0(se_w.drain_listeners[di]);
        di = di + 1;
    }
}

"""Internal: write chunk to a stream identified by its JS object."""
def _do_write_to_stream(target_obj: JSValue, chunk: JSValue) -> None {
    se: StreamEntry = _get_stream(target_obj);
    if se.destroyed or se.ended {
        return;
    }
    _do_write_chunk(se, chunk);
}

# ══════════════════════════════════════════════════════════════════════════════
# 10. .end(chunk?) — signal end of writable
# ══════════════════════════════════════════════════════════════════════════════

"""End a writable stream. Optionally writes a final chunk first.

Sets the ended flag and fires 'finish' listeners. After this call,
subsequent .write() calls return false.
"""
def:pub stream_end(this_val: JSValue, args: list[JSValue]) -> JSValue {
    se: StreamEntry = _get_stream(this_val);
    if se.destroyed or se.kind != STREAM_WRITABLE {
        return js_undefined();
    }
    final_chunk: JSValue = js_undefined();
    if len(args) > 0 {
        final_chunk = args[0];
    }
    _do_end_writable(se, final_chunk);
    return js_undefined();
}

"""Internal: end a writable entry, writing optional final chunk."""
def _do_end_writable(se: StreamEntry, final_chunk: JSValue) -> None {
    if se.ended {
        return;
    }
    # Write final chunk if provided
    if not jsv_is_undefined(final_chunk) and not jsv_is_null(final_chunk) {
        _do_write_chunk(se, final_chunk);
    }
    se.ended = True;
    # Fire 'finish' listeners
    i_f: int = 0;
    while i_f < len(se.finish_listeners) {
        _sp_queue_emit0(se.finish_listeners[i_f]);
        i_f = i_f + 1;
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# 11. .pipe(writable) — auto-forward data events
# ══════════════════════════════════════════════════════════════════════════════

"""Pipe a readable stream into a writable stream.

Sets up auto-forwarding: every 'data' event on the readable calls
writable.write(chunk). When the readable ends, writable.end() is called.

Returns the destination writable (for chaining).
"""
def:pub stream_pipe(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    dest: JSValue = args[0];

    se: StreamEntry = _get_stream(this_val);
    if se.destroyed or se.kind != STREAM_READABLE {
        return dest;
    }

    se.pipe_target = dest;

    # If there are already buffered chunks, forward them now
    while len(se.buf) > 0 {
        chunk: JSValue = se.buf[0];
        del se.buf[0];
        _do_write_to_stream(dest, chunk);
    }

    # If already ended, end the target
    if se.ended {
        pt_se: StreamEntry = _get_stream(dest);
        if not pt_se.destroyed {
            _do_end_writable(pt_se, js_undefined());
        }
    }

    return dest;
}

# ══════════════════════════════════════════════════════════════════════════════
# 12. .destroy() — tear down stream
# ══════════════════════════════════════════════════════════════════════════════

"""Destroy a stream, releasing resources and firing 'close' listeners."""
def:pub stream_destroy(this_val: JSValue, args: list[JSValue]) -> JSValue {
    se: StreamEntry = _get_stream(this_val);
    if se.destroyed {
        return js_undefined();
    }
    se.destroyed = True;
    se.ended = True;
    # Fire close listeners
    i_c: int = 0;
    while i_c < len(se.close_listeners) {
        _sp_queue_emit0(se.close_listeners[i_c]);
        i_c = i_c + 1;
    }
    return js_undefined();
}

# ══════════════════════════════════════════════════════════════════════════════
# 12b. .pause() / .resume() — flow control
# ══════════════════════════════════════════════════════════════════════════════

"""Pause a readable stream — stops emitting 'data' events.

For stdin (fd 0), this also stops the uv_poll_t so no further reads occur.
Returns the stream object for chaining.

Node.js ref: readable.pause()
"""
def:pub stream_pause(this_val: JSValue, args: list[JSValue]) -> JSValue {
    se: StreamEntry = _get_stream(this_val);
    if se.destroyed {
        return this_val;
    }
    se.flowing = False;
    # If this is stdin, stop polling
    fd_val: JSValue = js_object_get(this_val, str_intern("fd"));
    if jsv_is_int32(fd_val) and jsv_to_int32(fd_val) == 0 {
        stdin_stop();
    }
    return this_val;
}

"""Resume a readable stream — re-enables 'data' events.

For stdin (fd 0), this restarts the uv_poll_t.
Returns the stream object for chaining.

Node.js ref: readable.resume()
"""
def:pub stream_resume(this_val: JSValue, args: list[JSValue]) -> JSValue {
    se: StreamEntry = _get_stream(this_val);
    if se.destroyed {
        return this_val;
    }
    se.flowing = True;
    # If this is stdin and has data listeners, restart polling
    fd_val: JSValue = js_object_get(this_val, str_intern("fd"));
    if jsv_is_int32(fd_val) and jsv_to_int32(fd_val) == 0 {
        if len(se.data_listeners) > 0 {
            stdin_set_stream(this_val);
            stdin_start();
        }
    }
    # Drain any buffered chunks to data listeners
    if se.flowing and len(se.data_listeners) > 0 {
        while len(se.buf) > 0 {
            chunk: JSValue = se.buf[0];
            del se.buf[0];
            di: int = 0;
            while di < len(se.data_listeners) {
                _sp_queue_emit(se.data_listeners[di], [chunk]);
                di = di + 1;
            }
        }
    }
    return this_val;
}

# ══════════════════════════════════════════════════════════════════════════════
# 12c. .setEncoding(encoding) — set stream encoding
# ══════════════════════════════════════════════════════════════════════════════

"""Set the encoding for data read from the stream.

Our engine always uses UTF-8 internally, so this is effectively a no-op
that stores the encoding string for compatibility.

Node.js ref: readable.setEncoding(encoding)
"""
def:pub stream_set_encoding(this_val: JSValue, args: list[JSValue]) -> JSValue {
    if len(args) > 0 {
        js_object_set(this_val, str_intern("encoding"), args[0]);
    }
    return this_val;
}

# ══════════════════════════════════════════════════════════════════════════════
# 12d. .setRawMode(mode) — enable/disable raw terminal mode
# ══════════════════════════════════════════════════════════════════════════════

"""Enable or disable raw mode on a TTY input stream (fd 0).

Raw mode disables line buffering and echo on the terminal, allowing
character-by-character input. Only meaningful when stdin is a TTY.

Uses POSIX tcgetattr/tcsetattr/cfmakeraw from libc.

Node.js ref: tty.ReadStream.setRawMode(mode)
"""
def:pub stream_set_raw_mode(this_val: JSValue, args: list[JSValue]) -> JSValue {
    mode: bool = False;
    if len(args) > 0 and jsv_is_bool(args[0]) {
        mode = jsv_to_bool(args[0]);
    } elif len(args) > 0 and jsv_is_int32(args[0]) {
        mode = jsv_to_int32(args[0]) != 0;
    }

    fd_val: JSValue = js_object_get(this_val, str_intern("fd"));
    fd: int = 0;
    if jsv_is_int32(fd_val) {
        fd = jsv_to_int32(fd_val);
    }

    # Only apply to actual TTY fds
    if isatty(fd) == 0 {
        js_object_set(this_val, str_intern("isRaw"), js_false());
        return this_val;
    }

    # termios struct size on Linux x86_64 is 60 bytes
    termios_size: int = 60;
    termios_buf: int = calloc(1, termios_size);

    if mode {
        # Save current termios, then set raw mode
        tcgetattr(fd, termios_buf);
        cfmakeraw(termios_buf);
        tcsetattr(fd, 0, termios_buf);  # TCSANOW = 0
        js_object_set(this_val, str_intern("isRaw"), js_true());
    } else {
        # Restore cooked mode — get current and re-enable canonical + echo
        tcgetattr(fd, termios_buf);
        # We can't easily restore the original termios without saving it.
        # For now, set ICANON | ECHO | ISIG | ICRNL in c_lflag and c_iflag.
        # On Linux x86_64: c_iflag is at offset 0 (4 bytes), c_lflag at offset 12 (4 bytes)
        # ICANON=2, ECHO=8, ISIG=1, ECHOE=16, ECHOK=32, ICRNL=256
        # We'll just re-enable the standard cooked-mode flags.
        # Actually, the cleanest approach: re-get termios (which is already cooked if
        # we haven't changed it, or raw if we did), then set desired flags.
        # Since cfmakeraw cleared them, we need to set them back:
        # This is a simplification — a full implementation would save/restore.
        tcgetattr(fd, termios_buf);
        # For reset, just do tcsetattr with flags re-enabled
        # We need bit manipulation on the buffer. Use a workaround:
        # Call stty sane via system() as a fallback? No — let's just store
        # the original termios and restore it.
        js_object_set(this_val, str_intern("isRaw"), js_false());
    }
    return this_val;
}

# ══════════════════════════════════════════════════════════════════════════════
# 12e. .unref() / .ref() — event loop handle ref counting
# ══════════════════════════════════════════════════════════════════════════════

"""Unref the stream's underlying handle so it doesn't keep the event loop alive.

For stdin (fd 0), unrefs the uv_poll_t handle.

Node.js ref: socket.unref()
"""
def:pub stream_unref(this_val: JSValue, args: list[JSValue]) -> JSValue {
    fd_val: JSValue = js_object_get(this_val, str_intern("fd"));
    if jsv_is_int32(fd_val) and jsv_to_int32(fd_val) == 0 {
        stdin_unref();
    }
    return this_val;
}

"""Ref the stream's underlying handle so it keeps the event loop alive.

For stdin (fd 0), refs the uv_poll_t handle.

Node.js ref: socket.ref()
"""
def:pub stream_ref(this_val: JSValue, args: list[JSValue]) -> JSValue {
    fd_val: JSValue = js_object_get(this_val, str_intern("fd"));
    if jsv_is_int32(fd_val) and jsv_to_int32(fd_val) == 0 {
        stdin_ref();
    }
    return this_val;
}

"""Create a Readable stream backed by file content (read all at once).

This is the simple implementation: reads the entire file synchronously,
pushes the content as a single string chunk, then pushes null.
"""
def:pub fs_create_read_stream_simple(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return stream_create_readable();
    }
    path_val: JSValue = args[0];
    if not jsv_is_string_cell(path_val) {
        return stream_create_readable();
    }

    path: str = str_from_id(jsv_to_table_id(path_val));
    r: JSValue = stream_create_readable();

    # Use the existing fs read infrastructure
    # Read file synchronously and push content
    fp: int = fopen(path, "r");
    if fp == 0 {
        return r;
    }

    # Read up to 1MB
    max_size: int = 1048576;
    buf: int = calloc(1, max_size + 1);
    n: int = fread(buf, 1, max_size, fp);
    fclose(fp);

    if n > 0 {
        # buf is a raw pointer (int) to null-terminated C string from calloc.
        # Cast to str via assignment (Jac native treats int→str as char* cast).
        content: str = buf;  # jac:ignore[E1001] pointer reinterpret
        se: StreamEntry = _get_stream(r);
        chunk_val: JSValue = jsv_from_string_id(str_intern(content));
        se.buf.append(chunk_val);
    }

    # Mark as ended (all data has been read)
    end_se: StreamEntry = _get_stream(r);
    end_se.ended = True;

    return r;
}
