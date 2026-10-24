glob PY_SSL_ERROR_NONE: int = 0,
     PY_SSL_ERROR_SSL: int = 1,
     PY_SSL_ERROR_WANT_READ: int = 2,
     PY_SSL_ERROR_WANT_WRITE: int = 3,
     PY_SSL_ERROR_WANT_X509_LOOKUP: int = 4,
     PY_SSL_ERROR_SYSCALL: int = 5,
     PY_SSL_ERROR_ZERO_RETURN: int = 6,
     PY_SSL_ERROR_WANT_CONNECT: int = 7,
     PY_SSL_ERROR_EOF: int = 8,
     PY_SSL_ERROR_NO_SOCKET: int = 9,
     PY_SSL_ERROR_INVALID_ERROR_CODE: int = 10;

glob PY_SSL_CLIENT: int = 0,
     PY_SSL_SERVER: int = 1;

glob PY_SSL_CERT_NONE: int = 0,
     PY_SSL_CERT_OPTIONAL: int = 1,
     PY_SSL_CERT_REQUIRED: int = 2;

glob PY_SSL_VERSION_SSL2: int = 0,
     PY_SSL_VERSION_SSL3: int = 1,
     PY_SSL_VERSION_TLS: int = 2,
     PY_SSL_VERSION_TLS1: int = 3,
     PY_SSL_VERSION_TLS1_1: int = 4,
     PY_SSL_VERSION_TLS1_2: int = 5,
     PY_SSL_VERSION_TLS_CLIENT: int = 0x10,
     PY_SSL_VERSION_TLS_SERVER: int = 0x11;

glob PY_PROTO_MINIMUM_SUPPORTED: int = -2,
     PY_PROTO_SSLv3: int = SSL3_VERSION,
     PY_PROTO_TLSv1: int = TLS1_VERSION,
     PY_PROTO_TLSv1_1: int = TLS1_1_VERSION,
     PY_PROTO_TLSv1_2: int = TLS1_2_VERSION,
     PY_PROTO_TLSv1_3: int = TLS1_3_VERSION
         if "TLS1_3_VERSION" not in UNDEFINED
         else 0x304,
     PY_PROTO_MAXIMUM_SUPPORTED: int = -1;

glob SOCKET_IS_NONBLOCKING: int = 0,
     SOCKET_IS_BLOCKING: int = 1,
     SOCKET_HAS_TIMED_OUT: int = 2,
     SOCKET_HAS_BEEN_CLOSED: int = 3,
     SOCKET_TOO_LARGE_FOR_SELECT: int = 4,
     SOCKET_OPERATION_OK: int = 5;

glob X509_NAME_MAXLEN: int = 256,
     PySSL_CB_MAXLEN: int = 128,
     INVALID_SOCKET: int = -1,
     INT_MAX: int = 2147483647,
     UINT_MAX: int = 4294967295,
     PY_SSL_DEFAULT_CIPHER_STRING: str = "@SECLEVEL=2:ECDH+AESGCM:ECDH+CHACHA20:ECDH+AES:DHE+AES:!aNULL:!eNULL:!aDSS:!SHA1:!AESCCM",
     PY_SSL_MIN_PROTOCOL: int = TLS1_2_VERSION;

def:priv protocol_available(macro: str, disabled: bool) -> bool;

glob HAS_SSLv3: bool = protocol_available("SSL3_VERSION", OPENSSL_NO_SSL3),
     HAS_TLSv1: bool = protocol_available("TLS1_VERSION", OPENSSL_NO_TLS1),
     HAS_TLSv1_1: bool = protocol_available("TLS1_1_VERSION", OPENSSL_NO_TLS1_1),
     HAS_TLSv1_2: bool = protocol_available("TLS1_2_VERSION", OPENSSL_NO_TLS1_2),
     HAS_TLSv1_3: bool = protocol_available("TLS1_3_VERSION", OPENSSL_NO_TLS1_3),
     HAVE_POST_HS_AUTH: bool = "SSL_VERIFY_POST_HANDSHAKE" not in UNDEFINED
         and HAS_TLSv1_3;

def:priv minimum_available -> int;

