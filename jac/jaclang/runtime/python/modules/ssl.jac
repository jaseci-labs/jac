"""The _ssl module: TLS/SSL wrapper for socket objects.

Derived from CPython 3.14.6 Modules/_ssl.c and Modules/_ssl/cert.c,
debughelpers.c and misc.c; see ../LICENSE.cpython. The Argument Clinic
methods' _impl functions keep their C names and live here; the machinery
they share is in ssl_core.jac and certificate decoding in ssl_cert.jac.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyArg_ParseTuple,
    PyErr_BadArgument,
    PyErr_BadInternalCall,
    PyExc_NotImplementedError,
    PyList_Append,
    PyMutex_Lock,
    PyMutex_Unlock,
    PyThreadState,
    PyThread_acquire_lock,
    PyThread_release_lock,
    PyUnicode_FSConverter,
    PyArg_Parse,
    PyBytes_AsString,
    PyBytes_AsStringAndSize,
    PyBytes_FromString,
    PyCallable_Check,
    PyDict_New,
    PyDict_SetItemString,
    PyErr_CheckSignals,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_FormatUnraisable,
    PyErr_GetRaisedException,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyErr_SetFromErrnoWithFilenameObject,
    PyErr_SetObject,
    PyErr_SetString,
    PyErr_WarnEx,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_AttributeError,
    PyExc_DeprecationWarning,
    PyExc_MemoryError,
    PyExc_OSError,
    PyExc_OverflowError,
    PyExc_RuntimeError,
    PyExc_TimeoutError,
    PyExc_TypeError,
    PyExc_UnicodeEncodeError,
    PyExc_ValueError,
    PyGILState_Ensure,
    PyGILState_Release,
    PyList_Insert,
    PyList_New,
    PyList_SetItem,
    PyLong_AsLong,
    PyLong_FromLong,
    PyLong_FromSize_t,
    PyLong_FromUnsignedLong,
    PyLong_FromUnsignedLongLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawFree,
    PyMem_RawMalloc,
    PyObject,
    PyObject_CallFunction,
    PyObject_CallFunctionObjArgs,
    PyObject_CallNoArgs,
    PyObject_CheckBuffer,
    PyObject_IsTrue,
    PyThreadState_Swap,
    PyTuple_New,
    PyUnicode_AsASCIIString,
    PyUnicode_AsUTF8String,
    PyUnicode_DecodeASCII,
    PyUnicode_DecodeFSDefault,
    PyUnicode_DecodeUTF8Stateful,
    PyUnicode_FromEncodedObject,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    PyWeakref_GetRef,
    PyWeakref_NewRef,
    Py_BuildValue,
    Py_None,
    Py_NewRef,
    Py_NotImplemented,
    Py_TYPE,
    Py_buffer,
    Py_fopen,
    _PyBytes_Resize,
    _PyDeadline_Get,
    _PyDeadline_Init,
    _PyLong_FromTime_t,
    _PyLong_UnsignedLongLong_Converter,
    jacpy_buffer_release,
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_errno,
    jacpy_is_bytearray,
    jacpy_is_bytes,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_set_errno,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.layouts { PyTypeObject }
import from jaclang.runtime.python.capi {
    boundary_failure,
    c_int,
    c_string_length,
    c_string_text,
    c_text,
    object_error,
    text_value
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters {
    bad_argument,
    borrowed_false,
    borrowed_none,
    borrowed_true
}
import from jaclang.runtime.python.bindings.type { jacpy_binding_allocate }
import from jaclang.runtime.python.bindings.payload { jacpy_binding_native_set }
import from jaclang.runtime.python.modules.socket_address { new_view }
import from jaclang.runtime.python.modules.openssl {
    ASN1_OBJECT_free,
    ASN1_STRING_get0_data,
    ASN1_STRING_length,
    BIO_ctrl,
    BIO_ctrl_pending,
    BIO_clear_flags,
    BIO_free,
    BIO_free_all,
    BIO_new,
    BIO_new_fp,
    BIO_new_mem_buf,
    BIO_printf,
    BIO_puts,
    BIO_read,
    BIO_s_file,
    BIO_s_mem,
    BIO_set_flags,
    BIO_up_ref,
    BIO_write,
    DH_free,
    ERR_clear_error,
    ERR_get_error,
    ERR_peek_last_error,
    ERR_reason_error_string,
    OBJ_nid2ln,
    OBJ_nid2obj,
    OBJ_nid2sn,
    OBJ_obj2nid,
    OBJ_sn2nid,
    OBJ_txt2obj,
    OPENSSL_sk_find,
    OPENSSL_sk_free,
    OPENSSL_sk_num,
    OPENSSL_sk_value,
    OpenSSL_version,
    OpenSSL_version_num,
    PEM_read_DHparams,
    PEM_read_bio_X509,
    PEM_write_bio_X509,
    PEM_write_bio_X509_AUX,
    RAND_add,
    RAND_bytes,
    RAND_status,
    SSL_CIPHER_description,
    SSL_CIPHER_get_auth_nid,
    SSL_CIPHER_get_bits,
    SSL_CIPHER_get_cipher_nid,
    SSL_CIPHER_get_digest_nid,
    SSL_CIPHER_get_id,
    SSL_CIPHER_get_kx_nid,
    SSL_CIPHER_get_name,
    SSL_CIPHER_get_version,
    SSL_CIPHER_is_aead,
    SSL_CTX_callback_ctrl,
    SSL_CTX_free,
    SSL_CTX_check_private_key,
    SSL_CTX_clear_options,
    SSL_CTX_ctrl,
    SSL_CTX_get0_param,
    SSL_CTX_get_cert_store,
    SSL_CTX_get_default_passwd_cb,
    SSL_CTX_get_default_passwd_cb_userdata,
    SSL_CTX_get_num_tickets,
    SSL_CTX_get_options,
    SSL_CTX_get_security_level,
    SSL_CTX_get_verify_mode,
    SSL_CTX_load_verify_locations,
    SSL_CTX_new,
    SSL_CTX_set_alpn_protos,
    SSL_CTX_set_alpn_select_cb,
    SSL_CTX_set_cipher_list,
    SSL_CTX_set_default_passwd_cb,
    SSL_CTX_set_default_passwd_cb_userdata,
    SSL_CTX_set_default_verify_paths,
    SSL_CTX_set_keylog_callback,
    SSL_CTX_set_msg_callback,
    SSL_CTX_set_num_tickets,
    SSL_CTX_set_options,
    SSL_CTX_set_post_handshake_auth,
    SSL_CTX_set_psk_client_callback,
    SSL_CTX_set_psk_server_callback,
    SSL_CTX_set_verify,
    SSL_CTX_use_PrivateKey_file,
    SSL_CTX_use_certificate_chain_file,
    SSL_CTX_use_psk_identity_hint,
    SSL_SESSION_free,
    SSL_SESSION_get_id,
    SSL_SESSION_get_ticket_lifetime_hint,
    SSL_SESSION_get_time_ex,
    SSL_SESSION_get_timeout,
    SSL_SESSION_has_ticket,
    SSL_ctrl,
    SSL_do_handshake,
    SSL_free,
    SSL_get0_alpn_selected,
    SSL_get0_param,
    SSL_get0_verified_chain,
    SSL_get1_peer_certificate,
    SSL_get1_session,
    SSL_get_SSL_CTX,
    SSL_get_ciphers,
    SSL_get_client_ciphers,
    SSL_get_current_cipher,
    SSL_get_current_compression,
    SSL_get_error,
    SSL_get_ex_data,
    SSL_get_finished,
    SSL_get_peer_cert_chain,
    SSL_get_peer_finished,
    SSL_get_rbio,
    SSL_get_servername,
    SSL_get_shutdown,
    SSL_get_verify_mode,
    SSL_get_version,
    SSL_get_wbio,
    SSL_is_init_finished,
    SSL_new,
    SSL_pending,
    SSL_read_ex,
    SSL_select_next_proto,
    SSL_session_reused,
    SSL_set_SSL_CTX,
    SSL_set_accept_state,
    SSL_set_bio,
    SSL_set_connect_state,
    SSL_set_ex_data,
    SSL_set_fd,
    SSL_set_msg_callback,
    SSL_set_post_handshake_auth,
    SSL_set_read_ahead,
    SSL_set_session,
    SSL_set_session_id_context,
    SSL_set_verify,
    SSL_shutdown,
    SSL_verify_client_post_handshake,
    SSL_write_ex,
    TLS_client_method,
    TLS_method,
    TLS_server_method,
    TLSv1_1_method,
    TLSv1_2_method,
    TLSv1_method,
    COMP_get_type,
    X509_OBJECT_free,
    X509_OBJECT_get0_X509,
    X509_OBJECT_get_type,
    X509_STORE_add_cert,
    X509_STORE_get1_objects,
    X509_VERIFY_PARAM_clear_flags,
    X509_VERIFY_PARAM_get_flags,
    X509_VERIFY_PARAM_get_hostflags,
    X509_VERIFY_PARAM_set1_host,
    X509_VERIFY_PARAM_set1_ip,
    X509_VERIFY_PARAM_set_flags,
    X509_VERIFY_PARAM_set_hostflags,
    X509_check_ca,
    X509_free,
    X509_get_default_cert_dir,
    X509_get_default_cert_dir_env,
    X509_get_default_cert_file,
    X509_get_default_cert_file_env,
    X509_get_subject_name,
    X509_subject_name_hash,
    X509_cmp,
    a2i_IPADDRESS,
    d2i_X509_bio,
    err_get_lib,
    err_get_reason,
    fclose,
    i2d_X509_bio
}
import from jaclang.runtime.python.modules.openssl_constants {
    BIO_CLOSE,
    BIO_C_SET_FILENAME,
    BIO_FP_READ,
    BIO_CTRL_EOF,
    BIO_CTRL_FLUSH,
    BIO_C_FILE_TELL,
    BIO_C_SET_BUF_MEM_EOF_RETURN,
    BIO_C_SET_NBIO,
    BIO_FLAGS_READ,
    BIO_FLAGS_RWS,
    BIO_FLAGS_SHOULD_RETRY,
    BIO_FP_TEXT,
    ERR_LIB_PEM,
    ERR_LIB_X509,
    NID_undef,
    OPENSSL_NO_COMP,
    OPENSSL_NO_PSK,
    OPENSSL_NO_TLS1_1_METHOD,
    OPENSSL_NO_TLS1_2_METHOD,
    OPENSSL_NO_TLS1_METHOD,
    OPENSSL_NPN_NEGOTIATED,
    OPENSSL_VERSION,
    OPENSSL_VERSION_NUMBER,
    PEM_R_NO_START_LINE,
    SSL3_MT_CHANGE_CIPHER_SPEC,
    SSL3_RT_ALERT,
    SSL3_RT_CHANGE_CIPHER_SPEC,
    SSL3_RT_HANDSHAKE,
    SSL3_RT_HEADER,
    SSL3_RT_INNER_CONTENT_TYPE,
    SSL_AD_HANDSHAKE_FAILURE,
    SSL_AD_INTERNAL_ERROR,
    SSL_CTRL_GET_MAX_PROTO_VERSION,
    SSL_CTRL_GET_MIN_PROTO_VERSION,
    SSL_CTRL_MODE,
    SSL_CTRL_SESS_ACCEPT,
    SSL_CTRL_SESS_ACCEPT_GOOD,
    SSL_CTRL_SESS_ACCEPT_RENEGOTIATE,
    SSL_CTRL_SESS_CACHE_FULL,
    SSL_CTRL_SESS_CONNECT,
    SSL_CTRL_SESS_CONNECT_GOOD,
    SSL_CTRL_SESS_CONNECT_RENEGOTIATE,
    SSL_CTRL_SESS_HIT,
    SSL_CTRL_SESS_MISSES,
    SSL_CTRL_SESS_NUMBER,
    SSL_CTRL_SESS_TIMEOUTS,
    SSL_CTRL_SET_MAX_PROTO_VERSION,
    SSL_CTRL_SET_GROUPS,
    SSL_CTRL_SET_MIN_PROTO_VERSION,
    SSL_CTRL_SET_TLSEXT_HOSTNAME,
    SSL_CTRL_SET_TLSEXT_SERVERNAME_ARG,
    SSL_CTRL_SET_TLSEXT_SERVERNAME_CB,
    SSL_CTRL_SET_TMP_DH,
    SSL_ERROR_WANT_READ,
    SSL_ERROR_WANT_WRITE,
    SSL_ERROR_ZERO_RETURN,
    SSL_FILETYPE_ASN1,
    SSL_FILETYPE_PEM,
    SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER,
    SSL_MODE_AUTO_RETRY,
    SSL_MODE_RELEASE_BUFFERS,
    SSL_OP_ALL,
    SSL_OP_CIPHER_SERVER_PREFERENCE,
    SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS,
    SSL_OP_NO_COMPRESSION,
    SSL_OP_NO_SSLv2,
    SSL_OP_NO_SSLv3,
    SSL_OP_NO_TLSv1,
    SSL_OP_NO_TLSv1_1,
    SSL_OP_NO_TLSv1_2,
    SSL_OP_NO_TLSv1_3,
    SSL_OP_SINGLE_DH_USE,
    SSL_OP_SINGLE_ECDH_USE,
    SSL_RECEIVED_SHUTDOWN,
    SSL_TLSEXT_ERR_ALERT_FATAL,
    SSL_TLSEXT_ERR_NOACK,
    SSL_TLSEXT_ERR_OK,
    SSL_VERIFY_FAIL_IF_NO_PEER_CERT,
    SSL_VERIFY_NONE,
    SSL_VERIFY_PEER,
    SSL_VERIFY_POST_HANDSHAKE,
    TLSEXT_NAMETYPE_host_name,
    UNDEFINED,
    X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS,
    X509_FILETYPE_ASN1,
    X509_FILETYPE_PEM,
    X509_LU_CRL,
    X509_LU_X509,
    X509_R_CERT_ALREADY_IN_HASH_TABLE,
    X509_V_FLAG_TRUSTED_FIRST,
    XN_FLAG_RFC2253
}
import from jaclang.runtime.python.modules.ssl_core {
    AlpnProtocols,
    CertificateState,
    HAS_SSLv3,
    HAS_TLSv1,
    HAS_TLSv1_1,
    HAS_TLSv1_2,
    HAVE_POST_HS_AUTH,
    INT_MAX,
    MemoryBIOState,
    MemoryBIO_token,
    PY_PROTO_MAXIMUM_AVAILABLE,
    PY_PROTO_MAXIMUM_SUPPORTED,
    PY_PROTO_MINIMUM_AVAILABLE,
    PY_PROTO_MINIMUM_SUPPORTED,
    PY_PROTO_SSLv3,
    PY_PROTO_TLSv1,
    PY_PROTO_TLSv1_1,
    PY_PROTO_TLSv1_2,
    PY_PROTO_TLSv1_3,
    PY_SSL_CERT_NONE,
    PY_SSL_CERT_OPTIONAL,
    PY_SSL_CERT_REQUIRED,
    PY_SSL_CLIENT,
    PY_SSL_DEFAULT_CIPHER_STRING,
    PY_SSL_ERROR_NO_SOCKET,
    PY_SSL_MIN_PROTOCOL,
    PY_SSL_SERVER,
    PY_SSL_VERSION_SSL2,
    PY_SSL_VERSION_SSL3,
    PY_SSL_VERSION_TLS,
    PY_SSL_VERSION_TLS1,
    PY_SSL_VERSION_TLS1_1,
    PY_SSL_VERSION_TLS1_2,
    PY_SSL_VERSION_TLS_CLIENT,
    PY_SSL_VERSION_TLS_SERVER,
    PySSL_CB_MAXLEN,
    SOCKET_HAS_BEEN_CLOSED,
    SOCKET_HAS_TIMED_OUT,
    SOCKET_IS_NONBLOCKING,
    SOCKET_OPERATION_OK,
    SOCKET_TOO_LARGE_FOR_SELECT,
    SSLContextState,
    SSLSessionState,
    SSLSocketState,
    SSLSession_token,
    STATE_CERTIFICATE_TYPE,
    STATE_CONTEXT_TYPE,
    STATE_MEMORY_BIO_TYPE,
    STATE_SESSION_TYPE,
    STATE_SOCKET_TYPE,
    STATE_SOCK_TYPE,
    STATE_SSL_ERROR,
    UINT_MAX,
    _SSLContext_token,
    _SSLSocket_token,
    certificate_of,
    chain_exceptions,
    context_of,
    free_octet_string,
    get_socket,
    memory_bio_of,
    module_native,
    module_of_object,
    module_of_socket,
    module_of_type,
    mutex_new,
    session_of,
    set_ssl_error,
    socket_fd,
    socket_of,
    socket_timeout,
    ssl_select,
    ssl_set_error,
    state_ref,
    type_check
}
import from jaclang.runtime.python.modules.ssl_cert {
    asn1obj2py,
    bytes_from_bio,
    certificate_from_x509,
    certificates_from_stack,
    certificate_to_der,
    decode_certificate,
    pem_errors,
    type_name_address,
    unicode_from_bio,
    x509name_print
}

# enum py_ssl_encoding (_ssl.h)
glob PY_SSL_ENCODING_PEM: i32 = i32(X509_FILETYPE_PEM),
     PY_SSL_ENCODING_DER: i32 = i32(X509_FILETYPE_ASN1),
     PY_SSL_ENCODING_PEM_AUX: i32 = i32(X509_FILETYPE_PEM + 0x100);

# ---------------------------------------------------------------------------
# Small helpers.

"""_ssl_deprecated()."""
def:priv deprecated(message: str, stacklevel: int) -> bool {
    return PyErr_WarnEx(PyExc_DeprecationWarning, message, i64(stacklevel)) != -1;
}

"""BIO_set_nbio()."""
def:priv bio_set_nbio(bio: ptr, nonblocking: bool) {
    BIO_ctrl(bio, i32(BIO_C_SET_NBIO), i64(nonblocking), ptr());
}

"""The context's module (get_state_ctx())."""
def:priv context_module(ctx: SSLContextState) -> ptr[PyObject] {
    return ctx.module;
}

