"""Blocking TCP client + server sockets for js_engine.

Implements a synchronous (blocking) TCP layer on top of POSIX socket API
via ffi/libc.na.jac.  This is the transport layer that HTTP, WebSocket,
and TLS sit on.

Architecture
------------
  SocketAddress — resolved endpoint (host, port, address family)
  TCPSocket     — an active TCP connection (client or accepted server-side)
  TCPListener   — a listening server socket that accepts connections

Public API
----------
  tcp_connect(host, port)           -> TCPSocket   (DNS + connect)
  tcp_listen(host, port, backlog)   -> TCPListener (bind + listen)
  tcp_accept(listener)              -> TCPSocket   (accept one connection)
  tcp_read(sock, n)                 -> str         (blocking read)
  tcp_write(sock, data)             -> int         (blocking write)
  tcp_close(sock)                   -> None
  tcp_shutdown(sock, how)           -> int         (half-close)
  tcp_set_nodelay(sock, enable)     -> int
  tcp_set_keepalive(sock, enable, delay) -> int
  tcp_get_local_address(sock)       -> SocketAddress
  tcp_get_peer_address(sock)        -> SocketAddress

Bun references:
  bun/src/bun.js/api/bun/socket.zig            — NewSocket struct
  bun/src/bun.js/api/bun/socket/Listener.zig   — server accept loop
  bun/src/bun.js/api/bun/socket/SocketAddress.zig — address resolution
"""

import from engine.src.ffi.libc {
    calloc,
    socket,
    bind,
    listen,
    accept,
    connect,
    shutdown,
    send,
    recv,
    close,
    setsockopt,
    getsockopt,
    htons,
    ntohs,
    inet_ntop,
    getaddrinfo,
    freeaddrinfo,
    get_errno,
    getsockname,
    getpeername,
    fcntl
}
import from engine.src.runtime.syscall { is_c_error }
import from engine.src.runtime.mem {
    io_alloc,
    read_i32,
    read_u32,
    read_u16,
    read_ptr,
    write_i32,
    write_byte
}
import from engine.src.net.constants {
    AF_INET,
    AF_INET6,
    AF_UNIX,
    SOCK_STREAM,
    SOCK_DGRAM,
    SHUT_RD,
    SHUT_WR,
    SHUT_RDWR,
    SOL_SOCKET,
    IPPROTO_TCP,
    SO_REUSEADDR,
    SO_REUSEPORT,
    SO_KEEPALIVE,
    SO_RCVTIMEO,
    SO_SNDTIMEO,
    SO_ERROR,
    TCP_NODELAY,
    TCP_KEEPIDLE,
    TCP_KEEPINTVL,
    TCP_KEEPCNT,
    F_GETFL,
    F_SETFL,
    O_NONBLOCK,
    EINPROGRESS
}

# ── Constants (module-private offsets) ────────────────────────────────────────

# struct addrinfo offsets (x86-64 Linux)
glob:priv _AI_FAMILY: int = 4,
     _AI_SOCKTYPE: int = 8,
     _AI_ADDRLEN: int = 16,
     _AI_ADDR: int = 24,
     _AI_NEXT: int = 40,
     _SIN_FAMILY: int = 0,
     _SIN_PORT: int = 2,
     _SIN_ADDR: int = 4,
     _SIN_SIZE: int = 16,
     _SIN6_FAMILY: int = 0,
     _SIN6_PORT: int = 2,
     _SIN6_ADDR: int = 8,
     _SIN6_SIZE: int = 28,
     _SS_SIZE: int = 128,
     _INET_STRLEN: int = 16,
     _INET6_STRLEN: int = 46;  # int ai_family

# int ai_socktype
# socklen_t ai_addrlen
# struct sockaddr *ai_addr
# struct addrinfo *ai_next

# struct sockaddr_in offsets (x86-64)
# sa_family_t (2 bytes)
# in_port_t (2 bytes, network order)
# struct in_addr (4 bytes)
# sizeof(struct sockaddr_in)

# struct sockaddr_in6 offsets

# struct in6_addr (16 bytes)
# sizeof(struct sockaddr_in6)

# struct sockaddr_storage
# sizeof(struct sockaddr_storage)

