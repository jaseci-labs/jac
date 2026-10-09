"""OpenSSL libssl C FFI bindings for js_engine.

Exports every SSL_CTX / SSL symbol required by the TLS and X.509 layers.
Other modules should import from this file rather than directly from the .so.

  import from engine.src.ffi.libssl { SSL_CTX_new, SSL_new, ... }

"""

# ── C library import ──────────────────────────────────────────────────────────

import from "libssl.so.3" {
    # SSL_METHOD factories
    def:pub TLS_method -> int;  def:pub TLS_client_method -> int;  def:
        pub TLS_server_method -> int;
    # SSL_CTX lifecycle
    def:pub SSL_CTX_new(method: int) -> int;  def:pub SSL_CTX_free(ctx: int) -> None;
    # SSL_CTX configuration
    def:pub SSL_CTX_set_verify(ctx: int, mode: int, cb: int) -> None;  def:
        pub SSL_CTX_set_default_verify_paths(ctx: int) -> int;  def:
        pub SSL_CTX_load_verify_locations(
        ctx: int, ca_file: str, ca_path: int
    ) -> int;  def:pub SSL_CTX_use_certificate_file(
        ctx: int, file: str, type: int
    ) -> int;  def:pub SSL_CTX_use_PrivateKey_file(
        ctx: int, file: str, type: int
    ) -> int;
    # Load from in-memory X509/EVP_PKEY objects (used when cert/key is PEM content, not a file path)
    def:pub SSL_CTX_use_certificate(ctx: int, x509: int) -> int;  def:
        pub SSL_CTX_use_PrivateKey(ctx: int, pkey: int) -> int;  def:
        pub SSL_CTX_check_private_key(ctx: int) -> int;  def:pub SSL_CTX_set_options(
        ctx: int, options: int
    ) -> int;
    # SSL lifecycle
    def:pub SSL_new(ctx: int) -> int;  def:pub SSL_free(ssl: int) -> None;
    # SSL I/O binding
    def:pub SSL_set_fd(ssl: int, fd: int) -> int;
    # SNI: SSL_set_tlsext_host_name(ssl, name) is a macro over SSL_ctrl
    # SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME=55, TLSEXT_NAMETYPE_host_name=0, name)
    def:pub SSL_ctrl(ssl: int, cmd: int, larg: int, parg: str) -> int;
    # Handshake
    def:pub SSL_connect(ssl: int) -> int;  def:pub SSL_accept(ssl: int) -> int;  def:
        pub SSL_do_handshake(ssl: int) -> int;
    # I/O
    def:pub SSL_read(ssl: int, buf: int, num: int) -> int;  def:pub SSL_write(
        ssl: int, buf: str, num: int
    ) -> int;
    # Shutdown
    def:pub SSL_shutdown(ssl: int) -> int;
    # Error inspection
    def:pub SSL_get_error(ssl: int, ret: int) -> int;
    # Peer certificate (returns X509*; caller must X509_free when done)
    def:pub SSL_get1_peer_certificate(ssl: int) -> int;
    # Certificate verification result (call after handshake completes)
    #   Returns X509_V_OK (0) on success, or an X509_V_ERR_* code on failure.
    def:pub SSL_get_verify_result(ssl: int) -> int;
    # Peer identity for verification (call before SSL_connect): the DNS name
    # the server certificate must match (1 on success) and its X509_CHECK_FLAG_*
    # matching flags; SSL_get0_param returns the X509_VERIFY_PARAM* that
    # X509_VERIFY_PARAM_set1_ip_asc (libcrypto) sets an expected IP on.
    def:pub SSL_set1_host(ssl: int, hostname: str) -> int;  def:pub SSL_set_hostflags(
        ssl: int, flags: int
    ) -> None;  def:pub SSL_get0_param(ssl: int) -> int;
    # ALPN (Application-Layer Protocol Negotiation) — RFC 7301
    # Client-side: set list of protocols to offer (wire-format: len-prefixed)
    #   SSL_CTX_set_alpn_protos(ctx, protos, protos_len) → 0 on success
    def:pub SSL_CTX_set_alpn_protos(ctx: int, protos: int, protos_len: int) -> int;
    # Server-side: retrieve negotiated protocol after handshake
    #   SSL_get0_alpn_selected(ssl, &data, &len) → void
    def:pub SSL_get0_alpn_selected(ssl: int, data_out: int, len_out: int) -> None;
    # Server-side: set ALPN selection callback
    #   SSL_CTX_set_alpn_select_cb(ctx, cb, arg) → void
    #   cb signature: int(SSL*, out_ptr, out_len_ptr, in_ptr, in_len, arg) → int
    def:pub SSL_CTX_set_alpn_select_cb(ctx: int, cb: int, arg: int) -> None;
    # ALPN helper: finds first match between server and client protocol lists.
    #   SSL_select_next_proto(out, outlen, server, server_len, client, client_len)
    #   Returns OPENSSL_NPN_NEGOTIATED (1) on match, OPENSSL_NPN_NO_OVERLAP (2) if none.
    def:pub SSL_select_next_proto(
        out: int,
        outlen: int,
        server: int,
        server_len: int,
        client: int,
        client_len: int
    ) -> int;
}