"""The tp_name of a type as a str."""
def:priv type_name_text(type: ptr[PyObject]) -> str {
    name = c_string_text(ptr[PyTypeObject](type).view(1)[0].tp_name);
    if not name {
        PyErr_Clear();
        return "";
    }
    text = text_value(name);
    jacpy_release(name);
    return text;
}

def:priv true_or_false(flag: bool) -> ptr[PyObject] {
    return Py_NewRef(borrowed_true() if flag else borrowed_false());
}

def:priv none -> ptr[PyObject] {
    return Py_NewRef(borrowed_none());
}

# ---------------------------------------------------------------------------
# Clinic converters: object(subclass_of="get_state_ctx(self)->...").

def:priv check_state_type(
    receiver: ptr[PyObject], value: ptr[PyObject], fname: str, label: str, index: int
) {
    ctx = context_of(receiver);
    if ctx is None {
        raise boundary_failure();
    }
    type = state_ref(ctx.module, index);
    if not type_check(value, type) {
        bad_argument(fname, label, type_name_text(type), value);
    }
}

def subclass_get_state_ctx_self_Sock_Type(
    receiver: ptr[PyObject], value: ptr[PyObject], fname: str, label: str
) {
    check_state_type(receiver, value, fname, label, STATE_SOCK_TYPE);
}

def subclass_get_state_ctx_self_PySSLMemoryBIO_Type(
    receiver: ptr[PyObject], value: ptr[PyObject], fname: str, label: str
) {
    check_state_type(receiver, value, fname, label, STATE_MEMORY_BIO_TYPE);
}

# ---------------------------------------------------------------------------
# Debug helpers (Modules/_ssl/debughelpers.c).

"""The ssl.SSLSocket or ssl.SSLObject a callback passes on: the owner, else
the socket, else the _SSLSocket itself (a new reference, or NULL when the
weak reference is dead)."""
def:priv callback_socket(
    instance: ptr[PyObject], sock: SSLSocketState
) -> ptr[PyObject] {
    target = NULL;
    if sock.owner {
        PyWeakref_GetRef(sock.owner, &mut target);
    } elif sock.socket_ref {
        PyWeakref_GetRef(sock.socket_ref, &mut target);
    } else {
        target = Py_NewRef(instance);
    }
    return target;
}

"""_PySSL_msg_callback()."""
def:priv msg_callback(
    write_p: i32,
    version: i32,
    content_type: i32,
    buf: ptr,
    length: u64,
    ssl: ptr,
    argument: ptr
) {
    threadstate = PyGILState_Ensure();
    instance = ptr[PyObject](SSL_get_ex_data(ssl, i32(0)));
    sock = socket_of(instance);
    if sock is None {
        PyErr_Clear();
        PyGILState_Release(threadstate);
        return;
    }
    ctx = context_of(sock.ctx);
    if ctx is None or not ctx.msg_cb {
        PyErr_Clear();
        PyGILState_Release(threadstate);
        return;
    }
    ssl_socket = callback_socket(instance, sock);
    cbuf = ptr[u8](buf);
    msg_type = -1;
    shown_version = int(version);
    # Assume that OpenSSL verifies all payload and buf len is of sufficient
    # length.
    kind = int(content_type);
    if kind == SSL3_RT_CHANGE_CIPHER_SPEC {
        msg_type = SSL3_MT_CHANGE_CIPHER_SPEC;
    } elif kind == SSL3_RT_ALERT {
        # byte 0: level, byte 1: alert type
        msg_type = int(i8(cbuf.view(2)[1]));
    } elif kind == SSL3_RT_HANDSHAKE {
        msg_type = int(i8(cbuf.view(1)[0]));
    } elif "SSL3_RT_HEADER" not in UNDEFINED and kind == SSL3_RT_HEADER {
        # The frame header encodes the version in bytes 1..2.
        header = cbuf.view(3);
        shown_version = int(i8(header[1])) << 8 | int(i8(header[2]));
        msg_type = int(i8(header[0]));
    } elif "SSL3_RT_INNER_CONTENT_TYPE" not in UNDEFINED
        and kind == SSL3_RT_INNER_CONTENT_TYPE {
        msg_type = int(i8(cbuf.view(1)[0]));
    }
    res = PyObject_CallFunction(
        ctx.msg_cb,
        "Osiiiy#",
        ssl_socket,
        ptr[u8]("write") if write_p else ptr[u8]("read"),
        c_int(shown_version),
        content_type,
        c_int(msg_type),
        buf,
        i64(length)
    );
    if not res {
        sock.exc = PyErr_GetRaisedException();
    } else {
        jacpy_release(res);
    }
    if ssl_socket {
        jacpy_release(ssl_socket);
    }
    PyGILState_Release(threadstate);
}

"""_PySSLContext_get_msg_callback()."""
def context_get_msg_callback(instance: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(instance);
    if ctx is None {
        return NULL;
    }
    if ctx.msg_cb {
        return Py_NewRef(ctx.msg_cb);
    }
    return none();
}

"""_PySSLContext_set_msg_callback()."""
def context_set_msg_callback(instance: ptr[PyObject], arg: ptr[PyObject]) -> i32 {
    ctx = context_of(instance);
    if ctx is None {
        return i32(-1);
    }
    if ctx.msg_cb {
        previous = ctx.msg_cb;
        ctx.msg_cb = NULL;
        jacpy_release(previous);
    }
    if arg == Py_None {
        SSL_CTX_set_msg_callback(ctx.ctx, ptr());
    } else {
        if PyCallable_Check(arg) == 0 {
            SSL_CTX_set_msg_callback(ctx.ctx, ptr());
            PyErr_SetString(PyExc_TypeError, "not a callable object");
            return i32(-1);
        }
        ctx.msg_cb = Py_NewRef(arg);
        SSL_CTX_set_msg_callback(ctx.ctx, ptr(msg_callback));
    }
    return i32(0);
}

"""_PySSL_keylog_callback()."""
def:priv keylog_callback(ssl: ptr, line: ptr[u8]) {
    threadstate = PyGILState_Ensure();
    instance = ptr[PyObject](SSL_get_ex_data(ssl, i32(0)));
    sock = socket_of(instance);
    if sock is None {
        PyErr_Clear();
        PyGILState_Release(threadstate);
        return;
    }
    ctx = context_of(sock.ctx);
    module = module_of_socket(sock);
    native = module_native(module);
    if ctx is None or native is None or not ctx.keylog_bio {
        PyErr_Clear();
        PyGILState_Release(threadstate);
        return;
    }
    # The lock is neither released on exit nor on fork(). The lock is also
    # shared between all SSLContexts although contexts may write to their
    # own files. That's good enough for a non-performance critical debug
    # helper.
    lock = native.keylog_lock;
    bio = ctx.keylog_bio;
    thread = PyEval_SaveThread();
    PyThread_acquire_lock(lock, 1);
    res = BIO_printf(bio, ptr[u8]("%s\n"), line);
    e = jacpy_errno();
    BIO_ctrl(bio, i32(BIO_CTRL_FLUSH), 0, ptr());
    PyThread_release_lock(lock);
    PyEval_RestoreThread(thread);
    if res == -1 {
        jacpy_set_errno(e);
        PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, ctx.keylog_filename);
        sock.exc = PyErr_GetRaisedException();
    }
    PyGILState_Release(threadstate);
}

"""_PySSLContext_get_keylog_filename()."""
def context_get_keylog_filename(instance: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(instance);
    if ctx is None {
        return NULL;
    }
    if ctx.keylog_filename {
        return Py_NewRef(ctx.keylog_filename);
    }
    return none();
}

"""_PySSLContext_set_keylog_filename()."""
def context_set_keylog_filename(instance: ptr[PyObject], arg: ptr[PyObject]) -> i32 {
    ctx = context_of(instance);
    if ctx is None {
        return i32(-1);
    }
    # Reset variables and callback first.
    SSL_CTX_set_keylog_callback(ctx.ctx, ptr());
    if ctx.keylog_filename {
        previous = ctx.keylog_filename;
        ctx.keylog_filename = NULL;
        jacpy_release(previous);
    }
    if ctx.keylog_bio {
        bio = ctx.keylog_bio;
        ctx.keylog_bio = ptr();
        thread = PyEval_SaveThread();
        BIO_free_all(bio);
        PyEval_RestoreThread(thread);
    }
    if arg == Py_None {
        # None disables the callback.
        return i32(0);
    }
    # Py_fopen() also checks that arg is of proper type.
    fp = Py_fopen(arg, "a");
    if not fp {
        return i32(-1);
    }
    ctx.keylog_bio = BIO_new_fp(ptr(fp), i32(BIO_CLOSE | BIO_FP_TEXT));
    if not ctx.keylog_bio {
        PyErr_SetString(
            state_ref(ctx.module, STATE_SSL_ERROR),
            "Can't malloc memory for keylog file"
        );
        return i32(-1);
    }
    ctx.keylog_filename = Py_NewRef(arg);
    # Write a header for seekable, empty files (this excludes pipes).
    bio = ctx.keylog_bio;
    thread = ctx.begin_allow_threads();
    if BIO_ctrl(bio, i32(BIO_C_FILE_TELL), 0, ptr()) == 0 {
        BIO_puts(
            bio, ptr[u8]("# TLS secrets log file, generated by OpenSSL / Python\n")
        );
        BIO_ctrl(bio, i32(BIO_CTRL_FLUSH), 0, ptr());
    }
    ctx.end_allow_threads(thread);
    SSL_CTX_set_keylog_callback(ctx.ctx, ptr(keylog_callback));
    return i32(0);
}

# ---------------------------------------------------------------------------
# SSL objects.

"""_ssl_configure_hostname(): record server_hostname, send it as SNI unless
it is an IP address, and have OpenSSL check the peer against it."""
def:priv configure_hostname(sock: SSLSocketState, server_hostname: ptr[u8]) -> int {
    module = module_of_socket(sock);
    length = c_string_length(server_hostname);
    # Disable OpenSSL's special mode with leading dot in hostname: when name
    # starts with a dot (e.g ".example.com"), it will be matched by a
    # certificate valid for any sub-domain of name.
    if length == 0 or server_hostname.view(1)[0] == u8(46) {
        PyErr_SetString(
            PyExc_ValueError,
            "server_hostname cannot be an empty string or start with a leading dot."
        );
        return -1;
    }
    # inet_pton is not available on all platforms.
    ip = a2i_IPADDRESS(server_hostname);
    if not ip {
        ERR_clear_error();
    }
    retval = -1;
    hostname = PyUnicode_DecodeASCII(
        ptr(server_hostname), i64(length), ptr[u8]("strict")
    );
    if hostname {
        sock.server_hostname = hostname;
        retval = 0;
        # Only send SNI extension for non-IP hostnames.
        if not ip
            and SSL_ctrl(
                sock.ssl,
                i32(SSL_CTRL_SET_TLSEXT_HOSTNAME),
                TLSEXT_NAMETYPE_host_name,
                ptr(server_hostname)
            )
                == 0 {
            set_ssl_error(module, ptr[u8](), 825);
            retval = -1;
        }
        ctx = context_of(sock.ctx);
        if retval == 0 and ctx is not None and ctx.check_hostname {
            params = SSL_get0_param(sock.ssl);
            if not ip {
                if X509_VERIFY_PARAM_set1_host(params, server_hostname, u64(length))
                    == 0 {
                    set_ssl_error(module, ptr[u8](), 834);
                    retval = -1;
                }
            } elif X509_VERIFY_PARAM_set1_ip(
                params, ASN1_STRING_get0_data(ip), u64(ASN1_STRING_length(ip))
            )
                == 0 {
                set_ssl_error(module, ptr[u8](), 840);
                retval = -1;
            }
        }
    }
    free_octet_string(ip);
    return retval;
}

"""_ssl__SSLSocket_owner_set()."""
def:priv socket_set_owner(sock: SSLSocketState, value: ptr[PyObject]) -> int {
    owner = PyWeakref_NewRef(value, NULL);
    previous = sock.owner;
    sock.owner = owner;
    if previous {
        jacpy_release(previous);
    }
    return 0 if owner else -1;
}

"""_ssl__SSLSocket_session_set()."""
def:priv socket_set_session(sock: SSLSocketState, value: ptr[PyObject]) -> int {
    module = module_of_socket(sock);
    if Py_TYPE(value) != state_ref(module, STATE_SESSION_TYPE) {
        PyErr_SetString(PyExc_TypeError, "Value is not a SSLSession.");
        return -1;
    }
    session = session_of(value);
    ctx = context_of(sock.ctx);
    if session is None or ctx is None {
        return -1;
    }
    session_ctx = context_of(session.ctx);
    if session_ctx is None {
        return -1;
    }
    if ctx.ctx != session_ctx.ctx {
        PyErr_SetString(PyExc_ValueError, "Session refers to a different SSLContext.");
        return -1;
    }
    if sock.socket_type != PY_SSL_CLIENT {
        PyErr_SetString(
            PyExc_ValueError, "Cannot set session for server-side SSLSocket."
        );
        return -1;
    }
    if SSL_is_init_finished(sock.ssl) != 0 {
        PyErr_SetString(PyExc_ValueError, "Cannot set session after handshake.");
        return -1;
    }
    if SSL_set_session(sock.ssl, session.session) == 0 {
        set_ssl_error(module, ptr[u8](), 3001);
        return -1;
    }
    return 0;
}

