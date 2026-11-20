---
description: The native socket, select, selectors, socketserver and ssl modules - sockets and their addresses, waiting on many at once, servers that hand each request to a handler, and TLS over OpenSSL - with what each has, how they differ from CPython's, and what each platform provides.
keywords: socket, socket.socket, socket.socketpair, socket.create_connection, socket.create_server, socket.getaddrinfo, socket.gethostname, socket.timeout, socket.gaierror, AF_INET, SOCK_STREAM, select.select, select.poll, select.epoll, select.kqueue, selectors, selectors.DefaultSelector, selectors.SelectorKey, EVENT_READ, EVENT_WRITE, socketserver, socketserver.TCPServer, socketserver.UDPServer, socketserver.BaseRequestHandler, socketserver.StreamRequestHandler, ssl, ssl.SSLContext, ssl.create_default_context, ssl.SSLSocket, ssl.SSLObject, ssl.MemoryBIO, ssl.SSLError, TLS, sockets, network
---
# socket, select, selectors, socketserver and ssl

Five native modules are the network's lower layers, each with the names and behavior of CPython
3.15's module of the same name (see [The library](index.md), `jac docs library`):

| Module | What it has |
|---|---|
| `socket` | The `socket` class, `socketpair`, `create_connection`, `create_server`, the name lookups, the address conversions and each system's constants |
| `select` | `select`, `poll`, and the system's own: `epoll` on Linux, `kqueue` and `kevent` on macOS |
| `selectors` | `DefaultSelector` and the selectors it is one of, over `select` |
| `socketserver` | `TCPServer`, `UDPServer`, the Unix, forking and threading servers, and the request handlers |
| `ssl` | TLS over OpenSSL 3: `SSLContext`, `SSLSocket`, `SSLObject`, `MemoryBIO`, the exceptions |

HTTP and HTTPS are a layer above them: see [http](http.md) and [urllib](urllib.md).

```jac
import socket;
import select;
import selectors;

with entry {
    (a, b) = socket.socketpair();
    print(repr(a.family), repr(a.type), a.gettimeout());
    a.sendall(b"ping");
    (ready, _w, _x) = select.select([b], [], [], 1.0);
    print(len(ready), ready[0] is b, b.recv(16));
    sel = selectors.DefaultSelector();
    sel.register(b, selectors.EVENT_READ, "from a");
    print(sel.select(0));
    a.sendall(b"pong");
    for (key, events) in sel.select(1.0) {
        print(key.data, events == selectors.EVENT_READ, key.fileobj.recv(16));
    }
    sel.unregister(b);
    sel.close();
    with a.makefile("w") as out {
        out.write("one\ntwo\n");
    }
    a.shutdown(socket.SHUT_WR);
    with b.makefile("r") as lines {
        print([line.strip() for line in lines]);
    }
    a.settimeout(0.01);
    try {
        a.recv(16);
    } except TimeoutError as e {
        print("TimeoutError:", e);
    }
    a.close();
    b.close();
    print(a.fileno(), socket.inet_aton("127.0.0.1"));
    print(socket.inet_ntop(socket.AF_INET6, bytes(15) + b"\x01"));
}
```

```output
<AddressFamily.AF_UNIX: 1> <SocketKind.SOCK_STREAM: 1> None
1 True b'ping'
[]
from a True b'pong'
['one', 'two']
TimeoutError: timed out
-1 b'\x7f\x00\x00\x01'
::1
```

## socket

