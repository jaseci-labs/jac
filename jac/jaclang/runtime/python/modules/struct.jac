import from c {
    obj struct_record {
        has table: ptr[i64],
            items: i64,
            size: i64,
            little: i64,
            direct: i64,
            dense: i64,
            module: ptr[PyObject];
    }
}

glob STRUCT_RECORD_SIZE: Final[int] = 56,
     FLOAT_VALUE_OFFSET: Final[i64] = 16;

obj format_field {
    has code: int,
        offset: int,
        size: int,
        count: int,
        signed: bool = False;
}

obj struct_plan {
    has fields: list[format_field] = [],
        size: int = 0,
        items: int = 0,
        native: bool = True,
        little: bool = True,
        table: ptr[i64] = ptr[i64](),
        table_object: ptr[PyObject] = NULL,
        dense: bool = False;
}

def:priv struct_error(error: ptr[PyObject], message: str);

def:priv pending;

def:priv native_kind(code: int) -> int;

def:priv standard_size(code: int) -> int;

def:pub jacpy_struct_new -> struct_plan;

def:pub jacpy_struct_compile(
    plan: struct_plan, format: ptr[PyObject], error: ptr[PyObject]
) -> i64;

def:pub jacpy_struct_size(plan: struct_plan) -> i64;

def:pub jacpy_struct_items(plan: struct_plan) -> i64;

def:priv integer_bits(
    value: ptr[PyObject], code: int, size: int, signed: bool, error: ptr[PyObject]
) -> u64;

def:priv long_bits(
    number: ptr[PyObject], code: int, size: int, signed: bool, error: ptr[PyObject]
) -> u64;

def:priv build_table(plan: struct_plan) -> bool;

def:priv zero_memory(address: ptr, size: int);

def:priv pack_field(
    plan: struct_plan,
    code: int,
    size: int,
    signed: bool,
    address: ptr,
    value: ptr[PyObject],
    error: ptr[PyObject]
);

def:pub jacpy_struct_pack(
    plan: struct_plan, items: ptr[ptr[PyObject]], address: ptr, error: ptr[PyObject]
) -> i64;

def:priv unpack_field(
    little: bool, code: int, size: int, signed: bool, address: ptr
) -> ptr[PyObject];

def:pub jacpy_struct_unpack(plan: struct_plan, address: ptr) -> ptr[PyObject];

def:priv integer_code(code: i64) -> bool;

def:priv load_bits(at: ptr[u8], size: i64, direct: bool, little: bool) -> u64;

def:priv store_bits(at: ptr[u8], size: i64, direct: bool, little: bool, bits: u64);

def:priv unpack_fast(
    code: i64, size: i64, signed: bool, little: bool, direct: bool, at: ptr[u8]
) -> ptr[PyObject];

def:priv unpack_table(
    table: ptr[i64], count: i64, little: bool, direct: bool, address: ptr[u8]
) -> ptr[PyObject];

def:priv pack_fast(
    code: i64,
    size: i64,
    signed: bool,
    little: bool,
    direct: bool,
    at: ptr[u8],
    value: ptr[PyObject]
) -> i32;

def:priv pack_slow(
    instance: ptr[PyObject], row: ptr[i64], address: ptr[u8], value: ptr[PyObject]
) -> i32;

def:pub struct_record_of(instance: ptr[PyObject]) -> ptr[struct_record];

def:pub jacpy_struct_pack_record(
    instance: ptr[PyObject],
    record: ptr[struct_record],
    items: ptr[ptr[PyObject]],
    address: ptr[u8]
) -> i32;

def:pub jacpy_struct_unpack_record(
    record: ptr[struct_record], address: ptr[u8]
) -> ptr[PyObject];

def:pub jacpy_struct_offset(
    plan: struct_plan, length: i64, offset: i64, packing: i64, error: ptr[PyObject]
) -> i64;

obj unpack_cursor {
    has plan: struct_plan,
        address: ptr,
        length: int,
        index: int = 0;
}

