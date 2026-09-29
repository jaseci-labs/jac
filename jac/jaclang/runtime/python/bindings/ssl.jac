"""The _ssl module: its types over the generated clinic tables, the SSLError
hierarchy, the published constants and the execution slots in
Modules/_ssl.c's order."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyArg_ParseTuple,
    PyErr_SetString,
    PyExc_TypeError,
    PyMem_Free,
    PyTuple_Size,
    PyDict_New,
    PyDict_SetItem,
    PyErr_NewExceptionWithDoc,
    PyErr_NoMemory,
    PyExc_OSError,
    PyExc_ValueError,
    PyLong_FromLong,
    PyLong_FromUnsignedLongLong,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyModule_AddStringConstant,
    PyObject,
    PyObject_Str,
    PyThread_allocate_lock,
    PyTuple_Pack,
    PyType_FromSpecWithBases,
    PyType_Slot,
    PyType_Spec,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    Py_BuildValue,
    Py_NewRef,
    Py_TYPE,
    Py_buffer,
    jacpy_buffer_release,
    jacpy_is_unicode,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    PyOSErrorObject,
    PySocketModule_APIObject,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_IMMUTABLETYPE,
    Py_tp_doc,
    Py_tp_str,
    PY_OS_ERROR_OBJECT_SIZE
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.object_model.capsule { PyCapsule_Import }
import from jaclang.runtime.python.object_model.bool { py_true, py_false }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_module_native_set,
    jacpy_binding_state_get,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    PropertyCallbacks,
    PropertyDefinition,
    TypeDefinition,
    TypeFlags,
    TypeHooks
}
import from jaclang.runtime.python.bindings.payload {
    clear_payload,
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.modules.socket_address { new_view }
import from jaclang.runtime.python.bindings.clinic.ssl {
    Certificate_methods,
    MemoryBIO_getset,
    MemoryBIO_methods,
    SSLSession_getset,
    _SSLContext_getset,
    _SSLContext_methods,
    _SSLSocket_getset,
    _SSLSocket_methods,
    _ssl_MemoryBIO_new,
    _ssl__SSLContext_new,
    module_methods
}
import from jaclang.runtime.python.modules.openssl_constants {
    SSL_AD_ACCESS_DENIED,
    SSL_AD_BAD_CERTIFICATE,
    SSL_AD_BAD_CERTIFICATE_HASH_VALUE,
    SSL_AD_BAD_CERTIFICATE_STATUS_RESPONSE,
    SSL_AD_BAD_RECORD_MAC,
    SSL_AD_CERTIFICATE_EXPIRED,
    SSL_AD_CERTIFICATE_REVOKED,
    SSL_AD_CERTIFICATE_UNKNOWN,
    SSL_AD_CERTIFICATE_UNOBTAINABLE,
    SSL_AD_CLOSE_NOTIFY,
    SSL_AD_DECODE_ERROR,
    SSL_AD_DECOMPRESSION_FAILURE,
    SSL_AD_DECRYPT_ERROR,
    SSL_AD_HANDSHAKE_FAILURE,
    SSL_AD_ILLEGAL_PARAMETER,
    SSL_AD_INSUFFICIENT_SECURITY,
    SSL_AD_INTERNAL_ERROR,
    SSL_AD_NO_RENEGOTIATION,
    SSL_AD_PROTOCOL_VERSION,
    SSL_AD_RECORD_OVERFLOW,
    SSL_AD_UNEXPECTED_MESSAGE,
    SSL_AD_UNKNOWN_CA,
    SSL_AD_UNKNOWN_PSK_IDENTITY,
    SSL_AD_UNRECOGNIZED_NAME,
    SSL_AD_UNSUPPORTED_CERTIFICATE,
    SSL_AD_UNSUPPORTED_EXTENSION,
    SSL_AD_USER_CANCELLED,
    OPENSSL_NO_PSK,
    SSL_OP_ALL,
    SSL_OP_CIPHER_SERVER_PREFERENCE,
    SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS,
    SSL_OP_ENABLE_KTLS,
    SSL_OP_ENABLE_MIDDLEBOX_COMPAT,
    SSL_OP_IGNORE_UNEXPECTED_EOF,
    SSL_OP_LEGACY_SERVER_CONNECT,
    SSL_OP_NO_COMPRESSION,
    SSL_OP_NO_RENEGOTIATION,
    SSL_OP_NO_SSLv2,
    SSL_OP_NO_SSLv3,
    SSL_OP_NO_TICKET,
    SSL_OP_NO_TLSv1,
    SSL_OP_NO_TLSv1_1,
    SSL_OP_NO_TLSv1_2,
    SSL_OP_NO_TLSv1_3,
    SSL_OP_SINGLE_DH_USE,
    SSL_OP_SINGLE_ECDH_USE,
    UNDEFINED,
    X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT,
    X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS,
    X509_CHECK_FLAG_NEVER_CHECK_SUBJECT,
    X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS,
    X509_CHECK_FLAG_NO_WILDCARDS,
    X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS,
    X509_V_FLAG_ALLOW_PROXY_CERTS,
    X509_V_FLAG_CRL_CHECK,
    X509_V_FLAG_CRL_CHECK_ALL,
    X509_V_FLAG_PARTIAL_CHAIN,
    X509_V_FLAG_TRUSTED_FIRST,
    X509_V_FLAG_X509_STRICT
}
import from jaclang.runtime.python.modules.ssl_errors { ERROR_CODES, LIBRARY_CODES }
import from jaclang.runtime.python.modules.ssl_core {
    Certificate_token,
    HAS_SSLv3,
    HAS_TLSv1,
    HAS_TLSv1_1,
    HAS_TLSv1_2,
    HAS_TLSv1_3,
    HAVE_POST_HS_AUTH,
    MemoryBIO_token,
    PY_PROTO_MAXIMUM_SUPPORTED,
    PY_PROTO_MINIMUM_SUPPORTED,
    PY_PROTO_SSLv3,
    PY_PROTO_TLSv1,
    PY_PROTO_TLSv1_1,
    PY_PROTO_TLSv1_2,
    PY_PROTO_TLSv1_3,
    PY_SSL_CERT_NONE,
    PY_SSL_CERT_OPTIONAL,
    PY_SSL_CERT_REQUIRED,
    PY_SSL_DEFAULT_CIPHER_STRING,
    PY_SSL_ERROR_EOF,
    PY_SSL_ERROR_INVALID_ERROR_CODE,
    PY_SSL_ERROR_SSL,
    PY_SSL_ERROR_SYSCALL,
    PY_SSL_ERROR_WANT_CONNECT,
    PY_SSL_ERROR_WANT_READ,
    PY_SSL_ERROR_WANT_WRITE,
    PY_SSL_ERROR_WANT_X509_LOOKUP,
    PY_SSL_ERROR_ZERO_RETURN,
    PY_SSL_VERSION_SSL3,
    PY_SSL_VERSION_TLS,
    PY_SSL_VERSION_TLS1,
    PY_SSL_VERSION_TLS1_1,
    PY_SSL_VERSION_TLS1_2,
    PY_SSL_VERSION_TLS_CLIENT,
    PY_SSL_VERSION_TLS_SERVER,
    SSLModuleState,
    SSLSession_token,
    STATE_CERTIFICATE_TYPE,
    STATE_CERT_VERIFICATION_ERROR,
    STATE_CONTEXT_TYPE,
    STATE_COUNT,
    STATE_EOF_ERROR,
    STATE_ERR_CODES_TO_NAMES,
    STATE_LIB_CODES_TO_NAMES,
    STATE_MEMORY_BIO_TYPE,
    STATE_SESSION_TYPE,
    STATE_SOCKET_TYPE,
    STATE_SOCK_TYPE,
    STATE_SSL_ERROR,
    STATE_STR_LIBRARY,
    STATE_STR_REASON,
    STATE_STR_VERIFY_CODE,
    STATE_STR_VERIFY_MESSAGE,
    STATE_SYSCALL_ERROR,
    STATE_WANT_READ_ERROR,
    STATE_WANT_WRITE_ERROR,
    STATE_ZERO_RETURN_ERROR,
    _SSLContext_token,
    _SSLSocket_token,
    socket_of,
    ssl_module_token
}
import from jaclang.runtime.python.modules.ssl {
    PY_SSL_ENCODING_DER,
    PY_SSL_ENCODING_PEM,
    certificate_hash,
    certificate_repr,
    certificate_richcompare,
    context_get_keylog_filename,
    context_get_msg_callback,
    context_get_post_handshake_auth,
    context_set_keylog_filename,
    context_set_msg_callback,
    context_set_post_handshake_auth,
    session_richcompare,
    ssl_socket_read,
    version_constants
}

# ---------------------------------------------------------------------------
# SSLError

"""SSLError_str(): the strerror when it is a str, else str(args)."""
def:priv sslerror_str(op: ptr[PyObject]) -> ptr[PyObject] {
    error = ptr[PyOSErrorObject](op).view(1)[0];
    if error.strerror and jacpy_is_unicode(error.strerror) != 0 {
        return Py_NewRef(error.strerror);
    }
    return PyObject_Str(error.args);
}

import from c {
    glob:priv sslerror_slots: list[PyType_Slot] = [
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8]("An error occurred in the SSL implementation.")
             ),
             PyType_Slot(slot=Py_tp_str, pfunc=ptr(sslerror_str)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob sslerror_type_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("ssl.SSLError"),
             basicsize=i32(PY_OS_ERROR_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(sslerror_slots)
         );
}

# ---------------------------------------------------------------------------
# Type hooks.

def:priv context_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, _SSLContext_token.definition_of(Py_TYPE(instance)));
}

def:priv context_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, _SSLContext_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

def:priv context_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, _SSLContext_token.definition_of(Py_TYPE(instance)));
}

"""PySSL_dealloc(): the SSL object is marked shut down and freed before the
references are cleared."""
def:priv socket_dealloc(instance: ptr[PyObject]) {
    sock = socket_of(instance);
    if sock is not None {
        sock.release_ssl();
    }
    dispose_payload(instance, _SSLSocket_token.definition_of(Py_TYPE(instance)));
}

def:priv socket_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, _SSLSocket_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

def:priv socket_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, _SSLSocket_token.definition_of(Py_TYPE(instance)));
}

def:priv memory_bio_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, MemoryBIO_token.definition_of(Py_TYPE(instance)));
}

def:priv memory_bio_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(
        instance, MemoryBIO_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

def:priv session_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, SSLSession_token.definition_of(Py_TYPE(instance)));
}

def:priv session_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(
        instance, SSLSession_token.definition_of(Py_TYPE(instance)), visitor, context
    );
}

def:priv session_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, SSLSession_token.definition_of(Py_TYPE(instance)));
}

def:priv certificate_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, Certificate_token.definition_of(Py_TYPE(instance)));
}

# The hand-written getters and setters of _SSLContext.

def:priv keylog_filename_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return context_get_keylog_filename(instance);
}

def:priv keylog_filename_set(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    return context_set_keylog_filename(instance, value);
}

def:priv msg_callback_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return context_get_msg_callback(instance);
}

def:priv msg_callback_set(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    return context_set_msg_callback(instance, value);
}

def:priv post_handshake_auth_get(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return context_get_post_handshake_auth(instance);
}

def:priv post_handshake_auth_set(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    return context_set_post_handshake_auth(instance, value);
}

"""_ssl._SSLSocket.read(size, [buffer]): a clinic optional group, parsed as
the generated C does, by argument count."""
def:priv socket_read_call(
    receiver: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    size = i64(0);
    count = PyTuple_Size(args);
    if count == 1 {
        if PyArg_ParseTuple(args, "n:read", &mut size) == 0 {
            return NULL;
        }
        return ssl_socket_read(receiver, size, False, ptr[Py_buffer]());
    }
    if count == 2 {
        buffer = new_view();
        if not buffer {
            return NULL;
        }
        if PyArg_ParseTuple(args, "nw*:read", &mut size, buffer) == 0 {
            PyMem_Free(ptr(buffer));
            return NULL;
        }
        result = ssl_socket_read(receiver, size, True, buffer);
        jacpy_buffer_release(buffer);
        return result;
    }
    PyErr_SetString(PyExc_TypeError, "_ssl._SSLSocket.read requires 1 to 2 arguments");
    return NULL;
}

glob:priv GC_TYPE: u64 = u64(TypeFlags.GC.value),
     context_type = TypeDefinition(
         "_ssl._SSLContext",
         "",
         _SSLContext_methods,
         u64(TypeFlags.BASETYPE.value | TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=_ssl__SSLContext_new,
             dealloc=context_dealloc,
             traverse=context_traverse,
             clear=context_clear
         ),
         _SSLContext_getset
             + [
                 PropertyDefinition(
                     "keylog_filename",
                     PropertyCallbacks(
                         read=keylog_filename_get, write=keylog_filename_set
                     )
                 ),
                 PropertyDefinition(
                     "_msg_callback",
                     PropertyCallbacks(read=msg_callback_get, write=msg_callback_set)
                 ),
                 PropertyDefinition(
                     "post_handshake_auth",
                     PropertyCallbacks(
                         read=post_handshake_auth_get, write=post_handshake_auth_set
                     )
                         if HAVE_POST_HS_AUTH
                         else PropertyCallbacks(read=post_handshake_auth_get)
                 )
             ]
     ),
     socket_type = TypeDefinition(
         "_ssl._SSLSocket",
         "",
         _SSLSocket_methods
             + [
                 MethodDefinition(
                     "read",
                     MethodCallbacks(positional=socket_read_call),
                     "read(size, [buffer])\nRead up to size bytes from the SSL socket.",
                     flags=1
                 )
             ],
         u64(
             TypeFlags.IMMUTABLE.value
                 | TypeFlags.GC.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
         ),
         TypeHooks(
             dealloc=socket_dealloc, traverse=socket_traverse, clear=socket_clear
         ),
         _SSLSocket_getset
     ),
     memory_bio_type = TypeDefinition(
         "_ssl.MemoryBIO",
         "",
         MemoryBIO_methods,
         u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
         TypeHooks(
             create=_ssl_MemoryBIO_new,
             dealloc=memory_bio_dealloc,
             traverse=memory_bio_traverse
         ),
         MemoryBIO_getset
     ),
     session_type = TypeDefinition(
         "_ssl.SSLSession",
         "",
         [],
         u64(
             TypeFlags.GC.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
         ),
         TypeHooks(
             compare=session_richcompare,
             dealloc=session_dealloc,
             traverse=session_traverse,
             clear=session_clear
         ),
         SSLSession_getset
     ),
     certificate_type = TypeDefinition(
         "_ssl.Certificate",
         "",
         Certificate_methods,
         u64(TypeFlags.DISALLOW_INSTANTIATION.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             dealloc=certificate_dealloc,
             repr=certificate_repr,
             hash=certificate_hash,
             compare=certificate_richcompare
         )
     );

# ---------------------------------------------------------------------------
# Execution slots.

"""sslmodule_init_types()."""
def:priv init_types(module: ptr[PyObject]) -> bool {
    _SSLContext_token.handle = context_type.handle;
    _SSLSocket_token.handle = socket_type.handle;
    MemoryBIO_token.handle = memory_bio_type.handle;
    SSLSession_token.handle = session_type.handle;
    Certificate_token.handle = certificate_type.handle;
    for (index, definition) in [
        (STATE_CONTEXT_TYPE, context_type),
        (STATE_SOCKET_TYPE, socket_type),
        (STATE_MEMORY_BIO_TYPE, memory_bio_type),
        (STATE_SESSION_TYPE, session_type),
        (STATE_CERTIFICATE_TYPE, certificate_type)
    ] {
        created = definition.create(module);
        if not created {
            return False;
        }
        jacpy_binding_state_set(module, i64(index), created);
        jacpy_release(created);
    }
    for (index, name) in [
        (STATE_CONTEXT_TYPE, "_SSLContext"),
        (STATE_SOCKET_TYPE, "_SSLSocket"),
        (STATE_MEMORY_BIO_TYPE, "MemoryBIO"),
        (STATE_SESSION_TYPE, "SSLSession"),
        (STATE_CERTIFICATE_TYPE, "Certificate")
    ] {
        if PyModule_AddObjectRef(
            module, name, jacpy_binding_state_get(module, i64(index))
        )
            < 0 {
            return False;
        }
    }
    return True;
}

"""An exception in module state slot `index`, also published as `name`."""
def:priv add_exception(
    module: ptr[PyObject], index: int, name: str, doc: str, base: ptr[PyObject]
) -> bool {
    exc = PyErr_NewExceptionWithDoc("ssl." + name, doc, base, NULL);
    if not exc {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), exc);
    jacpy_release(exc);
    return PyModule_AddObjectRef(module, name, exc) == 0;
}

"""sslmodule_init_exceptions()."""
def:priv init_exceptions(module: ptr[PyObject]) -> bool {
    sslerror = PyType_FromSpecWithBases(addressof(sslerror_type_spec), PyExc_OSError);
    if not sslerror {
        return False;
    }
    jacpy_binding_state_set(module, i64(STATE_SSL_ERROR), sslerror);
    jacpy_release(sslerror);
    if PyModule_AddObjectRef(module, "SSLError", sslerror) < 0 {
        return False;
    }
    # ssl.CertificateError used to be a subclass of ValueError.
    bases = PyTuple_Pack(2, sslerror, PyExc_ValueError);
    if not bases {
        return False;
    }
    ok = add_exception(
        module,
        STATE_CERT_VERIFICATION_ERROR,
        "SSLCertVerificationError",
        "A certificate could not be verified.",
        bases
    );
    jacpy_release(bases);
    return ok
        and add_exception(
            module,
            STATE_ZERO_RETURN_ERROR,
            "SSLZeroReturnError",
            "SSL/TLS session closed cleanly.",
            sslerror
        )
        and add_exception(
            module,
            STATE_WANT_WRITE_ERROR,
            "SSLWantWriteError",
            "Non-blocking SSL socket needs to write more data\nbefore the requested operation can be completed.",
            sslerror
        )
        and add_exception(
            module,
            STATE_WANT_READ_ERROR,
            "SSLWantReadError",
            "Non-blocking SSL socket needs to read more data\nbefore the requested operation can be completed.",
            sslerror
        )
        and add_exception(
            module,
            STATE_SYSCALL_ERROR,
            "SSLSyscallError",
            "System error when attempting SSL operation.",
            sslerror
        )
        and add_exception(
            module,
            STATE_EOF_ERROR,
            "SSLEOFError",
            "SSL/TLS connection terminated abruptly.",
            sslerror
        );
}

"""sslmodule_init_socketapi(): the socket type of _socket's C API capsule."""
def:priv init_socketapi(module: ptr[PyObject]) -> bool {
    sockmod = ptr[PySocketModule_APIObject](
        PyCapsule_Import(ptr[u8]("_socket.CAPI"), i32(1))
    );
    if not sockmod {
        return False;
    }
    sock_type = ptr[PyObject](sockmod.view(1)[0].Sock_Type);
    if not sock_type {
        return False;
    }
    jacpy_binding_state_set(module, i64(STATE_SOCK_TYPE), sock_type);
    return True;
}

