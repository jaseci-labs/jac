"""
Network Bridge — exposes TCP/TLS socket operations to JavaScript.

JS code calls native functions (via NATIVE_KIND_NET_*) which manage an opaque
handle table.  Each TCP or TLS socket gets an integer handle ID; JS never sees
the Jac struct directly.

Handle ID semantics:
  - IDs 1..N are valid socket handles
  - 0 means "invalid / failed"
  - Negative IDs indicate TLS sockets (negated index into _TLS_HANDLES)
  - Positive IDs indicate TCP sockets (index into _TCP_HANDLES)

API exposed to JS via globalThis.__net:
  __net.tcpConnect(host, port)     → handle (int > 0) or 0 on error
  __net.tcpRead(handle, maxBytes)  → string ("" on EOF/error)
  __net.tcpWrite(handle, data)     → bytes written (int) or -1 on error
  __net.tcpClose(handle)           → undefined
  __net.tlsConnect(host, port)     → handle (int < 0) or 0 on error
  __net.tlsRead(handle, maxBytes)  → string
  __net.tlsWrite(handle, data)     → bytes written (int) or -1 on error
  __net.tlsClose(handle)           → undefined

Bun Zig mapping: bun/src/bun.js/api/bun/socket.zig (socket handle management)
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_number,
    js_true,
    js_false,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_is_string_cell,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_string_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.net.tcp_socket {
    TCPSocket,
    TCPListener,
    SocketAddress,
    tcp_connect,
    tcp_read,
    tcp_write,
    tcp_write_all,
    tcp_write_bytes,
    tcp_close,
    tcp_listen,
    tcp_accept,
    tcp_listener_close,
    tcp_connect_nb_start,
    tcp_set_nodelay,
    tcp_set_keepalive,
    tcp_get_local_address
}
import from engine.src.net.udp_socket {
    UDPSocket,
    UDPMessage,
    UDPAddress,
    udp_create_family,
    udp_bind_to,
    udp_send,
    udp_send_bytes,
    udp_recv,
    udp_close,
    udp_set_broadcast,
    udp_local_address,
    udp_extract_sender,
    udp_set_buffer_size,
    udp_get_buffer_size,
    udp_set_ttl
}
import from engine.src.net.unix_socket { unix_listen }
import from engine.src.runtime.jsobject { js_object_create_null, js_object_set }
import from engine.src.tls.tls {
    TLSConfig,
    TLSSocket,
    TLSContext,
    tls_connect,
    tls_connect_on_fd,
    tls_client_wrap_fd,
    tls_read,
    tls_read_into,
    tls_write,
    tls_close,
    tls_wrap_fd,
    tls_accept_on_fd,
    tls_accept_on_fd_shared_ctx,
    tls_handshake_nb,
    tls_create_server_context,
    tls_context_free,
    tls_get_alpn_selected,
    tls_ctx_set_alpn_protos,
    tls_ctx_set_alpn_select,
    SSL_ERROR_WANT_READ,
    SSL_ERROR_WANT_WRITE,
    SSL_ERROR_ZERO_RETURN
}
import from engine.src.ffi.libuv {
    UVLoop,
    UVHandle,
    uvpoll_create,
    uvpoll_start,
    uvpoll_stop,
    uvpoll_close,
    uvasync_send,
    uvhandle_ref,
    uvhandle_unref,
    UV_READABLE,
    UV_WRITABLE
}
import from engine.src.ffi.libc {
    recv,
    recvfrom,
    close,
    calloc,
    getsockopt,
    get_errno,
    fcntl,
    getenv
}
import from engine.src.runtime.mem { read_i32, read_u16, write_i32, io_alloc, io_free }
import from engine.src.runtime.gc_pin { gc_pin_live_list }
import from engine.src.net.constants {
    SOL_SOCKET,
    SO_ERROR,
    EAGAIN,
    EWOULDBLOCK,
    F_GETFL,
    F_SETFL,
    O_NONBLOCK,
    AF_INET,
    AF_INET6
}

# ── Handle tables ────────────────────────────────────────────────────────────
# Index 0 is a dummy sentinel (never used).  Valid handles start at 1.
glob _TCP_HANDLES: list[TCPSocket] = [TCPSocket()],
     _TLS_HANDLES: list[TLSSocket] = [TLSSocket()],
     _LISTENER_HANDLES: list[TCPListener] = [TCPListener()],
     _UDP_HANDLES: list[UDPSocket] = [UDPSocket()],
     _TLS_SERVER_CTX: list[TLSContext] = [TLSContext()],
     _NB_TYPE_CONNECT: int = 1,
     _NB_TYPE_READ: int = 2,
     _NB_TYPE_TLS_CONNECT: int = 3,
     _NB_TYPE_TLS_READ: int = 4,
     _NB_TYPE_ACCEPT: int = 5,
     _NB_TYPE_READ_BINARY: int = 6,
     _NB_TYPE_TLS_READ_BINARY: int = 7,
     _NB_TYPE_TLS_ACCEPT: int = 8,
     _NB_TYPE_TLS_WRITE: int = 9,
     _NB_TYPE_UDP_RECV: int = 10,
     _NB_TYPE_UDP_SEND: int = 11,
     _NB_LOOP_PTR: int = 0,
     _NB_ASYNC_PTR: int = 0,
     _NB_POLL_UVPTR: list[int] = [],
     _NB_POLL_FD: list[int] = [],
     _NB_POLL_CB: list[JSValue] = [],
     _NB_POLL_TYPE: list[int] = [],
     _NB_POLL_HANDLE_ID: list[int] = [],
     _NB_POLL_READ_N: list[int] = [],
     _NB_POLL_HOST: list[str] = [],
     _NB_POLL_ALPN: list[str] = [];

# ── TLS server context table (Phase 6.14) ─────────────────────────────────────
# Shared server contexts, one per (cert, key) pair.  Index 0 is dummy.

# ── Non-blocking I/O infrastructure (Phase 6.6) ─────────────────────────────
# Following the same fired-queue pattern as vm/timers.na.jac:
#   1. _NB_LOOP_PTR / _NB_ASYNC_PTR — raw libuv pointers, set by nb_init().
#   2. Active poll table — parallel lists tracking each uv_poll_t in flight.
#   3. Fired callback queue — drained by el_tick via accessor functions.
#   4. C poll callback _nb_poll_cb — pushes results into fired queue.
#
# Poll types:

# Phase 6.12 — binary-safe reads (callback fires (ptr, len, isEOF) instead of (str, isEOF))

# retry WANT_WRITE

# Raw libuv pointers (set once by nb_init, called from el_run)

# Active poll entries (parallel flat lists — compiler workaround)
# uv_poll_t handle_ptr
# file descriptor being polled
# JS callback to fire
# _NB_TYPE_CONNECT or _NB_TYPE_READ
# our handle table ID
# max bytes for read ops
# hostname for TLS connect (SNI)
# ALPN CSV for TLS connect
# Fired callback queue (drained by el_tick)
glob:pub _NB_FIRED_FNS: list[JSValue] = [],
     _NB_FIRED_ARGS: list[list[JSValue]] = [];

glob _NB_ROOTED: bool = False;

"""Register the net-bridge glob callback queues as live GC roots (once).
Glob queues are invisible to the GC root walk. Fired args are primitives or
interned strings (never swept), so only the callback lists need rooting."""
def _nb_root_once -> None {
    if _NB_ROOTED {
        return;
    }
    gc_pin_live_list(_NB_POLL_CB);
    gc_pin_live_list(_NB_FIRED_FNS);
    _NB_ROOTED = True;
}

"""Initialise the non-blocking I/O subsystem with event loop pointers.
Called once from el_run in vm/event_loop.na.jac."""
def:pub nb_init(loop_ptr: int, async_ptr: int) {
    _NB_LOOP_PTR = loop_ptr;
    _NB_ASYNC_PTR = async_ptr;
}

# ── Fired-queue accessors (called by el_tick) ────────────────────────────────

def:pub nb_fired_count -> int {
    return len(_NB_FIRED_FNS);
}

def:pub nb_fired_fn(idx: int) -> JSValue {
    return _NB_FIRED_FNS[idx];
}

def:pub nb_fired_args(idx: int) -> list[JSValue] {
    return _NB_FIRED_ARGS[idx];
}

def:pub nb_fired_clear(n: int) -> None {
    # O(remaining) rebuild — repeated `del [0]` is O(n^2) for a batch of n.
    if n <= 0 {
        return;
    }
    nb_fn_kept: list[JSValue] = [];
    nb_arg_kept: list[list[JSValue]] = [];
    nb_i: int = n;
    nb_len: int = len(_NB_FIRED_FNS);
    while nb_i < nb_len {
        nb_fn_kept.append(_NB_FIRED_FNS[nb_i]);
        nb_arg_kept.append(_NB_FIRED_ARGS[nb_i]);
        nb_i = nb_i + 1;
    }
    # Rebuild IN PLACE — _NB_FIRED_FNS identity is GC-rooted via gc_pin_live_list.
    while len(_NB_FIRED_FNS) > 0 {
        del _NB_FIRED_FNS[len(_NB_FIRED_FNS) - 1];
    }
    nb_k: int = 0;
    while nb_k < len(nb_fn_kept) {
        _NB_FIRED_FNS.append(nb_fn_kept[nb_k]);
        nb_k = nb_k + 1;
    }
    _NB_FIRED_ARGS = nb_arg_kept;
}

# ── Poll entry management ────────────────────────────────────────────────────

def _nb_add_poll(
    uvptr: int,
    fd: int,
    cb: JSValue,
    ptype: int,
    handle_id: int,
    read_n: int,
    host: str,
    alpn: str
) {
    _nb_root_once();
    _NB_POLL_UVPTR.append(uvptr);
    _NB_POLL_FD.append(fd);
    _NB_POLL_CB.append(cb);
    _NB_POLL_TYPE.append(ptype);
    _NB_POLL_HANDLE_ID.append(handle_id);
    _NB_POLL_READ_N.append(read_n);
    _NB_POLL_HOST.append(host);
    _NB_POLL_ALPN.append(alpn);
}

def _nb_remove_poll(idx: int) {
    del _NB_POLL_UVPTR[idx];
    del _NB_POLL_FD[idx];
    del _NB_POLL_CB[idx];
    del _NB_POLL_TYPE[idx];
    del _NB_POLL_HANDLE_ID[idx];
    del _NB_POLL_READ_N[idx];
    del _NB_POLL_HOST[idx];
    del _NB_POLL_ALPN[idx];
}

# ── C poll callback ──────────────────────────────────────────────────────────
# libuv invokes this with: void (*uv_poll_cb)(uv_poll_t *handle, int status, int events)

def _nb_poll_cb(handle_ptr: int, status: int, events: int) -> None {
    # Find the matching poll entry by uv_poll_t pointer
    i: int = 0;
    while i < len(_NB_POLL_UVPTR) {
        if _NB_POLL_UVPTR[i] == handle_ptr {
            cb: JSValue = _NB_POLL_CB[i];
            ptype: int = _NB_POLL_TYPE[i];
            hid: int = _NB_POLL_HANDLE_ID[i];
            fd: int = _NB_POLL_FD[i];
            read_n: int = _NB_POLL_READ_N[i];
            host: str = _NB_POLL_HOST[i];
            alpn_c: str = _NB_POLL_ALPN[i];

            # Stop the poll and remove entry
            ph: UVHandle = UVHandle();
            ph.handle_ptr = handle_ptr;
            uvpoll_stop(ph);
            uvpoll_close(ph);
            _nb_remove_poll(i);

            if ptype == _NB_TYPE_CONNECT {
                _nb_handle_connect_ready(cb, hid, fd, status);
            } elif ptype == _NB_TYPE_READ {
                _nb_handle_read_ready(cb, hid, fd, read_n, status);
            } elif ptype == _NB_TYPE_TLS_CONNECT {
                _nb_handle_tls_connect_ready(cb, hid, fd, host, status, read_n, alpn_c);
            } elif ptype == _NB_TYPE_TLS_READ {
                _nb_handle_tls_read_ready(cb, hid, read_n, status);
            } elif ptype == _NB_TYPE_ACCEPT {
                _nb_handle_accept_ready(cb, fd, status);
            } elif ptype == _NB_TYPE_READ_BINARY {
                _nb_handle_read_binary_ready(cb, hid, fd, read_n, status);
            } elif ptype == _NB_TYPE_TLS_READ_BINARY {
                _nb_handle_tls_read_binary_ready(cb, hid, read_n, status);
            } elif ptype == _NB_TYPE_TLS_ACCEPT {
                _nb_handle_tls_accept_ready(cb, hid, fd, read_n, status);
            } elif ptype == _NB_TYPE_TLS_WRITE {
                _nb_handle_tls_write_ready(cb, hid, host, status);
            } elif ptype == _NB_TYPE_UDP_RECV {
                _nb_handle_udp_recv_ready(cb, hid, fd, read_n, status);
            } elif ptype == _NB_TYPE_UDP_SEND {
                _nb_handle_udp_send_ready(cb, hid, host, read_n, alpn_c, status);
            }

            # Wake the event loop so el_tick drains the fired queue
            _nb_wake();
            return;
        }
        i = i + 1;
    }
}

def _nb_handle_connect_ready(cb: JSValue, hid: int, fd: int, status: int) -> None {
    if status < 0 {
        # libuv reported an error
        close(fd);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(status)]);
        return;
    }
    # Check SO_ERROR to verify connection succeeded
    err_buf: int = calloc(1, 4);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, 4);
    getsockopt(fd, SOL_SOCKET, SO_ERROR, err_buf, len_buf);
    so_err: int = read_i32(err_buf, 0);
    if so_err != 0 {
        close(fd);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(so_err)]);
        return;
    }
    # Connection succeeded — mark the handle as connected
    sock_ref: TCPSocket = _TCP_HANDLES[hid];
    sock_ref.connected = True;
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(hid), js_int(0)]);
}

def _nb_handle_read_ready(
    cb: JSValue, hid: int, fd: int, max_n: int, status: int
) -> None {
    if status < 0 {
        # Poll error → treat as EOF
        _NB_FIRED_FNS.append(cb);
        empty_str: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_ARGS.append([empty_str, js_true()]);
        return;
    }
    # Non-blocking recv
    buf_ptr: int = calloc(1, max_n + 1);
    nr: int = recv(fd, buf_ptr, max_n, 0);
    if nr > 0 {
        raw: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
        chunk: str = raw[0:nr];
        chunk_val: JSValue = jsv_from_string_id(str_intern(chunk));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([chunk_val, js_false()]);
    } elif nr == 0 {
        # EOF
        empty_val: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([empty_val, js_true()]);
    } else {
        # Error (shouldn't happen after poll said readable, but handle it)
        empty_val2: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([empty_val2, js_true()]);
    }
}

# ── Handle allocation ────────────────────────────────────────────────────────

def _alloc_tcp(sock: TCPSocket) -> int {
    _TCP_HANDLES.append(sock);
    return len(_TCP_HANDLES) - 1;
}

def _alloc_tls(sock: TLSSocket) -> int {
    _TLS_HANDLES.append(sock);
    # Return negated index so JS can distinguish TCP (>0) from TLS (<0)
    return 0 - (len(_TLS_HANDLES) - 1);
}

# ── Handle accessors (for ws_bridge cross-module use) ────────────────────────

"""Get the OS file descriptor for a TCP handle (positive int)."""
def:pub nb_get_tcp_fd(h: int) -> int {
    if h < 1 or h >= len(_TCP_HANDLES) {
        return 0;
    }
    return _TCP_HANDLES[h].fd;
}

"""Get the SSL* pointer for a TLS handle (negative int → index)."""
def:pub nb_get_tls_ssl_ptr(h: int) -> int {
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        return 0;
    }
    return _TLS_HANDLES[idx].ssl_ptr;
}

"""Get the OS file descriptor for a TLS handle."""
def:pub nb_get_tls_fd(h: int) -> int {
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        return 0;
    }
    return _TLS_HANDLES[idx].tcp_fd;
}

# ── Integer to string helper ─────────────────────────────────────────────────

def _nb_digit_char(d: int) -> str {
    if d == 0 {
        return "0";
    }
    if d == 1 {
        return "1";
    }
    if d == 2 {
        return "2";
    }
    if d == 3 {
        return "3";
    }
    if d == 4 {
        return "4";
    }
    if d == 5 {
        return "5";
    }
    if d == 6 {
        return "6";
    }
    if d == 7 {
        return "7";
    }
    if d == 8 {
        return "8";
    }
    return "9";
}

def _nb_int_to_str(n: int) -> str {
    if n == 0 {
        return "0";
    }
    result: str = "";
    rem: int = n;
    while rem > 0 {
        d: int = rem - (rem // 10) * 10;
        result = _nb_digit_char(d) + result;
        rem = rem // 10;
    }
    return result;
}

# ── TCP operations ───────────────────────────────────────────────────────────

"""__net.tcpConnect(host, port) → positive handle or 0"""
def:pub net_tcp_connect(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0);
    }
    if not jsv_is_string_cell(args[0]) {
        return js_int(0);
    }
    host: str = str_from_id(jsv_to_table_id(args[0]));
    port: int = 80;
    if jsv_is_int32(args[1]) {
        port = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        port = jsv_to_int32(args[1]);
    }

    sock: TCPSocket = tcp_connect(host, port);
    if not sock.connected {
        return js_int(0);
    }
    h: int = _alloc_tcp(sock);
    return js_int(h);
}

"""__net.tcpRead(handle, maxBytes) → string"""
def:pub net_tcp_read(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return jsv_from_string_id(str_intern(""));
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return jsv_from_string_id(str_intern(""));
    }
    n: int = 4096;
    if jsv_is_int32(args[1]) {
        n = jsv_to_int32(args[1]);
    }
    sock: TCPSocket = _TCP_HANDLES[h];
    data: str = tcp_read(sock, n);
    return jsv_from_string_id(str_intern(data));
}

"""__net.tcpWrite(handle, data) → bytes written (int)"""
def:pub net_tcp_write(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return js_int(0 - 1);
    }
    if not jsv_is_string_cell(args[1]) {
        return js_int(0 - 1);
    }
    data: str = str_from_id(jsv_to_table_id(args[1]));
    sock: TCPSocket = _TCP_HANDLES[h];
    written: int = tcp_write_all(sock, data);
    return js_int(written);
}

"""__net.tcpClose(handle) → undefined

