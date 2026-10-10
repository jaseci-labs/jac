"""Blocking UDP datagram sockets for js_engine.

Implements a synchronous (blocking) UDP layer on top of POSIX socket API
via ffi/libc.na.jac.

Architecture
------------
  UDPSocket — a bound or unbound UDP socket for sending/receiving datagrams

Public API
----------
  udp_create(host, port)             -> UDPSocket   (create + optional bind)
  udp_send(sock, data, host, port)   -> int         (sendto)
  udp_recv(sock, n)                  -> UDPMessage   (recvfrom)
  udp_close(sock)                    -> None
  udp_set_broadcast(sock, enable)    -> int

Bun references:
  bun/src/bun.js/api/bun/udp_socket.zig — UDPSocket struct
"""

import from engine.src.ffi.libc {
    calloc,
    socket,
    bind,
    close,
    sendto,
    recvfrom,
    setsockopt,
    getsockopt,
    htons,
    ntohs,
    inet_ntop,
    getaddrinfo,
    freeaddrinfo,
    get_errno,
    getsockname,
    fcntl
}
import from engine.src.runtime.mem {
    read_i32,
    read_u32,
    read_u16,
    read_ptr,
    write_i32,
    io_alloc
}
import from engine.src.runtime.syscall { is_c_error }
import from engine.src.net.constants {
    AF_INET,
    AF_INET6,
    SOCK_DGRAM,
    SOL_SOCKET,
    SO_BROADCAST,
    SO_REUSEADDR,
    SO_RCVBUF,
    SO_SNDBUF,
    IPPROTO_IP,
    IP_TTL,
    F_GETFL,
    F_SETFL,
    O_NONBLOCK
}

# ── Constants (module-private offsets) ────────────────────────────────────────

# struct addrinfo offsets (x86-64 Linux)
glob:priv _AI_FAMILY: int = 4,
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
     _INET6_STRLEN: int = 46;

# sockaddr offsets
# ── Data types ────────────────────────────────────────────────────────────────

"""A UDP socket.

  fd         — the underlying OS file descriptor
  bound      — True if the socket is bound to a local address
  bound_port — the port the socket is bound to (0 = unbound)
  family     — AF_INET or AF_INET6
  last_error — errno from the most recent failed call
"""
obj:pub UDPSocket {
    has fd: int = 0,
        bound: bool = False,
        bound_port: int = 0,
        family: int = 2,
        last_error: int = 0;
}

# AF_INET default
"""A received UDP message.

  data   — the received payload as a string
  length — number of bytes received
  host   — sender's IP address
  port   — sender's port
"""
obj:pub UDPMessage {
    has data: str = "",
        data_ptr: int = 0,
        length: int = 0,
        host: str = "",
        port: int = 0;
}

"""Local endpoint info from getsockname (avoids importing tcp SocketAddress)."""
obj:pub UDPAddress {
    has host: str = "",
        port: int = 0,
        family: int = 0;
}

# ── Internal helpers ──────────────────────────────────────────────────────────

"""Check if a C int return value indicates error (sign-extension workaround WA-6.1-A)."""
def _udp_is_error(rc: int) -> bool {
    return rc > 2147483647;
}

"""Set an integer socket option."""
def _udp_set_int_opt(fd: int, level: int, optname: int, value: int) -> int {
    buf: int = calloc(1, 4);
    write_i32(buf, 0, value);
    rc: int = setsockopt(fd, level, optname, buf, 4);
    return rc;
}

"""Extract host and port from a sockaddr buffer."""
def _udp_extract_sender(addr_ptr: int) -> UDPMessage {
    msg: UDPMessage = UDPMessage();
    fam: int = read_u16(addr_ptr, _SIN_FAMILY);
    port_net: int = read_u16(addr_ptr, _SIN_PORT);
    msg.port = ntohs(port_net);

    if fam == AF_INET {
        buf: int = io_alloc(_INET_STRLEN + 1);
        s: str = inet_ntop(AF_INET, addr_ptr + _SIN_ADDR, buf, _INET_STRLEN);
        msg.host = s;
    } elif fam == AF_INET6 {
        buf: int = io_alloc(_INET6_STRLEN + 1);
        s: str = inet_ntop(AF_INET6, addr_ptr + _SIN6_ADDR, buf, _INET6_STRLEN);
        msg.host = s;
    }
    return msg;
}

