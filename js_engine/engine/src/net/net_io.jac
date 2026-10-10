"""Shared HTTP/TCP/TLS raw recv for llhttp readers."""

import from engine.src.builtins.net_bridge { nb_get_tcp_fd, nb_get_tls_ssl_ptr }
import from engine.src.ffi.libc { recv }
import from engine.src.ffi.libssl { SSL_read }
import from engine.src.runtime.syscall { is_c_error }

"""Read up to n bytes from a net_bridge handle (positive=TCP, negative=TLS)."""
def:pub net_raw_recv(handle: int, buf: int, n: int) -> int {
    if handle > 0 {
        fd: int = nb_get_tcp_fd(handle);
        if fd == 0 {
            return 0;
        }
        nr: int = recv(fd, buf, n, 0);
        if is_c_error(nr) {
            return 0;
        }
        return nr;
    } elif handle < 0 {
        ssl: int = nb_get_tls_ssl_ptr(handle);
        if ssl == 0 {
            return 0;
        }
        nr: int = SSL_read(ssl, buf, n);
        if is_c_error(nr) {
            return 0;
        }
        return nr;
    }
    return 0;
}
