impl ctx_new_verifying -> int {
    ctx = SSL_CTX_new(TLS_client_method());
    if ctx == 0 {
        return 0;
    }
    SSL_CTX_set_verify(ctx, i32(_SSL_VERIFY_PEER), 0);
    return ctx;
}

impl ctx_load_ca_file(ctx: int, cafile: str) -> int {
    return SSL_CTX_load_verify_locations(ctx, cafile, 0);
}

impl ctx_load_default_ca(ctx: int) -> int {
    return SSL_CTX_set_default_verify_paths(ctx);
}

impl ctx_free(ctx: int) {
    if ctx != 0 {
        SSL_CTX_free(ctx);
    }
}

impl ssl_new_client(ctx: int, fd: int, hostname: str, check_hostname: bool) -> int {
    ssl = SSL_new(ctx);
    if ssl == 0 {
        return 0;
    }
    SSL_set_fd(ssl, i32(fd));

    SSL_ctrl(
        ssl,
        i32(_SSL_CTRL_SET_TLSEXT_HOSTNAME),
        i64(_TLSEXT_NAMETYPE_host_name),
        hostname
    );
    if check_hostname {
        SSL_set1_host(ssl, hostname);
    }
    return ssl;
}

impl do_handshake(ssl: int) -> int {
    return SSL_connect(ssl);
}

impl verify_result(ssl: int) -> int {
    return SSL_get_verify_result(ssl);
}

impl verify_message(code: int) -> str {
    return X509_verify_cert_error_string(i64(code));
}

impl last_error -> str {
    e = ERR_get_error();
    if e == 0 {
        return "unknown error";
    }
    return ERR_reason_error_string(e);
}

impl ssl_write_all(ssl: int, data: bytes) -> int {
    total = len(data);
    off = 0;
    while off < total {
        chunk = data[off:total];
        n = SSL_write(ssl, chunk, i32(len(chunk)));
        if n <= 0 {
            return -1;
        }
        off += n;
    }
    return total;
}

impl ssl_read(ssl: int, bufsize: int) -> bytes {
    if bufsize <= 0 {
        return b"";
    }
    buf = b"\x00" * bufsize;
    got = SSL_read(ssl, buf, i32(bufsize));
    if got > 0 {
        return buf[0:got];
    }
    err = SSL_get_error(ssl, got);
    if err == _SSL_ERROR_ZERO_RETURN {
        return b"";
    }
    if err == _SSL_ERROR_SSL {
        reason = int(ERR_peek_error()) & _ERR_REASON_MASK;
        if reason != _SSL_R_UNEXPECTED_EOF_WHILE_READING {
            raise OSError("TLS read failed: " + last_error());
        }
    }
    return b"";
}

impl ssl_close(ssl: int) {
    if ssl != 0 {
        SSL_shutdown(ssl);
        SSL_free(ssl);
    }
}
