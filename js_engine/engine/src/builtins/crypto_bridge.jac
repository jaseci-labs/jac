"""Crypto bridge — OpenSSL-backed primitives for node:crypto / WebCrypto.

Exposed via globalThis.__crypto (native fns wired in global.na.jac).
JS layer: src/builtins/js/crypto.js
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_true,
    js_false,
    jsv_is_int32,
    jsv_is_double,
    jsv_to_int32,
    jsv_to_double,
    jsv_is_string_cell,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_from_double
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.mem {
    io_alloc,
    read_byte,
    write_byte,
    read_u32,
    read_ptr,
    write_i64
}
import from engine.src.runtime.binary_state {
    BinaryViewWitness,
    BackingStore,
    binary_view_witness,
    binary_typed_array_buffer,
    binary_backing_store,
    binary_is_typed_array
}
import from engine.src.ffi.libcrypto {
    EVP_get_digestbyname,
    EVP_MD_CTX_new,
    EVP_MD_CTX_free,
    EVP_MD_CTX_reset,
    EVP_DigestInit_ex,
    EVP_DigestUpdate,
    EVP_DigestFinal_ex,
    HMAC,
    PKCS5_PBKDF2_HMAC,
    CRYPTO_memcmp,
    RAND_bytes,
    EVP_get_cipherbyname,
    EVP_CIPHER_CTX_new,
    EVP_CIPHER_CTX_free,
    EVP_EncryptInit_ex,
    EVP_EncryptUpdate,
    EVP_EncryptFinal_ex,
    EVP_DecryptInit_ex,
    EVP_DecryptUpdate,
    EVP_DecryptFinal_ex,
    EVP_CIPHER_CTX_ctrl,
    EVP_CIPHER_get_iv_length,
    ERR_get_error,
    EVP_PKEY_CTX_new_id,
    EVP_PKEY_CTX_new,
    EVP_PKEY_CTX_free,
    EVP_PKEY_keygen_init,
    EVP_PKEY_keygen,
    EVP_PKEY_paramgen_init,
    EVP_PKEY_paramgen,
    EVP_PKEY_CTX_set_rsa_keygen_bits,
    EVP_PKEY_CTX_set_rsa_keygen_pubexp,
    EVP_PKEY_CTX_set_ec_paramgen_curve_nid,
    EVP_PKEY_CTX_set_dh_paramgen_prime_len,
    EVP_PKEY_CTX_set_dh_paramgen_generator,
    BN_new,
    BN_free,
    BN_set_word,
    BN_get_word,
    BIO_s_mem,
    BIO_new,
    BIO_new_mem_buf,
    BIO_free,
    BIO_read,
    BIO_ctrl,
    PEM_write_bio_PrivateKey,
    PEM_write_bio_PrivateKey_traditional,
    PEM_write_bio_PUBKEY,
    PEM_read_bio_PUBKEY,
    PEM_read_bio_PrivateKey,
    PEM_write_bio_RSAPublicKey,
    PEM_read_bio_RSAPublicKey,
    i2d_PUBKEY_bio,
    i2d_PrivateKey_bio,
    i2d_PKCS8PrivateKeyInfo_bio,
    i2d_PKCS8PrivateKey_bio,
    i2d_RSAPublicKey_bio,
    d2i_PUBKEY_bio,
    d2i_PrivateKey_bio,
    d2i_RSAPublicKey_bio,
    EVP_PKEY_free,
    EVP_PKEY_get_base_id,
    EVP_PKEY_get_bits,
    EVP_PKEY_eq,
    EVP_PKEY_get_bn_param,
    EVP_PKEY_get_utf8_string_param,
    EVP_PKEY_get_octet_string_param,
    EVP_PKEY_get1_RSA,
    EVP_PKEY_set1_RSA,
    EVP_PKEY_new,
    RSA_free,
    EVP_PKEY_get_raw_public_key,
    EVP_PKEY_get_raw_private_key,
    EVP_PKEY_new_raw_public_key,
    EVP_PKEY_new_raw_private_key,
    OBJ_txt2nid
}
import from engine.src.ffi.libc { calloc, free, memcpy }
import from engine.src.builtins.string { _hex_val }

# EVP_CTRL_AEAD_SET_TAG = 0x11, EVP_CTRL_AEAD_GET_TAG = 0x10
glob _EVP_CTRL_AEAD_SET_TAG: int = 17,
     _EVP_CTRL_AEAD_GET_TAG: int = 16,
     _last_crypto_err: int = 0,
     _HASH_CTX_PTR: list[int] = [0],
     _HASH_MD: list[int] = [0],
     _HASH_OUT_SIZE: list[int] = [0],
     _HASH_FREE: list[int] = [];


def _arg_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def _arg_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

"""Encode bytes at ptr[0..len) as lowercase hex."""
def _ptr_to_hex(ptr: int, nbytes: int) -> str {
    hex_chars: str = "0123456789abcdef";
    out: str = "";
    i: int = 0;
    while i < nbytes {
        b: int = read_byte(ptr, i);
        out = out + hex_chars[(b >> 4) & 15];
        out = out + hex_chars[b & 15];
        i = i + 1;
    }
    return out;
}

"""Copy hex string into ptr; returns byte length or -1."""
def _hex_to_ptr(hexs: str, ptr: int, max_len: int) -> int {
    n: int = len(hexs);
    if n % 2 != 0 {
        return -1;
    }
    nbytes: int = n // 2;
    if nbytes > max_len {
        return -1;
    }
    i: int = 0;
    while i < nbytes {
        hi: int = _hex_val(ord(hexs[i * 2]));
        lo: int = _hex_val(ord(hexs[i * 2 + 1]));
        if hi < 0 or lo < 0 {
            return -1;
        }
        write_byte(ptr, i, (hi << 4) | lo);
        i = i + 1;
    }
    return nbytes;
}


def _is_gcm_algo(algo: str) -> bool {
    n: int = len(algo);
    if n < 3 {
        return False;
    }
    if algo[n - 3] == "g" and algo[n - 2] == "c" and algo[n - 1] == "m" {
        return True;
    }
    return False;
}

def _digest_size_for_algo(algo: str) -> int {
    if algo == "sha1" {
        return 20;
    }
    if algo == "sha224" {
        return 28;
    }
    if algo == "sha256" {
        return 32;
    }
    if algo == "sha384" {
        return 48;
    }
    if algo == "sha512" {
        return 64;
    }
    if algo == "sha512-224" {
        return 28;
    }
    if algo == "sha512-256" {
        return 32;
    }
    if algo == "md5" {
        return 16;
    }
    return 64;
}

# ── Hash contexts ─────────────────────────────────────────────────────────────

"""args[0]=algorithm name. Returns handle id (int) or 0."""
def:pub crypto_hash_new(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0);
    }
    algo: str = _arg_str(args[0]);
    md: int = EVP_get_digestbyname(algo);
    if md == 0 {
        return js_int(0);
    }
    ctx: int = EVP_MD_CTX_new();
    if ctx == 0 {
        return js_int(0);
    }
    if EVP_DigestInit_ex(ctx, md, 0) != 1 {
        EVP_MD_CTX_free(ctx);
        return js_int(0);
    }
    if len(_HASH_FREE) > 0 {
        slot: int = _HASH_FREE[len(_HASH_FREE) - 1];
        del _HASH_FREE[len(_HASH_FREE) - 1];
        _HASH_CTX_PTR[slot] = ctx;
        _HASH_MD[slot] = md;
        _HASH_OUT_SIZE[slot] = _digest_size_for_algo(algo);
        return js_int(slot);
    }
    _HASH_CTX_PTR.append(ctx);
    _HASH_MD.append(md);
    _HASH_OUT_SIZE.append(_digest_size_for_algo(algo));
    return js_int(len(_HASH_CTX_PTR) - 1);
}

"""(ptr, byte length) of a live Buffer / TypedArray view's bytes, or (0, -1)
when `v` is not one (or is detached / out of bounds)."""
def _view_span(v: JSValue) -> tuple[int, int] {
    if not binary_is_typed_array(v) {
        return (0, -1);
    }
    w: BinaryViewWitness = binary_view_witness(v);
    if not w.valid or w.detached or w.oob {
        return (0, -1);
    }
    store: BackingStore = binary_backing_store(binary_typed_array_buffer(v));
    if store.ptr == 0 and w.byte_length > 0 {
        return (0, -1);
    }
    return (store.ptr + w.byte_offset, w.byte_length);
}

"""args[0]=handle, then EITHER [1]=Buffer/TypedArray (hashed in place) OR
[1]=data ptr, [2]=len. crypto.js passes the Buffer: copying it into a scratch
allocation one byte at a time from JS (two native calls per byte) made SHA-1 of
a 1 MB module ~35 s — the ETag Vite's dev server computes for every response."""
def:pub crypto_hash_update(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_int(0);
    }
    hid: int = _arg_int(args[0]);
    if hid <= 0 or hid >= len(_HASH_CTX_PTR) {
        return js_int(0);
    }
    ptr: int = 0;
    n: int = 0;
    hu_span: tuple[int, int] = _view_span(args[1]);
    if hu_span[1] >= 0 {
        ptr = hu_span[0];
        n = hu_span[1];
    } else {
        if len(args) < 3 {
            return js_int(0);
        }
        ptr = _arg_int(args[1]);
        n = _arg_int(args[2]);
    }
    if n == 0 {
        return js_int(1);
    }
    ctx: int = _HASH_CTX_PTR[hid];
    if ctx == 0 {
        return js_int(0);
    }
    if EVP_DigestUpdate(ctx, ptr, n) == 1 {
        return js_int(1);
    }
    return js_int(0);
}

