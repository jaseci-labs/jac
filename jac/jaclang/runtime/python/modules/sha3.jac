"""SHA-3 and SHAKE hash objects; derived from CPython 3.14.6
Modules/sha3module.c. See ../LICENSE.cpython. The digests are the pure-Jac
Keccak cores of na_stdlib/_digest.jac.
"""

glob SHA3_token = ClassToken(),
     SHA3_NAMES: list[str] = [
         "sha3_224",
         "sha3_256",
         "sha3_384",
         "sha3_512",
         "shake_128",
         "shake_256"
     ];

def:priv type_index(cls: ptr[PyObject]) -> int;

def:priv rate_of(instance: ptr[PyObject]) -> i64;

def py_sha3_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject];

def _sha3_sha3_224_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _sha3_sha3_224_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _sha3_sha3_224_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _sha3_sha3_224_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject];

def:priv shake_digest(
    receiver: ptr[PyObject], length: u64, as_hex: bool
) -> ptr[PyObject];

def _sha3_shake_128_digest_impl(receiver: ptr[PyObject], length: u64) -> ptr[PyObject];

def _sha3_shake_128_hexdigest_impl(
    receiver: ptr[PyObject], length: u64
) -> ptr[PyObject];

def get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_shake_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_capacity_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_rate_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def get_shake_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

impl type_index(cls: ptr[PyObject]) -> int {
    module = PyType_GetModule(cls);
    if not module {
        return -1;
    }
    for index in range(len(SHA3_NAMES)) {
        if jacpy_binding_state_get(module, i64(index)) == cls {
            return index;
        }
    }
    return -1;
}

impl rate_of(instance: ptr[PyObject]) -> i64 {
    state = digest_state(instance, SHA3_token);
    if state is None {
        return -1;
    }
    return i64(state.core.block_size) * 8;
}

impl py_sha3_new_impl(
    type: ptr[PyObject],
    data_obj: ptr[PyObject],
    usedforsecurity: bool,
    string: ptr[PyObject]
) -> ptr[PyObject] {
    index = type_index(type);
    return digest_new(
        type,
        SHA3_token,
        new_core(SHA3_NAMES[index]) if index >= 0 else None,
        data_obj,
        string
    );
}

impl _sha3_sha3_224_copy_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_copy(receiver, SHA3_token);
}

impl _sha3_sha3_224_digest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA3_token, False);
}

impl _sha3_sha3_224_hexdigest_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return digest_value(receiver, SHA3_token, True);
}

impl _sha3_sha3_224_update_impl(
    receiver: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    return digest_update(receiver, SHA3_token, data);
}

impl shake_digest(receiver: ptr[PyObject], length: u64, as_hex: bool) -> ptr[PyObject] {
    if length >= u64(1 << 29) {
        object_error(PyExc_ValueError, "length is too large");
        return NULL;
    }
    return digest_value(receiver, SHA3_token, as_hex, i64(length));
}

impl _sha3_shake_128_digest_impl(
    receiver: ptr[PyObject], length: u64
) -> ptr[PyObject] {
    return shake_digest(receiver, length, False);
}

impl _sha3_shake_128_hexdigest_impl(
    receiver: ptr[PyObject], length: u64
) -> ptr[PyObject] {
    return shake_digest(receiver, length, True);
}

impl get_block_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_property(instance, SHA3_token, 2);
}

impl get_name(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_property(instance, SHA3_token, 0);
}

impl get_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return digest_property(instance, SHA3_token, 1);
}

impl get_shake_digest_size(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyLong_FromLong(0);
}

impl get_capacity_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    rate = rate_of(instance);
    return PyLong_FromLong(1600 - rate) if rate >= 0 else NULL;
}

impl get_rate_bits(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    rate = rate_of(instance);
    return PyLong_FromLong(rate) if rate >= 0 else NULL;
}

impl get_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(ptr[u8]("\x06"), 1);
}

impl get_shake_suffix(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(ptr[u8]("\x1f"), 1);
}
