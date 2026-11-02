"""OpenSSL libcrypto C FFI bindings for js_engine.

Exports all X.509 / BIO / EVP / PEM / error symbols required by the X.509
and TLS layers. Other modules should import from this file rather than
directly from the .so.

  import from engine.src.ffi.libcrypto { X509_free, BIO_new, EVP_sha256, ... }

"""

# ── C library import ──────────────────────────────────────────────────────────

import from "libcrypto.so.3" {
    # ── X.509 object lifecycle ────────────────────────────────────────────────
    def:pub X509_free(x509: int) -> None;
    # Distinguished-name accessors (return X509_NAME*)
    def:pub X509_get_subject_name(cert: int) -> int;  def:pub X509_get_issuer_name(
        cert: int
    ) -> int;
    # X509_NAME → human-readable string
    # When buf=0, size=0 OpenSSL malloc-allocates the result string.
    def:pub X509_NAME_oneline(nm: int, buf: int, size: int) -> str;
    # Validity period (return const ASN1_TIME*)
    def:pub X509_get0_notBefore(cert: int) -> int;  def:pub X509_get0_notAfter(
        cert: int
    ) -> int;
    # ── Memory BIO (print ASN1_TIME to a string) ──────────────────────────────
    def:pub BIO_s_mem -> int;  def:pub BIO_new(meth: int) -> int;  def:pub BIO_free(
        bio: int
    ) -> None;  def:pub BIO_read(bio: int, buf: int, len: int) -> int;  def:
        pub BIO_write(bio: int, data: str, len: int) -> int;
    # ASN1_TIME serialisation
    def:pub ASN1_TIME_print(bio: int, tm: int) -> int;
    # ── PEM parsing ───────────────────────────────────────────────────────────
    def:pub PEM_read_bio_X509(bp: int, x: int, cb: int, u: int) -> int;
    # Read private key (EVP_PKEY*) from a BIO
    def:pub PEM_read_bio_PrivateKey(bp: int, x: int, cb: int, u: int) -> int;
    # ── EVP_PKEY lifecycle ────────────────────────────────────────────────────
    def:pub EVP_PKEY_free(pkey: int) -> None;
    # ── Digest / fingerprint ─────────────────────────────────────────────────
    def:pub EVP_sha256 -> int;  def:pub X509_digest(
        cert: int, md: int, buf: int, len: int
    ) -> int;
    # ── Verification parameters ───────────────────────────────────────────────
    # Expected peer IP (text form, "127.0.0.1" / "::1") on an X509_VERIFY_PARAM*
    # (libssl's SSL_get0_param); 1 on success.
    def:pub X509_VERIFY_PARAM_set1_ip_asc(param: int, ipasc: str) -> int;
    # ── Error reporting ───────────────────────────────────────────────────────
    def:pub ERR_get_error -> int;
    # ── SHA-1 digest (Phase 6.9 — WebSocket handshake) ───────────────────────
    # unsigned char *SHA1(const unsigned char *d, size_t n, unsigned char *md);
    # Writes 20 bytes to md, returns md pointer.
    def:pub SHA1(data: int, length: int, md: int) -> int;
    # ── Base64 encoding ──────────────────────────────────────────────────────
    # int EVP_EncodeBlock(unsigned char *t, const unsigned char *f, int n);
    # Writes base64(f[0..n]) into t (null-terminated). Returns output length.
    def:pub EVP_EncodeBlock(out: int, data: int, n: int) -> int;
    # ── Random bytes ─────────────────────────────────────────────────────────
    # int RAND_bytes(unsigned char *buf, int num);
    # Returns 1 on success, 0 on failure.
    def:pub RAND_bytes(buf: int, num: int) -> int;
    # ── EVP digests (node:crypto) ────────────────────────────────────────────
    def:pub EVP_get_digestbyname(name: str) -> int;  def:pub EVP_MD_CTX_new -> int;  def:
        pub EVP_MD_CTX_free(ctx: int) -> None;  def:pub EVP_MD_CTX_reset(
        ctx: int
    ) -> int;  def:pub EVP_DigestInit_ex(ctx: int, md: int, engine: int) -> int;  def:
        pub EVP_DigestUpdate(ctx: int, data: int, len: int) -> int;  def:
        pub EVP_DigestFinal_ex(ctx: int, out: int, out_len: int) -> int;  def:pub HMAC(
        evptype: int,
        key: int,
        key_len: int,
        data: int,
        data_len: int,
        md: int,
        md_len: int
    ) -> int;  def:pub PKCS5_PBKDF2_HMAC(
        password: int,
        passlen: int,
        salt: int,
        saltlen: int,
        iter: int,
        digest: int,
        keylen: int,
        out: int
    ) -> int;  def:pub CRYPTO_memcmp(a: int, b: int, len: int) -> int;  def:
        pub EVP_get_cipherbyname(name: str) -> int;  def:pub EVP_CIPHER_CTX_new -> int;  def:
        pub EVP_CIPHER_CTX_free(ctx: int) -> None;  def:pub EVP_EncryptInit_ex(
        ctx: int, cipher: int, engine: int, key: int, iv: int
    ) -> int;  def:pub EVP_EncryptUpdate(
        ctx: int, out: int, outl: int, inp: int, inl: int
    ) -> int;  def:pub EVP_EncryptFinal_ex(ctx: int, out: int, outl: int) -> int;  def:
        pub EVP_DecryptInit_ex(
        ctx: int, cipher: int, engine: int, key: int, iv: int
    ) -> int;  def:pub EVP_DecryptUpdate(
        ctx: int, out: int, outl: int, inp: int, inl: int
    ) -> int;  def:pub EVP_DecryptFinal_ex(ctx: int, out: int, outl: int) -> int;  def:
        pub EVP_CIPHER_CTX_ctrl(ctx: int, type: int, arg: int, ptr: int) -> int;
    # OpenSSL 3 renamed EVP_CIPHER_iv_length → EVP_CIPHER_get_iv_length.
    def:pub EVP_CIPHER_get_iv_length(cipher: int) -> int;
    # ── Asymmetric key generation (node:crypto generateKeyPair) ──────────────
    def:pub EVP_PKEY_CTX_new_from_name(libctx: int, name: str, propquery: int) -> int;  def:
        pub EVP_PKEY_CTX_new_id(id: int, e: int) -> int;  def:pub EVP_PKEY_CTX_new(
        pkey: int, e: int
    ) -> int;  def:pub EVP_PKEY_CTX_free(ctx: int) -> None;  def:
        pub EVP_PKEY_keygen_init(ctx: int) -> int;
    # int EVP_PKEY_keygen(EVP_PKEY_CTX *ctx, EVP_PKEY **ppkey)
    def:pub EVP_PKEY_keygen(ctx: int, ppkey: int) -> int;  def:
        pub EVP_PKEY_paramgen_init(ctx: int) -> int;  def:pub EVP_PKEY_paramgen(
        ctx: int, ppkey: int
    ) -> int;  def:pub EVP_PKEY_CTX_set_rsa_keygen_bits(ctx: int, bits: int) -> int;
    # Takes ownership of pubexp on success — do not BN_free it afterwards.
    def:pub EVP_PKEY_CTX_set_rsa_keygen_pubexp(ctx: int, pubexp: int) -> int;  def:
        pub EVP_PKEY_CTX_set_ec_paramgen_curve_nid(ctx: int, nid: int) -> int;  def:
        pub EVP_PKEY_CTX_set_dh_paramgen_prime_len(ctx: int, pbits: int) -> int;  def:
        pub EVP_PKEY_CTX_set_dh_paramgen_generator(ctx: int, gen: int) -> int;
    # ── BIGNUM ───────────────────────────────────────────────────────────────
    def:pub BN_new -> int;  def:pub BN_free(a: int) -> None;  def:pub BN_set_word(
        a: int, w: int
    ) -> int;  def:pub BN_get_word(a: int) -> int;
    # ── Memory BIO from an existing buffer (read-only) ───────────────────────
    def:pub BIO_new_mem_buf(buf: int, len: int) -> int;
    # BIO_pending(b) == BIO_ctrl(b, BIO_CTRL_PENDING=10, 0, NULL)
    def:pub BIO_ctrl(bp: int, cmd: int, larg: int, parg: int) -> int;
    # ── Key serialisation (PEM) ──────────────────────────────────────────────
    def:pub PEM_write_bio_PrivateKey(
        bp: int, x: int, enc: int, kstr: int, klen: int, cb: int, u: int
    ) -> int;  def:pub PEM_write_bio_PrivateKey_traditional(
        bp: int, x: int, enc: int, kstr: int, klen: int, cb: int, u: int
    ) -> int;  def:pub PEM_write_bio_PUBKEY(bp: int, x: int) -> int;  def:
        pub PEM_read_bio_PUBKEY(bp: int, x: int, cb: int, u: int) -> int;  def:
        pub PEM_write_bio_RSAPublicKey(bp: int, rsa: int) -> int;  def:
        pub PEM_read_bio_RSAPublicKey(bp: int, rsa: int, cb: int, u: int) -> int;
    # ── Key serialisation (DER, via BIO) ─────────────────────────────────────
    def:pub i2d_PUBKEY_bio(bp: int, pkey: int) -> int;  def:pub i2d_PrivateKey_bio(
        bp: int, pkey: int
    ) -> int;  def:pub i2d_PKCS8PrivateKeyInfo_bio(bp: int, pkey: int) -> int;
    # Encrypted PKCS#8 DER: i2d_PKCS8PrivateKey_bio(bp, pkey, enc, kstr, klen, cb, u)
    def:pub i2d_PKCS8PrivateKey_bio(
        bp: int, pkey: int, enc: int, kstr: int, klen: int, cb: int, u: int
    ) -> int;  def:pub i2d_RSAPublicKey_bio(bp: int, rsa: int) -> int;  def:
        pub d2i_PUBKEY_bio(bp: int, a: int) -> int;  def:pub d2i_PrivateKey_bio(
        bp: int, a: int
    ) -> int;  def:pub d2i_PKCS8PrivateKey_bio(
        bp: int, x: int, cb: int, u: int
    ) -> int;  def:pub d2i_RSAPublicKey_bio(bp: int, rsa: int) -> int;
    # ── EVP_PKEY introspection ───────────────────────────────────────────────
    def:pub EVP_PKEY_get_base_id(pkey: int) -> int;  def:pub EVP_PKEY_get_bits(
        pkey: int
    ) -> int;  def:pub EVP_PKEY_eq(a: int, b: int) -> int;  def:pub EVP_PKEY_up_ref(
        pkey: int
    ) -> int;
    # int EVP_PKEY_get_bn_param(const EVP_PKEY *, const char *name, BIGNUM **bn)
    def:pub EVP_PKEY_get_bn_param(pkey: int, key_name: str, bn: int) -> int;  def:
        pub EVP_PKEY_get_utf8_string_param(
        pkey: int, key_name: str, out: int, max_sz: int, out_len: int
    ) -> int;  def:pub EVP_PKEY_get_octet_string_param(
        pkey: int, key_name: str, out: int, max_sz: int, out_len: int
    ) -> int;  def:pub EVP_PKEY_get1_RSA(pkey: int) -> int;  def:pub EVP_PKEY_set1_RSA(
        pkey: int, rsa: int
    ) -> int;  def:pub EVP_PKEY_new -> int;  def:pub RSA_free(r: int) -> None;
    # ── Raw (Ed25519 / X25519 / Ed448 / X448) key material ───────────────────
    def:pub EVP_PKEY_get_raw_public_key(pkey: int, out: int, len: int) -> int;  def:
        pub EVP_PKEY_get_raw_private_key(pkey: int, out: int, len: int) -> int;  def:
        pub EVP_PKEY_new_raw_public_key(
        type: int, e: int, data: int, len: int
    ) -> int;  def:pub EVP_PKEY_new_raw_private_key(
        type: int, e: int, data: int, len: int
    ) -> int;
    # ── Object identifiers ───────────────────────────────────────────────────
    def:pub OBJ_txt2nid(s: str) -> int;  def:pub OBJ_nid2sn(n: int) -> str;
}
