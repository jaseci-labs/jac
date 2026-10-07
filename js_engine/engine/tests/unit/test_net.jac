"""Comprehensive tests for Phase 6.2 — Raw TCP/UDP/Unix sockets.

Test plan:
  TCP Client Tests (1–10):
    1.  SocketAddress defaults
    2.  TCPSocket defaults
    3.  TCPListener defaults
    4.  tcp_connect to google.com:80 — valid fd, connected, peer_addr
    5.  tcp_write sends HTTP request → returns byte count > 0
    6.  tcp_read receives HTTP response → non-empty data starting with "HTTP/"
    7.  tcp_close zeroes fd and sets connected=False
    8.  tcp_close idempotent (no crash)
    9.  tcp_connect bad host → fd==0, last_error set
    10. tcp_set_nodelay on connected socket → returns 0
  TCP Server Tests (11–16):
    11. tcp_listen on 127.0.0.1:0 → valid fd, listening=True, port assigned
    12. tcp_listener_close → fd=0, listening=False
    13. tcp_listen + loopback connect + accept → two connected sockets
    14. Echo: client writes, server reads, server writes back, client reads
    15. tcp_shutdown SHUT_WR then read → empty (EOF)
    16. tcp_set_keepalive on connected socket → returns 0
  UDP Tests (17–21):
    17. UDPSocket defaults
    18. udp_create bound to 127.0.0.1:0 → valid fd, bound=True, port assigned
    19. udp_close → fd=0, bound=False
    20. UDP loopback: send + recv → same data round-trips
    21. udp_set_broadcast → returns 0
  Unix Socket Tests (22–25):
    22. unix_listen on temp path → valid fd, listening=True
    23. unix_connect + accept → two connected sockets
    24. Unix echo: client writes, server reads back
    25. Cleanup: close all, unlink path
"""

import from engine.src.net.tcp_socket {
    SocketAddress,
    TCPSocket,
    TCPListener,
    tcp_connect,
    tcp_listen,
    tcp_accept,
    tcp_read,
    tcp_write,
    tcp_write_all,
    tcp_close,
    tcp_shutdown,
    tcp_listener_close,
    tcp_set_nodelay,
    tcp_set_keepalive,
    tcp_set_reuseaddr,
    tcp_get_local_address,
    tcp_get_peer_address
}
import from engine.src.net.constants { SHUT_WR, AF_INET }
import from engine.src.net.udp_socket {
    UDPSocket,
    UDPMessage,
    udp_create,
    udp_send,
    udp_recv,
    udp_close,
    udp_set_broadcast
}
import from engine.src.net.unix_socket { unix_connect, unix_listen, unix_accept }
import from engine.src.ffi.libc { unlink }

# ── CRLF workaround (WA-6.1-F) ──────────────────────────────────────────────
glob _UT_CRLF: str = chr(13) + "\n",
     _pass_count: int = 0,
     _fail_count: int = 0,
     _total: int = 0;

# ── Test harness ─────────────────────────────────────────────────────────────
def check(label: str, ok: bool) {
    _total = _total + 1;
    if ok {
        _pass_count = _pass_count + 1;
        print("  OK " + label);
    } else {
        _fail_count = _fail_count + 1;
        print("  FAIL " + label);
    }
}

# ── Helper: fork a TCP loopback pair via listen+connect+accept ───────────────

"""Start a server on 127.0.0.1:0, connect to it, and accept.
Returns (listener, client_sock, server_sock) as a list of ints
representing the 3 fds, with objects stored in globs for access."""
glob _test_listener: TCPListener = TCPListener();
glob _test_client: TCPSocket = TCPSocket(),
     _test_server: TCPSocket = TCPSocket();

def _make_loopback_pair -> bool {
    _test_listener = tcp_listen("127.0.0.1", 0, 1);
    if _test_listener.fd == 0 {
        return False;
    }
    assigned_port: int = _test_listener.address.port;
    _test_client = tcp_connect("127.0.0.1", assigned_port);
    if _test_client.fd == 0 {
        tcp_listener_close(_test_listener);
        return False;
    }
    # Accept on server side
    _test_server = tcp_accept(_test_listener);
    if _test_server.fd == 0 {
        tcp_close(_test_client);
        tcp_listener_close(_test_listener);
        return False;
    }
    return True;
}