def:priv maximum_available -> int;

glob PY_PROTO_MINIMUM_AVAILABLE: int = minimum_available(),
     PY_PROTO_MAXIMUM_AVAILABLE: int = maximum_available();

obj ModuleToken {
    has handle: ptr = ptr();
}

glob ssl_module_token: ModuleToken = ModuleToken();

glob _SSLContext_token = ClassToken(),
     _SSLSocket_token = ClassToken(),
     MemoryBIO_token = ClassToken(),
     SSLSession_token = ClassToken(),
     Certificate_token = ClassToken();

glob STATE_CONTEXT_TYPE: int = 0,
     STATE_SOCKET_TYPE: int = 1,
     STATE_MEMORY_BIO_TYPE: int = 2,
     STATE_SESSION_TYPE: int = 3,
     STATE_CERTIFICATE_TYPE: int = 4,
     STATE_SSL_ERROR: int = 5,
     STATE_CERT_VERIFICATION_ERROR: int = 6,
     STATE_ZERO_RETURN_ERROR: int = 7,
     STATE_WANT_READ_ERROR: int = 8,
     STATE_WANT_WRITE_ERROR: int = 9,
     STATE_SYSCALL_ERROR: int = 10,
     STATE_EOF_ERROR: int = 11,
     STATE_ERR_CODES_TO_NAMES: int = 12,
     STATE_LIB_CODES_TO_NAMES: int = 13,
     STATE_SOCK_TYPE: int = 14,
     STATE_STR_LIBRARY: int = 15,
     STATE_STR_REASON: int = 16,
     STATE_STR_VERIFY_CODE: int = 17,
     STATE_STR_VERIFY_MESSAGE: int = 18,
     STATE_COUNT: int = 19;

obj SSLModuleState(NativeState) {
    has keylog_lock: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject];

def module_native(module: ptr[PyObject]) -> SSLModuleState | None;

def module_of_type(type: ptr[PyObject]) -> ptr[PyObject];

def module_of_object(instance: ptr[PyObject]) -> ptr[PyObject];

def type_check(value: ptr[PyObject], type: ptr[PyObject]) -> bool;

def mutex_new -> ptr[PyMutex];

import from c {
    obj AlpnProtocols {
        has data: ptr = ptr(),
            length: u32 = 0;
    }
}

obj SSLContextState(NativeState) {
    has ctx: ptr = ptr(),
        alpn: ptr[AlpnProtocols] = ptr[AlpnProtocols](),
        set_sni_cb: ptr[PyObject] = NULL,
        check_hostname: bool = False,
        protocol: int = 0,
        post_handshake_auth: int = 0,
        msg_cb: ptr[PyObject] = NULL,
        keylog_filename: ptr[PyObject] = NULL,
        keylog_bio: ptr = ptr(),
        module: ptr[PyObject] = NULL,
        psk_client_callback: ptr[PyObject] = NULL,
        psk_server_callback: ptr[PyObject] = NULL,
        tstate_mutex: ptr[PyMutex] = ptr[PyMutex]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
    def begin_allow_threads -> ptr[PyThreadState];
    def end_allow_threads(thread: ptr[PyThreadState]);
}

obj SSLSocketState(NativeState) {
    has socket_ref: ptr[PyObject] = NULL,
        ssl: ptr = ptr(),
        ctx: ptr[PyObject] = NULL,
        shutdown_seen_zero: bool = False,
        socket_type: int = 0,
        owner: ptr[PyObject] = NULL,
        server_hostname: ptr[PyObject] = NULL,
        err_ssl: int = 0,
        err_c: int = 0,
        exc: ptr[PyObject] = NULL;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def release_ssl;
    def drop;
}

