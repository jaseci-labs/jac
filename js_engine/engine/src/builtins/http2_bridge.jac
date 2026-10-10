"""HTTP/2 native bridge for js_engine.

Registers native kind handlers for nghttp2 session management, I/O, frame
submission, flow control, and event polling.  Follows the same dispatch pattern
as fs.na.jac and ws_bridge.na.jac.

Native kind IDs (all require entries in native_kinds.na.jac and dispatch.na.jac):
    606 — h2_session_create_client
    607 — h2_session_create_server
    608 — h2_session_del
    609 — h2_session_recv
    610 — h2_session_send
    611 — h2_submit_request
    612 — h2_submit_response
    613 — h2_submit_settings
    614 — h2_submit_goaway
    615 — h2_submit_rst_stream
    616 — h2_session_want_read
    617 — h2_session_want_write
    618 — h2_consume
    619 — h2_submit_window_update
    620 — h2_pop_event
    621 — h2_get_send_ptr
    622 — h2_request      (JS-friendly: accepts JS Array of header strings)
    623 — h2_respond      (JS-friendly: accepts JS Array of header strings)
    970 — h2_submit_data  (queues body bytes behind a data_source_read_callback)
    971 — h2_submit_trailer (JS-friendly trailing HEADERS / END_STREAM)
    972 — h2_set_local_window_size (connection-level absolute window)

Session state
─────────────
Each session occupies a slot in two global lists:
    _H2_SESS_PTR [slot]  = nghttp2_session* (0 means the slot is free)
    _H2_SESS_EBUF[slot]  = pointer to a fixed-size event buffer (C heap)

Handle format: handle = 10000 + slot.

Event buffer layout (H2_BUF_SIZE = 8 + H2_EVENT_CAP * H2_EVENT_SIZE bytes)
────────────────────────────────────────────────────────────────────────────
  [0..7]             count (int64) — number of pending events
  [8 .. 8+n*48 - 1]  events (H2_EVENT_SIZE=48 bytes each, up to H2_EVENT_CAP)

Per-event layout (6 × 8-byte fields):
  offset 0   ev_type   (int)
  offset 8   d0        (int)
  offset 16  d1        (int)
  offset 24  d2        (int)
  offset 32  d3        (int)
  offset 40  d4        (int)

Event types and field semantics:
  H2_EV_BEGIN_HEADERS (1): d0=stream_id, d1=raw u32 at frame_hd+12
  H2_EV_HEADER        (2): d0=stream_id, d1=name_ptr, d2=name_len,
                            d3=value_ptr, d4=value_len
  H2_EV_DATA_CHUNK    (3): d0=stream_id, d1=flags, d2=data_ptr, d3=data_len
  H2_EV_STREAM_CLOSE  (4): d0=stream_id, d1=error_code
  H2_EV_FRAME_RECV    (5): d0=stream_id, d1=frame_type, d2=frame_flags,
                            d3=last_stream_id (GOAWAY only), d4=error_code (GOAWAY only)
  H2_EV_GOAWAY        (6): d0=last_stream_id, d1=error_code,
                            d2=opaque_copy_ptr, d3=opaque_len (0 if none)

nghttp2_frame_hd offsets (x86-64 LP64, verified by C probe — sizeof=16):
  offset 0:  length    (size_t,    8 bytes)
  offset 8:  stream_id (int32_t,   4 bytes)
  offset 12: type      (uint8_t,   1 byte, low byte of u32 at offset 12)
  offset 13: flags     (uint8_t,   1 byte, second byte of u32 at offset 12)

Phase: E (HTTP/2 native bridge)
Bun reference: bun/src/bun.js/bindings/nghttp2.h (system lib)
"""

import from engine.src.ffi.libnghttp2 {
    nghttp2_session_client_new3,
    nghttp2_session_server_new3,
    nghttp2_session_del,
    nghttp2_session_mem_recv,
    nghttp2_session_mem_send,
    nghttp2_session_want_read,
    nghttp2_session_want_write,
    nghttp2_submit_settings,
    nghttp2_submit_request,
    nghttp2_submit_response,
    nghttp2_submit_goaway,
    nghttp2_submit_rst_stream,
    nghttp2_submit_window_update,
    nghttp2_submit_data,
    nghttp2_submit_trailer,
    nghttp2_session_resume_data,
    nghttp2_session_set_local_window_size,
    nghttp2_session_get_remote_settings,
    nghttp2_session_get_local_settings,
    nghttp2_session_get_last_proc_stream_id,
    nghttp2_session_consume,
    nghttp2_session_callbacks_del,
    nghttp2_session_callbacks_set_on_begin_headers_callback,
    nghttp2_session_callbacks_set_on_header_callback,
    nghttp2_session_callbacks_set_on_data_chunk_recv_callback,
    nghttp2_session_callbacks_set_on_stream_close_callback,
    nghttp2_session_callbacks_set_on_frame_recv_callback,
    nghttp2_settings_alloc,
    nghttp2_settings_set,
    nghttp2_nv_alloc,
    nghttp2_nv_set,
    nghttp2_alloc_callbacks,
    nghttp2_data_prd_alloc,
    NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE,
    NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS,
    NGHTTP2_SETTINGS_ENABLE_PUSH,
    NGHTTP2_NV_SIZE,
    NGHTTP2_NV_OFF_NAME,
    NGHTTP2_NV_OFF_VALUE,
    NGHTTP2_NV_FLAG_NONE,
    NGHTTP2_FLAG_END_STREAM,
    NGHTTP2_DATA_FLAG_EOF,
    NGHTTP2_DATA_FLAG_NO_END_STREAM,
    NGHTTP2_ERR_DEFERRED
}

import from "libc.so.6" {
    def calloc(n: int, size: int) -> int;  def free(ptr: int) -> None;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def realloc(ptr: int, size: int) -> int;
}
import from engine.src.runtime.mem {
    read_u32,
    read_u64,
    write_i32,
    write_i64,
    write_byte,
    io_alloc
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_from_int32,
    jsv_from_double,
    jsv_is_int32,
    jsv_to_int32,
    jsv_is_double,
    jsv_to_double,
    jsv_is_null,
    jsv_is_undefined
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_create_null, js_object_set }
import from engine.src.builtins.array { js_array_get, js_array_len, js_is_array }
import from engine.src.builtins.string { js_to_string_prim }

# ── Session handle table ──────────────────────────────────────────────────────