with entry {
    print("=== Phase 6.2: Raw TCP/UDP/Unix Socket Tests ===");

    # ── TCP Client Tests ─────────────────────────────────────────────────

    print("\n--- TCP Client ---");

    # Test 1: SocketAddress defaults
    sa: SocketAddress = SocketAddress();
    check(
        "1. SocketAddress defaults", sa.host == "" and sa.port == 0 and sa.family == 0
    );

    # Test 2: TCPSocket defaults
    ts: TCPSocket = TCPSocket();
    check(
        "2. TCPSocket defaults", ts.fd == 0 and not ts.connected and ts.last_error == 0
    );

    # Test 3: TCPListener defaults
    tl: TCPListener = TCPListener();
    check(
        "3. TCPListener defaults", tl.fd == 0 and not tl.listening and tl.backlog == 128
    );

    # Test 4–8: Connect to google.com:80, write, read, close
    g_sock: TCPSocket = tcp_connect("google.com", 80);
    check("4. tcp_connect google.com:80 fd>0", g_sock.fd > 0);
    check("4b. tcp_connect connected=True", g_sock.connected);
    check("4c. tcp_connect peer port=80", g_sock.peer_addr.port == 80);
}

glob
     # Test 5: Write HTTP request
     req: str = "GET / HTTP/1.0" + _UT_CRLF + "Host: google.com" + _UT_CRLF + _UT_CRLF;
with entry {
    wr: int = tcp_write(g_sock, req);
    check("5. tcp_write bytes>0", wr > 0);

    # Test 6: Read HTTP response
    resp: str = tcp_read(g_sock, 4096);
    check("6. tcp_read non-empty", len(resp) > 0);
    # Check it starts with "HTTP/"
    http_prefix: bool = False;
    if len(resp) > 4 {
        if resp[0] == "H"
            and resp[1] == "T"
            and resp[2] == "T"
            and resp[3] == "P"
            and resp[4] == "/" {
            http_prefix = True;
        }
    }
    check("6b. tcp_read starts with HTTP/", http_prefix);

    # Test 7: Close
    tcp_close(g_sock);
    check("7. tcp_close fd=0", g_sock.fd == 0);
    check("7b. tcp_close connected=False", not g_sock.connected);

    # Test 8: Idempotent close (no crash)
    tcp_close(g_sock);
    check("8. tcp_close idempotent", g_sock.fd == 0);

    # Test 9: Bad host
    bad: TCPSocket = tcp_connect("this.host.does.not.exist.invalid", 80);
    check("9. bad host fd=0", bad.fd == 0);
    check("9b. bad host last_error set", bad.last_error != 0);

    # Test 10: tcp_set_nodelay on a fresh loopback connection
    nd_sock: TCPSocket = tcp_connect("google.com", 80);
    nd_rc: int = -99;
    if nd_sock.fd > 0 {
        nd_rc = tcp_set_nodelay(nd_sock, True);
    }
    check("10. tcp_set_nodelay returns 0", nd_rc == 0);
    tcp_close(nd_sock);

    # ── TCP Server Tests ─────────────────────────────────────────────────

    print("\n--- TCP Server ---");

    # Test 11: tcp_listen on 127.0.0.1:0
    srv: TCPListener = tcp_listen("127.0.0.1", 0, 16);
    check("11. tcp_listen fd>0", srv.fd > 0);
    check("11b. tcp_listen listening=True", srv.listening);
    check("11c. tcp_listen port>0 (assigned)", srv.address.port > 0);

    # Test 12: tcp_listener_close
    port_saved: int = srv.address.port;
    tcp_listener_close(srv);
    check("12. tcp_listener_close fd=0", srv.fd == 0);
    check("12b. tcp_listener_close listening=False", not srv.listening);

    # Test 13–14: Loopback pair + echo
    pair_ok: bool = _make_loopback_pair();
    check("13. loopback pair created", pair_ok);

    if pair_ok {
        check("13b. client connected", _test_client.connected);
        check("13c. server connected", _test_server.connected);

        # Test 14: Echo
        echo_msg: str = "Hello, TCP!";
        wr2: int = tcp_write(_test_client, echo_msg);
        check("14a. echo write ok", wr2 == len(echo_msg));

        echo_back: str = tcp_read(_test_server, 256);
        check("14b. echo read matches", echo_back == echo_msg);

        # Write back from server to client
        wr3: int = tcp_write(_test_server, "PONG");
        pong: str = tcp_read(_test_client, 256);
        check("14c. server->client echo", pong == "PONG");

        # Test 15: tcp_shutdown SHUT_WR then read → EOF
        tcp_shutdown(_test_client, SHUT_WR);
        eof_data: str = tcp_read(_test_server, 256);
        check("15. shutdown SHUT_WR -> EOF", eof_data == "");

        # Test 16: tcp_set_keepalive
        ka_rc: int = tcp_set_keepalive(_test_server, True, 60);
        check("16. tcp_set_keepalive returns 0", ka_rc == 0);

        # Cleanup
        tcp_close(_test_client);
        tcp_close(_test_server);
        tcp_listener_close(_test_listener);
    }

    # ── UDP Tests ────────────────────────────────────────────────────────

    print("\n--- UDP ---");

    # Test 17: UDPSocket defaults
    us: UDPSocket = UDPSocket();
    check("17. UDPSocket defaults", us.fd == 0 and not us.bound and us.bound_port == 0);

    # Test 18: udp_create bound
    u1: UDPSocket = udp_create("127.0.0.1", 0);
    check("18. udp_create fd>0", u1.fd > 0);
    check("18b. udp_create bound=True", u1.bound);
    check("18c. udp_create port>0", u1.bound_port > 0);

    u_fixed: UDPSocket = udp_create("127.0.0.1", 12345);
    check("18d. udp_create fixed port 12345", u_fixed.bound_port == 12345);
    udp_close(u_fixed);

    # Test 19: udp_close
    udp_close(u1);
    check("19. udp_close fd=0", u1.fd == 0);
    check("19b. udp_close bound=False", not u1.bound);

    # Test 20: UDP loopback send+recv
    u_recv: UDPSocket = udp_create("127.0.0.1", 0);
    u_send: UDPSocket = udp_create("", 0);
}

