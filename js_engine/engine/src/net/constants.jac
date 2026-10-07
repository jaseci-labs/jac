"""Shared POSIX socket constants for js_engine net modules.

Centralises :pub constants that would otherwise be duplicated across
tcp_socket, udp_socket, and unix_socket — causing LLVM link-time
collisions when two sibling modules are imported into the same program.
"""

# ── Address families ──────────────────────────────────────────────────────────
glob:pub AF_INET: int = 2,
     AF_INET6: int = 10,
     AF_UNIX: int = 1,
     SOCK_STREAM: int = 1,
     SOCK_DGRAM: int = 2,
     SHUT_RD: int = 0,
     SHUT_WR: int = 1,
     SHUT_RDWR: int = 2,
     SOL_SOCKET: int = 1,
     SO_REUSEADDR: int = 2,
     SO_REUSEPORT: int = 15,
     SO_KEEPALIVE: int = 9,
     SO_BROADCAST: int = 6,
     SO_SNDBUF: int = 7,
     SO_RCVBUF: int = 8,
     SO_RCVTIMEO: int = 20,
     SO_SNDTIMEO: int = 21,
     SO_ERROR: int = 4,
     IPPROTO_IP: int = 0,
     IP_TTL: int = 2,
     IPPROTO_TCP: int = 6,
     TCP_NODELAY: int = 1,
     TCP_KEEPIDLE: int = 4,
     TCP_KEEPINTVL: int = 5,
     TCP_KEEPCNT: int = 6,
     F_GETFL: int = 3,
     F_SETFL: int = 4,
     O_NONBLOCK: int = 2048,
     EINPROGRESS: int = 115,
     EAGAIN: int = 11,
     EWOULDBLOCK: int = 11;
# ── Socket types ──────────────────────────────────────────────────────────────

# ── Shutdown modes ────────────────────────────────────────────────────────────

# ── Socket options ────────────────────────────────────────────────────────────

# ── IP-level options ──────────────────────────────────────────────────────────

# ── TCP-level options ─────────────────────────────────────────────────────────

# ── fcntl / non-blocking I/O ─────────────────────────────────────────────────

# ── errno values for non-blocking I/O ────────────────────────────────────────
