"""WebSocket Bridge — binary-safe WS frame I/O for JavaScript.

Exposes WebSocket handshake, frame sending, and frame receiving to JS
via the globalThis.__ws native object.

Send path:  Build the frame in native code and write it directly to the
            socket with explicit byte count — null bytes in mask keys
            or XOR'd payloads are handled correctly.

Receive:    Per-connection WSRecvBuf accumulates raw bytes from the socket.
            Frames are decoded from the buffer without string conversion.
            Only TEXT payloads (which are null-free) are returned as JS strings.

API exposed to JS via globalThis.__ws:
  __ws.acceptKey(clientKey)       → Sec-WebSocket-Accept string
  __ws.randomKey()                → base64-encoded 16-byte key
  __ws.sendFrame(h, op, payload, mask, isTls) → bytes sent
  __ws.createRecvBuf()            → bufId
  __ws.recvBufRead(h, bufId, isTls) → bytes read
  __ws.recvBufDecode(bufId)       → [op, pStart, pLen, fLen, fin, maskOff]
  __ws.recvBufExtract(bufId, s, l, mo) → text string
  __ws.recvBufConsume(bufId, n)   → undefined
  __ws.recvBufParseClose(bufId, s, l, mo) → [code, reason]
  __ws.makeClosePayload(code, reason) → string
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_true,
    js_false,
    jsv_is_int32,
    jsv_is_bool,
    jsv_is_string_cell,
    jsv_to_int32,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_string_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.builtins.array { js_array_create }
import from engine.src.builtins.net_bridge { nb_get_tcp_fd, nb_get_tls_ssl_ptr }
import from engine.src.ws.frame {
    ws_compute_accept_key,
    ws_base64_encode_16_random,
    ws_send_frame_tcp,
    ws_send_frame_tls,
    ws_make_close_payload,
    WSRecvBuf,
    ws_recv_buf_create,
    ws_recv_buf_read_tcp,
    ws_recv_buf_read_tls,
    ws_recv_buf_decode,
    ws_recv_buf_extract_text,
    ws_recv_buf_consume,
    ws_recv_buf_parse_close
}


# ── Receive buffer table ─────────────────────────────────────────────────────
# Indexed by buffer-id (returned to JS).  Slot 0 is unused.
glob _RECV_BUFS: list[WSRecvBuf] = [];

def _recv_bufs_init {
    _RECV_BUFS.append(ws_recv_buf_create());  # placeholder slot 0
}


# ── Bridge functions ─────────────────────────────────────────────────────────

"""__ws.acceptKey(clientKey) → Sec-WebSocket-Accept string"""
def:pub ws_bridge_accept_key(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    key: str = str_from_id(jsv_to_table_id(args[0]));
    result: str = ws_compute_accept_key(key);
    return jsv_from_string_id(str_intern(result));
}

"""__ws.randomKey() → base64-encoded 16-byte random key"""
def:pub ws_bridge_random_key(args: list[JSValue]) -> JSValue {
    result: str = ws_base64_encode_16_random();
    return jsv_from_string_id(str_intern(result));
}

"""__ws.sendFrame(handle, opcode, payload, doMask, isTls) → bytes sent"""
def:pub ws_bridge_send_frame(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return js_int(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    opcode: int = 1;
    if jsv_is_int32(args[1]) {
        opcode = jsv_to_int32(args[1]);
    }
    payload: str = "";
    if jsv_is_string_cell(args[2]) {
        payload = str_from_id(jsv_to_table_id(args[2]));
    }
    do_mask: bool = False;
    if jsv_is_bool(args[3]) {
        do_mask = jsv_to_bool(args[3]);
    } elif jsv_is_int32(args[3]) {
        do_mask = jsv_to_int32(args[3]) != 0;
    }
    is_tls: bool = False;
    if jsv_is_bool(args[4]) {
        is_tls = jsv_to_bool(args[4]);
    } elif jsv_is_int32(args[4]) {
        is_tls = jsv_to_int32(args[4]) != 0;
    }

    rc: int = 0;
    if is_tls {
        ssl_ptr: int = nb_get_tls_ssl_ptr(handle);
        if ssl_ptr == 0 {
            return js_int(0 - 1);
        }
        rc = ws_send_frame_tls(ssl_ptr, opcode, payload, do_mask);
    } else {
        fd: int = nb_get_tcp_fd(handle);
        if fd == 0 {
            return js_int(0 - 1);
        }
        rc = ws_send_frame_tcp(fd, opcode, payload, do_mask);
    }
    return js_int(rc);
}

"""__ws.createRecvBuf() → buffer id"""
def:pub ws_bridge_recv_buf_create(args: list[JSValue]) -> JSValue {
    if len(_RECV_BUFS) == 0 {
        _recv_bufs_init();
    }
    rb: WSRecvBuf = ws_recv_buf_create();
    _RECV_BUFS.append(rb);
    buf_id: int = len(_RECV_BUFS) - 1;
    return js_int(buf_id);
}

"""__ws.recvBufRead(handle, bufId, isTls) → bytes read"""
def:pub ws_bridge_recv_buf_read(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_int(0 - 1);
    }
    handle: int = 0;
    if jsv_is_int32(args[0]) {
        handle = jsv_to_int32(args[0]);
    }
    buf_id: int = 0;
    if jsv_is_int32(args[1]) {
        buf_id = jsv_to_int32(args[1]);
    }
    is_tls: bool = False;
    if jsv_is_bool(args[2]) {
        is_tls = jsv_to_bool(args[2]);
    } elif jsv_is_int32(args[2]) {
        is_tls = jsv_to_int32(args[2]) != 0;
    }

    if buf_id < 1 or buf_id >= len(_RECV_BUFS) {
        return js_int(0 - 1);
    }
    rb: WSRecvBuf = _RECV_BUFS[buf_id];

    nr: int = 0;
    if is_tls {
        ssl_ptr: int = nb_get_tls_ssl_ptr(handle);
        if ssl_ptr == 0 {
            return js_int(0 - 1);
        }
        nr = ws_recv_buf_read_tls(rb, ssl_ptr);
    } else {
        fd: int = nb_get_tcp_fd(handle);
        if fd == 0 {
            return js_int(0 - 1);
        }
        nr = ws_recv_buf_read_tcp(rb, fd);
    }
    return js_int(nr);
}

"""__ws.recvBufDecode(bufId) → [opcode, pStart, pLen, fLen, fin, maskOff]"""
def:pub ws_bridge_recv_buf_decode(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    buf_id: int = 0;
    if jsv_is_int32(args[0]) {
        buf_id = jsv_to_int32(args[0]);
    }
    if buf_id < 1 or buf_id >= len(_RECV_BUFS) {
        return js_undefined();
    }

    rb: WSRecvBuf = _RECV_BUFS[buf_id];
    result: list[int] = ws_recv_buf_decode(rb);
    els: list[JSValue] = [
        js_int(result[0]),
        js_int(result[1]),
        js_int(result[2]),
        js_int(result[3]),
        js_int(result[4]),
        js_int(result[5])
    ];
    return js_array_create(els);
}

"""__ws.recvBufExtract(bufId, start, len, maskOff) → text string"""
def:pub ws_bridge_recv_buf_extract(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    buf_id: int = 0;
    if jsv_is_int32(args[0]) {
        buf_id = jsv_to_int32(args[0]);
    }
    start: int = 0;
    if jsv_is_int32(args[1]) {
        start = jsv_to_int32(args[1]);
    }
    plen: int = 0;
    if jsv_is_int32(args[2]) {
        plen = jsv_to_int32(args[2]);
    }
    mask_off: int = 0;
    if jsv_is_int32(args[3]) {
        mask_off = jsv_to_int32(args[3]);
    }
    if buf_id < 1 or buf_id >= len(_RECV_BUFS) {
        return js_undefined();
    }

    rb: WSRecvBuf = _RECV_BUFS[buf_id];
    text: str = ws_recv_buf_extract_text(rb, start, plen, mask_off, 0);
    return jsv_from_string_id(str_intern(text));
}

"""__ws.recvBufConsume(bufId, nbytes) → undefined"""
def:pub ws_bridge_recv_buf_consume(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    buf_id: int = 0;
    if jsv_is_int32(args[0]) {
        buf_id = jsv_to_int32(args[0]);
    }
    nbytes: int = 0;
    if jsv_is_int32(args[1]) {
        nbytes = jsv_to_int32(args[1]);
    }
    if buf_id < 1 or buf_id >= len(_RECV_BUFS) {
        return js_undefined();
    }

    rb: WSRecvBuf = _RECV_BUFS[buf_id];
    ws_recv_buf_consume(rb, nbytes);
    return js_undefined();
}

"""__ws.recvBufParseClose(bufId, start, len, maskOff) → [code, reason]"""
def:pub ws_bridge_recv_buf_parse_close(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    buf_id: int = 0;
    if jsv_is_int32(args[0]) {
        buf_id = jsv_to_int32(args[0]);
    }
    start: int = 0;
    if jsv_is_int32(args[1]) {
        start = jsv_to_int32(args[1]);
    }
    plen: int = 0;
    if jsv_is_int32(args[2]) {
        plen = jsv_to_int32(args[2]);
    }
    mask_off: int = 0;
    if jsv_is_int32(args[3]) {
        mask_off = jsv_to_int32(args[3]);
    }
    if buf_id < 1 or buf_id >= len(_RECV_BUFS) {
        return js_undefined();
    }

    rb: WSRecvBuf = _RECV_BUFS[buf_id];
    info: list[int] = ws_recv_buf_parse_close(rb, start, plen, mask_off);
    code: int = info[0];
    # Extract reason text (info[1] = start offset, info[2] = length)
    reason: str = "";
    if info[2] > 0 {
        reason = ws_recv_buf_extract_text(rb, info[1], info[2], mask_off, 2);
    }
    els: list[JSValue] = [js_int(code), jsv_from_string_id(str_intern(reason))];
    return js_array_create(els);
}

"""__ws.makeClosePayload(code, reason) → close payload string (null-safe)"""
def:pub ws_bridge_make_close_payload(args: list[JSValue]) -> JSValue {
    code: int = 1000;
    reason: str = "";
    if len(args) >= 1 and jsv_is_int32(args[0]) {
        code = jsv_to_int32(args[0]);
    }
    if len(args) >= 2 and jsv_is_string_cell(args[1]) {
        reason = str_from_id(jsv_to_table_id(args[1]));
    }
    result: str = ws_make_close_payload(code, reason);
    return jsv_from_string_id(str_intern(result));
}