glob _H2_SESS_PTR: list[int] = [],
     _H2_SESS_EBUF: list[int] = [],
     _H2_SESS_SPTR: list[int] = [],
     H2_HANDLE_BASE: int = 10000,
     H2_EVENT_CAP: int = 64,
     H2_EVENT_SIZE: int = 48,
     H2_BUF_HDR: int = 8,
     H2_BUF_SIZE: int = 3080;  # nghttp2_session* per slot (0 = free)

# fixed-size event buffer ptr per slot
# last nghttp2_session_mem_send data ptr per slot

# ── Handle / buffer constants ─────────────────────────────────────────────────

# handles start at 10000

# max events in-flight per session
# 6 × 8 bytes: ev_type + 5 data fields
# byte offset where events start in the buffer
# 8 + 64 * 48
# ── Event type constants (exported for JS consumers) ──────────────────────────

glob:pub H2_EV_BEGIN_HEADERS: int = 1,
     H2_EV_HEADER: int = 2,
     H2_EV_DATA_CHUNK: int = 3,
     H2_EV_STREAM_CLOSE: int = 4,
     H2_EV_FRAME_RECV: int = 5,
     H2_EV_GOAWAY: int = 6,
     H2_EV_SETTINGS_ENTRY: int = 7;

# d0=settings_id, d1=value (non-ACK SETTINGS iv entry)
# ── nghttp2_frame_hd offsets (verified by C probe) ────────────────────────────

glob _H2_FHD_STREAM_ID: int = 8,
     _H2_FHD_TYPE_FLAGS: int = 12,
     _H2_DQ_KEY: list[int] = [],
     _H2_DQ_BUF: list[int] = [],
     _H2_DQ_CAP: list[int] = [],
     _H2_DQ_LEN: list[int] = [],
     _H2_DQ_OFF: list[int] = [],
     _H2_DQ_EOF: list[int] = [],
     _H2_DQ_NO_END: list[int] = [],
     _H2_DQ_DEFER: list[int] = [],
     _H2_DQ_ATTACHED: list[int] = [],
     _H2_DQ_KEY_MUL: int = 1000000;  # int32_t — stream_id

# u32 at offset 12: low byte=type, next=flags

# ── Outbound DATA queues (one entry per stream with a body) ───────────────────
# nghttp2 pulls request/response bodies through a data_source_read_callback
# instead of accepting a push-style write.  Each stream that carries a body
# gets an entry here; JS appends bytes with h2_submit_data and the callback
# drains them.  When the queue runs dry before the body is finished the
# callback returns NGHTTP2_ERR_DEFERRED and the next append resumes the stream.
#
# Entries are addressed by index; a key of -1 marks a free slot.

# slot * _H2_DQ_KEY_MUL + stream_id (-1 = free)
# C heap buffer holding queued bytes
# allocated capacity of the buffer
# bytes written into the buffer
# bytes already handed to nghttp2
# 1 once the body has been fully queued
# 1 → EOF without END_STREAM (trailers pending)
# 1 while the provider is parked on DEFERRED
# 1 once nghttp2 holds a provider
def _h2_dq_key(slot: int, stream_id: int) -> int {
    return slot * _H2_DQ_KEY_MUL + stream_id;
}

def _h2_dq_find(slot: int, stream_id: int) -> int {
    key: int = _h2_dq_key(slot, stream_id);
    i: int = 0;
    while i < len(_H2_DQ_KEY) {
        if _H2_DQ_KEY[i] == key {
            return i;
        }
        i = i + 1;
    }
    return 0 - 1;
}

"""Return the index of the entry for (slot, stream_id), creating one if needed."""
def _h2_dq_ensure(slot: int, stream_id: int) -> int {
    existing: int = _h2_dq_find(slot, stream_id);
    if existing >= 0 {
        return existing;
    }
    key: int = _h2_dq_key(slot, stream_id);
    i: int = 0;
    while i < len(_H2_DQ_KEY) {
        if _H2_DQ_KEY[i] < 0 {
            _H2_DQ_KEY[i] = key;
            _H2_DQ_LEN[i] = 0;
            _H2_DQ_OFF[i] = 0;
            _H2_DQ_EOF[i] = 0;
            _H2_DQ_NO_END[i] = 0;
            _H2_DQ_DEFER[i] = 0;
            _H2_DQ_ATTACHED[i] = 0;
            return i;
        }
        i = i + 1;
    }
    _H2_DQ_KEY.append(key);
    _H2_DQ_BUF.append(0);
    _H2_DQ_CAP.append(0);
    _H2_DQ_LEN.append(0);
    _H2_DQ_OFF.append(0);
    _H2_DQ_EOF.append(0);
    _H2_DQ_NO_END.append(0);
    _H2_DQ_DEFER.append(0);
    _H2_DQ_ATTACHED.append(0);
    return len(_H2_DQ_KEY) - 1;
}

"""Release an entry's buffer and mark the slot free."""
def _h2_dq_release(idx: int) -> None {
    if idx < 0 or idx >= len(_H2_DQ_KEY) {
        return;
    }
    if _H2_DQ_BUF[idx] != 0 {
        free(_H2_DQ_BUF[idx]);
        _H2_DQ_BUF[idx] = 0;
    }
    _H2_DQ_KEY[idx] = 0 - 1;
    _H2_DQ_CAP[idx] = 0;
    _H2_DQ_LEN[idx] = 0;
    _H2_DQ_OFF[idx] = 0;
    _H2_DQ_EOF[idx] = 0;
    _H2_DQ_NO_END[idx] = 0;
    _H2_DQ_DEFER[idx] = 0;
    _H2_DQ_ATTACHED[idx] = 0;
}

"""Drop every queue entry belonging to `slot` (session teardown)."""
def _h2_dq_release_slot(slot: int) {
    lo: int = slot * _H2_DQ_KEY_MUL;
    hi: int = lo + _H2_DQ_KEY_MUL;
    i: int = 0;
    while i < len(_H2_DQ_KEY) {
        k: int = _H2_DQ_KEY[i];
        if k >= lo and k < hi {
            _h2_dq_release(i);
        }
        i = i + 1;
    }
}