Closes the TCP socket.  Before closing the OS fd we **must** stop and close
every active uv_poll_t handle that watches this socket's fd.  If we skip
this, the poll handle stays reffed inside the libuv loop and uv_run never
returns — causing the process to hang after all JS work is complete.

This mirrors the cleanup already done by net_tcp_listener_close for accept
polls on listener sockets.
"""
def:pub net_tcp_close(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return js_undefined();
    }
    sock: TCPSocket = _TCP_HANDLES[h];

    # Cancel any active polls on this socket's fd (read, connect, …)
    sock_fd: int = sock.fd;
    if sock_fd > 0 {
        pi: int = 0;
        while pi < len(_NB_POLL_FD) {
            if _NB_POLL_FD[pi] == sock_fd {
                eph: UVHandle = UVHandle();
                eph.handle_ptr = _NB_POLL_UVPTR[pi];
                uvpoll_stop(eph);
                uvpoll_close(eph);
                _nb_remove_poll(pi);
                # Don't increment pi — removal shifted elements down
            } else {
                pi = pi + 1;
            }
        }
    }

    tcp_close(sock);
    return js_undefined();
}

# ── TLS operations ───────────────────────────────────────────────────────────

"""__net.tlsConnect(host, port) → negative handle or 0"""
def:pub net_tls_connect(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0);
    }
    if not jsv_is_string_cell(args[0]) {
        return js_int(0);
    }
    host: str = str_from_id(jsv_to_table_id(args[0]));
    port: int = 443;
    if jsv_is_int32(args[1]) {
        port = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        port = jsv_to_int32(args[1]);
    }

    cfg: TLSConfig = TLSConfig(
        verify_peer=True, ca_certs="", cert_file="", key_file="", server_name=host
    );
    # Phase 6.14A: NODE_EXTRA_CA_CERTS — path to a PEM bundle added to trusted roots
    extra_ca: str = getenv("NODE_EXTRA_CA_CERTS");
    if extra_ca {
        cfg.ca_certs = extra_ca;
    }
    sock: TLSSocket = tls_connect(host, port, cfg);
    if not sock.handshake_done {
        return js_int(0);
    }
    h: int = _alloc_tls(sock);
    return js_int(h);
}

"""__net.tlsRead(handle, maxBytes) → string"""
def:pub net_tls_read(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return jsv_from_string_id(str_intern(""));
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    # TLS handles are negative — convert to positive index
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        return jsv_from_string_id(str_intern(""));
    }
    n: int = 4096;
    if jsv_is_int32(args[1]) {
        n = jsv_to_int32(args[1]);
    }
    sock: TLSSocket = _TLS_HANDLES[idx];
    data: str = tls_read(sock, n);
    return jsv_from_string_id(str_intern(data));
}

"""Retry handler for SSL_ERROR_WANT_WRITE.
Called when the fd becomes writable after a WANT_WRITE was returned.
data (stored in _NB_POLL_HOST) is the remaining payload to send.
Callback is invoked as callback(bytesWritten, errCode)."""
def _nb_handle_tls_write_ready(cb: JSValue, hid: int, data: str, status: int) -> None {
    if status < 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0 - 1), js_int(status)]);
        return;
    }
    idx: int = 0 - hid;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0 - 1), js_int(0 - 1)]);
        return;
    }
    sock: TLSSocket = _TLS_HANDLES[idx];
    written: int = tls_write(sock, data);
    if written >= 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(written), js_int(0)]);
        return;
    }
    err: int = sock.last_error;
    if err == SSL_ERROR_WANT_WRITE {
        # Still not writable — re-arm the poll
        fd: int = sock.tcp_fd;
        lp: UVLoop = UVLoop();
        lp.loop_ptr = _NB_LOOP_PTR;
        ph: UVHandle = uvpoll_create(lp, fd);
        uvpoll_start(ph, UV_WRITABLE, _nb_poll_cb);
        _nb_add_poll(ph.handle_ptr, fd, cb, _NB_TYPE_TLS_WRITE, hid, 0, data, "");
        return;
    }
    # Fatal error
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(0 - 1), js_int(err)]);
}

"""__net.tlsWrite(handle, data) → bytes written (int)"""
def:pub net_tls_write(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        return js_int(0 - 1);
    }
    if not jsv_is_string_cell(args[1]) {
        return js_int(0 - 1);
    }
    data: str = str_from_id(jsv_to_table_id(args[1]));
    sock: TLSSocket = _TLS_HANDLES[idx];
    written: int = tls_write(sock, data);
    return js_int(written);
}

"""__net.tlsWriteNb(handle, data, callback) → undefined
Non-blocking TLS write.  Tries SSL_write immediately; if SSL_ERROR_WANT_WRITE
is returned the pending payload is stored and a UV_WRITABLE poll is armed.
Callback is invoked as callback(bytesWritten, errCode) once the write
completes (errCode 0) or fails (errCode < 0)."""
def:pub net_tls_write_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    idx: int = 0 - h;
    cb: JSValue = args[2];
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0 - 1), js_int(0 - 1)]);
        _nb_wake();
        return js_undefined();
    }
    if not jsv_is_string_cell(args[1]) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0 - 1), js_int(0 - 1)]);
        _nb_wake();
        return js_undefined();
    }
    data: str = str_from_id(jsv_to_table_id(args[1]));
    sock: TLSSocket = _TLS_HANDLES[idx];
    written: int = tls_write(sock, data);
    if written >= 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(written), js_int(0)]);
        _nb_wake();
        return js_undefined();
    }
    err: int = sock.last_error;
    if err == SSL_ERROR_WANT_WRITE {
        # Poll fd for writability and retry with the full payload
        fd: int = sock.tcp_fd;
        lp: UVLoop = UVLoop();
        lp.loop_ptr = _NB_LOOP_PTR;
        ph: UVHandle = uvpoll_create(lp, fd);
        uvpoll_start(ph, UV_WRITABLE, _nb_poll_cb);
        _nb_add_poll(ph.handle_ptr, fd, cb, _NB_TYPE_TLS_WRITE, h, 0, data, "");
        return js_undefined();
    }
    # Fatal error
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(0 - 1), js_int(err)]);
    _nb_wake();
    return js_undefined();
}

"""__net.tlsClose(handle) → undefined

