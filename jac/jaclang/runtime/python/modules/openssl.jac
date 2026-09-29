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

import from c {
    # asn1.h, x509v3.h
    def ASN1_OBJECT_free(value: ptr);  def ASN1_OCTET_STRING_free(value: ptr);  def ASN1_STRING_get0_data(
        value: ptr
    ) -> ptr[u8];  def ASN1_STRING_length(value: ptr) -> i32;  def ASN1_STRING_to_UTF8(
        out: &mut ptr[u8], value: ptr
    ) -> i32;  def ASN1_STRING_type(value: ptr) -> i32;  def ASN1_TIME_print(
        bio: ptr, time: ptr
    ) -> i32;  def AUTHORITY_INFO_ACCESS_free(value: ptr);  def CRL_DIST_POINTS_free(
        value: ptr
    );  def GENERAL_NAMES_free(value: ptr);  def GENERAL_NAME_print(
        bio: ptr, name: ptr
    ) -> i32;  def a2i_IPADDRESS(text: ptr[u8]) -> ptr;  def i2a_ASN1_INTEGER(
        bio: ptr, value: ptr
    ) -> i32;  def i2t_ASN1_OBJECT(buf: ptr, size: i32, value: ptr) -> i32;
    # bio.h
    def BIO_clear_flags(bio: ptr, flags: i32);  def BIO_ctrl(
        bio: ptr, command: i32, larg: i64, parg: ptr
    ) -> i64;  def BIO_ctrl_pending(bio: ptr) -> u64;  def BIO_free(bio: ptr) -> i32;  def BIO_free_all(
        bio: ptr
    );  def BIO_gets(bio: ptr, buf: ptr[u8], size: i32) -> i32;  def BIO_new(
        method: ptr
    ) -> ptr;  def BIO_new_fp(stream: ptr, close_flag: i32) -> ptr;  def BIO_new_mem_buf(
        buf: ptr, length: i32
    ) -> ptr;  def BIO_printf(bio: ptr, format_: ptr[u8], *args: any) -> i32;  def BIO_puts(
        bio: ptr, text: ptr[u8]
    ) -> i32;  def BIO_read(bio: ptr, data: ptr, length: i32) -> i32;  def BIO_s_file -> ptr;  def BIO_s_mem -> ptr;  def BIO_set_flags(
        bio: ptr, flags: i32
    );  def BIO_up_ref(bio: ptr) -> i32;  def BIO_write(
        bio: ptr, data: ptr, length: i32
    ) -> i32;
    # comp.h, dh.h, pem.h, rand.h
    def COMP_get_type(method: ptr) -> i32;  def DH_free(dh: ptr);  def PEM_read_DHparams(
        stream: ptr, x: ptr, callback: ptr, userdata: ptr
    ) -> ptr;  def PEM_read_bio_X509(
        bio: ptr, x: ptr, callback: ptr, userdata: ptr
    ) -> ptr;  def PEM_write_bio_X509(bio: ptr, x: ptr) -> i32;  def PEM_write_bio_X509_AUX(
        bio: ptr, x: ptr
    ) -> i32;  def RAND_add(buf: ptr, size: i32, randomness: f64);  def RAND_bytes(
        buf: ptr, size: i32
    ) -> i32;  def RAND_status -> i32;
    # objects.h
    def OBJ_nid2obj(nid: i32) -> ptr;  def OBJ_obj2nid(value: ptr) -> i32;  def OBJ_obj2txt(
        buf: ptr, size: i32, value: ptr, no_name: i32
    ) -> i32;  def OBJ_sn2nid(name: ptr[u8]) -> i32;  def OBJ_txt2obj(
        text: str, no_name: i32
    ) -> ptr;
    # stack.h
    def OPENSSL_sk_find(stack: ptr, data: ptr) -> i32;  def OPENSSL_sk_free(
        stack: ptr
    );  def OPENSSL_sk_num(stack: ptr) -> i32;  def OPENSSL_sk_value(
        stack: ptr, index: i32
    ) -> ptr;
    # ssl.h: ciphers
    def SSL_CIPHER_description(cipher: ptr, buf: ptr[u8], size: i32) -> ptr[u8];  def SSL_CIPHER_get_auth_nid(
        cipher: ptr
    ) -> i32;  def SSL_CIPHER_get_bits(cipher: ptr, alg_bits: &mut i32 | None) -> i32;  def SSL_CIPHER_get_cipher_nid(
        cipher: ptr
    ) -> i32;  def SSL_CIPHER_get_digest_nid(cipher: ptr) -> i32;  def SSL_CIPHER_get_id(
        cipher: ptr
    ) -> u32;  def SSL_CIPHER_get_kx_nid(cipher: ptr) -> i32;  def SSL_CIPHER_get_name(
        cipher: ptr
    ) -> ptr[u8];  def SSL_CIPHER_get_version(cipher: ptr) -> ptr[u8];  def SSL_CIPHER_is_aead(
        cipher: ptr
    ) -> i32;
    # ssl.h: contexts
    def SSL_CTX_callback_ctrl(ctx: ptr, command: i32, callback: ptr) -> i64;  def SSL_CTX_check_private_key(
        ctx: ptr
    ) -> i32;  def SSL_CTX_clear_options(ctx: ptr, options: u64) -> u64;  def SSL_CTX_ctrl(
        ctx: ptr, command: i32, larg: i64, parg: ptr
    ) -> i64;  def SSL_CTX_free(ctx: ptr);  def SSL_CTX_get0_param(ctx: ptr) -> ptr;  def SSL_CTX_get_cert_store(
        ctx: ptr
    ) -> ptr;  def SSL_CTX_get_default_passwd_cb(ctx: ptr) -> ptr;  def SSL_CTX_get_default_passwd_cb_userdata(
        ctx: ptr
    ) -> ptr;  def SSL_CTX_get_num_tickets(ctx: ptr) -> u64;  def SSL_CTX_get_options(
        ctx: ptr
    ) -> u64;  def SSL_CTX_get_security_level(ctx: ptr) -> i32;  def SSL_CTX_get_verify_mode(
        ctx: ptr
    ) -> i32;  def SSL_CTX_load_verify_locations(
        ctx: ptr, cafile: ptr[u8], capath: ptr[u8]
    ) -> i32;  def SSL_CTX_new(method: ptr) -> ptr;  def SSL_CTX_set_alpn_protos(
        ctx: ptr, protos: ptr, length: u32
    ) -> i32;  def SSL_CTX_set_alpn_select_cb(ctx: ptr, callback: ptr, argument: ptr);  def SSL_CTX_set_cipher_list(
        ctx: ptr, text: str
    ) -> i32;  def SSL_CTX_set_default_passwd_cb(ctx: ptr, callback: ptr);  def SSL_CTX_set_default_passwd_cb_userdata(
        ctx: ptr, userdata: ptr
    );  def SSL_CTX_set_default_verify_paths(ctx: ptr) -> i32;  def SSL_CTX_set_keylog_callback(
        ctx: ptr, callback: ptr
    );  def SSL_CTX_set_msg_callback(ctx: ptr, callback: ptr);  def SSL_CTX_set_num_tickets(
        ctx: ptr, count: u64
    ) -> i32;  def SSL_CTX_set_options(ctx: ptr, options: u64) -> u64;  def SSL_CTX_set_post_handshake_auth(
        ctx: ptr, value: i32
    );  def SSL_CTX_set_psk_client_callback(ctx: ptr, callback: ptr);  def SSL_CTX_set_psk_server_callback(
        ctx: ptr, callback: ptr
    );  def SSL_CTX_set_verify(ctx: ptr, mode: i32, callback: ptr);  def SSL_CTX_use_PrivateKey_file(
        ctx: ptr, file: ptr[u8], kind: i32
    ) -> i32;  def SSL_CTX_use_certificate_chain_file(ctx: ptr, file: ptr[u8]) -> i32;  def SSL_CTX_use_psk_identity_hint(
        ctx: ptr, hint: ptr[u8]
    ) -> i32;
    # ssl.h: sessions
    def SSL_SESSION_free(session: ptr);  def SSL_SESSION_get_id(
        session: ptr, length: &mut u32
    ) -> ptr[u8];  def SSL_SESSION_get_ticket_lifetime_hint(session: ptr) -> u64;  def SSL_SESSION_get_time_ex(
        session: ptr
    ) -> i64;  def SSL_SESSION_get_timeout(session: ptr) -> i64;  def SSL_SESSION_has_ticket(
        session: ptr
    ) -> i32;
    # ssl.h: connections
    def SSL_ctrl(ssl: ptr, command: i32, larg: i64, parg: ptr) -> i64;  def SSL_do_handshake(
        ssl: ptr
    ) -> i32;  def SSL_free(ssl: ptr);  def SSL_get0_alpn_selected(
        ssl: ptr, data: &mut ptr[u8], length: &mut u32
    );  def SSL_get0_param(ssl: ptr) -> ptr;  def SSL_get0_verified_chain(
        ssl: ptr
    ) -> ptr;  def SSL_get1_peer_certificate(ssl: ptr) -> ptr;  def SSL_get1_session(
        ssl: ptr
    ) -> ptr;  def SSL_get_SSL_CTX(ssl: ptr) -> ptr;  def SSL_get_ciphers(
        ssl: ptr
    ) -> ptr;  def SSL_get_client_ciphers(ssl: ptr) -> ptr;  def SSL_get_current_cipher(
        ssl: ptr
    ) -> ptr;  def SSL_get_current_compression(ssl: ptr) -> ptr;  def SSL_get_error(
        ssl: ptr, ret_code: i32
    ) -> i32;  def SSL_get_ex_data(ssl: ptr, index: i32) -> ptr;  def SSL_get_finished(
        ssl: ptr, buf: ptr, count: u64
    ) -> u64;  def SSL_get_peer_cert_chain(ssl: ptr) -> ptr;  def SSL_get_peer_finished(
        ssl: ptr, buf: ptr, count: u64
    ) -> u64;  def SSL_get_rbio(ssl: ptr) -> ptr;  def SSL_get_servername(
        ssl: ptr, kind: i32
    ) -> ptr[u8];  def SSL_get_shutdown(ssl: ptr) -> i32;  def SSL_get_verify_mode(
        ssl: ptr
    ) -> i32;  def SSL_get_verify_result(ssl: ptr) -> i64;  def SSL_get_version(
        ssl: ptr
    ) -> ptr[u8];  def SSL_get_wbio(ssl: ptr) -> ptr;  def SSL_is_init_finished(
        ssl: ptr
    ) -> i32;  def SSL_new(ctx: ptr) -> ptr;  def SSL_pending(ssl: ptr) -> i32;  def SSL_read_ex(
        ssl: ptr, buf: ptr, count: u64, readbytes: &mut u64
    ) -> i32;  def SSL_select_next_proto(
        out: ptr[ptr[u8]],
        outlen: ptr[u8],
        server: ptr[u8],
        server_len: u32,
        client: ptr[u8],
        client_len: u32
    ) -> i32;  def SSL_session_reused(ssl: ptr) -> i32;  def SSL_set_SSL_CTX(
        ssl: ptr, ctx: ptr
    ) -> ptr;  def SSL_set_accept_state(ssl: ptr);  def SSL_set_bio(
        ssl: ptr, rbio: ptr, wbio: ptr
    );  def SSL_set_connect_state(ssl: ptr);  def SSL_set_ex_data(
        ssl: ptr, index: i32, data: ptr
    ) -> i32;  def SSL_set_fd(ssl: ptr, fd: i32) -> i32;  def SSL_set_msg_callback(
        ssl: ptr, callback: ptr
    );  def SSL_set_post_handshake_auth(ssl: ptr, value: i32);  def SSL_set_read_ahead(
        ssl: ptr, yes: i32
    );  def SSL_set_session(ssl: ptr, session: ptr) -> i32;  def SSL_set_session_id_context(
        ssl: ptr, context: ptr[u8], length: u32
    ) -> i32;  def SSL_set_shutdown(ssl: ptr, mode: i32);  def SSL_set_verify(
        ssl: ptr, mode: i32, callback: ptr
    );  def SSL_shutdown(ssl: ptr) -> i32;  def SSL_verify_client_post_handshake(
        ssl: ptr
    ) -> i32;  def SSL_write_ex(
        ssl: ptr, buf: ptr, count: u64, written: &mut u64
    ) -> i32;  def TLS_client_method -> ptr;  def TLS_method -> ptr;  def TLS_server_method -> ptr;  def TLSv1_1_method -> ptr;  def TLSv1_2_method -> ptr;  def TLSv1_method -> ptr;
    # x509.h, x509_vfy.h
    def X509_NAME_ENTRY_get_data(entry_: ptr) -> ptr;  def X509_NAME_ENTRY_get_object(
        entry_: ptr
    ) -> ptr;  def X509_NAME_ENTRY_set(entry_: ptr) -> i32;  def X509_NAME_entry_count(
        name: ptr
    ) -> i32;  def X509_NAME_get_entry(name: ptr, location: i32) -> ptr;  def X509_NAME_print_ex(
        bio: ptr, name: ptr, indent: i32, flags: u64
    ) -> i32;  def X509_OBJECT_free(value: ptr);  def X509_OBJECT_get0_X509(
        value: ptr
    ) -> ptr;  def X509_OBJECT_get_type(value: ptr) -> i32;  def X509_STORE_add_cert(
        store: ptr, x: ptr
    ) -> i32;  def X509_STORE_get1_objects(store: ptr) -> ptr;  def X509_VERIFY_PARAM_clear_flags(
        param: ptr, flags: u64
    ) -> i32;  def X509_VERIFY_PARAM_get_flags(param: ptr) -> u64;  def X509_VERIFY_PARAM_get_hostflags(
        param: ptr
    ) -> u32;  def X509_VERIFY_PARAM_set1_host(
        param: ptr, name: ptr[u8], length: u64
    ) -> i32;  def X509_VERIFY_PARAM_set1_ip(
        param: ptr, ip: ptr[u8], length: u64
    ) -> i32;  def X509_VERIFY_PARAM_set_flags(param: ptr, flags: u64) -> i32;  def X509_VERIFY_PARAM_set_hostflags(
        param: ptr, flags: u32
    );  def X509_check_ca(x: ptr) -> i32;  def X509_cmp(a: ptr, b: ptr) -> i32;  def X509_free(
        x: ptr
    );  def X509_get0_notAfter(x: ptr) -> ptr;  def X509_get0_notBefore(
        x: ptr
    ) -> ptr;  def X509_get_default_cert_dir -> ptr[u8];  def X509_get_default_cert_dir_env -> ptr[
        u8
    ];  def X509_get_default_cert_file -> ptr[u8];  def X509_get_default_cert_file_env -> ptr[
        u8
    ];  def X509_get_ext_d2i(x: ptr, nid: i32, critical: ptr, index: ptr) -> ptr;  def X509_get_issuer_name(
        x: ptr
    ) -> ptr;  def X509_get_serialNumber(x: ptr) -> ptr;  def X509_get_subject_name(
        x: ptr
    ) -> ptr;  def X509_get_version(x: ptr) -> i64;  def X509_subject_name_hash(
        x: ptr
    ) -> u64;  def X509_up_ref(x: ptr) -> i32;  def X509_verify_cert_error_string(
        code: i64
    ) -> ptr[u8];  def d2i_X509_bio(bio: ptr, x: ptr) -> ptr;  def i2d_X509(
        x: ptr, out: &mut ptr[u8]
    ) -> i32;  def i2d_X509_bio(bio: ptr, x: ptr) -> i32;
    # stdio.h
    def fclose(stream: ptr) -> i32;
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