"""args[0]=handle. Returns hex digest string."""
def:pub crypto_hash_final(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_string_id(str_intern(""));
    }
    hid: int = _arg_int(args[0]);
    if hid <= 0 or hid >= len(_HASH_CTX_PTR) {
        return jsv_from_string_id(str_intern(""));
    }
    ctx: int = _HASH_CTX_PTR[hid];
    out_sz: int = _HASH_OUT_SIZE[hid];
    if ctx == 0 or out_sz <= 0 {
        return jsv_from_string_id(str_intern(""));
    }
    out_buf: int = io_alloc(out_sz + 4);
    out_len_ptr: int = io_alloc(4);
    if EVP_DigestFinal_ex(ctx, out_buf, out_len_ptr) != 1 {
        return jsv_from_string_id(str_intern(""));
    }
    hex: str = _ptr_to_hex(out_buf, out_sz);
    EVP_MD_CTX_free(ctx);
    _HASH_CTX_PTR[hid] = 0;
    _HASH_FREE.append(hid);
    return jsv_from_string_id(str_intern(hex));
}

"""args[0]=handle."""
def:pub crypto_hash_free(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    hid: int = _arg_int(args[0]);
    if hid > 0 and hid < len(_HASH_CTX_PTR) {
        ctx: int = _HASH_CTX_PTR[hid];
        if ctx != 0 {
            EVP_MD_CTX_free(ctx);
        }
        _HASH_CTX_PTR[hid] = 0;
        _HASH_FREE.append(hid);
    }
    return js_undefined();
}

