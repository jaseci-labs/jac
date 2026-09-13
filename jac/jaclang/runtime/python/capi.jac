"""Retained CPython object operations for native Jac module implementations.

Handles borrow their arguments. Object-producing operations return a new
reference (zero on error), released with jacpy_release or returned to Python.
All calls require the interpreter lock; exceptions remain in CPython's thread
state. No Python implementation of a replaced module is invoked here.
"""
enum builtin_kind {
    NONE = 0,
    BOOL = 1,
    INT = 2,
    FLOAT = 3,
    BYTES = 4,
    STR = 5,
    TUPLE = 6,
    LIST = 7,
    DICT = 8,
    SET = 9,
    FROZENSET = 10,
    BYTEARRAY = 11,
    TYPE = 12,
    FUNCTION = 13,
    PICKLE_BUFFER = 14,
    OTHER = 15
}

import from c {
    def jacpy_dict_memory(value: u64) -> i64;  def jacpy_dict_items(
        value: u64
    ) -> u64;  def jacpy_unicode_intern(value: u64) -> u64;  def jacpy_exception_context(
        error: u64, cause: u64
    );  def jacpy_not_implemented -> u64;  def jacpy_ellipsis -> u64;  def jacpy_is_iterator(
        value: u64
    ) -> i64;  def jacpy_mapping_optional_item(mapping: u64, key: u64) -> u64;  def jacpy_audit_pickle_find(
        module: u64, name: u64
    ) -> i64;  def jacpy_builtin_kind(value: u64) -> i64;  def jacpy_is_not_implemented(
        value: u64
    ) -> i64;  def jacpy_set_new(iterable: u64, frozen: i64) -> u64;  def jacpy_set_add(
        set: u64, value: u64
    ) -> i64;  def jacpy_memoryview(value: u64) -> u64;  def jacpy_is_type(
        value: u64
    ) -> i64;  def jacpy_float_from_text(value: u64) -> u64;  def jacpy_bytes_unescape(
        value: u64
    ) -> u64;  def jacpy_number_long(value: u64) -> u64;  def jacpy_long_signed_bytes(
        value: u64, size: i64
    ) -> u64;  def jacpy_long_from_signed_bytes(value: u64) -> u64;  def jacpy_bytes_decode(
        value: u64, encoding: str, errors: str
    ) -> u64;  def jacpy_unicode_encode(
        value: u64, encoding: str, errors: str
    ) -> u64;  def jacpy_optional_attr(value: u64, name: str) -> u64;  def jacpy_setattr(
        value: u64, name: u64, item: u64
    ) -> i64;  def jacpy_import_object(name: u64) -> u64;  def jacpy_type_new(
        type: u64, args: u64, kwargs: u64
    ) -> u64;  def jacpy_unicode_decode_bytes(value: u64, encoding: str) -> u64;  def jacpy_unicode_from_ordinal(
        point: i64
    ) -> u64;  def jacpy_memory_move(target: u64, source: u64, size: i64);  def jacpy_bytearray_new(
        size: i64
    ) -> u64;  def jacpy_bytearray_resize(value: u64, size: i64) -> i64;  def jacpy_bytearray_memory(
        value: u64
    ) -> i64;  def jacpy_float32_bits(value: f64) -> u64;  def jacpy_tuple_unique(
        value: u64
    ) -> i64;  def jacpy_tuple_exchange(value: u64, index: i64, item: u64) -> u64;  def jacpy_call_two(
        callable: u64, a: u64, b: u64
    ) -> u64;  def jacpy_object_type(value: u64) -> u64;  def jacpy_callable(
        value: u64
    ) -> i64;  def jacpy_is_exact_unicode(value: u64) -> i64;  def jacpy_is_exact_tuple(
        value: u64
    ) -> i64;  def jacpy_object_hash(value: u64) -> i64;  def jacpy_dict_copy(
        value: u64
    ) -> u64;  def jacpy_dict_update(target: u64, source: u64) -> i64;  def jacpy_ordered_dict_new -> u64;  def jacpy_long_fits_i64(
        value: u64
    ) -> i64;  def jacpy_sequence_tuple(value: u64) -> u64;  def jacpy_is_exact_float(
        value: u64
    ) -> i64;  def jacpy_long_double(value: u64) -> f64;  def jacpy_special_noargs(
        value: u64, name: str
    ) -> u64;  def jacpy_long_from_double(value: f64) -> u64;  def jacpy_libm_parts(
        value: f64, integral: i64
    ) -> u64;  def jacpy_float_bits(value: f64) -> u64;  def jacpy_float_from_bits(
        value: u64
    ) -> f64;  def jacpy_long_frexp(value: u64) -> u64;  def jacpy_long_sign(
        value: u64
    ) -> i64;  def jacpy_long_gcd(a: u64, b: u64) -> u64;  def jacpy_long_shift(
        value: u64, count: i64, left: i64
    ) -> u64;  def jacpy_sequence_list(value: u64) -> u64;  def jacpy_dict_repr(
        value: u64
    ) -> u64;  def jacpy_compare_bool(a: u64, b: u64, operation: i64) -> i64;  def jacpy_set_key_error(
        key: u64
    );  def jacpy_release(handle: u64);  def jacpy_retain(handle: u64) -> u64;  def jacpy_list_item(
        handle: u64, index: i64
    ) -> u64;  def jacpy_list_size(handle: u64) -> i64;  def jacpy_list_append(
        handle: u64, value: u64
    ) -> i64;  def jacpy_list_delete(handle: u64, start: i64, end: i64) -> i64;  def jacpy_list_exchange(
        handle: u64, index: i64, value: u64
    ) -> u64;  def jacpy_list_swap(handle: u64, left: i64, right: i64);  def jacpy_none -> u64;  def jacpy_int(
        value: i64
    ) -> u64;  def jacpy_raise_error(kind: str, message: str, size: i64);  def jacpy_object_size(
        handle: u64
    ) -> i64;  def jacpy_sequence_slot(handle: u64) -> u64;  def jacpy_slot_item(
        slot: u64, handle: u64, index: i64
    ) -> u64;  def jacpy_call_one(callable: u64, argument: u64) -> u64;  def jacpy_less(
        left: u64, right: u64
    ) -> i64;  def jacpy_comparison_slot(handle: u64) -> u64;  def jacpy_same_type(
        left: u64, right: u64
    ) -> i64;  def jacpy_slot_less(slot: u64, left: u64, right: u64) -> i64;  def jacpy_insert(
        handle: u64, index: i64, value: u64
    ) -> i64;  def jacpy_recursion_enter(context: str) -> i64;  def jacpy_recursion_leave;  def jacpy_is_long(
        handle: u64
    ) -> i64;  def jacpy_long_absolute(handle: u64) -> u64;  def jacpy_hash_unsigned(
        handle: u64
    ) -> u64;  def jacpy_long_bits(handle: u64) -> i64;  def jacpy_long_bytes(
        handle: u64, size: i64
    ) -> u64;  def jacpy_long_from_bytes(handle: u64) -> u64;  def jacpy_unsigned_long(
        handle: u64
    ) -> u64;  def jacpy_integer_value(handle: u64) -> i64;  def jacpy_entropy(
        size: i64
    ) -> u64;  def jacpy_clear_error;  def jacpy_error_pending -> i64;  def jacpy_wall_time -> i64;  def jacpy_monotonic_time -> i64;  def jacpy_process_id -> i64;  def jacpy_is_tuple(
        handle: u64
    ) -> i64;  def jacpy_tuple_size(handle: u64) -> i64;  def jacpy_tuple_new(
        size: i64
    ) -> u64;  def jacpy_tuple_item(handle: u64, index: i64) -> u64;  def jacpy_tuple_set_owned(
        handle: u64, index: i64, value: u64
    ) -> i64;  def jacpy_buffer_size(handle: u64) -> i64;  def jacpy_buffer_byte(
        handle: u64, index: i64
    ) -> i64;  def jacpy_buffer_new(size: i64) -> u64;  def jacpy_buffer_set(
        handle: u64, index: i64, value: i64
    );  def jacpy_set_exception(kind: u64, message: str, size: i64);  def jacpy_add(
        a: u64, b: u64
    ) -> u64;  def jacpy_sub(a: u64, b: u64) -> u64;  def jacpy_mul(
        a: u64, b: u64
    ) -> u64;  def jacpy_matmul(a: u64, b: u64) -> u64;  def jacpy_floordiv(
        a: u64, b: u64
    ) -> u64;  def jacpy_truediv(a: u64, b: u64) -> u64;  def jacpy_mod(
        a: u64, b: u64
    ) -> u64;  def jacpy_lshift(a: u64, b: u64) -> u64;  def jacpy_rshift(
        a: u64, b: u64
    ) -> u64;  def jacpy_and_(a: u64, b: u64) -> u64;  def jacpy_xor(
        a: u64, b: u64
    ) -> u64;  def jacpy_or_(a: u64, b: u64) -> u64;  def jacpy_iadd(
        a: u64, b: u64
    ) -> u64;  def jacpy_isub(a: u64, b: u64) -> u64;  def jacpy_imul(
        a: u64, b: u64
    ) -> u64;  def jacpy_imatmul(a: u64, b: u64) -> u64;  def jacpy_ifloordiv(
        a: u64, b: u64
    ) -> u64;  def jacpy_itruediv(a: u64, b: u64) -> u64;  def jacpy_imod(
        a: u64, b: u64
    ) -> u64;  def jacpy_ilshift(a: u64, b: u64) -> u64;  def jacpy_irshift(
        a: u64, b: u64
    ) -> u64;  def jacpy_iand(a: u64, b: u64) -> u64;  def jacpy_ixor(
        a: u64, b: u64
    ) -> u64;  def jacpy_ior(a: u64, b: u64) -> u64;  def jacpy_concat(
        a: u64, b: u64
    ) -> u64;  def jacpy_iconcat(a: u64, b: u64) -> u64;  def jacpy_getitem(
        a: u64, b: u64
    ) -> u64;  def jacpy_neg(a: u64) -> u64;  def jacpy_pos(a: u64) -> u64;  def jacpy_abs(
        a: u64
    ) -> u64;  def jacpy_invert(a: u64) -> u64;  def jacpy_index(a: u64) -> u64;  def jacpy_power(
        a: u64, b: u64, inplace: i64
    ) -> u64;  def jacpy_truth(a: u64) -> i64;  def jacpy_boolean(value: i64) -> u64;  def jacpy_is_none(
        a: u64
    ) -> i64;  def jacpy_compare(a: u64, b: u64, operation: i64) -> u64;  def jacpy_contains(
        a: u64, b: u64
    ) -> i64;  def jacpy_sequence_index(a: u64, b: u64) -> i64;  def jacpy_sequence_count(
        a: u64, b: u64
    ) -> i64;  def jacpy_length_hint(a: u64, fallback: i64) -> i64;  def jacpy_setitem(
        a: u64, b: u64, value: u64
    ) -> i64;  def jacpy_delitem(a: u64, b: u64) -> i64;  def jacpy_getattr(
        a: u64, name: u64
    ) -> u64;  def jacpy_call(callable: u64, args: u64, kwargs: u64) -> u64;  def jacpy_tuple_slice(
        a: u64, start: i64, end: i64
    ) -> u64;  def jacpy_is_unicode(a: u64) -> i64;  def jacpy_text(
        data: str, size: i64
    ) -> u64;  def jacpy_repr(a: u64) -> u64;  def jacpy_repr_enter(a: u64) -> i64;  def jacpy_repr_leave(
        a: u64
    );  def jacpy_unicode_split(a: u64, sep: u64) -> u64;  def jacpy_unicode_join(
        sep: u64, items: u64
    ) -> u64;  def jacpy_dict_size(a: u64) -> i64;  def jacpy_dict_entry(
        a: u64, position: i64
    ) -> u64;  def jacpy_import_attr(module: str, name: str) -> u64;  def jacpy_utf8(
        a: u64
    ) -> u64;  def jacpy_crypto_compare(a: u64, b: u64, size: i64) -> i64;  def jacpy_lock_new -> u64;  def jacpy_lock_free(
        handle: u64
    );  def jacpy_lock_notify(handle: u64);  def jacpy_lock_wait(
        handle: u64, timeout_ns: i64
    ) -> i64;  def jacpy_pending_calls -> i64;  def jacpy_timeout_ns(
        value: u64
    ) -> i64;  def jacpy_deadline(timeout: i64) -> i64;  def jacpy_deadline_remaining(
        deadline: i64
    ) -> i64;  def jacpy_set_none_exception(kind: u64);  def jacpy_writer_new -> u64;  def jacpy_writer_discard(
        writer: u64
    );  def jacpy_writer_finish(writer: u64) -> u64;  def jacpy_writer_char(
        writer: u64, value: i64
    ) -> i64;  def jacpy_writer_text(writer: u64, text: u64) -> i64;  def jacpy_writer_slice(
        writer: u64, text: u64, start: i64, end: i64
    ) -> i64;  def jacpy_writer_ascii(writer: u64, text: str, size: i64) -> i64;  def jacpy_unicode_size(
        text: u64
    ) -> i64;  def jacpy_unicode_char(text: u64, index: i64) -> i64;  def jacpy_unicode_slice(
        text: u64, start: i64, end: i64
    ) -> u64;  def jacpy_dict_default(dictionary: u64, key: u64, value: u64) -> u64;  def jacpy_dict_set(
        dictionary: u64, key: u64, value: u64
    ) -> i64;  def jacpy_raise_value(kind: str, value: u64);  def jacpy_set_object_exception(
        kind: u64, value: u64
    );  def jacpy_list_new -> u64;  def jacpy_dict_new -> u64;  def jacpy_is_bool(
        value: u64
    ) -> i64;  def jacpy_is_float(value: u64) -> i64;  def jacpy_is_list(
        value: u64
    ) -> i64;  def jacpy_is_dict(value: u64) -> i64;  def jacpy_is_exact_dict(
        value: u64
    ) -> i64;  def jacpy_long_repr(value: u64) -> u64;  def jacpy_float_repr(
        value: u64
    ) -> u64;  def jacpy_float_value(value: u64) -> f64;  def jacpy_identity(
        value: u64
    ) -> u64;  def jacpy_type_name(value: u64) -> u64;  def jacpy_qualified_type_name(
        value: u64
    ) -> u64;  def jacpy_error_take -> u64;  def jacpy_error_restore(value: u64);  def jacpy_exception_note(
        error: u64, note: u64
    ) -> i64;  def jacpy_sequence_fast(value: u64, message: str) -> u64;  def jacpy_fast_size(
        value: u64
    ) -> i64;  def jacpy_fast_item(value: u64, index: i64) -> u64;  def jacpy_mapping_items(
        value: u64
    ) -> u64;  def jacpy_list_sort(value: u64) -> i64;  def jacpy_dict_remove(
        dictionary: u64, key: u64
    ) -> i64;  def jacpy_unicode_concat(left: u64, right: u64) -> u64;  def jacpy_sequence_repeat(
        value: u64, count: i64
    ) -> u64;  def jacpy_is_exact_long(value: u64) -> i64;  def jacpy_type_check(
        value: u64, type: u64
    ) -> i64;  def jacpy_long_as_int32(value: u64) -> i64;  def jacpy_getattr_string(
        value: u64, name: str
    ) -> u64;  def jacpy_dict_get(dictionary: u64, key: u64) -> u64;  def jacpy_dict_keys(
        dictionary: u64
    ) -> u64;  def jacpy_dict_pop_discard(dictionary: u64, key: u64) -> i64;  def jacpy_iter(
        value: u64
    ) -> u64;  def jacpy_iter_next(value: u64) -> u64;  def jacpy_number_float(
        value: u64
    ) -> u64;  def jacpy_number_check(value: u64) -> i64;  def jacpy_object_str(
        value: u64
    ) -> u64;  def jacpy_error_is(name: str) -> i64;  def jacpy_number_as_double(
        value: u64
    ) -> f64;  def jac_heap_size(address: u64) -> i64;  def jac_list_heap_size(
        address: u64
    ) -> i64;  def jacpy_dict_clear(value: u64);  def jacpy_native_size(
        kind: i64, alignment: i64
    ) -> i64;  def jacpy_native_little_endian -> i64;  def jacpy_memory_byte(
        address: u64, offset: i64
    ) -> i64;  def jacpy_memory_set(address: u64, offset: i64, value: i64);  def jacpy_memory_zero(
        address: u64, size: i64
    );  def jacpy_memory_copy(target: u64, source: u64, size: i64);  def jacpy_bytes_from_memory(
        address: u64, size: i64
    ) -> u64;  def jacpy_is_bytes(value: u64) -> i64;  def jacpy_is_bytearray(
        value: u64
    ) -> i64;  def jacpy_bytes_address(value: u64) -> u64;  def jacpy_bytes_length(
        value: u64
    ) -> i64;  def jacpy_index_check(value: u64) -> i64;  def jacpy_long_pointer(
        value: u64
    ) -> u64;  def jacpy_uint(value: u64) -> u64;  def jacpy_long_u64(
        value: u64
    ) -> u64;  def jacpy_float(value: f64) -> u64;  def jacpy_complex_value(
        value: u64
    ) -> u64;  def jacpy_complex_real(value: u64) -> f64;  def jacpy_complex_imag(
        value: u64
    ) -> f64;  def jacpy_complex(real: f64, imaginary: f64) -> u64;  def jacpy_float_pack(
        value: f64, address: u64, size: i64, little: i64
    ) -> i64;  def jacpy_float_unpack(address: u64, size: i64, little: i64) -> f64;  def jacpy_native_float_store(
        value: f64, address: u64, size: i64
    );  def jacpy_clear_errno;  def jacpy_math_errno -> i64;
}

