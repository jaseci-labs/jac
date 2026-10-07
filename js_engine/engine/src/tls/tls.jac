"""TLS/SSL context and socket wrapping for js_engine.

Implements a blocking synchronous TLS layer on top of:
  - POSIX socket()/connect()  — from ffi/libc.na.jac
  - OpenSSL libssl             — from ffi/libssl.na.jac

Architecture
------------
  TLSConfig   — user-supplied parameters (CA, cert, key, SNI, verify mode)
  TLSContext  — holds an SSL_CTX* (owns the cert/key/CA configuration)
  TLSSocket   — holds an SSL* + raw OS fd; all I/O goes through OpenSSL

Public API
----------
  tls_create_client_context(cfg)     -> TLSContext
  tls_create_server_context(cfg)     -> TLSContext
  tls_context_free(ctx)              -> None

  tls_wrap_fd(fd, ctx, server_side)  -> TLSSocket
  tls_connect(host, port, cfg)       -> TLSSocket  (DNS + connect + handshake)
  tls_handshake(sock)                -> bool
  tls_read(sock, n)                  -> str
  tls_write(sock, data)              -> int
  tls_close(sock)                    -> None

  tls_last_error(sock)               -> str        (human-readable error string)
"""

import from engine.src.ffi.libssl {
    TLS_client_method,
    TLS_server_method,
    SSL_CTX_new,
    SSL_CTX_free,
    SSL_CTX_set_verify,
    SSL_CTX_set_default_verify_paths,
    SSL_CTX_load_verify_locations,
    SSL_CTX_use_certificate_file,
    SSL_CTX_use_PrivateKey_file,
    SSL_CTX_use_certificate,
    SSL_CTX_use_PrivateKey,
    SSL_CTX_check_private_key,
    SSL_CTX_set_options,
    SSL_new,
    SSL_free,
    SSL_set_fd,
    SSL_ctrl,
    SSL_connect,
    SSL_accept,
    SSL_do_handshake,
    SSL_read,
    SSL_write,
    SSL_shutdown,
    SSL_get_error,
    SSL_CTX_set_alpn_protos,
    SSL_get0_alpn_selected,
    SSL_CTX_set_alpn_select_cb,
    SSL_select_next_proto,
    SSL_get_verify_result
}
import from engine.src.ffi.libc {
    calloc,
    getaddrinfo,
    freeaddrinfo,
    socket,
    connect,
    close,
    get_errno
}
import from engine.src.ffi.libcrypto {
    BIO_s_mem,
    BIO_new,
    BIO_free,
    BIO_write,
    PEM_read_bio_X509,
    PEM_read_bio_PrivateKey,
    X509_free,
    EVP_PKEY_free,
    ERR_get_error
}
import from engine.src.runtime.syscall { is_c_error }
import from engine.src.runtime.mem {
    read_i32,
    read_u32,
    read_ptr,
    read_byte,
    write_byte,
    write_i32,
    write_i64,
    byte_chr
}
import from engine.src.runtime.jsstring { str_substr }
import from engine.src.net.constants { AF_INET, AF_INET6, SOCK_STREAM }

# ── Constants ─────────────────────────────────────────────────────────────────

# SSL_CTX_set_verify modes
glob:pub SSL_VERIFY_NONE: int = 0,
     SSL_VERIFY_PEER: int = 1,
     SSL_VERIFY_FAIL_IF_NO_PEER_CERT: int = 2,
     SSL_FILETYPE_PEM: int = 1,
     SSL_FILETYPE_ASN1: int = 2,
     SSL_CTRL_SET_TLSEXT_HOSTNAME: int = 55,
     TLSEXT_NAMETYPE_host_name: int = 0,
     CRLF: str = chr(13) + "\n",
     X509_V_OK: int = 0,
     SSL_ERROR_NONE: int = 0,
     SSL_ERROR_SSL: int = 1,
     SSL_ERROR_WANT_READ: int = 2,
     SSL_ERROR_WANT_WRITE: int = 3,
     SSL_ERROR_SYSCALL: int = 5,
     SSL_ERROR_ZERO_RETURN: int = 6,
     SSL_OP_NO_SSLv2: int = 16777216,
     SSL_OP_NO_SSLv3: int = 33554432,
     SSL_OP_NO_TLSv1: int = 67108864,
     SSL_OP_NO_TLSv1_1: int = 268435456;

