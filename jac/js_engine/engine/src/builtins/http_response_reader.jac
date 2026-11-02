"""
Native HTTP/1.1 response reader using llhttp for correct, efficient parsing.

Reads raw bytes from the socket (TCP or TLS) using recv()/SSL_read()
and feeds them to llhttp which fires callbacks to accumulate headers and body.

Exposed to JS as:  __net.readHTTPResponse(handle, maxBodySize, autoDecompress)
Returns JSValue object:  { headers: str, body: str }

- headers: the raw HTTP header block including status line and trailing CRLF CRLF
- body: the decoded (and optionally decompressed) response body text

Phase B — llhttp-based response parser
Bun reference: bun/src/bun.js/webcore/response.zig
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
    llhttp_get_status_code,
    llhttp_set_callback
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
    jsv_from_string_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.jsobject { js_object_create_null, js_object_set }
import from engine.src.builtins.net_bridge { nb_get_tcp_fd, nb_get_tls_ssl_ptr }
import from engine.src.ffi.zlib { zlib_inflate_auto }

# ── Constants ────────────────────────────────────────────────────────────────
glob:priv _MAX_HEADER_SIZE: int = 65536,
     _READ_CHUNK: int = 4096,
     _MAX_BODY_DEFAULT: int = 10485760,
     _CL: list[int] = [
         99,
         111,
         110,
         116,
         101,
         110,
         116,
         45,
         108,
         101,
         110,
         103,
         116,
         104
     ],
     _TE: list[int] = [
         116,
         114,
         97,
         110,
         115,
         102,
         101,
         114,
         45,
         101,
         110,
         99,
         111,
         100,
         105,
         110,
         103
     ],
     _CE: list[int] = [
         99,
         111,
         110,
         116,
         101,
         110,
         116,
         45,
         101,
         110,
         99,
         111,
         100,
         105,
         110,
         103
     ],
     _CHUNKED: list[int] = [99, 104, 117, 110, 107, 101, 100],
     _GZIP: list[int] = [103, 122, 105, 112],
     _DEFLATE: list[int] = [100, 101, 102, 108, 97, 116, 101],
     _LLHTTP_RESPONSE: int = 2,
     _HPE_OK: int = 0,
     _HPE_PAUSED: int = 21,
     _HPE_PAUSED_UPGRADE: int = 22,
     _CB_ON_STATUS: int = 24,
     _CB_ON_HEADER_FIELD: int = 48,
     _CB_ON_HEADER_VALUE: int = 56,
     _CB_ON_HEADERS_COMPLETE: int = 80,
     _CB_ON_BODY: int = 88,
     _CB_ON_MESSAGE_COMPLETE: int = 96,
     _CB_ON_HEADER_VALUE_COMPLETE: int = 152,
     _ST_HF_BUF: int = 0,
     _ST_HF_LEN: int = 8,
     _ST_HV_BUF: int = 16,
     _ST_HV_LEN: int = 24,
     _ST_HDR_BUF: int = 32,
     _ST_HDR_LEN: int = 40,
     _ST_BODY_BUF: int = 48,
     _ST_BODY_LEN: int = 56,
     _ST_BODY_CAP: int = 64,
     _ST_STXT_BUF: int = 72,
     _ST_STXT_LEN: int = 80,
     _ST_STATUS_CD: int = 88,
     _ST_HDR_DONE: int = 96,
     _ST_MSG_DONE: int = 104,
     _ST_HAS_GZIP: int = 112,
     _ST_HAS_DEFL: int = 120,
     _ST_IS_ERR: int = 128,
     _ST_SIZE: int = 136,
     _HF_BUF_SIZE: int = 1024,
     _HV_BUF_SIZE: int = 16384,
     _HDR_BUF_SIZE: int = 65536,
     _STXT_BUF_SIZE: int = 512;

# 10 MB

# Header name patterns (lowercase ASCII byte values)
# "content-length"

# "transfer-encoding"

# "content-encoding"

# "chunked"

# "gzip"

# "deflate"

# ── llhttp parser constants (mirrored locally) ───────────────────────────────

# ── llhttp_settings_t callback slot offsets ───────────────────────────────────

# ── State struct byte-offsets (17 slots × 8 bytes = 136 bytes) ───────────────
# ptr  — header field name buffer
# int  — bytes filled in hf_buf
# ptr  — header value buffer
# int  — bytes filled in hv_buf
# ptr  — accumulated header lines
# int  — bytes in hdr_buf
# ptr  — body accumulator
# int  — bytes in body_buf
# int  — body_buf capacity (= max_body)
# ptr  — status reason-phrase accumulator
# int  — bytes in st_buf
# int  — HTTP status code
# int  — 1 after on_headers_complete fires
# int  — 1 after on_message_complete fires
# int  — 1 if Content-Encoding: gzip
# int  — 1 if Content-Encoding: deflate
# int  — non-zero on parse error
# total size of state struct

# ── State sub-buffer capacities ───────────────────────────────────────────────
# max header field name length
# max header value length
# max accumulated header lines
# max status reason-phrase length
# ── Low-level helpers ────────────────────────────────────────────────────────

import from engine.src.net.net_io { net_raw_recv }

"""Read raw bytes from socket (TCP or TLS) into buf.
Returns bytes read, or 0 on error/EOF."""
def _raw_recv(handle: int, buf: int, n: int) -> int {
    return net_raw_recv(handle, buf, n);
}

"""Find \r\n\r\n (0x0D 0x0A 0x0D 0x0A) in raw bytes.
Returns index of the first \r, or -1 if not found."""
def _find_header_end(buf: int, buf_len: int) -> int {
    i: int = 0;
    limit: int = buf_len - 3;
    while i < limit {
        if read_byte(buf, i) == 13 {
            if read_byte(buf, i + 1) == 10 {
                if read_byte(buf, i + 2) == 13 {
                    if read_byte(buf, i + 3) == 10 {
                        return i;
                    }
                }
            }
        }
        i = i + 1;
    }
    return 0 - 1;
}

"""Convert raw bytes [buf..buf+n) to a Jac str.
Safe only when buf contains no embedded NUL bytes (e.g. HTTP headers,
or already-decompressed text)."""
def _bytes_to_str(buf: int, n: int) -> str {
    out: int = io_alloc(n + 1);
    if n > 0 {
        memcpy(out, buf, n);
    }
    write_byte(out, n, 0);
    result: str = out;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

"""Case-insensitive check: do bytes at buf[pos..pos+plen) match pattern?"""
def _match_ci(buf: int, pos: int, pattern: list[int], plen: int) -> bool {
    i: int = 0;
    while i < plen {
        b: int = read_byte(buf, pos + i);
        if b >= 65 and b <= 90 {
            b = b + 32;
        }
        if b != pattern[i] {
            return False;
        }
        i = i + 1;
    }
    return True;
}

"""Case-insensitive substring search: is pattern in buf[start..end)?"""
def _contains_ci(
    buf: int, start: int, end: int, pattern: list[int], plen: int
) -> bool {
    limit: int = end - plen;
    i: int = start;
    while i <= limit {
        if _match_ci(buf, i, pattern, plen) {
            return True;
        }
        i = i + 1;
    }
    return False;
}

"""Find \r\n starting from pos. Returns index of \r, or -1."""
def _find_crlf(buf: int, pos: int, end: int) -> int {
    limit: int = end - 1;
    while pos < limit {
        if read_byte(buf, pos) == 13 and read_byte(buf, pos + 1) == 10 {
            return pos;
        }
        pos = pos + 1;
    }
    return 0 - 1;
}

# ── llhttp callbacks ─────────────────────────────────────────────────────────

# on_status: accumulate status reason-phrase bytes into state.st_buf
def _cb_on_status(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    st_buf_p: int = read_u64(state, _ST_STXT_BUF);
    st_len_n: int = read_u64(state, _ST_STXT_LEN);
    avail: int = _STXT_BUF_SIZE - st_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(st_buf_p + st_len_n, at, copy_n);
    write_i64(state, _ST_STXT_LEN, st_len_n + copy_n);
    return 0;
}

# on_header_field: accumulate header field name bytes into state.hf_buf
def _cb_on_header_field(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    hf_buf_p: int = read_u64(state, _ST_HF_BUF);
    hf_len_n: int = read_u64(state, _ST_HF_LEN);
    avail: int = _HF_BUF_SIZE - hf_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(hf_buf_p + hf_len_n, at, copy_n);
    write_i64(state, _ST_HF_LEN, hf_len_n + copy_n);
    return 0;
}

# on_header_value: accumulate header value bytes into state.hv_buf
def _cb_on_header_value(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    hv_buf_p: int = read_u64(state, _ST_HV_BUF);
    hv_len_n: int = read_u64(state, _ST_HV_LEN);
    avail: int = _HV_BUF_SIZE - hv_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(hv_buf_p + hv_len_n, at, copy_n);
    write_i64(state, _ST_HV_LEN, hv_len_n + copy_n);
    return 0;
}

# on_header_value_complete: commit accumulated field:value pair to hdr_buf,
# detect Content-Encoding (gzip/deflate), reset field/value accumulators.
def _cb_on_hvc(parser: int) -> int {
    state: int = llhttp_read_data(parser);
    hf_buf_p: int = read_u64(state, _ST_HF_BUF);
    hf_len_n: int = read_u64(state, _ST_HF_LEN);
    hv_buf_p: int = read_u64(state, _ST_HV_BUF);
    hv_len_n: int = read_u64(state, _ST_HV_LEN);
    hdr_buf_p: int = read_u64(state, _ST_HDR_BUF);
    hdr_len_n: int = read_u64(state, _ST_HDR_LEN);

    # Overflow guard: drop header silently if it won't fit in hdr_buf.
    # Each "field: value\r\n" needs hf_len_n + 2 + hv_len_n + 2 bytes.
    needed: int = hf_len_n + hv_len_n + 4;
    if hdr_len_n + needed > _HDR_BUF_SIZE {
        write_i64(state, _ST_HF_LEN, 0);
        write_i64(state, _ST_HV_LEN, 0);
        return 0;
    }

    # Check for Content-Encoding header (16 bytes)
    if hf_len_n == 16 {
        if _match_ci(hf_buf_p, 0, _CE, 16) {
            if _contains_ci(hv_buf_p, 0, hv_len_n, _GZIP, 4) {
                write_i64(state, _ST_HAS_GZIP, 1);
            }
            if _contains_ci(hv_buf_p, 0, hv_len_n, _DEFLATE, 7) {
                write_i64(state, _ST_HAS_DEFL, 1);
            }
        }
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
    write_i64(state, _ST_HDR_LEN, hdr_len_n);

    # Reset field and value accumulators for the next header
    write_i64(state, _ST_HF_LEN, 0);
    write_i64(state, _ST_HV_LEN, 0);
    return 0;
}

# on_headers_complete: record status code, signal that headers are done
def _cb_on_hc(parser: int) -> int {
    state: int = llhttp_read_data(parser);
    sc: int = llhttp_get_status_code(parser);
    write_i64(state, _ST_STATUS_CD, sc);
    write_i64(state, _ST_HDR_DONE, 1);
    return 0;
}

# on_body: append body bytes to state.body_buf up to its capacity
def _cb_on_body(parser: int, at: int, length: int) -> int {
    state: int = llhttp_read_data(parser);
    body_buf_p: int = read_u64(state, _ST_BODY_BUF);
    body_len_n: int = read_u64(state, _ST_BODY_LEN);
    body_cap_n: int = read_u64(state, _ST_BODY_CAP);
    avail: int = body_cap_n - body_len_n;
    if avail <= 0 {
        return 0;
    }
    copy_n: int = length;
    if copy_n > avail {
        copy_n = avail;
    }
    memcpy(body_buf_p + body_len_n, at, copy_n);
    write_i64(state, _ST_BODY_LEN, body_len_n + copy_n);
    return 0;
}

# on_message_complete: signal that the full HTTP message has been received
def _cb_on_mc(parser: int) -> int {
    state: int = llhttp_read_data(parser);
    write_i64(state, _ST_MSG_DONE, 1);
    return 0;
}

# ── Public native bridge function ────────────────────────────────────────────

"""__net.readHTTPResponse(handle, maxBodySize, autoDecompress) → {headers, body}

