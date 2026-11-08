import fcntl;
import select;
import time;


impl SSLSocket.fileno -> int {
    return self._sock.fileno();
}

impl SSLSocket.sendall(data: bytes) {
    timeout = self._sock.gettimeout();
    if timeout is not None {
        (_readable, writable, _exceptional) = select.select(
            [], [self.fileno()], [], timeout
        );
        if self.fileno() not in writable {
            raise TimeoutError("TLS write timed out");
        }
    }
    if ssl_write_all(self._ssl, data) < 0 {
        raise SSLError("TLS write failed: " + last_error());
    }
}

impl SSLSocket.send(data: bytes) -> int {
    timeout = self._sock.gettimeout();
    if timeout is not None {
        (_readable, writable, _exceptional) = select.select(
            [], [self.fileno()], [], timeout
        );
        if self.fileno() not in writable {
            raise TimeoutError("TLS write timed out");
        }
    }
    n = ssl_write_all(self._ssl, data);
    if n < 0 {
        raise SSLError("TLS write failed: " + last_error());
    }
    return n;
}

impl SSLSocket.recv(bufsize: int) -> bytes {
    timeout = self._sock.gettimeout();
    if timeout is not None and ssl_pending(self._ssl) <= 0 {
        (readable, _writable, _exceptional) = select.select(
            [self.fileno()], [], [], timeout
        );
        if self.fileno() not in readable {
            raise TimeoutError("TLS read timed out");
        }
    }
    try {
        return ssl_read(self._ssl, bufsize);
    } except OSError as e {
        raise SSLError("TLS read error");
    }
}


impl SSLSocket.settimeout(timeout: (float | None)) -> None {
    self._sock.settimeout(timeout);
}


impl SSLSocket.gettimeout -> (float | None) {
    return self._sock.gettimeout();
}

impl SSLSocket.close {
    if self._ssl != 0 {
        ssl_close(self._ssl);
        ctx_free(self._ctx);
        self._ssl = 0;
        self._ctx = 0;
    }
    self._sock.close();
}

impl SSLContext.load_verify_locations(cafile: str) {
    self._cafile = cafile;
}

impl SSLContext.wrap_socket(sock: Socket, server_hostname: str) -> SSLSocket {
    ctx = ctx_new_verifying();
    if ctx == 0 {
        sock.close();
        raise SSLError("SSL_CTX_new failed");
    }
    loaded = 0;
    if len(self._cafile) > 0 {
        loaded = ctx_load_ca_file(ctx, self._cafile);
    } else {
        loaded = ctx_load_default_ca(ctx);
    }
    if loaded != 1 {
        ctx_free(ctx);
        sock.close();
        raise SSLError("could not load the CA trust store");
    }
    ssl = ssl_new_client(ctx, sock.fileno(), server_hostname, self.check_hostname);
    if ssl == 0 {
        ctx_free(ctx);
        sock.close();
        raise SSLError("SSL_new failed");
    }
    hs = 0;
    handshake_timeout = sock.gettimeout();
    if handshake_timeout is None {
        hs = do_handshake(ssl);
    } else {
        flags = fcntl.fcntl(sock.fileno(), fcntl.F_GETFL);
        fcntl.fcntl(sock.fileno(), fcntl.F_SETFL, flags | fcntl.O_NONBLOCK);
        timed_out = False;
        try {
            deadline = time.monotonic() + handshake_timeout;
            while True {
                rc = do_handshake(ssl);
                if rc == 1 {
                    hs = 1;
                    break;
                }
                serr = ssl_get_error(ssl, rc);
                if serr != _SSL_ERROR_WANT_READ and serr != _SSL_ERROR_WANT_WRITE {
                    break;
                }
                remain = deadline - time.monotonic();
                if remain <= 0.0 {
                    timed_out = True;
                    break;
                }
                if serr == _SSL_ERROR_WANT_READ {
                    (readable, _writable, _exceptional) = select.select(
                        [sock.fileno()], [], [], remain
                    );
                    if sock.fileno() not in readable {
                        timed_out = True;
                        break;
                    }
                } else {
                    (_readable, writable, _exceptional) = select.select(
                        [], [sock.fileno()], [], remain
                    );
                    if sock.fileno() not in writable {
                        timed_out = True;
                        break;
                    }
                }
            }
        } finally {
            fcntl.fcntl(sock.fileno(), fcntl.F_SETFL, flags);
        }
        if timed_out {
            ssl_close(ssl);
            ctx_free(ctx);
            sock.close();
            raise TimeoutError("TLS handshake timed out");
        }
    }
    if hs != 1 {
        vr = verify_result(ssl);
        msg = "";
        if vr != 0 {
            msg = "certificate verify failed: "
                + verify_message(vr)
                + " (host '"
                + server_hostname
                + "')";
        } else {
            msg = "TLS handshake failed: " + last_error();
        }
        ssl_close(ssl);
        ctx_free(ctx);
        sock.close();
        raise SSLError(msg);
    }
    return SSLSocket(_ssl=ssl, _ctx=ctx, _sock=sock);
}

impl create_default_context(cafile: str | None = None) -> SSLContext {
    c = SSLContext();
    if cafile is not None {
        if len(cafile) > 0 {
            c.load_verify_locations(cafile);
        }
    }
    return c;
}