| Name | What it is |
|---|---|
| `socket(family=-1, type=-1, proto=-1, fileno=None)` | A socket: `bind`, `listen`, `accept`, `connect`, `connect_ex`, `send`, `sendall`, `sendto`, `sendmsg`, `sendfile`, `recv`, `recv_into`, `recvfrom`, `recvfrom_into`, `recvmsg`, `shutdown`, `close`, `detach`, `dup`, `makefile`, `fileno`, `getsockname`, `getpeername`, `getsockopt`, `setsockopt`, `settimeout`, `gettimeout`, `setblocking`, `getblocking`, `get_inheritable`, `set_inheritable`, `family`, `type`, `proto`, `with` |
| `socketpair`, `create_connection`, `create_server`, `fromfd`, `has_dualstack_ipv6` | Sockets already connected, or listening |
| `getaddrinfo`, `getnameinfo`, `gethostname`, `gethostbyname`, `gethostbyname_ex`, `gethostbyaddr`, `getfqdn`, `getservbyname`, `getservbyport`, `getprotobyname`, `if_nameindex`, `if_nametoindex`, `if_indextoname` | The system's name lookups |
| `inet_aton`, `inet_ntoa`, `inet_pton`, `inet_ntop`, `htons`, `ntohs`, `htonl`, `ntohl` | Address and byte-order conversions |
| `getdefaulttimeout`, `setdefaulttimeout`, `close`, `CMSG_LEN`, `CMSG_SPACE` | As CPython's |
| `AddressFamily`, `SocketKind`, and `AF_*`, `SOCK_*`, `IPPROTO_*`, `SOL_*`, `SO_*`, `TCP_*`, `MSG_*`, `AI_*`, `NI_*`, `EAI_*`, `SHUT_*`, ... | Each system's own constants, the families and kinds as enums. On Linux the addresses of netlink, vsock, `AF_ALG`, packet, CAN, TIPC and RDS sockets are read and written too |
| `error`, `timeout`, `herror`, `gaierror` | `OSError`, `TimeoutError`, and the lookups' errors |

As in CPython:

- A socket is not inherited by child processes, and its `fileno()` is `-1` once it is closed.
- A timeout that passes raises `TimeoutError: timed out`; connecting to a port nothing listens
  on raises `ConnectionRefusedError`.
- Writing to a socket whose peer has gone raises `BrokenPipeError` or `ConnectionResetError`:
  the process is not ended by `SIGPIPE`.
- A call that waits (`connect`, `accept`, the sends and receives, `sendfile`, a wait for a
  timeout) and the name lookups let other threads run meanwhile
  ([threading](threading.md)). A `bytearray` a call reads or writes meanwhile must not be
  resized by another thread.

## select and selectors

`select.select(rlist, wlist, xlist, timeout=None)` takes descriptors, as ints or as objects with
a `fileno()`, and gives back the objects that are ready. `select.poll()` is there on Linux,
macOS and WASI, `select.epoll` on Linux, `select.kqueue` and `select.kevent` on macOS; Windows
has `select` alone, over sockets. Each has its system's constants (`POLLIN`, `EPOLLIN`,
`KQ_FILTER_READ`, ...).

`selectors` picks for the program: `DefaultSelector` is `EpollSelector` on Linux,
`KqueueSelector` on macOS, `PollSelector` on WASI and `SelectSelector` on Windows. A selector
has `register(fileobj, events, data=None)`, `unregister`, `modify`, `select(timeout=None)`,
`get_key`, `get_map`, `close` and `with`; `select` gives a list of `(SelectorKey, events)`, a
key holding `fileobj`, `fd`, `events` and `data`.

## socketserver

A server takes requests on its socket and hands each to a new object of the handler class it
was given. The class derives from `BaseRequestHandler` and overrides `handle`;
`StreamRequestHandler` gives it the connection as the files `rfile` and `wfile`, and
`DatagramRequestHandler` a datagram as the same.

```jac
import socket;
import socketserver;
import threading;

class Upper(socketserver.StreamRequestHandler) {
    override def handle -> None {
        line = self.rfile.readline();
        self.wfile.write(line.upper());
    }
}

with entry {
    with socketserver.TCPServer(("127.0.0.1", 0), Upper) as srv {
        port: int = srv.server_address[1];
        t = threading.Thread(target=srv.handle_request);
        t.start();
        with socket.create_connection(("127.0.0.1", port), timeout=5.0) as c {
            c.sendall(b"hello\n");
            print(c.recv(64), c.getpeername()[0]);
        }
        t.join();
    }
    try {
        socket.create_connection(("127.0.0.1", port), timeout=5.0);
    } except ConnectionRefusedError {
        print("refused");
    }
    with socketserver.ThreadingTCPServer(("127.0.0.1", 0), Upper) as each {
        port = each.server_address[1];
        t = threading.Thread(target=each.serve_forever, args=(0.01,));
        t.start();
        first = socket.create_connection(("127.0.0.1", port), timeout=5.0);
        second = socket.create_connection(("127.0.0.1", port), timeout=5.0);
        second.sendall(b"second\n");
        print(second.recv(64));
        first.sendall(b"first\n");
        print(first.recv(64));
        first.close();
        second.close();
        each.shutdown();
        t.join();
    }
}
```

```output
b'HELLO\n' 127.0.0.1
refused
b'SECOND\n'
b'FIRST\n'
```