obj MemoryBIOState(NativeState) {
    has bio: ptr = ptr(),
        eof_written: bool = False;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

obj SSLSessionState(NativeState) {
    has session: ptr = ptr(),
        ctx: ptr[PyObject] = NULL;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

obj CertificateState(NativeState) {
    has cert: ptr = ptr(),
        hash: i64 = -1;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
    def drop;
}

def:priv native_of(instance: ptr[PyObject], token: ClassToken) -> NativeState | None;

def context_of(instance: ptr[PyObject]) -> SSLContextState | None;

def socket_of(instance: ptr[PyObject]) -> SSLSocketState | None;

def memory_bio_of(instance: ptr[PyObject]) -> MemoryBIOState | None;

def session_of(instance: ptr[PyObject]) -> SSLSessionState | None;

def certificate_of(instance: ptr[PyObject]) -> CertificateState | None;

def module_of_socket(sock: SSLSocketState) -> ptr[PyObject];

def fill_and_set_sslerror(
    module: ptr[PyObject],
    sock: SSLSocketState | None,
    type: ptr[PyObject],
    ssl_errno: u64,
    errstr: ptr[u8],
    lineno: int,
    errcode: u64
);

def chain_exceptions(sock: SSLSocketState) -> int;

glob:priv ERRSTR_ZERO_RETURN: ptr[u8] = ptr[u8](
         "TLS/SSL connection has been closed (EOF)"
     ),
     ERRSTR_WANT_READ: ptr[u8] = ptr[u8]("The operation did not complete (read)"),
     ERRSTR_WANT_WRITE: ptr[u8] = ptr[u8]("The operation did not complete (write)"),
     ERRSTR_WANT_X509_LOOKUP: ptr[u8] = ptr[u8](
         "The operation did not complete (X509 lookup)"
     ),
     ERRSTR_WANT_CONNECT: ptr[u8] = ptr[u8]("The operation did not complete (connect)"),
     ERRSTR_EOF: ptr[u8] = ptr[u8]("EOF occurred in violation of protocol"),
     ERRSTR_SSL_FAILURE: ptr[u8] = ptr[u8]("A failure in the SSL library occurred"),
     ERRSTR_INVALID: ptr[u8] = ptr[u8]("Invalid error code");

def ssl_set_error(sock: SSLSocketState, lineno: int) -> ptr[PyObject];

def set_ssl_error(
    module: ptr[PyObject], errstr: ptr[u8], lineno: int
) -> ptr[PyObject];

def get_socket(sock: SSLSocketState) -> ptr[PyObject];

def socket_record(sock: ptr[PyObject]) -> ptr[PySocketSockObject];

def socket_timeout(sock: ptr[PyObject]) -> i64;

def socket_fd(sock: ptr[PyObject]) -> i32;

def ssl_select(sock: ptr[PyObject], writing: bool, timeout: i64) -> int;

def free_octet_string(value: ptr);

impl protocol_available(macro: str, disabled: bool) -> bool {
    return macro not in UNDEFINED and not disabled;
}

impl minimum_available -> int {
    if HAS_SSLv3 {
        return PY_PROTO_SSLv3;
    }
    if HAS_TLSv1 {
        return PY_PROTO_TLSv1;
    }
    if HAS_TLSv1_1 {
        return PY_PROTO_TLSv1_1;
    }
    if HAS_TLSv1_2 {
        return PY_PROTO_TLSv1_2;
    }
    return PY_PROTO_TLSv1_3;
}

impl maximum_available -> int {
    if HAS_TLSv1_3 {
        return PY_PROTO_TLSv1_3;
    }
    if HAS_TLSv1_2 {
        return PY_PROTO_TLSv1_2;
    }
    if HAS_TLSv1_1 {
        return PY_PROTO_TLSv1_1;
    }
    if HAS_TLSv1 {
        return PY_PROTO_TLSv1;
    }
    return PY_PROTO_SSLv3;
}

impl SSLModuleState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl SSLModuleState.clear {}

impl SSLModuleState.drop {
    if self.keylog_lock {
        PyThread_free_lock(self.keylog_lock);
    }
}

impl state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl module_native(module: ptr[PyObject]) -> SSLModuleState | None {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, SSLModuleState) {
            return state;
        }
    }
    return None;
}

impl module_of_type(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, ssl_module_token.handle);
}

impl module_of_object(instance: ptr[PyObject]) -> ptr[PyObject] {
    return module_of_type(Py_TYPE(instance));
}

impl type_check(value: ptr[PyObject], type: ptr[PyObject]) -> bool {
    return Py_TYPE(value) == type or PyType_IsSubtype(Py_TYPE(value), type) != 0;
}