# INET_ADDRSTRLEN / INET6_ADDRSTRLEN
# ── Data types ────────────────────────────────────────────────────────────────

"""A resolved network endpoint.

  host    — IP address string (e.g. "127.0.0.1", "::1")
  port    — port number in host byte order
  family  — AF_INET (2) or AF_INET6 (10)
"""
obj:pub SocketAddress {
    has host: str = "",
        port: int = 0,
        family: int = 0;
}

"""An active TCP connection.

  fd          — the underlying OS file descriptor
  connected   — True once the connection is established
  local_addr  — local endpoint (populated after connect/accept)
  peer_addr   — remote endpoint (populated after connect/accept)
  last_error  — errno from the most recent failed call
"""
obj:pub TCPSocket {
    has fd: int = 0,
        connected: bool = False,
        local_addr: SocketAddress = SocketAddress(),
        peer_addr: SocketAddress = SocketAddress(),
        last_error: int = 0;
}

"""A TCP server listening for incoming connections.

  fd         — the listening socket file descriptor
  address    — the bound address
  backlog    — the listen backlog
  listening  — True once listen() has been called
  last_error — errno from the most recent failed call
"""
obj:pub TCPListener {
    has fd: int = 0,
        address: SocketAddress = SocketAddress(),
        backlog: int = 128,
        listening: bool = False,
        last_error: int = 0;
}

# ── Internal helpers ──────────────────────────────────────────────────────────