"""One-shot digest: args[0]=algo, [1]=ptr, [2]=len → hex."""
def:pub crypto_hash_oneshot(args: list[JSValue]) -> JSValue {
    h: JSValue = crypto_hash_new([args[0]]);
    hid: int = _arg_int(h);
    if hid == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    crypto_hash_update([h, args[1], args[2]]);
    return crypto_hash_final([h]);
}

# ── HMAC ──────────────────────────────────────────────────────────────────────

"""args: algo, keyPtr, keyLen, dataPtr, dataLen → hex."""
def:pub crypto_hmac(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return jsv_from_string_id(str_intern(""));
    }
    algo: str = _arg_str(args[0]);
    md: int = EVP_get_digestbyname(algo);
    if md == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    key_ptr: int = _arg_int(args[1]);
    key_len: int = _arg_int(args[2]);
    data_ptr: int = _arg_int(args[3]);
    data_len: int = _arg_int(args[4]);
    out_sz: int = 64;
    out_buf: int = io_alloc(out_sz + 4);
    md_len_ptr: int = io_alloc(4);
    if HMAC(md, key_ptr, key_len, data_ptr, data_len, out_buf, md_len_ptr) == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    actual_len: int = read_u32(md_len_ptr, 0);
    if actual_len <= 0 or actual_len > out_sz {
        actual_len = out_sz;
    }
    hex: str = _ptr_to_hex(out_buf, actual_len);
    return jsv_from_string_id(str_intern(hex));
}

# ── Random ────────────────────────────────────────────────────────────────────

"""args[0]=byte count. Returns hex string of random bytes."""
def:pub crypto_random_bytes_hex(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_string_id(str_intern(""));
    }
    n: int = _arg_int(args[0]);
    if n <= 0 or n > 1048576 {
        return jsv_from_string_id(str_intern(""));
    }
    buf: int = io_alloc(n + 4);
    if RAND_bytes(buf, n) != 1 {
        return jsv_from_string_id(str_intern(""));
    }
    return jsv_from_string_id(str_intern(_ptr_to_hex(buf, n)));
}

# ── timingSafeEqual ───────────────────────────────────────────────────────────

"""args: ptrA, lenA, ptrB, lenB → bool."""
def:pub crypto_timing_safe_equal(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_false();
    }
    pa: int = _arg_int(args[0]);
    la: int = _arg_int(args[1]);
    pb: int = _arg_int(args[2]);
    lb: int = _arg_int(args[3]);
    if la != lb {
        return js_false();
    }
    if la == 0 {
        return js_true();
    }
    if CRYPTO_memcmp(pa, pb, la) == 0 {
        return js_true();
    }
    return js_false();
}

# ── PBKDF2 ────────────────────────────────────────────────────────────────────

"""args: pass ptr, pass len, salt ptr, salt len, iterations, keylen, digest name → hex key."""
def:pub crypto_pbkdf2(args: list[JSValue]) -> JSValue {
    if len(args) < 7 {
        return jsv_from_string_id(str_intern(""));
    }
    pass_ptr: int = _arg_int(args[0]);
    pass_len: int = _arg_int(args[1]);
    salt_ptr: int = _arg_int(args[2]);
    salt_len: int = _arg_int(args[3]);
    iterations: int = _arg_int(args[4]);
    keylen: int = _arg_int(args[5]);
    digest: str = _arg_str(args[6]);
    md: int = EVP_get_digestbyname(digest);
    if md == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    out: int = io_alloc(keylen + 4);
    if PKCS5_PBKDF2_HMAC(
        pass_ptr, pass_len, salt_ptr, salt_len, iterations, md, keylen, out
    )
        != 1 {
        return jsv_from_string_id(str_intern(""));
    }
    return jsv_from_string_id(str_intern(_ptr_to_hex(out, keylen)));
}

# ── Cipher (encrypt/decrypt one-shot) ─────────────────────────────────────────