def object_error(kind: str, message: str) {
    jacpy_raise_error(kind, message, i64(len(message.encode("utf-8"))));
}


def read_buffer(handle: u64) -> list[int] {
    return [
        int(jacpy_buffer_byte(handle, i64(i)))
        for i in range(int(jacpy_buffer_size(handle)))
    ];
}

def write_buffer(data: list[int]) -> u64 {
    handle = jacpy_buffer_new(i64(len(data)));
    if handle != 0 {
        for i in range(len(data)) {
            jacpy_buffer_set(handle, i64(i), i64(data[i]));
        }
    }
    return handle;
}


obj module_failure(Exception) {
    has message: str;
}

obj boundary_failure(Exception) {}

def required(handle: u64) -> u64 {
    if handle == 0 {
        raise boundary_failure();
    }
    return handle;
}

def text_object(value: str) -> u64 {
    return required(
        jacpy_text(value, i64(len(value.encode("utf-8", "surrogatepass"))))
    );
}

def text_value(value: u64) -> str {
    buffer = required(jacpy_utf8(value));
    try {
        return bytes(read_buffer(buffer)).decode("utf-8", "surrogatepass");
    } finally {
        jacpy_release(buffer);
    }
}

def repr_value(value: u64) -> str {
    result = required(jacpy_repr(value));
    try {
        return text_value(result);
    } finally {
        jacpy_release(result);
    }
}

