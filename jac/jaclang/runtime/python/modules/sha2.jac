"""SHA-2 hash objects; derived from CPython 3.14.6 Modules/sha2module.c.

See ../LICENSE.cpython. The digests are the pure-Jac SHA-2 cores of
na_stdlib/_digest.jac. SHA-224 and SHA-256 share SHA256Type's methods;
SHA-384 and SHA-512 share SHA512Type's.
"""

glob SHA256Type_token = ClassToken(),
     SHA512Type_token = ClassToken();

glob SHA256_BLOCKSIZE: i64 = 64,
     SHA512_BLOCKSIZE: i64 = 128,
     SHA224_TYPE: int = 0,
     SHA256_TYPE: int = 1,
     SHA384_TYPE: int = 2,
     SHA512_TYPE: int = 3;

def SHA256Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    return digest_copy(receiver, SHA256Type_token);
}

def SHA512Type_copy_impl(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    return digest_copy(receiver, SHA512Type_token);
}

def SHA256Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA256Type_token, False);
}

def SHA512Type_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA512Type_token, False);
}

def SHA256Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA256Type_token, True);
}

def SHA512Type_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA512Type_token, True);
}

def SHA256Type_update_impl(
    receiver: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_update(receiver, SHA256Type_token, obj_);
}

def SHA512Type_update_impl(
    receiver: ptr[PyObject], obj_: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_update(receiver, SHA512Type_token, obj_);
}

"""The module-level constructors: a new object of the module's `slot` type,
fed the initial data when there is any."""
def:priv new_sha2(
    module: ptr[PyObject],
    slot: int,
    data: ptr[PyObject],
    string_obj: ptr[PyObject],
    name: str
) -> ptr[PyObject] {
    wide = slot == SHA384_TYPE or slot == SHA512_TYPE;
    return digest_new(
        jacpy_binding_state_get(module, i64(slot)),
        SHA512Type_token if wide else SHA256Type_token,
        new_core(name),
        data,
        string_obj
    );
}

def _sha2_sha256_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA256_TYPE, data, string_obj, "sha256");
}

def _sha2_sha224_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA224_TYPE, data, string_obj, "sha224");
}

def _sha2_sha512_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA512_TYPE, data, string_obj, "sha512");
}

def _sha2_sha384_impl(
    module: ptr[PyObject],
    data: ptr[PyObject],
    usedforsecurity: bool,
    string_obj: ptr[PyObject]
) -> ptr[PyObject] {
    return new_sha2(module, SHA384_TYPE, data, string_obj, "sha384");
}