"""newPySSLSocket(): an _SSLSocket over a socket or a pair of MemoryBIOs."""
def:priv new_ssl_socket(
    context: ptr[PyObject],
    sock: ptr[PyObject],
    socket_type: int,
    server_hostname: ptr[u8],
    owner: ptr[PyObject],
    session: ptr[PyObject],
    inbio: ptr[PyObject],
    outbio: ptr[PyObject]
) -> ptr[PyObject] {
    sslctx = context_of(context);
    if sslctx is None {
        return NULL;
    }
    module = sslctx.module;
    if socket_type == PY_SSL_SERVER and sslctx.protocol == PY_SSL_VERSION_TLS_CLIENT {
        set_ssl_error(
            module,
            ptr[u8]("Cannot create a server socket with a PROTOCOL_TLS_CLIENT context"),
            868
        );
        return NULL;
    }
    if socket_type == PY_SSL_CLIENT and sslctx.protocol == PY_SSL_VERSION_TLS_SERVER {
        set_ssl_error(
            module,
            ptr[u8]("Cannot create a client socket with a PROTOCOL_TLS_SERVER context"),
            875
        );
        return NULL;
    }
    type = state_ref(module, STATE_SOCKET_TYPE);
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = SSLSocketState(ctx=Py_NewRef(context));
    if jacpy_binding_native_set(instance, _SSLSocket_token.definition_of(type), state)
        < 0 {
        state.clear();
        jacpy_release(instance);
        return NULL;
    }
    # Make sure the SSL error state is initialized.
    ERR_clear_error();
    openssl_ctx = sslctx.ctx;
    thread = sslctx.begin_allow_threads();
    ssl = SSL_new(openssl_ctx);
    sslctx.end_allow_threads(thread);
    state.ssl = ssl;
    if not ssl {
        set_ssl_error(module, ptr[u8](), 900);
        jacpy_release(instance);
        return NULL;
    }
    if socket_type == PY_SSL_SERVER {
        # Set the session id context (server-side only); sizeof("Python").
        SSL_set_session_id_context(ssl, ptr[u8]("Python"), u32(7));
    }
    SSL_set_ex_data(ssl, i32(0), ptr(instance));
    if sock {
        SSL_set_fd(ssl, socket_fd(sock));
    } else {
        # BIOs are reference counted and SSL_set_bio borrows our reference.
        # To prevent a double free in memory_bio_dealloc() we need to take an
        # extra reference here.
        incoming = memory_bio_of(inbio);
        outgoing = memory_bio_of(outbio);
        if incoming is None or outgoing is None {
            jacpy_release(instance);
            return NULL;
        }
        BIO_up_ref(incoming.bio);
        BIO_up_ref(outgoing.bio);
        SSL_set_bio(ssl, incoming.bio, outgoing.bio);
    }
    SSL_ctrl(
        ssl,
        i32(SSL_CTRL_MODE),
        SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER | SSL_MODE_AUTO_RETRY,
        ptr()
    );
    if HAVE_POST_HS_AUTH and sslctx.post_handshake_auth == 1 {
        if socket_type == PY_SSL_SERVER {
            # bpo-37428: OpenSSL does not ignore SSL_VERIFY_POST_HANDSHAKE.
            # Set SSL_VERIFY_POST_HANDSHAKE flag only for server sockets and
            # only in combination with SSL_VERIFY_PEER flag.
            mode = int(SSL_get_verify_mode(ssl));
            if mode & SSL_VERIFY_PEER {
                SSL_set_verify(ssl, i32(mode | SSL_VERIFY_POST_HANDSHAKE), ptr());
            }
        } else {
            # client socket
            SSL_set_post_handshake_auth(ssl, i32(1));
        }
    }
    if server_hostname and configure_hostname(state, server_hostname) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    # If the socket is in non-blocking mode or timeout mode, set the BIO to
    # non-blocking mode (blocking is the default).
    if sock and socket_timeout(sock) >= 0 {
        bio_set_nbio(SSL_get_rbio(ssl), True);
        bio_set_nbio(SSL_get_wbio(ssl), True);
    }
    thread = PyEval_SaveThread();
    if socket_type == PY_SSL_CLIENT {
        SSL_set_connect_state(ssl);
    } else {
        SSL_set_accept_state(ssl);
    }
    PyEval_RestoreThread(thread);
    state.socket_type = socket_type;
    if sock {
        state.socket_ref = PyWeakref_NewRef(sock, NULL);
        if not state.socket_ref {
            jacpy_release(instance);
            return NULL;
        }
    }
    if owner and owner != Py_None and socket_set_owner(state, owner) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    if session and session != Py_None and socket_set_session(state, session) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

"""The socket of an SSL method, as the C methods' prologue takes it: its
borrowed pointer (NULL for memory BIOs), or None with the "Underlying
socket connection gone" error set at `lineno`."""
def:priv method_socket(sock: SSLSocketState, lineno: int) -> ptr[PyObject] {
    target = get_socket(sock);
    if target == Py_None {
        set_ssl_error(
            module_of_socket(sock), ptr[u8]("Underlying socket connection gone"), lineno
        );
    }
    return target;
}

"""Make the BIOs follow the socket's blocking mode, in case it changed."""
def:priv sync_blocking(sock: SSLSocketState, target: ptr[PyObject]) {
    nonblocking = socket_timeout(target) >= 0;
    bio_set_nbio(SSL_get_rbio(sock.ssl), nonblocking);
    bio_set_nbio(SSL_get_wbio(sock.ssl), nonblocking);
}

def _ssl__SSLSocket_do_handshake_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    target = method_socket(sock, 1021);
    if target == Py_None {
        return NULL;
    }
    if target {
        # Keep the socket alive for the call.
        target = Py_NewRef(target);
        sync_blocking(sock, target);
    }
    module = module_of_socket(sock);
    timeout = socket_timeout(target);
    has_timeout = timeout > 0;
    deadline = i64(0);
    if has_timeout {
        deadline = _PyDeadline_Init(timeout);
    }
    ret = i32(0);
    failed = False;
    ssl = sock.ssl;
    # Actually negotiate the SSL connection.
    # XXX If SSL_do_handshake() returns 0, it's also a failure.
    while True {
        thread = PyEval_SaveThread();
        ret = SSL_do_handshake(ssl);
        c_errno = jacpy_errno();
        err_ssl = SSL_get_error(ssl, ret) if ret < 1 else i32(0);
        PyEval_RestoreThread(thread);
        sock.err_c = int(c_errno) if ret < 1 else 0;
        sock.err_ssl = int(err_ssl);
        if PyErr_CheckSignals() != 0 {
            failed = True;
            break;
        }
        if has_timeout {
            timeout = _PyDeadline_Get(deadline);
        }
        sockstate = SOCKET_OPERATION_OK;
        if sock.err_ssl == SSL_ERROR_WANT_READ {
            sockstate = ssl_select(target, False, timeout);
        } elif sock.err_ssl == SSL_ERROR_WANT_WRITE {
            sockstate = ssl_select(target, True, timeout);
        }
        if sockstate == SOCKET_HAS_TIMED_OUT {
            PyErr_SetString(
                PyExc_TimeoutError, "_ssl.c:1064: The handshake operation timed out"
            );
            failed = True;
            break;
        } elif sockstate == SOCKET_HAS_BEEN_CLOSED {
            PyErr_SetString(
                state_ref(module, STATE_SSL_ERROR),
                "_ssl.c:1068: Underlying socket has been closed."
            );
            failed = True;
            break;
        } elif sockstate == SOCKET_TOO_LARGE_FOR_SELECT {
            PyErr_SetString(
                state_ref(module, STATE_SSL_ERROR),
                "_ssl.c:1072: Underlying socket too large for select()."
            );
            failed = True;
            break;
        } elif sockstate == SOCKET_IS_NONBLOCKING {
            break;
        }
        if sock.err_ssl != SSL_ERROR_WANT_READ
            and sock.err_ssl != SSL_ERROR_WANT_WRITE {
            break;
        }
    }
    if target {
        jacpy_release(target);
    }
    if failed {
        chain_exceptions(sock);
        return NULL;
    }
    if ret < 1 {
        return ssl_set_error(sock, 1082);
    }
    if chain_exceptions(sock) < 0 {
        return NULL;
    }
    return none();
}

def _ssl__test_decode_cert_impl(
    module: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    retval = NULL;
    cert = BIO_new(BIO_s_file());
    if not cert {
        PyErr_SetString(
            state_ref(module, STATE_SSL_ERROR), "Can't malloc memory to read file"
        );
    } elif BIO_ctrl(
        cert,
        i32(BIO_C_SET_FILENAME),
        BIO_CLOSE | BIO_FP_READ,
        ptr(PyBytes_AsString(path))
    )
        <= 0 {
        PyErr_SetString(state_ref(module, STATE_SSL_ERROR), "Can't open file");
    } else {
        x = PEM_read_bio_X509(cert, ptr(), ptr(), ptr());
        if not x {
            PyErr_SetString(
                state_ref(module, STATE_SSL_ERROR), "Error decoding PEM-encoded file"
            );
        } else {
            retval = decode_certificate(module, x);
            X509_free(x);
        }
    }
    if cert {
        BIO_free(cert);
    }
    return retval;
}

def _ssl__SSLSocket_getpeercert_impl(
    receiver: ptr[PyObject], binary_mode: bool
) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if SSL_is_init_finished(sock.ssl) == 0 {
        PyErr_SetString(PyExc_ValueError, "handshake not done yet");
        return NULL;
    }
    peer_cert = SSL_get1_peer_certificate(sock.ssl);
    if not peer_cert {
        return none();
    }
    module = module_of_socket(sock);
    result = NULL;
    if binary_mode {
        # Return the certificate in DER-encoded format.
        result = certificate_to_der(module, peer_cert);
    } else {
        verification = int(SSL_CTX_get_verify_mode(SSL_get_SSL_CTX(sock.ssl)));
        if (verification & SSL_VERIFY_PEER) == 0 {
            result = PyDict_New();
        } else {
            result = decode_certificate(module, peer_cert);
        }
    }
    X509_free(peer_cert);
    return result;
}

def _ssl__SSLSocket_get_verified_chain_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    # A borrowed reference.
    chain = SSL_get0_verified_chain(sock.ssl);
    if not chain {
        return none();
    }
    return certificates_from_stack(module_of_socket(sock), chain, True);
}

def _ssl__SSLSocket_get_unverified_chain_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    # A borrowed reference.
    chain = SSL_get_peer_cert_chain(sock.ssl);
    if not chain {
        return none();
    }
    module = module_of_socket(sock);
    retval = certificates_from_stack(module, chain, True);
    if not retval {
        return NULL;
    }
    # OpenSSL does not include the peer cert for server side connections.
    if sock.socket_type == PY_SSL_SERVER {
        peerobj = NULL;
        peer = SSL_get1_peer_certificate(sock.ssl);
        if not peer {
            peerobj = none();
        } else {
            # Consume the X509 reference on success.
            peerobj = certificate_from_x509(module, peer, False);
            if not peerobj {
                X509_free(peer);
                jacpy_release(retval);
                return NULL;
            }
        }
        res = PyList_Insert(retval, 0, peerobj);
        jacpy_release(peerobj);
        if res < 0 {
            jacpy_release(retval);
            return NULL;
        }
    }
    return retval;
}

"""A C string as a str, or None when it is NULL (a new reference)."""
def:priv optional_text(text: ptr[u8]) -> ptr[PyObject] {
    if not text {
        return none();
    }
    return c_string_text(text);
}

"""cipher_to_tuple(): (name, protocol, secret bits)."""
def:priv cipher_to_tuple(cipher: ptr) -> ptr[PyObject] {
    retval = PyTuple_New(3);
    if not retval {
        return NULL;
    }
    items = [
        optional_text(SSL_CIPHER_get_name(cipher)),
        optional_text(SSL_CIPHER_get_version(cipher)),
        PyLong_FromLong(i64(SSL_CIPHER_get_bits(cipher, None)))
    ];
    failed = False;
    for index in range(3) {
        if not items[index] {
            failed = True;
            continue;
        }
        jacpy_tuple_set_owned(retval, i64(index), items[index]);
    }
    if failed {
        jacpy_release(retval);
        return NULL;
    }
    return retval;
}

"""The long name of a NID, or NULL for NID_undef."""
def:priv nid_long_name(nid: i32) -> ptr[u8] {
    return OBJ_nid2ln(nid) if i64(nid) != NID_undef else ptr[u8]();
}

"""cipher_to_dict()."""
def:priv cipher_to_dict(cipher: ptr) -> ptr[PyObject] {
    buf = ptr[u8](PyMem_Malloc(u64(512)));
    if not buf {
        return PyErr_NoMemory();
    }
    characters = buf.view(512);
    for i in range(512) {
        characters[i] = u8(0);
    }
    # These can be NULL.
    cipher_name = SSL_CIPHER_get_name(cipher);
    cipher_protocol = SSL_CIPHER_get_version(cipher);
    cipher_id = SSL_CIPHER_get_id(cipher);
    SSL_CIPHER_description(cipher, buf, i32(511));
    length = c_string_length(buf);
    if length > 1 and characters[length - 1] == u8(10) {
        characters[length - 1] = u8(0);
    }
    alg_bits = i32(0);
    strength_bits = SSL_CIPHER_get_bits(cipher, &mut alg_bits);
    aead = SSL_CIPHER_is_aead(cipher);
    skcipher = nid_long_name(SSL_CIPHER_get_cipher_nid(cipher));
    digest = nid_long_name(SSL_CIPHER_get_digest_nid(cipher));
    kx = nid_long_name(SSL_CIPHER_get_kx_nid(cipher));
    auth = nid_long_name(SSL_CIPHER_get_auth_nid(cipher));
    result = Py_BuildValue(
        "{sksssssssisisOssssssss}",
        ptr[u8]("id"),
        u64(cipher_id),
        ptr[u8]("name"),
        cipher_name,
        ptr[u8]("protocol"),
        cipher_protocol,
        ptr[u8]("description"),
        buf,
        ptr[u8]("strength_bits"),
        strength_bits,
        ptr[u8]("alg_bits"),
        alg_bits,
        ptr[u8]("aead"),
        borrowed_true() if aead else borrowed_false(),
        ptr[u8]("symmetric"),
        skcipher,
        ptr[u8]("digest"),
        digest,
        ptr[u8]("kea"),
        kx,
        ptr[u8]("auth"),
        auth
    );
    PyMem_Free(buf);
    return result;
}

def _ssl__SSLSocket_shared_ciphers_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    # Rather than use SSL_get_shared_ciphers, use an equivalent algorithm:
    # that returns a colon separated list of strings, in an undefined order,
    # truncated without notice if the buffer is too small.
    server_ciphers = SSL_get_ciphers(sock.ssl);
    if not server_ciphers {
        return none();
    }
    client_ciphers = SSL_get_client_ciphers(sock.ssl);
    if not client_ciphers {
        return none();
    }
    res = PyList_New(0);
    if not res {
        return NULL;
    }
    for i in range(int(OPENSSL_sk_num(server_ciphers))) {
        cipher = OPENSSL_sk_value(server_ciphers, i32(i));
        if OPENSSL_sk_find(client_ciphers, cipher) < 0 {
            continue;
        }
        tup = cipher_to_tuple(cipher);
        if not tup {
            jacpy_release(res);
            return NULL;
        }
        status = append_owned(res, tup);
        if status < 0 {
            jacpy_release(res);
            return NULL;
        }
    }
    return res;
}

"""PyList_Append() of a new reference, which it releases."""
def:priv append_owned(target: ptr[PyObject], item: ptr[PyObject]) -> i32 {
    status = PyList_Append(target, item);
    jacpy_release(item);
    return status;
}

def _ssl__SSLSocket_cipher_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if not sock.ssl {
        return none();
    }
    current = SSL_get_current_cipher(sock.ssl);
    if not current {
        return none();
    }
    return cipher_to_tuple(current);
}

def _ssl__SSLSocket_version_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if not sock.ssl or SSL_is_init_finished(sock.ssl) == 0 {
        # The handshake is not finished.
        return none();
    }
    version = c_string_text(SSL_get_version(sock.ssl));
    if not version {
        return NULL;
    }
    if text_value(version) == "unknown" {
        jacpy_release(version);
        return none();
    }
    return version;
}

def _ssl__SSLSocket_selected_alpn_protocol_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    out = ptr[u8]();
    outlen = u32(0);
    SSL_get0_alpn_selected(sock.ssl, &mut out, &mut outlen);
    if not out {
        return none();
    }
    return c_text(out, i64(outlen));
}

def _ssl__SSLSocket_compression_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if OPENSSL_NO_COMP {
        return none();
    }
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if not sock.ssl {
        return none();
    }
    comp_method = SSL_get_current_compression(sock.ssl);
    if not comp_method or i64(COMP_get_type(comp_method)) == NID_undef {
        return none();
    }
    short_name = OBJ_nid2sn(COMP_get_type(comp_method));
    if not short_name {
        return none();
    }
    return PyUnicode_DecodeFSDefault(short_name);
}

def _ssl__SSLSocket_context_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    return Py_NewRef(sock.ctx);
}

def _ssl__SSLSocket_context_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    sock = socket_of(receiver);
    if sock is None {
        return -1;
    }
    if not type_check(value, state_ref(module_of_socket(sock), STATE_CONTEXT_TYPE)) {
        PyErr_SetString(PyExc_TypeError, "The value must be a SSLContext");
        return -1;
    }
    ctx = context_of(value);
    if ctx is None {
        return -1;
    }
    previous = sock.ctx;
    sock.ctx = Py_NewRef(value);
    jacpy_release(previous);
    SSL_set_SSL_CTX(sock.ssl, ctx.ctx);
    # Set SSL* internal msg_callback to state of new context's state.
    SSL_set_msg_callback(sock.ssl, ptr(msg_callback) if ctx.msg_cb else ptr());
    return 0;
}

def _ssl__SSLSocket_server_side_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    return PyBool_FromLong(i64(sock.socket_type == PY_SSL_SERVER));
}

def _ssl__SSLSocket_server_hostname_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if not sock.server_hostname {
        return none();
    }
    return Py_NewRef(sock.server_hostname);
}

def _ssl__SSLSocket_owner_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if not sock.owner {
        return none();
    }
    owner = NULL;
    if PyWeakref_GetRef(sock.owner, &mut owner) == 0 {
        return none();
    }
    return owner;
}

def _ssl__SSLSocket_owner_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    sock = socket_of(receiver);
    if sock is None {
        return -1;
    }
    return socket_set_owner(sock, value);
}

