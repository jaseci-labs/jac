"""nghttp2 C FFI bindings for js_engine.

nghttp2 is the HTTP/2 C library used by Node.js, curl, and many others.
Version: 1.59.0  (system-installed; bound by its soname libnghttp2.so.14,
which the runtime package ships — the bare libnghttp2.so is only in -dev)

Struct sizes (verified with gcc against nghttp2 1.59.0 headers, x86-64 LP64):
    nghttp2_nv             = 40 bytes  (name*:8, value*:8, namelen:8, valuelen:8, flags:1 + 7 pad)
    nghttp2_settings_entry =  8 bytes  (settings_id:4, value:4)

Key nghttp2_nv field offsets:
    name     → 0   (uint8_t*)
    value    → 8   (uint8_t*)
    namelen  → 16  (size_t)
    valuelen → 24  (size_t)
    flags    → 32  (uint8_t)

Key nghttp2_settings_entry field offsets:
    settings_id → 0  (int32_t)
    value       → 4  (uint32_t)

All session/callbacks handles are opaque C pointers stored as Jac int.

Bun reference: bun/src/bun.js/bindings/nghttp2.h  (system lib, not vendored)
Phase: D (HTTP/2 FFI foundation)
"""

import from "libnghttp2.so.14" {
    # ── Session lifecycle ─────────────────────────────────────────────────────

    # Create a client session. session_ptr is a (nghttp2_session**) C pointer;
    # on return *session_ptr holds the allocated session. Returns 0 on success.
    def:pub nghttp2_session_client_new3(
        session_ptr: int, callbacks: int, user_data: int, option: int, mem: int
    ) -> int;
    # Create a server session. Same calling convention as client_new3.
    def:pub nghttp2_session_server_new3(
        session_ptr: int, callbacks: int, user_data: int, option: int, mem: int
    ) -> int;
    # Free a session allocated by *_new3.
    def:pub nghttp2_session_del(session: int) -> None;
    # ── I/O ───────────────────────────────────────────────────────────────────

    # Drive the session's receive path (reads via recv_callback).
    def:pub nghttp2_session_recv(session: int) -> int;
    # Drive the session's send path (writes via send_callback).
    def:pub nghttp2_session_send(session: int) -> int;
    # Feed raw bytes into the session (no recv_callback).
    # Returns bytes consumed, or negative error code.
    def:pub nghttp2_session_mem_recv(session: int, data: int, datalen: int) -> int;
    # Get the next chunk to send (no send_callback).
    # data_out receives the pointer; returns byte count or negative error code.
    def:pub nghttp2_session_mem_send(session: int, data_out: int) -> int;
    # ── State queries ─────────────────────────────────────────────────────────

    def:pub nghttp2_session_want_read(session: int) -> int;  def:
        pub nghttp2_session_want_write(session: int) -> int;  def:
        pub nghttp2_session_check_request_allowed(session: int) -> int;  def:
        pub nghttp2_session_check_server_session(session: int) -> int;
    # ── Frame submission ──────────────────────────────────────────────────────

    # Send a SETTINGS frame. iv is a (nghttp2_settings_entry*) array of niv entries.
    def:pub nghttp2_submit_settings(
        session: int, flags: int, iv: int, niv: int
    ) -> int;
    # Submit a request (HEADERS frame). Returns stream_id or negative error.
    # nva: (nghttp2_nv*), nvlen: count. data_prd: 0 for no body.
    def:pub nghttp2_submit_request(
        session: int,
        pri_spec: int,
        nva: int,
        nvlen: int,
        data_prd: int,
        stream_user_data: int
    ) -> int;
    # Submit a response (HEADERS frame, server side).
    # nva: (nghttp2_nv*), nvlen: count. data_prd: 0 for no body.
    def:pub nghttp2_submit_response(
        session: int, stream_id: int, nva: int, nvlen: int, data_prd: int
    ) -> int;
    # Send a GOAWAY frame and schedule session teardown.
    def:pub nghttp2_submit_goaway(
        session: int,
        flags: int,
        last_stream_id: int,
        error_code: int,
        opaque_data: int,
        opaque_data_len: int
    ) -> int;
    # Send a RST_STREAM frame on stream_id.
    def:pub nghttp2_submit_rst_stream(
        session: int, flags: int, stream_id: int, error_code: int
    ) -> int;
    # Send a PUSH_PROMISE frame (server push).
    def:pub nghttp2_submit_push_promise(
        session: int,
        flags: int,
        promised_stream_id: int,
        nva: int,
        nvlen: int,
        promised_stream_user_data: int
    ) -> int;
    # Send a WINDOW_UPDATE frame.
    def:pub nghttp2_submit_window_update(
        session: int, flags: int, stream_id: int, window_size_increment: int
    ) -> int;
    # Send a PING frame. opaque_data: 0 or 8-byte buffer.
    def:pub nghttp2_submit_ping(session: int, flags: int, opaque_data: int) -> int;
    # Attach a DATA payload to an already-opened stream.
    # data_prd is a (nghttp2_data_provider*) — see NGHTTP2_DATA_PRD_* below.
    # nghttp2 copies the provider struct, so the caller may free it afterwards.
    # Fails with NGHTTP2_ERR_DATA_EXIST if a provider is already attached.
    def:pub nghttp2_submit_data(
        session: int, flags: int, stream_id: int, data_prd: int
    ) -> int;
    # Submit trailing HEADERS (END_STREAM). Call after DATA with
    # NGHTTP2_DATA_FLAG_EOF | NGHTTP2_DATA_FLAG_NO_END_STREAM.
    def:pub nghttp2_submit_trailer(
        session: int, stream_id: int, nva: int, nvlen: int
    ) -> int;
    # Re-arm a data provider that previously returned NGHTTP2_ERR_DEFERRED.
    def:pub nghttp2_session_resume_data(session: int, stream_id: int) -> int;
    # Set the connection/stream local window to an absolute size (Node setLocalWindowSize).
    def:pub nghttp2_session_set_local_window_size(
        session: int, flags: int, stream_id: int, window_size: int
    ) -> int;
    # Query a single remote/local setting (nghttp2_settings_id → uint32 value).
    def:pub nghttp2_session_get_remote_settings(
        session: int, settings_id: int
    ) -> int;  def:pub nghttp2_session_get_local_settings(
        session: int, settings_id: int
    ) -> int;  def:pub nghttp2_session_get_last_proc_stream_id(session: int) -> int;
    # ── Callbacks management ──────────────────────────────────────────────────

    # Allocate a callbacks struct. callbacks_ptr is (nghttp2_session_callbacks**).
    # Returns 0 on success; fills *callbacks_ptr.
    def:pub nghttp2_session_callbacks_new(callbacks_ptr: int) -> int;
    # Free a callbacks struct.
    def:pub nghttp2_session_callbacks_del(callbacks: int) -> None;
    # Install individual callbacks (fn pointer passed as i64).
    # send: ssize_t(session, data, length, flags, user_data)
    def:pub nghttp2_session_callbacks_set_send_callback(cbs: int, cb: int) -> None;
    # recv: ssize_t(session, buf, length, flags, user_data)
    def:pub nghttp2_session_callbacks_set_recv_callback(cbs: int, cb: int) -> None;
    # on_frame_recv: int(session, frame, user_data)
    def:pub nghttp2_session_callbacks_set_on_frame_recv_callback(
        cbs: int, cb: int
    ) -> None;
    # on_begin_headers: int(session, frame, user_data)
    def:pub nghttp2_session_callbacks_set_on_begin_headers_callback(
        cbs: int, cb: int
    ) -> None;
    # on_header: int(session, frame, name, namelen, value, valuelen, flags, user_data)
    def:pub nghttp2_session_callbacks_set_on_header_callback(
        cbs: int, cb: int
    ) -> None;
    # on_data_chunk_recv: int(session, flags, stream_id, data, len, user_data)
    def:pub nghttp2_session_callbacks_set_on_data_chunk_recv_callback(
        cbs: int, cb: int
    ) -> None;
    # on_stream_close: int(session, stream_id, error_code, user_data)
    def:pub nghttp2_session_callbacks_set_on_stream_close_callback(
        cbs: int, cb: int
    ) -> None;
    # on_frame_send: int(session, frame, user_data)
    def:pub nghttp2_session_callbacks_set_on_frame_send_callback(
        cbs: int, cb: int
    ) -> None;
    # on_frame_not_send: int(session, frame, lib_error_code, user_data)
    def:pub nghttp2_session_callbacks_set_on_frame_not_send_callback(
        cbs: int, cb: int
    ) -> None;
    # error callback: int(session, msg, len, user_data)
    def:pub nghttp2_session_callbacks_set_error_callback2(cbs: int, cb: int) -> None;
    # ── Flow control ──────────────────────────────────────────────────────────

    # Mark `size` bytes of connection-level receive window as consumed.
    def:pub nghttp2_session_consume(session: int, stream_id: int, size: int) -> int;  def:
        pub nghttp2_session_consume_connection(session: int, size: int) -> int;  def:
        pub nghttp2_session_consume_stream(
        session: int, stream_id: int, size: int
    ) -> int;
    # ── Stream inspection ─────────────────────────────────────────────────────

    def:pub nghttp2_session_find_stream(session: int, stream_id: int) -> int;  def:
        pub nghttp2_session_get_stream_user_data(session: int, stream_id: int) -> int;  def:
        pub nghttp2_session_set_stream_user_data(
        session: int, stream_id: int, stream_user_data: int
    ) -> int;
    # ── Error helpers ─────────────────────────────────────────────────────────

    # Return a const char* describing a library-level error code.
    def:pub nghttp2_strerror(lib_error_code: int) -> int;
    # Return a const char* naming an RFC 7540 HTTP/2 error code.
    def:pub nghttp2_http2_strerror(error_code: int) -> int;
}