"""Make room for `extra` more bytes, compacting already-consumed bytes first."""
def _h2_dq_reserve(idx: int, extra: int) -> None {
    off: int = _H2_DQ_OFF[idx];
    if off > 0 {
        remaining: int = _H2_DQ_LEN[idx] - off;
        if remaining > 0 {
            memcpy(_H2_DQ_BUF[idx], _H2_DQ_BUF[idx] + off, remaining);
        }
        _H2_DQ_LEN[idx] = remaining;
        _H2_DQ_OFF[idx] = 0;
    }
    needed: int = _H2_DQ_LEN[idx] + extra;
    if needed <= _H2_DQ_CAP[idx] {
        return;
    }
    new_cap: int = _H2_DQ_CAP[idx];
    if new_cap < 4096 {
        new_cap = 4096;
    }
    while new_cap < needed {
        new_cap = new_cap * 2;
    }
    if _H2_DQ_BUF[idx] == 0 {
        _H2_DQ_BUF[idx] = calloc(1, new_cap);
    } else {
        _H2_DQ_BUF[idx] = realloc(_H2_DQ_BUF[idx], new_cap);
    }
    _H2_DQ_CAP[idx] = new_cap;
}

# ── nghttp2_data_source_read_callback ─────────────────────────────────────────
# ssize_t (session, stream_id, buf, length, *data_flags, *source, user_data)
# user_data is the session slot (set at session creation time).

def _h2_dq_eof_flags(idx: int) -> int {
    flags: int = NGHTTP2_DATA_FLAG_EOF;
    if _H2_DQ_NO_END[idx] != 0 {
        flags = flags + NGHTTP2_DATA_FLAG_NO_END_STREAM;
    }
    return flags;
}

def _h2_cb_data_read(
    session: int,
    stream_id: int,
    buf: int,
    length: int,
    data_flags: int,
    source: int,
    user_data: int
) -> int {
    slot: int = user_data;
    idx: int = _h2_dq_find(slot, stream_id);
    if idx < 0 {
        # No queue for this stream — nothing left to send.
        write_i32(data_flags, 0, NGHTTP2_DATA_FLAG_EOF);
        return 0;
    }
    avail: int = _H2_DQ_LEN[idx] - _H2_DQ_OFF[idx];
    if avail <= 0 {
        if _H2_DQ_EOF[idx] != 0 {
            write_i32(data_flags, 0, _h2_dq_eof_flags(idx));
            return 0;
        }
        _H2_DQ_DEFER[idx] = 1;
        return NGHTTP2_ERR_DEFERRED;
    }
    n: int = avail;
    if n > length {
        n = length;
    }
    memcpy(buf, _H2_DQ_BUF[idx] + _H2_DQ_OFF[idx], n);
    _H2_DQ_OFF[idx] = _H2_DQ_OFF[idx] + n;
    if _H2_DQ_OFF[idx] >= _H2_DQ_LEN[idx] and _H2_DQ_EOF[idx] != 0 {
        write_i32(data_flags, 0, _h2_dq_eof_flags(idx));
    }
    return n;
}

"""Return the i64 function pointer for the data provider read callback."""
def _h2_data_read_cb_ptr -> int {
    cb: int = _h2_cb_data_read;
    return cb;
}

# ── Internal: push one event into a session's event buffer ────────────────────

def _h2_push_event(
    slot: int, ev_type: int, d0: int, d1: int, d2: int, d3: int, d4: int
) -> None {
    buf: int = _H2_SESS_EBUF[slot];
    if buf == 0 {
        return;
    }
    count: int = read_u64(buf, 0);
    if count >= H2_EVENT_CAP {
        return;
    }  # buffer full — drop event
    base: int = buf + H2_BUF_HDR + count * H2_EVENT_SIZE;
    write_i64(base, 0, ev_type);
    write_i64(base, 8, d0);
    write_i64(base, 16, d1);
    write_i64(base, 24, d2);
    write_i64(base, 32, d3);
    write_i64(base, 40, d4);
    write_i64(buf, 0, count + 1);
}

# ── Handle ↔ slot helpers ─────────────────────────────────────────────────────

def _h2_to_handle(slot: int) -> int {
    return slot + H2_HANDLE_BASE;
}
def _h2_to_slot(handle: int) -> int {
    return handle - H2_HANDLE_BASE;
}

# ── nghttp2 C callbacks (module-level defs — ptrtoint coercion applies) ───────
# Each callback receives user_data = slot index (set during session creation).

def _h2_cb_begin_headers(session: int, frame: int, user_data: int) -> int {
    slot: int = user_data;
    stream_id: int = read_u32(frame, _H2_FHD_STREAM_ID);
    raw32: int = read_u32(frame, _H2_FHD_TYPE_FLAGS);
    _h2_push_event(slot, H2_EV_BEGIN_HEADERS, stream_id, raw32, 0, 0, 0);
    return 0;
}

def _h2_cb_on_header(
    session: int,
    frame: int,
    name: int,
    namelen: int,
    value: int,
    valuelen: int,
    flags: int,
    user_data: int
) -> int {
    slot: int = user_data;
    stream_id: int = read_u32(frame, _H2_FHD_STREAM_ID);
    # nghttp2's name/value pointers are only valid during this callback.
    # Copy them to heap-allocated buffers so the JS layer can read them later
    # via __buf.getByte() after h2_pop_event returns.  The JS layer MUST free
    # these buffers with __buf.free() after reading — hence io_alloc, which
    # lays out the 8-byte header __buf.free() expects.
    name_copy: int = io_alloc(namelen + 1);
    memcpy(name_copy, name, namelen);
    value_copy: int = io_alloc(valuelen + 1);
    memcpy(value_copy, value, valuelen);
    _h2_push_event(
        slot, H2_EV_HEADER, stream_id, name_copy, namelen, value_copy, valuelen
    );
    return 0;
}

def _h2_cb_on_data_chunk(
    session: int, flags: int, stream_id: int, data: int, datalen: int, user_data: int
) -> int {
    slot: int = user_data;
    # nghttp2's data pointer is only valid during this callback.
    # Copy to heap so the JS layer can read via __buf.getByte() then __buf.free().
    data_copy: int = io_alloc(datalen + 1);
    memcpy(data_copy, data, datalen);
    _h2_push_event(slot, H2_EV_DATA_CHUNK, stream_id, flags, data_copy, datalen, 0);
    return 0;
}

def _h2_cb_on_stream_close(
    session: int, stream_id: int, error_code: int, user_data: int
) -> int {
    slot: int = user_data;
    _h2_dq_release(_h2_dq_find(slot, stream_id));
    _h2_push_event(slot, H2_EV_STREAM_CLOSE, stream_id, error_code, 0, 0, 0);
    return 0;
}