"""Encrypt: algo, key ptr, key len, iv ptr, iv len, plain ptr, plain len, [aad ptr, aad len] → hex(out|tag)."""
def:pub crypto_cipher_encrypt(args: list[JSValue]) -> JSValue {
    if len(args) < 7 {
        return jsv_from_string_id(str_intern(""));
    }
    algo: str = _arg_str(args[0]);
    cipher: int = EVP_get_cipherbyname(algo);
    if cipher == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    key_ptr: int = _arg_int(args[1]);
    iv_ptr: int = _arg_int(args[3]);
    plain_ptr: int = _arg_int(args[5]);
    plain_len: int = _arg_int(args[6]);
    ctx: int = EVP_CIPHER_CTX_new();
    if ctx == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    if EVP_EncryptInit_ex(ctx, cipher, 0, key_ptr, iv_ptr) != 1 {
        EVP_CIPHER_CTX_free(ctx);
        return jsv_from_string_id(str_intern(""));
    }
    out_cap: int = plain_len + 32;
    out_buf: int = io_alloc(out_cap);
    outl_ptr: int = io_alloc(4);
    if len(args) >= 9 {
        aad_ptr: int = _arg_int(args[7]);
        aad_len: int = _arg_int(args[8]);
        if aad_len > 0 {
            EVP_CIPHER_CTX_ctrl(ctx, 18, aad_len, aad_ptr);
        }
    }
    if EVP_EncryptUpdate(ctx, out_buf, outl_ptr, plain_ptr, plain_len) != 1 {
        EVP_CIPHER_CTX_free(ctx);
        return jsv_from_string_id(str_intern(""));
    }
    out_len: int = read_u32(outl_ptr, 0);
    fin_ptr: int = out_buf + out_len;
    if EVP_EncryptFinal_ex(ctx, fin_ptr, outl_ptr) != 1 {
        EVP_CIPHER_CTX_free(ctx);
        return jsv_from_string_id(str_intern(""));
    }
    fin_len: int = read_u32(outl_ptr, 0);
    total: int = out_len + fin_len;
    # GCM tag (16 bytes)
    if _is_gcm_algo(algo) {
        tag: int = io_alloc(16);
        EVP_CIPHER_CTX_ctrl(ctx, _EVP_CTRL_AEAD_GET_TAG, 16, tag);
        hex_out: str = _ptr_to_hex(out_buf, total) + _ptr_to_hex(tag, 16);
        EVP_CIPHER_CTX_free(ctx);
        return jsv_from_string_id(str_intern(hex_out));
    }
    EVP_CIPHER_CTX_free(ctx);
    return jsv_from_string_id(str_intern(_ptr_to_hex(out_buf, total)));
}

"""Decrypt: algo, key ptr, iv ptr, ct ptr, ct len, tag hex (GCM) or empty."""
def:pub crypto_cipher_decrypt(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return jsv_from_string_id(str_intern(""));
    }
    algo: str = _arg_str(args[0]);
    cipher: int = EVP_get_cipherbyname(algo);
    if cipher == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    key_ptr: int = _arg_int(args[1]);
    iv_ptr: int = _arg_int(args[2]);
    ct_ptr: int = _arg_int(args[3]);
    ct_len: int = _arg_int(args[4]);
    ctx: int = EVP_CIPHER_CTX_new();
    if ctx == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    if EVP_DecryptInit_ex(ctx, cipher, 0, key_ptr, iv_ptr) != 1 {
        EVP_CIPHER_CTX_free(ctx);
        return jsv_from_string_id(str_intern(""));
    }
    if len(args) >= 6 and _is_gcm_algo(algo) {
        tag_hex: str = _arg_str(args[5]);
        tag_ptr: int = io_alloc(32);
        if _hex_to_ptr(tag_hex, tag_ptr, 32) == 16 {
            EVP_CIPHER_CTX_ctrl(ctx, _EVP_CTRL_AEAD_SET_TAG, 16, tag_ptr);
        }
    }
    out_buf: int = io_alloc(ct_len + 32);
    outl_ptr: int = io_alloc(4);
    if EVP_DecryptUpdate(ctx, out_buf, outl_ptr, ct_ptr, ct_len) != 1 {
        EVP_CIPHER_CTX_free(ctx);
        return jsv_from_string_id(str_intern(""));
    }
    out_len: int = read_u32(outl_ptr, 0);
    fin_ptr: int = out_buf + out_len;
    if EVP_DecryptFinal_ex(ctx, fin_ptr, outl_ptr) != 1 {
        _last_crypto_err = ERR_get_error();
        EVP_CIPHER_CTX_free(ctx);
        return jsv_from_string_id(str_intern(""));
    }
    fin_len: int = read_u32(outl_ptr, 0);
    total: int = out_len + fin_len;
    EVP_CIPHER_CTX_free(ctx);
    return jsv_from_string_id(str_intern(_ptr_to_hex(out_buf, total)));
}

"""Return comma-separated supported hash names (OpenSSL 3 common set)."""
def:pub crypto_get_hashes(args: list[JSValue]) -> JSValue {
    names: str = "sha1,sha224,sha256,sha384,sha512,sha512-224,sha512-256,sha3-224,sha3-256,sha3-384,sha3-512";
    return jsv_from_string_id(str_intern(names));
}

"""Return comma-separated supported cipher names."""
def:pub crypto_get_ciphers(args: list[JSValue]) -> JSValue {
    names: str = "aes-128-cbc,aes-192-cbc,aes-256-cbc,aes-128-ctr,aes-192-ctr,aes-256-ctr,aes-128-gcm,aes-192-gcm,aes-256-gcm";
    return jsv_from_string_id(str_intern(names));
}

"""Return the most recent OpenSSL error code as a JS double.

Checks _last_crypto_err first (captured before EVP_CIPHER_CTX_free in the
decrypt path).  Falls back to ERR_get_error() for other operations (hash,
HMAC, pbkdf2).  Clears the stored code after reading.  Returns 0 when no
error is pending."""
def:pub crypto_get_last_error(args: list[JSValue]) -> JSValue {
    code: int = _last_crypto_err;
    _last_crypto_err = 0;
    if code == 0 {
        code = ERR_get_error();
    }
    return jsv_from_double(float(code));
}

# ── Asymmetric keys (generateKeyPair / KeyObject) ─────────────────────────────
#
# EVP_PKEY* values live in _PKEY_TAB and are referenced from JS by their slot
# index (1-based; slot 0 is reserved as the "invalid handle" sentinel).  JS
# releases a slot with keyFree(); freed slots are recycled through _PKEY_FREE.