import from engine.src.ffi.libc { calloc, free, memcpy }
import from engine.src.runtime.mem { write_i64, write_i32, read_u64, read_u32 }

# ── NV flags (nghttp2_nv_flag) ────────────────────────────────────────────────

glob:pub NGHTTP2_NV_FLAG_NONE: int = 0,
     NGHTTP2_NV_FLAG_NO_INDEX: int = 1,
     NGHTTP2_NV_FLAG_NO_COPY_NAME: int = 2,
     NGHTTP2_NV_FLAG_NO_COPY_VALUE: int = 4,
     NGHTTP2_SETTINGS_HEADER_TABLE_SIZE: int = 1,
     NGHTTP2_SETTINGS_ENABLE_PUSH: int = 2,
     NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS: int = 3,
     NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE: int = 4,
     NGHTTP2_SETTINGS_MAX_FRAME_SIZE: int = 5,
     NGHTTP2_SETTINGS_MAX_HEADER_LIST_SIZE: int = 6,
     NGHTTP2_NO_ERROR: int = 0,
     NGHTTP2_PROTOCOL_ERROR: int = 1,
     NGHTTP2_INTERNAL_ERROR: int = 2,
     NGHTTP2_FLOW_CONTROL_ERROR: int = 3,
     NGHTTP2_SETTINGS_TIMEOUT: int = 4,
     NGHTTP2_STREAM_CLOSED: int = 5,
     NGHTTP2_FRAME_SIZE_ERROR: int = 6,
     NGHTTP2_REFUSED_STREAM: int = 7,
     NGHTTP2_CANCEL: int = 8,
     NGHTTP2_COMPRESSION_ERROR: int = 9,
     NGHTTP2_CONNECT_ERROR: int = 10,
     NGHTTP2_ENHANCE_YOUR_CALM: int = 11,
     NGHTTP2_INADEQUATE_SECURITY: int = 12,
     NGHTTP2_HTTP_1_1_REQUIRED: int = 13,
     NGHTTP2_DATA: int = 0,
     NGHTTP2_HEADERS: int = 1,
     NGHTTP2_PRIORITY: int = 2,
     NGHTTP2_RST_STREAM: int = 3,
     NGHTTP2_SETTINGS: int = 4,
     NGHTTP2_PUSH_PROMISE: int = 5,
     NGHTTP2_PING: int = 6,
     NGHTTP2_GOAWAY: int = 7,
     NGHTTP2_WINDOW_UPDATE: int = 8,
     NGHTTP2_CONTINUATION: int = 9,
     NGHTTP2_ERR_INVALID_ARGUMENT: int = 0 - 501,
     NGHTTP2_ERR_DATA_EXIST: int = 0 - 529,
     NGHTTP2_ERR_BUFFER_ERROR: int = 0 - 502,
     NGHTTP2_ERR_WOULDBLOCK: int = 0 - 504,
     NGHTTP2_ERR_PROTO: int = 0 - 505,
     NGHTTP2_ERR_EOF: int = 0 - 507,
     NGHTTP2_ERR_DEFERRED: int = 0 - 508,
     NGHTTP2_ERR_STREAM_CLOSED: int = 0 - 510,
     NGHTTP2_ERR_CALLBACK_FAILURE: int = 0 - 902,
     NGHTTP2_ERR_TEMPORAL_CALLBACK_FAILURE: int = 0 - 521,
     NGHTTP2_NV_SIZE: int = 40,
     NGHTTP2_SETTINGS_ENTRY_SIZE: int = 8,
     NGHTTP2_FLAG_END_STREAM: int = 1,
     NGHTTP2_DATA_PRD_SIZE: int = 16,
     NGHTTP2_DATA_PRD_OFF_SRC: int = 0,
     NGHTTP2_DATA_PRD_OFF_CB: int = 8,
     NGHTTP2_DATA_FLAG_NONE: int = 0,
     NGHTTP2_DATA_FLAG_EOF: int = 1,
     NGHTTP2_DATA_FLAG_NO_END_STREAM: int = 2,
     NGHTTP2_DATA_FLAG_NO_COPY: int = 4,
     NGHTTP2_NV_OFF_NAME: int = 0,
     NGHTTP2_NV_OFF_VALUE: int = 8,
     NGHTTP2_NV_OFF_NAMELEN: int = 16,
     NGHTTP2_NV_OFF_VALUELEN: int = 24,
     NGHTTP2_NV_OFF_FLAGS: int = 32,
     NGHTTP2_SE_OFF_ID: int = 0,
     NGHTTP2_SE_OFF_VALUE: int = 4;

