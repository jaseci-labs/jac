"""
Native HTTP/1.x request reader using llhttp — server-side request parsing.

Reads raw bytes from the socket and feeds them to llhttp which fires callbacks
to accumulate method, URL, headers, and body.

Exposed to JS as:  __net.readHTTPRequest(handle, maxBodySize)
Returns JSValue object:  { method, url, httpVersion, headers, body, upgrade }

  - method:      "GET" | "POST" | … (string)
  - url:         "/path?query" (string)
  - httpVersion: "1.1" or "1.0" (string)
  - headers:     raw header lines "field: value\r\n…" (string)
                 → JS side converts with _headersStrToHeaders()
  - body:        request body (string, empty for GET/HEAD)
  - upgrade:     1 if an Upgrade header is present, 0 otherwise

Returns js_undefined() on parse error or if the connection closed before
the request headers were fully received.

Phase C — llhttp-based request parser
Bun reference: bun/src/bun.js/bindings/HTTPRequestContext.zig
"""

import from engine.src.ffi.libc { calloc, free, recv, memcpy }
import from engine.src.ffi.libssl { SSL_read }
import from engine.src.ffi.libllhttp {
    llhttp_alloc_parser,
    llhttp_alloc_settings,
    llhttp_init,
    llhttp_execute,
    llhttp_finish,
    llhttp_set_lenient_headers,
    llhttp_write_data,
    llhttp_read_data,
    llhttp_get_http_major,
    llhttp_get_http_minor,
    llhttp_get_upgrade,
    llhttp_set_callback,
    LLHTTP_HTTP_REQUEST
}
import from engine.src.runtime.mem {
    io_alloc,
    read_byte,
    read_u64,
    write_byte,
    write_i64
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_is_int32,
    jsv_to_int32,
    jsv_from_string_id,
    jsv_from_int32
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_create_null, js_object_set }
import from engine.src.builtins.net_bridge { nb_get_tcp_fd, nb_get_tls_ssl_ptr }

# ── Constants ─────────────────────────────────────────────────────────────────

glob:priv _READ_CHUNK: int = 4096,
     _MAX_BODY_DEFAULT: int = 10485760,
     _HPE_OK: int = 0,
     _HPE_PAUSED: int = 21,
     _HPE_PAUSED_UPGRADE: int = 22,
     _CB_ON_URL: int = 16,
     _CB_ON_METHOD: int = 32,
     _CB_ON_HEADER_FIELD: int = 48,
     _CB_ON_HEADER_VALUE: int = 56,
     _CB_ON_HEADERS_COMPLETE: int = 80,
     _CB_ON_BODY: int = 88,
     _CB_ON_MESSAGE_COMPLETE: int = 96,
     _CB_ON_HEADER_VALUE_COMPLETE: int = 152,
     _STR_URL_BUF: int = 0,
     _STR_URL_LEN: int = 8,
     _STR_MTH_BUF: int = 16,
     _STR_MTH_LEN: int = 24,
     _STR_HF_BUF: int = 32,
     _STR_HF_LEN: int = 40,
     _STR_HV_BUF: int = 48,
     _STR_HV_LEN: int = 56,
     _STR_HDR_BUF: int = 64,
     _STR_HDR_LEN: int = 72,
     _STR_BODY_BUF: int = 80,
     _STR_BODY_LEN: int = 88,
     _STR_BODY_CAP: int = 96,
     _STR_HDR_DONE: int = 104,
     _STR_MSG_DONE: int = 112,
     _STR_IS_ERR: int = 120,
     _STR_UPGRADE: int = 128,
     _STR_SIZE: int = 136,
     _URL_BUF_SIZE: int = 8192,
     _MTH_BUF_SIZE: int = 32,
     _HF_BUF_SIZE: int = 1024,
     _HV_BUF_SIZE: int = 16384,
     _HDR_BUF_SIZE: int = 65536;

# 10 MB

# llhttp error codes

# llhttp_settings_t callback slot offsets (8 bytes each, from libllhttp.na.jac)

# ── State struct byte-offsets (17 slots × 8 bytes = 136 bytes, calloc'd) ──────

# ptr  — URL accumulator
# int  — bytes in url_buf
# ptr  — method accumulator
# int  — bytes in mth_buf
# ptr  — header field name
# int  — bytes in hf_buf
# ptr  — header value
# int  — bytes in hv_buf
# ptr  — accumulated header lines
# int  — bytes in hdr_buf
# ptr  — body accumulator
# int  — bytes in body_buf
# int  — body_buf capacity
# int  — 1 after on_headers_complete fires
# int  — 1 after on_message_complete fires
# int  — non-zero on parse error
# int  — 1 if Upgrade header present
# total size of state struct