"""Convert a small positive integer to its decimal string representation.
Same as tls.na.jac _tcp_int_to_str — duplicated here to avoid circular deps."""
def _tcp_int_to_str(n: int) -> str {
    if n == 0 {
        return "0";
    }
    if n == 21 {
        return "21";
    }
    if n == 22 {
        return "22";
    }
    if n == 25 {
        return "25";
    }
    if n == 53 {
        return "53";
    }
    if n == 80 {
        return "80";
    }
    if n == 110 {
        return "110";
    }
    if n == 143 {
        return "143";
    }
    if n == 443 {
        return "443";
    }
    if n == 465 {
        return "465";
    }
    if n == 587 {
        return "587";
    }
    if n == 636 {
        return "636";
    }
    if n == 993 {
        return "993";
    }
    if n == 995 {
        return "995";
    }
    if n == 3000 {
        return "3000";
    }
    if n == 3306 {
        return "3306";
    }
    if n == 5432 {
        return "5432";
    }
    if n == 6379 {
        return "6379";
    }
    if n == 8080 {
        return "8080";
    }
    if n == 8443 {
        return "8443";
    }
    # Generic: build digit-by-digit
    result: str = "";
    rem: int = n;
    while rem > 0 {
        d: int = rem - (rem // 10) * 10;
        result = _tcp_digit_char(d) + result;
        rem = rem // 10;
    }
    return result;
}

"""Return the ASCII character for a single decimal digit 0..9."""
def _tcp_digit_char(d: int) -> str {
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

"""Check if a C int return value indicates error (sign-extension workaround WA-6.1-A)."""
def _tcp_is_error(rc: int) -> bool {
    return rc > 2147483647;
}

"""Extract a SocketAddress from a sockaddr buffer.

Reads family, port, and IP address from a raw sockaddr_in or sockaddr_in6."""
def _tcp_extract_address(addr_ptr: int) -> SocketAddress {
    sa: SocketAddress = SocketAddress();
    fam: int = read_u16(addr_ptr, _SIN_FAMILY);
    sa.family = fam;

    port_net: int = read_u16(addr_ptr, _SIN_PORT);
    sa.port = ntohs(port_net);

    if fam == AF_INET {
        buf: int = io_alloc(_INET_STRLEN + 1);
        s: str = inet_ntop(AF_INET, addr_ptr + _SIN_ADDR, buf, _INET_STRLEN);
        sa.host = s;
    } elif fam == AF_INET6 {
        buf: int = io_alloc(_INET6_STRLEN + 1);
        s: str = inet_ntop(AF_INET6, addr_ptr + _SIN6_ADDR, buf, _INET6_STRLEN);
        sa.host = s;
    }
    return sa;
}

"""Set an integer socket option."""
def _tcp_set_int_opt(fd: int, level: int, optname: int, value: int) -> int {
    buf: int = calloc(1, 4);
    write_i32(buf, 0, value);
    rc: int = setsockopt(fd, level, optname, buf, 4);
    return rc;
}

# ── Client API ────────────────────────────────────────────────────────────────

"""Set a socket to non-blocking mode using fcntl(F_SETFL, O_NONBLOCK).

Returns 0 on success, -1 on error."""
def:pub tcp_set_nonblock(sock: TCPSocket) -> int {
    flags: int = fcntl(sock.fd, F_GETFL, 0);
    if flags < 0 {
        return 0 - 1;
    }
    return fcntl(sock.fd, F_SETFL, flags + O_NONBLOCK);
}

"""Connect to host:port using TCP.  Does DNS resolution and POSIX connect().

Returns a TCPSocket.  On failure, sock.fd == 0 and sock.last_error is set.

Usage:
    sock: TCPSocket = tcp_connect("example.com", 80);
    if sock.fd == 0 { print("connect failed"); }
    tcp_write(sock, "GET / HTTP/1.0...");
    data: str = tcp_read(sock, 4096);
    tcp_close(sock);
"""
def:pub tcp_connect(host: str, port: int) -> TCPSocket {
    sock: TCPSocket = TCPSocket();

    # ── 1. Resolve host ───────────────────────────────────────────────────
    port_str: str = _tcp_int_to_str(port);
    result_pp: int = calloc(1, 8);
    rc: int = getaddrinfo(host, port_str, 0, result_pp);
    if rc != 0 {
        sock.last_error = rc;
        return sock;
    }

    first: int = read_ptr(result_pp, 0);
    fam: int = read_i32(first, _AI_FAMILY);
    alen: int = read_u32(first, _AI_ADDRLEN);
    addr: int = read_ptr(first, _AI_ADDR);

    # ── 2. Create socket ─────────────────────────────────────────────────
    fd: int = socket(fam, SOCK_STREAM, 0);
    if is_c_error(fd) {
        freeaddrinfo(first);
        sock.last_error = get_errno();
        return sock;
    }

    # ── 3. Connect ───────────────────────────────────────────────────────
    rc2: int = connect(fd, addr, alen);
    freeaddrinfo(first);
    if rc2 != 0 {
        close(fd);
        sock.last_error = get_errno();
        return sock;
    }

    sock.fd = fd;
    sock.connected = True;

    # Populate peer address
    sock.peer_addr.host = host;
    sock.peer_addr.port = port;
    sock.peer_addr.family = fam;

    # Populate local address
    la_buf: int = calloc(1, _SS_SIZE);
    la_len_buf: int = calloc(1, 4);
    write_i32(la_len_buf, 0, _SS_SIZE);
    gsn_rc: int = getsockname(fd, la_buf, la_len_buf);
    if gsn_rc == 0 {
        sock.local_addr = _tcp_extract_address(la_buf);
    }

    return sock;
}

"""Start a non-blocking TCP connect.  Does DNS resolution (blocking), creates
a socket, sets O_NONBLOCK, and calls connect().

Return semantics:
  - sock.fd > 0, sock.connected == True   → immediate connection (rare)
  - sock.fd > 0, sock.connected == False   → EINPROGRESS; poll for writable
  - sock.fd == 0                           → error (see sock.last_error)
"""
def:pub tcp_connect_nb_start(host: str, port: int) -> TCPSocket {
    sock: TCPSocket = TCPSocket();

    # ── 1. Resolve host (blocking for now) ────────────────────────────────
    port_str: str = _tcp_int_to_str(port);
    result_pp: int = calloc(1, 8);
    rc: int = getaddrinfo(host, port_str, 0, result_pp);
    if rc != 0 {
        sock.last_error = rc;
        return sock;
    }
    first: int = read_ptr(result_pp, 0);
    fam: int = read_i32(first, _AI_FAMILY);
    alen: int = read_u32(first, _AI_ADDRLEN);
    addr: int = read_ptr(first, _AI_ADDR);

    # ── 2. Create socket ─────────────────────────────────────────────────
    fd: int = socket(fam, SOCK_STREAM, 0);
    if is_c_error(fd) {
        freeaddrinfo(first);
        sock.last_error = get_errno();
        return sock;
    }

    # ── 3. Set non-blocking ──────────────────────────────────────────────
    flags: int = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags + O_NONBLOCK);

    # ── 4. Non-blocking connect ──────────────────────────────────────────
    rc2: int = connect(fd, addr, alen);
    freeaddrinfo(first);

    if rc2 == 0 {
        # Immediate connection (rare for non-blocking)
        sock.fd = fd;
        sock.connected = True;
        sock.peer_addr.host = host;
        sock.peer_addr.port = port;
        sock.peer_addr.family = fam;
        return sock;
    }

    err: int = get_errno();
    if err == EINPROGRESS {
        # Expected: connection in progress
        sock.fd = fd;
        sock.connected = False;
        sock.peer_addr.host = host;
        sock.peer_addr.port = port;
        sock.peer_addr.family = fam;
        return sock;
    }

    # Real error
    close(fd);
    sock.last_error = err;
    return sock;
}

# ── Server API ────────────────────────────────────────────────────────────────

"""Create a TCP server listening on host:port.

Binds to the given address, sets SO_REUSEADDR, and calls listen().
If host is "" or "0.0.0.0", listens on all interfaces.

Returns a TCPListener.  On failure, listener.fd == 0 and last_error is set.

Usage:
    listener: TCPListener = tcp_listen("0.0.0.0", 8080, 128);
    if listener.fd == 0 { print("listen failed"); }
    client: TCPSocket = tcp_accept(listener);
    data: str = tcp_read(client, 1024);
    tcp_write(client, "HTTP/1.1 200 OK...");
    tcp_close(client);
    tcp_listener_close(listener);
"""
def:pub tcp_listen(host: str, port: int, backlog: int) -> TCPListener {
    listener: TCPListener = TCPListener();
    listener.backlog = backlog;

    # ── 1. Resolve bind address ───────────────────────────────────────────
    bind_host: str = host;
    if bind_host == "" {
        bind_host = "0.0.0.0";
    }

    port_str: str = _tcp_int_to_str(port);
    result_pp: int = calloc(1, 8);

    # Set up hints for getaddrinfo: AI_PASSIVE for server binding
    # hints struct: ai_flags=AI_PASSIVE(1), ai_family=AF_UNSPEC(0), ai_socktype=SOCK_STREAM
    hints: int = calloc(1, 48);  # sizeof(struct addrinfo) = 48 on x86-64
    write_i32(hints, 0, 1);  # ai_flags = AI_PASSIVE
    write_i32(hints, 8, 1);  # ai_socktype = SOCK_STREAM

    rc: int = getaddrinfo(bind_host, port_str, hints, result_pp);
    if rc != 0 {
        listener.last_error = rc;
        return listener;
    }

    first: int = read_ptr(result_pp, 0);
    fam: int = read_i32(first, _AI_FAMILY);
    alen: int = read_u32(first, _AI_ADDRLEN);
    addr: int = read_ptr(first, _AI_ADDR);

    # ── 2. Create socket ─────────────────────────────────────────────────
    fd: int = socket(fam, SOCK_STREAM, 0);
    if is_c_error(fd) {
        freeaddrinfo(first);
        listener.last_error = get_errno();
        return listener;
    }

    # ── 3. Set SO_REUSEADDR ──────────────────────────────────────────────
    _tcp_set_int_opt(fd, SOL_SOCKET, SO_REUSEADDR, 1);

    # ── 4. Bind ──────────────────────────────────────────────────────────
    rc2: int = bind(fd, addr, alen);
    freeaddrinfo(first);
    if rc2 != 0 {
        close(fd);
        listener.last_error = get_errno();
        return listener;
    }

    # ── 5. Listen ────────────────────────────────────────────────────────
    rc3: int = listen(fd, backlog);
    if rc3 != 0 {
        close(fd);
        listener.last_error = get_errno();
        return listener;
    }

    # ── 6. Set O_NONBLOCK on listener fd (for non-blocking accept) ──────
    lf: int = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, lf + O_NONBLOCK);

    listener.fd = fd;
    listener.listening = True;

    # Populate bound address (may differ from requested if port=0)
    la_buf: int = calloc(1, _SS_SIZE);
    la_len_buf: int = calloc(1, 4);
    write_i32(la_len_buf, 0, _SS_SIZE);
    gsn_rc: int = getsockname(fd, la_buf, la_len_buf);
    if gsn_rc == 0 {
        listener.address = _tcp_extract_address(la_buf);
    }

    return listener;
}