"""Public sockaddr → {host, port} extract for the async bridge."""
def:pub udp_extract_sender(addr_ptr: int) -> UDPMessage {
    return _udp_extract_sender(addr_ptr);
}

"""Convert a small positive integer to its decimal string representation."""
def _udp_int_to_str(n: int) -> str {
    if n == 0 {
        return "0";
    }
    result: str = "";
    rem: int = n;
    while rem > 0 {
        d: int = rem - (rem // 10) * 10;
        result = _udp_digit_char(d) + result;
        rem = rem // 10;
    }
    return result;
}

def _udp_digit_char(d: int) -> str {
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

# ── Public API ────────────────────────────────────────────────────────────────

"""Create a UDP socket, optionally bound to host:port.

If port > 0, the socket is bound to the given address.
If port == 0 and host == "", the socket is unbound (for sending only).
If port == 0 and host != "", the socket is bound to a system-assigned port.

Returns a UDPSocket. On failure, sock.fd == 0."""
def:pub udp_create(host: str, port: int) -> UDPSocket {
    sock: UDPSocket = UDPSocket();

    # For now, default to IPv4
    fd: int = socket(AF_INET, SOCK_DGRAM, 0);
    if is_c_error(fd) {
        sock.last_error = get_errno();
        return sock;
    }
    sock.fd = fd;
    sock.family = AF_INET;

    if port > 0 or host != "" {
        # Resolve + bind
        bind_host: str = host;
        if bind_host == "" {
            bind_host = "0.0.0.0";
        }

        port_str: str = _udp_int_to_str(port);
        result_pp: int = calloc(1, 8);

        hints: int = calloc(1, 48);
        write_i32(hints, 0, 1);  # ai_flags = AI_PASSIVE
        write_i32(hints, 4, AF_INET);  # ai_family
        write_i32(hints, 8, SOCK_DGRAM);  # ai_socktype

        rc: int = getaddrinfo(bind_host, port_str, hints, result_pp);
        if rc != 0 {
            close(fd);
            sock.fd = 0;
            sock.last_error = rc;
            return sock;
        }

        first: int = read_ptr(result_pp, 0);
        alen: int = read_u32(first, _AI_ADDRLEN);
        addr: int = read_ptr(first, _AI_ADDR);

        _udp_set_int_opt(fd, SOL_SOCKET, SO_REUSEADDR, 1);

        rc2: int = bind(fd, addr, alen);
        freeaddrinfo(first);
        if rc2 != 0 {
            close(fd);
            sock.fd = 0;
            sock.last_error = get_errno();
            return sock;
        }

        sock.bound = True;

        # Get the actual bound port
        la_buf: int = calloc(1, _SS_SIZE);
        la_len_buf: int = calloc(1, 4);
        write_i32(la_len_buf, 0, _SS_SIZE);
        getsockname(fd, la_buf, la_len_buf);
        port_net: int = read_u16(la_buf, _SIN_PORT);
        sock.bound_port = ntohs(port_net);
    }

    return sock;
}

"""Send a UDP datagram to host:port.

Returns the number of bytes sent, or -1 on error."""
def:pub udp_send(sock: UDPSocket, data: str, host: str, port: int) -> int {
    if sock.fd == 0 {
        return 0 - 1;
    }

    # Resolve destination
    port_str: str = _udp_int_to_str(port);
    result_pp: int = calloc(1, 8);

    hints: int = calloc(1, 48);
    write_i32(hints, 4, sock.family);  # ai_family
    write_i32(hints, 8, SOCK_DGRAM);  # ai_socktype

    rc: int = getaddrinfo(host, port_str, hints, result_pp);
    if rc != 0 {
        sock.last_error = rc;
        return 0 - 1;
    }

    first: int = read_ptr(result_pp, 0);
    alen: int = read_u32(first, _AI_ADDRLEN);
    addr: int = read_ptr(first, _AI_ADDR);

    n: int = len(data);
    sent: int = sendto(sock.fd, data, n, 0, addr, alen);
    freeaddrinfo(first);
    return sent;
}

"""Send exactly data_len bytes from data_ptr (binary-safe)."""
def:pub udp_send_bytes(
    sock: UDPSocket, data_ptr: int, data_len: int, host: str, port: int
) -> int {
    if sock.fd == 0 or data_ptr == 0 or data_len <= 0 {
        return 0 - 1;
    }
    port_str: str = _udp_int_to_str(port);
    result_pp: int = calloc(1, 8);
    hints: int = calloc(1, 48);
    write_i32(hints, 4, sock.family);
    write_i32(hints, 8, SOCK_DGRAM);
    rc: int = getaddrinfo(host, port_str, hints, result_pp);
    if rc != 0 {
        sock.last_error = rc;
        return 0 - 1;
    }
    first: int = read_ptr(result_pp, 0);
    alen: int = read_u32(first, _AI_ADDRLEN);
    addr: int = read_ptr(first, _AI_ADDR);
    buf: str = data_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    sent: int = sendto(sock.fd, buf, data_len, 0, addr, alen);
    freeaddrinfo(first);

    if _udp_is_error(sent) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return sent;
}

"""Receive a UDP datagram (blocks until a message arrives).

Returns a UDPMessage with sender info.  On error, length == 0."""
def:pub udp_recv(sock: UDPSocket, n: int) -> UDPMessage {
    msg: UDPMessage = UDPMessage();
    if sock.fd == 0 {
        return msg;
    }

    buf: int = io_alloc(n + 1);
    addr_buf: int = calloc(1, _SS_SIZE);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, _SS_SIZE);

    nread: int = recvfrom(sock.fd, buf, n, 0, addr_buf, len_buf);
    if _udp_is_error(nread) {
        sock.last_error = get_errno();
        return msg;
    }
    if nread == 0 {
        return msg;
    }

    msg = _udp_extract_sender(addr_buf);
    msg.data = buf;  # jac:ignore[E1001] pointer reinterpret
    msg.data_ptr = buf;
    msg.length = nread;
    return msg;
}

"""Close the UDP socket."""
def:pub udp_close(sock: UDPSocket) {
    if sock.fd > 0 {
        close(sock.fd);
        sock.fd = 0;
    }
    sock.bound = False;
}

"""Enable or disable SO_BROADCAST.

Returns 0 on success, -1 on error."""
def:pub udp_set_broadcast(sock: UDPSocket, enable: bool) -> int {
    val: int = 0;
    if enable {
        val = 1;
    }
    rc: int = _udp_set_int_opt(sock.fd, SOL_SOCKET, SO_BROADCAST, val);
    if _udp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return 0;
}

# ── Async / Node dgram helpers (Wave 7) ───────────────────────────────────────

"""Create an unbound non-blocking UDP socket for the given address family.

family must be AF_INET or AF_INET6.  On failure sock.fd == 0."""
def:pub udp_create_family(family: int) -> UDPSocket {
    sock: UDPSocket = UDPSocket();
    fam: int = family;
    if fam != AF_INET6 {
        fam = AF_INET;
    }
    fd: int = socket(fam, SOCK_DGRAM, 0);
    if is_c_error(fd) {
        sock.last_error = get_errno();
        return sock;
    }
    sock.fd = fd;
    sock.family = fam;
    flags: int = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags + O_NONBLOCK);
    return sock;
}