# SSL_CTX_use_certificate_file / use_PrivateKey_file type

# SSL_ctrl command for SNI hostname

# HTTP CRLF — workaround for \r being 2 chars in Jac native (see issues/backslash-r-escape/)

# X509 verification result

# SSL_get_error return codes

# SSL_CTX_set_options flags
# 0x01000000
# 0x02000000
# 0x04000000
# 0x10000000
# struct addrinfo offsets (x86-64 Linux)
glob:priv _AI_FAMILY: int = 4,
     _AI_ADDRLEN: int = 16,
     _AI_ADDR: int = 24,
     _AI_NEXT: int = 40;

# ── Data types ────────────────────────────────────────────────────────────────

"""TLS configuration supplied by the caller.

  verify_peer   — whether to verify the server certificate (default True)
  ca_certs      — path to CA bundle file, e.g. "/etc/ssl/certs/ca-certificates.crt"
                  empty string → use OpenSSL's default system CA store
  cert_file     — PEM path to client/server certificate (optional)
  key_file      — PEM path to matching private key (optional)
  server_name   — SNI hostname override; defaults to the connect host when empty
"""
obj:pub TLSConfig {
    has verify_peer: bool = True,
        ca_certs: str = "",
        cert_file: str = "",
        key_file: str = "",
        server_name: str = "";
}

"""Opaque TLS context.  Holds an SSL_CTX* pointer and its mode flag.

Create with tls_create_client_context / tls_create_server_context.
Free with tls_context_free."""
obj:pub TLSContext {
    has ctx_ptr: int = 0,
        is_server: bool = False,
        server_name: str = "",
        verify_peer: bool = True;
}

"""An active TLS-wrapped socket.

  tcp_fd         — the underlying OS file descriptor
  ssl_ptr        — the SSL* object bound to tcp_fd
  context        — back-reference to the TLSContext that created this socket
  handshake_done — True once TLS negotiation is complete
  last_error     — SSL_get_error result from the most recent failed call
"""
obj:pub TLSSocket {
    has tcp_fd: int = 0,
        ssl_ptr: int = 0,
        context: TLSContext = TLSContext(),
        handshake_done: bool = False,
        last_error: int = 0;
}

# ── Context factory functions ─────────────────────────────────────────────────

"""Load a PEM certificate (content string) into an existing SSL_CTX.

Uses a memory BIO so the caller does not need a file on disk.
Returns True on success, False on failure."""
def _ctx_load_cert_pem(ssl_ctx: int, cert_pem: str) -> bool {
    bio: int = BIO_new(BIO_s_mem());
    if bio == 0 {
        return False;
    }
    BIO_write(bio, cert_pem, len(cert_pem));
    x509: int = PEM_read_bio_X509(bio, 0, 0, 0);
    BIO_free(bio);
    if x509 == 0 {
        return False;
    }
    rc: int = SSL_CTX_use_certificate(ssl_ctx, x509);
    X509_free(x509);
    return rc == 1;
}

"""Load a PEM private key (content string) into an existing SSL_CTX.

Uses a memory BIO so the caller does not need a file on disk.
Returns True on success, False on failure."""
def _ctx_load_key_pem(ssl_ctx: int, key_pem: str) -> bool {
    bio: int = BIO_new(BIO_s_mem());
    if bio == 0 {
        return False;
    }
    BIO_write(bio, key_pem, len(key_pem));
    pkey: int = PEM_read_bio_PrivateKey(bio, 0, 0, 0);
    BIO_free(bio);
    if pkey == 0 {
        return False;
    }
    rc: int = SSL_CTX_use_PrivateKey(ssl_ctx, pkey);
    EVP_PKEY_free(pkey);
    return rc == 1;
}