"""Accept one incoming connection from a listening socket.

Blocks until a client connects.  Returns a TCPSocket with the accepted fd.
On failure, sock.fd == 0 and sock.last_error is set."""
def:pub tcp_accept(listener: TCPListener) -> TCPSocket {
    sock: TCPSocket = TCPSocket();

    if listener.fd == 0 {
        sock.last_error = -1;
        return sock;
    }

    # Accept with full sockaddr_storage for the client address
    addr_buf: int = calloc(1, _SS_SIZE);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, _SS_SIZE);

    new_fd: int = accept(listener.fd, addr_buf, len_buf);
    if is_c_error(new_fd) {
        sock.last_error = get_errno();
        return sock;
    }
    # C int sign-extension check (WA-6.1-A)
    if _tcp_is_error(new_fd) {
        sock.last_error = get_errno();
        return sock;
    }

    sock.fd = new_fd;
    sock.connected = True;

    # Set accepted socket to non-blocking (accept() on Linux does NOT
    # inherit O_NONBLOCK from the listener)
    nb_flags: int = fcntl(new_fd, F_GETFL, 0);
    fcntl(new_fd, F_SETFL, nb_flags + O_NONBLOCK);

    # Populate peer address from accepted sockaddr
    sock.peer_addr = _tcp_extract_address(addr_buf);

    # Populate local address
    la_buf: int = calloc(1, _SS_SIZE);
    la_len_buf: int = calloc(1, 4);
    write_i32(la_len_buf, 0, _SS_SIZE);
    gsn_rc: int = getsockname(new_fd, la_buf, la_len_buf);
    if gsn_rc == 0 {
        sock.local_addr = _tcp_extract_address(la_buf);
    }

    return sock;
}