glob _PKEY_TAB: list[int] = [0],
     _PKEY_FREE: list[int] = [],
     _BIO_CTRL_PENDING: int = 10;

# BIO_CTRL_PENDING — number of bytes buffered in a memory BIO.
def _pkey_store(pkey: int) -> int {
    if pkey == 0 {
        return 0;
    }
    if len(_PKEY_FREE) > 0 {
        slot: int = _PKEY_FREE[len(_PKEY_FREE) - 1];
        del _PKEY_FREE[len(_PKEY_FREE) - 1];
        _PKEY_TAB[slot] = pkey;
        return slot;
    }
    _PKEY_TAB.append(pkey);
    return len(_PKEY_TAB) - 1;
}

def _pkey_get(handle: int) -> int {
    if handle <= 0 or handle >= len(_PKEY_TAB) {
        return 0;
    }
    return _PKEY_TAB[handle];
}

"""NID for a Node key-type name, or 0 when unsupported."""
def _pkey_type_nid(t: str) -> int {
    if t == "rsa" {
        return 6;
    }
    if t == "ec" {
        return 408;
    }
    if t == "dh" {
        return 28;
    }
    if t == "x25519" {
        return 1034;
    }
    if t == "x448" {
        return 1035;
    }
    if t == "ed25519" {
        return 1087;
    }
    if t == "ed448" {
        return 1088;
    }
    return 0;
}

"""Node key-type name for an EVP_PKEY base NID, or "" when unrecognised."""
def _pkey_nid_name(nid: int) -> str {
    if nid == 6 {
        return "rsa";
    }
    if nid == 912 {
        return "rsa-pss";
    }
    if nid == 408 {
        return "ec";
    }
    if nid == 1034 {
        return "x25519";
    }
    if nid == 1035 {
        return "x448";
    }
    if nid == 1087 {
        return "ed25519";
    }
    if nid == 1088 {
        return "ed448";
    }
    if nid == 116 {
        return "dsa";
    }
    if nid == 28 {
        return "dh";
    }
    return "";
}

def _is_raw_curve_nid(nid: int) -> bool {
    return nid == 1034 or nid == 1035 or nid == 1087 or nid == 1088;
}

"""Drain a memory BIO into a NUL-terminated Jac string (text formats only)."""
def _bio_to_str(bio: int) -> str {
    n: int = BIO_ctrl(bio, _BIO_CTRL_PENDING, 0, 0);
    if n <= 0 {
        return "";
    }
    buf: int = io_alloc(n + 8);
    got: int = BIO_read(bio, buf, n);
    if got <= 0 {
        return "";
    }
    out: str = buf;  # jac:ignore[E1001] pointer reinterpret
    return out;
}

"""Drain a memory BIO into a lowercase hex string (binary formats)."""
def _bio_to_hex(bio: int) -> str {
    n: int = BIO_ctrl(bio, _BIO_CTRL_PENDING, 0, 0);
    if n <= 0 {
        return "";
    }
    buf: int = io_alloc(n + 8);
    got: int = BIO_read(bio, buf, n);
    if got <= 0 {
        return "";
    }
    return _ptr_to_hex(buf, got);
}

"""Generate a key pair.  args: type, modulusLength/primeLength, publicExponent/generator, namedCurve.

Returns a key handle (int) for the freshly generated EVP_PKEY, or 0."""
def:pub crypto_keygen(args: list[JSValue]) -> JSValue {
    if len(args) < 4 {
        return js_int(0);
    }
    ktype: str = _arg_str(args[0]);
    bits: int = _arg_int(args[1]);
    expo: int = _arg_int(args[2]);
    curve: str = _arg_str(args[3]);
    nid: int = _pkey_type_nid(ktype);
    if nid == 0 {
        return js_int(0);
    }

    # Classic DH: paramgen (primeLength + generator) then keygen from params.
    if ktype == "dh" {
        if bits <= 0 {
            bits = 2048;
        }
        gen: int = expo;
        if gen <= 0 {
            gen = 2;
        }
        pctx: int = EVP_PKEY_CTX_new_id(nid, 0);
        if pctx == 0 {
            return js_int(0);
        }
        if EVP_PKEY_paramgen_init(pctx) != 1 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(pctx);
            return js_int(0);
        }
        if EVP_PKEY_CTX_set_dh_paramgen_prime_len(pctx, bits) <= 0 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(pctx);
            return js_int(0);
        }
        if EVP_PKEY_CTX_set_dh_paramgen_generator(pctx, gen) <= 0 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(pctx);
            return js_int(0);
        }
        params_out: int = io_alloc(16);
        if EVP_PKEY_paramgen(pctx, params_out) != 1 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(pctx);
            return js_int(0);
        }
        EVP_PKEY_CTX_free(pctx);
        params_pkey: int = read_ptr(params_out, 0);
        if params_pkey == 0 {
            return js_int(0);
        }
        kctx: int = EVP_PKEY_CTX_new(params_pkey, 0);
        if kctx == 0 {
            EVP_PKEY_free(params_pkey);
            return js_int(0);
        }
        if EVP_PKEY_keygen_init(kctx) != 1 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(kctx);
            EVP_PKEY_free(params_pkey);
            return js_int(0);
        }
        out_dh: int = io_alloc(16);
        if EVP_PKEY_keygen(kctx, out_dh) != 1 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(kctx);
            EVP_PKEY_free(params_pkey);
            return js_int(0);
        }
        EVP_PKEY_CTX_free(kctx);
        EVP_PKEY_free(params_pkey);
        return js_int(_pkey_store(read_ptr(out_dh, 0)));
    }

    ctx: int = EVP_PKEY_CTX_new_id(nid, 0);
    if ctx == 0 {
        return js_int(0);
    }
    if EVP_PKEY_keygen_init(ctx) != 1 {
        _last_crypto_err = ERR_get_error();
        EVP_PKEY_CTX_free(ctx);
        return js_int(0);
    }
    if ktype == "rsa" {
        if bits <= 0 {
            bits = 2048;
        }
        if EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, bits) <= 0 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(ctx);
            return js_int(0);
        }
        if expo > 0 and expo != 65537 {
            bn: int = BN_new();
            if bn == 0 {
                EVP_PKEY_CTX_free(ctx);
                return js_int(0);
            }
            BN_set_word(bn, expo);
            # On success the context takes ownership of `bn`.
            if EVP_PKEY_CTX_set_rsa_keygen_pubexp(ctx, bn) <= 0 {
                _last_crypto_err = ERR_get_error();
                BN_free(bn);
                EVP_PKEY_CTX_free(ctx);
                return js_int(0);
            }
        }
    }
    if ktype == "ec" {
        cnid: int = OBJ_txt2nid(curve);
        if cnid == 0 {
            EVP_PKEY_CTX_free(ctx);
            return js_int(0);
        }
        if EVP_PKEY_CTX_set_ec_paramgen_curve_nid(ctx, cnid) <= 0 {
            _last_crypto_err = ERR_get_error();
            EVP_PKEY_CTX_free(ctx);
            return js_int(0);
        }
    }
    out: int = io_alloc(16);
    if EVP_PKEY_keygen(ctx, out) != 1 {
        _last_crypto_err = ERR_get_error();
        EVP_PKEY_CTX_free(ctx);
        return js_int(0);
    }
    EVP_PKEY_CTX_free(ctx);
    return js_int(_pkey_store(read_ptr(out, 0)));
}

