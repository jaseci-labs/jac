"""Minimal test for non-blocking TLS handshake."""
import from engine.src.ffi.libc { close, fcntl }
import from engine.src.net.constants { F_GETFL, F_SETFL, O_NONBLOCK }
import from engine.src.net.tcp_socket { TCPSocket, tcp_connect, tcp_connect_nb_start }
import from engine.src.tls.tls {
    TLSConfig,
    TLSContext,
    TLSSocket,
    tls_create_client_context,
    tls_wrap_fd,
    tls_handshake_nb,
    tls_close,
    tls_client_wrap_fd,
    SSL_ERROR_WANT_READ,
    SSL_ERROR_WANT_WRITE
}
import from engine.src.ffi.libssl { SSL_connect, SSL_get_error }

with entry {
    print("=== Non-blocking TLS handshake test ===");

    # 1. Connect to google.com:443 (blocking TCP)
    sock: TCPSocket = tcp_connect("google.com", 443);
    print("tcp fd:", sock.fd, "connected:", sock.connected);

    if sock.fd == 0 {
        print("FAIL: TCP connect failed");
    } else {
        # 2. Set fd to non-blocking
        fl: int = fcntl(sock.fd, F_GETFL, 0);
        print("flags before:", fl);
        fcntl(sock.fd, F_SETFL, fl | O_NONBLOCK);
        fl2: int = fcntl(sock.fd, F_GETFL, 0);
        print("flags after:", fl2);
        # 3. Create TLS client wrap (no handshake)
        tls_sock: TLSSocket = tls_client_wrap_fd(sock.fd, "google.com", True, "");
        print("ssl_ptr:", tls_sock.ssl_ptr);
        print("is_server:", tls_sock.context.is_server);
        if tls_sock.ssl_ptr == 0 {
            print("FAIL: tls_client_wrap_fd failed");
        } else {
            # 4. Attempt non-blocking handshake
            err: int = tls_handshake_nb(tls_sock);
            print("handshake_nb result:", err);
            print("SSL_ERROR_WANT_READ =", SSL_ERROR_WANT_READ);
            print("SSL_ERROR_WANT_WRITE =", SSL_ERROR_WANT_WRITE);
            if err == 0 {
                print("OK: handshake completed immediately");
            } elif err == SSL_ERROR_WANT_READ {
                print("OK: WANT_READ (expected for non-blocking)");
            } elif err == SSL_ERROR_WANT_WRITE {
                print("OK: WANT_WRITE (expected for non-blocking)");
            } else {
                print("UNEXPECTED error code:", err);
                # Try raw SSL_connect on the same ssl_ptr
                rc: int = SSL_connect(tls_sock.ssl_ptr);
                print("raw SSL_connect rc:", rc);
                raw_err: int = SSL_get_error(tls_sock.ssl_ptr, rc);
                print("raw SSL_get_error:", raw_err);
            }
            tls_close(tls_sock);
        }
    }

    print("=== done ===");
}