def _h2_cb_on_frame_recv(session: int, frame: int, user_data: int) -> int {
    slot: int = user_data;
    stream_id: int = read_u32(frame, _H2_FHD_STREAM_ID);
    raw32: int = read_u32(frame, _H2_FHD_TYPE_FLAGS);
    frame_type: int = raw32 & 255;
    frame_flags: int = (raw32 >> 8) & 255;
    # GOAWAY payload (nghttp2_goaway): last_stream_id@16, error_code@20,
    # opaque_data ptr@24, opaque_data_len@32 (LP64).
    # SETTINGS payload (nghttp2_settings): niv@16, iv*@24.
    d3: int = 0;
    d4: int = 0;
    if frame_type == 7 {
        d3 = read_u32(frame, 16);
        d4 = read_u32(frame, 20);
        opaque_ptr: int = read_u64(frame, 24);
        opaque_len: int = read_u64(frame, 32);
        opaque_copy: int = 0;
        if opaque_ptr != 0 and opaque_len > 0 {
            opaque_copy = io_alloc(opaque_len + 1);
            memcpy(opaque_copy, opaque_ptr, opaque_len);
        }
        _h2_push_event(slot, H2_EV_GOAWAY, d3, d4, opaque_copy, opaque_len, 0);
    } elif frame_type == 4 {
        # Non-ACK SETTINGS: emit one H2_EV_SETTINGS_ENTRY per iv entry so JS
        # can surface custom settings filtered by remoteCustomSettings.
        if (frame_flags & 1) == 0 {
            niv: int = read_u64(frame, 16);
            iv: int = read_u64(frame, 24);
            if iv != 0 and niv > 0 {
                si: int = 0;
                while si < niv and si < 64 {
                    sid: int = read_u32(iv, si * 8);
                    sval: int = read_u32(iv, si * 8 + 4);
                    _h2_push_event(slot, H2_EV_SETTINGS_ENTRY, sid, sval, 0, 0, 0);
                    si = si + 1;
                }
            }
        }
    }
    _h2_push_event(slot, H2_EV_FRAME_RECV, stream_id, frame_type, frame_flags, d3, d4);
    return 0;
}

# ── Internal: create an nghttp2 session in an already-allocated slot ──────────

def _h2_make_session(is_server: int, slot: int) -> int {
    # Allocate and configure the callbacks struct.
    cbs: int = nghttp2_alloc_callbacks();
    if cbs == 0 {
        return 0;
    }

    # Install callbacks using untyped locals (triggers ptrtoint coercion).
    cb_bh: int = _h2_cb_begin_headers;
    cb_hd: int = _h2_cb_on_header;
    cb_dc: int = _h2_cb_on_data_chunk;
    cb_sc: int = _h2_cb_on_stream_close;
    cb_fr: int = _h2_cb_on_frame_recv;
    nghttp2_session_callbacks_set_on_begin_headers_callback(cbs, cb_bh);
    nghttp2_session_callbacks_set_on_header_callback(cbs, cb_hd);
    nghttp2_session_callbacks_set_on_data_chunk_recv_callback(cbs, cb_dc);
    nghttp2_session_callbacks_set_on_stream_close_callback(cbs, cb_sc);
    nghttp2_session_callbacks_set_on_frame_recv_callback(cbs, cb_fr);

    # Create the session.  session_ptr is a holder for nghttp2_session**.
    holder: int = calloc(1, 8);
    rc: int = 0;
    if is_server == 0 {
        rc = nghttp2_session_client_new3(holder, cbs, slot, 0, 0);
    } else {
        rc = nghttp2_session_server_new3(holder, cbs, slot, 0, 0);
    }
    session: int = read_u64(holder, 0);
    free(holder);
    nghttp2_session_callbacks_del(cbs);
    if rc != 0 or session == 0 {
        return 0;
    }
    return session;
}

# ── Internal: find or create a free slot ──────────────────────────────────────

def _h2_alloc_slot -> int {
    i: int = 0;
    while i < len(_H2_SESS_PTR) {
        if _H2_SESS_PTR[i] == 0 {
            return i;
        }
        i = i + 1;
    }
    _H2_SESS_PTR.append(0);
    _H2_SESS_EBUF.append(0);
    _H2_SESS_SPTR.append(0);
    return len(_H2_SESS_PTR) - 1;
}

# ── Internal: validate a handle and return the session pointer (0 = invalid) ──

def _h2_session_of(handle: int) -> int {
    if handle < H2_HANDLE_BASE {
        return 0;
    }
    slot: int = _h2_to_slot(handle);
    if slot < 0 or slot >= len(_H2_SESS_PTR) {
        return 0;
    }
    return _H2_SESS_PTR[slot];
}

# ── 606: h2_session_create_client ────────────────────────────────────────────
# args[0]: (reserved) socket handle — not consumed during create
# Returns: h2 handle (int >= 10000) on success, -1 on failure.

def:pub h2_session_create_client(args: list[JSValue]) -> JSValue {
    slot: int = _h2_alloc_slot();
    buf: int = calloc(1, H2_BUF_SIZE);
    if buf == 0 {
        return jsv_from_int32(0 - 1);
    }
    _H2_SESS_EBUF[slot] = buf;

    session: int = _h2_make_session(0, slot);
    if session == 0 {
        free(buf);
        _H2_SESS_EBUF[slot] = 0;
        return jsv_from_int32(0 - 1);
    }
    _H2_SESS_PTR[slot] = session;

    # Queue the client connection preface SETTINGS frame.
    iv: int = nghttp2_settings_alloc(3);
    nghttp2_settings_set(iv, 0, NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE, 65535);
    nghttp2_settings_set(iv, 1, NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS, 100);
    nghttp2_settings_set(iv, 2, NGHTTP2_SETTINGS_ENABLE_PUSH, 0);
    nghttp2_submit_settings(session, 0, iv, 3);
    free(iv);

    return jsv_from_int32(_h2_to_handle(slot));
}

# ── 607: h2_session_create_server ────────────────────────────────────────────
# Returns: h2 handle (int >= 10000) on success, -1 on failure.

def:pub h2_session_create_server(args: list[JSValue]) -> JSValue {
    slot: int = _h2_alloc_slot();
    buf: int = calloc(1, H2_BUF_SIZE);
    if buf == 0 {
        return jsv_from_int32(0 - 1);
    }
    _H2_SESS_EBUF[slot] = buf;

    session: int = _h2_make_session(1, slot);
    if session == 0 {
        free(buf);
        _H2_SESS_EBUF[slot] = 0;
        return jsv_from_int32(0 - 1);
    }
    _H2_SESS_PTR[slot] = session;

    # Queue server initial SETTINGS.
    # Omit MAX_CONCURRENT_STREAMS so the peer sees the HTTP/2 default (2^32-1),
    # matching Node's createServer() preface — session.settings() can lower it.
    iv: int = nghttp2_settings_alloc(1);
    nghttp2_settings_set(iv, 0, NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE, 65535);
    nghttp2_submit_settings(session, 0, iv, 1);
    free(iv);

    return jsv_from_int32(_h2_to_handle(slot));
}