impl mutex_new -> ptr[PyMutex] {
    memory = ptr[u8](PyMem_RawMalloc(u64(1)));
    if memory {
        memory.view(1)[0] = u8(0);
    }
    return ptr[PyMutex](memory);
}

impl SSLContextState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    for value in [
        self.set_sni_cb,
        self.msg_cb,
        self.keylog_filename,
        self.psk_client_callback,
        self.psk_server_callback
    ] {
        status = visit_reference(value, visitor, context);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

impl SSLContextState.clear {
    for value in [
        self.set_sni_cb,
        self.msg_cb,
        self.keylog_filename,
        self.psk_client_callback,
        self.psk_server_callback
    ] {
        if value {
            jacpy_release(value);
        }
    }
    self.set_sni_cb = NULL;
    self.msg_cb = NULL;
    self.keylog_filename = NULL;
    self.psk_client_callback = NULL;
    self.psk_server_callback = NULL;
    if self.keylog_bio {
        bio = self.keylog_bio;
        thread = PyEval_SaveThread();
        BIO_free_all(bio);
        PyEval_RestoreThread(thread);
        self.keylog_bio = ptr();
    }
}

impl SSLContextState.drop {
    if self.ctx {
        SSL_CTX_free(self.ctx);
    }
    if self.alpn {
        record = self.alpn.view(1)[0];
        if record.data {
            PyMem_RawFree(record.data);
        }
        PyMem_RawFree(self.alpn);
    }
    if self.tstate_mutex {
        PyMem_RawFree(self.tstate_mutex);
    }
}

impl SSLContextState.begin_allow_threads -> ptr[PyThreadState] {
    thread = PyEval_SaveThread();
    PyMutex_Lock(self.tstate_mutex);
    return thread;
}

impl SSLContextState.end_allow_threads(thread: ptr[PyThreadState]) {
    PyMutex_Unlock(self.tstate_mutex);
    PyEval_RestoreThread(thread);
}

impl SSLSocketState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return visit_reference(self.exc, visitor, context);
}

impl SSLSocketState.clear {
    for value in [
        self.socket_ref,
        self.ctx,
        self.owner,
        self.server_hostname,
        self.exc
    ] {
        if value {
            jacpy_release(value);
        }
    }
    self.socket_ref = NULL;
    self.ctx = NULL;
    self.owner = NULL;
    self.server_hostname = NULL;
    self.exc = NULL;
}

impl SSLSocketState.release_ssl {
    if self.ssl {
        SSL_set_shutdown(self.ssl, i32(SSL_SENT_SHUTDOWN) | SSL_get_shutdown(self.ssl));
        SSL_free(self.ssl);
        self.ssl = ptr();
    }
}

impl SSLSocketState.drop {
    self.release_ssl();
}

impl MemoryBIOState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl MemoryBIOState.clear {}

impl MemoryBIOState.drop {
    if self.bio {
        BIO_free_all(self.bio);
    }
}

impl SSLSessionState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return visit_reference(self.ctx, visitor, context);
}

impl SSLSessionState.clear {
    if self.ctx {
        jacpy_release(self.ctx);
        self.ctx = NULL;
    }
}

impl SSLSessionState.drop {
    if self.session {
        SSL_SESSION_free(self.session);
    }
}

impl CertificateState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl CertificateState.clear {}

impl CertificateState.drop {
    if self.cert {
        X509_free(self.cert);
    }
}

impl native_of(instance: ptr[PyObject], token: ClassToken) -> NativeState | None {
    definition = token.definition_of(Py_TYPE(instance));
    if jacpy_binding_native_present(instance, definition) != 0 {
        return jacpy_binding_native_get(instance, definition);
    }
    object_error(PyExc_SystemError, "_ssl object state is unavailable");
    return None;
}

impl context_of(instance: ptr[PyObject]) -> SSLContextState | None {
    state = native_of(instance, _SSLContext_token);
    if isinstance(state, SSLContextState) {
        return state;
    }
    return None;
}