"""Bind an existing UDP socket to host:port.

host == \"\" binds to the wildcard address for the socket family.
port == 0 requests an ephemeral port.
Returns 0 on success, -1 on error."""
def:pub udp_bind_to(sock: UDPSocket, host: str, port: int) -> int {
    if sock.fd == 0 {
        return 0 - 1;
    }
    bind_host: str = host;
    if bind_host == "" {
        if sock.family == AF_INET6 {
            bind_host = "::";
        } else {
            bind_host = "0.0.0.0";
        }
    }
    port_str: str = _udp_int_to_str(port);
    result_pp: int = calloc(1, 8);
    hints: int = calloc(1, 48);
    write_i32(hints, 0, 1);  # AI_PASSIVE
    write_i32(hints, 4, sock.family);
    write_i32(hints, 8, SOCK_DGRAM);
    rc: int = getaddrinfo(bind_host, port_str, hints, result_pp);
    if rc != 0 {
        sock.last_error = rc;
        return 0 - 1;
    }
    first: int = read_ptr(result_pp, 0);
    alen: int = read_u32(first, _AI_ADDRLEN);
    addr: int = read_ptr(first, _AI_ADDR);
    _udp_set_int_opt(sock.fd, SOL_SOCKET, SO_REUSEADDR, 1);
    rc2: int = bind(sock.fd, addr, alen);
    freeaddrinfo(first);
    if rc2 != 0 {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    sock.bound = True;
    sa: UDPAddress = udp_local_address(sock);
    sock.bound_port = sa.port;
    return 0;
}

"""Return the local address via getsockname."""
def:pub udp_local_address(sock: UDPSocket) -> UDPAddress {
    sa: UDPAddress = UDPAddress();
    if sock.fd == 0 {
        return sa;
    }
    la_buf: int = calloc(1, _SS_SIZE);
    la_len_buf: int = calloc(1, 4);
    write_i32(la_len_buf, 0, _SS_SIZE);
    rc: int = getsockname(sock.fd, la_buf, la_len_buf);
    if rc != 0 {
        sock.last_error = get_errno();
        return sa;
    }
    msg: UDPMessage = _udp_extract_sender(la_buf);
    sa.host = msg.host;
    sa.port = msg.port;
    sa.family = sock.family;
    fam: int = read_u16(la_buf, _SIN_FAMILY);
    if fam == AF_INET or fam == AF_INET6 {
        sa.family = fam;
    }
    return sa;
}

"""Set SO_RCVBUF or SO_SNDBUF. is_recv=True → RCVBUF."""
def:pub udp_set_buffer_size(sock: UDPSocket, is_recv: bool, size: int) -> int {
    if sock.fd == 0 {
        return 0 - 1;
    }
    opt: int = SO_SNDBUF;
    if is_recv {
        opt = SO_RCVBUF;
    }
    rc: int = _udp_set_int_opt(sock.fd, SOL_SOCKET, opt, size);
    if _udp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return 0;
}

"""Get SO_RCVBUF or SO_SNDBUF. Returns size or -1 on error."""
def:pub udp_get_buffer_size(sock: UDPSocket, is_recv: bool) -> int {
    if sock.fd == 0 {
        return 0 - 1;
    }
    opt: int = SO_SNDBUF;
    if is_recv {
        opt = SO_RCVBUF;
    }
    buf: int = calloc(1, 4);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, 4);
    rc: int = getsockopt(sock.fd, SOL_SOCKET, opt, buf, len_buf);
    if _udp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return read_i32(buf, 0);
}

"""Set IP_TTL (IPv4). Returns 0 on success, -1 on error."""
def:pub udp_set_ttl(sock: UDPSocket, ttl: int) -> int {
    if sock.fd == 0 {
        return 0 - 1;
    }
    rc: int = _udp_set_int_opt(sock.fd, IPPROTO_IP, IP_TTL, ttl);
    if _udp_is_error(rc) {
        sock.last_error = get_errno();
        return 0 - 1;
    }
    return 0;
}
