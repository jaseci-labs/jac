import from ssl { def TLS_client_method -> int;  }
import from ssl { def SSL_CTX_new(method: int) -> int;  }
import from ssl { def SSL_CTX_set_verify(ctx: int, mode: i32, cb: int) -> None;  }
import from ssl {
    def SSL_CTX_load_verify_locations(ctx: int, cafile: str, capath: int) -> i32;
}
import from ssl { def SSL_CTX_set_default_verify_paths(ctx: int) -> i32;  }
import from ssl { def SSL_CTX_free(ctx: int) -> None;  }
import from ssl { def SSL_new(ctx: int) -> int;  }
import from ssl { def SSL_set_fd(ssl: int, fd: i32) -> i32;  }
import from ssl { def SSL_ctrl(ssl: int, cmd: i32, larg: i64, parg: str) -> i64;  }
import from ssl { def SSL_set1_host(ssl: int, hostname: str) -> i32;  }
import from ssl { def SSL_connect(ssl: int) -> i32;  }
import from ssl { def SSL_get_verify_result(ssl: int) -> i64;  }
import from ssl { def SSL_get_error(ssl: int, ret: i32) -> i32;  }
import from ssl { def SSL_read(ssl: int, buf: bytes, num: i32) -> i32;  }
import from ssl { def SSL_write(ssl: int, buf: bytes, num: i32) -> i32;  }
import from ssl { def SSL_shutdown(ssl: int) -> i32;  }
import from ssl { def SSL_free(ssl: int) -> None;  }

import from crypto { def X509_verify_cert_error_string(n: i64) -> str;  }
import from crypto { def ERR_get_error -> u64;  }
import from crypto { def ERR_peek_error -> u64;  }
import from crypto { def ERR_reason_error_string(e: u64) -> str;  }

glob _SSL_CTRL_SET_TLSEXT_HOSTNAME: int = 55,
     _TLSEXT_NAMETYPE_host_name: int = 0;

glob _SSL_VERIFY_PEER: int = 1;

glob _SSL_ERROR_ZERO_RETURN: int = 6,
     _SSL_ERROR_SSL: int = 1;

glob _ERR_REASON_MASK: int = 8388607,
     _SSL_R_UNEXPECTED_EOF_WHILE_READING: int = 294;


def:pub ctx_new_verifying -> int {
    ctx = SSL_CTX_new(TLS_client_method());
    if ctx == 0 {
        return 0;
    }
    SSL_CTX_set_verify(ctx, _SSL_VERIFY_PEER, 0);
    return ctx;
}


def:pub ctx_load_ca_file(ctx: int, cafile: str) -> int {
    return SSL_CTX_load_verify_locations(ctx, cafile, 0);
}


def:pub ctx_load_default_ca(ctx: int) -> int {
    return SSL_CTX_set_default_verify_paths(ctx);
}


def:pub ctx_free(ctx: int) {
    if ctx != 0 {
        SSL_CTX_free(ctx);
    }
}


def:pub ssl_new_client(ctx: int, fd: int, hostname: str, check_hostname: bool) -> int {
    ssl = SSL_new(ctx);
    if ssl == 0 {
        return 0;
    }
    SSL_set_fd(ssl, fd);

    SSL_ctrl(ssl, _SSL_CTRL_SET_TLSEXT_HOSTNAME, _TLSEXT_NAMETYPE_host_name, hostname);
    if check_hostname {
        SSL_set1_host(ssl, hostname);
    }
    return ssl;
}


def:pub do_handshake(ssl: int) -> int {
    return SSL_connect(ssl);
}


def:pub verify_result(ssl: int) -> int {
    return SSL_get_verify_result(ssl);
}


def:pub verify_message(code: int) -> str {
    return X509_verify_cert_error_string(code);
}


def:pub last_error -> str {
    e = ERR_get_error();
    if e == 0 {
        return "unknown error";
    }
    return ERR_reason_error_string(e);
}


def:pub ssl_write_all(ssl: int, data: bytes) -> int {
    total = len(data);
    off = 0;
    while off < total {
        chunk = data[off:total];
        n = SSL_write(ssl, chunk, len(chunk));
        if n <= 0 {
            return -1;
        }
        off += n;
    }
    return total;
}


def:pub ssl_read(ssl: int, bufsize: int) -> bytes {
    if bufsize <= 0 {
        return b"";
    }
    buf = b"\x00" * bufsize;
    got = SSL_read(ssl, buf, bufsize);
    if got > 0 {
        return buf[0:got];
    }
    err = SSL_get_error(ssl, got);
    if err == _SSL_ERROR_ZERO_RETURN {
        return b"";
    }
    if err == _SSL_ERROR_SSL {
        reason = ERR_peek_error() & _ERR_REASON_MASK;
        if reason != _SSL_R_UNEXPECTED_EOF_WHILE_READING {
            raise OSError("TLS read failed: " + last_error());
        }
    }
    return b"";
}


def:pub ssl_close(ssl: int) {
    if ssl != 0 {
        SSL_shutdown(ssl);
        SSL_free(ssl);
    }
}