# ── 608: h2_session_del ───────────────────────────────────────────────────────
# args[0]: h2 handle

def:pub h2_session_del(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    if handle < H2_HANDLE_BASE {
        return js_undefined();
    }
    slot: int = _h2_to_slot(handle);
    if slot < 0 or slot >= len(_H2_SESS_PTR) {
        return js_undefined();
    }

    session: int = _H2_SESS_PTR[slot];
    if session != 0 {
        nghttp2_session_del(session);
        _H2_SESS_PTR[slot] = 0;
    }
    _h2_dq_release_slot(slot);
    buf: int = _H2_SESS_EBUF[slot];
    if buf != 0 {
        free(buf);
        _H2_SESS_EBUF[slot] = 0;
    }
    if slot < len(_H2_SESS_SPTR) {
        _H2_SESS_SPTR[slot] = 0;
    }
    return js_undefined();
}

# ── 609: h2_session_recv ─────────────────────────────────────────────────────
# Feed raw bytes from the socket into the nghttp2 session.
# Callbacks fire during this call and append events to the event buffer.
# args[0]: h2 handle
# args[1]: data pointer (C heap int)
# args[2]: data length (int)
# Returns: bytes consumed (int), or negative error code.

def:pub h2_session_recv(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    data_ptr: int = 0;
    if jsv_is_int32(args[1]) {
        data_ptr = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        data_ptr = int(jsv_to_double(args[1]));
    }
    data_len: int = 0;
    if jsv_is_int32(args[2]) {
        data_len = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        data_len = int(jsv_to_double(args[2]));
    }

    rc: int = nghttp2_session_mem_recv(session, data_ptr, data_len);
    return jsv_from_int32(rc);
}

# ── 610: h2_session_send ─────────────────────────────────────────────────────
# Drain the session's outgoing frame queue.
# args[0]: h2 handle
# Returns: { dataPtr: float, length: int }
#   dataPtr — C pointer to bytes owned by nghttp2 (valid until next API call)
#   length  — byte count; 0 means nothing more to send this round
#   Callers loop calling h2SessionSend until length == 0.

def:pub h2_session_send(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return js_undefined();
    }

    # nghttp2_session_mem_send fills *data_out with a C pointer.
    holder: int = calloc(1, 8);
    n: int = nghttp2_session_mem_send(session, holder);
    data_out: int = read_u64(holder, 0);
    free(holder);

    # Store the data pointer so h2_get_send_ptr (kind 621) can retrieve it.
    # The pointer is owned by nghttp2 and valid until the next nghttp2 API call.
    slot: int = _h2_to_slot(handle);
    if slot >= 0 and slot < len(_H2_SESS_SPTR) {
        _H2_SESS_SPTR[slot] = data_out;
    }

    return jsv_from_int32(n);
}

# ── 611: h2_submit_request ───────────────────────────────────────────────────
# Submit a HEADERS frame on the client side.
# args[0]: h2 handle
# args[1]: nva pointer (C heap — use nghttp2_nv_alloc/set from libnghttp2)
# args[2]: nvlen (int, number of header entries in nva)
# Returns: stream_id (positive int) on success, or negative error code.

def:pub h2_submit_request(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    nva: int = 0;
    if jsv_is_int32(args[1]) {
        nva = jsv_to_int32(args[1]);
    }
    nvlen: int = 0;
    if jsv_is_int32(args[2]) {
        nvlen = jsv_to_int32(args[2]);
    }

    # pri_spec=0 (default priority), data_prd=0 (no body), stream_user_data=0
    stream_id: int = nghttp2_submit_request(session, 0, nva, nvlen, 0, 0);
    return jsv_from_int32(stream_id);
}

# ── 612: h2_submit_response ──────────────────────────────────────────────────
# Submit a HEADERS frame on the server side.
# args[0]: h2 handle
# args[1]: stream_id (int) — from H2_EV_BEGIN_HEADERS
# args[2]: nva pointer (C heap)
# args[3]: nvlen (int)
# Returns: 0 on success, negative error code on failure.

def:pub h2_submit_response(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        stream_id = jsv_to_int32(args[1]);
    }
    nva: int = 0;
    if jsv_is_int32(args[2]) {
        nva = jsv_to_int32(args[2]);
    }
    nvlen: int = 0;
    if jsv_is_int32(args[3]) {
        nvlen = jsv_to_int32(args[3]);
    }

    # data_prd=0 (no body; body support is Phase F)
    rc: int = nghttp2_submit_response(session, stream_id, nva, nvlen, 0);
    return jsv_from_int32(rc);
}

# ── 613: h2_submit_settings ──────────────────────────────────────────────────
# Transmit a SETTINGS frame with custom parameters.
# args[0]: h2 handle
# args[1]: either
#   (a) JS Array of alternating settings id/value ints  [id0, val0, id1, val1, ...]
#   (b) iv pointer (C heap — use nghttp2_settings_alloc/set from libnghttp2)
# args[2]: niv (int) — only required for the pointer form (b)
# Returns: 0 on success, negative error code on failure.

def:pub h2_submit_settings(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    # JS-friendly flat array form.
    if len(args) >= 2 and js_is_array(args[1]) {
        n: int = js_array_len(args[1]);
        niv: int = n // 2;  # integer division: `/` yields float (not assignable to int)
        if niv <= 0 {
            rc0: int = nghttp2_submit_settings(session, 0, 0, 0);
            return jsv_from_int32(rc0);
        }
        iv_arr: int = nghttp2_settings_alloc(niv);
        if iv_arr == 0 {
            return jsv_from_int32(0 - 1);
        }
        i: int = 0;
        slot_i: int = 0;
        while i < n - 1 {
            id_jsv: JSValue = js_array_get(args[1], i);
            val_jsv: JSValue = js_array_get(args[1], i + 1);
            sid: int = 0;
            sval: int = 0;
            if jsv_is_int32(id_jsv) {
                sid = jsv_to_int32(id_jsv);
            } elif jsv_is_double(id_jsv) {
                sid = int(jsv_to_double(id_jsv));
            }
            if jsv_is_int32(val_jsv) {
                sval = jsv_to_int32(val_jsv);
            } elif jsv_is_double(val_jsv) {
                sval = int(jsv_to_double(val_jsv));
            }
            nghttp2_settings_set(iv_arr, slot_i, sid, sval);
            slot_i = slot_i + 1;
            i = i + 2;
        }
        rc1: int = nghttp2_submit_settings(session, 0, iv_arr, niv);
        free(iv_arr);
        return jsv_from_int32(rc1);
    }

    # Legacy C-pointer form.
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    iv: int = 0;
    if jsv_is_int32(args[1]) {
        iv = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        iv = int(jsv_to_double(args[1]));
    }
    niv2: int = 0;
    if jsv_is_int32(args[2]) {
        niv2 = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        niv2 = int(jsv_to_double(args[2]));
    }

    rc: int = nghttp2_submit_settings(session, 0, iv, niv2);
    return jsv_from_int32(rc);
}