def _ssl__SSLSocket_write_impl(
    receiver: ptr[PyObject], b: BufferArgument
) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    target = method_socket(sock, 2483);
    if target == Py_None {
        return NULL;
    }
    if target {
        target = Py_NewRef(target);
        sync_blocking(sock, target);
    }
    module = module_of_socket(sock);
    timeout = socket_timeout(target);
    has_timeout = timeout > 0;
    deadline = i64(0);
    if has_timeout {
        deadline = _PyDeadline_Init(timeout);
    }
    failed = False;
    retval = i32(0);
    count = u64(0);
    sockstate = ssl_select(target, True, timeout);
    if sockstate == SOCKET_HAS_TIMED_OUT {
        PyErr_SetString(PyExc_TimeoutError, "The write operation timed out");
        failed = True;
    } elif sockstate == SOCKET_HAS_BEEN_CLOSED {
        PyErr_SetString(
            state_ref(module, STATE_SSL_ERROR), "Underlying socket has been closed."
        );
        failed = True;
    } elif sockstate == SOCKET_TOO_LARGE_FOR_SELECT {
        PyErr_SetString(
            state_ref(module, STATE_SSL_ERROR),
            "Underlying socket too large for select()."
        );
        failed = True;
    }
    ssl = sock.ssl;
    address = b.address();
    size = u64(b.size());
    while not failed {
        thread = PyEval_SaveThread();
        retval = SSL_write_ex(ssl, address, size, &mut count);
        c_errno = jacpy_errno();
        err_ssl = SSL_get_error(ssl, retval) if retval == 0 else i32(0);
        PyEval_RestoreThread(thread);
        sock.err_c = int(c_errno) if retval == 0 else 0;
        sock.err_ssl = int(err_ssl);
        if PyErr_CheckSignals() != 0 {
            failed = True;
            break;
        }
        if has_timeout {
            timeout = _PyDeadline_Get(deadline);
        }
        if sock.err_ssl == SSL_ERROR_WANT_READ {
            sockstate = ssl_select(target, False, timeout);
        } elif sock.err_ssl == SSL_ERROR_WANT_WRITE {
            sockstate = ssl_select(target, True, timeout);
        } else {
            sockstate = SOCKET_OPERATION_OK;
        }
        if sockstate == SOCKET_HAS_TIMED_OUT {
            PyErr_SetString(PyExc_TimeoutError, "The write operation timed out");
            failed = True;
            break;
        } elif sockstate == SOCKET_HAS_BEEN_CLOSED {
            PyErr_SetString(
                state_ref(module, STATE_SSL_ERROR), "Underlying socket has been closed."
            );
            failed = True;
            break;
        } elif sockstate == SOCKET_IS_NONBLOCKING {
            break;
        }
        if sock.err_ssl != SSL_ERROR_WANT_READ
            and sock.err_ssl != SSL_ERROR_WANT_WRITE {
            break;
        }
    }
    if target {
        jacpy_release(target);
    }
    if failed {
        chain_exceptions(sock);
        return NULL;
    }
    if retval == 0 {
        return ssl_set_error(sock, 2556);
    }
    if chain_exceptions(sock) < 0 {
        return NULL;
    }
    return PyLong_FromSize_t(count);
}

def _ssl__SSLSocket_pending_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    ssl = sock.ssl;
    thread = PyEval_SaveThread();
    count = SSL_pending(ssl);
    c_errno = jacpy_errno();
    err_ssl = SSL_get_error(ssl, count) if count < 0 else i32(0);
    PyEval_RestoreThread(thread);
    sock.err_c = int(c_errno) if count < 0 else 0;
    sock.err_ssl = int(err_ssl);
    if count < 0 {
        return ssl_set_error(sock, 2588);
    }
    return PyLong_FromLong(i64(count));
}

"""_ssl__SSLSocket_read_impl(): the optional group's buffer is `buffer`
(a Py_buffer the caller releases) when `group_right_1`."""
def ssl_socket_read(
    receiver: ptr[PyObject], size: i64, group_right_1: bool, buffer: ptr[Py_buffer]
) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if not group_right_1 and size < 0 {
        PyErr_SetString(PyExc_ValueError, "size should not be negative");
        return NULL;
    }
    target = method_socket(sock, 2630);
    if target == Py_None {
        return NULL;
    }
    if target {
        target = Py_NewRef(target);
    }
    dest = NULL;
    mem = ptr();
    length = size;
    count = u64(0);
    done = False;
    failed = False;
    if not group_right_1 {
        dest = jacpy_bytes_from_memory(ptr(), length);
        if not dest {
            failed = True;
        } elif length == 0 {
            if target {
                jacpy_release(target);
            }
            return dest;
        } else {
            mem = jacpy_bytes_address(dest);
        }
    } else {
        view = buffer.view(1)[0];
        mem = view.buf;
        if length <= 0 or length > view.length {
            length = i64(c_int(view.length));
            if view.length != length {
                PyErr_SetString(
                    PyExc_OverflowError, "maximum length can't fit in a C 'int'"
                );
                failed = True;
            } elif length == 0 {
                count = u64(0);
                done = True;
            }
        }
    }
    retval = i32(1);
    if not failed and not done {
        if target {
            sync_blocking(sock, target);
        }
        timeout = socket_timeout(target);
        has_timeout = timeout > 0;
        deadline = i64(0);
        if has_timeout {
            deadline = _PyDeadline_Init(timeout);
        }
        ssl = sock.ssl;
        while True {
            thread = PyEval_SaveThread();
            retval = SSL_read_ex(ssl, mem, u64(length), &mut count);
            c_errno = jacpy_errno();
            err_ssl = SSL_get_error(ssl, retval) if retval == 0 else i32(0);
            PyEval_RestoreThread(thread);
            sock.err_c = int(c_errno) if retval == 0 else 0;
            sock.err_ssl = int(err_ssl);
            if PyErr_CheckSignals() != 0 {
                failed = True;
                break;
            }
            if has_timeout {
                timeout = _PyDeadline_Get(deadline);
            }
            sockstate = SOCKET_OPERATION_OK;
            if sock.err_ssl == SSL_ERROR_WANT_READ {
                sockstate = ssl_select(target, False, timeout);
            } elif sock.err_ssl == SSL_ERROR_WANT_WRITE {
                sockstate = ssl_select(target, True, timeout);
            } elif sock.err_ssl == SSL_ERROR_ZERO_RETURN
                and int(SSL_get_shutdown(ssl)) == SSL_RECEIVED_SHUTDOWN {
                count = u64(0);
                done = True;
                break;
            }
            if sockstate == SOCKET_HAS_TIMED_OUT {
                PyErr_SetString(PyExc_TimeoutError, "The read operation timed out");
                failed = True;
                break;
            } elif sockstate == SOCKET_IS_NONBLOCKING {
                break;
            }
            if sock.err_ssl != SSL_ERROR_WANT_READ
                and sock.err_ssl != SSL_ERROR_WANT_WRITE {
                break;
            }
        }
        if not failed and not done {
            if retval == 0 {
                ssl_set_error(sock, 2713);
                failed = True;
            } elif sock.exc {
                failed = True;
            }
        }
    }
    if failed {
        chain_exceptions(sock);
        if target {
            jacpy_release(target);
        }
        if not group_right_1 and dest {
            jacpy_release(dest);
        }
        return NULL;
    }
    if target {
        jacpy_release(target);
    }
    if not group_right_1 {
        _PyBytes_Resize(&mut dest, i64(count));
        return dest;
    }
    return PyLong_FromSize_t(count);
}

def _ssl__SSLSocket_shutdown_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    target = get_socket(sock);
    if target {
        # Guard against a closed socket.
        if target == Py_None or int(socket_fd(target)) == -1 {
            set_ssl_error(
                module_of_socket(sock),
                ptr[u8]("Underlying socket connection gone"),
                2760
            );
            return NULL;
        }
        target = Py_NewRef(target);
        # Just in case the blocking state of the socket has been changed.
        sync_blocking(sock, target);
    }
    module = module_of_socket(sock);
    timeout = socket_timeout(target);
    has_timeout = timeout > 0;
    deadline = i64(0);
    if has_timeout {
        deadline = _PyDeadline_Init(timeout);
    }
    zeros = 0;
    ret = i32(0);
    failed = False;
    ssl = sock.ssl;
    while True {
        seen_zero = sock.shutdown_seen_zero;
        thread = PyEval_SaveThread();
        # Disable read-ahead so that unwrap can work correctly. Otherwise
        # OpenSSL might read in too much data, eating clear text data that
        # happens to be transmitted after the SSL shutdown. Should be safe to
        # call repeatedly every time this function is used and the
        # shutdown_seen_zero != 0 condition is met.
        if seen_zero {
            SSL_set_read_ahead(ssl, i32(0));
        }
        ret = SSL_shutdown(ssl);
        c_errno = jacpy_errno();
        err_ssl = SSL_get_error(ssl, ret) if ret < 0 else i32(0);
        PyEval_RestoreThread(thread);
        sock.err_c = int(c_errno) if ret < 0 else 0;
        sock.err_ssl = int(err_ssl);
        # If ret == 1, a secure shutdown with SSL_shutdown() is complete.
        if ret > 0 {
            break;
        }
        if ret == 0 {
            # Don't loop endlessly; instead preserve legacy behaviour of
            # trying SSL_shutdown() only twice.
            zeros += 1;
            if zeros > 1 {
                break;
            }
            # Shutdown was sent, now try receiving.
            sock.shutdown_seen_zero = True;
            continue;
        }
        if has_timeout {
            timeout = _PyDeadline_Get(deadline);
        }
        # Possibly retry shutdown until timeout or failure.
        sockstate = SOCKET_OPERATION_OK;
        if sock.err_ssl == SSL_ERROR_WANT_READ {
            sockstate = ssl_select(target, False, timeout);
        } elif sock.err_ssl == SSL_ERROR_WANT_WRITE {
            sockstate = ssl_select(target, True, timeout);
        } else {
            break;
        }
        if sockstate == SOCKET_HAS_TIMED_OUT {
            if sock.err_ssl == SSL_ERROR_WANT_READ {
                PyErr_SetString(PyExc_TimeoutError, "The read operation timed out");
            } else {
                PyErr_SetString(PyExc_TimeoutError, "The write operation timed out");
            }
            failed = True;
            break;
        } elif sockstate == SOCKET_TOO_LARGE_FOR_SELECT {
            PyErr_SetString(
                state_ref(module, STATE_SSL_ERROR),
                "Underlying socket too large for select()."
            );
            failed = True;
            break;
        } elif sockstate != SOCKET_OPERATION_OK {
            # Retain the SSL error code.
            break;
        }
    }
    if not failed and ret < 0 {
        if target {
            jacpy_release(target);
        }
        ssl_set_error(sock, 2841);
        return NULL;
    }
    if not failed and sock.exc {
        failed = True;
    }
    if failed {
        if target {
            jacpy_release(target);
        }
        chain_exceptions(sock);
        return NULL;
    }
    if target {
        # It already holds a reference.
        return target;
    }
    return none();
}

def _ssl__SSLSocket_get_channel_binding_impl(
    receiver: ptr[PyObject], cb_type: str
) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if cb_type != "tls-unique" {
        object_error(
            PyExc_ValueError, f"'{cb_type}' channel binding type not implemented"
        );
        return NULL;
    }
    buf = PyMem_Malloc(u64(PySSL_CB_MAXLEN));
    if not buf {
        return PyErr_NoMemory();
    }
    length = u64(0);
    if (SSL_session_reused(sock.ssl) != 0) != (sock.socket_type == PY_SSL_CLIENT) {
        # The session is resumed XOR we are the client.
        length = SSL_get_finished(sock.ssl, buf, u64(PySSL_CB_MAXLEN));
    } else {
        # A new session XOR we are the server.
        length = SSL_get_peer_finished(sock.ssl, buf, u64(PySSL_CB_MAXLEN));
    }
    # It cannot be negative in current OpenSSL versions.
    result = NULL;
    if length == u64(0) {
        result = none();
    } else {
        result = jacpy_bytes_from_memory(buf, i64(length));
    }
    PyMem_Free(buf);
    return result;
}

def _ssl__SSLSocket_verify_client_post_handshake_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    if not HAVE_POST_HS_AUTH {
        PyErr_SetString(
            PyExc_NotImplementedError,
            "Post-handshake auth is not supported by your OpenSSL version."
        );
        return NULL;
    }
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    if SSL_verify_client_post_handshake(sock.ssl) == 0 {
        return set_ssl_error(module_of_socket(sock), ptr[u8](), 2919);
    }
    return none();
}

"""A new SSLSession of the socket's context owning `session`."""
def:priv new_session_object(context: ptr[PyObject], session: ptr) -> ptr[PyObject] {
    ctx = context_of(context);
    if ctx is None {
        SSL_SESSION_free(session);
        return NULL;
    }
    type = state_ref(ctx.module, STATE_SESSION_TYPE);
    instance = jacpy_binding_allocate(type);
    if not instance {
        # It's not possible for another thread to access this, so it needs
        # no lock.
        SSL_SESSION_free(session);
        return NULL;
    }
    state = SSLSessionState(session=session, ctx=Py_NewRef(context));
    if jacpy_binding_native_set(instance, SSLSession_token.definition_of(type), state)
        < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def _ssl__SSLSocket_session_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    # get_session can return sessions from a server-side connection, it does
    # not check for handshake done or client socket.
    session = SSL_get1_session(sock.ssl);
    if not session {
        return none();
    }
    return new_session_object(sock.ctx, session);
}

def _ssl__SSLSocket_session_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    sock = socket_of(receiver);
    if sock is None {
        return -1;
    }
    return socket_set_session(sock, value);
}

def _ssl__SSLSocket_session_reused_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    sock = socket_of(receiver);
    if sock is None {
        return NULL;
    }
    return true_or_false(SSL_session_reused(sock.ssl) != 0);
}

# ---------------------------------------------------------------------------
# _SSLContext objects.

"""_set_verify_mode()."""
def:priv set_verify_mode(ctx: SSLContextState, n: int) -> int {
    mode = 0;
    if n == PY_SSL_CERT_NONE {
        mode = SSL_VERIFY_NONE;
    } elif n == PY_SSL_CERT_OPTIONAL {
        mode = SSL_VERIFY_PEER;
    } elif n == PY_SSL_CERT_REQUIRED {
        mode = SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
    } else {
        PyErr_SetString(PyExc_ValueError, "invalid value for verify_mode");
        return -1;
    }
    # bpo-37428: newPySSLSocket() sets SSL_VERIFY_POST_HANDSHAKE flag for
    # server sockets and SSL_set_post_handshake_auth() for client.
    SSL_CTX_set_verify(ctx.ctx, i32(mode), ptr());
    return 0;
}

"""SSL_CTX_ctrl() without a pointer argument."""
def:priv ctx_ctrl(ctx: ptr, command: int, larg: i64) -> i64 {
    return SSL_CTX_ctrl(ctx, i32(command), larg, ptr());
}

def _ssl__SSLContext_impl(type: ptr[PyObject], proto_version: i32) -> ptr[PyObject] {
    # Walk the MRO for the module: PyType_GetModuleByDef is required for
    # SSLContext subclasses.
    module = module_of_type(type);
    if not module {
        PyErr_Clear();
        PyErr_SetString(PyExc_RuntimeError, "Cannot find internal module state");
        return NULL;
    }
    version = int(proto_version);
    method = ptr();
    # PY_SSL_VERSION_SSL3 is a case only where SSL3_VERSION is defined and
    # OPENSSL_NO_SSL3 is not; the vendored OpenSSL is built without SSLv3
    # (openssl_constants.OPENSSL_NO_SSL3), so SSLv3_method() is never linked
    # and the version falls through to the unsupported-version error.
    if version == PY_SSL_VERSION_TLS1 and HAS_TLSv1 and not OPENSSL_NO_TLS1_METHOD {
        if not deprecated("ssl.PROTOCOL_TLSv1 is deprecated", 2) {
            return NULL;
        }
        method = TLSv1_method();
    } elif version == PY_SSL_VERSION_TLS1_1
        and HAS_TLSv1_1
        and not OPENSSL_NO_TLS1_1_METHOD {
        if not deprecated("ssl.PROTOCOL_TLSv1_1 is deprecated", 2) {
            return NULL;
        }
        method = TLSv1_1_method();
    } elif version == PY_SSL_VERSION_TLS1_2
        and HAS_TLSv1_2
        and not OPENSSL_NO_TLS1_2_METHOD {
        if not deprecated("ssl.PROTOCOL_TLSv1_2 is deprecated", 2) {
            return NULL;
        }
        method = TLSv1_2_method();
    } elif version == PY_SSL_VERSION_TLS {
        if not deprecated("ssl.PROTOCOL_TLS is deprecated", 2) {
            return NULL;
        }
        method = TLS_method();
    } elif version == PY_SSL_VERSION_TLS_CLIENT {
        method = TLS_client_method();
    } elif version == PY_SSL_VERSION_TLS_SERVER {
        method = TLS_server_method();
    }
    if not method {
        PyErr_Format(
            PyExc_ValueError,
            "invalid or unsupported protocol version %i",
            proto_version
        );
        return NULL;
    }
    # The constructor needs no lock: no other thread can touch this object
    # yet.
    thread = PyEval_SaveThread();
    ctx = SSL_CTX_new(method);
    PyEval_RestoreThread(thread);
    if not ctx {
        set_ssl_error(module, ptr[u8](), 3191);
        return NULL;
    }
    instance = jacpy_binding_allocate(type);
    if not instance {
        SSL_CTX_free(ctx);
        return NULL;
    }
    state = SSLContextState(ctx=ctx, protocol=version, module=module);
    state.tstate_mutex = mutex_new();
    alpn = ptr[AlpnProtocols](PyMem_RawMalloc(u64(16)));
    if not state.tstate_mutex or not alpn {
        if alpn {
            PyMem_RawFree(alpn);
        }
        jacpy_release(instance);
        PyErr_NoMemory();
        return NULL;
    }
    alpn.view(1)[0] = AlpnProtocols(data=ptr(), length=u32(0));
    state.alpn = alpn;
    if jacpy_binding_native_set(instance, _SSLContext_token.definition_of(type), state)
        < 0 {
        jacpy_release(instance);
        return NULL;
    }
    # Don't check host name by default.
    if version == PY_SSL_VERSION_TLS_CLIENT {
        state.check_hostname = True;
        if set_verify_mode(state, PY_SSL_CERT_REQUIRED) == -1 {
            jacpy_release(instance);
            return NULL;
        }
    } else {
        state.check_hostname = False;
        if set_verify_mode(state, PY_SSL_CERT_NONE) == -1 {
            jacpy_release(instance);
            return NULL;
        }
    }
    # Defaults.
    options = u64(SSL_OP_ALL) & ~u64(SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS);
    if version != PY_SSL_VERSION_SSL2 {
        options |= u64(SSL_OP_NO_SSLv2);
    }
    if version != PY_SSL_VERSION_SSL3 {
        options |= u64(SSL_OP_NO_SSLv3);
    }
    # Minimal security flags for server and client side context. Client
    # sockets ignore server-side parameters.
    for (flag, macro) in [
        (SSL_OP_NO_COMPRESSION, "SSL_OP_NO_COMPRESSION"),
        (SSL_OP_CIPHER_SERVER_PREFERENCE, "SSL_OP_CIPHER_SERVER_PREFERENCE"),
        (SSL_OP_SINGLE_DH_USE, "SSL_OP_SINGLE_DH_USE"),
        (SSL_OP_SINGLE_ECDH_USE, "SSL_OP_SINGLE_ECDH_USE")
    ] {
        if macro not in UNDEFINED {
            options |= u64(flag);
        }
    }
    SSL_CTX_set_options(ctx, options);
    # A bare minimum cipher list without completely broken cipher suites.
    # It's far from perfect but gives users a better head start.
    result = i32(0);
    if version != PY_SSL_VERSION_SSL2 {
        result = SSL_CTX_set_cipher_list(ctx, PY_SSL_DEFAULT_CIPHER_STRING);
    } else {
        # SSLv2 needs MD5.
        result = SSL_CTX_set_cipher_list(ctx, "HIGH:!aNULL:!eNULL");
    }
    if result == 0 {
        ERR_clear_error();
        PyErr_SetString(
            state_ref(module, STATE_SSL_ERROR), "No cipher can be selected."
        );
        jacpy_release(instance);
        ERR_clear_error();
        return NULL;
    }
    if version == PY_SSL_VERSION_TLS
        or version == PY_SSL_VERSION_TLS_CLIENT
        or version == PY_SSL_VERSION_TLS_SERVER {
        if ctx_ctrl(ctx, SSL_CTRL_SET_MIN_PROTO_VERSION, PY_SSL_MIN_PROTOCOL) == 0 {
            PyErr_Format(
                PyExc_ValueError,
                "Failed to set minimum protocol 0x%x",
                c_int(PY_SSL_MIN_PROTOCOL)
            );
            jacpy_release(instance);
            ERR_clear_error();
            return NULL;
        }
    }
    # Set SSL_MODE_RELEASE_BUFFERS. This potentially greatly reduces memory
    # usage for no cost at all.
    ctx_ctrl(ctx, SSL_CTRL_MODE, SSL_MODE_RELEASE_BUFFERS);
    params = SSL_CTX_get0_param(ctx);
    # Improve trust chain building when cross-signed intermediate
    # certificates are present. See https://bugs.python.org/issue23476.
    X509_VERIFY_PARAM_set_flags(params, u64(X509_V_FLAG_TRUSTED_FIRST));
    X509_VERIFY_PARAM_set_hostflags(params, u32(X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS));
    if HAVE_POST_HS_AUTH {
        state.post_handshake_auth = 0;
        SSL_CTX_set_post_handshake_auth(ctx, i32(0));
    }
    return instance;
}