"""sslmodule_init_errorcodes(): err_codes_to_names and lib_codes_to_names."""
def:priv init_errorcodes(module: ptr[PyObject]) -> bool {
    err_codes_to_names = PyDict_New();
    if not err_codes_to_names {
        return False;
    }
    jacpy_binding_state_set(module, i64(STATE_ERR_CODES_TO_NAMES), err_codes_to_names);
    jacpy_release(err_codes_to_names);
    lib_codes_to_names = PyDict_New();
    if not lib_codes_to_names {
        return False;
    }
    jacpy_binding_state_set(module, i64(STATE_LIB_CODES_TO_NAMES), lib_codes_to_names);
    jacpy_release(lib_codes_to_names);
    for (mnemonic, library, reason) in ERROR_CODES {
        mnemo = PyUnicode_FromString(mnemonic);
        if not mnemo {
            return False;
        }
        key = Py_BuildValue("ii", i32(library), i32(reason));
        if not key {
            jacpy_release(mnemo);
            return False;
        }
        rc = PyDict_SetItem(err_codes_to_names, key, mnemo);
        jacpy_release(key);
        jacpy_release(mnemo);
        if rc < 0 {
            return False;
        }
    }
    for (library, code) in LIBRARY_CODES {
        key = PyLong_FromLong(code);
        mnemo = PyUnicode_FromString(library);
        if not key or not mnemo {
            return False;
        }
        if PyDict_SetItem(lib_codes_to_names, key, mnemo) != 0 {
            return False;
        }
        jacpy_release(key);
        jacpy_release(mnemo);
    }
    return True;
}

