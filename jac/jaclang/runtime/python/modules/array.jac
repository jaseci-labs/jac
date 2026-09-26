"""Native typed array storage and sequence policies.

CPython bytearray supplies the retained buffer allocation; resizing, element
conversion, slicing and sequence behavior are native Jac. Exported views pin
logical size until the final buffer release. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyByteArray_Resize,
    PyFloat_AsDouble,
    PyFloat_FromDouble,
    PyIter_Next,
    PyList_Append,
    PyLong_AsLongLong,
    PyLong_AsUnsignedLongLong,
    PyLong_FromLongLong,
    PyNumber_Index,
    PyObject,
    PyObject_Call,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyObject_GetIter,
    PyObject_RichCompare,
    PyObject_RichCompareBool,
    PyUnicode_FromOrdinal,
    PyUnicode_Join,
    PyUnicode_ReadChar,
    Py_NewRef,
    jacpy_bytearray_memory,
    jacpy_bytearray_new,
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_bytes_length,
    jacpy_error_pending,
    jacpy_float32_bits,
    jacpy_float_bits,
    jacpy_float_unpack,
    jacpy_is_bytes,
    jacpy_is_unicode,
    jacpy_list_new,
    jacpy_memory_copy,
    jacpy_memory_move,
    jacpy_memory_zero,
    jacpy_native_little_endian,
    jacpy_native_size,
    jacpy_offset,
    jacpy_release,
    jacpy_unicode_decode_bytes,
    jacpy_unicode_size
}
import from jaclang.runtime.python.modules.binary_scalars {
    read_bits,
    write_bits,
    integer_from_bits
}
import from jaclang.runtime.python.capi {
    required,
    checked,
    object_error,
    boundary_failure,
    text_object,
    jac_heap_size,
    repr_value,
    object_tuple
}

obj array_state {
    has storage: ptr[PyObject] = NULL,
        code: int = 0,
        itemsize: int = 0,
        length: i64 = 0,
        capacity: i64 = 0,
        exports: i64 = 0,
        little: bool = True;
}

def:priv pending {
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
}

def:pub jacpy_array_new -> array_state {
    return array_state();
}

def:pub jacpy_array_init(state: array_state, code: i64) -> i64 {
    state.code = int(code);
    state.little = jacpy_native_little_endian() != 0;
    letter = chr(state.code);
    kind = "bBhHiIlLqQfd".find(letter);
    if kind < 0 and letter not in "uw" {
        object_error(
            "ValueError",
            "bad typecode (must be b, B, u, h, H, i, I, l, L, q, Q, f, d or w)"
        );
        return -1;
    }
    if letter in "uw" {
        state.itemsize = 4;
    } elif letter == "f" {
        state.itemsize = int(jacpy_native_size(8, 0));
    } elif letter == "d" {
        state.itemsize = int(jacpy_native_size(9, 0));
    } else {
        state.itemsize = int(jacpy_native_size(i64(kind // 2), 0));
    }
    state.storage = jacpy_bytearray_new(0);
    return 0 if state.storage != 0 else -1;
}

def:pub jacpy_array_clear(state: array_state) {
    storage = state.storage;
    state.storage = NULL;
    state.length = 0;
    state.capacity = 0;
    jacpy_release(storage);
}

def:pub jacpy_array_field(state: array_state) -> ptr[PyObject] {
    return state.storage;
}

def:pub jacpy_array_length(state: array_state) -> i64 {
    return state.length;
}

def:pub jacpy_array_code(state: array_state) -> i64 {
    return i64(state.code);
}

def:pub jacpy_array_itemsize(state: array_state) -> i64 {
    return i64(state.itemsize);
}

def:pub jacpy_array_address(state: array_state) -> ptr {
    return jacpy_bytes_address(state.storage);
}

def:pub jacpy_array_export(state: array_state, delta: i64) {
    state.exports += delta;
}

def:pub jacpy_array_memory(state: array_state) -> i64 {
    return jac_heap_size(u64(id(state))) + jacpy_bytearray_memory(state.storage);
}

# Convert before taking an address: __index__ and __float__ may resize the array.
def:priv encode(state: array_state, value: ptr[PyObject]) -> u64 {
    letter = chr(state.code);
    if letter in "uw" {
        if jacpy_is_unicode(value) == 0 or jacpy_unicode_size(value) != 1 {
            object_error("TypeError", "array item must be unicode character");
            raise boundary_failure();
        }
        return u64(PyUnicode_ReadChar(value, 0));
    }
    if letter in "fd" {
        floating = PyFloat_AsDouble(value);
        pending();
        return jacpy_float32_bits(floating)
            if state.itemsize == 4
            else jacpy_float_bits(floating);
    }
    number = required(PyNumber_Index(value));
    try {
        signed = letter in "bhilq";
        if signed {
            actual = PyLong_AsLongLong(number);
            pending();
            if state.itemsize < 8 {
                limit = i64(1) << i64(state.itemsize * 8 - 1);
                if actual < -limit or actual >= limit {
                    object_error("OverflowError", "signed integer is out of range");
                    raise boundary_failure();
                }
            }
            return ~u64(-(actual + i64(1))) if actual < 0 else u64(actual);
        }
        bits = PyLong_AsUnsignedLongLong(number);
        pending();
        if state.itemsize < 8 and bits >= (u64(1) << i64(state.itemsize * 8)) {
            object_error("OverflowError", "unsigned integer is out of range");
            raise boundary_failure();
        }
        return bits;
    } finally {
        jacpy_release(number);
    }
}

def:priv decode(state: array_state, index: i64) -> ptr[PyObject] {
    address = jacpy_offset(
        jacpy_bytes_address(state.storage), index * i64(state.itemsize)
    );
    letter = chr(state.code);
    if letter in "fd" {
        number = jacpy_float_unpack(address, i64(state.itemsize), i64(state.little));
        pending();
        return required(PyFloat_FromDouble(number));
    }
    bits = read_bits(address, state.itemsize, state.little);
    if letter in "uw" {
        if bits > u64(1114111) {
            object_error("ValueError", "character out of range [U+0000; U+10ffff]");
            raise boundary_failure();
        }
        return required(PyUnicode_FromOrdinal(i32(bits)));
    }
    return integer_from_bits(bits, state.itemsize, letter in "bhilq");
}

def:priv resize(state: array_state, length: i64) {
    if length == state.length {
        return;
    }
    if state.exports != 0 {
        object_error("BufferError", "cannot resize an array that is exporting buffers");
        raise boundary_failure();
    }
    if length < 0 or length > i64(9223372036854775807) // i64(state.itemsize) {
        object_error("MemoryError", "");
        raise boundary_failure();
    }
    if length > state.capacity or length == 0 {
        capacity = length;
        if length > state.capacity
            and length
                < i64(9223372036854775807) // i64(state.itemsize) - length // 8 - 8 {
            capacity += length // 8 + 8;
        }
        checked(PyByteArray_Resize(state.storage, capacity * i64(state.itemsize)));
        state.capacity = capacity;
    }
    state.length = length;
}

def:pub jacpy_array_item(state: array_state, index: i64) -> ptr[PyObject] {
    try {
        if index < 0 or index >= state.length {
            object_error("IndexError", "array index out of range");
            return NULL;
        }
        return decode(state, index);
    } except boundary_failure {
        return NULL;
    }
}

def:pub jacpy_array_assign(
    state: array_state, index: i64, value: ptr[PyObject]
) -> i64 {
    try {
        bits = encode(state, value);
        if index < 0 or index >= state.length {
            object_error("IndexError", "array assignment index out of range");
            return -1;
        }
        write_bits(
            jacpy_offset(
                jacpy_bytes_address(state.storage), index * i64(state.itemsize)
            ),
            state.itemsize,
            state.little,
            bits
        );
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_insert(
    state: array_state, index: i64, value: ptr[PyObject]
) -> i64 {
    try {
        bits = encode(state, value);
        if index < 0 {
            index = max(i64(0), index + state.length);
        }
        index = min(index, state.length);
        old_length = state.length;
        resize(state, old_length + 1);
        address = jacpy_bytes_address(state.storage);
        width = i64(state.itemsize);
        jacpy_memory_move(
            jacpy_offset(address, (index + 1) * width),
            jacpy_offset(address, index * width),
            (old_length - index) * width
        );
        write_bits(
            jacpy_offset(address, index * width), state.itemsize, state.little, bits
        );
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_empty(state: array_state) -> i64 {
    try {
        resize(state, 0);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_extend(state: array_state, values: ptr[PyObject]) -> i64 {
    iterator: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    try {
        iterator = required(PyObject_GetIter(values));
        while True {
            value = PyIter_Next(iterator);
            if value == 0 {
                pending();
                return 0;
            }
            checked(jacpy_array_insert(state, state.length, value));
            jacpy_release(value);
            value = NULL;
        }
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(value);
        jacpy_release(iterator);
    }
}

def:pub jacpy_array_tolist(state: array_state) -> ptr[PyObject] {
    result: ptr[PyObject] = NULL;
    value: ptr[PyObject] = NULL;
    try {
        result = required(jacpy_list_new());
        index: i64 = 0;
        while index < state.length {
            value = decode(state, index);
            checked(PyList_Append(result, value));
            jacpy_release(value);
            value = NULL;
            index += 1;
        }
        answer = result;
        result = NULL;
        return answer;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(value);
        jacpy_release(result);
    }
}

def:pub jacpy_array_tobytes(state: array_state) -> ptr[PyObject] {
    return jacpy_bytes_from_memory(
        jacpy_bytes_address(state.storage), state.length * i64(state.itemsize)
    );
}

# Source bytes are held by the boundary across resizing, including self-views.
def:pub jacpy_array_frombytes(state: array_state, address: ptr, size: i64) -> i64 {
    try {
        width = i64(state.itemsize);
        if size % width != 0 {
            object_error("ValueError", "bytes length not a multiple of item size");
            return -1;
        }
        old_length = state.length;
        if size // width > i64(9223372036854775807) - old_length {
            object_error("MemoryError", "");
            return -1;
        }
        resize(state, old_length + size // width);
        if size != 0 {
            jacpy_memory_copy(
                jacpy_offset(jacpy_bytes_address(state.storage), old_length * width),
                address,
                size
            );
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_reverse(state: array_state, swap_bytes: i64) {
    address = jacpy_bytes_address(state.storage);
    width = i64(state.itemsize);
    if swap_bytes != 0 {
        index: i64 = 0;
        while index < state.length {
            offset = jacpy_offset(address, index * width);
            write_bits(
                offset,
                state.itemsize,
                not state.little,
                read_bits(offset, state.itemsize, state.little)
            );
            index += 1;
        }
    } else {
        index: i64 = 0;
        while index < state.length // 2 {
            left = jacpy_offset(address, index * width);
            right = jacpy_offset(address, (state.length - index - 1) * width);
            a = read_bits(left, state.itemsize, state.little);
            b = read_bits(right, state.itemsize, state.little);
            write_bits(left, state.itemsize, state.little, b);
            write_bits(right, state.itemsize, state.little, a);
            index += 1;
        }
    }
}

def:pub jacpy_array_copy(
    out: array_state, source: array_state, start: i64, step: i64, count: i64
) -> i64 {
    try {
        resize(out, count);
        width = i64(out.itemsize);
        target = jacpy_bytes_address(out.storage);
        address = jacpy_bytes_address(source.storage);
        if step == 1 and count > 0 {
            jacpy_memory_copy(
                target, jacpy_offset(address, start * width), count * width
            );
        } else {
            i: i64 = 0;
            while i < count {
                jacpy_memory_copy(
                    jacpy_offset(target, i * width),
                    jacpy_offset(address, (start + i * step) * width),
                    width
                );
                i += 1;
            }
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_assign_slice(
    state: array_state, start: i64, step: i64, count: i64, source: array_state
) -> i64 {
    snapshot: ptr[PyObject] = NULL;
    try {
        if state.code != source.code {
            object_error("TypeError", "bad argument type for built-in operation");
            return -1;
        }
        if step != 1 and count != source.length {
            object_error(
                "ValueError",
                "attempt to assign array of size "
                    + str(source.length)
                    + " to extended slice of size "
                    + str(count)
            );
            return -1;
        }
        source_length = source.length;
        old_length = state.length;
        width = i64(state.itemsize);
        if source_length > i64(9223372036854775807) - (old_length - count) {
            object_error("MemoryError", "");
            return -1;
        }
        new_length = old_length - count + source_length;
        if new_length != old_length and state.exports != 0 {
            object_error(
                "BufferError", "cannot resize an array that is exporting buffers"
            );
            return -1;
        }
        snapshot = required(jacpy_array_tobytes(source));
        if new_length > old_length {
            resize(state, new_length);
        }
        address = jacpy_bytes_address(state.storage);
        data = jacpy_bytes_address(snapshot);
        if step == 1 {
            tail = old_length - start - count;
            if tail > 0 {
                jacpy_memory_move(
                    jacpy_offset(address, (start + source_length) * width),
                    jacpy_offset(address, (start + count) * width),
                    tail * width
                );
            }
            if source_length > 0 {
                jacpy_memory_copy(
                    jacpy_offset(address, start * width), data, source_length * width
                );
            }
        } else {
            i: i64 = 0;
            while i < count {
                jacpy_memory_copy(
                    jacpy_offset(address, (start + i * step) * width),
                    jacpy_offset(data, i * width),
                    width
                );
                i += 1;
            }
        }
        if new_length < old_length {
            resize(state, new_length);
        }
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(snapshot);
    }
}

def:pub jacpy_array_delete(
    state: array_state, start: i64, step: i64, count: i64
) -> i64 {
    try {
        if count == 0 {
            return 0;
        }
        if state.exports != 0 {
            object_error(
                "BufferError", "cannot resize an array that is exporting buffers"
            );
            return -1;
        }
        if step < 0 {
            start += (count - 1) * step;
            step = -step;
        }
        address = jacpy_bytes_address(state.storage);
        width = i64(state.itemsize);
        read: i64 = start;
        write: i64 = start;
        removed: i64 = 0;
        next_removed = start;
        while read < state.length {
            if removed < count and read == next_removed {
                removed += 1;
                if removed < count {
                    next_removed += step;
                }
            } else {
                if write != read {
                    jacpy_memory_move(
                        jacpy_offset(address, write * width),
                        jacpy_offset(address, read * width),
                        width
                    );
                }
                write += 1;
            }
            read += 1;
        }
        resize(state, state.length - count);
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_pop(state: array_state, index: i64) -> ptr[PyObject] {
    value: ptr[PyObject] = NULL;
    try {
        if index < 0 {
            index += state.length;
        }
        if index < 0 or index >= state.length {
            object_error("IndexError", "pop index out of range");
            return NULL;
        }
        value = decode(state, index);
        checked(jacpy_array_delete(state, index, 1, 1));
        result = value;
        value = NULL;
        return result;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(value);
    }
}

def:pub jacpy_array_repeat(state: array_state, times: i64) -> i64 {
    try {
        if times < 0 {
            times = 0;
        }
        old_length = state.length;
        if old_length == 0 or times == 1 {
            return 0;
        }
        if times > i64(9223372036854775807) // old_length {
            object_error("MemoryError", "");
            return -1;
        }
        resize(state, old_length * times);
        address = jacpy_bytes_address(state.storage);
        width = i64(state.itemsize);
        copied = old_length;
        while copied < state.length {
            amount = min(copied, state.length - copied);
            jacpy_memory_copy(
                jacpy_offset(address, copied * width), address, amount * width
            );
            copied += amount;
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_fromlist(state: array_state, values: ptr[PyObject]) -> i64 {
    temporary = array_state();
    try {
        checked(jacpy_array_init(temporary, i64(state.code)));
        checked(jacpy_array_extend(temporary, values));
        return jacpy_array_assign_slice(state, state.length, 1, 0, temporary);
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_array_clear(temporary);
    }
}

# Element comparisons keep a strong operand while arbitrary Python equality runs.
def:pub jacpy_array_search(
    state: array_state, value: ptr[PyObject], start: i64, stop: i64, mode: i64
) -> i64 {
    item: ptr[PyObject] = NULL;
    try {
        if start < 0 {
            start = max(i64(0), start + state.length);
        }
        if stop < 0 {
            stop = max(i64(0), stop + state.length);
        }
        index = start;
        found: i64 = 0;
        while index < min(stop, state.length) {
            item = decode(state, index);
            equal = PyObject_RichCompareBool(item, value, 2);
            checked(equal);
            jacpy_release(item);
            item = NULL;
            if equal != 0 {
                if mode == 1 {
                    return index;
                }
                if mode == 2 {
                    if index < state.length {
                        checked(jacpy_array_delete(state, index, 1, 1));
                    }
                    return 0;
                }
                if mode == 3 {
                    return 1;
                }
                found += 1;
            }
            index += 1;
        }
        if mode == 1 or mode == 2 {
            object_error("ValueError", "array.index(x): x not in array");
            return -1;
        }
        return found;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(item);
    }
}

def:pub jacpy_array_compare(
    left: array_state, right: array_state, operation: i64
) -> ptr[PyObject] {
    a: ptr[PyObject] = NULL;
    b: ptr[PyObject] = NULL;
    try {
        if (operation == 2 or operation == 3) and left.length != right.length {
            return PyBool_FromLong(i64(operation == 3));
        }
        index: i64 = 0;
        while index < min(left.length, right.length) {
            a = decode(left, index);
            b = decode(right, index);
            equal = PyObject_RichCompareBool(a, b, 2);
            checked(equal);
            if equal == 0 {
                return PyObject_RichCompare(a, b, i32(operation));
            }
            jacpy_release(a);
            a = NULL;
            jacpy_release(b);
            b = NULL;
            index += 1;
        }
        a = required(PyLong_FromLongLong(left.length));
        b = required(PyLong_FromLongLong(right.length));
        return PyObject_RichCompare(a, b, i32(operation));
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(a);
        jacpy_release(b);
    }
}

def:pub jacpy_array_tounicode(state: array_state) -> ptr[PyObject] {
    values: ptr[PyObject] = NULL;
    separator: ptr[PyObject] = NULL;
    try {
        if chr(state.code) not in "uw" {
            object_error(
                "ValueError", "tounicode() may only be called on unicode type arrays"
            );
            return NULL;
        }
        values = required(jacpy_array_tolist(state));
        separator = text_object("");
        return PyUnicode_Join(separator, values);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(values);
        jacpy_release(separator);
    }
}

def:pub jacpy_array_fromunicode(state: array_state, value: ptr[PyObject]) -> i64 {
    if chr(state.code) not in "uw" {
        object_error(
            "ValueError", "fromunicode() may only be called on unicode type arrays"
        );
        return -1;
    }
    return jacpy_array_extend(state, value);
}

def:pub jacpy_array_repr(state: array_state) -> ptr[PyObject] {
    value: ptr[PyObject] = NULL;
    try {
        prefix = "array('" + chr(state.code) + "'";
        if state.length == 0 {
            return text_object(prefix + ")");
        }
        value = required(
            jacpy_array_tounicode(state)
                if chr(state.code) in "uw"
                else jacpy_array_tolist(state)
        );
        return text_object(prefix + ", " + repr_value(value) + ")");
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(value);
    }
}

obj array_cursor {
    has state: (array_state | None),
        owner: ptr[PyObject] = NULL,
        index: i64 = 0;
}

def:pub jacpy_array_cursor_new(
    owner: ptr[PyObject], state: array_state
) -> array_cursor {
    return array_cursor(state=state, owner=Py_NewRef(owner));
}

def:pub jacpy_array_cursor_owner(cursor: array_cursor) -> ptr[PyObject] {
    return cursor.owner;
}

def:pub jacpy_array_cursor_index(cursor: array_cursor) -> i64 {
    return cursor.index;
}

def:pub jacpy_array_cursor_clear(cursor: array_cursor) {
    owner = cursor.owner;
    cursor.owner = NULL;
    cursor.state = None;
    jacpy_release(owner);
}

def:pub jacpy_array_cursor_set(cursor: array_cursor, index: i64) {
    state = cursor.state;
    if cursor.owner != 0 and state is not None {
        cursor.index = min(state.length, max(i64(0), index));
    }
}

def:pub jacpy_array_cursor_next(cursor: array_cursor) -> ptr[PyObject] {
    state = cursor.state;
    if cursor.owner == 0 or state is None {
        return NULL;
    }
    if cursor.index >= state.length {
        jacpy_array_cursor_clear(cursor);
        return NULL;
    }
    try {
        value = decode(state, cursor.index);
        cursor.index += 1;
        return value;
    } except boundary_failure {
        return NULL;
    }
}

def:pub jacpy_array_fromfile(
    state: array_state, file: ptr[PyObject], count: i64
) -> i64 {
    method: ptr[PyObject] = NULL;
    size: ptr[PyObject] = NULL;
    data: ptr[PyObject] = NULL;
    try {
        if count < 0 {
            object_error("ValueError", "negative count");
            return -1;
        }
        if count > i64(9223372036854775807) // i64(state.itemsize) {
            object_error("MemoryError", "");
            return -1;
        }
        expected = count * i64(state.itemsize);
        size = required(PyLong_FromLongLong(expected));
        method = required(PyObject_GetAttrString(file, "read"));
        data = required(PyObject_CallOneArg(method, size));
        if jacpy_is_bytes(data) == 0 {
            object_error("TypeError", "read() didn't return bytes");
            return -1;
        }
        actual = jacpy_bytes_length(data);
        checked(jacpy_array_frombytes(state, jacpy_bytes_address(data), actual));
        if actual != expected {
            object_error("EOFError", "read() didn't return enough bytes");
            return -1;
        }
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(method);
        jacpy_release(size);
        jacpy_release(data);
    }
}

def:pub jacpy_array_tofile(state: array_state, file: ptr[PyObject]) -> i64 {
    snapshot: ptr[PyObject] = NULL;
    method: ptr[PyObject] = NULL;
    block: ptr[PyObject] = NULL;
    result: ptr[PyObject] = NULL;
    try {
        if state.length == 0 {
            return 0;
        }
        snapshot = required(jacpy_array_tobytes(state));
        size = jacpy_bytes_length(snapshot);
        offset: i64 = 0;
        while offset < size {
            amount = min(i64(65536), size - offset);
            block = required(
                jacpy_bytes_from_memory(
                    jacpy_offset(jacpy_bytes_address(snapshot), offset), amount
                )
            );
            method = required(PyObject_GetAttrString(file, "write"));
            result = required(PyObject_CallOneArg(method, block));
            jacpy_release(result);
            result = NULL;
            jacpy_release(method);
            method = NULL;
            jacpy_release(block);
            block = NULL;
            offset += amount;
        }
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(snapshot);
        jacpy_release(method);
        jacpy_release(block);
        jacpy_release(result);
    }
}

def:priv machine_format(state: array_state) -> int {
    code = chr(state.code);
    endian = int(not state.little);
    if code == "b" {
        return 1;
    }
    if code == "B" {
        return 0;
    }
    if code in "uw" {
        return 20 + endian;
    }
    if code == "f" {
        return 14 + endian;
    }
    if code == "d" {
        return 16 + endian;
    }
    base = 2 if state.itemsize == 2 else 6 if state.itemsize == 4 else 10;
    return base + endian + (2 if code in "hilq" else 0);
}

def:pub jacpy_array_reduce(
    state: array_state,
    type: ptr[PyObject],
    dictionary: ptr[PyObject],
    reconstructor: ptr[PyObject],
    protocol: i64
) -> ptr[PyObject] {
    code: ptr[PyObject] = NULL;
    values: ptr[PyObject] = NULL;
    format: ptr[PyObject] = NULL;
    args: ptr[PyObject] = NULL;
    try {
        code = text_object(chr(state.code));
        if protocol < 3 {
            values = required(jacpy_array_tolist(state));
            args = object_tuple([code, values]);
            return object_tuple([type, args, dictionary]);
        }
        values = required(jacpy_array_tobytes(state));
        format = required(PyLong_FromLongLong(i64(machine_format(state))));
        args = object_tuple([type, code, format, values]);
        return object_tuple([reconstructor, args, dictionary]);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(code);
        jacpy_release(values);
        jacpy_release(format);
        jacpy_release(args);
    }
}

def:pub jacpy_array_cursor_reduce(
    cursor: array_cursor, iterate: ptr[PyObject]
) -> ptr[PyObject] {
    args: ptr[PyObject] = NULL;
    index: ptr[PyObject] = NULL;
    empty: ptr[PyObject] = NULL;
    try {
        if cursor.owner == 0 {
            empty = object_tuple([]);
            args = object_tuple([empty]);
            return object_tuple([iterate, args]);
        }
        args = object_tuple([cursor.owner]);
        index = required(PyLong_FromLongLong(cursor.index));
        return object_tuple([iterate, args, index]);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(args);
        jacpy_release(index);
        jacpy_release(empty);
    }
}

def:priv decode_pickle(
    state: array_state, format: i64, data: ptr[PyObject]
) -> ptr[PyObject] {
    value: ptr[PyObject] = NULL;
    decoded: ptr[PyObject] = NULL;
    values: ptr[PyObject] = NULL;
    try {
        if format < 0 or format > 21 {
            object_error(
                "ValueError", "third argument must be a valid machine format code"
            );
            return NULL;
        }
        size = jacpy_bytes_length(data);
        address = jacpy_bytes_address(data);
        if format == i64(machine_format(state)) {
            return Py_NewRef(data);
        }
        width = 1
            if format < 2
            else 2
                if format < 6
                else 4
                    if format < 10
                    else 8
                        if format < 14
                        else 4
                            if format < 16
                            else 8 if format < 18 else 4 if format < 20 else 8;
        if size % i64(width) != 0 {
            object_error("ValueError", "string length not a multiple of item size");
            return NULL;
        }
        little = format % 2 == 0;
        if format >= 18 {
            encoding = ("utf-16-" if format < 20 else "utf-32-")
                + ("le" if little else "be");
            decoded = required(jacpy_unicode_decode_bytes(data, encoding));
            result = decoded;
            decoded = NULL;
            return result;
        }
        signed = format == 1 or (format >= 2 and (format - 2) % 4 >= 2);
        if format < 14 {
            # Match the retained platform's narrowest suitable integer layout;
            # ties follow the descriptor order used by CPython array pickles.
            for code in "bBhHiIlLqQ" {
                kind = "bBhHiIlLqQ".find(code) // 2;
                if jacpy_native_size(i64(kind), 0) == i64(width)
                    and (code in "bhilq") == signed {
                    state.code = ord(code);
                    state.itemsize = width;
                }
            }
        }
        values = required(jacpy_list_new());
        offset: i64 = 0;
        while offset < size {
            if format >= 14 {
                floating = jacpy_float_unpack(
                    jacpy_offset(address, offset), i64(width), i64(little)
                );
                pending();
                value = required(PyFloat_FromDouble(floating));
            } else {
                value = integer_from_bits(
                    read_bits(jacpy_offset(address, offset), width, little),
                    width,
                    signed
                );
            }
            checked(PyList_Append(values, value));
            jacpy_release(value);
            value = NULL;
            offset += i64(width);
        }
        result = values;
        values = NULL;
        return result;
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_release(value);
        jacpy_release(decoded);
        jacpy_release(values);
    }
}

def:pub jacpy_array_reconstruct_object(
    type: ptr[PyObject], code: i64, format: i64, data: ptr[PyObject]
) -> ptr[PyObject] {
    state = array_state();
    values: ptr[PyObject] = NULL;
    tag: ptr[PyObject] = NULL;
    args: ptr[PyObject] = NULL;
    try {
        checked(jacpy_array_init(state, code));
        values = required(decode_pickle(state, format, data));
        tag = text_object(chr(state.code));
        args = object_tuple([tag, values]);
        return PyObject_Call(type, args, NULL);
    } except boundary_failure {
        return NULL;
    } finally {
        jacpy_array_clear(state);
        jacpy_release(values);
        jacpy_release(tag);
        jacpy_release(args);
    }
}
