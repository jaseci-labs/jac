"""MD5 hash objects; derived from CPython 3.14.6 Modules/md5module.c.

See ../LICENSE.cpython. The digest is the pure-Jac MD5 core of
na_stdlib/_digest.jac.
"""

glob MD5Type_token = ClassToken();

glob MD5_BLOCKSIZE: i64 = 64,
     MD5_DIGESTSIZE: i64 = 16;

def MD5Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    return digest_copy(receiver, MD5Type_token);
}

def MD5Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, MD5Type_token, False);
}

def MD5Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, MD5Type_token, True);
}

def MD5Type_update_impl(receiver: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    return digest_update(receiver, MD5Type_token, obj_);
}

def _md5_md5_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_new(
        jacpy_binding_state_get(module, 0),
        MD5Type_token,
        new_core("md5"),
        data,
        string_obj
    );
}