"""Create a TLS client context from the supplied configuration.

Sets up certificate verification, optional CA bundle, optional client cert/key,
and disables SSLv2/v3.  The returned TLSContext is shared across connections
that use the same settings.

Returns a TLSContext with ctx_ptr == 0 on failure."""
def:pub tls_create_client_context(cfg: TLSConfig) -> TLSContext {
    ctx: TLSContext = TLSContext();

    meth: int = TLS_client_method();
    ssl_ctx: int = SSL_CTX_new(meth);
    if ssl_ctx == 0 {
        return ctx;
    }

    # Disable legacy protocol versions
    SSL_CTX_set_options(ssl_ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);

    # Certificate verification
    if cfg.verify_peer {
        SSL_CTX_set_verify(ssl_ctx, SSL_VERIFY_PEER, 0);
        if cfg.ca_certs != "" {
            SSL_CTX_load_verify_locations(ssl_ctx, cfg.ca_certs, 0);
        } else {
            SSL_CTX_set_default_verify_paths(ssl_ctx);
        }
    } else {
        SSL_CTX_set_verify(ssl_ctx, SSL_VERIFY_NONE, 0);
    }

    # Optional client certificate
    if cfg.cert_file != "" {
        if cfg.cert_file[0] == "-" {
            _ctx_load_cert_pem(ssl_ctx, cfg.cert_file);
        } else {
            SSL_CTX_use_certificate_file(ssl_ctx, cfg.cert_file, SSL_FILETYPE_PEM);
        }
    }
    if cfg.key_file != "" {
        if cfg.key_file[0] == "-" {
            _ctx_load_key_pem(ssl_ctx, cfg.key_file);
        } else {
            SSL_CTX_use_PrivateKey_file(ssl_ctx, cfg.key_file, SSL_FILETYPE_PEM);
        }
    }

    ctx.ctx_ptr = ssl_ctx;
    ctx.is_server = False;
    ctx.server_name = cfg.server_name;
    ctx.verify_peer = cfg.verify_peer;
    return ctx;
}

"""Create a TLS server context from the supplied configuration.

cert_file and key_file are required for a server context.

Returns a TLSContext with ctx_ptr == 0 on failure."""
def:pub tls_create_server_context(cfg: TLSConfig) -> TLSContext {
    ctx: TLSContext = TLSContext();

    meth: int = TLS_server_method();
    ssl_ctx: int = SSL_CTX_new(meth);
    if ssl_ctx == 0 {
        return ctx;
    }

    SSL_CTX_set_options(ssl_ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);

    if cfg.verify_peer {
        SSL_CTX_set_verify(
            ssl_ctx, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, 0
        );
        if cfg.ca_certs != "" {
            SSL_CTX_load_verify_locations(ssl_ctx, cfg.ca_certs, 0);
        } else {
            SSL_CTX_set_default_verify_paths(ssl_ctx);
        }
    } else {
        SSL_CTX_set_verify(ssl_ctx, SSL_VERIFY_NONE, 0);
    }

    if cfg.cert_file != "" {
        if cfg.cert_file[0] == "-" {
            _ctx_load_cert_pem(ssl_ctx, cfg.cert_file);
        } else {
            SSL_CTX_use_certificate_file(ssl_ctx, cfg.cert_file, SSL_FILETYPE_PEM);
        }
    }
    if cfg.key_file != "" {
        if cfg.key_file[0] == "-" {
            _ctx_load_key_pem(ssl_ctx, cfg.key_file);
        } else {
            SSL_CTX_use_PrivateKey_file(ssl_ctx, cfg.key_file, SSL_FILETYPE_PEM);
        }
    }

    ctx.ctx_ptr = ssl_ctx;
    ctx.is_server = True;
    ctx.verify_peer = cfg.verify_peer;
    return ctx;
}

"""Free an SSL_CTX and invalidate the TLSContext handle."""
def:pub tls_context_free(ctx: TLSContext) {
    if ctx.ctx_ptr != 0 {
        SSL_CTX_free(ctx.ctx_ptr);
        ctx.ctx_ptr = 0;
    }
}

# ── Socket wrapping ───────────────────────────────────────────────────────────

"""Wrap an already-connected OS file descriptor with TLS.

The caller is responsible for having called connect() on fd before wrapping.
After this call, use tls_handshake() to complete the TLS negotiation.

server_side=True → schedules SSL_accept instead of SSL_connect.

Returns a TLSSocket with ssl_ptr == 0 on failure."""
def:pub tls_wrap_fd(fd: int, ctx: TLSContext, server_side: bool) -> TLSSocket {
    sock: TLSSocket = TLSSocket();
    sock.context = ctx;
    sock.tcp_fd = fd;

    if ctx.ctx_ptr == 0 {
        return sock;
    }

    ssl: int = SSL_new(ctx.ctx_ptr);
    if ssl == 0 {
        return sock;
    }

    r: int = SSL_set_fd(ssl, fd);
    if r != 1 {
        SSL_free(ssl);
        return sock;
    }

    sock.ssl_ptr = ssl;
    return sock;
}