impl socket_of(instance: ptr[PyObject]) -> SSLSocketState | None {
    state = native_of(instance, _SSLSocket_token);
    if isinstance(state, SSLSocketState) {
        return state;
    }
    return None;
}

impl memory_bio_of(instance: ptr[PyObject]) -> MemoryBIOState | None {
    state = native_of(instance, MemoryBIO_token);
    if isinstance(state, MemoryBIOState) {
        return state;
    }
    return None;
}

impl session_of(instance: ptr[PyObject]) -> SSLSessionState | None {
    state = native_of(instance, SSLSession_token);
    if isinstance(state, SSLSessionState) {
        return state;
    }
    return None;
}

impl certificate_of(instance: ptr[PyObject]) -> CertificateState | None {
    state = native_of(instance, Certificate_token);
    if isinstance(state, CertificateState) {
        return state;
    }
    return None;
}

impl module_of_socket(sock: SSLSocketState) -> ptr[PyObject] {
    ctx = context_of(sock.ctx);
    return ctx.module if ctx is not None else NULL;
}

impl fill_and_set_sslerror(
    module: ptr[PyObject],
    sock: SSLSocketState | None,
    type: ptr[PyObject],
    ssl_errno: u64,
    errstr: ptr[u8],
    lineno: int,
    errcode: u64
) {
    reason_obj = NULL;
    lib_obj = NULL;
    verify_obj = NULL;
    verify_code_obj = NULL;
    err_value = NULL;
    writer = ptr[PyUnicodeWriter]();
    message = errstr;
    failed = False;
    if errcode != u64(0) {
        lib = err_get_lib(errcode);
        reason = err_get_reason(errcode);
        key = Py_BuildValue("ii", c_int(lib), c_int(reason));
        if not key {
            return;
        }
        reason_obj = PyDict_GetItemWithError(
            state_ref(module, STATE_ERR_CODES_TO_NAMES), key
        );
        jacpy_release(key);
        if not reason_obj and PyErr_Occurred() {
            return;
        }
        key = PyLong_FromLong(lib);
        if not key {
            return;
        }
        lib_obj = PyDict_GetItemWithError(
            state_ref(module, STATE_LIB_CODES_TO_NAMES), key
        );
        jacpy_release(key);
        if not lib_obj and PyErr_Occurred() {
            return;
        }
        if not message {
            message = ERR_reason_error_string(errcode);
        }
    }
    is_verification = False;
    if sock is not None and type == state_ref(module, STATE_CERT_VERIFICATION_ERROR) {
        is_verification = True;
        verify_code = SSL_get_verify_result(sock.ssl);
        verify_code_obj = PyLong_FromLong(verify_code);
        if not verify_code_obj {
            return;
        }
        if verify_code == X509_V_ERR_HOSTNAME_MISMATCH {
            verify_obj = PyUnicode_FromFormat(
                "Hostname mismatch, certificate is not valid for '%S'.",
                sock.server_hostname
            );
        } elif verify_code == X509_V_ERR_IP_ADDRESS_MISMATCH {
            verify_obj = PyUnicode_FromFormat(
                "IP address mismatch, certificate is not valid for '%S'.",
                sock.server_hostname
            );
        } else {
            verify_str = X509_verify_cert_error_string(verify_code);
            if verify_str {
                verify_obj = c_string_text(verify_str);
            } else {
                verify_obj = Py_NewRef(Py_None);
            }
        }
        if not verify_obj {
            jacpy_release(verify_code_obj);
            return;
        }
    }

    writer = PyUnicodeWriter_Create(64);
    failed = not writer;
    if not failed and lib_obj {
        failed = PyUnicodeWriter_Format(writer, "[%S", lib_obj) < 0
            or (
                bool(reason_obj)
                and PyUnicodeWriter_Format(writer, ": %S", reason_obj) < 0
            )
            or PyUnicodeWriter_WriteASCII(writer, ptr[u8]("] "), 2) < 0;
    }
    if not failed {
        if message {
            failed = PyUnicodeWriter_Format(writer, "%s", message) < 0;
        } else {
            failed = PyUnicodeWriter_Format(writer, "unknown error (0x%lx)", errcode)
                < 0;
        }
    }
    if not failed and verify_obj {
        failed = PyUnicodeWriter_Format(writer, ": %S", verify_obj) < 0;
    }
    if not failed {
        failed = PyUnicodeWriter_Format(writer, " (_ssl.c:%d)", c_int(lineno)) < 0;
    }
    msg = NULL;
    if not failed {
        msg = PyUnicodeWriter_Finish(writer);
        writer = ptr[PyUnicodeWriter]();
        failed = not msg;
    }
    if not failed {
        init_value = Py_BuildValue("iN", c_int(err_get_reason(ssl_errno)), msg);
        if init_value {
            err_value = PyObject_CallObject(type, init_value);
            jacpy_release(init_value);
        }
        failed = not err_value;
    }
    if not failed {
        failed = PyObject_SetAttr(
            err_value, state_ref(module, STATE_STR_REASON), reason_obj or Py_None
        )
            != 0
            or PyObject_SetAttr(
                err_value, state_ref(module, STATE_STR_LIBRARY), lib_obj or Py_None
            )
                != 0;
    }
    if not failed and is_verification {
        failed = PyObject_SetAttr(
            err_value, state_ref(module, STATE_STR_VERIFY_CODE), verify_code_obj
        )
            != 0
            or PyObject_SetAttr(
                err_value, state_ref(module, STATE_STR_VERIFY_MESSAGE), verify_obj
            )
                != 0;
    }
    if not failed {
        PyErr_SetObject(type, err_value);
    }
    if err_value {
        jacpy_release(err_value);
    }
    if verify_code_obj {
        jacpy_release(verify_code_obj);
    }
    if verify_obj {
        jacpy_release(verify_obj);
    }
    PyUnicodeWriter_Discard(writer);
}

