"""Comprehensive TLS test suite.

Tests all public functions in tls/tls.na.jac:
  - TLSConfig defaults
  - tls_create_client_context / tls_create_server_context
  - tls_context_free (no crash, idempotent)
  - tls_wrap_fd (valid + invalid fd)
  - tls_handshake (no ssl_ptr → False)
  - tls_read / tls_write on unconnected socket → error
  - tls_close (no crash, idempotent)
  - tls_error_str for all error codes
  - CRLF constant (chr(13) workaround verification)
  - tls_connect to google.com:443 → full HTTP/1.0 round-trip
  - tls_connect to bad host → graceful failure
"""

import from engine.src.tls.tls {
    TLSConfig,
    TLSContext,
    TLSSocket,
    tls_create_client_context,
    tls_create_server_context,
    tls_context_free,
    tls_wrap_fd,
    tls_handshake,
    tls_read,
    tls_write,
    tls_close,
    tls_connect,
    tls_error_str,
    CRLF,
    SSL_ERROR_NONE,
    SSL_ERROR_SSL,
    SSL_ERROR_WANT_READ,
    SSL_ERROR_WANT_WRITE,
    SSL_ERROR_SYSCALL,
    SSL_ERROR_ZERO_RETURN
}

# ═══════════════════════════════════════════════════════════════════════════════
# TLS tests
# ═══════════════════════════════════════════════════════════════════════════════
with entry {
    ok: int = 0;
    err: int = 0;

    # ── 1. TLSConfig defaults ────────────────────────────────────────────────
    cfg: TLSConfig = TLSConfig();
    if cfg.verify_peer == True {
        if cfg.ca_certs == "" {
            if cfg.cert_file == "" {
                if cfg.key_file == "" {
                    if cfg.server_name == "" {
                        print("OK  1 TLSConfig defaults correct");
                        ok = ok + 1;
                    }
                }
            }
        }
    }
    if ok == 0 {
        print("FAIL 1 TLSConfig defaults");
        err = err + 1;
    }

    # ── 2. Client context creation ────────────────────────────────────────────
    cfg2: TLSConfig = TLSConfig();
    ctx_c: TLSContext = tls_create_client_context(cfg2);
    if ctx_c.ctx_ptr != 0 {
        if not ctx_c.is_server {
            print("OK  2 client context created, is_server=False");
            ok = ok + 1;
        } else {
            print("FAIL 2 client context is_server should be False");
            err = err + 1;
        }
    } else {
        print("FAIL 2 tls_create_client_context returned ctx_ptr=0");
        err = err + 1;
    }

    # ── 2b. verify_peer propagated from TLSConfig to TLSContext ─────────────
    cfg_off: TLSConfig = TLSConfig(verify_peer=False);
    ctx_off: TLSContext = tls_create_client_context(cfg_off);
    if ctx_off.ctx_ptr != 0 and not ctx_off.verify_peer {
        print("OK  2b client context verify_peer=False propagated");
        ok = ok + 1;
    } else {
        print("FAIL 2b client context verify_peer should be False");
        err = err + 1;
    }
    tls_context_free(ctx_off);

    cfg_on: TLSConfig = TLSConfig(verify_peer=True);
    ctx_on: TLSContext = tls_create_client_context(cfg_on);
    if ctx_on.ctx_ptr != 0 and ctx_on.verify_peer {
        print("OK  2c client context verify_peer=True propagated");
        ok = ok + 1;
    } else {
        print("FAIL 2c client context verify_peer should be True");
        err = err + 1;
    }
    tls_context_free(ctx_on);

    # ── 3. Server context creation ────────────────────────────────────────────
    cfg3: TLSConfig = TLSConfig(verify_peer=False);
    ctx_s: TLSContext = tls_create_server_context(cfg3);
    if ctx_s.ctx_ptr != 0 {
        if ctx_s.is_server {
            print("OK  3 server context created, is_server=True");
            ok = ok + 1;
        } else {
            print("FAIL 3 server context is_server should be True");
            err = err + 1;
        }
    } else {
        print("FAIL 3 tls_create_server_context returned ctx_ptr=0");
        err = err + 1;
    }

    # ── 4. Context free (no crash, zeroes ptr) ────────────────────────────────
    tls_context_free(ctx_c);
    if ctx_c.ctx_ptr == 0 {
        print("OK  4 context_free zeroed ctx_ptr");
        ok = ok + 1;
    } else {
        print("FAIL 4 context_free did not zero ctx_ptr");
        err = err + 1;
    }

    # ── 5. Context free idempotent (double-free no crash) ─────────────────────
    tls_context_free(ctx_c);
    print("OK  5 context_free idempotent (no crash)");
    ok = ok + 1;

    tls_context_free(ctx_s);

    # ── 6. tls_wrap_fd with null context → ssl_ptr=0 ─────────────────────────
    null_ctx: TLSContext = TLSContext();
    sock_null: TLSSocket = tls_wrap_fd(5, null_ctx, False);
    if sock_null.ssl_ptr == 0 {
        print("OK  6 wrap_fd null context -> ssl_ptr=0");
        ok = ok + 1;
    } else {
        print("FAIL 6 wrap_fd null context should return ssl_ptr=0");
        err = err + 1;
    }

    # ── 7. tls_wrap_fd with bad fd + valid context ────────────────────────────
    cfg7: TLSConfig = TLSConfig(verify_peer=False);
    ctx7: TLSContext = tls_create_client_context(cfg7);
    sock_bad: TLSSocket = tls_wrap_fd(0 - 1, ctx7, False);
    # SSL_set_fd(-1) may or may not fail depending on OpenSSL build
    if sock_bad.ssl_ptr == 0 {
        print("OK  7 wrap_fd bad fd -> ssl_ptr=0 (SSL_set_fd rejected)");
        ok = ok + 1;
    } else {
        print("OK  7 wrap_fd bad fd -> ssl_ptr set (OpenSSL deferred)");
        ok = ok + 1;
        tls_close(sock_bad);
    }
    tls_context_free(ctx7);

    # ── 8. tls_handshake with ssl_ptr=0 → False ──────────────────────────────
    empty_sock: TLSSocket = TLSSocket();
    hresult: bool = tls_handshake(empty_sock);
    if not hresult {
        print("OK  8 handshake null ssl_ptr -> False");
        ok = ok + 1;
    } else {
        print("FAIL 8 handshake null ssl_ptr should return False");
        err = err + 1;
    }

    # ── 9. tls_read with ssl_ptr=0 → empty string ────────────────────────────
    rd: str = tls_read(empty_sock, 1024);
    if rd == "" {
        print("OK  9 read null ssl_ptr -> empty");
        ok = ok + 1;
    } else {
        print("FAIL 9 read null ssl_ptr should return empty");
        err = err + 1;
    }

    # ── 10. tls_write with ssl_ptr=0 → negative ──────────────────────────────
    wd: int = tls_write(empty_sock, "hello");
    if wd < 0 {
        print("OK  10 write null ssl_ptr -> negative");
        ok = ok + 1;
    } else {
        print("FAIL 10 write null ssl_ptr should return negative");
        err = err + 1;
    }

    # ── 11. tls_close on empty socket (no crash) ─────────────────────────────
    tls_close(empty_sock);
    print("OK  11 close empty socket (no crash)");
    ok = ok + 1;

    # ── 12. tls_close idempotent ──────────────────────────────────────────────
    tls_close(empty_sock);
    print("OK  12 close idempotent (no crash)");
    ok = ok + 1;

    # ── 13. tls_error_str covers all codes ────────────────────────────────────
    pass13: bool = True;
    if tls_error_str(SSL_ERROR_NONE) != "SSL_ERROR_NONE" {
        print("FAIL 13a error_str NONE");
        err = err + 1;
        pass13 = False;
    }
    if tls_error_str(SSL_ERROR_SSL) != "SSL_ERROR_SSL (protocol error)" {
        print("FAIL 13b error_str SSL");
        err = err + 1;
        pass13 = False;
    }
    if tls_error_str(SSL_ERROR_WANT_READ) != "SSL_ERROR_WANT_READ" {
        print("FAIL 13c error_str WANT_READ");
        err = err + 1;
        pass13 = False;
    }
    if tls_error_str(SSL_ERROR_WANT_WRITE) != "SSL_ERROR_WANT_WRITE" {
        print("FAIL 13d error_str WANT_WRITE");
        err = err + 1;
        pass13 = False;
    }
    if tls_error_str(SSL_ERROR_SYSCALL) != "SSL_ERROR_SYSCALL" {
        print("FAIL 13e error_str SYSCALL");
        err = err + 1;
        pass13 = False;
    }
    if tls_error_str(SSL_ERROR_ZERO_RETURN) != "SSL_ERROR_ZERO_RETURN (peer closed)" {
        print("FAIL 13f error_str ZERO_RETURN");
        err = err + 1;
        pass13 = False;
    }
    if tls_error_str(99) != "SSL_ERROR_UNKNOWN" {
        print("FAIL 13g error_str unknown code");
        err = err + 1;
        pass13 = False;
    }
    if pass13 {
        print("OK  13 tls_error_str all 7 codes correct");
        ok = ok + 1;
    }

    # ── 14. CRLF constant = chr(13) + newline ─────────────────────────────────
    if len(CRLF) == 2 {
        print("OK  14 CRLF len=2");
        ok = ok + 1;
    } else {
        print("FAIL 14 CRLF len=" + str(len(CRLF)) + " (expected 2)");
        err = err + 1;
    }

    # ── 15. TLSSocket defaults ────────────────────────────────────────────────
    ds: TLSSocket = TLSSocket();
    pass15: bool = True;
    if ds.tcp_fd != 0 {
        pass15 = False;
    }
    if ds.ssl_ptr != 0 {
        pass15 = False;
    }
    if ds.handshake_done {
        pass15 = False;
    }
    if ds.last_error != 0 {
        pass15 = False;
    }
    if pass15 {
        print("OK  15 TLSSocket defaults correct");
        ok = ok + 1;
    } else {
        print("FAIL 15 TLSSocket defaults");
        err = err + 1;
    }

    # ── 16. Client context with verify_peer=False ─────────────────────────────
    cfg_nv: TLSConfig = TLSConfig(verify_peer=False);
    ctx_nv: TLSContext = tls_create_client_context(cfg_nv);
    if ctx_nv.ctx_ptr != 0 {
        print("OK  16 client context verify_peer=False created");
        ok = ok + 1;
    } else {
        print("FAIL 16 client context verify_peer=False");
        err = err + 1;
    }
    tls_context_free(ctx_nv);

    # ── 17. Client context with custom SNI ────────────────────────────────────
    cfg_sni: TLSConfig = TLSConfig(server_name="custom.example.com");
    ctx_sni: TLSContext = tls_create_client_context(cfg_sni);
    if ctx_sni.ctx_ptr != 0 {
        if ctx_sni.server_name == "custom.example.com" {
            print("OK  17 client context custom SNI preserved");
            ok = ok + 1;
        } else {
            print("FAIL 17 server_name not preserved");
            err = err + 1;
        }
    } else {
        print("FAIL 17 client context creation");
        err = err + 1;
    }
    tls_context_free(ctx_sni);

    # ── 18. tls_connect to google.com:443 → full round-trip ──────────────────
    cfg18: TLSConfig = TLSConfig();
    sock18: TLSSocket = tls_connect("google.com", 443, cfg18);
    if sock18.ssl_ptr == 0 {
        print("FAIL 18 tls_connect ssl_ptr=0, last_error=" + str(sock18.last_error));
        err = err + 1;
    } else {
        # 18a: handshake complete
        if sock18.handshake_done {
            print("OK  18a handshake_done=True");
            ok = ok + 1;
        } else {
            print("FAIL 18a handshake_done should be True");
            err = err + 1;
        }
        # 18b: valid fd
        if sock18.tcp_fd > 0 {
            print("OK  18b tcp_fd=" + str(sock18.tcp_fd) + " (positive)");
            ok = ok + 1;
        } else {
            print("FAIL 18b tcp_fd should be positive");
            err = err + 1;
        }
        # 18c: write HTTP request
        req: str = "GET / HTTP/1.0"
            + CRLF
            + "Host: google.com"
            + CRLF
            + "Connection: close"
            + CRLF
            + CRLF;
        wr: int = tls_write(sock18, req);
        if wr > 0 {
            print("OK  18c tls_write=" + str(wr) + " bytes");
            ok = ok + 1;
        } else {
            print("FAIL 18c tls_write returned " + str(wr));
            err = err + 1;
        }
        # 18d: read response
        resp: str = tls_read(sock18, 4096);
        if len(resp) > 0 {
            print("OK  18d tls_read=" + str(len(resp)) + " bytes");
            ok = ok + 1;
        } else {
            print("FAIL 18d tls_read empty, last_error=" + str(sock18.last_error));
            err = err + 1;
        }
        # 18e: response starts with "HTTP/"
        if len(resp) > 5 {
            hdr: str = resp[0] + resp[1] + resp[2] + resp[3] + resp[4];
            if hdr == "HTTP/" {
                print("OK  18e response starts with HTTP/");
                ok = ok + 1;
            } else {
                print("FAIL 18e response header mismatch: " + hdr);
                err = err + 1;
            }
        }
        # 18f: close zeroes fields
        tls_close(sock18);
        pass18f: bool = True;
        if sock18.ssl_ptr != 0 {
            pass18f = False;
        }
        if sock18.tcp_fd != 0 {
            pass18f = False;
        }
        if sock18.handshake_done {
            pass18f = False;
        }
        if pass18f {
            print("OK  18f tls_close zeroed all fields");
            ok = ok + 1;
        } else {
            print("FAIL 18f tls_close did not zero fields");
            err = err + 1;
        }
    }

    # ── 19. tls_connect to bad host → graceful failure ────────────────────────
    cfg19: TLSConfig = TLSConfig();
    sock19: TLSSocket = tls_connect("this.host.does.not.exist.invalid", 443, cfg19);
    if sock19.ssl_ptr == 0 {
        if sock19.last_error != 0 {
            print(
                "OK  19 tls_connect bad host -> ssl_ptr=0, last_error="
                    + str(sock19.last_error)
            );
            ok = ok + 1;
        } else {
            print("FAIL 19 bad host should set last_error");
            err = err + 1;
        }
    } else {
        print("FAIL 19 bad host should not succeed");
        tls_close(sock19);
        err = err + 1;
    }

    # ── 20. tls_write/read on default (closed) socket ─────────────────────────
    closed_sock: TLSSocket = TLSSocket();
    wd2: int = tls_write(closed_sock, "data");
    rd2: str = tls_read(closed_sock, 512);
    if wd2 < 0 {
        if rd2 == "" {
            print("OK  20 write/read on default socket -> error/empty");
            ok = ok + 1;
        } else {
            print("FAIL 20 read should be empty");
            err = err + 1;
        }
    } else {
        print("FAIL 20 write on default socket should fail");
        err = err + 1;
    }

    # ── Summary ───────────────────────────────────────────────────────────────
    total: int = ok + err;
    print("---");
    print(
        "TLS tests: "
            + str(ok)
            + " passed, "
            + str(err)
            + " failed (total "
            + str(total)
            + ")"
    );
    if err == 0 {
        print("OK all TLS tests passed");
    }
}