# Both inputs are borrowed; the returned tuple owns its references.
def pair(first: u64, second: u64) -> u64 {
    result = required(jacpy_tuple_new(2));
    jacpy_tuple_set_owned(result, 0, jacpy_retain(first));
    jacpy_tuple_set_owned(result, 1, jacpy_retain(second));
    return result;
}


def checked(status: i64) {
    if status < 0 {
        raise boundary_failure();
    }
}

# Entries are borrowed; each successful result owns all its element references.
def object_tuple(values: list[u64]) -> u64 {
    result = required(jacpy_tuple_new(i64(len(values))));
    for i in range(len(values)) {
        jacpy_tuple_set_owned(result, i64(i), jacpy_retain(values[i]));
    }
    return result;
}

def type_name(value: u64, qualified: bool = False) -> str {
    name = required(
        jacpy_qualified_type_name(value) if qualified else jacpy_type_name(value)
    );
    try {
        return text_value(name);
    } finally {
        jacpy_release(name);
    }
}

# Preserve the original exception if formatting a diagnostic invokes user code.
def serialization_note(value: u64, key: u64, index: int, kind: int, detail: str = "") {
    error = jacpy_error_take();
    if error == 0 {
        return;
    }
    try {
        tail = " " + detail if detail else " object";
        if kind == 1 {
            tail = " item " + str(index);
        } elif kind == 2 {
            tail = " item " + repr_value(key);
        }
        note = text_object("when serializing " + type_name(value, True) + tail);
        try {
            checked(jacpy_exception_note(error, note));
        } finally {
            jacpy_release(note);
        }
    } except boundary_failure {} finally {
        jacpy_error_restore(error);
    }
}

import from c {
    obj SliceBounds {
        has start: i64,
            stop: i64,
            step: i64,
            count: i64,
            valid: i64;
    }  def jacpy_is_slice(value: u64) -> i64;  def jacpy_slice_unpack(
        value: u64
    ) -> SliceBounds;  def jacpy_slice_adjust(
        length: i64, bounds: SliceBounds
    ) -> SliceBounds;  def jacpy_audit(event: str, arguments: u64) -> i64;  def jacpy_warn(
        category: str, message: str, stacklevel: i64
    ) -> i64;  def jacpy_builtins -> u64;  def jacpy_type_subtype(
        type: u64, base: u64
    ) -> i64;  def jacpy_number_ssize(value: u64, exception: str) -> i64;
}

import from c {
    def jacpy_builtin_type(kind: i64) -> u64;  def jacpy_generic_getattr(
        object: u64, name: u64
    ) -> u64;  def jacpy_generic_setattr(object: u64, name: u64, value: u64) -> i32;
}