# ── 614: h2_submit_goaway ────────────────────────────────────────────────────
# args[0]: h2 handle
# args[1]: last_stream_id (int)
# args[2]: error_code (int — use NGHTTP2_* constants from libnghttp2)
# args[3]: optional opaque payload (binary-safe JS string, one char per byte)
# Returns: 0 on success, negative error code.

def:pub h2_submit_goaway(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    last_stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        last_stream_id = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        last_stream_id = int(jsv_to_double(args[1]));
    }
    error_code: int = 0;
    if jsv_is_int32(args[2]) {
        error_code = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        error_code = int(jsv_to_double(args[2]));
    }

    opaque_ptr: int = 0;
    opaque_len: int = 0;
    if len(args) >= 4
        and (not jsv_is_undefined(args[3]))
        and (not jsv_is_null(args[3])) {
        opaque_s: str = js_to_string_prim(args[3]);
        opaque_len = len(opaque_s);
        if opaque_len > 0 {
            opaque_ptr = calloc(1, opaque_len + 1);
            oi: int = 0;
            while oi < opaque_len {
                write_byte(opaque_ptr, oi, ord(opaque_s[oi]) & 255);
                oi = oi + 1;
            }
        }
    }

    # flags=0; nghttp2 copies opaque_data before returning.
    rc: int = nghttp2_submit_goaway(
        session, 0, last_stream_id, error_code, opaque_ptr, opaque_len
    );
    if opaque_ptr != 0 {
        free(opaque_ptr);
    }
    return jsv_from_int32(rc);
}

# ── 615: h2_submit_rst_stream ────────────────────────────────────────────────
# args[0]: h2 handle
# args[1]: stream_id (int)
# args[2]: error_code (int)
# Returns: 0 on success, negative error code.

def:pub h2_submit_rst_stream(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        handle = int(jsv_to_double(args[0]));
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        stream_id = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        stream_id = int(jsv_to_double(args[1]));
    }
    error_code: int = 0;
    if jsv_is_int32(args[2]) {
        error_code = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        error_code = int(jsv_to_double(args[2]));
    }

    rc: int = nghttp2_submit_rst_stream(session, 0, stream_id, error_code);
    return jsv_from_int32(rc);
}

# ── 616: h2_session_want_read ────────────────────────────────────────────────
# args[0]: h2 handle
# Returns: 1 if session wants to read, 0 otherwise.

def:pub h2_session_want_read(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_int32(0);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0);
    }
    return jsv_from_int32(nghttp2_session_want_read(session));
}

# ── 617: h2_session_want_write ───────────────────────────────────────────────
# args[0]: h2 handle
# Returns: 1 if session wants to write, 0 otherwise.

def:pub h2_session_want_write(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_int32(0);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0);
    }
    return jsv_from_int32(nghttp2_session_want_write(session));
}

# ── 618: h2_consume ──────────────────────────────────────────────────────────
# Mark bytes as consumed for flow control.
# args[0]: h2 handle
# args[1]: stream_id (int, use 0 for connection-level)
# args[2]: size (int, bytes consumed)
# Returns: 0 on success, negative error code.

def:pub h2_consume(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        stream_id = jsv_to_int32(args[1]);
    }
    size: int = 0;
    if jsv_is_int32(args[2]) {
        size = jsv_to_int32(args[2]);
    }

    rc: int = nghttp2_session_consume(session, stream_id, size);
    return jsv_from_int32(rc);
}

# ── 619: h2_submit_window_update ─────────────────────────────────────────────
# Send an explicit WINDOW_UPDATE frame.
# args[0]: h2 handle
# args[1]: stream_id (int, 0 = connection-level)
# args[2]: window_size_increment (int)
# Returns: 0 on success, negative error code.

def:pub h2_submit_window_update(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        stream_id = jsv_to_int32(args[1]);
    }
    increment: int = 0;
    if jsv_is_int32(args[2]) {
        increment = jsv_to_int32(args[2]);
    }

    rc: int = nghttp2_submit_window_update(session, 0, stream_id, increment);
    return jsv_from_int32(rc);
}

# ── 620: h2_pop_event ────────────────────────────────────────────────────────
# Pop the oldest event from the session's event buffer (FIFO).
# args[0]: h2 handle
# Returns: { type, d0, d1, d2, d3, d4 } JSObject, or js_undefined() if empty.
#
# Consumers should poll in a loop after h2_session_recv until undefined:
#   let ev; while ((ev = __net.h2PopEvent(h)) !== undefined) { handleEv(ev); }

def:pub h2_pop_event(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    if handle < H2_HANDLE_BASE {
        return js_undefined();
    }
    slot: int = _h2_to_slot(handle);
    if slot < 0 or slot >= len(_H2_SESS_EBUF) {
        return js_undefined();
    }

    buf: int = _H2_SESS_EBUF[slot];
    if buf == 0 {
        return js_undefined();
    }

    count: int = read_u64(buf, 0);
    if count <= 0 {
        return js_undefined();
    }

    # Read the first event (offset H2_BUF_HDR).
    base: int = buf + H2_BUF_HDR;
    ev_type: int = read_u64(base, 0);
    d0: int = read_u64(base, 8);
    d1: int = read_u64(base, 16);
    d2: int = read_u64(base, 24);
    d3: int = read_u64(base, 32);
    d4: int = read_u64(base, 40);

    # Shift remaining events down by one slot.
    if count > 1 {
        src_start: int = buf + H2_BUF_HDR + H2_EVENT_SIZE;
        dst_start: int = buf + H2_BUF_HDR;
        n_bytes: int = (count - 1) * H2_EVENT_SIZE;
        memcpy(dst_start, src_start, n_bytes);
    }
    write_i64(buf, 0, count - 1);

    ev: JSValue = js_object_create_null();
    js_object_set(ev, str_intern("type"), jsv_from_int32(ev_type));
    js_object_set(ev, str_intern("d0"), jsv_from_double(float(d0)));
    js_object_set(ev, str_intern("d1"), jsv_from_double(float(d1)));
    js_object_set(ev, str_intern("d2"), jsv_from_double(float(d2)));
    js_object_set(ev, str_intern("d3"), jsv_from_double(float(d3)));
    js_object_set(ev, str_intern("d4"), jsv_from_double(float(d4)));
    return ev;
}