glob udp_msg: str = "UDP ping";
with entry {
    udp_wr: int = udp_send(u_send, udp_msg, "127.0.0.1", u_recv.bound_port);
    check("20a. udp_send bytes>0", udp_wr > 0);

    udp_got: UDPMessage = udp_recv(u_recv, 256);
    check("20b. udp_recv data matches", udp_got.data == udp_msg);
    check("20c. udp_recv length correct", udp_got.length == len(udp_msg));
    check("20d. udp_recv sender host", udp_got.host == "127.0.0.1");
    check("20e. udp_recv sender port>0", udp_got.port > 0);

    udp_close(u_recv);
    udp_close(u_send);

    # Test 21: udp_set_broadcast
    u_bc: UDPSocket = udp_create("", 0);
    bc_rc: int = udp_set_broadcast(u_bc, True);
    check("21. udp_set_broadcast returns 0", bc_rc == 0);
    udp_close(u_bc);

    # ── Unix Socket Tests ────────────────────────────────────────────────

    print("\n--- Unix Socket ---");
}

glob
     # Use a temp path
     unix_path: str = "/tmp/js_engine_test_unix.sock";

with entry {
    # Clean up any leftover socket file from a previous run
    unlink(unix_path);

    # Test 22: unix_listen
    unix_srv: TCPListener = unix_listen(unix_path, 4);
    unix_ok: bool = unix_srv.fd > 0;
    check("22. unix_listen fd>0", unix_ok);
    check("22b. unix_listen listening", unix_srv.listening);

    if unix_ok {
        # Test 23: unix_connect + accept
        unix_cli: TCPSocket = unix_connect(unix_path);
        check("23a. unix_connect fd>0", unix_cli.fd > 0);
        check("23b. unix_connect connected", unix_cli.connected);

        unix_acc: TCPSocket = unix_accept(unix_srv);
        check("23c. unix_accept fd>0", unix_acc.fd > 0);
        check("23d. unix_accept connected", unix_acc.connected);

        # Test 24: Echo over Unix socket
        unix_msg: str = "Hello, Unix!";
        ux_wr: int = tcp_write(unix_cli, unix_msg);
        check("24a. unix write ok", ux_wr == len(unix_msg));

        ux_rd: str = tcp_read(unix_acc, 256);
        check("24b. unix read matches", ux_rd == unix_msg);

        # Test 25: Cleanup
        tcp_close(unix_cli);
        tcp_close(unix_acc);
        tcp_listener_close(unix_srv);
        check("25. unix cleanup (listener closed)", unix_srv.fd == 0);
    }

    # Remove socket file
    unlink(unix_path);

    # ── Summary ──────────────────────────────────────────────────────────

    print(
        "\nNet tests: "
            + _tnet_int_to_str(_pass_count)
            + " passed, "
            + _tnet_int_to_str(_fail_count)
            + " failed (total "
            + _tnet_int_to_str(_total)
            + ")"
    );
    if _fail_count == 0 {
        print("OK all net tests passed");
    } else {
        print("FAIL some net tests failed");
    }
}

# ── Helpers (duplicated since we can't import private fns) ───────────────────

def _tnet_int_to_str(n: int) -> str {
    if n == 0 {
        return "0";
    }
    result: str = "";
    rem: int = n;
    while rem > 0 {
        d: int = rem - (rem // 10) * 10;
        result = _tnet_digit_char(d) + result;
        rem = rem // 10;
    }
    return result;
}

def _tnet_digit_char(d: int) -> str {
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