Like net_tcp_close, we must stop and close every active uv_poll_t on the
underlying TCP fd before closing the TLS connection, to prevent poll handles
from keeping the event loop alive.
"""
def:pub net_tls_close(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        return js_undefined();
    }
    sock: TLSSocket = _TLS_HANDLES[idx];

    # Cancel any active polls on the underlying TCP fd
    sock_fd: int = sock.tcp_fd;
    if sock_fd > 0 {
        pi: int = 0;
        while pi < len(_NB_POLL_FD) {
            if _NB_POLL_FD[pi] == sock_fd {
                eph: UVHandle = UVHandle();
                eph.handle_ptr = _NB_POLL_UVPTR[pi];
                uvpoll_stop(eph);
                uvpoll_close(eph);
                _nb_remove_poll(pi);
            } else {
                pi = pi + 1;
            }
        }
    }

    tls_close(sock);
    return js_undefined();
}

# ── Server operations (Phase 6.5) ───────────────────────────────────────────

def _alloc_listener(listener: TCPListener) -> int {
    _LISTENER_HANDLES.append(listener);
    return len(_LISTENER_HANDLES) - 1;
}

"""__net.tcpListen(host, port, backlog) → listener handle (int > 0) or 0"""
def:pub net_tcp_listen(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0);
    }
    if not jsv_is_string_cell(args[0]) {
        return js_int(0);
    }
    host: str = str_from_id(jsv_to_table_id(args[0]));
    port: int = 0;
    if jsv_is_int32(args[1]) {
        port = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        port = jsv_to_int32(args[1]);
    }
    backlog: int = 128;
    if len(args) >= 3 {
        if jsv_is_int32(args[2]) {
            backlog = jsv_to_int32(args[2]);
        }
    }

    listener: TCPListener = tcp_listen(host, port, backlog);
    if not listener.listening {
        return js_int(0);
    }
    h: int = _alloc_listener(listener);
    return js_int(h);
}

"""__net.unixListen(path, backlog) → listener handle (int > 0) or 0.
Creates an AF_UNIX listening socket so the path exists as S_IFSOCK."""
def:pub net_unix_listen(args: list[JSValue]) -> JSValue {
    if len(args) < 1 or not jsv_is_string_cell(args[0]) {
        return js_int(0);
    }
    path: str = str_from_id(jsv_to_table_id(args[0]));
    backlog: int = 128;
    if len(args) >= 2 {
        if jsv_is_int32(args[1]) {
            backlog = jsv_to_int32(args[1]);
        } elif jsv_is_double(args[1]) {
            backlog = jsv_to_int32(args[1]);
        }
    }
    listener: TCPListener = unix_listen(path, backlog);
    if not listener.listening {
        return js_int(0);
    }
    h: int = _alloc_listener(listener);
    return js_int(h);
}

"""__net.tcpAccept(listenerHandle) → client socket handle (int > 0) or 0"""
def:pub net_tcp_accept(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_LISTENER_HANDLES) {
        return js_int(0);
    }
    listener: TCPListener = _LISTENER_HANDLES[h];
    sock: TCPSocket = tcp_accept(listener);
    if not sock.connected {
        return js_int(0);
    }
    ch: int = _alloc_tcp(sock);
    return js_int(ch);
}

"""__net.tcpListenerClose(listenerHandle) → undefined"""
def:pub net_tcp_listener_close(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_LISTENER_HANDLES) {
        return js_undefined();
    }
    listener: TCPListener = _LISTENER_HANDLES[h];

    # Cancel any active accept polls on this listener fd
    pi: int = 0;
    while pi < len(_NB_POLL_FD) {
        if _NB_POLL_FD[pi] == listener.fd and _NB_POLL_TYPE[pi] == _NB_TYPE_ACCEPT {
            eph: UVHandle = UVHandle();
            eph.handle_ptr = _NB_POLL_UVPTR[pi];
            uvpoll_stop(eph);
            uvpoll_close(eph);
            _nb_remove_poll(pi);
            break;
        }
        pi = pi + 1;
    }

    tcp_listener_close(listener);
    return js_undefined();
}

"""__net.tcpPeerAddr(handle) → "ip:port" string or "" on error"""
def:pub net_tcp_peer_addr(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_string_id(str_intern(""));
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return jsv_from_string_id(str_intern(""));
    }
    sock: TCPSocket = _TCP_HANDLES[h];
    addr_str: str = sock.peer_addr.host + ":" + _nb_int_to_str(sock.peer_addr.port);
    return jsv_from_string_id(str_intern(addr_str));
}

"""__net.tcpListenerPort(listenerHandle) → bound port (int) or 0"""
def:pub net_tcp_listener_port(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_LISTENER_HANDLES) {
        return js_int(0);
    }
    listener: TCPListener = _LISTENER_HANDLES[h];
    return js_int(listener.address.port);
}

# ── Non-blocking TCP operations (Phase 6.6) ─────────────────────────────────

"""__net.tcpConnectNb(host, port, callback) → undefined
Starts a non-blocking TCP connect.  The callback is invoked as
callback(handle, errCode) when the connection completes (or fails).
handle > 0 on success, 0 on error."""
def:pub net_tcp_connect_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    host: str = str_from_id(jsv_to_table_id(args[0]));
    port: int = 80;
    if jsv_is_int32(args[1]) {
        port = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        port = jsv_to_int32(args[1]);
    }
    cb: JSValue = args[2];

    sock: TCPSocket = tcp_connect_nb_start(host, port);

    if sock.fd == 0 {
        # Connect error — fire callback immediately (on next el_tick)
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(sock.last_error)]);
        _nb_wake();
        return js_undefined();
    }

    hid: int = _alloc_tcp(sock);

    if sock.connected {
        # Immediate connection (very rare for non-blocking) — fire callback
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(hid), js_int(0)]);
        _nb_wake();
        return js_undefined();
    }

    # EINPROGRESS — poll for writability to detect connect completion
    lp: UVLoop = UVLoop();
    lp.loop_ptr = _NB_LOOP_PTR;
    ph: UVHandle = uvpoll_create(lp, sock.fd);
    uvpoll_start(ph, UV_WRITABLE, _nb_poll_cb);
    _nb_add_poll(ph.handle_ptr, sock.fd, cb, _NB_TYPE_CONNECT, hid, 0, "", "");
    return js_undefined();
}

"""__net.tcpReadNb(handle, maxBytes, callback) → undefined
Starts a non-blocking read.  The callback is invoked as
callback(chunk, isEOF) when data is available or the socket is closed.
chunk is a string; isEOF is true/false."""
def:pub net_tcp_read_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        # Invalid handle — fire callback with EOF immediately
        empty_v: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(args[2]);
        _NB_FIRED_ARGS.append([empty_v, js_true()]);
        _nb_wake();
        return js_undefined();
    }
    max_n: int = 4096;
    if jsv_is_int32(args[1]) {
        max_n = jsv_to_int32(args[1]);
    }
    cb: JSValue = args[2];
    sock: TCPSocket = _TCP_HANDLES[h];
    fd: int = sock.fd;

    # Try non-blocking recv immediately — data may already be buffered
    buf_ptr: int = calloc(1, max_n + 1);
    nr: int = recv(fd, buf_ptr, max_n, 0);
    if nr > 0 {
        # Data available — fire callback immediately (on next el_tick)
        raw: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
        chunk: str = raw[0:nr];
        chunk_val: JSValue = jsv_from_string_id(str_intern(chunk));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([chunk_val, js_false()]);
        _nb_wake();
        return js_undefined();
    }
    if nr == 0 {
        # EOF
        eof_val: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([eof_val, js_true()]);
        _nb_wake();
        return js_undefined();
    }
    # EAGAIN / EWOULDBLOCK — no data yet, poll for readability
    lp: UVLoop = UVLoop();
    lp.loop_ptr = _NB_LOOP_PTR;
    ph: UVHandle = uvpoll_create(lp, fd);
    uvpoll_start(ph, UV_READABLE, _nb_poll_cb);
    _nb_add_poll(ph.handle_ptr, fd, cb, _NB_TYPE_READ, h, max_n, "", "");
    return js_undefined();
}

# ── Non-blocking TLS operations (Phase 6.6 — async HTTPS) ───────────────────

"""Handle TLS connect readiness: the TCP fd is writable (connected).
Wrap with SSL, attempt non-blocking handshake, poll if WANT_READ/WRITE."""
def _nb_handle_tls_connect_ready(
    cb: JSValue,
    tcp_hid: int,
    fd: int,
    host: str,
    status: int,
    verify: int,
    alpn_csv: str
) -> None {
    if status < 0 {
        close(fd);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(status)]);
        return;
    }
    # Check SO_ERROR
    err_buf: int = calloc(1, 4);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, 4);
    getsockopt(fd, SOL_SOCKET, SO_ERROR, err_buf, len_buf);
    so_err: int = read_i32(err_buf, 0);
    if so_err != 0 {
        close(fd);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(so_err)]);
        return;
    }
    # Mark TCP handle as connected (fd is alive)
    tcp_ref: TCPSocket = _TCP_HANDLES[tcp_hid];
    tcp_ref.connected = True;

    # fd is already non-blocking from tcp_connect_nb_start — keep it that way
    # Create SSL object with client context (no handshake)
    v_bool: bool = True;
    if verify == 0 {
        v_bool = False;
    }
    tls_sock: TLSSocket = tls_client_wrap_fd(fd, host, v_bool, alpn_csv);
    if tls_sock.ssl_ptr == 0 {
        close(fd);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(tls_sock.last_error)]);
        return;
    }

    # Attempt non-blocking TLS handshake
    hs_err: int = tls_handshake_nb(tls_sock);

    if hs_err == 0 {
        # Handshake completed immediately
        tls_hid: int = _alloc_tls(tls_sock);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(tls_hid), js_int(0)]);
        return;
    }

    if hs_err == SSL_ERROR_WANT_READ or hs_err == SSL_ERROR_WANT_WRITE {
        # Handshake needs more data — allocate TLS handle and poll
        tls_hid2: int = _alloc_tls(tls_sock);
        ev: int = UV_READABLE;
        if hs_err == SSL_ERROR_WANT_WRITE {
            ev = UV_WRITABLE;
        }

        lp: UVLoop = UVLoop();
        lp.loop_ptr = _NB_LOOP_PTR;
        ph: UVHandle = uvpoll_create(lp, fd);
        uvpoll_start(ph, ev, _nb_poll_cb);
        # Reuse _NB_TYPE_TLS_ACCEPT — handler retries tls_handshake_nb which
        # calls SSL_connect or SSL_accept based on is_server flag
        _nb_add_poll(
            ph.handle_ptr, fd, cb, _NB_TYPE_TLS_ACCEPT, tls_hid2, tcp_hid, "", ""
        );
        return;
    }

    # Fatal error
    tls_close(tls_sock);
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(0), js_int(hs_err)]);
}

"""Handle TLS read readiness: the fd is readable, retry SSL_read."""
def _nb_handle_tls_read_ready(cb: JSValue, hid: int, max_n: int, status: int) -> None {
    if status < 0 {
        empty_val: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([empty_val, js_true()]);
        return;
    }
    # hid is negative (TLS handle) — convert to index
    idx: int = 0 - hid;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        empty_v2: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([empty_v2, js_true()]);
        return;
    }
    sock: TLSSocket = _TLS_HANDLES[idx];
    data: str = tls_read(sock, max_n);
    if len(data) > 0 {
        chunk_val: JSValue = jsv_from_string_id(str_intern(data));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([chunk_val, js_false()]);
    } else {
        # EOF or error
        eof_val: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([eof_val, js_true()]);
    }
}

"""__net.tlsConnectNb(host, port, callback) → undefined
Starts a non-blocking TLS connect.  The callback is invoked as
callback(handle, errCode) when the TLS handshake completes (or fails).
handle < 0 on success (TLS handle), 0 on error."""
def:pub net_tls_connect_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    if not jsv_is_string_cell(args[0]) {
        return js_undefined();
    }
    host: str = str_from_id(jsv_to_table_id(args[0]));
    port: int = 443;
    if jsv_is_int32(args[1]) {
        port = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        port = jsv_to_int32(args[1]);
    }
    cb: JSValue = args[2];

    # Optional 4th arg: rejectUnauthorized (default 1 = true)
    verify: int = 1;
    if len(args) >= 4 {
        if jsv_is_bool(args[3]) {
            if not jsv_to_bool(args[3]) {
                verify = 0;
            }
        } elif jsv_is_int32(args[3]) {
            verify = jsv_to_int32(args[3]);
        }
    }

    # Optional 5th arg: ALPN protocols (comma-separated string)
    alpn: str = "";
    if len(args) >= 5 {
        if jsv_is_string_cell(args[4]) {
            alpn = str_from_id(jsv_to_table_id(args[4]));
        }
    }

    # Non-blocking TCP connect (same as net_tcp_connect_nb)
    sock: TCPSocket = tcp_connect_nb_start(host, port);

    if sock.fd == 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(sock.last_error)]);
        _nb_wake();
        return js_undefined();
    }

    tcp_hid: int = _alloc_tcp(sock);

    if sock.connected {
        # Immediate TCP connect — attempt non-blocking TLS handshake
        v_bool2: bool = True;
        if verify == 0 {
            v_bool2 = False;
        }
        tls_sock: TLSSocket = tls_client_wrap_fd(sock.fd, host, v_bool2, alpn);
        if tls_sock.ssl_ptr == 0 {
            close(sock.fd);
            _NB_FIRED_FNS.append(cb);
            _NB_FIRED_ARGS.append([js_int(0), js_int(tls_sock.last_error)]);
            _nb_wake();
            return js_undefined();
        }

        hs_err: int = tls_handshake_nb(tls_sock);
        if hs_err == 0 {
            tls_hid: int = _alloc_tls(tls_sock);
            _NB_FIRED_FNS.append(cb);
            _NB_FIRED_ARGS.append([js_int(tls_hid), js_int(0)]);
            _nb_wake();
            return js_undefined();
        }

        if hs_err == SSL_ERROR_WANT_READ or hs_err == SSL_ERROR_WANT_WRITE {
            tls_hid2: int = _alloc_tls(tls_sock);
            ev2: int = UV_READABLE;
            if hs_err == SSL_ERROR_WANT_WRITE {
                ev2 = UV_WRITABLE;
            }
            lp2: UVLoop = UVLoop();
            lp2.loop_ptr = _NB_LOOP_PTR;
            ph2: UVHandle = uvpoll_create(lp2, sock.fd);
            uvpoll_start(ph2, ev2, _nb_poll_cb);
            _nb_add_poll(
                ph2.handle_ptr,
                sock.fd,
                cb,
                _NB_TYPE_TLS_ACCEPT,
                tls_hid2,
                tcp_hid,
                "",
                ""
            );
            return js_undefined();
        }

        # Fatal
        tls_close(tls_sock);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(hs_err)]);
        _nb_wake();
        return js_undefined();
    }

    # EINPROGRESS — poll for writability, then do TLS handshake in callback
    lp: UVLoop = UVLoop();
    lp.loop_ptr = _NB_LOOP_PTR;
    ph: UVHandle = uvpoll_create(lp, sock.fd);
    uvpoll_start(ph, UV_WRITABLE, _nb_poll_cb);
    _nb_add_poll(
        ph.handle_ptr, sock.fd, cb, _NB_TYPE_TLS_CONNECT, tcp_hid, verify, host, alpn
    );
    return js_undefined();
}

"""__net.tlsWrapClientNb(tcpHandle, host, rejectUnauthorized, callback) → undefined