# ── Handshake ─────────────────────────────────────────────────────────────────

"""Perform the TLS handshake on a wrapped socket.

For client sockets (is_server=False) calls SSL_connect; for server sockets
calls SSL_accept.  Also sets the SNI hostname for client connections when
context.server_name is non-empty.

Returns True on success, False on failure.  On failure, sock.last_error
holds the SSL_get_error code."""
def:pub tls_handshake(sock: TLSSocket) -> bool {
    if sock.ssl_ptr == 0 {
        return False;
    }

    # Set SNI hostname for client connections
    if not sock.context.is_server {
        if sock.context.server_name != "" {
            SSL_ctrl(
                sock.ssl_ptr,
                SSL_CTRL_SET_TLSEXT_HOSTNAME,
                TLSEXT_NAMETYPE_host_name,
                sock.context.server_name
            );
        }
    }

    rc: int = 0;
    if sock.context.is_server {
        rc = SSL_accept(sock.ssl_ptr);
    } else {
        rc = SSL_connect(sock.ssl_ptr);
    }

    if rc == 1 {
        # Verify certificate for client sockets with verify_peer enabled
        if not sock.context.is_server {
            if sock.context.verify_peer {
                vr: int = SSL_get_verify_result(sock.ssl_ptr);
                if vr != X509_V_OK {
                    sock.last_error = SSL_ERROR_SSL;
                    return False;
                }
            }
        }
        sock.handshake_done = True;
        return True;
    }

    sock.last_error = SSL_get_error(sock.ssl_ptr, rc);
    return False;
}

"""Non-blocking handshake attempt.

Call on a socket whose fd is set to O_NONBLOCK.  Returns:
  0                     — handshake completed successfully
  SSL_ERROR_WANT_READ   — need to poll fd for readability, then retry
  SSL_ERROR_WANT_WRITE  — need to poll fd for writability, then retry
  other (> 0)           — fatal error, TLS handshake failed
"""
def:pub tls_handshake_nb(sock: TLSSocket) -> int {
    if sock.ssl_ptr == 0 {
        return 0 - 1;
    }

    # Set SNI hostname for client connections (idempotent — safe to call on retry)
    if not sock.context.is_server {
        if sock.context.server_name != "" {
            SSL_ctrl(
                sock.ssl_ptr,
                SSL_CTRL_SET_TLSEXT_HOSTNAME,
                TLSEXT_NAMETYPE_host_name,
                sock.context.server_name
            );
        }
    }

    rc: int = 0;
    if sock.context.is_server {
        rc = SSL_accept(sock.ssl_ptr);
    } else {
        rc = SSL_connect(sock.ssl_ptr);
    }

    if rc == 1 {
        # Verify certificate for client sockets with verify_peer enabled
        if not sock.context.is_server {
            if sock.context.verify_peer {
                vr: int = SSL_get_verify_result(sock.ssl_ptr);
                if vr != X509_V_OK {
                    sock.last_error = SSL_ERROR_SSL;
                    return SSL_ERROR_SSL;
                }
            }
        }
        sock.handshake_done = True;
        return 0;
    }

    err: int = SSL_get_error(sock.ssl_ptr, rc);
    sock.last_error = err;
    return err;
}

# ── I/O ───────────────────────────────────────────────────────────────────────

"""Read up to n bytes from the TLS stream.  Returns the data as a Jac str.

Returns "" on error or connection close.  Check sock.last_error for the
SSL_get_error code; SSL_ERROR_ZERO_RETURN means the peer closed cleanly."""
def:pub tls_read(sock: TLSSocket, n: int) -> str {
    if sock.ssl_ptr == 0 {
        return "";
    }
    buf: int = calloc(1, n + 1);  # +1 for null terminator
    nread: int = SSL_read(sock.ssl_ptr, buf, n);
    # C int -1 zero-extends to 4294967295 in i64
    if nread > 2147483647 {
        sock.last_error = SSL_get_error(sock.ssl_ptr, 0 - 1);
        return "";
    }
    if nread == 0 {
        sock.last_error = SSL_get_error(sock.ssl_ptr, 0);
        return "";
    }
    result: str = buf;  # jac:ignore[E1001] pointer reinterpret
    return result;
}