impl chain_exceptions(sock: SSLSocketState) -> int {
    if not sock.exc {
        return 0;
    }
    _PyErr_ChainExceptions1(sock.exc);
    sock.exc = NULL;
    return -1;
}

impl ssl_set_error(sock: SSLSocketState, lineno: int) -> ptr[PyObject] {
    module = module_of_socket(sock);
    type = state_ref(module, STATE_SSL_ERROR);
    errstr = ptr[u8]();
    p = PY_SSL_ERROR_NONE;

    e = ERR_peek_last_error();
    if sock.ssl {
        err_ssl = sock.err_ssl;
        if err_ssl == SSL_ERROR_ZERO_RETURN {
            errstr = ERRSTR_ZERO_RETURN;
            type = state_ref(module, STATE_ZERO_RETURN_ERROR);
            p = PY_SSL_ERROR_ZERO_RETURN;
        } elif err_ssl == SSL_ERROR_WANT_READ {
            errstr = ERRSTR_WANT_READ;
            type = state_ref(module, STATE_WANT_READ_ERROR);
            p = PY_SSL_ERROR_WANT_READ;
        } elif err_ssl == SSL_ERROR_WANT_WRITE {
            p = PY_SSL_ERROR_WANT_WRITE;
            type = state_ref(module, STATE_WANT_WRITE_ERROR);
            errstr = ERRSTR_WANT_WRITE;
        } elif err_ssl == SSL_ERROR_WANT_X509_LOOKUP {
            p = PY_SSL_ERROR_WANT_X509_LOOKUP;
            errstr = ERRSTR_WANT_X509_LOOKUP;
        } elif err_ssl == SSL_ERROR_WANT_CONNECT {
            p = PY_SSL_ERROR_WANT_CONNECT;
            errstr = ERRSTR_WANT_CONNECT;
        } elif err_ssl == SSL_ERROR_SYSCALL {
            if e == u64(0) {
                ERR_clear_error();
                if sock.err_c {
                    jacpy_set_errno(i64(sock.err_c));
                    return PyErr_SetFromErrno(PyExc_OSError);
                }
                p = PY_SSL_ERROR_EOF;
                type = state_ref(module, STATE_EOF_ERROR);
                errstr = ERRSTR_EOF;
            } else {
                if err_get_lib(e) == ERR_LIB_SSL
                    and err_get_reason(e) == SSL_R_CERTIFICATE_VERIFY_FAILED {
                    type = state_ref(module, STATE_CERT_VERIFICATION_ERROR);
                }
                if err_get_lib(e) == ERR_LIB_SYS {
                    jacpy_set_errno(err_get_reason(e));
                    return PyErr_SetFromErrno(PyExc_OSError);
                }
                p = PY_SSL_ERROR_SYSCALL;
            }
        } elif err_ssl == SSL_ERROR_SSL {
            p = PY_SSL_ERROR_SSL;
            if e == u64(0) {
                errstr = ERRSTR_SSL_FAILURE;
            }
            if err_get_lib(e) == ERR_LIB_SSL
                and err_get_reason(e) == SSL_R_CERTIFICATE_VERIFY_FAILED {
                type = state_ref(module, STATE_CERT_VERIFICATION_ERROR);
            }
            if "SSL_R_UNEXPECTED_EOF_WHILE_READING" not in UNDEFINED
                and err_get_lib(e) == ERR_LIB_SSL
                and err_get_reason(e) == SSL_R_UNEXPECTED_EOF_WHILE_READING {
                p = PY_SSL_ERROR_EOF;
                type = state_ref(module, STATE_EOF_ERROR);
                errstr = ERRSTR_EOF;
            }
            if err_get_lib(e) == ERR_LIB_SYS {
                jacpy_set_errno(err_get_reason(e));
                return PyErr_SetFromErrno(PyExc_OSError);
            }
        } else {
            p = PY_SSL_ERROR_INVALID_ERROR_CODE;
            errstr = ERRSTR_INVALID;
        }
    }
    fill_and_set_sslerror(module, sock, type, u64(p), errstr, lineno, e);
    ERR_clear_error();
    chain_exceptions(sock);
    return NULL;
}