Wrap an already-connected TCP handle (e.g. after HTTP CONNECT) with TLS and
complete the client handshake.  callback(tlsHandle, errCode) — tlsHandle < 0
on success, 0 on error."""
def:pub net_tls_wrap_client_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_undefined();
    }
    tcp_h: int = 0;
    if jsv_is_int32(args[0]) {
        tcp_h = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        tcp_h = jsv_to_int32(args[0]);
    }
    if tcp_h < 1 or tcp_h >= len(_TCP_HANDLES) {
        return js_undefined();
    }
    if not jsv_is_string_cell(args[1]) {
        return js_undefined();
    }
    host: str = str_from_id(jsv_to_table_id(args[1]));
    verify: int = 1;
    if len(args) >= 3 {
        if jsv_is_bool(args[2]) {
            if not jsv_to_bool(args[2]) {
                verify = 0;
            }
        } elif jsv_is_int32(args[2]) {
            verify = jsv_to_int32(args[2]);
        }
    }
    cb: JSValue = args[3];
    fd: int = _TCP_HANDLES[tcp_h].fd;
    if fd == 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
        _nb_wake();
        return js_undefined();
    }
    _nb_handle_tls_connect_ready(cb, tcp_h, fd, host, 0, verify, "");
    return js_undefined();
}

"""__net.tlsReadNb(handle, maxBytes, callback) → undefined
Starts a non-blocking TLS read.  The callback is invoked as
callback(chunk, isEOF) when data is available or the socket is closed."""
def:pub net_tls_read_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    # TLS handles are negative
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        empty_v: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(args[2]);
        _NB_FIRED_ARGS.append([empty_v, js_true()]);
        _nb_wake();
        return js_undefined();
    }
    max_n: int = 4096;
    if jsv_is_int32(args[1]) {
        max_n = jsv_to_int32(args[1]);
    }
    cb: JSValue = args[2];
    sock: TLSSocket = _TLS_HANDLES[idx];

    # Try SSL_read immediately — data may already be buffered in OpenSSL
    data: str = tls_read(sock, max_n);
    if len(data) > 0 {
        chunk_val: JSValue = jsv_from_string_id(str_intern(data));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([chunk_val, js_false()]);
        _nb_wake();
        return js_undefined();
    }
    # Check if it's a clean EOF vs WANT_READ
    err_code: int = sock.last_error;
    if err_code == SSL_ERROR_ZERO_RETURN {
        eof_val: JSValue = jsv_from_string_id(str_intern(""));
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([eof_val, js_true()]);
        _nb_wake();
        return js_undefined();
    }
    # SSL_ERROR_WANT_READ or other — poll for readability and retry
    fd: int = sock.tcp_fd;
    lp: UVLoop = UVLoop();
    lp.loop_ptr = _NB_LOOP_PTR;
    ph: UVHandle = uvpoll_create(lp, fd);
    uvpoll_start(ph, UV_READABLE, _nb_poll_cb);
    _nb_add_poll(ph.handle_ptr, fd, cb, _NB_TYPE_TLS_READ, h, max_n, "", "");
    return js_undefined();
}

# ── Phase 6.12 — binary-safe non-blocking reads ──────────────────────────────
# These variants fire callback(ptr, len, isEOF) where ptr is a raw C heap
# pointer (calloc-allocated) containing the received bytes, and len is the
# actual byte count.  JS feeds ptr+len directly to __zlib.feed and then
# calls __buf.free(ptr) to release the buffer.

"""Handle raw TCP read readiness: recv into a calloc buffer, fire (ptr, len, isEOF)."""
def _nb_handle_read_binary_ready(
    cb: JSValue, hid: int, fd: int, max_n: int, status: int
) -> None {
    if status < 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
        return;
    }
    # io_alloc (not calloc): the pointer crosses into JS, which releases it
    # with __buf.free() — that expects io_alloc's 8-byte header.
    buf_ptr: int = io_alloc(max_n + 1);
    nr: int = recv(fd, buf_ptr, max_n, 0);
    if nr > 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_number(float(buf_ptr)), js_int(nr), js_false()]);
    } elif nr == 0 {
        io_free(buf_ptr);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
    } else {
        io_free(buf_ptr);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
    }
}

"""__net.tcpReadBinaryNb(handle, maxBytes, callback) → undefined
Binary-safe non-blocking TCP read.  The callback fires as
callback(ptr, len, isEOF) where ptr is a raw C heap pointer to the received
bytes (calloc-allocated) and len is the byte count.  Caller must call
__buf.free(ptr) after consuming it."""
def:pub net_tcp_read_binary_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        _NB_FIRED_FNS.append(args[2]);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
        _nb_wake();
        return js_undefined();
    }
    max_n: int = 4096;
    if jsv_is_int32(args[1]) {
        max_n = jsv_to_int32(args[1]);
    }
    cb: JSValue = args[2];
    sock: TCPSocket = _TCP_HANDLES[h];
    fd: int = sock.fd;

    buf_ptr: int = io_alloc(max_n + 1);
    nr: int = recv(fd, buf_ptr, max_n, 0);
    if nr > 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_number(float(buf_ptr)), js_int(nr), js_false()]);
        _nb_wake();
        return js_undefined();
    }
    io_free(buf_ptr);
    if nr == 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
        _nb_wake();
        return js_undefined();
    }
    # EAGAIN — poll and retry
    lp2: UVLoop = UVLoop();
    lp2.loop_ptr = _NB_LOOP_PTR;
    ph2: UVHandle = uvpoll_create(lp2, fd);
    uvpoll_start(ph2, UV_READABLE, _nb_poll_cb);
    _nb_add_poll(ph2.handle_ptr, fd, cb, _NB_TYPE_READ_BINARY, h, max_n, "", "");
    return js_undefined();
}

"""Handle TLS read readiness — binary variant: reads into a calloc buffer,
fires callback(ptr, len, isEOF)."""
def _nb_handle_tls_read_binary_ready(
    cb: JSValue, hid: int, max_n: int, status: int
) -> None {
    if status < 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
        return;
    }
    idx: int = 0 - hid;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
        return;
    }
    sock: TLSSocket = _TLS_HANDLES[idx];
    buf_ptr: int = io_alloc(max_n + 1);
    nr: int = tls_read_into(sock, buf_ptr, max_n);
    if nr > 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_number(float(buf_ptr)), js_int(nr), js_false()]);
    } else {
        io_free(buf_ptr);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
    }
}

"""__net.tlsReadBinaryNb(handle, maxBytes, callback) → undefined
Binary-safe non-blocking TLS read.  The callback fires as
callback(ptr, len, isEOF).  Caller must call __buf.free(ptr) after use."""
def:pub net_tls_read_binary_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        _NB_FIRED_FNS.append(args[2]);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
        _nb_wake();
        return js_undefined();
    }
    max_n: int = 4096;
    if jsv_is_int32(args[1]) {
        max_n = jsv_to_int32(args[1]);
    }
    cb: JSValue = args[2];
    sock: TLSSocket = _TLS_HANDLES[idx];

    buf_ptr: int = io_alloc(max_n + 1);
    nr: int = tls_read_into(sock, buf_ptr, max_n);
    if nr > 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_number(float(buf_ptr)), js_int(nr), js_false()]);
        _nb_wake();
        return js_undefined();
    }
    io_free(buf_ptr);
    # Check for clean EOF vs WANT_READ
    if sock.last_error == SSL_ERROR_ZERO_RETURN {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0), js_true()]);
        _nb_wake();
        return js_undefined();
    }
    # SSL_ERROR_WANT_READ — poll for readability
    tls_fd: int = sock.tcp_fd;
    lp3: UVLoop = UVLoop();
    lp3.loop_ptr = _NB_LOOP_PTR;
    ph3: UVHandle = uvpoll_create(lp3, tls_fd);
    uvpoll_start(ph3, UV_READABLE, _nb_poll_cb);
    _nb_add_poll(
        ph3.handle_ptr, tls_fd, cb, _NB_TYPE_TLS_READ_BINARY, h, max_n, "", ""
    );
    return js_undefined();
}

"""__net.tcpWriteRaw(handle, ptr, len) → bytesWritten
Write raw binary bytes from a C heap buffer to a TCP socket.
`ptr` and `len` are JS numbers (integers).  Returns bytes written or -1."""
def:pub net_tcp_write_raw(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return js_int(0 - 1);
    }
    ptr: int = 0;
    if jsv_is_int32(args[1]) {
        ptr = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        ptr = int(jsv_to_double(args[1]));
    }
    n: int = 0;
    if jsv_is_int32(args[2]) {
        n = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        n = int(jsv_to_double(args[2]));
    }
    if ptr == 0 or n <= 0 {
        return js_int(0);
    }
    sock: TCPSocket = _TCP_HANDLES[h];
    written: int = tcp_write_bytes(sock, ptr, n);
    return js_int(written);
}

"""Unref the async handle after draining fired items.
Called from el_tick once the NB fired queue is empty."""
def:pub nb_unref_async {
    if _NB_ASYNC_PTR != 0 {
        ah: UVHandle = UVHandle();
        ah.handle_ptr = _NB_ASYNC_PTR;
        uvhandle_unref(ah);
    }
}

"""Wake the event loop to drain the fired queue on the next tick.
Also refs the async handle so the event loop stays alive until
the fired items are drained (matching the unref in el_tick)."""
def _nb_wake {
    _nb_root_once();  # fired queues were just appended to — ensure GC-rooted
    if _NB_ASYNC_PTR != 0 {
        ah: UVHandle = UVHandle();
        ah.handle_ptr = _NB_ASYNC_PTR;
        uvhandle_ref(ah);
        uvasync_send(ah);
    }
}

# ── Phase 6.7 — node:net / node:tls extras ──────────────────────────────────

"""__net.tcpAcceptNb(listenerHandle, callback) → undefined
Polls the listener fd for readability, then accepts one connection.
callback(clientHandle, errCode) — clientHandle > 0 on success, 0 on error."""
def:pub net_tcp_accept_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_LISTENER_HANDLES) {
        return js_undefined();
    }
    cb: JSValue = args[1];
    listener: TCPListener = _LISTENER_HANDLES[h];

    # Try immediate accept first (non-blocking since listener socket is in listen mode)
    sock: TCPSocket = tcp_accept(listener);
    if sock.connected {
        ch: int = _alloc_tcp(sock);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(ch), js_int(0)]);
        _nb_wake();
        return js_undefined();
    }

    # Poll for readability on the listener fd
    lp: UVLoop = UVLoop();
    lp.loop_ptr = _NB_LOOP_PTR;
    ph: UVHandle = uvpoll_create(lp, listener.fd);
    uvpoll_start(ph, UV_READABLE, _nb_poll_cb);
    _nb_add_poll(ph.handle_ptr, listener.fd, cb, _NB_TYPE_ACCEPT, h, 0, "", "");
    return js_undefined();
}

"""Handle listener fd becoming readable — accept a connection."""
def _nb_handle_accept_ready(cb: JSValue, listener_fd: int, status: int) -> None {
    if status < 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(status)]);
        return;
    }
    # Find the listener whose fd matches
    i: int = 1;
    found_listener: TCPListener = TCPListener();
    while i < len(_LISTENER_HANDLES) {
        if _LISTENER_HANDLES[i].fd == listener_fd {
            found_listener = _LISTENER_HANDLES[i];
            break;
        }
        i = i + 1;
    }
    if not found_listener.listening {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
        return;
    }
    sock: TCPSocket = tcp_accept(found_listener);
    if sock.connected {
        ch: int = _alloc_tcp(sock);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(ch), js_int(0)]);
    } else {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
    }
}

"""__net.tcpSetNodelay(handle, enable) → 0 on success, -1 on error"""
def:pub net_tcp_set_nodelay(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return js_int(0 - 1);
    }
    sock: TCPSocket = _TCP_HANDLES[h];
    enable: bool = False;
    if jsv_is_bool(args[1]) {
        enable = jsv_to_bool(args[1]);
    } elif jsv_is_int32(args[1]) {
        enable = jsv_to_int32(args[1]) != 0;
    }
    rc: int = tcp_set_nodelay(sock, enable);
    return js_int(rc);
}

"""__net.tcpSetKeepalive(handle, enable, delay) → 0 on success, -1 on error"""
def:pub net_tcp_set_keepalive(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return js_int(0 - 1);
    }
    sock: TCPSocket = _TCP_HANDLES[h];
    enable: bool = False;
    if jsv_is_bool(args[1]) {
        enable = jsv_to_bool(args[1]);
    } elif jsv_is_int32(args[1]) {
        enable = jsv_to_int32(args[1]) != 0;
    }
    delay: int = 0;
    if len(args) >= 3 {
        if jsv_is_int32(args[2]) {
            delay = jsv_to_int32(args[2]);
        } elif jsv_is_double(args[2]) {
            delay = jsv_to_int32(args[2]);
        }
    }
    rc: int = tcp_set_keepalive(sock, enable, delay);
    return js_int(rc);
}

"""__net.tcpLocalAddr(handle) → "ip:port" string or "" on error"""
def:pub net_tcp_local_addr(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_string_id(str_intern(""));
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        return jsv_from_string_id(str_intern(""));
    }
    sock: TCPSocket = _TCP_HANDLES[h];
    sa: SocketAddress = tcp_get_local_address(sock);
    if sa.host == "" {
        return jsv_from_string_id(str_intern(""));
    }
    addr_str: str = sa.host + ":" + _nb_int_to_str(sa.port);
    return jsv_from_string_id(str_intern(addr_str));
}

"""__net.tcpWriteNb(handle, data, callback) → undefined
Tries a synchronous write; calls callback(bytesWritten, errCode) asynchronously.
For now this is effectively sync — we push the result to the fired queue immediately.
A truly non-blocking write with poll-for-writable can be added later if needed."""
def:pub net_tcp_write_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TCP_HANDLES) {
        cb0: JSValue = args[2];
        _NB_FIRED_FNS.append(cb0);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
        _nb_wake();
        return js_undefined();
    }
    if not jsv_is_string_cell(args[1]) {
        cb1: JSValue = args[2];
        _NB_FIRED_FNS.append(cb1);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
        _nb_wake();
        return js_undefined();
    }
    sock: TCPSocket = _TCP_HANDLES[h];
    data: str = str_from_id(jsv_to_table_id(args[1]));
    cb: JSValue = args[2];
    written: int = tcp_write(sock, data);
    if written < 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
    } else {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(written), js_int(0)]);
    }
    _nb_wake();
    return js_undefined();
}

# ── TLS Server operations (Phase 6.14) ──────────────────────────────────────

"""__net.tlsCreateServerCtx(certFile, keyFile) → server context handle (int > 0) or 0