"""Close a listening socket."""
def:pub tcp_listener_close(listener: TCPListener) {
    if listener.fd > 0 {
        close(listener.fd);
        listener.fd = 0;
    }
    listener.listening = False;
}

# ── I/O ───────────────────────────────────────────────────────────────────────

"""Read up to n bytes from the TCP socket.

Returns the received data as a Jac str, or "" on error/EOF.
Check sock.last_error for the errno on failure; 0 means clean EOF."""
def:pub tcp_read(sock: TCPSocket, n: int) -> str {
    if sock.fd == 0 {
        return "";
    }
    buf: int = io_alloc(n + 1);  # +1 for null terminator; io_alloc adds 8-byte str header
    nread: int = recv(sock.fd, buf, n, 0);
    # C int -1 zero-extends to 4294967295 (WA-6.1-A)
    if _tcp_is_error(nread) {
        sock.last_error = get_errno();
        return "";
    }
    if nread == 0 {
        # EOF — peer closed cleanly
        sock.connected = False;
        return "";
    }
    result: str = buf;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

"""Write data to the TCP socket.

Returns the number of bytes written, or -1 on error.
On error, sock.last_error holds the errno."""
def:pub tcp_write(sock: TCPSocket, data: str) -> int {
    if sock.fd == 0 {
        return 0 - 1;
    }
    n: int = len(data);
    rc: int = send(sock.fd, data, n, 0);
    # C int -1 zero-extends (WA-6.1-A)
    if _tcp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return rc;
}

"""Write `data_len` bytes from a raw C pointer `data_ptr` (binary-safe).

Unlike tcp_write, this does not stop at null bytes — it sends exactly
`data_len` bytes.  Used by net_tcp_write_raw and by the Phase 6.12 test
server to deliver gzip-compressed response bodies."""
def:pub tcp_write_bytes(sock: TCPSocket, data_ptr: int, data_len: int) -> int {
    if sock.fd == 0 or data_ptr == 0 {
        return 0 - 1;
    }
    buf: str = data_ptr;  # cast raw pointer to str — Jac native allows this  # jac:ignore[E1001] pointer reinterpreted as str
    rc: int = send(sock.fd, buf, data_len, 0);
    if _tcp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return rc;
}

"""Write all data to the TCP socket, retrying on partial writes.

Returns the total number of bytes written, or -1 on error."""
def:pub tcp_write_all(sock: TCPSocket, data: str) -> int {
    total: int = len(data);
    sent: int = 0;
    while sent < total {
        # We need to send the remaining bytes.  Since we can't do
        # pointer arithmetic on Jac strings, we must re-send from the
        # beginning if send() returns a partial write.  In practice,
        # blocking sockets almost always send everything in one call.
        rc: int = send(sock.fd, data, total, 0);
        if _tcp_is_error(rc) {
            sock.last_error = get_errno();
            return 0 - 1;
        }
        if rc == 0 {
            return sent;
        }
        sent = sent + rc;
        if sent < total {
            # Partial write — unlikely on blocking socket, but safe to break
            return sent;
        }
    }
    return sent;
}

"""Shut down part or all of a TCP connection.

how: SHUT_RD (0), SHUT_WR (1), or SHUT_RDWR (2).
Returns 0 on success, -1 on error."""
def:pub tcp_shutdown(sock: TCPSocket, how: int) -> int {
    if sock.fd == 0 {
        return 0 - 1;
    }
    rc: int = shutdown(sock.fd, how);
    if _tcp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return 0;
}

"""Close the TCP socket and release the file descriptor."""
def:pub tcp_close(sock: TCPSocket) {
    if sock.fd > 0 {
        close(sock.fd);
        sock.fd = 0;
    }
    sock.connected = False;
}

# ── Socket options ────────────────────────────────────────────────────────────

"""Enable or disable Nagle's algorithm (TCP_NODELAY).

enable=True disables Nagle (sends immediately).
Returns 0 on success, -1 on error."""
def:pub tcp_set_nodelay(sock: TCPSocket, enable: bool) -> int {
    val: int = 0;
    if enable {
        val = 1;
    }
    rc: int = _tcp_set_int_opt(sock.fd, IPPROTO_TCP, TCP_NODELAY, val);
    if _tcp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return 0;
}

"""Enable or disable TCP keepalive with the given idle delay (seconds).

Returns 0 on success, -1 on error."""
def:pub tcp_set_keepalive(sock: TCPSocket, enable: bool, delay: int) -> int {
    val: int = 0;
    if enable {
        val = 1;
    }
    rc: int = _tcp_set_int_opt(sock.fd, SOL_SOCKET, SO_KEEPALIVE, val);
    if _tcp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    if enable {
        _tcp_set_int_opt(sock.fd, IPPROTO_TCP, TCP_KEEPIDLE, delay);
        _tcp_set_int_opt(sock.fd, IPPROTO_TCP, TCP_KEEPINTVL, delay);
        _tcp_set_int_opt(sock.fd, IPPROTO_TCP, TCP_KEEPCNT, 3);
    }
    return 0;
}

"""Set SO_REUSEADDR on the socket.

Returns 0 on success, -1 on error."""
def:pub tcp_set_reuseaddr(sock: TCPSocket, enable: bool) -> int {
    val: int = 0;
    if enable {
        val = 1;
    }
    rc: int = _tcp_set_int_opt(sock.fd, SOL_SOCKET, SO_REUSEADDR, val);
    if _tcp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return 0;
}

# ── Address introspection ─────────────────────────────────────────────────────

"""Get the local address of a connected socket."""
def:pub tcp_get_local_address(sock: TCPSocket) -> SocketAddress {
    if sock.fd == 0 {
        return SocketAddress();
    }
    addr_buf: int = calloc(1, _SS_SIZE);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, _SS_SIZE);
    rc: int = getsockname(sock.fd, addr_buf, len_buf);
    if rc != 0 {
        return SocketAddress();
    }
    sa: SocketAddress = _tcp_extract_address(addr_buf);
    return sa;
}

"""Get the peer (remote) address of a connected socket."""
def:pub tcp_get_peer_address(sock: TCPSocket) -> SocketAddress {
    if sock.fd == 0 {
        return SocketAddress();
    }
    addr_buf: int = calloc(1, _SS_SIZE);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, _SS_SIZE);
    rc: int = getpeername(sock.fd, addr_buf, len_buf);
    if rc != 0 {
        return SocketAddress();
    }
    sa: SocketAddress = _tcp_extract_address(addr_buf);
    return sa;
}