# skip HPACK indexing
# name ptr is caller-owned
# value ptr is caller-owned

# ── Settings IDs (nghttp2_settings_id) ───────────────────────────────────────

# default 4096
# server push
# default unlimited
# default 65535
# default 16384

# ── HTTP/2 RFC 7540 §7 error codes ───────────────────────────────────────────

# ── Frame type constants ──────────────────────────────────────────────────────

# ── Library-level error codes (NGHTTP2_ERR_*) ─────────────────────────────────

# ── Struct size constants (x86-64 LP64, verified) ────────────────────────────

# nghttp2_nv (8+8+8+8+1+7pad)
# nghttp2_settings_entry (4+4)

# ── DATA frame flags (nghttp2_flag, RFC 7540 §6.1) ───────────────────────────

# ── Data provider (nghttp2_data_provider) ────────────────────────────────────
# struct { nghttp2_data_source source; nghttp2_data_source_read_callback cb; }
# nghttp2_data_source is a union { int fd; void *ptr; } → 8 bytes.
#
# The read callback has C signature
#   ssize_t (*)(nghttp2_session *session, int32_t stream_id, uint8_t *buf,
#               size_t length, uint32_t *data_flags,
#               nghttp2_data_source *source, void *user_data)
# and is passed as a plain i64 function pointer (ptrtoint coercion).