impl set_ssl_error(
    module: ptr[PyObject], errstr: ptr[u8], lineno: int
) -> ptr[PyObject] {
    errcode = u64(0);
    if not errstr {
        errcode = c_size(i64(c_int(i64(ERR_peek_last_error()))));
    }
    fill_and_set_sslerror(
        module,
        None,
        state_ref(module, STATE_SSL_ERROR),
        errcode,
        errstr,
        lineno,
        errcode
    );
    ERR_clear_error();
    return NULL;
}

impl get_socket(sock: SSLSocketState) -> ptr[PyObject] {
    if not sock.socket_ref {
        return NULL;
    }
    target = NULL;
    if PyWeakref_GetRef(sock.socket_ref, &mut target) > 0 {
        jacpy_release(target);
        return target;
    }
    return Py_None;
}

impl socket_record(sock: ptr[PyObject]) -> ptr[PySocketSockObject] {
    return ptr[PySocketSockObject](sock);
}

impl socket_timeout(sock: ptr[PyObject]) -> i64 {
    if not sock {
        return 0;
    }
    return socket_record(sock).view(1)[0].sock_timeout;
}

impl socket_fd(sock: ptr[PyObject]) -> i32 {
    return socket_record(sock).view(1)[0].sock_fd;
}

impl ssl_select(sock: ptr[PyObject], writing: bool, timeout: i64) -> int {
    if not sock or timeout == 0 {
        return SOCKET_IS_NONBLOCKING;
    } elif timeout < 0 {
        if socket_timeout(sock) > 0 {
            return SOCKET_HAS_TIMED_OUT;
        }
        return SOCKET_IS_BLOCKING;
    }

    fd = socket_fd(sock);
    if int(fd) == INVALID_SOCKET {
        return SOCKET_HAS_BEEN_CLOSED;
    }

    request = pollfd(fd=fd, events=i16(POLLOUT if writing else POLLIN), revents=i16(0));

    ms = c_int(_PyTime_AsMilliseconds(timeout, _PyTime_ROUND_CEILING));
    thread = PyEval_SaveThread();
    rc = poll(&mut request, u64(1), ms);
    PyEval_RestoreThread(thread);

    return SOCKET_HAS_TIMED_OUT if rc == 0 else SOCKET_OPERATION_OK;
}

impl free_octet_string(value: ptr) {
    if value {
        ASN1_OCTET_STRING_free(value);
    }
}
