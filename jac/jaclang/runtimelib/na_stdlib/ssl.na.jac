import from socket { socket as Socket }
import from _ssl_native {
    ctx_new_verifying,
    ctx_load_ca_file,
    ctx_load_default_ca,
    ctx_free,
    ssl_new_client,
    do_handshake,
    verify_result,
    verify_message,
    last_error,
    ssl_write_all,
    ssl_read,
    ssl_close
}


obj:pub SSLError(Exception) {}


obj:pub SSLSocket {
    has _ssl: int,
        _ctx: int,
        _sock: Socket;

    def fileno -> int {
        return self._sock.fileno();
    }

    def sendall(data: bytes) {
        if ssl_write_all(self._ssl, data) < 0 {
            raise SSLError("TLS write failed: " + last_error());
        }
    }

    def send(data: bytes) -> int {
        n = ssl_write_all(self._ssl, data);
        if n < 0 {
            raise SSLError("TLS write failed: " + last_error());
        }
        return n;
    }

    def recv(bufsize: int) -> bytes {
        try {
            return ssl_read(self._ssl, bufsize);
        } except OSError as e {
            raise SSLError("TLS read error");
        }
    }

    def close {
        if self._ssl != 0 {
            ssl_close(self._ssl);
            ctx_free(self._ctx);
            self._ssl = 0;
            self._ctx = 0;
        }
        self._sock.close();
    }
}


obj:pub SSLContext {
    has check_hostname: bool = True,
        _cafile: str = "";

    def load_verify_locations(cafile: str) {
        self._cafile = cafile;
    }

    def wrap_socket(sock: Socket, server_hostname: str) -> SSLSocket {
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
        if do_handshake(ssl) != 1 {
            vr = verify_result(ssl);
            msg = "";
            if vr != 0 {
                msg = "certificate verify failed: " + verify_message(vr) + " (host '" + server_hostname + "')";
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
}


def:pub create_default_context(cafile: str | None = None) -> SSLContext {
    c = SSLContext();
    if cafile is not None {
        if len(cafile) > 0 {
            c.load_verify_locations(cafile);
        }
    }
    return c;
}