# ── 621: h2_get_send_ptr ─────────────────────────────────────────────────────
# Return the data pointer stored by the most recent h2_session_send call.
# Must be called before any other nghttp2 API (pointer is nghttp2-owned).
# args[0]: h2 handle
# Returns: C pointer as Float64 JSValue (Float64 holds 47-bit userspace ptrs
#          exactly on x86-64 Linux), or 0.0 if no send was done.

def:pub h2_get_send_ptr(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_double(0.0);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    if handle < H2_HANDLE_BASE {
        return jsv_from_double(0.0);
    }
    slot: int = _h2_to_slot(handle);
    if slot < 0 or slot >= len(_H2_SESS_SPTR) {
        return jsv_from_double(0.0);
    }
    return jsv_from_double(float(_H2_SESS_SPTR[slot]));
}

# ── Internal: build an nghttp2_nv array from a JS flat string Array ──────────
# hdr_arr is a JSValue containing a JS Array of alternating name/value strings:
#   ["name0", "value0", "name1", "value1", ...]
# Returns (nva pointer, nvlen) packed as two Jac ints.  Caller must free nva.
# Returns (0, 0) on allocation failure.

def _build_nva(hdr_arr: JSValue) -> list[int] {
    n: int = js_array_len(hdr_arr);
    nvlen: int = n // 2;
    if nvlen <= 0 {
        result: list[int] = [0, 0];
        return result;
    }
    nva: int = nghttp2_nv_alloc(nvlen);
    if nva == 0 {
        result2: list[int] = [0, 0];
        return result2;
    }
    # Each nghttp2_nv is NGHTTP2_NV_SIZE bytes.
    # We allocate a C copy of each string so the nva outlives the Jac str.
    i: int = 0;
    slot_idx: int = 0;
    while i < n - 1 {
        name_jsv: JSValue = js_array_get(hdr_arr, i);
        val_jsv: JSValue = js_array_get(hdr_arr, i + 1);
        name_s: str = js_to_string_prim(name_jsv);
        val_s: str = js_to_string_prim(val_jsv);
        name_len: int = len(name_s);
        val_len: int = len(val_s);
        name_ptr: int = calloc(1, name_len + 1);
        val_ptr: int = calloc(1, val_len + 1);
        # Copy name bytes
        ni: int = 0;
        while ni < name_len {
            write_byte(name_ptr, ni, ord(name_s[ni]));
            ni = ni + 1;
        }
        # Copy value bytes
        vi: int = 0;
        while vi < val_len {
            write_byte(val_ptr, vi, ord(val_s[vi]));
            vi = vi + 1;
        }
        nghttp2_nv_set(
            nva, slot_idx, name_ptr, name_len, val_ptr, val_len, NGHTTP2_NV_FLAG_NONE
        );
        slot_idx = slot_idx + 1;
        i = i + 2;
    }
    result3: list[int] = [nva, nvlen];
    return result3;
}

# ── Internal: free the C copies of name/value strings stored in an nva ─────

def _free_nva_strs(nva: int, nvlen: int) {
    i: int = 0;
    while i < nvlen {
        name_ptr: int = read_u64(nva + i * NGHTTP2_NV_SIZE, NGHTTP2_NV_OFF_NAME);
        val_ptr: int = read_u64(nva + i * NGHTTP2_NV_SIZE, NGHTTP2_NV_OFF_VALUE);
        if name_ptr != 0 {
            free(name_ptr);
        }
        if val_ptr != 0 {
            free(val_ptr);
        }
        i = i + 1;
    }
}

# ── 622: h2_request ──────────────────────────────────────────────────────────
# JS-friendly client request submission.
# args[0]: h2 handle
# args[1]: JS Array of alternating header name/value strings
# Returns: stream_id (positive int) on success, -1 on failure.

def:pub h2_request(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    # args[2] (optional): 1 when the request carries a body.  Without a data
    # provider nghttp2 sets END_STREAM on the HEADERS frame, which would make
    # any later h2_submit_data land on a half-closed stream.
    has_body: int = 0;
    if len(args) >= 3 {
        if jsv_is_int32(args[2]) {
            has_body = jsv_to_int32(args[2]);
        } elif jsv_is_double(args[2]) {
            has_body = int(jsv_to_double(args[2]));
        }
    }

    nva_info: list[int] = _build_nva(args[1]);
    nva: int = nva_info[0];
    nvlen: int = nva_info[1];
    if nva == 0 {
        return jsv_from_int32(0 - 1);
    }

    slot: int = _h2_to_slot(handle);
    prd: int = 0;
    if has_body != 0 {
        prd = nghttp2_data_prd_alloc(slot, _h2_data_read_cb_ptr());
    }
    stream_id: int = nghttp2_submit_request(session, 0, nva, nvlen, prd, 0);
    if prd != 0 {
        free(prd);
        if stream_id > 0 {
            _H2_DQ_ATTACHED[_h2_dq_ensure(slot, stream_id)] = 1;
        }
    }

    _free_nva_strs(nva, nvlen);
    free(nva);

    return jsv_from_int32(stream_id);
}

# ── 623: h2_respond ──────────────────────────────────────────────────────────
# JS-friendly server response submission.
# args[0]: h2 handle
# args[1]: stream_id (int)
# args[2]: JS Array of alternating header name/value strings
# Returns: 0 on success, negative error code on failure.