"""Read up to `n` bytes from the TLS stream into the pre-allocated buffer
`buf` (caller-owned C heap pointer).

Returns the number of bytes actually read, 0 on EOF, or a large value
(> 2^31) on error (mirrors the Jac i64 sign-extension behaviour of
SSL_read returning C int -1)."""
def:pub tls_read_into(sock: TLSSocket, buf: int, n: int) -> int {
    if sock.ssl_ptr == 0 or buf == 0 {
        return 0;
    }
    nread: int = SSL_read(sock.ssl_ptr, buf, n);
    if nread > 2147483647 {
        sock.last_error = SSL_get_error(sock.ssl_ptr, 0 - 1);
        return 0;
    }
    if nread < 0 {
        sock.last_error = SSL_get_error(sock.ssl_ptr, nread);
        return 0;
    }
    return nread;
}

"""Write data to the TLS stream.

Loops until all bytes are written or a fatal/would-block error occurs.
On a non-blocking fd OpenSSL returns SSL_ERROR_WANT_WRITE instead of a
partial count, so the loop handles both cases:
  - blocking fd:    SSL_write may return rc < n; advance the window and retry
  - non-blocking fd: SSL_write returns WANT_WRITE which is propagated up

Returns total bytes written, or -1 on error.
On error, sock.last_error holds the SSL_get_error code."""
def:pub tls_write(sock: TLSSocket, data: str) -> int {
    if sock.ssl_ptr == 0 {
        return 0 - 1;
    }
    n: int = len(data);
    total: int = 0;
    remaining: str = data;

    while total < n {
        rc: int = SSL_write(sock.ssl_ptr, remaining, len(remaining));

        # C int -1 zero-extends to large positive in i64
        if rc > 2147483647 {
            sock.last_error = SSL_get_error(sock.ssl_ptr, 0 - 1);
            return 0 - 1;
        }
        if rc <= 0 {
            sock.last_error = SSL_get_error(sock.ssl_ptr, rc);
            return 0 - 1;
        }

        total = total + rc;
        if total < n {
            # Partial write on a blocking fd — advance the window
            remaining = str_substr(remaining, rc, len(remaining));
        }
    }

    return total;
}

# ── Shutdown ──────────────────────────────────────────────────────────────────

"""Shut down TLS and close the underlying OS fd.

Calls SSL_shutdown twice for bidirectional close_notify exchange
(first call sends close_notify, second waits for peer's close_notify),
then SSL_free, then close(fd)."""
def:pub tls_close(sock: TLSSocket) {
    if sock.ssl_ptr != 0 {
        rc: int = SSL_shutdown(sock.ssl_ptr);
        if rc == 0 {
            # First call sent close_notify; call again to complete
            # bidirectional shutdown (wait for peer's close_notify).
            SSL_shutdown(sock.ssl_ptr);
        }
        SSL_free(sock.ssl_ptr);
        sock.ssl_ptr = 0;
    }
    if sock.tcp_fd > 0 {
        close(sock.tcp_fd);
        sock.tcp_fd = 0;
    }
    sock.handshake_done = False;
}

# ── High-level connect ────────────────────────────────────────────────────────