Arguments (JSValue):
  [0] handle:          int — socket handle (positive TCP, negative TLS)
  [1] maxBodySize:     int — max body bytes (default 10 MB)
  [2] autoDecompress:  int — 1 to auto-decompress gzip/deflate, 0 to leave raw

Returns a JSValue object with:
  .headers — the raw HTTP header block (status line + headers + blank line)
             as a plain string.  JS calls _parseHTTPResponse() on this.
  .body    — the response body (decompressed if applicable) as a string.
"""
def:pub read_http_response(args: list[JSValue]) -> JSValue {
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

    auto_decompress: int = 1;
    if len(args) >= 3 and jsv_is_int32(args[2]) {
        auto_decompress = jsv_to_int32(args[2]);
    }

    # ── Step 1: Allocate parser, settings, and per-request state ─────────
    parser: int = llhttp_alloc_parser(_LLHTTP_RESPONSE);
    settings: int = llhttp_alloc_settings();
    state: int = calloc(1, _ST_SIZE);

    # Allocate state sub-buffers and store their pointers in the state struct
    hf_buf_p: int = calloc(1, _HF_BUF_SIZE);
    hv_buf_p: int = calloc(1, _HV_BUF_SIZE);
    hdr_buf_p: int = calloc(1, _HDR_BUF_SIZE);
    st_buf_p: int = calloc(1, _STXT_BUF_SIZE);
    body_buf_p: int = calloc(1, max_body + 1);
    write_i64(state, _ST_HF_BUF, hf_buf_p);
    write_i64(state, _ST_HV_BUF, hv_buf_p);
    write_i64(state, _ST_HDR_BUF, hdr_buf_p);
    write_i64(state, _ST_STXT_BUF, st_buf_p);
    write_i64(state, _ST_BODY_BUF, body_buf_p);
    write_i64(state, _ST_BODY_CAP, max_body);

    # ── Step 2: Wire llhttp callbacks ─────────────────────────────────────
    cb_status: int = _cb_on_status;
    cb_hf: int = _cb_on_header_field;
    cb_hv: int = _cb_on_header_value;
    cb_hvc: int = _cb_on_hvc;
    cb_hc: int = _cb_on_hc;
    cb_body: int = _cb_on_body;
    cb_mc: int = _cb_on_mc;
    llhttp_set_callback(settings, _CB_ON_STATUS, cb_status);
    llhttp_set_callback(settings, _CB_ON_HEADER_FIELD, cb_hf);
    llhttp_set_callback(settings, _CB_ON_HEADER_VALUE, cb_hv);
    llhttp_set_callback(settings, _CB_ON_HEADER_VALUE_COMPLETE, cb_hvc);
    llhttp_set_callback(settings, _CB_ON_HEADERS_COMPLETE, cb_hc);
    llhttp_set_callback(settings, _CB_ON_BODY, cb_body);
    llhttp_set_callback(settings, _CB_ON_MESSAGE_COMPLETE, cb_mc);

    # ── Step 3: Init parser and bind per-request state ────────────────────
    llhttp_init(parser, _LLHTTP_RESPONSE, settings);
    llhttp_set_lenient_headers(parser, 1);
    llhttp_write_data(parser, state);

    # ── Step 4: Feed socket data to llhttp ────────────────────────────────
    # io_alloc gives a proper Jac-str-compatible buffer (8-byte RC header).
    recv_buf: int = io_alloc(_READ_CHUNK);
    recv_str: str = recv_buf;  # retain once; buffer stays alive for the loop  # jac:ignore[E1001] pointer reinterpret
    msg_done: int = 0;
    while msg_done == 0 {
        nr: int = _raw_recv(handle, recv_buf, _READ_CHUNK);
        if nr == 0 {
            break;
        }
        rc_ex: int = llhttp_execute(parser, recv_str, nr);
        if rc_ex != _HPE_OK and rc_ex != _HPE_PAUSED and rc_ex != _HPE_PAUSED_UPGRADE {
            write_i64(state, _ST_IS_ERR, rc_ex);
            break;
        }
        msg_done = read_u64(state, _ST_MSG_DONE);
    }
    # recv_str released here when function exits, freeing the io_alloc buffer
    llhttp_finish(parser);

    # ── Step 5: Extract state values before freeing C heap ────────────────
    hf_buf_v: int = read_u64(state, _ST_HF_BUF);
    hv_buf_v: int = read_u64(state, _ST_HV_BUF);
    hdr_buf_v: int = read_u64(state, _ST_HDR_BUF);
    hdr_len_v: int = read_u64(state, _ST_HDR_LEN);
    st_buf_v: int = read_u64(state, _ST_STXT_BUF);
    st_len_v: int = read_u64(state, _ST_STXT_LEN);
    body_buf_v: int = read_u64(state, _ST_BODY_BUF);
    body_len_v: int = read_u64(state, _ST_BODY_LEN);
    has_gzip_v: int = read_u64(state, _ST_HAS_GZIP);
    has_defl_v: int = read_u64(state, _ST_HAS_DEFL);
    status_cd_v: int = read_u64(state, _ST_STATUS_CD);
    is_err_v: int = read_u64(state, _ST_IS_ERR);

    # Read HTTP version from the parser struct before freeing it
    maj: int = llhttp_get_http_major(parser);
    min_v: int = llhttp_get_http_minor(parser);

    # ── Error path (§5.7): free everything and signal failure ─────────────
    # JS treats undefined from readHTTPResponse as a network/parse error.
    if is_err_v != 0 {
        free(hf_buf_v);
        free(hv_buf_v);
        free(hdr_buf_v);
        free(st_buf_v);
        free(body_buf_v);
        free(state);
        free(settings);
        free(parser);
        return js_undefined();
    }

    # ── Step 6: Convert C buffers to Jac strings ──────────────────────────
    hdr_content: str = _bytes_to_str(hdr_buf_v, hdr_len_v);
    st_text: str = _bytes_to_str(st_buf_v, st_len_v);
    body_str: str = "";
    if auto_decompress == 1
        and (has_gzip_v == 1 or has_defl_v == 1)
        and body_len_v > 0 {
        body_str = zlib_inflate_auto(body_buf_v, body_len_v);
    } else {
        body_str = _bytes_to_str(body_buf_v, body_len_v);
    }

    # ── Step 7: Free all C-heap allocations ───────────────────────────────
    free(hf_buf_v);
    free(hv_buf_v);
    free(hdr_buf_v);
    free(st_buf_v);
    free(body_buf_v);
    free(state);
    free(settings);
    free(parser);

    # ── Step 8: Build the header string expected by JS ────────────────────
    # Format: "HTTP/X.Y NNN reason\r\nfield: value\r\n...\r\n"
    crlf: str = chr(13) + "\n";
    status_line: str = "HTTP/"
        + str(maj)
        + "."
        + str(min_v)
        + " "
        + str(status_cd_v)
        + " "
        + st_text
        + crlf;
    hdr_str: str = status_line + hdr_content + crlf;

    # ── Step 9: Build result JSValue object ───────────────────────────────
    result: JSValue = js_object_create_null();
    hdr_val: JSValue = jsv_from_string_id(str_intern(hdr_str));
    body_val: JSValue = jsv_from_string_id(str_intern(body_str));
    js_object_set(result, str_intern("headers"), hdr_val);
    js_object_set(result, str_intern("body"), body_val);
    return result;
}
