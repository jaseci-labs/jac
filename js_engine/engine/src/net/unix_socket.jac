"""Blocking Unix-domain (AF_UNIX) sockets for js_engine.

Mirrors the TCP socket API with Unix-domain paths instead of host:port.
Used for IPC (inter-process communication).

Public API
----------
  unix_connect(path)                  -> TCPSocket      (connect to Unix path)
  unix_listen(path, backlog)          -> TCPListener    (bind + listen on Unix path)
  unix_accept(listener)               -> TCPSocket      (accept one connection)

I/O is done via the tcp_socket module's tcp_read/tcp_write/tcp_close since
Unix-domain sockets share the same POSIX stream interface.

Bun references:
  bun/src/bun.js/api/bun/socket.zig — UnixOrHost union (.unix variant)
"""

import from engine.src.ffi.libc {
    calloc,
    socket,
    bind,
    listen,
    accept,
    connect,
    close,
    get_errno
}
import from engine.src.runtime.mem { write_i32, write_byte, read_u16 }
import from engine.src.net.constants { AF_UNIX, SOCK_STREAM }
import from engine.src.net.tcp_socket { TCPSocket, TCPListener, SocketAddress }

# ── Constants (module-private offsets) ────────────────────────────────────────

# struct sockaddr_un layout (x86-64 Linux):
#   sa_family_t  sun_family;   // 2 bytes at offset 0
#   char         sun_path[108]; // 108 bytes at offset 2
glob:priv _SUN_FAMILY: int = 0,
     _SUN_PATH: int = 2,
     _SUN_SIZE: int = 110;

# sizeof(struct sockaddr_un)
# ── Internal helpers ──────────────────────────────────────────────────────────

"""Build a sockaddr_un from a filesystem path.

Returns the pointer to the filled sockaddr_un buffer."""
def _unix_build_sockaddr_un(path: str) -> int {
    buf: int = calloc(1, _SUN_SIZE);
    # sun_family = AF_UNIX (1)
    write_byte(buf, 0, AF_UNIX);
    write_byte(buf, 1, 0);
    # Copy path bytes into sun_path at offset 2
    i: int = 0;
    plen: int = len(path);
    if plen > 107 {
        plen = 107;  # leave room for null terminator
    }
    while i < plen {
        c: int = ord(path[i]);
        write_byte(buf, _SUN_PATH + i, c);
        i = i + 1;
    }
    # null terminator is already there from calloc
    return buf;
}

"""Check if a C int return value indicates error (sign-extension workaround WA-6.1-A)."""
def _unix_is_error(rc: int) -> bool {
    return rc > 2147483647;
}

# ── Public API ────────────────────────────────────────────────────────────────

"""Connect to a Unix-domain socket at the given filesystem path.

Returns a TCPSocket.  On failure, sock.fd == 0.
Use tcp_read/tcp_write/tcp_close from net.tcp_socket for I/O."""
def:pub unix_connect(path: str) -> TCPSocket {
    sock: TCPSocket = TCPSocket();

    fd: int = socket(AF_UNIX, SOCK_STREAM, 0);
    if fd < 0 {
        sock.last_error = get_errno();
        return sock;
    }

    addr: int = _unix_build_sockaddr_un(path);
    # addrlen = 2 (family) + strlen(path)
    addrlen: int = 2 + len(path);
    if addrlen > _SUN_SIZE {
        addrlen = _SUN_SIZE;
    }

    rc: int = connect(fd, addr, addrlen);
    if rc != 0 {
        close(fd);
        sock.last_error = get_errno();
        return sock;
    }

    sock.fd = fd;
    sock.connected = True;
    sock.peer_addr.host = path;
    sock.peer_addr.family = AF_UNIX;
    return sock;
}

"""Create a Unix-domain server socket listening at the given path.

Returns a TCPListener.  On failure, listener.fd == 0.
Use unix_accept() to accept connections."""
def:pub unix_listen(path: str, backlog: int) -> TCPListener {
    listener: TCPListener = TCPListener();
    listener.backlog = backlog;

    fd: int = socket(AF_UNIX, SOCK_STREAM, 0);
    if fd < 0 {
        listener.last_error = get_errno();
        return listener;
    }

    addr: int = _unix_build_sockaddr_un(path);
    addrlen: int = 2 + len(path);
    if addrlen > _SUN_SIZE {
        addrlen = _SUN_SIZE;
    }

    rc: int = bind(fd, addr, addrlen);
    if rc != 0 {
        close(fd);
        listener.last_error = get_errno();
        return listener;
    }

    rc2: int = listen(fd, backlog);
    if rc2 != 0 {
        close(fd);
        listener.last_error = get_errno();
        return listener;
    }

    listener.fd = fd;
    listener.listening = True;
    listener.address.host = path;
    listener.address.family = AF_UNIX;
    return listener;
}

"""Accept one incoming Unix-domain connection.

Returns a TCPSocket.  On failure, sock.fd == 0.
Use tcp_read/tcp_write/tcp_close for I/O."""
def:pub unix_accept(listener: TCPListener) -> TCPSocket {
    sock: TCPSocket = TCPSocket();

    if listener.fd == 0 {
        sock.last_error = -1;
        return sock;
    }

    # Accept with sockaddr_un buffer
    addr_buf: int = calloc(1, _SUN_SIZE);
    len_buf: int = calloc(1, 4);
    write_i32(len_buf, 0, _SUN_SIZE);

    new_fd: int = accept(listener.fd, addr_buf, len_buf);
    if new_fd < 0 {
        sock.last_error = get_errno();
        return sock;
    }
    if _unix_is_error(new_fd) {
        sock.last_error = get_errno();
        return sock;
    }

    sock.fd = new_fd;
    sock.connected = True;
    sock.peer_addr.family = AF_UNIX;
    return sock;
}