def _import_pem(ptr: int, nbytes: int, want_private: bool) -> int {
    bio: int = BIO_new_mem_buf(ptr, nbytes);
    if bio == 0 {
        return 0;
    }
    if want_private {
        pkey: int = PEM_read_bio_PrivateKey(bio, 0, 0, 0);
        BIO_free(bio);
        return pkey;
    }
    pub_key: int = PEM_read_bio_PUBKEY(bio, 0, 0, 0);
    BIO_free(bio);
    if pub_key != 0 {
        return pub_key;
    }
    # Fall back to a PKCS#1 RSA public key, then to a private key whose public
    # half we lift out (Node allows createPublicKey(privateKeyPem)).
    ERR_get_error();
    bio2: int = BIO_new_mem_buf(ptr, nbytes);
    if bio2 == 0 {
        return 0;
    }
    rsa: int = PEM_read_bio_RSAPublicKey(bio2, 0, 0, 0);
    BIO_free(bio2);
    if rsa != 0 {
        wrapped: int = EVP_PKEY_new();
        if wrapped == 0 {
            RSA_free(rsa);
            return 0;
        }
        ok: int = EVP_PKEY_set1_RSA(wrapped, rsa);
        RSA_free(rsa);
        if ok != 1 {
            EVP_PKEY_free(wrapped);
            return 0;
        }
        return wrapped;
    }
    ERR_get_error();
    bio3: int = BIO_new_mem_buf(ptr, nbytes);
    if bio3 == 0 {
        return 0;
    }
    priv_key: int = PEM_read_bio_PrivateKey(bio3, 0, 0, 0);
    BIO_free(bio3);
    if priv_key == 0 {
        return 0;
    }
    derived: int = _public_part(priv_key);
    EVP_PKEY_free(priv_key);
    return derived;
}

def _import_der(ptr: int, nbytes: int, want_private: bool, kind: str) -> int {
    bio: int = BIO_new_mem_buf(ptr, nbytes);
    if bio == 0 {
        return 0;
    }
    if want_private {
        # d2i_PrivateKey_bio auto-detects PKCS#8, PKCS#1 and SEC1.
        pkey: int = d2i_PrivateKey_bio(bio, 0);
        BIO_free(bio);
        return pkey;
    }
    if kind == "pkcs1" {
        rsa: int = d2i_RSAPublicKey_bio(bio, 0);
        BIO_free(bio);
        if rsa == 0 {
            return 0;
        }
        wrapped: int = EVP_PKEY_new();
        if wrapped == 0 {
            RSA_free(rsa);
            return 0;
        }
        ok: int = EVP_PKEY_set1_RSA(wrapped, rsa);
        RSA_free(rsa);
        if ok != 1 {
            EVP_PKEY_free(wrapped);
            return 0;
        }
        return wrapped;
    }
    pub_key: int = d2i_PUBKEY_bio(bio, 0);
    BIO_free(bio);
    if pub_key != 0 {
        return pub_key;
    }
    ERR_get_error();
    bio2: int = BIO_new_mem_buf(ptr, nbytes);
    if bio2 == 0 {
        return 0;
    }
    priv_key: int = d2i_PrivateKey_bio(bio2, 0);
    BIO_free(bio2);
    if priv_key == 0 {
        return 0;
    }
    derived: int = _public_part(priv_key);
    EVP_PKEY_free(priv_key);
    return derived;
}