"""Connect to host:port using TLS.  Does DNS resolution, POSIX connect,
wraps with OpenSSL, and performs the TLS handshake in one call.

port is an integer (e.g. 443).  The SNI hostname defaults to host unless
cfg.server_name is set.

Returns a TLSSocket.  On any failure, sock.ssl_ptr will be 0 and
sock.last_error will be non-zero (negative = C error, positive = SSL error code).

Usage:
    cfg: TLSConfig = TLSConfig();
    sock: TLSSocket = tls_connect("example.com", 443, cfg);
    if sock.ssl_ptr == 0 { ... error ... }
    tls_write(sock, "GET / HTTP/1.0\r\nHost: example.com\r\n\r\n");
    data: str = tls_read(sock, 4096);
"""
def:pub tls_connect(host: str, port: int, cfg: TLSConfig) -> TLSSocket {
    sock: TLSSocket = TLSSocket();

    # ── 1. Resolve host ───────────────────────────────────────────────────────
    port_str: str = _int_to_str(port);
    result_pp: int = calloc(1, 8);
    rc: int = getaddrinfo(host, port_str, 0, result_pp);
    if rc != 0 {
        sock.last_error = -1;
        return sock;
    }

    first: int = read_ptr(result_pp, 0);
    fam: int = read_i32(first, _AI_FAMILY);
    alen: int = read_u32(first, _AI_ADDRLEN);
    addr: int = read_ptr(first, _AI_ADDR);

    # ── 2. Create + connect POSIX socket ─────────────────────────────────────
    fd: int = socket(fam, SOCK_STREAM, 0);
    if is_c_error(fd) {
        freeaddrinfo(first);
        sock.last_error = get_errno();
        return sock;
    }

    rc2: int = connect(fd, addr, alen);
    freeaddrinfo(first);
    if rc2 != 0 {
        close(fd);
        sock.last_error = get_errno();
        return sock;
    }

    # ── 3. Build TLSContext ───────────────────────────────────────────────────
    # Set SNI to host if caller didn't specify
    if cfg.server_name == "" {
        cfg.server_name = host;
    }
    ctx: TLSContext = tls_create_client_context(cfg);
    if ctx.ctx_ptr == 0 {
        close(fd);
        sock.last_error = -2;
        return sock;
    }

    # ── 4. Wrap fd with SSL ───────────────────────────────────────────────────
    sock = tls_wrap_fd(fd, ctx, False);
    if sock.ssl_ptr == 0 {
        tls_context_free(ctx);
        close(fd);
        return sock;
    }

    # ── 5. TLS handshake ──────────────────────────────────────────────────────
    ok: bool = tls_handshake(sock);
    if not ok {
        tls_close(sock);
        return sock;
    }

    return sock;
}

"""Wrap an already-connected TCP fd with TLS and perform the handshake.

The fd MUST be in BLOCKING mode when this is called — SSL_connect expects a
blocking socket for a simple synchronous handshake.  The caller is responsible
for clearing O_NONBLOCK before calling and restoring it afterwards if needed.

Returns a TLSSocket.  On any failure, ssl_ptr == 0 and last_error is set.

Usage (from net_bridge after non-blocking TCP connect completes):
    # fd is connected, currently BLOCKING
    tls_sock: TLSSocket = tls_connect_on_fd(fd, "example.com");
    if tls_sock.ssl_ptr == 0 { ... error ... }
"""
def:pub tls_connect_on_fd(fd: int, host: str) -> TLSSocket {
    sock: TLSSocket = tls_client_wrap_fd(fd, host, True, "");
    if sock.ssl_ptr == 0 {
        return sock;
    }

    ok: bool = tls_handshake(sock);
    if not ok {
        SSL_free(sock.ssl_ptr);
        sock.ssl_ptr = 0;
        return sock;
    }
    return sock;
}

"""Create a client TLS socket wrapping an already-connected fd.

Does context creation + SSL wrap + SNI setup but does NOT perform the
handshake.  Caller is responsible for calling tls_handshake() or
tls_handshake_nb() afterwards.
"""
def:pub tls_client_wrap_fd(
    fd: int, host: str, verify: bool, alpn_csv: str
) -> TLSSocket {
    sock: TLSSocket = TLSSocket();

    cfg: TLSConfig = TLSConfig(
        verify_peer=verify, ca_certs="", cert_file="", key_file="", server_name=host
    );

    ctx: TLSContext = tls_create_client_context(cfg);
    if ctx.ctx_ptr == 0 {
        sock.last_error = 0 - 2;
        return sock;
    }

    # Set client-side ALPN if provided
    if len(alpn_csv) > 0 {
        alpn_list: list[str] = [];
        cur: str = "";
        ci: int = 0;
        while ci < len(alpn_csv) {
            ch: str = alpn_csv[ci];
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
            tls_ctx_set_alpn_protos(ctx, alpn_list);
        }
    }

    sock = tls_wrap_fd(fd, ctx, False);
    if sock.ssl_ptr == 0 {
        tls_context_free(ctx);
        sock.last_error = 0 - 3;
        return sock;
    }

    return sock;
}

# ── Helpers ───────────────────────────────────────────────────────────────────

"""Convert a small positive integer to its decimal string representation."""
def _int_to_str(n: int) -> str {
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
        result = _digit_char(d) + result;
        rem = rem // 10;
    }
    return result;
}