A `TCPServer` takes one request at a time. A `ThreadingTCPServer` gives each a thread of its
own ([threading](threading.md)), so the second connection above is answered while the first
is still open and silent.

| Name | What it is |
|---|---|
| `BaseServer`, `TCPServer(server_address, RequestHandlerClass, bind_and_activate=True)`, `UDPServer` | `handle_request` serves one request, waiting at most `timeout`; `serve_forever(poll_interval=0.5)` serves until `shutdown()`; `server_close`, `fileno`, `with`, and the steps a subclass overrides (`verify_request`, `process_request`, `handle_error`, `handle_timeout`, `service_actions`, ...) |
| `UnixStreamServer`, `UnixDatagramServer` | The same over Unix sockets; Linux and macOS |
| `ForkingMixIn`, `ForkingTCPServer`, `ForkingUDPServer`, `ForkingUnixStreamServer`, `ForkingUnixDatagramServer` | Each request in a child process; Linux and macOS |
| `ThreadingMixIn`, `ThreadingTCPServer`, `ThreadingUDPServer`, `ThreadingUnixStreamServer`, `ThreadingUnixDatagramServer` | Each request in a thread of its own (`daemon_threads`, `block_on_close`) |
| `BaseRequestHandler`, `StreamRequestHandler`, `DatagramRequestHandler` | `setup`, `handle`, `finish`, with `request`, `client_address` and `server` |

What CPython's servers and handlers keep as class attributes (`allow_reuse_address`,
`request_queue_size`, `timeout`, `rbufsize`, `wbufsize`, ...) are fields with defaults here: a
subclass declares the field again with its own default
(`has allow_reuse_address: bool = True;`).

## ssl

`ssl` is TLS over OpenSSL 3 on every system: the system's on Linux, linked into the program on
macOS and Windows. A call that waits in it lets other threads run meanwhile, as a socket's
does. An `SSLContext` holds the settings (certificates and keys, verification,
ciphers, ALPN, the SNI and PSK callbacks, sessions); `wrap_socket` makes an `SSLSocket` of a
connected socket, and `wrap_bio` an `SSLObject` that reads and writes TLS records in two
`MemoryBIO`s, for a program that moves the bytes itself:

```jac
import ssl;

with entry {
    ctx = ssl.create_default_context();
    print(repr(ctx.verify_mode), ctx.check_hostname, repr(ctx.minimum_version));
    ctx.set_alpn_protocols(["h2", "http/1.1"]);
    incoming = ssl.MemoryBIO();
    outgoing = ssl.MemoryBIO();
    tls = ctx.wrap_bio(incoming, outgoing, server_hostname="example.org");
    try {
        tls.do_handshake();
    } except ssl.SSLWantReadError {
        hello = outgoing.read();
        print("wants to read; sent a client hello:", hello[:1], len(hello) > 100);
    }
    print(tls.server_hostname, tls.version(), tls.cipher());
    try {
        ctx.load_verify_locations(cadata="not a certificate");
    } except ssl.SSLError as e {
        print(type(e).__name__, isinstance(e, OSError));
    }
    server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);
    print(repr(server.verify_mode), server.check_hostname, ssl.OPENSSL_VERSION_INFO[0]);
}
```

```output
<VerifyMode.CERT_REQUIRED: 2> True <TLSVersion.TLSv1_2: 771>
wants to read; sent a client hello: b'\x16' True
example.org None None
SSLError True
<VerifyMode.CERT_NONE: 0> False 3
```

| Name | What it is |
|---|---|
| `SSLContext(protocol=None)` | `load_cert_chain`, `load_verify_locations`, `load_default_certs`, `set_default_verify_paths`, `set_ciphers`, `get_ciphers`, `set_alpn_protocols`, `set_servername_callback`, `set_psk_client_callback`, `set_psk_server_callback`, `wrap_socket`, `wrap_bio`, `session_stats`, `cert_store_stats`, `get_ca_certs`, and `verify_mode`, `check_hostname`, `minimum_version`, `maximum_version`, `options`, `verify_flags`, `num_tickets`, `keylog_filename`, ... |
| `create_default_context(purpose=Purpose.SERVER_AUTH, *, cafile=None, capath=None, cadata=None)` | A context with the system's CA certificates and CPython's defaults |
| `SSLSocket` | A `socket.socket` that speaks TLS: `do_handshake`, `getpeercert`, `cipher`, `version`, `selected_alpn_protocol`, `unwrap`, `session`, `pending`, ... |
| `SSLObject`, `MemoryBIO` | TLS over memory buffers: the same without a socket |
| `SSLError`, `SSLZeroReturnError`, `SSLWantReadError`, `SSLWantWriteError`, `SSLSyscallError`, `SSLEOFError`, `SSLCertVerificationError` (`CertificateError`) | The exceptions, each an `OSError` |
| `TLSVersion`, `VerifyMode`, `Purpose`, `AlertDescription`, `SSLErrorNumber`, `PROTOCOL_*`, `OP_*`, `VERIFY_*`, `CERT_*`, `HAS_*`, `OPENSSL_VERSION`, ... | The enums and constants |
| `get_default_verify_paths`, `get_server_certificate`, `DER_cert_to_PEM_cert`, `PEM_cert_to_DER_cert`, `cert_time_to_seconds`, `RAND_bytes`, `RAND_status`, `RAND_add` | As CPython's |

