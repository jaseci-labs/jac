"""HMAC objects; derived from CPython 3.14.6 Modules/hmacmodule.c.

See ../LICENSE.cpython. An HMAC object holds the HMAC core of
na_stdlib/_digest.jac: inner and outer digest cores keyed by the padded key.
The 32-bit length limits of the C module's HACL* calls are kept.
"""

glob HMAC_token = ClassToken();

glob UNKNOWN_HASH_ERROR: int = 0,
     HMAC_TYPE: int = 1;

glob:priv UINT32_MAX: i64 = 0xFFFFFFFF,
     HASH_NAMES: list[str] = [
         "md5",
         "sha1",
         "sha224",
         "sha256",
         "sha384",
         "sha512",
         "sha3_224",
         "sha3_256",
         "sha3_384",
         "sha3_512",
         "blake2s",
         "blake2b"
     ],
     HASH_ALIASES: list[str] = [
         "",
         "",
         "sha2_224",
         "sha2_256",
         "sha2_384",
         "sha2_512",
         "",
         "",
         "",
         "",
         "blake2s_32",
         "blake2b_32"
     ];

def:priv hash_name(name: str) -> str;

def:priv find_hash_name(module: ptr[PyObject], ref: ptr[PyObject]) -> str;

def:priv sized_buffer(value: ptr[PyObject], kind: str) -> BufferArgument | None;

def _hmac_new_impl(
    module: ptr[PyObject],
    keyobj: ptr[PyObject],
    msgobj: ptr[PyObject],
    hash_info_ref: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_HMAC_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_update_impl(
    receiver: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_HMAC_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_name_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_block_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _hmac_HMAC_digest_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def hmac_repr(instance: ptr[PyObject]) -> ptr[PyObject];

def:priv oneshot(
    name: str, keyobj: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_digest_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject], digest: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_md5_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha1_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha2_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_sha3_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_blake2s_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _hmac_compute_blake2b_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

impl hash_name(name: str) -> str {
    for index in range(len(HASH_NAMES)) {
        if name == HASH_NAMES[index]
            or (HASH_ALIASES[index] and name == HASH_ALIASES[index]) {
            return HASH_NAMES[index];
        }
    }
    return "";
}

impl find_hash_name(module: ptr[PyObject], ref: ptr[PyObject]) -> str {
    if jacpy_is_unicode(ref) != 0 {
        if not PyUnicode_AsUTF8(ref) {
            return "";
        }
        found = hash_name(text_value(ref));
        if found {
            return found;
        }
        lower = PyObject_GetAttrString(ref, ptr[u8]("lower"));
        if not lower {
            return "";
        }
        lowered = PyObject_CallNoArgs(lower);
        jacpy_release(lower);
        if not lowered {
            return "";
        }
        if not PyUnicode_AsUTF8(lowered) {
            jacpy_release(lowered);
            return "";
        }
        found = hash_name(text_value(lowered));
        jacpy_release(lowered);
        if found {
            return found;
        }
    }
    shown = PyObject_Repr(ref);
    if not shown {
        return "";
    }
    prefix = PyUnicode_FromString(ptr[u8]("unsupported hash type: "));
    message = PyUnicode_Concat(prefix, shown) if prefix else NULL;
    jacpy_release(prefix);
    jacpy_release(shown);
    if message {
        PyErr_SetObject(jacpy_binding_state_get(module, UNKNOWN_HASH_ERROR), message);
        jacpy_release(message);
    }
    return "";
}

impl sized_buffer(value: ptr[PyObject], kind: str) -> BufferArgument | None {
    view = hash_buffer(value);
    if view is not None and view.size() > UINT32_MAX {
        view.close();
        object_error(PyExc_OverflowError, f"{kind} length exceeds {UINT32_MAX}");
        return None;
    }
    return view;
}

impl _hmac_new_impl(
    module: ptr[PyObject],
    keyobj: ptr[PyObject],
    msgobj: ptr[PyObject],
    hash_info_ref: ptr[PyObject]
) -> ptr[PyObject] {
    if not hash_info_ref {
        object_error(PyExc_TypeError, "new() missing 1 required argument 'digestmod'");
        return NULL;
    }
    name = find_hash_name(module, hash_info_ref);
    if not name {
        return NULL;
    }
    key = sized_buffer(keyobj, "key");
    if key is None {
        return NULL;
    }
    core = new_hmac(name, int(key.address()), key.size());
    key.close();
    if core is None {
        PyErr_NoMemory();
        return NULL;
    }
    return digest_object(
        jacpy_binding_state_get(module, HMAC_TYPE),
        HMAC_token,
        core,
        msgobj if msgobj and msgobj != Py_None else NULL
    );
}

impl _hmac_HMAC_copy_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_copy(receiver, HMAC_token);
}

impl _hmac_HMAC_update_impl(
    receiver: ptr[PyObject], msgobj: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_update(receiver, HMAC_token, msgobj);
}

impl _hmac_HMAC_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, HMAC_token, False);
}

