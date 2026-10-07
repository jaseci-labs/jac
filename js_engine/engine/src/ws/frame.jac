"""RFC 6455 WebSocket Frame Codec.

Binary-safe frame encoding and decoding.  All frame I/O uses raw buffers
with explicit lengths to avoid null-byte truncation in Jac's null-terminated
strings.

Send path:  ws_send_frame_tcp / ws_send_frame_tls build the complete frame
            in a native buffer and write it to the socket with explicit
            byte count — null bytes in mask keys or masked payloads are
            handled correctly.

Receive:    ws_recv_buf_* functions manage a per-connection byte buffer.
            ws_recv_buf_read_tcp / _tls appends raw bytes.
            ws_recv_buf_decode extracts the next frame.
            For TEXT frames the payload is null-free and safe to return
            as a Jac str.

Handshake:  ws_compute_accept_key (SHA-1 + base64)
            ws_base64_encode_16_random (Sec-WebSocket-Key generation)

Bun Zig mapping:
  bun/src/http/websocket.zig — Frame type definitions
  bun/src/http/websocket_client.zig — Client frame handling
"""

import from engine.src.ffi.libcrypto { SHA1, EVP_EncodeBlock, RAND_bytes }
import from engine.src.ffi.libc { calloc, memcpy, send, recv }
import from engine.src.ffi.libssl { SSL_read, SSL_write }
import from engine.src.runtime.mem { io_alloc, read_byte, write_byte }

# ── WebSocket GUID (RFC 6455 §4.2.2) ────────────────────────────────────────
glob WS_GUID: str = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

# ── Opcode constants ─────────────────────────────────────────────────────────
glob:pub WS_OP_CONTINUATION: int = 0,
     WS_OP_TEXT: int = 1,
     WS_OP_BINARY: int = 2,
     WS_OP_CLOSE: int = 8,
     WS_OP_PING: int = 9,
     WS_OP_PONG: int = 10;


# ══════════════════════════════════════════════════════════════════════════════
# Sec-WebSocket-Accept computation
# ══════════════════════════════════════════════════════════════════════════════