Creates a shared TLS server context with the given certificate and key.
This context is reused for all connections accepted by this server.
"""
def:pub net_tls_create_server_ctx(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0);
    }
    if not jsv_is_string_cell(args[0]) {
        return js_int(0);
    }
    if not jsv_is_string_cell(args[1]) {
        return js_int(0);
    }

    cert_file: str = str_from_id(jsv_to_table_id(args[0]));
    key_file: str = str_from_id(jsv_to_table_id(args[1]));

    cfg: TLSConfig = TLSConfig(
        verify_peer=False,
        ca_certs="",
        cert_file=cert_file,
        key_file=key_file,
        server_name=""
    );

    ctx: TLSContext = tls_create_server_context(cfg);
    if ctx.ctx_ptr == 0 {
        return js_int(0);
    }

    # Optional 3rd arg: ALPN protocols (comma-separated string, e.g. "h2,http/1.1")
    if len(args) >= 3 {
        if jsv_is_string_cell(args[2]) {
            alpn_str: str = str_from_id(jsv_to_table_id(args[2]));
            if len(alpn_str) > 0 {
                # Split by comma
                alpn_list: list[str] = [];
                cur: str = "";
                ci: int = 0;
                while ci < len(alpn_str) {
                    ch: str = alpn_str[ci];
                    if ch == "," {
                        if len(cur) > 0 {
                            alpn_list.append(cur);
                        }
                        cur = "";
                    } else {
                        cur = cur + ch;
                    }
                    ci = ci + 1;
                }
                if len(cur) > 0 {
                    alpn_list.append(cur);
                }
                if len(alpn_list) > 0 {
                    tls_ctx_set_alpn_select(ctx, alpn_list);
                }
            }
        }
    }

    _TLS_SERVER_CTX.append(ctx);
    return js_int(len(_TLS_SERVER_CTX) - 1);
}

"""__net.tlsFreeServerCtx(ctxHandle) → undefined