"""defined(NAME) for a macro of openssl_constants."""
def:priv defined(name: str) -> bool {
    return name not in UNDEFINED;
}

"""sslmodule_init_constants()."""
def:priv init_constants(module: ptr[PyObject]) -> bool {
    if PyModule_AddStringConstant(
        module, "_DEFAULT_CIPHERS", PY_SSL_DEFAULT_CIPHER_STRING
    )
        < 0 {
        return False;
    }
    constants: list[tuple[str, int]] = [
        ("SSL_ERROR_ZERO_RETURN", PY_SSL_ERROR_ZERO_RETURN),
        ("SSL_ERROR_WANT_READ", PY_SSL_ERROR_WANT_READ),
        ("SSL_ERROR_WANT_WRITE", PY_SSL_ERROR_WANT_WRITE),
        ("SSL_ERROR_WANT_X509_LOOKUP", PY_SSL_ERROR_WANT_X509_LOOKUP),
        ("SSL_ERROR_SYSCALL", PY_SSL_ERROR_SYSCALL),
        ("SSL_ERROR_SSL", PY_SSL_ERROR_SSL),
        ("SSL_ERROR_WANT_CONNECT", PY_SSL_ERROR_WANT_CONNECT),
        # non ssl.h errorcodes
        ("SSL_ERROR_EOF", PY_SSL_ERROR_EOF),
        ("SSL_ERROR_INVALID_ERROR_CODE", PY_SSL_ERROR_INVALID_ERROR_CODE),
        # cert requirements
        ("CERT_NONE", PY_SSL_CERT_NONE),
        ("CERT_OPTIONAL", PY_SSL_CERT_OPTIONAL),
        ("CERT_REQUIRED", PY_SSL_CERT_REQUIRED),
        # CRL verification for verification_flags
        ("VERIFY_DEFAULT", 0),
        ("VERIFY_CRL_CHECK_LEAF", X509_V_FLAG_CRL_CHECK),
        ("VERIFY_CRL_CHECK_CHAIN", X509_V_FLAG_CRL_CHECK | X509_V_FLAG_CRL_CHECK_ALL),
        ("VERIFY_X509_STRICT", X509_V_FLAG_X509_STRICT),
        ("VERIFY_ALLOW_PROXY_CERTS", X509_V_FLAG_ALLOW_PROXY_CERTS),
        ("VERIFY_X509_TRUSTED_FIRST", X509_V_FLAG_TRUSTED_FIRST)
    ];
    if defined("X509_V_FLAG_PARTIAL_CHAIN") {
        constants.append(("VERIFY_X509_PARTIAL_CHAIN", X509_V_FLAG_PARTIAL_CHAIN));
    }
    # Alert Descriptions from ssl.h; RESERVED constants no longer intended
    # for use have been removed.
    # http://www.iana.org/assignments/tls-parameters/tls-parameters.xml#tls-parameters-6
    constants += [
        ("ALERT_DESCRIPTION_CLOSE_NOTIFY", SSL_AD_CLOSE_NOTIFY),
        ("ALERT_DESCRIPTION_UNEXPECTED_MESSAGE", SSL_AD_UNEXPECTED_MESSAGE),
        ("ALERT_DESCRIPTION_BAD_RECORD_MAC", SSL_AD_BAD_RECORD_MAC),
        ("ALERT_DESCRIPTION_RECORD_OVERFLOW", SSL_AD_RECORD_OVERFLOW),
        ("ALERT_DESCRIPTION_DECOMPRESSION_FAILURE", SSL_AD_DECOMPRESSION_FAILURE),
        ("ALERT_DESCRIPTION_HANDSHAKE_FAILURE", SSL_AD_HANDSHAKE_FAILURE),
        ("ALERT_DESCRIPTION_BAD_CERTIFICATE", SSL_AD_BAD_CERTIFICATE),
        ("ALERT_DESCRIPTION_UNSUPPORTED_CERTIFICATE", SSL_AD_UNSUPPORTED_CERTIFICATE),
        ("ALERT_DESCRIPTION_CERTIFICATE_REVOKED", SSL_AD_CERTIFICATE_REVOKED),
        ("ALERT_DESCRIPTION_CERTIFICATE_EXPIRED", SSL_AD_CERTIFICATE_EXPIRED),
        ("ALERT_DESCRIPTION_CERTIFICATE_UNKNOWN", SSL_AD_CERTIFICATE_UNKNOWN),
        ("ALERT_DESCRIPTION_ILLEGAL_PARAMETER", SSL_AD_ILLEGAL_PARAMETER),
        ("ALERT_DESCRIPTION_UNKNOWN_CA", SSL_AD_UNKNOWN_CA),
        ("ALERT_DESCRIPTION_ACCESS_DENIED", SSL_AD_ACCESS_DENIED),
        ("ALERT_DESCRIPTION_DECODE_ERROR", SSL_AD_DECODE_ERROR),
        ("ALERT_DESCRIPTION_DECRYPT_ERROR", SSL_AD_DECRYPT_ERROR),
        ("ALERT_DESCRIPTION_PROTOCOL_VERSION", SSL_AD_PROTOCOL_VERSION),
        ("ALERT_DESCRIPTION_INSUFFICIENT_SECURITY", SSL_AD_INSUFFICIENT_SECURITY),
        ("ALERT_DESCRIPTION_INTERNAL_ERROR", SSL_AD_INTERNAL_ERROR),
        ("ALERT_DESCRIPTION_USER_CANCELLED", SSL_AD_USER_CANCELLED),
        ("ALERT_DESCRIPTION_NO_RENEGOTIATION", SSL_AD_NO_RENEGOTIATION)
    ];
    # Not all constants are in old OpenSSL versions.
    for (name, value, macro) in [
        (
            "ALERT_DESCRIPTION_UNSUPPORTED_EXTENSION",
            SSL_AD_UNSUPPORTED_EXTENSION,
            "SSL_AD_UNSUPPORTED_EXTENSION"
        ),
        (
            "ALERT_DESCRIPTION_CERTIFICATE_UNOBTAINABLE",
            SSL_AD_CERTIFICATE_UNOBTAINABLE,
            "SSL_AD_CERTIFICATE_UNOBTAINABLE"
        ),
        (
            "ALERT_DESCRIPTION_UNRECOGNIZED_NAME",
            SSL_AD_UNRECOGNIZED_NAME,
            "SSL_AD_UNRECOGNIZED_NAME"
        ),
        (
            "ALERT_DESCRIPTION_BAD_CERTIFICATE_STATUS_RESPONSE",
            SSL_AD_BAD_CERTIFICATE_STATUS_RESPONSE,
            "SSL_AD_BAD_CERTIFICATE_STATUS_RESPONSE"
        ),
        (
            "ALERT_DESCRIPTION_BAD_CERTIFICATE_HASH_VALUE",
            SSL_AD_BAD_CERTIFICATE_HASH_VALUE,
            "SSL_AD_BAD_CERTIFICATE_HASH_VALUE"
        ),
        (
            "ALERT_DESCRIPTION_UNKNOWN_PSK_IDENTITY",
            SSL_AD_UNKNOWN_PSK_IDENTITY,
            "SSL_AD_UNKNOWN_PSK_IDENTITY"
        )
    ] {
        if defined(macro) {
            constants.append((name, value));
        }
    }
    # protocol versions
    if HAS_SSLv3 {
        constants.append(("PROTOCOL_SSLv3", PY_SSL_VERSION_SSL3));
    }
    constants += [
        ("PROTOCOL_SSLv23", PY_SSL_VERSION_TLS),
        ("PROTOCOL_TLS", PY_SSL_VERSION_TLS),
        ("PROTOCOL_TLS_CLIENT", PY_SSL_VERSION_TLS_CLIENT),
        ("PROTOCOL_TLS_SERVER", PY_SSL_VERSION_TLS_SERVER),
        ("PROTOCOL_TLSv1", PY_SSL_VERSION_TLS1),
        ("PROTOCOL_TLSv1_1", PY_SSL_VERSION_TLS1_1),
        ("PROTOCOL_TLSv1_2", PY_SSL_VERSION_TLS1_2)
    ];
    for (name, value) in constants {
        if PyModule_AddIntConstant(module, name, i64(value)) < 0 {
            return False;
        }
    }
    # protocol options
    options: list[tuple[str, int]] = [
        ("OP_ALL", SSL_OP_ALL & ~SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS),
        ("OP_NO_SSLv2", SSL_OP_NO_SSLv2),
        ("OP_NO_SSLv3", SSL_OP_NO_SSLv3),
        ("OP_NO_TLSv1", SSL_OP_NO_TLSv1),
        ("OP_NO_TLSv1_1", SSL_OP_NO_TLSv1_1),
        ("OP_NO_TLSv1_2", SSL_OP_NO_TLSv1_2),
        ("OP_NO_TLSv1_3", SSL_OP_NO_TLSv1_3 if defined("SSL_OP_NO_TLSv1_3") else 0),
        ("OP_CIPHER_SERVER_PREFERENCE", SSL_OP_CIPHER_SERVER_PREFERENCE),
        ("OP_SINGLE_DH_USE", SSL_OP_SINGLE_DH_USE),
        ("OP_NO_TICKET", SSL_OP_NO_TICKET),
        ("OP_LEGACY_SERVER_CONNECT", SSL_OP_LEGACY_SERVER_CONNECT)
    ];
    for (name, value, macro) in [
        ("OP_SINGLE_ECDH_USE", SSL_OP_SINGLE_ECDH_USE, "SSL_OP_SINGLE_ECDH_USE"),
        ("OP_NO_COMPRESSION", SSL_OP_NO_COMPRESSION, "SSL_OP_NO_COMPRESSION"),
        (
            "OP_ENABLE_MIDDLEBOX_COMPAT",
            SSL_OP_ENABLE_MIDDLEBOX_COMPAT,
            "SSL_OP_ENABLE_MIDDLEBOX_COMPAT"
        ),
        ("OP_NO_RENEGOTIATION", SSL_OP_NO_RENEGOTIATION, "SSL_OP_NO_RENEGOTIATION"),
        (
            "OP_IGNORE_UNEXPECTED_EOF",
            SSL_OP_IGNORE_UNEXPECTED_EOF,
            "SSL_OP_IGNORE_UNEXPECTED_EOF"
        ),
        ("OP_ENABLE_KTLS", SSL_OP_ENABLE_KTLS, "SSL_OP_ENABLE_KTLS")
    ] {
        if defined(macro) {
            options.append((name, value));
        }
    }
    for (name, value) in options {
        if PyModule_Add(module, name, PyLong_FromUnsignedLongLong(u64(value))) < 0 {
            return False;
        }
    }
    host_flags: list[tuple[str, int]] = [];
    for (name, value, macro) in [
        (
            "HOSTFLAG_ALWAYS_CHECK_SUBJECT",
            X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT,
            "X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT"
        ),
        (
            "HOSTFLAG_NEVER_CHECK_SUBJECT",
            X509_CHECK_FLAG_NEVER_CHECK_SUBJECT,
            "X509_CHECK_FLAG_NEVER_CHECK_SUBJECT"
        ),
        (
            "HOSTFLAG_NO_WILDCARDS",
            X509_CHECK_FLAG_NO_WILDCARDS,
            "X509_CHECK_FLAG_NO_WILDCARDS"
        ),
        (
            "HOSTFLAG_NO_PARTIAL_WILDCARDS",
            X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS,
            "X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS"
        ),
        (
            "HOSTFLAG_MULTI_LABEL_WILDCARDS",
            X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS,
            "X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS"
        ),
        (
            "HOSTFLAG_SINGLE_LABEL_SUBDOMAINS",
            X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS,
            "X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS"
        )
    ] {
        if defined(macro) {
            host_flags.append((name, value));
        }
    }
    host_flags += [
        # file types
        ("ENCODING_PEM", int(PY_SSL_ENCODING_PEM)),
        ("ENCODING_DER", int(PY_SSL_ENCODING_DER)),
        # protocol versions
        ("PROTO_MINIMUM_SUPPORTED", PY_PROTO_MINIMUM_SUPPORTED),
        ("PROTO_MAXIMUM_SUPPORTED", PY_PROTO_MAXIMUM_SUPPORTED),
        ("PROTO_SSLv3", PY_PROTO_SSLv3),
        ("PROTO_TLSv1", PY_PROTO_TLSv1),
        ("PROTO_TLSv1_1", PY_PROTO_TLSv1_1),
        ("PROTO_TLSv1_2", PY_PROTO_TLSv1_2),
        ("PROTO_TLSv1_3", PY_PROTO_TLSv1_3)
    ];
    for (name, value) in host_flags {
        if PyModule_AddIntConstant(module, name, i64(value)) < 0 {
            return False;
        }
    }
    for (name, flag) in [
        ("HAS_SNI", True),
        ("HAS_TLS_UNIQUE", True),
        ("HAS_ECDH", True),
        ("HAS_NPN", False),
        ("HAS_ALPN", True),
        ("HAS_SSLv2", False),
        ("HAS_SSLv3", HAS_SSLv3),
        ("HAS_TLSv1", HAS_TLSv1),
        ("HAS_TLSv1_1", HAS_TLSv1_1),
        ("HAS_TLSv1_2", HAS_TLSv1_2),
        ("HAS_TLSv1_3", HAS_TLSv1_3),
        ("HAS_PSK", not OPENSSL_NO_PSK),
        ("HAS_PHA", defined("SSL_VERIFY_POST_HANDSHAKE"))
    ] {
        if PyModule_AddObjectRef(module, name, py_true() if flag else py_false()) < 0 {
            return False;
        }
    }
    return True;
}