# nghttp2_data_source (8 bytes)
# read callback pointer

# ── nghttp2_data_flag (values OR-ed into *data_flags by the read callback) ───

# ── nghttp2_nv field offsets ──────────────────────────────────────────────────

# uint8_t*
# uint8_t*
# size_t
# size_t
# uint8_t

# ── nghttp2_settings_entry field offsets ──────────────────────────────────────

# int32_t (settings_id)
# uint32_t
# ── High-level helpers ────────────────────────────────────────────────────────

"""Allocate a C heap array of `n` nghttp2_nv entries, zero-initialised.
Caller must free the returned pointer when done with nghttp2_submit_*."""
def:pub nghttp2_nv_alloc(n: int) -> int {
    return calloc(n, NGHTTP2_NV_SIZE);
}

"""Write one nghttp2_nv entry at slot `i` in a calloc'd nva array.
`name_ptr` and `value_ptr` must remain valid until after nghttp2_session_send().
Use NGHTTP2_NV_FLAG_NONE as flags for normal indexed headers."""
def:pub nghttp2_nv_set(
    nva: int,
    i: int,
    name_ptr: int,
    name_len: int,
    value_ptr: int,
    value_len: int,
    flags: int
) {
    base: int = nva + i * NGHTTP2_NV_SIZE;
    write_i64(base, NGHTTP2_NV_OFF_NAME, name_ptr);
    write_i64(base, NGHTTP2_NV_OFF_VALUE, value_ptr);
    write_i64(base, NGHTTP2_NV_OFF_NAMELEN, name_len);
    write_i64(base, NGHTTP2_NV_OFF_VALUELEN, value_len);
    write_i32(base, NGHTTP2_NV_OFF_FLAGS, flags);
}