def:pub jacpy_struct_cursor(
    plan: struct_plan, address: ptr, length: i64
) -> unpack_cursor;

def:pub jacpy_struct_remaining(cursor: unpack_cursor) -> i64;

def:pub jacpy_struct_next(cursor: unpack_cursor) -> ptr[PyObject];

def:pub jacpy_struct_cached(
    cache: ptr[PyObject], type: ptr[PyObject], format: ptr[PyObject]
) -> ptr[PyObject];

def:pub jacpy_struct_memory(plan: struct_plan) -> i64;

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

    def clear;
    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def drop;
}

def state_for(instance: ptr[PyObject]) -> (StructState | None);

def module_for(instance: ptr[PyObject]) -> ptr[PyObject];

def module_error(module: ptr[PyObject], message: str);

def iterator_state(instance: ptr[PyObject]) -> (UnpackState | None);

def Struct___init___impl(instance: ptr[PyObject], format_: ptr[PyObject]) -> i32;

def Struct_unpack_impl(
    instance: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def Struct_unpack_from_impl(
    instance: ptr[PyObject], buffer: BufferArgument, offset: i64
) -> ptr[PyObject];

def Struct_iter_unpack_impl(
    instance: ptr[PyObject], buffer: ptr[PyObject]
) -> ptr[PyObject];

def convert_cache_struct_converter(
    module: ptr[PyObject], value: ptr[PyObject], fname: str, label: str
) -> ptr[PyObject];

def _clearcache_impl(module: ptr[PyObject]) -> ptr[PyObject];

def calcsize_impl(module: ptr[PyObject], s_object: ptr[PyObject]) -> i64;

def unpack_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def unpack_from_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: BufferArgument, offset: i64
) -> ptr[PyObject];

def iter_unpack_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: ptr[PyObject]
) -> ptr[PyObject];

impl struct_error(error: ptr[PyObject], message: str) {
    jacpy_set_exception(error, message, i64(len(message.encode("utf-8"))));
    raise boundary_failure();
}

impl pending {
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
}

impl native_kind(code: int) -> int {
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

impl standard_size(code: int) -> int {
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

impl jacpy_struct_new -> struct_plan {
    return struct_plan(little=jacpy_native_little_endian() != 0);
}

impl jacpy_struct_compile(
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
                    format_field(
                        code=code,
                        offset=plan.size,
                        size=size,
                        count=count,
                        signed=code == 98
                            or code == 104
                            or code == 105
                            or code == 108
                            or code == 113
                            or code == 110
                    )
                );
                plan.items += count;
            }
            plan.size += count * size;
        }
        return 0 if build_table(plan) else -1;
    } except boundary_failure {
        return -1;
    }
}

impl jacpy_struct_size(plan: struct_plan) -> i64 {
    return i64(plan.size);
}

impl jacpy_struct_items(plan: struct_plan) -> i64 {
    return i64(plan.items);
}

impl integer_bits(
    value: ptr[PyObject], code: int, size: int, signed: bool, error: ptr[PyObject]
) -> u64 {
    if jacpy_is_exact_long(value) != 0 {
        return long_bits(value, code, size, signed, error);
    }
    if PyIndex_Check(value) == 0 and jacpy_is_long(value) == 0 {
        struct_error(error, "required argument is not an integer");
    }
    number = required(PyNumber_Index(value));
    try {
        return long_bits(number, code, size, signed, error);
    } finally {
        jacpy_release(number);
    }
}

