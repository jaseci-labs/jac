"""Native binary layout compilation and packing.

The format plan owns typed Jac fields; Python values and exported buffers stay
at the shared object boundary. Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_complex_value,
    jacpy_dict_get,
    jacpy_dict_size,
    jacpy_error_pending,
    jacpy_float_pack,
    jacpy_float_unpack,
    jacpy_is_bytearray,
    jacpy_is_bytes,
    jacpy_is_long,
    jacpy_long_address,
    jacpy_memory_copy,
    jacpy_memory_zero,
    jacpy_native_float_store,
    jacpy_native_little_endian,
    jacpy_native_size,
    jacpy_release,
    jacpy_set_exception,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    NULL,
    Py_NewRef,
    PyDict_Clear,
    PyDict_SetItem,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyExc_OverflowError,
    PyFloat_AsDouble,
    PyFloat_FromDouble,
    PyIndex_Check,
    PyLong_AsLongLong,
    PyLong_AsUnsignedLongLong,
    PyNumber_Index,
    PyObject,
    PyObject_CallOneArg,
    PyObject_IsTrue,
    PyTuple_New,
    PyExc_RuntimeError,
    PyExc_TypeError,
    PyUnicode_AsEncodedString,
    Py_None,
    Py_TYPE,
    jacpy_is_unicode
}
import from jaclang.runtime.python.object_model.complex {
    PyComplex_FromDoubles,
    PyComplex_ImagAsDouble,
    PyComplex_RealAsDouble
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.modules.binary_scalars {
    read_bits,
    write_bits,
    integer_from_bits
}
import from jaclang.runtime.python.capi {
    type_name,
    boundary_failure,
    required,
    checked,
    object_error,
    jac_heap_size,
    jac_list_heap_size,
    memory_byte,
    memory_set
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.references { ReferenceState }
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_owner
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    visit_reference
}

obj format_field {
    has code: int,
        offset: int,
        size: int,
        count: int;
}

obj struct_plan {
    has fields: list[format_field] = [],
        size: int = 0,
        items: int = 0,
        native: bool = True,
        little: bool = True;
}

def:priv struct_error(error: ptr[PyObject], message: str) {
    jacpy_set_exception(error, message, i64(len(message.encode("utf-8"))));
    raise boundary_failure();
}

def:priv pending {
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
}

# Kinds refer to platform ABI facts, not a second format-code table in C.
def:priv native_kind(code: int) -> int {
    if code == 104 or code == 72 or code == 101 {
        return 1;
    }
    if code == 105 or code == 73 {
        return 2;
    }
    if code == 108 or code == 76 {
        return 3;
    }
    if code == 113 or code == 81 {
        return 4;
    }
    if code == 110 or code == 78 {
        return 5;
    }
    if code == 80 {
        return 6;
    }
    if code == 63 {
        return 7;
    }
    if code == 102 or code == 70 {
        return 8;
    }
    if code == 100 or code == 68 {
        return 9;
    }
    return 0;
}

def:priv standard_size(code: int) -> int {
    if code == 104 or code == 72 or code == 101 {
        return 2;
    }
    if code == 105 or code == 73 or code == 108 or code == 76 or code == 102 {
        return 4;
    }
    if code == 113 or code == 81 or code == 100 or code == 70 {
        return 8;
    }
    if code == 68 {
        return 16;
    }
    return 1;
}

def:pub jacpy_struct_new -> struct_plan {
    return struct_plan(little=jacpy_native_little_endian() != 0);
}

def:pub jacpy_struct_compile(
    plan: struct_plan, format: ptr[PyObject], error: ptr[PyObject]
) -> i64 {
    try {
        data = jacpy_bytes_address(format);
        length = int(jacpy_bytes_length(format));
        for j in range(length) {
            if memory_byte(data, i64(j)) == 0 {
                struct_error(error, "embedded null character");
            }
        }
        index = 0;
        if length > 0 {
            prefix = int(memory_byte(data, 0));
            if prefix == 64
                or prefix == 61
                or prefix == 60
                or prefix == 62
                or prefix == 33 {
                index = 1;
                plan.native = prefix == 64;
                if prefix == 60 {
                    plan.little = True;
                } elif prefix == 62 or prefix == 33 {
                    plan.little = False;
                }
            }
        }
        limit = 9223372036854775807;
        while index < length {
            code = int(memory_byte(data, i64(index)));
            index += 1;
            if code == 32 or (code >= 9 and code <= 13) {
                continue;
            }
            count = 1;
            if code >= 48 and code <= 57 {
                count = 0;
                while code >= 48 and code <= 57 {
                    digit = code - 48;
                    if count > (limit - digit) // 10 {
                        struct_error(error, "total struct size too long");
                    }
                    count = count * 10 + digit;
                    if index == length {
                        struct_error(
                            error, "repeat count given without format specifier"
                        );
                    }
                    code = int(memory_byte(data, i64(index)));
                    index += 1;
                }
            }
            if chr(code) not in "xcbBsp?hHiIlLqQefdFDnNP"
                or (not plan.native and (code == 110 or code == 78 or code == 80)) {
                struct_error(error, "bad char in struct format");
            }
            size = standard_size(code);
            alignment = 1;
            if plan.native {
                kind = native_kind(code);
                size = int(jacpy_native_size(i64(kind), 0));
                alignment = int(jacpy_native_size(i64(kind), 1));
                if code == 70 or code == 68 {
                    size *= 2;
                }
            }
            padding = (alignment - plan.size % alignment) % alignment;
            if plan.size > limit - padding {
                struct_error(error, "total struct size too long");
            }
            plan.size += padding;
            if count > (limit - plan.size) // size {
                struct_error(error, "total struct size too long");
            }
            if code == 115 or code == 112 {
                plan.fields.append(
                    format_field(code=code, offset=plan.size, size=count, count=1)
                );
                plan.items += 1;
            } elif code != 120 and count != 0 {
                plan.fields.append(
                    format_field(code=code, offset=plan.size, size=size, count=count)
                );
                plan.items += count;
            }
            plan.size += count * size;
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_struct_size(plan: struct_plan) -> i64 {
    return i64(plan.size);
}

def:pub jacpy_struct_items(plan: struct_plan) -> i64 {
    return i64(plan.items);
}

def:priv integer_bits(
    value: ptr[PyObject], code: int, size: int, error: ptr[PyObject]
) -> u64 {
    if PyIndex_Check(value) == 0 and jacpy_is_long(value) == 0 {
        struct_error(error, "required argument is not an integer");
    }
    number = required(PyNumber_Index(value));
    try {
        if code == 80 {
            result = jacpy_long_address(number);
            if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
                struct_error(error, "int too large to convert");
            }
            pending();
            return result;
        }
        signed = chr(code) in "bhilqn";
        result: u64 = 0;
        minimum: i64 = 0;
        maximum: u64 = u64(18446744073709551615);
        invalid = False;
        if signed {
            bits = i64(size * 8 - 1);
            if size == 8 {
                minimum = i64(-9223372036854775807) - i64(1);
            } else {
                minimum = -(i64(1) << bits);
            }
            maximum = (u64(1) << bits) - u64(1);
            actual = PyLong_AsLongLong(number);
            result = ~u64(-(actual + i64(1))) if actual < 0 else u64(actual);
            invalid = actual < minimum or (actual >= 0 and u64(actual) > maximum);
        } else {
            if size < 8 {
                maximum = (u64(1) << i64(size * 8)) - u64(1);
            }
            result = PyLong_AsUnsignedLongLong(number);
            invalid = result > maximum;
        }
        if jacpy_error_pending() != 0 {
            if PyErr_ExceptionMatches(PyExc_OverflowError) == 0 {
                raise boundary_failure();
            }
            invalid = True;
        }
        if invalid {
            struct_error(
                error,
                "'"
                    + chr(code)
                    + "' format requires "
                    + str(minimum)
                    + " <= number <= "
                    + str(maximum)
            );
        }
        return result;
    } finally {
        jacpy_release(number);
    }
}

def:priv pack_field(
    plan: struct_plan,
    field: format_field,
    address: ptr,
    value: ptr[PyObject],
    error: ptr[PyObject]
) {
    code = field.code;
    size = field.size;
    if code == 115 or code == 112 {
        if jacpy_is_bytes(value) == 0 and jacpy_is_bytearray(value) == 0 {
            struct_error(
                error, "argument for '" + chr(code) + "' must be a bytes object"
            );
        }
        length = int(jacpy_bytes_length(value));
        if code == 112 {
            if size == 0 {
                return;
            }
            length = min(length, size - 1);
            memory_set(address, 0, i64(min(length, 255)));
            address += 1;
        } else {
            length = min(length, size);
        }
        jacpy_memory_copy(address, jacpy_bytes_address(value), i64(length));
        return;
    }
    if code == 99 {
        if jacpy_is_bytes(value) == 0 or jacpy_bytes_length(value) != 1 {
            struct_error(error, "char format requires a bytes object of length 1");
        }
        jacpy_memory_copy(address, jacpy_bytes_address(value), 1);
        return;
    }
    if code == 63 {
        truth = PyObject_IsTrue(value);
        checked(truth);
        memory_set(address, 0, truth);
        return;
    }
    if code == 101 or code == 102 or code == 100 {
        number = PyFloat_AsDouble(value);
        if jacpy_error_pending() != 0 {
            struct_error(error, "required argument is not a float");
        }
        checked(jacpy_float_pack(number, address, i64(size), i64(plan.little)));
        return;
    }
    if code == 70 or code == 68 {
        complex_handle = jacpy_complex_value(value);
        if complex_handle == 0 {
            struct_error(error, "required argument is not a complex");
        }
        try {
            component_size = size // 2;
            real = PyComplex_RealAsDouble(complex_handle);
            imaginary = PyComplex_ImagAsDouble(complex_handle);
            if plan.native {
                jacpy_native_float_store(real, address, i64(component_size));
                jacpy_native_float_store(
                    imaginary, address + component_size, i64(component_size)
                );
            } else {
                checked(
                    jacpy_float_pack(
                        real, address, i64(component_size), i64(plan.little)
                    )
                );
                checked(
                    jacpy_float_pack(
                        imaginary,
                        address + component_size,
                        i64(component_size),
                        i64(plan.little)
                    )
                );
            }
        } finally {
            jacpy_release(complex_handle);
        }
        return;
    }
    bits = integer_bits(value, code, size, error);
    write_bits(address, size, plan.little, bits);
}

def:pub jacpy_struct_pack(
    plan: struct_plan,
    args: ptr[PyObject],
    start: i64,
    address: ptr,
    error: ptr[PyObject]
) -> i64 {
    try {
        jacpy_memory_zero(address, i64(plan.size));
        index = start;
        for field in plan.fields {
            for repetition in range(field.count) {
                value = required(jacpy_tuple_item(args, index));
                try {
                    pack_field(
                        plan,
                        field,
                        address + (field.offset + repetition * field.size),
                        value,
                        error
                    );
                } finally {
                    jacpy_release(value);
                }
                index += 1;
            }
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:priv unpack_field(
    plan: struct_plan, field: format_field, address: ptr
) -> ptr[PyObject] {
    code = field.code;
    size = field.size;
    if code == 115 or code == 99 {
        return required(jacpy_bytes_from_memory(address, i64(size)));
    }
    if code == 112 {
        length = 0;
        if size != 0 {
            length = min(int(memory_byte(address, 0)), size - 1);
        }
        return required(
            jacpy_bytes_from_memory(address + (1 if size != 0 else 0), i64(length))
        );
    }
    if code == 63 {
        return required(PyBool_FromLong(i64(memory_byte(address, 0) != 0)));
    }
    if code == 101 or code == 102 or code == 100 {
        number = jacpy_float_unpack(address, i64(size), i64(plan.little));
        pending();
        return required(PyFloat_FromDouble(number));
    }
    if code == 70 or code == 68 {
        component_size = size // 2;
        real = jacpy_float_unpack(address, i64(component_size), i64(plan.little));
        pending();
        imaginary = jacpy_float_unpack(
            address + component_size, i64(component_size), i64(plan.little)
        );
        pending();
        return required(PyComplex_FromDoubles(real, imaginary));
    }
    return integer_from_bits(
        read_bits(address, size, plan.little), size, chr(code) in "bhilqn"
    );
}

def:pub jacpy_struct_unpack(plan: struct_plan, address: ptr) -> ptr[PyObject] {
    result: ptr[PyObject] = NULL;
    try {
        result = required(PyTuple_New(i64(plan.items)));
        index: i64 = 0;
        for field in plan.fields {
            for repetition in range(field.count) {
                value = unpack_field(
                    plan, field, address + (field.offset + repetition * field.size)
                );
                checked(jacpy_tuple_set_owned(result, index, value));
                index += 1;
            }
        }
        return result;
    } except boundary_failure {
        jacpy_release(result);
        return NULL;
    }
}

# Offset arithmetic stays native and is shared by pack_into and unpack_from.
def:pub jacpy_struct_offset(
    plan: struct_plan, length: i64, offset: i64, packing: i64, error: ptr[PyObject]
) -> i64 {
    try {
        size = i64(plan.size);
        if offset < 0 {
            if offset > -size {
                struct_error(
                    error,
                    (
                        "no space to pack "
                            if packing != 0
                            else "not enough data to unpack "
                    )
                        + str(size)
                        + " bytes at offset "
                        + str(offset)
                );
            }
            if offset < -length {
                struct_error(
                    error,
                    "offset "
                        + str(offset)
                        + " out of range for "
                        + str(length)
                        + "-byte buffer"
                );
            }
            offset += length;
        }
        if size > length or offset > length - size {
            struct_error(
                error,
                ("pack_into" if packing != 0 else "unpack_from")
                    + " requires a buffer of at least "
                    + str(u64(offset) + u64(size))
                    + " bytes for "
                    + ("packing" if packing != 0 else "unpacking")
                    + " "
                    + str(size)
                    + " bytes at offset "
                    + str(offset)
                    + " (actual buffer size is "
                    + str(length)
                    + ")"
            );
        }
        return offset;
    } except boundary_failure {
        return -1;
    }
}

obj unpack_cursor {
    has plan: struct_plan,
        address: ptr,
        length: int,
        index: int = 0;
}

def:pub jacpy_struct_cursor(
    plan: struct_plan, address: ptr, length: i64
) -> unpack_cursor {
    return unpack_cursor(plan=plan, address=address, length=int(length));
}

def:pub jacpy_struct_remaining(cursor: unpack_cursor) -> i64 {
    return i64((cursor.length - cursor.index) // cursor.plan.size);
}

def:pub jacpy_struct_next(cursor: unpack_cursor) -> ptr[PyObject] {
    if cursor.index == cursor.length {
        return NULL;
    }
    result = jacpy_struct_unpack(cursor.plan, cursor.address + cursor.index);
    cursor.index += cursor.plan.size;
    return result;
}

def:pub jacpy_struct_cached(
    cache: ptr[PyObject], type: ptr[PyObject], format: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        result = jacpy_dict_get(cache, format);
        pending();
        if result != 0 {
            return result;
        }
        result = required(PyObject_CallOneArg(type, format));
        if jacpy_dict_size(cache) >= 100 {
            PyDict_Clear(cache);
        }
        if PyDict_SetItem(cache, format, result) < 0 {
            PyErr_Clear();
        }
        return result;
    } except boundary_failure {
        return NULL;
    }
}

def:pub jacpy_struct_memory(plan: struct_plan) -> i64 {
    total = jac_heap_size(u64(id(plan))) + jac_list_heap_size(u64(id(plan.fields)));
    for field in plan.fields {
        total += jac_heap_size(u64(id(field)));
    }
    return total;
}

# The definitions the binding creates; the methods find the receiver's state
# and module by them.
glob Struct_token = ClassToken(),
     unpack_iterator_token = ClassToken(),
     struct_module_token = ClassToken();

obj StructState(ReferenceState) {
    has plan: struct_plan;
}

obj UnpackState(NativeState) {
    has cursor: (unpack_cursor | None) = None,
        buffer: (BufferArgument | None) = None,
        owner: ptr[PyObject] = NULL;

    def clear {
        previous_owner = self.owner;
        previous_buffer = self.buffer;
        self.cursor = None;
        self.buffer = None;
        self.owner = NULL;
        if previous_buffer is not None {
            previous_buffer.close();
        }
        jacpy_release(previous_owner);
    }

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        status = visit_reference(self.owner, visitor, context);
        if status != 0 {
            return status;
        }
        buffer = self.buffer;
        if buffer is not None {
            return visit_reference(buffer.owner(), visitor, context);
        }
        return i32(0);
    }

    def drop {
        self.clear();
    }
}

def state_for(instance: ptr[PyObject]) -> (StructState | None) {
    if jacpy_binding_native_present(instance, Struct_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Struct_token.handle);
        if isinstance(state, StructState) and state.references[0] != 0 {
            return state;
        }
    }
    object_error(PyExc_RuntimeError, "Struct object is not initialized");
    return None;
}

def module_for(instance: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(Py_TYPE(instance), struct_module_token.handle);
}

def module_error(module: ptr[PyObject], message: str) {
    jacpy_set_exception(
        jacpy_binding_state_get(module, 0), message, i64(len(message.encode("utf-8")))
    );
}

def iterator_state(instance: ptr[PyObject]) -> (UnpackState | None) {
    if jacpy_binding_native_present(instance, unpack_iterator_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, unpack_iterator_token.handle);
        if isinstance(state, UnpackState) {
            return state;
        }
    }
    return None;
}

# The Argument Clinic _impl functions.
def Struct___init___impl(instance: ptr[PyObject], format_: ptr[PyObject]) -> i32 {
    source = format_;
    format: ptr[PyObject] = NULL;
    if jacpy_is_unicode(source) != 0 {
        format = PyUnicode_AsEncodedString(source, "ascii", "strict");
    } elif jacpy_is_bytes(source) != 0 {
        format = Py_NewRef(source);
    } else {
        object_error(
            PyExc_TypeError,
            f"Struct() argument 1 must be a str or bytes object, not {type_name(source)[:200]}"
        );
        return i32(-1);
    }
    if format == 0 {
        return i32(-1);
    }
    state = StructState(references=[format], plan=struct_plan());
    module = module_for(instance);
    if module == 0 {
        return i32(-1);
    }
    if jacpy_struct_compile(state.plan, format, jacpy_binding_state_get(module, 0))
        < 0 {
        return i32(-1);
    }
    if jacpy_binding_native_set(instance, Struct_token.handle, state) < 0 {
        return i32(-1);
    }
    return i32(0);
}

def Struct_unpack_impl(
    instance: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    plan = state.plan;
    module = module_for(instance);
    if module == 0 {
        return NULL;
    }
    size = jacpy_struct_size(plan);
    if buffer.size() != size {
        module_error(module, f"unpack requires a buffer of {size} bytes");
        return NULL;
    }
    return jacpy_struct_unpack(plan, buffer.address());
}

def Struct_unpack_from_impl(
    instance: ptr[PyObject], buffer: BufferArgument, offset: i64
) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    plan = state.plan;
    module = module_for(instance);
    if module == 0 {
        return NULL;
    }
    start = jacpy_struct_offset(
        plan, buffer.size(), offset, 0, jacpy_binding_state_get(module, 0)
    );
    if start < 0 {
        return NULL;
    }
    return jacpy_struct_unpack(plan, buffer.address() + start);
}

def Struct_iter_unpack_impl(
    instance: ptr[PyObject], buffer: ptr[PyObject]
) -> ptr[PyObject] {
    state = state_for(instance);
    if state is None {
        return NULL;
    }
    plan = state.plan;
    module = module_for(instance);
    if module == 0 {
        return NULL;
    }
    size = jacpy_struct_size(plan);
    if size == 0 {
        module_error(module, "cannot iteratively unpack with a struct of length 0");
        return NULL;
    }
    iterator = jacpy_binding_allocate(jacpy_binding_state_get(module, 2));
    if iterator == 0 {
        return NULL;
    }
    view = BufferArgument();
    iterator_data = UnpackState(buffer=view);
    if jacpy_binding_native_set(iterator, unpack_iterator_token.handle, iterator_data)
        < 0 {
        jacpy_release(iterator);
        return NULL;
    }
    if not view.acquire(buffer) {
        jacpy_release(iterator);
        return NULL;
    }
    if view.size() % size != 0 {
        module_error(
            module,
            f"iterative unpacking requires a buffer of a multiple of {size} bytes"
        );
        jacpy_release(iterator);
        return NULL;
    }
    iterator_data.owner = Py_NewRef(instance);
    iterator_data.cursor = jacpy_struct_cursor(plan, view.address(), view.size());
    return iterator;
}

# cache_struct_converter: the cached Struct for `format`, a new reference
# the glue releases.
def convert_cache_struct_converter(
    module: ptr[PyObject], value: ptr[PyObject], fname: str, label: str
) -> ptr[PyObject] {
    result = jacpy_struct_cached(
        jacpy_binding_state_get(module, 3), jacpy_binding_state_get(module, 1), value
    );
    if result == 0 {
        raise boundary_failure();
    }
    return result;
}

def _clearcache_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    PyDict_Clear(jacpy_binding_state_get(module, 3));
    return Py_NewRef(Py_None);
}

# calcsize returns clinic's Py_ssize_t.
def calcsize_impl(module: ptr[PyObject], s_object: ptr[PyObject]) -> i64 {
    state = state_for(s_object);
    if state is None {
        return -1;
    }
    return jacpy_struct_size(state.plan);
}

def unpack_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return Struct_unpack_impl(s_object, buffer);
}

def unpack_from_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: BufferArgument, offset: i64
) -> ptr[PyObject] {
    return Struct_unpack_from_impl(s_object, buffer, offset);
}

def iter_unpack_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: ptr[PyObject]
) -> ptr[PyObject] {
    return Struct_iter_unpack_impl(s_object, buffer);
}