def _ssl__SSLContext_set_ciphers_impl(
    receiver: ptr[PyObject], cipherlist: str
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    if SSL_CTX_set_cipher_list(ctx.ctx, cipherlist) == 0 {
        # Clearing the error queue is necessary on some OpenSSL versions,
        # otherwise the error will be reported again when another SSL call is
        # done.
        ERR_clear_error();
        PyErr_SetString(
            state_ref(ctx.module, STATE_SSL_ERROR), "No cipher can be selected."
        );
        return NULL;
    }
    return none();
}

def _ssl__SSLContext_get_ciphers_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    ssl = SSL_new(ctx.ctx);
    if not ssl {
        set_ssl_error(ctx.module, ptr[u8](), 3401);
        return NULL;
    }
    sk = SSL_get_ciphers(ssl);
    count = int(OPENSSL_sk_num(sk));
    result = PyList_New(count);
    if result {
        for i in range(count) {
            dct = cipher_to_dict(OPENSSL_sk_value(sk, i32(i)));
            if not dct {
                jacpy_release(result);
                result = NULL;
                break;
            }
            PyList_SetItem(result, i, dct);
        }
    }
    SSL_free(ssl);
    return result;
}

"""_selectALPN_cb(): pick the protocol from the client's list, reading the
context's protocols from C memory (the GIL may be released)."""
def:priv select_alpn_callback(
    s: ptr,
    out: ptr[ptr[u8]],
    outlen: ptr[u8],
    client_protocols: ptr[u8],
    client_protocols_len: u32,
    args: ptr
) -> i32 {
    record = ptr[AlpnProtocols](args).view(1)[0];
    server_protocols = ptr[u8](record.data);
    server_protocols_len = record.length;
    if not client_protocols {
        client_protocols = ptr[u8]("");
        client_protocols_len = u32(0);
    }
    if not server_protocols {
        server_protocols = ptr[u8]("");
        server_protocols_len = u32(0);
    }
    ret = SSL_select_next_proto(
        out,
        outlen,
        server_protocols,
        server_protocols_len,
        client_protocols,
        client_protocols_len
    );
    if ret != i32(OPENSSL_NPN_NEGOTIATED) {
        return i32(SSL_TLSEXT_ERR_NOACK);
    }
    return i32(SSL_TLSEXT_ERR_OK);
}

def _ssl__SSLContext__set_alpn_protocols_impl(
    receiver: ptr[PyObject], protos: BufferArgument
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    size = protos.size();
    if size > UINT_MAX {
        PyErr_Format(
            PyExc_OverflowError, "protocols longer than %u bytes", u32(UINT_MAX)
        );
        return NULL;
    }
    record = ctx.alpn.view(1)[0];
    if record.data {
        PyMem_RawFree(record.data);
    }
    data = PyMem_RawMalloc(u64(size) if size > 0 else u64(1));
    ctx.alpn.view(1)[0] = AlpnProtocols(
        data=data, length=u32(size) if data else u32(0)
    );
    if not data {
        return PyErr_NoMemory();
    }
    source = ptr[u8](protos.address()).view(int(size));
    target = ptr[u8](data).view(int(size));
    for i in range(int(size)) {
        target[i] = source[i];
    }
    if SSL_CTX_set_alpn_protos(ctx.ctx, data, u32(size)) != 0 {
        return PyErr_NoMemory();
    }
    SSL_CTX_set_alpn_select_cb(ctx.ctx, ptr(select_alpn_callback), ptr(ctx.alpn));
    return none();
}

def _ssl__SSLContext_verify_mode_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    # Ignore SSL_VERIFY_CLIENT_ONCE and SSL_VERIFY_POST_HANDSHAKE.
    mask = SSL_VERIFY_NONE | SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
    verify_mode = int(SSL_CTX_get_verify_mode(ctx.ctx)) & mask;
    if verify_mode == SSL_VERIFY_NONE {
        return PyLong_FromLong(PY_SSL_CERT_NONE);
    }
    if verify_mode == SSL_VERIFY_PEER {
        return PyLong_FromLong(PY_SSL_CERT_OPTIONAL);
    }
    if verify_mode == (SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT) {
        return PyLong_FromLong(PY_SSL_CERT_REQUIRED);
    }
    PyErr_SetString(
        state_ref(ctx.module, STATE_SSL_ERROR),
        "invalid return value from SSL_CTX_get_verify_mode"
    );
    return NULL;
}

def _ssl__SSLContext_verify_mode_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    n = i32(0);
    if PyArg_Parse(value, "i", &mut n) == 0 {
        return -1;
    }
    if int(n) == PY_SSL_CERT_NONE and ctx.check_hostname {
        PyErr_SetString(
            PyExc_ValueError,
            "Cannot set verify_mode to CERT_NONE when check_hostname is enabled."
        );
        return -1;
    }
    return set_verify_mode(ctx, int(n));
}

def _ssl__SSLContext_verify_flags_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    flags = X509_VERIFY_PARAM_get_flags(SSL_CTX_get0_param(ctx.ctx));
    return PyLong_FromUnsignedLong(flags);
}

def _ssl__SSLContext_verify_flags_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    new_flags = u64(0);
    if PyArg_Parse(value, "k", &mut new_flags) == 0 {
        return -1;
    }
    params = SSL_CTX_get0_param(ctx.ctx);
    flags = X509_VERIFY_PARAM_get_flags(params);
    clear = flags & ~new_flags;
    set = ~flags & new_flags;
    if clear and X509_VERIFY_PARAM_clear_flags(params, clear) == 0 {
        set_ssl_error(ctx.module, ptr[u8](), 3586);
        return -1;
    }
    if set and X509_VERIFY_PARAM_set_flags(params, set) == 0 {
        set_ssl_error(ctx.module, ptr[u8](), 3592);
        return -1;
    }
    return 0;
}

"""set_min_max_proto_version(): `what` 0 sets the minimum, 1 the maximum."""
def:priv set_min_max_proto_version(
    ctx: SSLContextState, arg: ptr[PyObject], what: int
) -> int {
    parsed = i32(0);
    if PyArg_Parse(arg, "i", &mut parsed) == 0 {
        return -1;
    }
    v = int(parsed);
    if ctx.protocol != PY_SSL_VERSION_TLS_CLIENT
        and ctx.protocol != PY_SSL_VERSION_TLS_SERVER
        and ctx.protocol != PY_SSL_VERSION_TLS {
        PyErr_SetString(
            PyExc_ValueError,
            "The context's protocol doesn't support modification of highest and lowest version."
        );
        return -1;
    }
    # Check for deprecations and supported values.
    if v == PY_PROTO_SSLv3 {
        if not deprecated("ssl.TLSVersion.SSLv3 is deprecated", 2) {
            return -1;
        }
    } elif v == PY_PROTO_TLSv1 {
        if not deprecated("ssl.TLSVersion.TLSv1 is deprecated", 2) {
            return -1;
        }
    } elif v == PY_PROTO_TLSv1_1 {
        if not deprecated("ssl.TLSVersion.TLSv1_1 is deprecated", 2) {
            return -1;
        }
    } elif v != PY_PROTO_MINIMUM_SUPPORTED
        and v != PY_PROTO_MAXIMUM_SUPPORTED
        and v != PY_PROTO_TLSv1_2
        and v != PY_PROTO_TLSv1_3 {
        PyErr_Format(
            PyExc_ValueError, "Unsupported TLS/SSL version 0x%x", u32(c_int(v))
        );
        return -1;
    }
    result = i64(0);
    if what == 0 {
        if v == PY_PROTO_MINIMUM_SUPPORTED {
            v = 0;
        } elif v == PY_PROTO_MAXIMUM_SUPPORTED {
            # Emulate max for set_min_proto_version.
            v = PY_PROTO_MAXIMUM_AVAILABLE;
        }
        result = ctx_ctrl(ctx.ctx, SSL_CTRL_SET_MIN_PROTO_VERSION, i64(v));
    } else {
        if v == PY_PROTO_MAXIMUM_SUPPORTED {
            v = 0;
        } elif v == PY_PROTO_MINIMUM_SUPPORTED {
            # Emulate max for set_min_proto_version.
            v = PY_PROTO_MINIMUM_AVAILABLE;
        }
        result = ctx_ctrl(ctx.ctx, SSL_CTRL_SET_MAX_PROTO_VERSION, i64(v));
    }
    if result == 0 {
        PyErr_Format(
            PyExc_ValueError, "Unsupported protocol version 0x%x", u32(c_int(v))
        );
        return -1;
    }
    return 0;
}

def _ssl__SSLContext_minimum_version_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    v = i64(c_int(ctx_ctrl(ctx.ctx, SSL_CTRL_GET_MIN_PROTO_VERSION, 0)));
    if v == 0 {
        v = PY_PROTO_MINIMUM_SUPPORTED;
    }
    return PyLong_FromLong(v);
}

def _ssl__SSLContext_minimum_version_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    return set_min_max_proto_version(ctx, value, 0);
}

def _ssl__SSLContext_maximum_version_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    v = i64(c_int(ctx_ctrl(ctx.ctx, SSL_CTRL_GET_MAX_PROTO_VERSION, 0)));
    if v == 0 {
        v = PY_PROTO_MAXIMUM_SUPPORTED;
    }
    return PyLong_FromLong(v);
}

def _ssl__SSLContext_maximum_version_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    return set_min_max_proto_version(ctx, value, 1);
}

def _ssl__SSLContext_num_tickets_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    return PyLong_FromSize_t(SSL_CTX_get_num_tickets(ctx.ctx));
}

def _ssl__SSLContext_num_tickets_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    num = i64(0);
    if PyArg_Parse(value, "l", &mut num) == 0 {
        return -1;
    }
    if num < 0 {
        PyErr_SetString(PyExc_ValueError, "value must be non-negative");
        return -1;
    }
    if ctx.protocol != PY_SSL_VERSION_TLS_SERVER {
        PyErr_SetString(PyExc_ValueError, "SSLContext is not a server context.");
        return -1;
    }
    if SSL_CTX_set_num_tickets(ctx.ctx, u64(num)) != 1 {
        PyErr_SetString(PyExc_ValueError, "failed to set num tickets.");
        return -1;
    }
    return 0;
}

def _ssl__SSLContext_security_level_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    return PyLong_FromLong(i64(SSL_CTX_get_security_level(ctx.ctx)));
}

def _ssl__SSLContext_options_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    return PyLong_FromUnsignedLongLong(SSL_CTX_get_options(ctx.ctx));
}

def _ssl__SSLContext_options_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    opt_no = u64(
        SSL_OP_NO_SSLv2
            | SSL_OP_NO_SSLv3
            | SSL_OP_NO_TLSv1
            | SSL_OP_NO_TLSv1_1
            | SSL_OP_NO_TLSv1_2
            | SSL_OP_NO_TLSv1_3
    );
    new_opts = u64(0);
    if PyArg_Parse(value, "O&", ptr(_PyLong_UnsignedLongLong_Converter), &mut new_opts)
        == 0 {
        return -1;
    }
    opts = SSL_CTX_get_options(ctx.ctx);
    clear = opts & ~new_opts;
    set = ~opts & new_opts;
    if (set & opt_no) != u64(0) {
        if not deprecated("ssl.OP_NO_SSL*/ssl.OP_NO_TLS* options are deprecated", 2) {
            return -1;
        }
    }
    if clear {
        SSL_CTX_clear_options(ctx.ctx, clear);
    }
    if set {
        SSL_CTX_set_options(ctx.ctx, set);
    }
    return 0;
}

def _ssl__SSLContext__host_flags_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    host_flags = X509_VERIFY_PARAM_get_hostflags(SSL_CTX_get0_param(ctx.ctx));
    return PyLong_FromUnsignedLong(u64(host_flags));
}

def _ssl__SSLContext__host_flags_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    new_flags = u32(0);
    if PyArg_Parse(value, "I", &mut new_flags) == 0 {
        return -1;
    }
    X509_VERIFY_PARAM_set_hostflags(SSL_CTX_get0_param(ctx.ctx), new_flags);
    return 0;
}

def _ssl__SSLContext_check_hostname_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    return PyBool_FromLong(i64(ctx.check_hostname));
}

def _ssl__SSLContext_check_hostname_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    check_hostname = i32(0);
    if PyArg_Parse(value, "p", &mut check_hostname) == 0 {
        return -1;
    }
    verify_mode = int(SSL_CTX_get_verify_mode(ctx.ctx)) if check_hostname else 0;
    if check_hostname and verify_mode == SSL_VERIFY_NONE {
        # check_hostname = True sets verify_mode = CERT_REQUIRED.
        if set_verify_mode(ctx, PY_SSL_CERT_REQUIRED) == -1 {
            return -1;
        }
    }
    ctx.check_hostname = bool(check_hostname);
    return 0;
}

"""get_post_handshake_auth()."""
def context_get_post_handshake_auth(instance: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(instance);
    if ctx is None {
        return NULL;
    }
    if HAVE_POST_HS_AUTH {
        return PyBool_FromLong(i64(ctx.post_handshake_auth));
    }
    return none();
}

"""set_post_handshake_auth()."""
def context_set_post_handshake_auth(
    instance: ptr[PyObject], arg: ptr[PyObject]
) -> i32 {
    ctx = context_of(instance);
    if ctx is None {
        return i32(-1);
    }
    if not arg {
        PyErr_SetString(PyExc_AttributeError, "cannot delete attribute");
        return i32(-1);
    }
    pha = PyObject_IsTrue(arg);
    if pha == -1 {
        return i32(-1);
    }
    ctx.post_handshake_auth = int(pha);
    # bpo-37428: newPySSLSocket() sets SSL_VERIFY_POST_HANDSHAKE flag for
    # server sockets and SSL_set_post_handshake_auth() for client.
    return i32(0);
}

def _ssl__SSLContext_protocol_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    return PyLong_FromLong(i64(ctx.protocol));
}

# ---------------------------------------------------------------------------
# Passwords.