"""sslmodule_init_versioninfo()."""
def:priv init_versioninfo(module: ptr[PyObject]) -> bool {
    for (name, value) in version_constants() {
        if PyModule_Add(module, name, value) < 0 {
            return False;
        }
    }
    return True;
}

"""sslmodule_init_strings()."""
def:priv init_strings(module: ptr[PyObject]) -> bool {
    for (index, text) in [
        (STATE_STR_LIBRARY, "library"),
        (STATE_STR_REASON, "reason"),
        (STATE_STR_VERIFY_MESSAGE, "verify_message"),
        (STATE_STR_VERIFY_CODE, "verify_code")
    ] {
        interned = PyUnicode_InternFromString(text);
        if not interned {
            return False;
        }
        jacpy_binding_state_set(module, i64(index), interned);
        jacpy_release(interned);
    }
    return True;
}

"""sslmodule_init_lock()."""
def:priv init_lock(module: ptr[PyObject]) -> bool {
    lock = PyThread_allocate_lock();
    if not lock {
        PyErr_NoMemory();
        return False;
    }
    jacpy_binding_module_native_set(module, SSLModuleState(keylog_lock=lock));
    return True;
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    ssl_module_token.handle = definition.handle;
    if not init_types(module)
        or not init_exceptions(module)
        or not init_socketapi(module)
        or not init_errorcodes(module)
        or not init_constants(module)
        or not init_versioninfo(module)
        or not init_strings(module)
        or not init_lock(module) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_ssl",
         "Implementation module for SSL socket operations.  See the socket module\nfor documentation.",
         module_methods,
         ModuleHooks(execute=execute),
         STATE_COUNT
     );

def:pub PyInit__ssl -> ptr[PyObject] {
    return definition.initialize();
}