"""Return the ASCII character for a single decimal digit 0..9."""
def _digit_char(d: int) -> str {
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

"""Return a human-readable description of an SSL_ERROR_* code."""
def:pub tls_error_str(code: int) -> str {
    if code == SSL_ERROR_NONE {
        return "SSL_ERROR_NONE";
    }
    if code == SSL_ERROR_SSL {
        return "SSL_ERROR_SSL (protocol error)";
    }
    if code == SSL_ERROR_WANT_READ {
        return "SSL_ERROR_WANT_READ";
    }
    if code == SSL_ERROR_WANT_WRITE {
        return "SSL_ERROR_WANT_WRITE";
    }
    if code == SSL_ERROR_SYSCALL {
        return "SSL_ERROR_SYSCALL";
    }
    if code == SSL_ERROR_ZERO_RETURN {
        return "SSL_ERROR_ZERO_RETURN (peer closed)";
    }
    return "SSL_ERROR_UNKNOWN";
}

# ── ALPN (Application-Layer Protocol Negotiation) ─────────────────────────────

"""Set ALPN protocol list on a client SSL_CTX.

`protocols` is a list of protocol strings, e.g. ["h2", "http/1.1"].
The OpenSSL wire format is length-prefixed: \x02h2\x08http/1.1

Returns 0 on success."""
def:pub tls_ctx_set_alpn_protos(ctx: TLSContext, protocols: list[str]) -> int {
    if ctx.ctx_ptr == 0 {
        return 0 - 1;
    }
    # Calculate total wire-format length
    total: int = 0;
    i: int = 0;
    while i < len(protocols) {
        total = total + 1 + len(protocols[i]);
        i = i + 1;
    }
    if total == 0 {
        return 0;
    }

    # Build wire-format buffer
    buf: int = calloc(1, total + 1);
    offset: int = 0;
    j: int = 0;
    while j < len(protocols) {
        proto: str = protocols[j];
        plen: int = len(proto);
        # Write length byte
        write_byte(buf, offset, plen);
        offset = offset + 1;
        # Write protocol string bytes
        k: int = 0;
        while k < plen {
            write_byte(buf, offset, ord(proto[k]));
            offset = offset + 1;
            k = k + 1;
        }
        j = j + 1;
    }

    rc: int = SSL_CTX_set_alpn_protos(ctx.ctx_ptr, buf, total);
    return rc;
}

"""Build wire-format ALPN buffer from protocol list.

Returns [buf_ptr, total_len] as a two-element list.
buf_ptr is a calloc'd buffer; caller is responsible for its lifetime."""
def:pub tls_alpn_build_wire(protocols: list[str]) -> list[int] {
    total: int = 0;
    i: int = 0;
    while i < len(protocols) {
        total = total + 1 + len(protocols[i]);
        i = i + 1;
    }
    if total == 0 {
        return [0, 0];
    }

    buf: int = calloc(1, total + 1);
    offset: int = 0;
    j: int = 0;
    while j < len(protocols) {
        proto: str = protocols[j];
        plen: int = len(proto);
        write_byte(buf, offset, plen);
        offset = offset + 1;
        k: int = 0;
        while k < plen {
            write_byte(buf, offset, ord(proto[k]));
            offset = offset + 1;
            k = k + 1;
        }
        j = j + 1;
    }
    return [buf, total];
}

"""ALPN server selection callback — passed to SSL_CTX_set_alpn_select_cb.

Signature matches OpenSSL's expected:
  int cb(SSL *ssl, const unsigned char **out, unsigned char *outlen,
         const unsigned char *in, unsigned int inlen, void *arg)

`arg` points to a 16-byte struct: [server_protos_ptr (8 bytes), server_protos_len (4 bytes)].
Uses SSL_select_next_proto to find the first common protocol.

Returns SSL_TLSEXT_ERR_OK (0) on match, SSL_TLSEXT_ERR_ALERT_FATAL (2) if no match."""
def _alpn_select_cb(
    ssl: int,
    out_ptr: int,
    out_len_ptr: int,
    client_protos: int,
    client_len: int,
    arg: int
) -> int {
    server_buf: int = read_ptr(arg, 0);
    server_len: int = read_i32(arg, 8);

    # SSL_select_next_proto(out, outlen, server, server_len, client, client_len)
    # Returns OPENSSL_NPN_NEGOTIATED=1 on match
    rc: int = SSL_select_next_proto(
        out_ptr, out_len_ptr, server_buf, server_len, client_protos, client_len
    );
    if rc == 1 {
        return 0;
    }  # SSL_TLSEXT_ERR_OK
    return 2;  # SSL_TLSEXT_ERR_ALERT_FATAL
}

"""Set up server-side ALPN selection on a TLS context.

`protocols` is a list of server-preferred protocol strings, e.g. ["h2", "http/1.1"].
The callback will select the first match with the client's advertised list.

Returns the arg pointer (must be kept alive as long as the ctx is used)."""
def:pub tls_ctx_set_alpn_select(ctx: TLSContext, protocols: list[str]) -> int {
    wire: list[int] = tls_alpn_build_wire(protocols);
    if wire[0] == 0 {
        return 0;
    }

    # Build arg struct: [ptr (8 bytes), len (4 bytes)] = 16 bytes
    arg: int = calloc(1, 16);
    write_i64(arg, 0, wire[0]);
    write_i32(arg, 8, wire[1]);

    SSL_CTX_set_alpn_select_cb(ctx.ctx_ptr, _alpn_select_cb, arg);
    return arg;
}

"""Retrieve the ALPN-selected protocol from a completed handshake.

Returns the protocol string (e.g. "h2") or "" if ALPN not negotiated."""
def:pub tls_get_alpn_selected(sock: TLSSocket) -> str {
    if sock.ssl_ptr == 0 {
        return "";
    }

    # SSL_get0_alpn_selected(&data, &len) writes to out pointers
    data_out: int = calloc(1, 8);  # pointer to const unsigned char*
    len_out: int = calloc(1, 4);  # pointer to unsigned int
    SSL_get0_alpn_selected(sock.ssl_ptr, data_out, len_out);

    proto_ptr: int = read_ptr(data_out, 0);
    proto_len: int = read_u32(len_out, 0);

    if proto_ptr == 0 or proto_len == 0 {
        return "";
    }

    # Read the protocol string from the pointer
    result: str = "";
    m: int = 0;
    while m < proto_len {
        result = result + byte_chr(read_byte(proto_ptr, m));
        m = m + 1;
    }
    return result;
}

# ── Server-side TLS accept ────────────────────────────────────────────────────

"""Accept a TLS connection on an already-connected TCP fd (server side).

The fd must be a connected client socket (from accept()).  This function:
1. Creates a server TLS context from the supplied config
2. Wraps the fd with SSL
3. Performs the SSL_accept handshake

Returns a TLSSocket.  On failure, ssl_ptr == 0 and last_error is set.

If the TLSConfig includes ALPN protocols, they will be set on the context
before the handshake so the server can negotiate ALPN with the client."""
def:pub tls_accept_on_fd(fd: int, cfg: TLSConfig) -> TLSSocket {
    sock: TLSSocket = TLSSocket();

    ctx: TLSContext = tls_create_server_context(cfg);
    if ctx.ctx_ptr == 0 {
        sock.last_error = 0 - 2;
        return sock;
    }

    sock = tls_wrap_fd(fd, ctx, True);
    if sock.ssl_ptr == 0 {
        tls_context_free(ctx);
        sock.last_error = 0 - 3;
        return sock;
    }

    ok: bool = tls_handshake(sock);
    if not ok {
        SSL_free(sock.ssl_ptr);
        sock.ssl_ptr = 0;
        tls_context_free(ctx);
        return sock;
    }

    return sock;
}

"""Accept a TLS connection using a pre-built, shared TLSContext.

Unlike tls_accept_on_fd, this reuses an existing context (one per server)
instead of creating a new one per connection.  Suitable for high-throughput
servers.

The fd must be a connected client socket (from accept()).

Returns a TLSSocket.  On failure, ssl_ptr == 0 and last_error is set."""
def:pub tls_accept_on_fd_shared_ctx(fd: int, ctx: TLSContext) -> TLSSocket {
    sock: TLSSocket = TLSSocket();

    if ctx.ctx_ptr == 0 {
        sock.last_error = 0 - 2;
        return sock;
    }

    sock = tls_wrap_fd(fd, ctx, True);
    if sock.ssl_ptr == 0 {
        sock.last_error = 0 - 3;
        return sock;
    }

    ok: bool = tls_handshake(sock);
    if not ok {
        SSL_free(sock.ssl_ptr);
        sock.ssl_ptr = 0;
        return sock;
    }

    return sock;
}