import from c {
    # _PySSLPasswordInfo: _password_callback()'s userdata, in C memory, as
    # OpenSSL calls the callback with the GIL released.
    obj PasswordInfo {
        has thread_state: ptr = ptr(),
            callable: ptr = ptr(),
            password: ptr = ptr(),
            size: i32 = 0,
            error: i32 = 0;
    }
}

"""_pwinfo_set(): copy a str, bytes or bytearray password into the record."""
def:priv pwinfo_set(
    info: ptr[PasswordInfo], password: ptr[PyObject], bad_type_error: str
) -> bool {
    password_bytes = NULL;
    data = ptr();
    size = i64(0);
    if jacpy_is_unicode(password) != 0 {
        password_bytes = PyUnicode_AsUTF8String(password);
        if not password_bytes {
            return False;
        }
        data = jacpy_bytes_address(password_bytes);
        size = jacpy_bytes_length(password_bytes);
    } elif jacpy_is_bytes(password) != 0 or jacpy_is_bytearray(password) != 0 {
        data = jacpy_bytes_address(password);
        size = jacpy_bytes_length(password);
    } else {
        PyErr_SetString(PyExc_TypeError, bad_type_error);
        return False;
    }
    if size > INT_MAX {
        PyErr_Format(
            PyExc_ValueError, "password cannot be longer than %d bytes", c_int(INT_MAX)
        );
        if password_bytes {
            jacpy_release(password_bytes);
        }
        return False;
    }
    record = info.view(1)[0];
    PyMem_Free(record.password);
    copy = PyMem_Malloc(u64(size) if size > 0 else u64(1));
    if not copy {
        info.view(1)[0].password = ptr();
        PyErr_SetString(PyExc_MemoryError, "unable to allocate password buffer");
        if password_bytes {
            jacpy_release(password_bytes);
        }
        return False;
    }
    source = ptr[u8](data).view(int(size));
    target = ptr[u8](copy).view(int(size));
    for i in range(int(size)) {
        target[i] = source[i];
    }
    info.view(1)[0].password = copy;
    info.view(1)[0].size = i32(size);
    if password_bytes {
        jacpy_release(password_bytes);
    }
    return True;
}

"""_password_callback(): OpenSSL asks for the private key's password with
the GIL released; the thread state is swapped back in to ask Python."""
def:priv password_callback(buf: ptr[u8], size: i32, rwflag: i32, userdata: ptr) -> i32 {
    info = ptr[PasswordInfo](userdata);
    info.view(1)[0].thread_state = ptr(
        PyThreadState_Swap(ptr[PyThreadState](info.view(1)[0].thread_state))
    );
    failed = info.view(1)[0].error != 0;
    fn_ret = NULL;
    if not failed and info.view(1)[0].callable {
        fn_ret = PyObject_CallNoArgs(ptr[PyObject](info.view(1)[0].callable));
        failed = not fn_ret
            or not pwinfo_set(info, fn_ret, "password callback must return a string");
        if fn_ret {
            jacpy_release(fn_ret);
        }
    }
    if not failed and info.view(1)[0].size > size {
        PyErr_Format(PyExc_ValueError, "password cannot be longer than %d bytes", size);
        failed = True;
    }
    if failed {
        info.view(1)[0].thread_state = ptr(
            PyThreadState_Swap(ptr[PyThreadState](info.view(1)[0].thread_state))
        );
        info.view(1)[0].error = i32(1);
        return i32(-1);
    }
    info.view(1)[0].thread_state = ptr(
        PyThreadState_Swap(ptr[PyThreadState](info.view(1)[0].thread_state))
    );
    record = info.view(1)[0];
    length = int(record.size);
    source = ptr[u8](record.password).view(length);
    target = buf.view(length);
    for i in range(length) {
        target[i] = source[i];
    }
    return record.size;
}


"""A filesystem path argument of load_cert_chain() and
load_verify_locations(): its bytes (a new reference), or NULL with TypeError
naming the argument."""
def:priv fs_path(value: ptr[PyObject], message: str) -> ptr[PyObject] {
    result = NULL;
    if PyUnicode_FSConverter(value, &mut result) == 0 {
        if PyErr_ExceptionMatches(PyExc_TypeError) != 0 {
            PyErr_SetString(PyExc_TypeError, message);
        }
        return NULL;
    }
    return result;
}

"""The failure after an SSL_CTX_use_*_file() call: the password callback's
error, the call's errno, or OpenSSL's error."""
def:priv load_failure(
    ctx: SSLContextState, info: ptr[PasswordInfo], errno: i64, lineno: int
) {
    if info.view(1)[0].error != 0 {
        # The password callback has already set the error information.
        ERR_clear_error();
    } elif errno != 0 {
        jacpy_set_errno(errno);
        PyErr_SetFromErrno(PyExc_OSError);
        ERR_clear_error();
    } else {
        set_ssl_error(ctx.module, ptr[u8](), lineno);
    }
}

def _ssl__SSLContext_load_cert_chain_impl(
    receiver: ptr[PyObject],
    certfile: ptr[PyObject],
    keyfile: ptr[PyObject],
    password: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    openssl_ctx = ctx.ctx;
    orig_passwd_cb = SSL_CTX_get_default_passwd_cb(openssl_ctx);
    orig_passwd_userdata = SSL_CTX_get_default_passwd_cb_userdata(openssl_ctx);
    info = ptr[PasswordInfo](PyMem_RawMalloc(u64(32)));
    if not info {
        return PyErr_NoMemory();
    }
    info.view(1)[0] = PasswordInfo(
        thread_state=ptr(), callable=ptr(), password=ptr(), size=i32(0), error=i32(0)
    );
    jacpy_set_errno(0);
    ERR_clear_error();
    if keyfile == Py_None {
        keyfile = NULL;
    }
    certfile_bytes = fs_path(certfile, "certfile should be a valid filesystem path");
    if not certfile_bytes {
        PyMem_RawFree(info);
        return NULL;
    }
    keyfile_bytes = NULL;
    ok = True;
    if keyfile {
        keyfile_bytes = fs_path(keyfile, "keyfile should be a valid filesystem path");
        ok = bool(keyfile_bytes);
    }
    if ok and password != Py_None {
        if PyCallable_Check(password) != 0 {
            info.view(1)[0].callable = ptr(password);
        } elif not pwinfo_set(
            info, password, "password should be a string or callable"
        ) {
            ok = False;
        }
        if ok {
            SSL_CTX_set_default_passwd_cb(openssl_ctx, ptr(password_callback));
            SSL_CTX_set_default_passwd_cb_userdata(openssl_ctx, ptr(info));
        }
    }
    if ok {
        path = PyBytes_AsString(certfile_bytes);
        info.view(1)[0].thread_state = ptr(PyEval_SaveThread());
        PyMutex_Lock(ctx.tstate_mutex);
        r = SSL_CTX_use_certificate_chain_file(openssl_ctx, path);
        e = jacpy_errno();
        PyMutex_Unlock(ctx.tstate_mutex);
        PyEval_RestoreThread(ptr[PyThreadState](info.view(1)[0].thread_state));
        if r != 1 {
            load_failure(ctx, info, e, 4163);
            ok = False;
        }
    }
    if ok {
        path = PyBytes_AsString(keyfile_bytes if keyfile else certfile_bytes);
        info.view(1)[0].thread_state = ptr(PyEval_SaveThread());
        PyMutex_Lock(ctx.tstate_mutex);
        r = SSL_CTX_use_PrivateKey_file(openssl_ctx, path, i32(SSL_FILETYPE_PEM));
        e = jacpy_errno();
        PyMutex_Unlock(ctx.tstate_mutex);
        PyEval_RestoreThread(ptr[PyThreadState](info.view(1)[0].thread_state));
        if keyfile_bytes {
            jacpy_release(keyfile_bytes);
            keyfile_bytes = NULL;
        }
        jacpy_release(certfile_bytes);
        certfile_bytes = NULL;
        if r != 1 {
            load_failure(ctx, info, e, 4184);
            ok = False;
        }
    }
    if ok {
        info.view(1)[0].thread_state = ptr(PyEval_SaveThread());
        PyMutex_Lock(ctx.tstate_mutex);
        r = SSL_CTX_check_private_key(openssl_ctx);
        PyMutex_Unlock(ctx.tstate_mutex);
        PyEval_RestoreThread(ptr[PyThreadState](info.view(1)[0].thread_state));
        if r != 1 {
            set_ssl_error(ctx.module, ptr[u8](), 4192);
            ok = False;
        }
    }
    SSL_CTX_set_default_passwd_cb(openssl_ctx, orig_passwd_cb);
    SSL_CTX_set_default_passwd_cb_userdata(openssl_ctx, orig_passwd_userdata);
    PyMem_Free(info.view(1)[0].password);
    PyMem_RawFree(info);
    if keyfile_bytes {
        jacpy_release(keyfile_bytes);
    }
    if certfile_bytes {
        jacpy_release(certfile_bytes);
    }
    if not ok {
        return NULL;
    }
    return none();
}

"""_add_ca_certs(): load PEM or DER certificates from memory into the
context's store; -1 with the error set."""
def:priv add_ca_certs(
    ctx: SSLContextState, data: ptr, length: i64, filetype: int
) -> int {
    if length <= 0 {
        PyErr_SetString(PyExc_ValueError, "Empty certificate data");
        return -1;
    } elif length > INT_MAX {
        PyErr_SetString(PyExc_OverflowError, "Certificate data is too long.");
        return -1;
    }
    biobuf = BIO_new_mem_buf(data, i32(length));
    if not biobuf {
        set_ssl_error(ctx.module, ptr[u8]("Can't allocate buffer"), 4233);
        return -1;
    }
    store = SSL_CTX_get_cert_store(ctx.ctx);
    loaded = 0;
    was_bio_eof = False;
    while True {
        cert = ptr();
        if filetype == SSL_FILETYPE_ASN1 {
            if BIO_ctrl(biobuf, i32(BIO_CTRL_EOF), 0, ptr()) != 0 {
                was_bio_eof = True;
                break;
            }
            cert = d2i_X509_bio(biobuf, ptr());
        } else {
            cert = PEM_read_bio_X509(
                biobuf,
                ptr(),
                SSL_CTX_get_default_passwd_cb(ctx.ctx),
                SSL_CTX_get_default_passwd_cb_userdata(ctx.ctx)
            );
        }
        if not cert {
            break;
        }
        r = X509_STORE_add_cert(store, cert);
        X509_free(cert);
        if r == 0 {
            err = ERR_peek_last_error();
            if err_get_lib(err) == ERR_LIB_X509
                and err_get_reason(err) == X509_R_CERT_ALREADY_IN_HASH_TABLE {
                # The cert is already in the hash table, not an error.
                ERR_clear_error();
            } else {
                break;
            }
        }
        loaded += 1;
    }
    err = ERR_peek_last_error();
    retval = 0;
    if loaded == 0 {
        message = ptr[u8]("no start line: cadata does not contain a certificate")
            if filetype == SSL_FILETYPE_PEM
            else ptr[u8]("not enough data: cadata does not contain a certificate");
        set_ssl_error(ctx.module, message, 4282);
        retval = -1;
    } elif filetype == SSL_FILETYPE_ASN1 and was_bio_eof {
        # EOF ASN1 file, not an error.
        ERR_clear_error();
    } elif filetype == SSL_FILETYPE_PEM
        and err_get_lib(err) == ERR_LIB_PEM
        and err_get_reason(err) == PEM_R_NO_START_LINE {
        # EOF PEM file, not an error.
        ERR_clear_error();
    } elif err != u64(0) {
        set_ssl_error(ctx.module, ptr[u8](), 4295);
        retval = -1;
    }
    BIO_free(biobuf);
    return retval;
}

def _ssl__SSLContext_load_verify_locations_impl(
    receiver: ptr[PyObject],
    cafile: ptr[PyObject],
    capath: ptr[PyObject],
    cadata: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    jacpy_set_errno(0);
    if cafile == Py_None {
        cafile = NULL;
    }
    if capath == Py_None {
        capath = NULL;
    }
    if cadata == Py_None {
        cadata = NULL;
    }
    cafile_bytes = NULL;
    capath_bytes = NULL;
    ok = True;
    if not cafile and not capath and not cadata {
        PyErr_SetString(
            PyExc_TypeError, "cafile, capath and cadata cannot be all omitted"
        );
        ok = False;
    }
    if ok and cafile {
        cafile_bytes = fs_path(cafile, "cafile should be a valid filesystem path");
        ok = bool(cafile_bytes);
    }
    if ok and capath {
        capath_bytes = fs_path(capath, "capath should be a valid filesystem path");
        ok = bool(capath_bytes);
    }
    # Validate the cadata type and load cadata.
    if ok and cadata {
        invalid_cadata = False;
        if jacpy_is_unicode(cadata) != 0 {
            cadata_ascii = PyUnicode_AsASCIIString(cadata);
            if not cadata_ascii {
                if PyErr_ExceptionMatches(PyExc_UnicodeEncodeError) != 0 {
                    invalid_cadata = True;
                } else {
                    ok = False;
                }
            } else {
                r = add_ca_certs(
                    ctx,
                    jacpy_bytes_address(cadata_ascii),
                    jacpy_bytes_length(cadata_ascii),
                    SSL_FILETYPE_PEM
                );
                jacpy_release(cadata_ascii);
                ok = r != -1;
            }
        } elif PyObject_CheckBuffer(cadata) != 0 {
            view = BufferArgument();
            if not view.export(cadata, 0) {
                ok = False;
            } elif view.dimensions() > 1 {
                view.close();
                PyErr_SetString(
                    PyExc_TypeError,
                    "cadata should be a contiguous buffer with a single dimension"
                );
                ok = False;
            } else {
                r = add_ca_certs(ctx, view.address(), view.size(), SSL_FILETYPE_ASN1);
                view.close();
                ok = r != -1;
            }
        } else {
            invalid_cadata = True;
        }
        if invalid_cadata {
            PyErr_SetString(
                PyExc_TypeError,
                "cadata should be an ASCII string or a bytes-like object"
            );
            ok = False;
        }
    }
    # Load cafile or capath.
    if ok and (cafile or capath) {
        cafile_buf = PyBytes_AsString(cafile_bytes) if cafile else ptr[u8]();
        capath_buf = PyBytes_AsString(capath_bytes) if capath else ptr[u8]();
        openssl_ctx = ctx.ctx;
        thread = ctx.begin_allow_threads();
        r = SSL_CTX_load_verify_locations(openssl_ctx, cafile_buf, capath_buf);
        e = jacpy_errno();
        ctx.end_allow_threads(thread);
        if r != 1 {
            if e != 0 {
                jacpy_set_errno(e);
                PyErr_SetFromErrno(PyExc_OSError);
                ERR_clear_error();
            } else {
                set_ssl_error(ctx.module, ptr[u8](), 4416);
            }
            ok = False;
        }
    }
    if cafile_bytes {
        jacpy_release(cafile_bytes);
    }
    if capath_bytes {
        jacpy_release(capath_bytes);
    }
    if not ok {
        return NULL;
    }
    return none();
}

def _ssl__SSLContext_load_dh_params_impl(
    receiver: ptr[PyObject], filepath: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    f = Py_fopen(filepath, "rb");
    if not f {
        return NULL;
    }
    jacpy_set_errno(0);
    thread = PyEval_SaveThread();
    dh = PEM_read_DHparams(ptr(f), ptr(), ptr(), ptr());
    e = jacpy_errno();
    fclose(ptr(f));
    PyEval_RestoreThread(thread);
    if not dh {
        if e != 0 {
            jacpy_set_errno(e);
            PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, filepath);
            ERR_clear_error();
        } else {
            set_ssl_error(ctx.module, ptr[u8](), 4472);
        }
        return NULL;
    }
    if SSL_CTX_ctrl(ctx.ctx, i32(SSL_CTRL_SET_TMP_DH), 0, dh) == 0 {
        DH_free(dh);
        return set_ssl_error(ctx.module, ptr[u8](), 4478);
    }
    DH_free(dh);
    return none();
}

"""The server_hostname of _wrap_socket() and _wrap_bio(): None, or an IDN
A-label (ASCII str) without NUL bytes, as a PyMem C string (NULL for None).
Returns (False, NULL) with the error set on failure."""
def:priv wrap_hostname(hostname_obj: ptr[PyObject]) -> tuple[bool, ptr[u8]] {
    hostname = ptr[u8]();
    if hostname_obj != Py_None {
        if PyArg_Parse(hostname_obj, "es", ptr[u8]("ascii"), &mut hostname) == 0 {
            return (False, ptr[u8]());
        }
    }
    return (True, hostname);
}

def _ssl__SSLContext__wrap_socket_impl(
    receiver: ptr[PyObject],
    sock: ptr[PyObject],
    server_side: bool,
    hostname_obj: ptr[PyObject],
    owner: ptr[PyObject],
    session: ptr[PyObject]
) -> ptr[PyObject] {
    (ok, hostname) = wrap_hostname(hostname_obj);
    if not ok {
        return NULL;
    }
    res = new_ssl_socket(
        receiver,
        sock,
        PY_SSL_SERVER if server_side else PY_SSL_CLIENT,
        hostname,
        owner,
        session,
        NULL,
        NULL
    );
    if hostname {
        PyMem_Free(hostname);
    }
    return res;
}