# ── Sub-buffer capacities ─────────────────────────────────────────────────────

# max URL length
# max method name (DELETE = 6 chars)
# max header field name length
# max header value length
# max accumulated header lines
# ── Low-level helpers ─────────────────────────────────────────────────────────

import from engine.src.net.net_io { net_raw_recv }

"""Read raw bytes from a socket handle into buf (TCP or TLS).
Returns bytes read, or 0 on error/EOF."""
def _raw_recv_req(handle: int, buf: int, n: int) -> int {
    return net_raw_recv(handle, buf, n);
}

"""Convert raw bytes [buf..buf+n) to a Jac str (NUL-terminated copy)."""
def _bytes_to_str_req(buf: int, n: int) -> str {
    out: int = io_alloc(n + 1);
    if n > 0 {
        memcpy(out, buf, n);
    }
    write_byte(out, n, 0);
    result: str = out;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

# ── llhttp callbacks ──────────────────────────────────────────────────────────

# on_url: accumulate URL bytes (may fire multiple times for long URLs)
def _cbr_on_url(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    url_buf_p: int = read_u64(state, _STR_URL_BUF);
    url_len_n: int = read_u64(state, _STR_URL_LEN);
    avail: int = _URL_BUF_SIZE - url_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(url_buf_p + url_len_n, at, copy_n);
    write_i64(state, _STR_URL_LEN, url_len_n + copy_n);
    return 0;
}

# on_method: accumulate HTTP method bytes ("GET", "POST", etc.)
def _cbr_on_method(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    mth_buf_p: int = read_u64(state, _STR_MTH_BUF);
    mth_len_n: int = read_u64(state, _STR_MTH_LEN);
    avail: int = _MTH_BUF_SIZE - mth_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(mth_buf_p + mth_len_n, at, copy_n);
    write_i64(state, _STR_MTH_LEN, mth_len_n + copy_n);
    return 0;
}

# on_header_field: accumulate header field name bytes
def _cbr_on_hf(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    hf_buf_p: int = read_u64(state, _STR_HF_BUF);
    hf_len_n: int = read_u64(state, _STR_HF_LEN);
    avail: int = _HF_BUF_SIZE - hf_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(hf_buf_p + hf_len_n, at, copy_n);
    write_i64(state, _STR_HF_LEN, hf_len_n + copy_n);
    return 0;
}

# on_header_value: accumulate header value bytes
def _cbr_on_hv(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    hv_buf_p: int = read_u64(state, _STR_HV_BUF);
    hv_len_n: int = read_u64(state, _STR_HV_LEN);
    avail: int = _HV_BUF_SIZE - hv_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(hv_buf_p + hv_len_n, at, copy_n);
    write_i64(state, _STR_HV_LEN, hv_len_n + copy_n);
    return 0;
}

# on_header_value_complete: commit accumulated field:value pair to hdr_buf,
# reset field/value accumulators for the next header.
def _cbr_on_hvc(parser: int) -> int {
    state: int = llhttp_read_data(parser);
    hf_buf_p: int = read_u64(state, _STR_HF_BUF);
    hf_len_n: int = read_u64(state, _STR_HF_LEN);
    hv_buf_p: int = read_u64(state, _STR_HV_BUF);
    hv_len_n: int = read_u64(state, _STR_HV_LEN);
    hdr_buf_p: int = read_u64(state, _STR_HDR_BUF);
    hdr_len_n: int = read_u64(state, _STR_HDR_LEN);

    # Overflow guard: silently drop this header if it won't fit in hdr_buf.
    # "field: value\r\n" needs hf_len_n + 2 + hv_len_n + 2 bytes.
    needed: int = hf_len_n + hv_len_n + 4;
    if hdr_len_n + needed > _HDR_BUF_SIZE {
        write_i64(state, _STR_HF_LEN, 0);
        write_i64(state, _STR_HV_LEN, 0);
        return 0;
    }

    # Append "field: value\r\n" to hdr_buf
    memcpy(hdr_buf_p + hdr_len_n, hf_buf_p, hf_len_n);
    hdr_len_n = hdr_len_n + hf_len_n;
    write_byte(hdr_buf_p, hdr_len_n, 58);  # ':'
    write_byte(hdr_buf_p, hdr_len_n + 1, 32);  # ' '
    hdr_len_n = hdr_len_n + 2;
    memcpy(hdr_buf_p + hdr_len_n, hv_buf_p, hv_len_n);
    hdr_len_n = hdr_len_n + hv_len_n;
    write_byte(hdr_buf_p, hdr_len_n, 13);  # CR
    write_byte(hdr_buf_p, hdr_len_n + 1, 10);  # LF
    hdr_len_n = hdr_len_n + 2;
    write_i64(state, _STR_HDR_LEN, hdr_len_n);

    # Reset field and value accumulators
    write_i64(state, _STR_HF_LEN, 0);
    write_i64(state, _STR_HV_LEN, 0);
    return 0;
}

# on_headers_complete: record HDR_DONE and Upgrade flag
def _cbr_on_hc(parser: int) -> int {
    state: int = llhttp_read_data(parser);
    write_i64(state, _STR_HDR_DONE, 1);
    up: int = llhttp_get_upgrade(parser);
    write_i64(state, _STR_UPGRADE, up);
    return 0;
}

# on_body: append request body bytes up to the allocated capacity
def _cbr_on_body(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    body_buf_p: int = read_u64(state, _STR_BODY_BUF);
    body_len_n: int = read_u64(state, _STR_BODY_LEN);
    body_cap_n: int = read_u64(state, _STR_BODY_CAP);
    avail: int = body_cap_n - body_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(body_buf_p + body_len_n, at, copy_n);
    write_i64(state, _STR_BODY_LEN, body_len_n + copy_n);
    return 0;
}

# on_message_complete: signal that the full HTTP request has been parsed
def _cbr_on_mc(parser: int) -> int {
    state: int = llhttp_read_data(parser);
    write_i64(state, _STR_MSG_DONE, 1);
    return 0;
}

# ── Public native bridge function ─────────────────────────────────────────────

"""__net.readHTTPRequest(handle, maxBodySize) → {method, url, httpVersion, headers, body, upgrade}

Arguments (JSValue list):
  [0] handle:      int — socket handle (positive = TCP, negative = TLS)
  [1] maxBodySize: int — max body bytes to accumulate (default 10 MB)

Returns a JSValue object or js_undefined() on parse error / connection close.

  .method      — "GET", "POST", "PUT", "DELETE", etc.
  .url         — "/path?query" (raw request target from the request line)
  .httpVersion — "1.1" or "1.0"
  .headers     — raw "field: value\\r\\n" lines; JS side converts with
                 _headersStrToHeaders() to a Headers object
  .body        — request body as a string (empty for GET/HEAD)
  .upgrade     — 1 if an Upgrade header is present, 0 otherwise
"""
def:pub read_http_request(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }

    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    if handle == 0 {
        return js_undefined();
    }

    max_body: int = _MAX_BODY_DEFAULT;
    if len(args) >= 2 and jsv_is_int32(args[1]) {
        max_body = jsv_to_int32(args[1]);
    }

    # ── Step 1: Allocate parser, settings, and per-request state ──────────
    parser: int = llhttp_alloc_parser(LLHTTP_HTTP_REQUEST);
    settings: int = llhttp_alloc_settings();
    state: int = calloc(1, _STR_SIZE);

    url_buf_p: int = calloc(1, _URL_BUF_SIZE);
    mth_buf_p: int = calloc(1, _MTH_BUF_SIZE);
    hf_buf_p: int = calloc(1, _HF_BUF_SIZE);
    hv_buf_p: int = calloc(1, _HV_BUF_SIZE);
    hdr_buf_p: int = calloc(1, _HDR_BUF_SIZE);
    body_buf_p: int = calloc(1, max_body + 1);

    write_i64(state, _STR_URL_BUF, url_buf_p);
    write_i64(state, _STR_MTH_BUF, mth_buf_p);
    write_i64(state, _STR_HF_BUF, hf_buf_p);
    write_i64(state, _STR_HV_BUF, hv_buf_p);
    write_i64(state, _STR_HDR_BUF, hdr_buf_p);
    write_i64(state, _STR_BODY_BUF, body_buf_p);
    write_i64(state, _STR_BODY_CAP, max_body);

    # ── Step 2: Wire llhttp callbacks ─────────────────────────────────────
    cb_url: int = _cbr_on_url;
    cb_mth: int = _cbr_on_method;
    cb_hf: int = _cbr_on_hf;
    cb_hv: int = _cbr_on_hv;
    cb_hvc: int = _cbr_on_hvc;
    cb_hc: int = _cbr_on_hc;
    cb_body: int = _cbr_on_body;
    cb_mc: int = _cbr_on_mc;

    llhttp_set_callback(settings, _CB_ON_URL, cb_url);
    llhttp_set_callback(settings, _CB_ON_METHOD, cb_mth);
    llhttp_set_callback(settings, _CB_ON_HEADER_FIELD, cb_hf);
    llhttp_set_callback(settings, _CB_ON_HEADER_VALUE, cb_hv);
    llhttp_set_callback(settings, _CB_ON_HEADER_VALUE_COMPLETE, cb_hvc);
    llhttp_set_callback(settings, _CB_ON_HEADERS_COMPLETE, cb_hc);
    llhttp_set_callback(settings, _CB_ON_BODY, cb_body);
    llhttp_set_callback(settings, _CB_ON_MESSAGE_COMPLETE, cb_mc);

    # ── Step 3: Initialise parser and bind per-request state ──────────────
    llhttp_init(parser, LLHTTP_HTTP_REQUEST, settings);
    llhttp_set_lenient_headers(parser, 1);
    llhttp_write_data(parser, state);

    # ── Step 4: Feed socket data to llhttp ────────────────────────────────
    recv_buf: int = io_alloc(_READ_CHUNK);
    recv_str: str = recv_buf;  # retain so GC keeps the buffer alive  # jac:ignore[E1001] pointer reinterpret
    msg_done: int = 0;
    while msg_done == 0 {
        nr: int = _raw_recv_req(handle, recv_buf, _READ_CHUNK);
        if nr == 0 {
            break;
        }  # EOF or connection close
        rc_ex: int = llhttp_execute(parser, recv_str, nr);
        if rc_ex != _HPE_OK and rc_ex != _HPE_PAUSED and rc_ex != _HPE_PAUSED_UPGRADE {
            write_i64(state, _STR_IS_ERR, rc_ex);
            break;
        }
        msg_done = read_u64(state, _STR_MSG_DONE);
    }
    llhttp_finish(parser);

    # ── Step 5: Extract state values before freeing C heap ────────────────
    url_buf_v: int = read_u64(state, _STR_URL_BUF);
    url_len_v: int = read_u64(state, _STR_URL_LEN);
    mth_buf_v: int = read_u64(state, _STR_MTH_BUF);
    mth_len_v: int = read_u64(state, _STR_MTH_LEN);
    hf_buf_v: int = read_u64(state, _STR_HF_BUF);
    hv_buf_v: int = read_u64(state, _STR_HV_BUF);
    hdr_buf_v: int = read_u64(state, _STR_HDR_BUF);
    hdr_len_v: int = read_u64(state, _STR_HDR_LEN);
    body_buf_v: int = read_u64(state, _STR_BODY_BUF);
    body_len_v: int = read_u64(state, _STR_BODY_LEN);
    upgrade_v: int = read_u64(state, _STR_UPGRADE);
    is_err_v: int = read_u64(state, _STR_IS_ERR);
    hdr_done_v: int = read_u64(state, _STR_HDR_DONE);

    maj: int = llhttp_get_http_major(parser);
    min_v: int = llhttp_get_http_minor(parser);

    # ── Error / incomplete path: free all C allocations and signal failure ─
    # Return js_undefined() so JS can break out of the connection loop.
    if is_err_v != 0 or hdr_done_v == 0 {
        free(url_buf_v);
        free(mth_buf_v);
        free(hf_buf_v);
        free(hv_buf_v);
        free(hdr_buf_v);
        free(body_buf_v);
        free(state);
        free(settings);
        free(parser);
        return js_undefined();
    }

    # ── Step 6: Convert C buffers to Jac strings ──────────────────────────
    url_str: str = _bytes_to_str_req(url_buf_v, url_len_v);
    mth_str: str = _bytes_to_str_req(mth_buf_v, mth_len_v);
    hdr_str: str = _bytes_to_str_req(hdr_buf_v, hdr_len_v);
    body_str: str = _bytes_to_str_req(body_buf_v, body_len_v);

    # ── Step 7: Free all C-heap allocations ───────────────────────────────
    free(url_buf_v);
    free(mth_buf_v);
    free(hf_buf_v);
    free(hv_buf_v);
    free(hdr_buf_v);
    free(body_buf_v);
    free(state);
    free(settings);
    free(parser);

    # ── Step 8: Build HTTP version string ─────────────────────────────────
    httpver_str: str = str(maj) + "." + str(min_v);

    # ── Step 9: Build the result JSValue object ────────────────────────────
    result: JSValue = js_object_create_null();
    js_object_set(
        result, str_intern("method"), jsv_from_string_id(str_intern(mth_str))
    );
    js_object_set(result, str_intern("url"), jsv_from_string_id(str_intern(url_str)));
    js_object_set(
        result, str_intern("httpVersion"), jsv_from_string_id(str_intern(httpver_str))
    );
    js_object_set(
        result, str_intern("headers"), jsv_from_string_id(str_intern(hdr_str))
    );
    js_object_set(result, str_intern("body"), jsv_from_string_id(str_intern(body_str)));
    js_object_set(result, str_intern("upgrade"), jsv_from_int32(upgrade_v));
    return result;
}
