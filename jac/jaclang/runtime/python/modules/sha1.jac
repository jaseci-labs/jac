"""SHA1 hash objects; derived from CPython 3.14.6 Modules/sha1module.c.

See ../LICENSE.cpython. The digest is the pure-Jac SHA-1 core of
na_stdlib/_digest.jac.
"""

glob SHA1Type_token = ClassToken();

glob SHA1_BLOCKSIZE: i64 = 64,
     SHA1_DIGESTSIZE: i64 = 20;

def SHA1Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    return digest_copy(receiver, SHA1Type_token);
}

def SHA1Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA1Type_token, False);
}

def SHA1Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA1Type_token, True);
}

def SHA1Type_update_impl(
    receiver: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_update(receiver, SHA1Type_token, obj_);
}

def _sha1_sha1_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_new(
        jacpy_binding_state_get(module, 0),
        SHA1Type_token,
        new_core("sha1"),
        data,
        string_obj
    );
}