Frees a TLS server context previously created with tlsCreateServerCtx.
"""
def:pub net_tls_free_server_ctx(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_TLS_SERVER_CTX) {
        return js_undefined();
    }
    tls_context_free(_TLS_SERVER_CTX[h]);
    return js_undefined();
}

"""__net.tlsAccept(tcpHandle, ctxHandle) → TLS handle (negative int) or 0

Given a connected TCP client handle (from tcpAccept) and a server context
handle (from tlsCreateServerCtx), performs the server-side TLS handshake.
Returns a negative TLS handle on success (same convention as tlsConnect),
or 0 on failure.
"""
def:pub net_tls_accept(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0);
    }
    tcp_h: int = 0;
    ctx_h: int = 0;
    if jsv_is_int32(args[0]) {
        tcp_h = jsv_to_int32(args[0]);
    }
    if jsv_is_int32(args[1]) {
        ctx_h = jsv_to_int32(args[1]);
    }

    if tcp_h < 1 or tcp_h >= len(_TCP_HANDLES) {
        return js_int(0);
    }
    if ctx_h < 1 or ctx_h >= len(_TLS_SERVER_CTX) {
        return js_int(0);
    }

    sock: TCPSocket = _TCP_HANDLES[tcp_h];
    ctx: TLSContext = _TLS_SERVER_CTX[ctx_h];

    tls_sock: TLSSocket = tls_accept_on_fd_shared_ctx(sock.fd, ctx);
    if tls_sock.ssl_ptr == 0 {
        return js_int(0);
    }

    # Null out the TCP handle's fd so it won't be double-closed
    # (TLS now owns the fd)
    _TCP_HANDLES[tcp_h].fd = 0;
    _TCP_HANDLES[tcp_h].connected = False;

    h: int = _alloc_tls(tls_sock);
    return js_int(h);
}

"""__net.tlsAcceptNb(tcpHandle, ctxHandle, callback) → undefined