## Differences from CPython

- **The flag constants are ints.** Jac has no flag enums, so `socket`'s `MSG_*` and `AI_*` and
  `ssl`'s `OP_*` and `VERIFY_*` are plain ints, which combine with `|` and `&`
  (`ctx.options |= ssl.OP_NO_TICKET`), and `ssl.Options` and `ssl.VerifyFlags` are left out
  (E5142).
- **An enum member read from a socket or a context has no `name` yet.** `sock.family`,
  `sock.type` and the like are an enum member or an int, as CPython's stub types them, and
  `sock.family.name` raises `AttributeError`. Compare it (`sock.family == socket.AF_INET`) or
  print its `repr`.
- **`ThreadingMixIn` and `ForkingMixIn` derive from `BaseServer`**, where CPython's are plain
  mixins. A server of the program's own names the mixin first:
  `class Mine(socketserver.ThreadingMixIn, socketserver.TCPServer) {}`.
- **`ssl.SSLContext.sslsocket_class` and `sslobject_class` are not there** (E1030): a context
  makes `SSLSocket`s and `SSLObject`s.
- **`ssl.PROTOCOL_SSLv2` and `PROTOCOL_SSLv3` are left out** (E5142): OpenSSL 3 makes no such
  connections.
- **`socket.CAPI`, `AddressFamily.AF_ROUTE` and `AddressFamily.AF_BLUETOOTH` are left out**
  (E5142). `socket.AF_ROUTE` is there, as the int it is.

```jac
# expect: E5142
import ssl;

with entry {
    print(ssl.Options.OP_NO_TICKET);
}
```

## Platforms

`socketserver`'s Unix-socket and forking servers and `select.poll` are for Linux and macOS;
`epoll` is Linux's and `kqueue` macOS's. `socketpair()` gives Unix sockets where the system has
them. `ssl` needs OpenSSL 3 where the program runs on
Linux (`libssl.so.3`, `libcrypto.so.3`), and carries it on macOS and Windows.

On WASI (preview 1) a program makes no sockets: it is given them by its host. `socket.socket()`
with no `fileno`, `socketpair`, `bind`, `listen`, `connect`, `sendto`, `recvfrom`,
`getsockname`, `getpeername`, `setsockopt`, `getaddrinfo` and `getnameinfo` raise `OSError`
(`ENOTSUP`, 58), as CPython's WASI build does, and so does every lookup of a host name. There is
no host, service, protocol or interface database: `gethostbyname_ex` and `gethostbyaddr` of an
address raise `herror`, `getservbyname`, `getservbyport`, `getprotobyname` and `if_nameindex`
and its siblings `OSError`. A socket made with `socket.socket(family, type, fileno=fd)` of a
descriptor the host gave can `accept`, `recv`, `send`, `sendall`, `shutdown`,
`getsockopt(SOL_SOCKET, SO_TYPE)`, block or not, and wait with a timeout. `inet_aton`,
`inet_pton`, `inet_ntop` and `gethostname` work as elsewhere. The constants are WASI's:
`AF_INET` is 1, `SOCK_STREAM` 6, and only the options and flags WASI has are there. `select` has
`select` and `poll`, and `ssl` is not available.

## Where to go next

- HTTP clients and servers: [http](http.md), [urllib](urllib.md).
- Mail and file transfer clients: [smtplib, poplib, imaplib and ftplib](mailclients.md).
- An event loop over selectors, with streams and servers that take many connections in one
  thread: [asyncio](asyncio.md).
- Threads, to serve several connections: [threading](threading.md).
- Every native module: [Standard-library modules](stdlib.md).