impl long_bits(
    number: ptr[PyObject], code: int, size: int, signed: bool, error: ptr[PyObject]
) -> u64 {
    if code == 80 {
        address = jacpy_long_address(number);
        if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
            struct_error(error, "int too large to convert");
        }
        pending();
        return address;
    }
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
        if actual == -1 and jacpy_error_pending() != 0 {
            if PyErr_ExceptionMatches(PyExc_OverflowError) == 0 {
                raise boundary_failure();
            }
            invalid = True;
        }
    } else {
        if size < 8 {
            maximum = (u64(1) << i64(size * 8)) - u64(1);
        }
        result = PyLong_AsUnsignedLongLong(number);
        invalid = result > maximum;
        if result == u64(18446744073709551615) and jacpy_error_pending() != 0 {
            if PyErr_ExceptionMatches(PyExc_OverflowError) == 0 {
                raise boundary_failure();
            }
            invalid = True;
        }
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
}

impl pack_field(
    plan: struct_plan,
    code: int,
    size: int,
    signed: bool,
    address: ptr,
    value: ptr[PyObject],
    error: ptr[PyObject]
) {
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
            size -= 1;
        } else {
            length = min(length, size);
        }
        jacpy_memory_copy(address, jacpy_bytes_address(value), i64(length));
        if length < size {
            zero_memory(address + length, size - length);
        }
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
    bits = integer_bits(value, code, size, signed, error);
    write_bits(address, size, plan.little, bits);
}

impl zero_memory(address: ptr, size: int) {
    data = ptr[u8](address);
    i = 0;
    while i < size {
        (data + i).view(1)[0] = u8(0);
        i += 1;
    }
}