def:pub h2_respond(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        handle = int(jsv_to_double(args[0]));
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    # Stream ids from h2PopEvent arrive as JS numbers (doubles) — accept both.
    stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        stream_id = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        stream_id = int(jsv_to_double(args[1]));
    }

    # args[3] (optional): 1 when the response carries a body — see h2_request.
    has_body: int = 0;
    if len(args) >= 4 {
        if jsv_is_int32(args[3]) {
            has_body = jsv_to_int32(args[3]);
        } elif jsv_is_double(args[3]) {
            has_body = int(jsv_to_double(args[3]));
        }
    }

    nva_info2: list[int] = _build_nva(args[2]);
    nva2: int = nva_info2[0];
    nvlen2: int = nva_info2[1];
    if nva2 == 0 {
        return jsv_from_int32(0 - 1);
    }

    slot: int = _h2_to_slot(handle);
    prd2: int = 0;
    if has_body != 0 {
        prd2 = nghttp2_data_prd_alloc(slot, _h2_data_read_cb_ptr());
    }
    rc: int = nghttp2_submit_response(session, stream_id, nva2, nvlen2, prd2);
    if prd2 != 0 {
        free(prd2);
        if rc == 0 {
            _H2_DQ_ATTACHED[_h2_dq_ensure(slot, stream_id)] = 1;
        }
    }

    _free_nva_strs(nva2, nvlen2);
    free(nva2);

    return jsv_from_int32(rc);
}

# ── 970: h2_submit_data ──────────────────────────────────────────────────────
# Queue body bytes for a stream and let nghttp2 pull them as DATA frames.
# args[0]: h2 handle
# args[1]: stream_id (int)
# args[2]: payload (binary-safe JS string, one char per byte); may be empty
# args[3]: endStream mode:
#            0 — more body may follow
#            1 — body complete; DATA carries END_STREAM
#            2 — body complete; DATA has EOF|NO_END_STREAM (trailers follow)
# Returns: number of bytes queued, or a negative nghttp2 error code.

def:pub h2_submit_data(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        stream_id = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        stream_id = int(jsv_to_double(args[1]));
    }
    if stream_id <= 0 {
        return jsv_from_int32(0 - 1);
    }

    payload: str = "";
    if len(args) >= 3 {
        payload = js_to_string_prim(args[2]);
    }
    end_stream: int = 0;
    if len(args) >= 4 {
        if jsv_is_int32(args[3]) {
            end_stream = jsv_to_int32(args[3]);
        } elif jsv_is_double(args[3]) {
            end_stream = int(jsv_to_double(args[3]));
        }
    }

    slot: int = _h2_to_slot(handle);
    idx: int = _h2_dq_ensure(slot, stream_id);

    n: int = len(payload);
    if n > 0 {
        _h2_dq_reserve(idx, n);
        base: int = _H2_DQ_BUF[idx] + _H2_DQ_LEN[idx];
        i: int = 0;
        while i < n {
            write_byte(base, i, ord(payload[i]) & 255);
            i = i + 1;
        }
        _H2_DQ_LEN[idx] = _H2_DQ_LEN[idx] + n;
    }
    if end_stream != 0 {
        _H2_DQ_EOF[idx] = 1;
        if end_stream == 2 {
            _H2_DQ_NO_END[idx] = 1;
        }
    }

    # h2_request / h2_respond normally attach the provider along with HEADERS.
    # If they did not, attach one now; afterwards a provider parked on
    # NGHTTP2_ERR_DEFERRED only needs an explicit resume.
    if _H2_DQ_ATTACHED[idx] == 0 {
        prd: int = nghttp2_data_prd_alloc(slot, _h2_data_read_cb_ptr());
        if prd != 0 {
            rc: int = nghttp2_submit_data(
                session, NGHTTP2_FLAG_END_STREAM, stream_id, prd
            );
            free(prd);
            if rc != 0 {
                return jsv_from_int32(rc);
            }
            _H2_DQ_ATTACHED[idx] = 1;
        }
    } elif _H2_DQ_DEFER[idx] != 0 {
        _H2_DQ_DEFER[idx] = 0;
        nghttp2_session_resume_data(session, stream_id);
    }
    return jsv_from_int32(n);
}

# ── 971: h2_submit_trailer ───────────────────────────────────────────────────
# Submit trailing HEADERS with END_STREAM (after DATA with NO_END_STREAM).
# args[0]: h2 handle
# args[1]: stream_id (int)
# args[2]: JS Array of alternating header name/value strings
# Returns: 0 on success, negative error code on failure.

def:pub h2_submit_trailer(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    stream_id: int = 0;
    if jsv_is_int32(args[1]) {
        stream_id = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        stream_id = int(jsv_to_double(args[1]));
    }
    if stream_id <= 0 {
        return jsv_from_int32(0 - 1);
    }

    nva_info: list[int] = _build_nva(args[2]);
    nva: int = nva_info[0];
    nvlen: int = nva_info[1];
    if nva == 0 {
        # Empty trailer list — still submit (closes the stream).
        rc0: int = nghttp2_submit_trailer(session, stream_id, 0, 0);
        return jsv_from_int32(rc0);
    }

    rc: int = nghttp2_submit_trailer(session, stream_id, nva, nvlen);
    _free_nva_strs(nva, nvlen);
    free(nva);
    return jsv_from_int32(rc);
}

# ── 972: h2_set_local_window_size ────────────────────────────────────────────
# Absolute connection-level (stream_id=0) local window size — Node's
# session.setLocalWindowSize(windowSize).
# args[0]: h2 handle
# args[1]: window_size (int)
# Returns: 0 on success, negative error code.

def:pub h2_set_local_window_size(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return jsv_from_int32(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0 - 1);
    }

    window_size: int = 0;
    if jsv_is_int32(args[1]) {
        window_size = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        window_size = int(jsv_to_double(args[1]));
    }

    rc: int = nghttp2_session_set_local_window_size(session, 0, 0, window_size);
    return jsv_from_int32(rc);
}

# ── 973: h2_get_remote_setting ───────────────────────────────────────────────
# args[0]: h2 handle
# args[1]: settings_id (int, RFC 7540 §6.5.2)
# Returns: uint32 setting value.

def:pub h2_get_remote_setting(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return jsv_from_int32(0);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        handle = int(jsv_to_double(args[0]));
    }
    session: int = _h2_session_of(handle);
    if session == 0 {
        return jsv_from_int32(0);
    }
    sid: int = 0;
    if jsv_is_int32(args[1]) {
        sid = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        sid = int(jsv_to_double(args[1]));
    }
    return jsv_from_int32(nghttp2_session_get_remote_settings(session, sid));
}

# NOTE: Smoke tests were moved to engine/src/builtins/http2_bridge_test.na.jac
# Library modules must NOT contain `with entry {}` blocks — the compiler always
# emits `jac_entry` from them, even for imported modules, which collides with the
# main module's `jac_entry` and causes a SIGSEGV at JIT startup.
# See: js_engine/issues/with-entry-in-imported-module-collides-jac-entry/