"""Round-trip a key through SPKI DER so only the public half survives."""
def _public_part(pkey: int) -> int {
    bio: int = BIO_new(BIO_s_mem());
    if bio == 0 {
        return 0;
    }
    if i2d_PUBKEY_bio(bio, pkey) != 1 {
        _last_crypto_err = ERR_get_error();
        BIO_free(bio);
        return 0;
    }
    pub_key: int = d2i_PUBKEY_bio(bio, 0);
    BIO_free(bio);
    return pub_key;
}

"""Import a key.  args: ptr, len, format, kind, typeName, curveName.

format is "pem", "der", "raw-public" or "raw-private"; kind is "private" or
"public"; typeName/curveName are only consulted for the raw formats.
Returns a key handle, or 0 on failure."""
def:pub crypto_key_import(args: list[JSValue]) -> JSValue {
    if len(args) < 6 {
        return js_int(0);
    }
    ptr: int = _arg_int(args[0]);
    nbytes: int = _arg_int(args[1]);
    fmt: str = _arg_str(args[2]);
    kind: str = _arg_str(args[3]);
    type_name: str = _arg_str(args[4]);
    want_private: bool = kind == "private";
    pkey: int = 0;
    if fmt == "pem" {
        pkey = _import_pem(ptr, nbytes, want_private);
    } elif fmt == "der" {
        pkey = _import_der(ptr, nbytes, want_private, kind);
    } elif fmt == "raw-public" or fmt == "raw-private" {
        nid: int = _pkey_type_nid(type_name);
        if not _is_raw_curve_nid(nid) {
            return js_int(0);
        }
        if fmt == "raw-public" {
            pkey = EVP_PKEY_new_raw_public_key(nid, 0, ptr, nbytes);
        } else {
            pkey = EVP_PKEY_new_raw_private_key(nid, 0, ptr, nbytes);
        }
    }
    if pkey == 0 {
        _last_crypto_err = ERR_get_error();
        return js_int(0);
    }
    return js_int(_pkey_store(pkey));
}

"""args[0]=handle → new handle holding only the public half (0 on failure)."""
def:pub crypto_key_public_of(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_int(0);
    }
    pkey: int = _pkey_get(_arg_int(args[0]));
    if pkey == 0 {
        return js_int(0);
    }
    return js_int(_pkey_store(_public_part(pkey)));
}

def _raw_export(pkey: int, want_private: bool) -> str {
    base: int = EVP_PKEY_get_base_id(pkey);
    len_ptr: int = io_alloc(16);
    if base == 408 {
        if want_private {
            return "";
        }
        # EC public points are only reachable through the provider param API.
        buf: int = io_alloc(256);
        if EVP_PKEY_get_octet_string_param(pkey, "encoded-pub-key", buf, 248, len_ptr)
            != 1 {
            _last_crypto_err = ERR_get_error();
            return "";
        }
        return _ptr_to_hex(buf, read_ptr(len_ptr, 0));
    }
    if not _is_raw_curve_nid(base) {
        return "";
    }
    probe: int = 0;
    if want_private {
        probe = EVP_PKEY_get_raw_private_key(pkey, 0, len_ptr);
    } else {
        probe = EVP_PKEY_get_raw_public_key(pkey, 0, len_ptr);
    }
    if probe != 1 {
        _last_crypto_err = ERR_get_error();
        return "";
    }
    n: int = read_ptr(len_ptr, 0);
    if n <= 0 or n > 1024 {
        return "";
    }
    out: int = io_alloc(n + 8);
    write_i64(len_ptr, 0, n);
    got: int = 0;
    if want_private {
        got = EVP_PKEY_get_raw_private_key(pkey, out, len_ptr);
    } else {
        got = EVP_PKEY_get_raw_public_key(pkey, out, len_ptr);
    }
    if got != 1 {
        _last_crypto_err = ERR_get_error();
        return "";
    }
    return _ptr_to_hex(out, read_ptr(len_ptr, 0));
}

"""Copy a Jac string into a freshly calloc'd C buffer (NUL-terminated).
Returns 0 when s is empty. Caller must free() the result."""
def _str_cbuf(s: str) -> int {
    n: int = len(s);
    if n <= 0 {
        return 0;
    }
    buf: int = calloc(1, n + 1);
    if buf == 0 {
        return 0;
    }
    i: int = 0;
    while i < n {
        write_byte(buf, i, ord(s[i]));
        i = i + 1;
    }
    return buf;
}