"""Allocate a C heap array of `n` nghttp2_settings_entry structs, zero-initialised."""
def:pub nghttp2_settings_alloc(n: int) -> int {
    return calloc(n, NGHTTP2_SETTINGS_ENTRY_SIZE);
}

"""Write one settings entry at slot `i` in a calloc'd settings array.
`id` should be one of the NGHTTP2_SETTINGS_* constants."""
def:pub nghttp2_settings_set(iv: int, i: int, id: int, value: int) {
    base: int = iv + i * NGHTTP2_SETTINGS_ENTRY_SIZE;
    write_i32(base, NGHTTP2_SE_OFF_ID, id);
    write_i32(base, NGHTTP2_SE_OFF_VALUE, value);
}

"""Allocate and populate an nghttp2_data_provider on the C heap.
`source` is stored in the union slot; `read_cb` is the i64 function pointer.
Caller must free the returned pointer once nghttp2_submit_data has copied it."""
def:pub nghttp2_data_prd_alloc(source: int, read_cb: int) -> int {
    prd: int = calloc(1, NGHTTP2_DATA_PRD_SIZE);
    if prd == 0 {
        return 0;
    }
    write_i64(prd, NGHTTP2_DATA_PRD_OFF_SRC, source);
    write_i64(prd, NGHTTP2_DATA_PRD_OFF_CB, read_cb);
    return prd;
}

"""Allocate a callbacks struct and return the (nghttp2_session_callbacks*) pointer.
Returns 0 if allocation failed."""
def:pub nghttp2_alloc_callbacks -> int {
    holder: int = calloc(1, 8);
    rc: int = nghttp2_session_callbacks_new(holder);
    cbs: int = read_u64(holder, 0);
    free(holder);
    if rc != 0 {
        return 0;
    }
    return cbs;
}

# NOTE: Smoke tests moved to engine/src/ffi/libnghttp2_test.na.jac
# Library (FFI) modules must NOT contain `with entry {}` blocks — the compiler
# always emits `jac_entry` from them even when compiling as an imported module,
# which overwrites the main module's entry point and crashes with SIGSEGV.
# See: js_engine/issues/with-entry-in-imported-module-collides-jac-entry/