def _ssl__SSLContext__wrap_bio_impl(
    receiver: ptr[PyObject],
    incoming: ptr[PyObject],
    outgoing: ptr[PyObject],
    server_side: bool,
    hostname_obj: ptr[PyObject],
    owner: ptr[PyObject],
    session: ptr[PyObject]
) -> ptr[PyObject] {
    (ok, hostname) = wrap_hostname(hostname_obj);
    if not ok {
        return NULL;
    }
    res = new_ssl_socket(
        receiver,
        NULL,
        PY_SSL_SERVER if server_side else PY_SSL_CLIENT,
        hostname,
        owner,
        session,
        incoming,
        outgoing
    );
    PyMem_Free(hostname);
    return res;
}

def _ssl__SSLContext_session_stats_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    stats = PyDict_New();
    if not stats {
        return NULL;
    }
    for (command, key) in [
        (SSL_CTRL_SESS_NUMBER, "number"),
        (SSL_CTRL_SESS_CONNECT, "connect"),
        (SSL_CTRL_SESS_CONNECT_GOOD, "connect_good"),
        (SSL_CTRL_SESS_CONNECT_RENEGOTIATE, "connect_renegotiate"),
        (SSL_CTRL_SESS_ACCEPT, "accept"),
        (SSL_CTRL_SESS_ACCEPT_GOOD, "accept_good"),
        (SSL_CTRL_SESS_ACCEPT_RENEGOTIATE, "accept_renegotiate"),
        (SSL_CTRL_SESS_ACCEPT, "accept"),
        (SSL_CTRL_SESS_HIT, "hits"),
        (SSL_CTRL_SESS_MISSES, "misses"),
        (SSL_CTRL_SESS_TIMEOUTS, "timeouts"),
        (SSL_CTRL_SESS_CACHE_FULL, "cache_full")
    ] {
        value = PyLong_FromLong(ctx_ctrl(ctx.ctx, command, 0));
        if not value {
            jacpy_release(stats);
            return NULL;
        }
        r = PyDict_SetItemString(stats, key, value);
        jacpy_release(value);
        if r < 0 {
            jacpy_release(stats);
            return NULL;
        }
    }
    return stats;
}

def _ssl__SSLContext_set_default_verify_paths_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    openssl_ctx = ctx.ctx;
    thread = PyEval_SaveThread();
    rc = SSL_CTX_set_default_verify_paths(openssl_ctx);
    PyEval_RestoreThread(thread);
    if rc == 0 {
        set_ssl_error(ctx.module, ptr[u8](), 4619);
        return NULL;
    }
    return none();
}

def _ssl__SSLContext_set_ecdh_curve_impl(
    receiver: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    name_bytes = NULL;
    if PyUnicode_FSConverter(name, &mut name_bytes) == 0 {
        return NULL;
    }
    nid = OBJ_sn2nid(PyBytes_AsString(name_bytes));
    jacpy_release(name_bytes);
    if nid == 0 {
        PyErr_Format(PyExc_ValueError, "unknown elliptic curve name %R", name);
        return NULL;
    }
    nids = ptr[i32](PyMem_Malloc(u64(4)));
    if not nids {
        return PyErr_NoMemory();
    }
    nids.view(1)[0] = nid;
    result = SSL_CTX_ctrl(ctx.ctx, i32(SSL_CTRL_SET_GROUPS), 1, ptr(nids));
    PyMem_Free(nids);
    if result == 0 {
        set_ssl_error(ctx.module, ptr[u8](), 4659);
        return NULL;
    }
    return none();
}

"""_servername_callback(): run the context's sni_callback for the name the
client sent."""
def:priv servername_callback(s: ptr, al: ptr[i32], args: ptr) -> i32 {
    servername = SSL_get_servername(s, i32(TLSEXT_NAMETYPE_host_name));
    gstate = PyGILState_Ensure();
    context = ptr[PyObject](args);
    ctx = context_of(context);
    sni_cb = NULL;
    if ctx is not None and ctx.set_sni_cb {
        sni_cb = Py_NewRef(ctx.set_sni_cb);
    }
    if not sni_cb {
        PyErr_Clear();
        PyGILState_Release(gstate);
        return i32(SSL_TLSEXT_ERR_OK);
    }
    instance = ptr[PyObject](SSL_get_ex_data(s, i32(0)));
    sock = socket_of(instance);
    ssl_socket = NULL;
    if sock is not None {
        # The servername callback expects an argument that represents the
        # current SSL connection and that has a .context attribute that can
        # be changed to identify the requested hostname. Pass the owner
        # (typically an SSLObject) if there is one, else the socket, else the
        # C-level object.
        ssl_socket = callback_socket(instance, sock);
    }
    if not ssl_socket {
        jacpy_release(sni_cb);
        al.view(1)[0] = i32(SSL_AD_INTERNAL_ERROR);
        PyGILState_Release(gstate);
        return i32(SSL_TLSEXT_ERR_ALERT_FATAL);
    }
    result = NULL;
    if not servername {
        result = PyObject_CallFunctionObjArgs(
            sni_cb, ssl_socket, Py_None, context, NULL
        );
    } else {
        servername_bytes = PyBytes_FromString(servername);
        if not servername_bytes {
            PyErr_FormatUnraisable("Exception ignored in ssl servername callback");
            jacpy_release(ssl_socket);
            jacpy_release(sni_cb);
            al.view(1)[0] = i32(SSL_AD_INTERNAL_ERROR);
            PyGILState_Release(gstate);
            return i32(SSL_TLSEXT_ERR_ALERT_FATAL);
        }
        # server_hostname was encoded to an A-label by our caller; put it
        # back into a str object, but still as an A-label (bpo-28414).
        servername_str = PyUnicode_FromEncodedObject(
            servername_bytes, "ascii", "strict"
        );
        if not servername_str {
            PyErr_FormatUnraisable(
                "Exception ignored in ssl servername callback while decoding name %R",
                servername_bytes
            );
            jacpy_release(servername_bytes);
            jacpy_release(ssl_socket);
            jacpy_release(sni_cb);
            al.view(1)[0] = i32(SSL_AD_INTERNAL_ERROR);
            PyGILState_Release(gstate);
            return i32(SSL_TLSEXT_ERR_ALERT_FATAL);
        }
        jacpy_release(servername_bytes);
        result = PyObject_CallFunctionObjArgs(
            sni_cb, ssl_socket, servername_str, context, NULL
        );
        jacpy_release(servername_str);
    }
    jacpy_release(ssl_socket);
    ret = i32(SSL_TLSEXT_ERR_OK);
    if not result {
        PyErr_FormatUnraisable(
            "Exception ignored in ssl servername callback while calling set SNI callback %R",
            sni_cb
        );
        al.view(1)[0] = i32(SSL_AD_HANDSHAKE_FAILURE);
        ret = i32(SSL_TLSEXT_ERR_ALERT_FATAL);
    } else {
        # The result may be None, a SSLContext or an integer: None and an
        # SSLContext are OK, an integer or other values are an error.
        if result != Py_None {
            al.view(1)[0] = c_int(PyLong_AsLong(result));
            if PyErr_Occurred() {
                PyErr_FormatUnraisable(
                    "Exception ignored in ssl servername callback while calling set SNI callback (result=%R)",
                    result
                );
                al.view(1)[0] = i32(SSL_AD_INTERNAL_ERROR);
            }
            ret = i32(SSL_TLSEXT_ERR_ALERT_FATAL);
        }
        jacpy_release(result);
    }
    jacpy_release(sni_cb);
    PyGILState_Release(gstate);
    return ret;
}

def _ssl__SSLContext_sni_callback_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    if not ctx.set_sni_cb {
        return none();
    }
    return Py_NewRef(ctx.set_sni_cb);
}

def _ssl__SSLContext_sni_callback_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    ctx = context_of(receiver);
    if ctx is None {
        return -1;
    }
    if ctx.protocol == PY_SSL_VERSION_TLS_CLIENT {
        PyErr_SetString(
            PyExc_ValueError, "sni_callback cannot be set on TLS_CLIENT context"
        );
        return -1;
    }
    if PyCallable_Check(value) == 0 {
        SSL_CTX_callback_ctrl(ctx.ctx, i32(SSL_CTRL_SET_TLSEXT_SERVERNAME_CB), ptr());
        if ctx.set_sni_cb {
            previous = ctx.set_sni_cb;
            ctx.set_sni_cb = NULL;
            jacpy_release(previous);
        }
        if value != Py_None {
            PyErr_SetString(PyExc_TypeError, "not a callable object");
            return -1;
        }
    } else {
        previous = ctx.set_sni_cb;
        ctx.set_sni_cb = Py_NewRef(value);
        if previous {
            jacpy_release(previous);
        }
        SSL_CTX_ctrl(
            ctx.ctx, i32(SSL_CTRL_SET_TLSEXT_SERVERNAME_ARG), 0, ptr(receiver)
        );
        SSL_CTX_callback_ctrl(
            ctx.ctx, i32(SSL_CTRL_SET_TLSEXT_SERVERNAME_CB), ptr(servername_callback)
        );
    }
    return 0;
}

"""sk_X509_OBJECT_pop_free(objs, X509_OBJECT_free)."""
def:priv free_objects(objs: ptr) {
    for i in range(int(OPENSSL_sk_num(objs))) {
        X509_OBJECT_free(OPENSSL_sk_value(objs, i32(i)));
    }
    OPENSSL_sk_free(objs);
}

def _ssl__SSLContext_cert_store_stats_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    objs = X509_STORE_get1_objects(SSL_CTX_get_cert_store(ctx.ctx));
    if not objs {
        PyErr_SetString(PyExc_MemoryError, "failed to query cert store");
        return NULL;
    }
    x509 = 0;
    crl = 0;
    ca = 0;
    for i in range(int(OPENSSL_sk_num(objs))) {
        obj_ = OPENSSL_sk_value(objs, i32(i));
        kind = int(X509_OBJECT_get_type(obj_));
        if kind == X509_LU_X509 {
            x509 += 1;
            if X509_check_ca(X509_OBJECT_get0_X509(obj_)) != 0 {
                ca += 1;
            }
        } elif kind == X509_LU_CRL {
            crl += 1;
        }
        # Ignore unrecognized types.
    }
    free_objects(objs);
    return Py_BuildValue(
        "{sisisi}",
        ptr[u8]("x509"),
        c_int(x509),
        ptr[u8]("crl"),
        c_int(crl),
        ptr[u8]("x509_ca"),
        c_int(ca)
    );
}

def _ssl__SSLContext_get_ca_certs_impl(
    receiver: ptr[PyObject], binary_form: bool
) -> ptr[PyObject] {
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    rlist = PyList_New(0);
    if not rlist {
        return NULL;
    }
    objs = X509_STORE_get1_objects(SSL_CTX_get_cert_store(ctx.ctx));
    if not objs {
        PyErr_SetString(PyExc_MemoryError, "failed to query cert store");
        jacpy_release(rlist);
        return NULL;
    }
    for i in range(int(OPENSSL_sk_num(objs))) {
        obj_ = OPENSSL_sk_value(objs, i32(i));
        if int(X509_OBJECT_get_type(obj_)) != X509_LU_X509 {
            # Not a x509 cert.
            continue;
        }
        # CA for any purpose.
        cert = X509_OBJECT_get0_X509(obj_);
        if X509_check_ca(cert) == 0 {
            continue;
        }
        ci = certificate_to_der(ctx.module, cert)
            if binary_form
            else decode_certificate(ctx.module, cert);
        if not ci or append_owned(rlist, ci) == -1 {
            free_objects(objs);
            jacpy_release(rlist);
            return NULL;
        }
    }
    free_objects(objs);
    return rlist;
}

# ---------------------------------------------------------------------------
# TLS-PSK.

"""The str of a NUL-terminated UTF-8 hint or identity, None when empty, or
NULL when it does not decode."""
def:priv psk_text(text: ptr[u8]) -> ptr[PyObject] {
    if not text or text.view(1)[0] == u8(0) {
        return none();
    }
    return PyUnicode_DecodeUTF8Stateful(
        ptr(text), i64(c_string_length(text)), ptr[u8]("strict"), None
    );
}

"""The PSK callback of the context of an SSL object's _SSLSocket (borrowed),
or NULL."""
def:priv psk_callback_of(s: ptr, client: bool) -> ptr[PyObject] {
    instance = ptr[PyObject](SSL_get_ex_data(s, i32(0)));
    if not instance {
        return NULL;
    }
    sock = socket_of(instance);
    if sock is None or not sock.ctx {
        PyErr_Clear();
        return NULL;
    }
    ctx = context_of(sock.ctx);
    if ctx is None {
        PyErr_Clear();
        return NULL;
    }
    return ctx.psk_client_callback if client else ctx.psk_server_callback;
}

"""psk_client_callback()."""
def:priv psk_client_callback(
    s: ptr,
    hint: ptr[u8],
    identity: ptr[u8],
    max_identity_len: u32,
    psk: ptr[u8],
    max_psk_len: u32
) -> u32 {
    gstate = PyGILState_Ensure();
    callback = psk_callback_of(s, True);
    result_len = u32(0);
    if callback {
        hint_str = psk_text(hint);
        if not hint_str {
            # The remote side has sent an invalid UTF-8 string (breaking the
            # standard): drop the connection without raising a decode
            # exception.
            PyErr_Clear();
        } else {
            result = PyObject_CallFunctionObjArgs(callback, hint_str, NULL);
            jacpy_release(hint_str);
            if result {
                identity_ = ptr[u8]();
                psk_ = ptr[u8]();
                identity_len_ = i64(0);
                psk_len_ = i64(0);
                if PyArg_ParseTuple(
                    result,
                    "z#y#",
                    &mut identity_,
                    &mut identity_len_,
                    &mut psk_,
                    &mut psk_len_
                )
                    != 0
                    and u64(identity_len_) + u64(1) <= u64(max_identity_len)
                    and u64(psk_len_) <= u64(max_psk_len) {
                    copy_memory(psk, psk_, psk_len_);
                    if identity_ {
                        copy_memory(identity, identity_, identity_len_);
                    }
                    identity.view(int(identity_len_) + 1)[int(identity_len_)] = u8(0);
                    result_len = u32(psk_len_);
                }
                jacpy_release(result);
            }
        }
    }
    if result_len == u32(0) and PyErr_Occurred() {
        PyErr_FormatUnraisable(
            "Exception ignored in ssl PSK client callback while calling callback %R",
            callback
        );
    }
    PyGILState_Release(gstate);
    return result_len;
}

def:priv copy_memory(target: ptr[u8], source: ptr[u8], length: i64) {
    to = target.view(int(length));
    from_ = source.view(int(length));
    for i in range(int(length)) {
        to[i] = from_[i];
    }
}

def _ssl__SSLContext_set_psk_client_callback_impl(
    receiver: ptr[PyObject], callback: ptr[PyObject]
) -> ptr[PyObject] {
    if OPENSSL_NO_PSK {
        PyErr_SetString(
            PyExc_NotImplementedError,
            "TLS-PSK is not supported by your OpenSSL version."
        );
        return NULL;
    }
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    if ctx.protocol == PY_SSL_VERSION_TLS_SERVER {
        set_ssl_error(
            ctx.module,
            ptr[u8]("Cannot add PSK client callback to a PROTOCOL_TLS_SERVER context"),
            5096
        );
        return NULL;
    }
    stored = NULL;
    if callback != Py_None {
        if PyCallable_Check(callback) == 0 {
            PyErr_SetString(PyExc_TypeError, "callback must be callable");
            return NULL;
        }
        stored = Py_NewRef(callback);
    }
    previous = ctx.psk_client_callback;
    ctx.psk_client_callback = stored;
    if previous {
        jacpy_release(previous);
    }
    if stored {
        SSL_CTX_set_psk_client_callback(ctx.ctx, ptr(psk_client_callback));
    } else {
        # Delete the existing callback.
        SSL_CTX_set_psk_client_callback(ctx.ctx, ptr());
    }
    return none();
}

"""psk_server_callback()."""
def:priv psk_server_callback(
    s: ptr, identity: ptr[u8], psk: ptr[u8], max_psk_len: u32
) -> u32 {
    gstate = PyGILState_Ensure();
    callback = psk_callback_of(s, False);
    result_len = u32(0);
    if callback {
        identity_str = psk_text(identity);
        if not identity_str {
            # The remote side has sent an invalid UTF-8 string (breaking the
            # standard): drop the connection without raising a decode
            # exception.
            PyErr_Clear();
        } else {
            result = PyObject_CallFunctionObjArgs(callback, identity_str, NULL);
            jacpy_release(identity_str);
            if result {
                psk_ = ptr[u8]();
                psk_len_ = i64(0);
                if PyBytes_AsStringAndSize(result, &mut psk_, &mut psk_len_) >= 0
                    and u64(psk_len_) <= u64(max_psk_len) {
                    copy_memory(psk, psk_, psk_len_);
                    result_len = u32(psk_len_);
                }
                jacpy_release(result);
            }
        }
    }
    if result_len == u32(0) and PyErr_Occurred() {
        PyErr_FormatUnraisable(
            "Exception ignored in ssl PSK server callback while calling callback %R",
            callback
        );
    }
    PyGILState_Release(gstate);
    return result_len;
}