impl jacpy_struct_pack(
    plan: struct_plan, items: ptr[ptr[PyObject]], address: ptr, error: ptr[PyObject]
) -> i64 {
    try {
        if not plan.dense {
            zero_memory(address, plan.size);
        }
        table = plan.table;
        for index in range(plan.items) {
            row = (table + index * 4).view(4);
            pack_field(
                plan,
                int(row[0]),
                int(row[2]),
                row[3] != 0,
                address + row[1],
                (items + index).view(1)[0],
                error
            );
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

impl unpack_field(
    little: bool, code: int, size: int, signed: bool, address: ptr
) -> ptr[PyObject] {
    if code == 115 or code == 99 {
        return jacpy_bytes_from_memory(address, i64(size));
    }
    if code == 112 {
        length = 0;
        if size != 0 {
            length = min(int(memory_byte(address, 0)), size - 1);
        }
        return jacpy_bytes_from_memory(address + (1 if size != 0 else 0), i64(length));
    }
    if code == 63 {
        return PyBool_FromLong(i64(memory_byte(address, 0) != 0));
    }
    if code == 101 or code == 102 or code == 100 {
        number = jacpy_float_unpack(address, i64(size), i64(little));
        if number == -1.0 and jacpy_error_pending() != 0 {
            return NULL;
        }
        return PyFloat_FromDouble(number);
    }
    if code == 70 or code == 68 {
        component_size = size // 2;
        real = jacpy_float_unpack(address, i64(component_size), i64(little));
        if real == -1.0 and jacpy_error_pending() != 0 {
            return NULL;
        }
        imaginary = jacpy_float_unpack(
            address + component_size, i64(component_size), i64(little)
        );
        if imaginary == -1.0 and jacpy_error_pending() != 0 {
            return NULL;
        }
        return PyComplex_FromDoubles(real, imaginary);
    }
    bits = read_bits(address, size, little);
    if not signed {
        return PyLong_FromUnsignedLongLong(bits);
    }
    if size < 8 and bits & (u64(1) << i64(size * 8 - 1)) != 0 {
        bits |= wrapping_shl(~u64(0), u64(size * 8));
    }
    return PyLong_FromLongLong(
        -i64(~bits) - i64(1) if bits > u64(9223372036854775807) else i64(bits)
    );
}

impl jacpy_struct_unpack(plan: struct_plan, address: ptr) -> ptr[PyObject] {
    return unpack_table(
        plan.table,
        i64(plan.items),
        plan.little,
        plan.little == (jacpy_native_little_endian() != 0),
        ptr[u8](address)
    );
}

impl integer_code(code: i64) -> bool {
    return code == 98
        or code == 66
        or code == 104
        or code == 72
        or code == 105
        or code == 73
        or code == 108
        or code == 76
        or code == 113
        or code == 81
        or code == 110
        or code == 78;
}

impl load_bits(at: ptr[u8], size: i64, direct: bool, little: bool) -> u64 {
    if direct {
        if size == 1 {
            return u64(at.view(1)[0]);
        }
        if size == 2 {
            return u64(ptr[u16](at).view(1)[0]);
        }
        if size == 4 {
            return u64(ptr[u32](at).view(1)[0]);
        }
        if size == 8 {
            return ptr[u64](at).view(1)[0];
        }
    }
    return read_bits(ptr(at), int(size), little);
}

impl store_bits(at: ptr[u8], size: i64, direct: bool, little: bool, bits: u64) {
    if direct {
        if size == 1 {
            at.view(1)[0] = u8(bits & u64(255));
            return;
        }
        if size == 2 {
            ptr[u16](at).view(1)[0] = u16(bits & u64(65535));
            return;
        }
        if size == 4 {
            ptr[u32](at).view(1)[0] = u32(bits & u64(4294967295));
            return;
        }
        if size == 8 {
            ptr[u64](at).view(1)[0] = bits;
            return;
        }
    }
    write_bits(ptr(at), int(size), little, bits);
}

impl unpack_fast(
    code: i64, size: i64, signed: bool, little: bool, direct: bool, at: ptr[u8]
) -> ptr[PyObject] {
    if integer_code(code) {
        bits = load_bits(at, size, direct, little);
        if not signed {
            return PyLong_FromUnsignedLongLong(bits);
        }
        if size < 8 and (bits & (u64(1) << u64(size * 8 - 1))) != u64(0) {
            bits |= wrapping_shl(~u64(0), u64(size * 8));
        }
        return PyLong_FromLongLong(i64.wrap(bits));
    }
    if code == 100 and direct {
        return PyFloat_FromDouble(ptr[f64](at).view(1)[0]);
    }
    return unpack_field(little, int(code), int(size), signed, ptr(at));
}

impl unpack_table(
    table: ptr[i64], count: i64, little: bool, direct: bool, address: ptr[u8]
) -> ptr[PyObject] {
    result = PyTuple_New(count);
    if result == NULL {
        return NULL;
    }
    slots = ptr[ptr[PyObject]](ptr[u8](result) + PyTupleObject_ITEMS);
    index: i64 = 0;
    while index < count {
        row = table + index * 4;
        value = unpack_fast(
            row.view(1)[0],
            (row + 2).view(1)[0],
            (row + 3).view(1)[0] != 0,
            little,
            direct,
            address + (row + 1).view(1)[0]
        );
        if value == NULL {
            jacpy_release(result);
            return NULL;
        }
        (slots + index).view(1)[0] = value;
        index += 1;
    }
    return result;
}

impl pack_fast(
    code: i64,
    size: i64,
    signed: bool,
    little: bool,
    direct: bool,
    at: ptr[u8],
    value: ptr[PyObject]
) -> i32 {
    type = ptr[ptr[PyObject]](ptr[u8](value) + 8).view(1)[0];
    if type == ptr[PyObject](addressof(PyLong_Type)) and integer_code(code) {
        overflow: i32 = 0;
        number = PyLong_AsLongLongAndOverflow(value, &mut overflow);
        if overflow != 0 {
            return 0;
        }
        if signed {
            if size < 8 {
                limit = i64(1) << (size * 8 - 1);
                if number < -limit or number >= limit {
                    return 0;
                }
            }
        } else {
            if number < 0 {
                return 0;
            }
            if size < 8 and number >= (i64(1) << (size * 8)) {
                return 0;
            }
        }
        store_bits(at, size, direct, little, u64.wrap(number));
        return 1;
    }
    if type == ptr[PyObject](addressof(PyFloat_Type))
        and (code == 100 or code == 102 or code == 101) {
        real = ptr[f64](ptr[u8](value) + FLOAT_VALUE_OFFSET).view(1)[0];
        if code == 100 and direct {
            ptr[f64](at).view(1)[0] = real;
            return 1;
        }
        if jacpy_float_pack(real, ptr(at), size, i64(little)) < 0 {
            return -1;
        }
        return 1;
    }
    if code == 115 and type == ptr[PyObject](addressof(PyBytes_Type)) {
        length = jacpy_bytes_length(value);
        if length > size {
            length = size;
        }
        jacpy_memory_copy(ptr(at), ptr(ptr[u8](value) + PyBytesObject_OB_SVAL), length);
        if length < size {
            zero_memory(ptr(at + length), int(size - length));
        }
        return 1;
    }
    return 0;
}

impl pack_slow(
    instance: ptr[PyObject], row: ptr[i64], address: ptr[u8], value: ptr[PyObject]
) -> i32 {
    state = state_for(instance);
    if state is None {
        return i32(-1);
    }
    module = module_for(instance);
    if module == 0 {
        return i32(-1);
    }
    try {
        pack_field(
            state.plan,
            int(row.view(1)[0]),
            int((row + 2).view(1)[0]),
            (row + 3).view(1)[0] != 0,
            ptr(address + (row + 1).view(1)[0]),
            value,
            jacpy_binding_state_get(module, 0)
        );
        return i32(0);
    } except boundary_failure {
        return i32(-1);
    }
}

impl struct_record_of(instance: ptr[PyObject]) -> ptr[struct_record] {
    return ptr[struct_record](jacpy_binding_record(instance, Struct_token.handle));
}

impl jacpy_struct_pack_record(
    instance: ptr[PyObject],
    record: ptr[struct_record],
    items: ptr[ptr[PyObject]],
    address: ptr[u8]
) -> i32 {
    table = record.view(1)[0].table;
    count = record.view(1)[0].items;
    little = record.view(1)[0].little != 0;
    direct = record.view(1)[0].direct != 0;
    if record.view(1)[0].dense == 0 {
        zero_memory(ptr(address), int(record.view(1)[0].size));
    }
    index: i64 = 0;
    while index < count {
        row = table + index * 4;
        value = (items + index).view(1)[0];
        status = pack_fast(
            row.view(1)[0],
            (row + 2).view(1)[0],
            (row + 3).view(1)[0] != 0,
            little,
            direct,
            address + (row + 1).view(1)[0],
            value
        );
        if status < 0 {
            return i32(-1);
        }
        if status == 0 and pack_slow(instance, row, address, value) < 0 {
            return i32(-1);
        }
        index += 1;
    }
    return i32(0);
}

impl jacpy_struct_unpack_record(
    record: ptr[struct_record], address: ptr[u8]
) -> ptr[PyObject] {
    return unpack_table(
        record.view(1)[0].table,
        record.view(1)[0].items,
        record.view(1)[0].little != 0,
        record.view(1)[0].direct != 0,
        address
    );
}

impl build_table(plan: struct_plan) -> bool {
    table_object = PyBytes_FromStringAndSize(ptr[u8](), i64(max(plan.items, 1) * 32));
    if table_object == NULL {
        return False;
    }
    table = ptr[i64](jacpy_bytes_address(table_object));
    row = 0;
    covered = 0;
    for field in plan.fields {
        covered += field.size * field.count;
        for repetition in range(field.count) {
            cells = (table + row * 4).view(4);
            cells[0] = i64(field.code);
            cells[1] = i64(field.offset + repetition * field.size);
            cells[2] = i64(field.size);
            cells[3] = i64(1 if field.signed else 0);
            row += 1;
        }
    }
    plan.table = table;
    plan.table_object = table_object;
    plan.dense = covered == plan.size;
    return True;
}

impl jacpy_struct_offset(
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

impl jacpy_struct_cursor(
    plan: struct_plan, address: ptr, length: i64
) -> unpack_cursor {
    return unpack_cursor(plan=plan, address=address, length=int(length));
}

impl jacpy_struct_remaining(cursor: unpack_cursor) -> i64 {
    return i64((cursor.length - cursor.index) // cursor.plan.size);
}

impl jacpy_struct_next(cursor: unpack_cursor) -> ptr[PyObject] {
    if cursor.index == cursor.length {
        return NULL;
    }
    result = jacpy_struct_unpack(cursor.plan, cursor.address + cursor.index);
    cursor.index += cursor.plan.size;
    return result;
}

impl jacpy_struct_cached(
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

impl jacpy_struct_memory(plan: struct_plan) -> i64 {
    total = jac_heap_size(u64(id(plan))) + jac_list_heap_size(u64(id(plan.fields)));
    for field in plan.fields {
        total += jac_heap_size(u64(id(field)));
    }
    return total;
}

impl UnpackState.clear {
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

impl UnpackState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
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

impl UnpackState.drop {
    self.clear();
}

impl state_for(instance: ptr[PyObject]) -> (StructState | None) {
    state: (NativeState | None) = jacpy_binding_native_get(
        instance, Struct_token.handle
    );
    if state is not None
        and isinstance(state, StructState)
        and state.references[0] != 0 {
        return state;
    }
    object_error(PyExc_RuntimeError, "Struct object is not initialized");
    return None;
}

impl module_for(instance: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(Py_TYPE(instance), struct_module_token.handle);
}

impl module_error(module: ptr[PyObject], message: str) {
    jacpy_set_exception(
        jacpy_binding_state_get(module, 0), message, i64(len(message.encode("utf-8")))
    );
}

impl iterator_state(instance: ptr[PyObject]) -> (UnpackState | None) {
    if jacpy_binding_native_present(instance, unpack_iterator_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, unpack_iterator_token.handle);
        if isinstance(state, UnpackState) {
            return state;
        }
    }
    return None;
}

impl Struct___init___impl(instance: ptr[PyObject], format_: ptr[PyObject]) -> i32 {
    source = format_;
    format: ptr[PyObject] = NULL;
    if jacpy_is_unicode(source) != 0 {
        format = PyUnicode_AsEncodedString(source, ptr[u8]("ascii"), ptr[u8]("strict"));
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
    state.references.append(state.plan.table_object);
    if jacpy_binding_native_set(instance, Struct_token.handle, state) < 0 {
        return i32(-1);
    }
    record = struct_record_of(instance);
    if record {
        plan = state.plan;
        record.view(1)[0].table = plan.table;
        record.view(1)[0].items = i64(plan.items);
        record.view(1)[0].size = i64(plan.size);
        record.view(1)[0].little = i64(plan.little);
        record.view(1)[0].direct = i64(
            plan.little == (jacpy_native_little_endian() != 0)
        );
        record.view(1)[0].dense = i64(plan.dense);
        record.view(1)[0].module = module;
    }
    return i32(0);
}

impl Struct_unpack_impl(
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

impl Struct_unpack_from_impl(
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

impl Struct_iter_unpack_impl(
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

impl convert_cache_struct_converter(
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

impl _clearcache_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    PyDict_Clear(jacpy_binding_state_get(module, 3));
    return Py_NewRef(Py_None);
}

impl calcsize_impl(module: ptr[PyObject], s_object: ptr[PyObject]) -> i64 {
    state = state_for(s_object);
    if state is None {
        return -1;
    }
    return jacpy_struct_size(state.plan);
}

impl unpack_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return Struct_unpack_impl(s_object, buffer);
}

impl unpack_from_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: BufferArgument, offset: i64
) -> ptr[PyObject] {
    return Struct_unpack_from_impl(s_object, buffer, offset);
}

impl iter_unpack_impl(
    module: ptr[PyObject], s_object: ptr[PyObject], buffer: ptr[PyObject]
) -> ptr[PyObject] {
    return Struct_iter_unpack_impl(s_object, buffer);
}
