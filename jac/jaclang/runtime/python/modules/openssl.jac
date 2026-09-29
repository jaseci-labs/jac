"""The OpenSSL API of the native _ssl and _hashlib modules.

Both ports call libssl and libcrypto (the vendored OpenSSL the JacPython build
links) directly. The declarations name the exported functions; where CPython's
C calls a macro or a static inline function, the port calls what it expands to
(EVP_MD_size is EVP_MD_get_size, SSL_set_tlsext_host_name is an SSL_ctrl), and
the few inline functions with logic (ERR_GET_LIB, ERR_GET_REASON) are Jac here.
The macro values are generated in openssl_constants.jac. OpenSSL objects are
opaque `ptr`s; a C string OpenSSL returns is a `ptr[u8]`.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Format,
    PyErr_SetString,
    PyObject
}
import from jaclang.runtime.python.capi { c_string_copy }
import from jaclang.runtime.python.modules.openssl_constants {
    ERR_LIB_MASK,
    ERR_LIB_OFFSET,
    ERR_LIB_SYS,
    ERR_REASON_MASK,
    ERR_SYSTEM_FLAG,
    ERR_SYSTEM_MASK
}

import from c {
    # crypto.h, err.h
    def OpenSSL_version_num -> u64;  def OpenSSL_version(kind: i32) -> ptr[u8];  def CRYPTO_free(
        address: ptr, file: str, line: i32
    );  def CRYPTO_memcmp(a: ptr, b: ptr, size: u64) -> i32;  def ERR_get_error -> u64;  def ERR_peek_last_error -> u64;  def ERR_clear_error;  def ERR_lib_error_string(
        code: u64
    ) -> ptr[u8];  def ERR_func_error_string(code: u64) -> ptr[u8];  def ERR_reason_error_string(
        code: u64
    ) -> ptr[u8];
    # evp.h
    def EVP_MD_fetch(context: ptr, algorithm: str, properties: ptr[u8]) -> ptr;  def EVP_MD_up_ref(
        md: ptr
    ) -> i32;  def EVP_MD_free(md: ptr);  def EVP_MD_get_type(md: ptr) -> i32;  def EVP_MD_get_size(
        md: ptr
    ) -> i32;  def EVP_MD_get_block_size(md: ptr) -> i32;  def EVP_MD_get_flags(
        md: ptr
    ) -> u64;  def EVP_MD_do_all_provided(
        context: ptr, callback: Callable[[ptr, ptr], None], argument: ptr
    );  def EVP_MD_CTX_new -> ptr;  def EVP_MD_CTX_free(context: ptr);  def EVP_MD_CTX_copy(
        target: ptr, source: ptr
    ) -> i32;  def EVP_MD_CTX_get0_md(context: ptr) -> ptr;  def EVP_MD_CTX_get_size_ex(
        context: ptr
    ) -> i32;  def EVP_DigestInit_ex(context: ptr, md: ptr, engine: ptr) -> i32;  def EVP_DigestUpdate(
        context: ptr, data: ptr, size: u64
    ) -> i32;  def EVP_DigestFinal(context: ptr, output: ptr, size: ptr) -> i32;  def EVP_DigestFinalXOF(
        context: ptr, output: ptr, size: u64
    ) -> i32;  def EVP_default_properties_is_fips_enabled(context: ptr) -> i32;  def PKCS5_PBKDF2_HMAC(
        password: ptr,
        password_length: i32,
        salt: ptr,
        salt_length: i32,
        iterations: i32,
        md: ptr,
        key_length: i32,
        key: ptr
    ) -> i32;  def EVP_PBE_scrypt(
        password: ptr,
        password_length: u64,
        salt: ptr,
        salt_length: u64,
        n: u64,
        r: u64,
        p: u64,
        maxmem: u64,
        key: ptr,
        key_length: u64
    ) -> i32;
    # hmac.h
    def HMAC(
        md: ptr,
        key: ptr,
        key_length: i32,
        data: ptr,
        data_length: u64,
        output: ptr,
        output_length: &mut u32
    ) -> ptr;  def HMAC_CTX_new -> ptr;  def HMAC_CTX_free(context: ptr);  def HMAC_CTX_copy(
        target: ptr, source: ptr
    ) -> i32;  def HMAC_CTX_get_md(context: ptr) -> ptr;  def HMAC_Init_ex(
        context: ptr, key: ptr, key_length: i32, md: ptr, engine: ptr
    ) -> i32;  def HMAC_Update(context: ptr, data: ptr, size: u64) -> i32;  def HMAC_Final(
        context: ptr, output: ptr, size: &mut u32
    ) -> i32;
    # objects.h
    def OBJ_nid2ln(nid: i32) -> ptr[u8];  def OBJ_nid2sn(nid: i32) -> ptr[u8];
}

"""OPENSSL_free()."""
def openssl_free(address: ptr) {
    CRYPTO_free(address, "", i32(0));
}

"""ERR_GET_LIB()."""
def err_get_lib(code: u64) -> i64 {
    if (code & u64(ERR_SYSTEM_FLAG)) != 0 {
        return ERR_LIB_SYS;
    }
    return i64((code >> u64(ERR_LIB_OFFSET)) & u64(ERR_LIB_MASK));
}

"""ERR_GET_REASON()."""
def err_get_reason(code: u64) -> i64 {
    if (code & u64(ERR_SYSTEM_FLAG)) != 0 {
        return i64(code & u64(ERR_SYSTEM_MASK));
    }
    return i64(code & u64(ERR_REASON_MASK));
}