Non-blocking TLS accept.  Sets the fd to O_NONBLOCK, wraps it with SSL,
and attempts SSL_accept.  If the handshake needs more data (WANT_READ/WRITE),
a libuv poll is installed so the event loop can process other callbacks
(including the connecting client's SSL_connect) before retrying.

callback(tlsHandle, errCode)  — tlsHandle < 0 on success, 0 on error.
"""
def:pub net_tls_accept_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return js_undefined();
    }
    tcp_h: int = 0;
    ctx_h: int = 0;
    if jsv_is_int32(args[0]) {
        tcp_h = jsv_to_int32(args[0]);
    }
    if jsv_is_int32(args[1]) {
        ctx_h = jsv_to_int32(args[1]);
    }
    cb: JSValue = args[2];

    if tcp_h < 1 or tcp_h >= len(_TCP_HANDLES) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
        _nb_wake();
        return js_undefined();
    }
    if ctx_h < 1 or ctx_h >= len(_TLS_SERVER_CTX) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 2)]);
        _nb_wake();
        return js_undefined();
    }

    sock: TCPSocket = _TCP_HANDLES[tcp_h];
    ctx: TLSContext = _TLS_SERVER_CTX[ctx_h];
    fd: int = sock.fd;

    # Set fd to non-blocking for async SSL_accept
    fl: int = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, fl | O_NONBLOCK);

    # Create SSL object without handshake
    tls_sock: TLSSocket = tls_wrap_fd(fd, ctx, True);
    if tls_sock.ssl_ptr == 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 3)]);
        _nb_wake();
        return js_undefined();
    }

    # Attempt non-blocking handshake
    hs_err: int = tls_handshake_nb(tls_sock);

    if hs_err == 0 {
        # Handshake completed immediately (unlikely but possible)
        _TCP_HANDLES[tcp_h].fd = 0;
        _TCP_HANDLES[tcp_h].connected = False;
        h: int = _alloc_tls(tls_sock);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(h), js_int(0)]);
        _nb_wake();
        return js_undefined();
    }

    if hs_err == SSL_ERROR_WANT_READ or hs_err == SSL_ERROR_WANT_WRITE {
        # Handshake needs more data — allocate the TLS handle now and poll
        _TCP_HANDLES[tcp_h].fd = 0;
        _TCP_HANDLES[tcp_h].connected = False;
        tls_hid: int = _alloc_tls(tls_sock);
        ev: int = UV_READABLE;
        if hs_err == SSL_ERROR_WANT_WRITE {
            ev = UV_WRITABLE;
        }

        lp: UVLoop = UVLoop();
        lp.loop_ptr = _NB_LOOP_PTR;
        ph: UVHandle = uvpoll_create(lp, fd);
        uvpoll_start(ph, ev, _nb_poll_cb);
        # Store: hid=tls_hid (negative), read_n=tcp_h (for cleanup), host="" (unused)
        _nb_add_poll(
            ph.handle_ptr, fd, cb, _NB_TYPE_TLS_ACCEPT, tls_hid, tcp_h, "", ""
        );
        return js_undefined();
    }

    # Fatal handshake error
    tls_close(tls_sock);
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(0), js_int(hs_err)]);
    _nb_wake();
    return js_undefined();
}

"""Handle TLS accept poll readiness: retry SSL_accept on the partially-
handshaked TLS socket.  hid is a negative TLS handle index; read_n holds
the original TCP handle id (unused here but kept for symmetry)."""
def _nb_handle_tls_accept_ready(
    cb: JSValue, tls_hid: int, fd: int, tcp_h: int, status: int
) -> None {
    idx: int = 0 - tls_hid;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 4)]);
        return;
    }
    if status < 0 {
        tls_close(_TLS_HANDLES[idx]);
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(status)]);
        return;
    }

    tls_sock: TLSSocket = _TLS_HANDLES[idx];
    hs_err: int = tls_handshake_nb(tls_sock);

    if hs_err == 0 {
        # Handshake done — fd stays non-blocking for async I/O
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(tls_hid), js_int(0)]);
        return;
    }

    if hs_err == SSL_ERROR_WANT_READ or hs_err == SSL_ERROR_WANT_WRITE {
        # Still in progress — re-poll
        ev: int = UV_READABLE;
        if hs_err == SSL_ERROR_WANT_WRITE {
            ev = UV_WRITABLE;
        }
        lp: UVLoop = UVLoop();
        lp.loop_ptr = _NB_LOOP_PTR;
        ph: UVHandle = uvpoll_create(lp, fd);
        uvpoll_start(ph, ev, _nb_poll_cb);
        _nb_add_poll(
            ph.handle_ptr, fd, cb, _NB_TYPE_TLS_ACCEPT, tls_hid, tcp_h, "", ""
        );
        # Don't wake — continue polling, no callback yet
        return;
    }

    # Fatal error
    tls_close(_TLS_HANDLES[idx]);
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(0), js_int(hs_err)]);
}

"""__net.tlsGetAlpn(tlsHandle) → protocol string or ""

Returns the ALPN-negotiated protocol from a completed TLS handshake."""
def:pub net_tls_get_alpn(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_string_id(str_intern(""));
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    idx: int = 0 - h;
    if idx < 1 or idx >= len(_TLS_HANDLES) {
        return jsv_from_string_id(str_intern(""));
    }
    tls_sock: TLSSocket = _TLS_HANDLES[idx];
    proto: str = tls_get_alpn_selected(tls_sock);
    return jsv_from_string_id(str_intern(proto));
}

# ── Wave 7 — UDP / dgram bridge ─────────────────────────────────────────────

glob _UDP_SS_SIZE: int = 128,
     _UDP_MAX_DGRAM: int = 65535;

def _alloc_udp(sock: UDPSocket) -> int {
    _UDP_HANDLES.append(sock);
    return len(_UDP_HANDLES) - 1;
}

def _udp_cancel_polls(fd: int) -> None {
    if fd <= 0 {
        return;
    }
    pi: int = 0;
    while pi < len(_NB_POLL_FD) {
        if _NB_POLL_FD[pi] == fd {
            eph: UVHandle = UVHandle();
            eph.handle_ptr = _NB_POLL_UVPTR[pi];
            uvpoll_stop(eph);
            uvpoll_close(eph);
            _nb_remove_poll(pi);
        } else {
            pi = pi + 1;
        }
    }
}

"""Fire UDP recv callback: callback(errCode, data, address, port)."""
def _nb_fire_udp_msg(cb: JSValue, err: int, data: str, address: str, port: int) {
    data_v: JSValue = jsv_from_string_id(str_intern(data));
    addr_v: JSValue = jsv_from_string_id(str_intern(address));
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(err), data_v, addr_v, js_int(port)]);
}

"""Try recvfrom on a UDP fd. Returns True if a callback was fired (done);
False if EAGAIN and caller should poll."""
def _nb_try_udp_recv(cb: JSValue, hid: int, fd: int, max_n: int) -> bool {
    buf_ptr: int = calloc(1, max_n + 1);
    addr_buf: int = calloc(1, _UDP_SS_SIZE);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, _UDP_SS_SIZE);
    nread: int = recvfrom(fd, buf_ptr, max_n, 0, addr_buf, len_buf);
    if nread > 2147483647 {
        errn: int = get_errno();
        if errn == EAGAIN or errn == EWOULDBLOCK {
            return False;
        }
        _nb_fire_udp_msg(cb, errn, "", "", 0);
        return True;
    }
    # Success — including zero-length datagrams
    sender: UDPMessage = udp_extract_sender(addr_buf);
    data: str = "";
    if nread > 0 {
        raw: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
        data = raw[0:nread];
    }
    _nb_fire_udp_msg(cb, 0, data, sender.host, sender.port);
    return True;
}

def _nb_handle_udp_recv_ready(
    cb: JSValue, hid: int, fd: int, max_n: int, status: int
) -> None {
    if status < 0 {
        _nb_fire_udp_msg(cb, status, "", "", 0);
        return;
    }
    if hid < 1 or hid >= len(_UDP_HANDLES) {
        _nb_fire_udp_msg(cb, 0 - 1, "", "", 0);
        return;
    }
    done: bool = _nb_try_udp_recv(cb, hid, fd, max_n);
    if not done {
        # Spurious wakeup — re-arm
        lp: UVLoop = UVLoop();
        lp.loop_ptr = _NB_LOOP_PTR;
        ph: UVHandle = uvpoll_create(lp, fd);
        uvpoll_start(ph, UV_READABLE, _nb_poll_cb);
        _nb_add_poll(ph.handle_ptr, fd, cb, _NB_TYPE_UDP_RECV, hid, max_n, "", "");
    }
}

"""UDP send ready: host=address, read_n=port, alpn=data."""
def _nb_handle_udp_send_ready(
    cb: JSValue, hid: int, address: str, port: int, data: str, status: int
) -> None {
    if status < 0 {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(status)]);
        return;
    }
    if hid < 1 or hid >= len(_UDP_HANDLES) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
        return;
    }
    sock: UDPSocket = _UDP_HANDLES[hid];
    sent: int = udp_send(sock, data, address, port);
    if sent < 0 {
        errn: int = sock.last_error;
        if errn == EAGAIN or errn == EWOULDBLOCK {
            lp: UVLoop = UVLoop();
            lp.loop_ptr = _NB_LOOP_PTR;
            ph: UVHandle = uvpoll_create(lp, sock.fd);
            uvpoll_start(ph, UV_WRITABLE, _nb_poll_cb);
            _nb_add_poll(
                ph.handle_ptr, sock.fd, cb, _NB_TYPE_UDP_SEND, hid, port, address, data
            );
            return;
        }
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(errn)]);
        return;
    }
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(sent), js_int(0)]);
}

"""__net.udpCreate(type) → handle > 0 or 0. type: 'udp4'|'udp6'"""
def:pub net_udp_create(args: list[JSValue]) -> JSValue {
    fam: int = AF_INET;
    if len(args) >= 1 and jsv_is_string_cell(args[0]) {
        t: str = str_from_id(jsv_to_table_id(args[0]));
        if t == "udp6" {
            fam = AF_INET6;
        }
    }
    sock: UDPSocket = udp_create_family(fam);
    if sock.fd == 0 {
        return js_int(0);
    }
    h: int = _alloc_udp(sock);
    return js_int(h);
}

"""__net.udpBind(handle, address, port, flags) → bound port or -1"""
def:pub net_udp_bind(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_int(0 - 1);
    }
    address: str = "";
    if len(args) >= 2 and jsv_is_string_cell(args[1]) {
        address = str_from_id(jsv_to_table_id(args[1]));
    }
    port: int = 0;
    if len(args) >= 3 {
        if jsv_is_int32(args[2]) {
            port = jsv_to_int32(args[2]);
        } elif jsv_is_double(args[2]) {
            port = jsv_to_int32(args[2]);
        }
    }
    sock: UDPSocket = _UDP_HANDLES[h];
    rc: int = udp_bind_to(sock, address, port);
    if rc != 0 {
        return js_int(0 - 1);
    }
    return js_int(sock.bound_port);
}

"""__net.udpSendNb(handle, data, port, address, callback) → undefined
callback(bytesWritten, errCode)"""
def:pub net_udp_send_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    cb: JSValue = args[4];
    if h < 1 or h >= len(_UDP_HANDLES) {
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(0 - 1)]);
        _nb_wake();
        return js_undefined();
    }
    data: str = "";
    if jsv_is_string_cell(args[1]) {
        data = str_from_id(jsv_to_table_id(args[1]));
    }
    port: int = 0;
    if jsv_is_int32(args[2]) {
        port = jsv_to_int32(args[2]);
    } elif jsv_is_double(args[2]) {
        port = jsv_to_int32(args[2]);
    }
    address: str = "127.0.0.1";
    if jsv_is_string_cell(args[3]) {
        address = str_from_id(jsv_to_table_id(args[3]));
    }
    sock: UDPSocket = _UDP_HANDLES[h];
    # Empty datagram: sendto with length 0
    sent: int = udp_send(sock, data, address, port);
    if sent < 0 {
        errn: int = sock.last_error;
        if errn == EAGAIN or errn == EWOULDBLOCK {
            lp: UVLoop = UVLoop();
            lp.loop_ptr = _NB_LOOP_PTR;
            ph: UVHandle = uvpoll_create(lp, sock.fd);
            uvpoll_start(ph, UV_WRITABLE, _nb_poll_cb);
            _nb_add_poll(
                ph.handle_ptr, sock.fd, cb, _NB_TYPE_UDP_SEND, h, port, address, data
            );
            return js_undefined();
        }
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(errn)]);
        _nb_wake();
        return js_undefined();
    }
    # udp_send returns the C sendto result; treat unsigned error
    if sent > 2147483647 {
        errn2: int = get_errno();
        if errn2 == EAGAIN or errn2 == EWOULDBLOCK {
            lp2: UVLoop = UVLoop();
            lp2.loop_ptr = _NB_LOOP_PTR;
            ph2: UVHandle = uvpoll_create(lp2, sock.fd);
            uvpoll_start(ph2, UV_WRITABLE, _nb_poll_cb);
            _nb_add_poll(
                ph2.handle_ptr, sock.fd, cb, _NB_TYPE_UDP_SEND, h, port, address, data
            );
            return js_undefined();
        }
        _NB_FIRED_FNS.append(cb);
        _NB_FIRED_ARGS.append([js_int(0), js_int(errn2)]);
        _nb_wake();
        return js_undefined();
    }
    _NB_FIRED_FNS.append(cb);
    _NB_FIRED_ARGS.append([js_int(sent), js_int(0)]);
    _nb_wake();
    return js_undefined();
}

"""__net.udpRecvNb(handle, callback) → undefined
callback(errCode, data, address, port)"""
def:pub net_udp_recv_nb(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    cb: JSValue = args[1];
    if h < 1 or h >= len(_UDP_HANDLES) {
        _nb_fire_udp_msg(cb, 0 - 1, "", "", 0);
        _nb_wake();
        return js_undefined();
    }
    sock: UDPSocket = _UDP_HANDLES[h];
    fd: int = sock.fd;
    max_n: int = _UDP_MAX_DGRAM;
    done: bool = _nb_try_udp_recv(cb, h, fd, max_n);
    if done {
        _nb_wake();
        return js_undefined();
    }
    lp: UVLoop = UVLoop();
    lp.loop_ptr = _NB_LOOP_PTR;
    ph: UVHandle = uvpoll_create(lp, fd);
    uvpoll_start(ph, UV_READABLE, _nb_poll_cb);
    _nb_add_poll(ph.handle_ptr, fd, cb, _NB_TYPE_UDP_RECV, h, max_n, "", "");
    return js_undefined();
}

"""__net.udpClose(handle) → undefined"""
def:pub net_udp_close(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_undefined();
    }
    sock: UDPSocket = _UDP_HANDLES[h];
    _udp_cancel_polls(sock.fd);
    udp_close(sock);
    return js_undefined();
}

"""__net.udpAddress(handle) → {address, port, family} or null"""
def:pub net_udp_address(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    } elif jsv_is_double(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_undefined();
    }
    sock: UDPSocket = _UDP_HANDLES[h];
    if not sock.bound {
        return js_undefined();
    }
    sa: UDPAddress = udp_local_address(sock);
    if sa.host == "" and sa.port == 0 {
        return js_undefined();
    }
    addr_obj: JSValue = js_object_create_null();
    fam_str: str = "IPv4";
    if sa.family == AF_INET6 {
        fam_str = "IPv6";
    }
    js_object_set(
        addr_obj, str_intern("address"), jsv_from_string_id(str_intern(sa.host))
    );
    js_object_set(addr_obj, str_intern("port"), js_int(sa.port));
    js_object_set(
        addr_obj, str_intern("family"), jsv_from_string_id(str_intern(fam_str))
    );
    return addr_obj;
}

"""__net.udpSetBroadcast(handle, flag) → 0 or -1"""
def:pub net_udp_set_broadcast(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_int(0 - 1);
    }
    flag: bool = False;
    if jsv_is_bool(args[1]) {
        flag = jsv_to_bool(args[1]);
    } elif jsv_is_int32(args[1]) {
        flag = jsv_to_int32(args[1]) != 0;
    }
    rc: int = udp_set_broadcast(_UDP_HANDLES[h], flag);
    return js_int(rc);
}

"""__net.udpSetRecvBuf(handle, size) → 0 or -1"""
def:pub net_udp_set_recv_buf(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_int(0 - 1);
    }
    size: int = 0;
    if jsv_is_int32(args[1]) {
        size = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        size = jsv_to_int32(args[1]);
    }
    return js_int(udp_set_buffer_size(_UDP_HANDLES[h], True, size));
}

"""__net.udpGetRecvBuf(handle) → size or -1"""
def:pub net_udp_get_recv_buf(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_int(0 - 1);
    }
    return js_int(udp_get_buffer_size(_UDP_HANDLES[h], True));
}

"""__net.udpSetSendBuf(handle, size) → 0 or -1"""
def:pub net_udp_set_send_buf(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_int(0 - 1);
    }
    size: int = 0;
    if jsv_is_int32(args[1]) {
        size = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        size = jsv_to_int32(args[1]);
    }
    return js_int(udp_set_buffer_size(_UDP_HANDLES[h], False, size));
}

"""__net.udpGetSendBuf(handle) → size or -1"""
def:pub net_udp_get_send_buf(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_int(0 - 1);
    }
    return js_int(udp_get_buffer_size(_UDP_HANDLES[h], False));
}

"""__net.udpSetTTL(handle, ttl) → 0 or -1"""
def:pub net_udp_set_ttl(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0 - 1);
    }
    h: int = 0;
    if jsv_is_int32(args[0]) {
        h = jsv_to_int32(args[0]);
    }
    if h < 1 or h >= len(_UDP_HANDLES) {
        return js_int(0 - 1);
    }
    ttl: int = 64;
    if jsv_is_int32(args[1]) {
        ttl = jsv_to_int32(args[1]);
    } elif jsv_is_double(args[1]) {
        ttl = jsv_to_int32(args[1]);
    }
    return js_int(udp_set_ttl(_UDP_HANDLES[h], ttl));
}