def _ssl__SSLContext_set_psk_server_callback_impl(
    receiver: ptr[PyObject], callback: ptr[PyObject], identity_hint: ptr[u8]
) -> ptr[PyObject] {
    if OPENSSL_NO_PSK {
        PyErr_SetString(
            PyExc_NotImplementedError,
            "TLS-PSK is not supported by your OpenSSL version."
        );
        return NULL;
    }
    ctx = context_of(receiver);
    if ctx is None {
        return NULL;
    }
    if ctx.protocol == PY_SSL_VERSION_TLS_CLIENT {
        set_ssl_error(
            ctx.module,
            ptr[u8]("Cannot add PSK server callback to a PROTOCOL_TLS_CLIENT context"),
            5208
        );
        return NULL;
    }
    stored = NULL;
    hint = identity_hint;
    if callback == Py_None {
        # Delete the existing callback and hint.
        hint = ptr[u8]();
    } else {
        if PyCallable_Check(callback) == 0 {
            PyErr_SetString(PyExc_TypeError, "callback must be callable");
            return NULL;
        }
        stored = callback;
    }
    if SSL_CTX_use_psk_identity_hint(ctx.ctx, hint) != 1 {
        PyErr_SetString(PyExc_ValueError, "failed to set identity hint");
        return NULL;
    }
    previous = ctx.psk_server_callback;
    ctx.psk_server_callback = Py_NewRef(stored) if stored else NULL;
    if previous {
        jacpy_release(previous);
    }
    if stored {
        SSL_CTX_set_psk_server_callback(ctx.ctx, ptr(psk_server_callback));
    } else {
        SSL_CTX_set_psk_server_callback(ctx.ctx, ptr());
    }
    return none();
}

# ---------------------------------------------------------------------------
# MemoryBIO objects.

def _ssl_MemoryBIO_impl(type: ptr[PyObject]) -> ptr[PyObject] {
    bio = BIO_new(BIO_s_mem());
    if not bio {
        PyErr_SetString(PyExc_MemoryError, "failed to allocate BIO");
        return NULL;
    }
    # Since our BIO is non-blocking an empty read() does not indicate EOF,
    # just that no data is currently available. The SSL routines should
    # retry the read, which BIO_set_retry_read() achieves.
    BIO_set_flags(bio, i32(BIO_FLAGS_READ | BIO_FLAGS_SHOULD_RETRY));
    BIO_ctrl(bio, i32(BIO_C_SET_BUF_MEM_EOF_RETURN), -1, ptr());
    instance = jacpy_binding_allocate(type);
    if not instance {
        BIO_free(bio);
        return NULL;
    }
    state = MemoryBIOState(bio=bio, eof_written=False);
    if jacpy_binding_native_set(instance, MemoryBIO_token.definition_of(type), state)
        < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def _ssl_MemoryBIO_pending_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = memory_bio_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromSize_t(BIO_ctrl_pending(state.bio));
}

def _ssl_MemoryBIO_eof_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = memory_bio_of(receiver);
    if state is None {
        return NULL;
    }
    pending = BIO_ctrl_pending(state.bio);
    return PyBool_FromLong(i64(pending == u64(0) and state.eof_written));
}

def _ssl_MemoryBIO_read_impl(receiver: ptr[PyObject], size: i32) -> ptr[PyObject] {
    state = memory_bio_of(receiver);
    if state is None {
        return NULL;
    }
    pending = BIO_ctrl_pending(state.bio);
    avail = int(pending) if pending < u64(INT_MAX) else INT_MAX;
    length = int(size);
    if length < 0 or length > avail {
        length = avail;
    }
    result = jacpy_bytes_from_memory(ptr(), i64(length));
    if not result or length == 0 {
        return result;
    }
    nbytes = int(BIO_read(state.bio, jacpy_bytes_address(result), i32(length)));
    if nbytes < 0 {
        jacpy_release(result);
        set_ssl_error(module_of_object(receiver), ptr[u8](), 5436);
        return NULL;
    }
    # There should never be any short reads but check anyway.
    if nbytes < length {
        _PyBytes_Resize(&mut result, i64(nbytes));
    }
    return result;
}

def _ssl_MemoryBIO_write_impl(
    receiver: ptr[PyObject], b: BufferArgument
) -> ptr[PyObject] {
    state = memory_bio_of(receiver);
    if state is None {
        return NULL;
    }
    if b.size() > INT_MAX {
        PyErr_Format(
            PyExc_OverflowError, "string longer than %d bytes", c_int(INT_MAX)
        );
        return NULL;
    }
    if state.eof_written {
        module = module_of_object(receiver);
        if not module {
            return NULL;
        }
        PyErr_SetString(
            state_ref(module, STATE_SSL_ERROR), "cannot write() after write_eof()"
        );
        return NULL;
    }
    nbytes = BIO_write(state.bio, b.address(), i32(b.size()));
    if nbytes < 0 {
        set_ssl_error(module_of_object(receiver), ptr[u8](), 5483);
        return NULL;
    }
    return PyLong_FromLong(i64(nbytes));
}

def _ssl_MemoryBIO_write_eof_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = memory_bio_of(receiver);
    if state is None {
        return NULL;
    }
    state.eof_written = True;
    # After an EOF is written, a zero return from read() should be a real
    # EOF i.e. it should not be retried. Clear the SHOULD_RETRY flag.
    BIO_clear_flags(state.bio, i32(BIO_FLAGS_RWS | BIO_FLAGS_SHOULD_RETRY));
    BIO_ctrl(state.bio, i32(BIO_C_SET_BUF_MEM_EOF_RETURN), 0, ptr());
    return none();
}

# ---------------------------------------------------------------------------
# SSLSession objects.

"""PySSLSession_richcompare()."""
def session_richcompare(
    left: ptr[PyObject], right: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if not left or not right {
        PyErr_BadInternalCall();
        return NULL;
    }
    left_state = session_of(left);
    if left_state is None {
        return NULL;
    }
    left_ctx = context_of(left_state.ctx);
    if left_ctx is None {
        return NULL;
    }
    sesstype = state_ref(left_ctx.module, STATE_SESSION_TYPE);
    if Py_TYPE(left) != sesstype or Py_TYPE(right) != sesstype {
        return Py_NewRef(Py_NotImplemented);
    }
    result = 0;
    if left != right {
        right_state = session_of(right);
        if right_state is None {
            return NULL;
        }
        left_len = u32(0);
        right_len = u32(0);
        left_id = SSL_SESSION_get_id(left_state.session, &mut left_len);
        right_id = SSL_SESSION_get_id(right_state.session, &mut right_len);
        if left_len == right_len {
            first = left_id.view(int(left_len));
            second = right_id.view(int(right_len));
            for i in range(int(left_len)) {
                if first[i] != second[i] {
                    result = 1;
                    break;
                }
            }
        } else {
            result = 1;
        }
    }
    operation = int(op);
    # Py_EQ is 2, Py_NE 3; Py_LT, Py_LE, Py_GT and Py_GE are 0, 1, 4 and 5.
    if operation == 2 {
        return true_or_false(result == 0);
    }
    if operation == 3 {
        return true_or_false(result != 0);
    }
    if operation in [0, 1, 4, 5] {
        return Py_NewRef(Py_NotImplemented);
    }
    PyErr_BadArgument();
    return NULL;
}

def _ssl_SSLSession_time_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = session_of(receiver);
    if state is None {
        return NULL;
    }
    return _PyLong_FromTime_t(SSL_SESSION_get_time_ex(state.session));
}

def _ssl_SSLSession_timeout_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = session_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(SSL_SESSION_get_timeout(state.session));
}

def _ssl_SSLSession_ticket_lifetime_hint_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    state = session_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromUnsignedLong(SSL_SESSION_get_ticket_lifetime_hint(state.session));
}

def _ssl_SSLSession_id_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = session_of(receiver);
    if state is None {
        return NULL;
    }
    length = u32(0);
    identifier = SSL_SESSION_get_id(state.session, &mut length);
    return jacpy_bytes_from_memory(ptr(identifier), i64(length));
}

def _ssl_SSLSession_has_ticket_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = session_of(receiver);
    if state is None {
        return NULL;
    }
    return true_or_false(SSL_SESSION_has_ticket(state.session) != 0);
}

# ---------------------------------------------------------------------------
# Certificate objects (Modules/_ssl/cert.c).

def _ssl_Certificate_public_bytes_impl(
    receiver: ptr[PyObject], format_: i32
) -> ptr[PyObject] {
    state = certificate_of(receiver);
    if state is None {
        return NULL;
    }
    module = module_of_object(receiver);
    bio = BIO_new(BIO_s_mem());
    if not bio {
        PyErr_SetString(state_ref(module, STATE_SSL_ERROR), "failed to allocate BIO");
        return NULL;
    }
    kind = int(format_);
    retcode = i32(0);
    if kind == int(PY_SSL_ENCODING_PEM) {
        retcode = PEM_write_bio_X509(bio, state.cert);
    } elif kind == int(PY_SSL_ENCODING_PEM_AUX) {
        retcode = PEM_write_bio_X509_AUX(bio, state.cert);
    } elif kind == int(PY_SSL_ENCODING_DER) {
        retcode = i2d_X509_bio(bio, state.cert);
    } else {
        PyErr_SetString(PyExc_ValueError, "Unsupported format");
        BIO_free(bio);
        return NULL;
    }
    if retcode != 1 {
        BIO_free(bio);
        set_ssl_error(module, ptr[u8](), 105);
        return NULL;
    }
    result = NULL;
    if kind == int(PY_SSL_ENCODING_DER) {
        result = bytes_from_bio(bio);
    } else {
        result = unicode_from_bio(bio, pem_errors());
    }
    BIO_free(bio);
    return result;
}

def _ssl_Certificate_get_info_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = certificate_of(receiver);
    if state is None {
        return NULL;
    }
    return decode_certificate(module_of_object(receiver), state.cert);
}

"""certificate_repr(): "<_ssl.Certificate 'subject'>", the subject in RFC 2253
form (ASCII, with UTF-8 characters quoted)."""
def certificate_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = certificate_of(instance);
    if state is None {
        return NULL;
    }
    osubject = x509name_print(
        module_of_object(instance),
        X509_get_subject_name(state.cert),
        0,
        u64(XN_FLAG_RFC2253)
    );
    if not osubject {
        return NULL;
    }
    result = PyUnicode_FromFormat("<%s '%U'>", type_name_address(instance), osubject);
    jacpy_release(osubject);
    return result;
}

"""certificate_hash()."""
def certificate_hash(instance: ptr[PyObject]) -> i64 {
    state = certificate_of(instance);
    if state is None {
        return -1;
    }
    if state.hash == -1 {
        hash = i64(X509_subject_name_hash(state.cert));
        state.hash = -2 if hash == -1 else hash;
    }
    return state.hash;
}

"""certificate_richcompare(): == and != compare the certificates."""
def certificate_richcompare(
    lhs: ptr[PyObject], rhs: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    state = certificate_of(lhs);
    if state is None {
        return NULL;
    }
    module = module_of_object(lhs);
    if Py_TYPE(rhs) != state_ref(module, STATE_CERTIFICATE_TYPE) {
        return Py_NewRef(Py_NotImplemented);
    }
    # Only == and != are supported.
    operation = int(op);
    if operation != 2 and operation != 3 {
        return Py_NewRef(Py_NotImplemented);
    }
    other = certificate_of(rhs);
    if other is None {
        return NULL;
    }
    cmp = int(X509_cmp(state.cert, other.cert));
    return true_or_false(
        (operation == 2 and cmp == 0) or (operation == 3 and cmp != 0)
    );
}

# ---------------------------------------------------------------------------
# Module functions.

def _ssl_RAND_add_impl(
    module: ptr[PyObject], view: BufferArgument, entropy: f64
) -> ptr[PyObject] {
    buf = view.address();
    length = view.size();
    while True {
        written = length if length < INT_MAX else INT_MAX;
        RAND_add(buf, i32(written), entropy);
        buf += written;
        length -= written;
        if length == 0 {
            break;
        }
    }
    return none();
}

"""PySSL_RAND()."""
def:priv ssl_rand(module: ptr[PyObject], length: int, pseudo: bool) -> ptr[PyObject] {
    if length < 0 {
        PyErr_SetString(PyExc_ValueError, "num must be positive");
        return NULL;
    }
    data = jacpy_bytes_from_memory(ptr(), i64(length));
    if not data {
        return NULL;
    }
    ok = RAND_bytes(jacpy_bytes_address(data), i32(length));
    if pseudo {
        if ok == 0 or ok == 1 {
            return Py_BuildValue(
                "NO", data, borrowed_true() if ok == 1 else borrowed_false()
            );
        }
    } elif ok == 1 {
        return data;
    }
    jacpy_release(data);
    err = ERR_get_error();
    errstr = ERR_reason_error_string(err);
    v = Py_BuildValue("(ks)", err, errstr);
    if v {
        PyErr_SetObject(state_ref(module, STATE_SSL_ERROR), v);
        jacpy_release(v);
    }
    return NULL;
}

def _ssl_RAND_bytes_impl(module: ptr[PyObject], n: i32) -> ptr[PyObject] {
    return ssl_rand(module, int(n), False);
}

def _ssl_RAND_status_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return PyBool_FromLong(i64(RAND_status()));
}

"""CONVERT in _ssl_get_default_verify_paths_impl(): None, the path decoded
with the filesystem encoding, or its bytes."""
def:priv default_path(value: ptr[u8]) -> ptr[PyObject] {
    if not value {
        return none();
    }
    target = PyUnicode_DecodeFSDefault(value);
    if not target {
        target = PyBytes_FromString(value);
    }
    return target;
}

def _ssl_get_default_verify_paths_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    ofile_env = default_path(X509_get_default_cert_file_env());
    ofile = default_path(X509_get_default_cert_file()) if ofile_env else NULL;
    odir_env = default_path(X509_get_default_cert_dir_env()) if ofile else NULL;
    odir = default_path(X509_get_default_cert_dir()) if odir_env else NULL;
    if not odir {
        for value in [ofile_env, ofile, odir_env] {
            if value {
                jacpy_release(value);
            }
        }
        return NULL;
    }
    return Py_BuildValue("NNNN", ofile_env, ofile, odir_env, odir);
}

"""asn1obj2py(): (nid, short name, long name, oid) of an ASN.1 object."""
def:priv asn1obj_tuple(module: ptr[PyObject], obj_: ptr) -> ptr[PyObject] {
    nid = OBJ_obj2nid(obj_);
    if i64(nid) == NID_undef {
        PyErr_Format(PyExc_ValueError, "Unknown object");
        return NULL;
    }
    sn = OBJ_nid2sn(nid);
    ln = OBJ_nid2ln(nid);
    return Py_BuildValue("issN", nid, sn, ln, asn1obj2py(module, obj_, True));
}

def _ssl_txt2obj_impl(module: ptr[PyObject], txt: str, name: bool) -> ptr[PyObject] {
    obj_ = OBJ_txt2obj(txt, i32(0 if name else 1));
    if not obj_ {
        object_error(PyExc_ValueError, f"unknown object '{txt[:100]}'");
        return NULL;
    }
    result = asn1obj_tuple(module, obj_);
    ASN1_OBJECT_free(obj_);
    return result;
}

def _ssl_nid2obj_impl(module: ptr[PyObject], nid: i32) -> ptr[PyObject] {
    if i64(nid) < NID_undef {
        PyErr_SetString(PyExc_ValueError, "NID must be positive.");
        return NULL;
    }
    obj_ = OBJ_nid2obj(nid);
    if not obj_ {
        PyErr_Format(PyExc_ValueError, "unknown NID %i", nid);
        return NULL;
    }
    result = asn1obj_tuple(module, obj_);
    ASN1_OBJECT_free(obj_);
    return result;
}

# ---------------------------------------------------------------------------
# Module initialization helpers for the binding.

"""parse_openssl_version(): (major, minor, fix, patch, status)."""
def:priv version_info(libver: u64) -> ptr[PyObject] {
    status = libver & u64(0xF);
    libver = libver >> u64(4);
    patch = libver & u64(0xFF);
    libver = libver >> u64(8);
    fix = libver & u64(0xFF);
    libver = libver >> u64(8);
    minor = libver & u64(0xFF);
    libver = libver >> u64(8);
    major = libver & u64(0xFF);
    return Py_BuildValue(
        "IIIII", u32(major), u32(minor), u32(fix), u32(patch), u32(status)
    );
}

"""sslmodule_init_versioninfo()'s values: OPENSSL_VERSION_NUMBER,
OPENSSL_VERSION_INFO and OPENSSL_VERSION of the linked library, and
_OPENSSL_API_VERSION of the headers."""
def version_constants -> list[tuple[str, ptr[PyObject]]] {
    libver = OpenSSL_version_num();
    return [
        ("OPENSSL_VERSION_NUMBER", PyLong_FromUnsignedLong(libver)),
        ("OPENSSL_VERSION_INFO", version_info(libver)),
        ("OPENSSL_VERSION", c_string_text(OpenSSL_version(i32(OPENSSL_VERSION)))),
        ("_OPENSSL_API_VERSION", version_info(u64(OPENSSL_VERSION_NUMBER)))
    ];
}