"""Compute Sec-WebSocket-Accept from the client's Sec-WebSocket-Key.
RFC 6455 §4.2.2: accept = base64(SHA1(key + GUID))"""
def:pub ws_compute_accept_key(client_key: str) -> str {
    combined: str = client_key + WS_GUID;
    md_buf: int = io_alloc(20);
    combined_ptr: int = combined;  # jac:ignore[E1001] pointer reinterpret
    SHA1(combined_ptr, len(combined), md_buf);
    b64_buf: int = io_alloc(32);
    EVP_EncodeBlock(b64_buf, md_buf, 20);
    result: str = b64_buf;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

"""Generate base64-encoded 16 random bytes (for Sec-WebSocket-Key)."""
def:pub ws_base64_encode_16_random -> str {
    raw: int = io_alloc(16);
    RAND_bytes(raw, 16);
    b64_buf: int = io_alloc(28);
    EVP_EncodeBlock(b64_buf, raw, 16);
    result: str = b64_buf;  # jac:ignore[E1001] pointer reinterpret
    return result;
}


# ══════════════════════════════════════════════════════════════════════════════
# Frame encoding: build in buffer then raw-write to socket
# ══════════════════════════════════════════════════════════════════════════════

"""Build a WebSocket frame in a native buffer.
Returns (buf_ptr, frame_len) as a list of 2 ints."""
def _build_frame(opcode: int, payload: str, do_mask: bool) -> list[int] {
    plen: int = len(payload);

    # Calculate header size
    header_size: int = 2;
    if plen >= 126 and plen < 65536 {
        header_size = 4;
    } elif plen >= 65536 {
        header_size = 10;
    }
    if do_mask {
        header_size = header_size + 4;
    }
    frame_size: int = header_size + plen;
    frame_buf: int = io_alloc(frame_size + 1);

    # Byte 0: FIN (0x80) | opcode
    write_byte(frame_buf, 0, 128 + opcode);

    # Byte 1: MASK bit | payload length
    mask_bit: int = 0;
    if do_mask {
        mask_bit = 128;
    }

    off: int = 2;
    if plen < 126 {
        write_byte(frame_buf, 1, mask_bit + plen);
    } elif plen < 65536 {
        write_byte(frame_buf, 1, mask_bit + 126);
        write_byte(frame_buf, 2, (plen >> 8) & 255);
        write_byte(frame_buf, 3, plen & 255);
        off = 4;
    } else {
        write_byte(frame_buf, 1, mask_bit + 127);
        write_byte(frame_buf, 2, (plen >> 56) & 255);
        write_byte(frame_buf, 3, (plen >> 48) & 255);
        write_byte(frame_buf, 4, (plen >> 40) & 255);
        write_byte(frame_buf, 5, (plen >> 32) & 255);
        write_byte(frame_buf, 6, (plen >> 24) & 255);
        write_byte(frame_buf, 7, (plen >> 16) & 255);
        write_byte(frame_buf, 8, (plen >> 8) & 255);
        write_byte(frame_buf, 9, plen & 255);
        off = 10;
    }

    if do_mask {
        mask_buf: int = io_alloc(4);
        RAND_bytes(mask_buf, 4);
        mk0: int = read_byte(mask_buf, 0);
        mk1: int = read_byte(mask_buf, 1);
        mk2: int = read_byte(mask_buf, 2);
        mk3: int = read_byte(mask_buf, 3);
        write_byte(frame_buf, off, mk0);
        write_byte(frame_buf, off + 1, mk1);
        write_byte(frame_buf, off + 2, mk2);
        write_byte(frame_buf, off + 3, mk3);
        off = off + 4;
        i: int = 0;
        while i < plen {
            b: int = ord(payload[i]);
            m: int = i & 3;
            if m == 0 {
                b = b ^ mk0;
            } elif m == 1 {
                b = b ^ mk1;
            } elif m == 2 {
                b = b ^ mk2;
            } else {
                b = b ^ mk3;
            }
            write_byte(frame_buf, off + i, b);
            i = i + 1;
        }
    } else {
        if plen > 0 {
            payload_ptr: int = payload;  # jac:ignore[E1001] pointer reinterpret
            memcpy(frame_buf + off, payload_ptr, plen);
        }
    }

    return [frame_buf, frame_size];
}

"""Build and send a WebSocket frame over a plain TCP socket.
Uses explicit length in send() to handle null bytes correctly."""
def:pub ws_send_frame_tcp(fd: int, opcode: int, payload: str, do_mask: bool) -> int {
    parts: list[int] = _build_frame(opcode, payload, do_mask);
    buf_ptr: int = parts[0];
    frame_len: int = parts[1];
    # Cast to str for send() — send uses explicit frame_len, not strlen
    buf_str: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    rc: int = send(fd, buf_str, frame_len, 0);
    return rc;
}

"""Build and send a WebSocket frame over a TLS connection.
Uses explicit length in SSL_write() to handle null bytes correctly."""
def:pub ws_send_frame_tls(
    ssl_ptr: int, opcode: int, payload: str, do_mask: bool
) -> int {
    parts: list[int] = _build_frame(opcode, payload, do_mask);
    buf_ptr: int = parts[0];
    frame_len: int = parts[1];
    buf_str: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    rc: int = SSL_write(ssl_ptr, buf_str, frame_len);
    return rc;
}


# ══════════════════════════════════════════════════════════════════════════════
# Receive buffer — binary-safe per-connection byte buffer
# ══════════════════════════════════════════════════════════════════════════════

"""Per-connection receive buffer for raw binary WebSocket data."""
obj:pub WSRecvBuf {
    has ptr: int = 0,
        len: int = 0,
        cap: int = 0;  # raw byte buffer
}

# current bytes in buffer
# buffer capacity
"""Create a receive buffer with initial capacity."""
def:pub ws_recv_buf_create -> WSRecvBuf {
    cap: int = 65536;
    rb = WSRecvBuf(ptr=io_alloc(cap), len=0, cap=cap);
    return rb;
}

"""Read more data from a TCP socket into the receive buffer.
Returns the number of bytes read (0 = EOF, negative = error)."""
def:pub ws_recv_buf_read_tcp(rb: WSRecvBuf, fd: int) -> int {
    space: int = rb.cap - rb.len;
    if space < 4096 {
        # Grow buffer
        new_cap: int = rb.cap * 2;
        new_buf: int = io_alloc(new_cap);
        if rb.len > 0 {
            memcpy(new_buf, rb.ptr, rb.len);
        }
        rb.ptr = new_buf;
        rb.cap = new_cap;
        space = new_cap - rb.len;
    }
    nr: int = recv(fd, rb.ptr + rb.len, space, 0);
    # Treat C error (uint64 wrap of -1) as -1
    if nr > 2147483647 {
        return 0 - 1;
    }
    if nr > 0 {
        rb.len = rb.len + nr;
    }
    return nr;
}

"""Read more data from a TLS connection into the receive buffer."""
def:pub ws_recv_buf_read_tls(rb: WSRecvBuf, ssl_ptr: int) -> int {
    space: int = rb.cap - rb.len;
    if space < 4096 {
        new_cap: int = rb.cap * 2;
        new_buf: int = io_alloc(new_cap);
        if rb.len > 0 {
            memcpy(new_buf, rb.ptr, rb.len);
        }
        rb.ptr = new_buf;
        rb.cap = new_cap;
        space = new_cap - rb.len;
    }
    nr: int = SSL_read(ssl_ptr, rb.ptr + rb.len, space);
    if nr > 2147483647 {
        return 0 - 1;
    }
    if nr > 0 {
        rb.len = rb.len + nr;
    }
    return nr;
}

"""Try to decode the next frame from the receive buffer.
Returns [opcode, payload_start, payload_len, frame_len, fin, mask_off].
If not enough data: [-1, 0, 0, 0, 0, 0].
All offsets are relative to rb.ptr."""
def:pub ws_recv_buf_decode(rb: WSRecvBuf) -> list[int] {
    if rb.len < 2 {
        return [0 - 1, 0, 0, 0, 0, 0];
    }
    b0: int = read_byte(rb.ptr, 0);
    b1: int = read_byte(rb.ptr, 1);

    fin: int = 0;
    if b0 & 128 {
        fin = 1;
    }
    opcode: int = b0 & 15;
    masked: int = 0;
    if b1 & 128 {
        masked = 1;
    }
    plen: int = b1 & 127;

    header_off: int = 2;

    if plen == 126 {
        if rb.len < 4 {
            return [0 - 1, 0, 0, 0, 0, 0];
        }
        plen = read_byte(rb.ptr, 2) * 256 + read_byte(rb.ptr, 3);
        header_off = 4;
    } elif plen == 127 {
        if rb.len < 10 {
            return [0 - 1, 0, 0, 0, 0, 0];
        }
        plen = (
            read_byte(rb.ptr, 2) * 72057594037927936
            + read_byte(rb.ptr, 3) * 281474976710656
            + read_byte(rb.ptr, 4) * 1099511627776
            + read_byte(rb.ptr, 5) * 4294967296
            + read_byte(rb.ptr, 6) * 16777216
            + read_byte(rb.ptr, 7) * 65536
            + read_byte(rb.ptr, 8) * 256
            + read_byte(rb.ptr, 9)
        );
        header_off = 10;
    }

    mask_off: int = 0;
    if masked == 1 {
        mask_off = header_off;
        header_off = header_off + 4;
    }

    payload_start: int = header_off;
    total_frame_len: int = header_off + plen;

    if rb.len < total_frame_len {
        return [0 - 1, 0, 0, 0, 0, 0];
    }

    return [opcode, payload_start, plen, total_frame_len, fin, mask_off];
}

"""Extract text payload from the receive buffer (safe — text has no null bytes).
If mask_off > 0, unmasks the payload.  mask_phase is the byte offset into the
mask cycle (0 for the start of payload, 2 for close-frame reason text)."""
def:pub ws_recv_buf_extract_text(
    rb: WSRecvBuf, payload_start: int, payload_len: int, mask_off: int, mask_phase: int
) -> str {
    if payload_len == 0 {
        return "";
    }

    buf: int = io_alloc(payload_len);

    if mask_off == 0 {
        memcpy(buf, rb.ptr + payload_start, payload_len);
    } else {
        mk0: int = read_byte(rb.ptr, mask_off);
        mk1: int = read_byte(rb.ptr, mask_off + 1);
        mk2: int = read_byte(rb.ptr, mask_off + 2);
        mk3: int = read_byte(rb.ptr, mask_off + 3);
        i: int = 0;
        while i < payload_len {
            b: int = read_byte(rb.ptr, payload_start + i);
            m: int = (mask_phase + i) & 3;
            if m == 0 {
                b = b ^ mk0;
            } elif m == 1 {
                b = b ^ mk1;
            } elif m == 2 {
                b = b ^ mk2;
            } else {
                b = b ^ mk3;
            }
            write_byte(buf, i, b);
            i = i + 1;
        }
    }

    result: str = buf;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

"""Parse close code from the receive buffer.
Returns [code, reason_start, reason_len] — offsets into rb.ptr."""
def:pub ws_recv_buf_parse_close(
    rb: WSRecvBuf, payload_start: int, payload_len: int, mask_off: int
) -> list[int] {
    if payload_len < 2 {
        return [1005, 0, 0];
    }
    # Extract the 2-byte code (handling masking if needed)
    b0: int = read_byte(rb.ptr, payload_start);
    b1: int = read_byte(rb.ptr, payload_start + 1);
    if mask_off > 0 {
        b0 = b0 ^ read_byte(rb.ptr, mask_off);
        b1 = b1 ^ read_byte(rb.ptr, mask_off + 1);
    }
    code: int = b0 * 256 + b1;
    return [code, payload_start + 2, payload_len - 2];
}

"""Consume bytes from the front of the receive buffer."""
def:pub ws_recv_buf_consume(rb: WSRecvBuf, nbytes: int) -> None {
    if nbytes >= rb.len {
        rb.len = 0;
        return;
    }
    remain: int = rb.len - nbytes;
    # Shift remaining bytes to front
    # Use a temporary buffer to avoid overlapping memcpy
    tmp: int = io_alloc(remain);
    memcpy(tmp, rb.ptr + nbytes, remain);
    memcpy(rb.ptr, tmp, remain);
    rb.len = remain;
}


# ══════════════════════════════════════════════════════════════════════════════
# Legacy string-based API (for handshake only — safe when no null bytes)
# ══════════════════════════════════════════════════════════════════════════════

"""Build a close frame payload from code + reason (string-based).
Used for building close frames where code > 255 and the high byte is non-null."""
def:pub ws_make_close_payload(code: int, reason: str) -> str {
    rlen: int = len(reason);
    buf: int = io_alloc(2 + rlen);
    write_byte(buf, 0, (code >> 8) & 255);
    write_byte(buf, 1, code & 255);
    if rlen > 0 {
        reason_ptr: int = reason;  # jac:ignore[E1001] pointer reinterpret
        memcpy(buf + 2, reason_ptr, rlen);
    }
    result: str = buf;  # jac:ignore[E1001] pointer reinterpret
    return result;
}