impl _hmac_HMAC_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, HMAC_token, True);
}

impl _hmac_HMAC_name_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = digest_state(receiver, HMAC_token);
    if state is None {
        return NULL;
    }
    return jacpy_unicode_from_text("hmac-" + state.core.name);
}

impl _hmac_HMAC_block_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_property(receiver, HMAC_token, 2);
}

impl _hmac_HMAC_digest_size_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_property(receiver, HMAC_token, 1);
}

impl hmac_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = digest_state(instance, HMAC_token);
    if state is None {
        return NULL;
    }
    number = PyLong_FromVoidPtr(instance);
    if not number {
        return NULL;
    }
    address = PyNumber_ToBase(number, 16);
    jacpy_release(number);
    if not address {
        return NULL;
    }
    head = jacpy_unicode_from_text(f"<{state.core.name} HMAC object @ ");
    tail = PyUnicode_FromString(ptr[u8](">"));
    result = NULL;
    if head and tail {
        joined = PyUnicode_Concat(head, address);
        if joined {
            result = PyUnicode_Concat(joined, tail);
            jacpy_release(joined);
        }
    }
    jacpy_release(head);
    jacpy_release(tail);
    jacpy_release(address);
    return result;
}

impl oneshot(name: str, keyobj: ptr[PyObject], msgobj: ptr[PyObject]) -> ptr[PyObject] {
    key_size = small_bytes(keyobj);
    msg_size = small_bytes(msgobj);
    if key_size >= 0 and msg_size >= 0 {
        quick = new_hmac(name, int(jacpy_bytes_address(keyobj)), key_size);
        if quick is None {
            PyErr_NoMemory();
            return NULL;
        }
        quick.absorb(int(jacpy_bytes_address(msgobj)), msg_size);
        digest = quick.finish();
        return jacpy_bytes_from_payload(digest, i64(len(digest)));
    }
    key = sized_buffer(keyobj, "key");
    if key is None {
        return NULL;
    }
    msg = sized_buffer(msgobj, "message");
    if msg is None {
        key.close();
        return NULL;
    }
    core = new_hmac(name, int(key.address()), key.size());
    key.close();
    if core is None {
        msg.close();
        PyErr_NoMemory();
        return NULL;
    }
    core.absorb(int(msg.address()), msg.size());
    msg.close();
    value = core.finish();
    return jacpy_bytes_from_payload(value, i64(len(value)));
}

impl _hmac_compute_digest_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject], digest: ptr[PyObject]
) -> ptr[PyObject] {
    name = find_hash_name(module, digest);
    if not name {
        return NULL;
    }
    return oneshot(name, key, msg);
}

impl _hmac_compute_md5_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("md5", key, msg);
}

impl _hmac_compute_sha1_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha1", key, msg);
}

impl _hmac_compute_sha2_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha224", key, msg);
}

impl _hmac_compute_sha2_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha256", key, msg);
}

impl _hmac_compute_sha2_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha384", key, msg);
}

impl _hmac_compute_sha2_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha512", key, msg);
}

impl _hmac_compute_sha3_224_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha3_224", key, msg);
}

impl _hmac_compute_sha3_256_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha3_256", key, msg);
}

impl _hmac_compute_sha3_384_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha3_384", key, msg);
}

impl _hmac_compute_sha3_512_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("sha3_512", key, msg);
}

impl _hmac_compute_blake2s_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("blake2s", key, msg);
}

impl _hmac_compute_blake2b_32_impl(
    module: ptr[PyObject], key: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    return oneshot("blake2b", key, msg);
}