"""Serialise a key.  args: handle, kind, format[, cipher, passphrase].

kind is one of "pkcs8", "pkcs1", "sec1" (private), "spki", "pkcs1-public"
(public), "raw-public" or "raw-private".  format is "pem" or "der"; DER (and
every raw form) is returned as lowercase hex.  Optional cipher+passphrase
enable encrypted private-key export.  Returns "" on failure."""
def:pub crypto_key_export(args: list[JSValue]) -> JSValue {
    if len(args) < 3 {
        return jsv_from_string_id(str_intern(""));
    }
    pkey: int = _pkey_get(_arg_int(args[0]));
    kind: str = _arg_str(args[1]);
    fmt: str = _arg_str(args[2]);
    cipher_name: str = "";
    passphrase: str = "";
    if len(args) >= 4 {
        cipher_name = _arg_str(args[3]);
    }
    if len(args) >= 5 {
        passphrase = _arg_str(args[4]);
    }
    if pkey == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    if kind == "raw-public" {
        return jsv_from_string_id(str_intern(_raw_export(pkey, False)));
    }
    if kind == "raw-private" {
        return jsv_from_string_id(str_intern(_raw_export(pkey, True)));
    }
    enc: int = 0;
    kstr: int = 0;
    klen: int = 0;
    if cipher_name != "" {
        enc = EVP_get_cipherbyname(cipher_name);
        if enc == 0 {
            _last_crypto_err = ERR_get_error();
            return jsv_from_string_id(str_intern(""));
        }
        klen = len(passphrase);
        kstr = _str_cbuf(passphrase);
        # Empty passphrase is legal (Node allows it); pass a non-NULL 0-length buf.
        if kstr == 0 {
            kstr = calloc(1, 1);
            klen = 0;
        }
    }
    bio: int = BIO_new(BIO_s_mem());
    if bio == 0 {
        if kstr != 0 {
            free(kstr);
        }
        return jsv_from_string_id(str_intern(""));
    }
    is_pem: bool = fmt == "pem";
    rc: int = 0;
    rsa: int = 0;
    if kind == "pkcs1-public" {
        rsa = EVP_PKEY_get1_RSA(pkey);
        if rsa == 0 {
            _last_crypto_err = ERR_get_error();
            BIO_free(bio);
            if kstr != 0 {
                free(kstr);
            }
            return jsv_from_string_id(str_intern(""));
        }
        if is_pem {
            rc = PEM_write_bio_RSAPublicKey(bio, rsa);
        } else {
            rc = i2d_RSAPublicKey_bio(bio, rsa);
        }
        RSA_free(rsa);
    } elif kind == "spki" {
        if is_pem {
            rc = PEM_write_bio_PUBKEY(bio, pkey);
        } else {
            rc = i2d_PUBKEY_bio(bio, pkey);
        }
    } elif kind == "pkcs8" {
        if is_pem {
            rc = PEM_write_bio_PrivateKey(bio, pkey, enc, kstr, klen, 0, 0);
        } elif enc != 0 {
            rc = i2d_PKCS8PrivateKey_bio(bio, pkey, enc, kstr, klen, 0, 0);
        } else {
            rc = i2d_PKCS8PrivateKeyInfo_bio(bio, pkey);
        }
    } elif kind == "pkcs1" or kind == "sec1" {
        if is_pem {
            rc = PEM_write_bio_PrivateKey_traditional(bio, pkey, enc, kstr, klen, 0, 0);
        } else {
            rc = i2d_PrivateKey_bio(bio, pkey);
        }
    }
    if kstr != 0 {
        free(kstr);
    }
    if rc != 1 {
        _last_crypto_err = ERR_get_error();
        BIO_free(bio);
        return jsv_from_string_id(str_intern(""));
    }
    result: str = "";
    if is_pem {
        result = _bio_to_str(bio);
    } else {
        result = _bio_to_hex(bio);
    }
    BIO_free(bio);
    return jsv_from_string_id(str_intern(result));
}

"""args[0]=handle → "type|bits|publicExponent|curveName" ("" when invalid)."""
def:pub crypto_key_info(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return jsv_from_string_id(str_intern(""));
    }
    pkey: int = _pkey_get(_arg_int(args[0]));
    if pkey == 0 {
        return jsv_from_string_id(str_intern(""));
    }
    base: int = EVP_PKEY_get_base_id(pkey);
    name: str = _pkey_nid_name(base);
    bits: int = EVP_PKEY_get_bits(pkey);
    expo: int = 0;
    curve: str = "";
    if base == 6 or base == 912 {
        bn_ptr: int = io_alloc(16);
        if EVP_PKEY_get_bn_param(pkey, "e", bn_ptr) == 1 {
            bn: int = read_ptr(bn_ptr, 0);
            if bn != 0 {
                expo = BN_get_word(bn);
                BN_free(bn);
            }
        } else {
            ERR_get_error();
        }
    }
    if base == 408 {
        cbuf: int = io_alloc(128);
        clen: int = io_alloc(16);
        if EVP_PKEY_get_utf8_string_param(pkey, "group", cbuf, 120, clen) == 1 {
            cstr: str = cbuf;  # jac:ignore[E1001] pointer reinterpret
            curve = cstr;
        } else {
            ERR_get_error();
        }
    }
    info: str = name + "|" + str(bits) + "|" + str(expo) + "|" + curve;
    return jsv_from_string_id(str_intern(info));
}

"""args: handleA, handleB → true when both keys hold the same public material."""
def:pub crypto_key_equals(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        return js_false();
    }
    a: int = _pkey_get(_arg_int(args[0]));
    b: int = _pkey_get(_arg_int(args[1]));
    if a == 0 or b == 0 {
        return js_false();
    }
    if EVP_PKEY_eq(a, b) == 1 {
        return js_true();
    }
    ERR_get_error();
    return js_false();
}

"""args[0]=handle. Frees the EVP_PKEY and recycles the slot."""
def:pub crypto_key_free(args: list[JSValue]) -> JSValue {
    if len(args) < 1 {
        return js_undefined();
    }
    handle: int = _arg_int(args[0]);
    if handle > 0 and handle < len(_PKEY_TAB) {
        pkey: int = _PKEY_TAB[handle];
        if pkey != 0 {
            EVP_PKEY_free(pkey);
            _PKEY_TAB[handle] = 0;
            _PKEY_FREE.append(handle);
        }
    }
    return js_undefined();
}
