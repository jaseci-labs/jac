"""Native typed array storage and sequence policies.

CPython bytearray supplies the retained buffer allocation; resizing, element
conversion, slicing and sequence behavior are native Jac. Exported views pin
logical size until the final buffer release. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""
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
    jacpy_release,
    jacpy_retain,
    jacpy_error_pending,
    jacpy_index,
    jacpy_integer_value,
    jacpy_long_u64,
    jacpy_number_as_double,
    jacpy_float32_bits,
    jacpy_float_bits,
    jacpy_float_unpack,
    jacpy_float,
    jacpy_is_unicode,
    jacpy_unicode_size,
    jacpy_unicode_char,
    jacpy_unicode_from_ordinal,
    jacpy_bytearray_new,
    jacpy_bytearray_resize,
    jacpy_bytearray_memory,
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_native_size,
    jacpy_native_little_endian,
    jacpy_memory_copy,
    jacpy_memory_move,
    jacpy_memory_zero,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_list_new,
    jacpy_list_append,
    jac_heap_size,
    jacpy_compare_bool,
    jacpy_compare,
    jacpy_boolean,
    jacpy_int,
    jacpy_unicode_join,
    repr_value,
    object_tuple,
    jacpy_getattr_string,
    jacpy_call_one,
    jacpy_call,
    jacpy_is_bytes,
    jacpy_bytes_length,
    jacpy_unicode_decode_bytes
}

obj array_state {
    has storage: u64 = 0,
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
    state.storage = 0;
    state.length = 0;
    state.capacity = 0;
    jacpy_release(storage);
}

def:pub jacpy_array_field(state: array_state) -> u64 {
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

def:pub jacpy_array_address(state: array_state) -> u64 {
    return jacpy_bytes_address(state.storage);
}

def:pub jacpy_array_export(state: array_state, delta: i64) {
    state.exports += delta;
}

def:pub jacpy_array_memory(state: array_state) -> i64 {
    return jac_heap_size(u64(id(state))) + jacpy_bytearray_memory(state.storage);
}

# Convert before taking an address: __index__ and __float__ may resize the array.
def:priv encode(state: array_state, value: u64) -> u64 {
    letter = chr(state.code);
    if letter in "uw" {
        if jacpy_is_unicode(value) == 0 or jacpy_unicode_size(value) != 1 {
            object_error("TypeError", "array item must be unicode character");
            raise boundary_failure();
        }
        return u64(jacpy_unicode_char(value, 0));
    }
    if letter in "fd" {
        floating = jacpy_number_as_double(value);
        pending();
        return jacpy_float32_bits(floating)
            if state.itemsize == 4
            else jacpy_float_bits(floating);
    }
    number = required(jacpy_index(value));
    try {
        signed = letter in "bhilq";
        if signed {
            actual = jacpy_integer_value(number);
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
        bits = jacpy_long_u64(number);
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

def:priv decode(state: array_state, index: i64) -> u64 {
    address = jacpy_bytes_address(state.storage) + u64(index * i64(state.itemsize));
    letter = chr(state.code);
    if letter in "fd" {
        number = jacpy_float_unpack(address, i64(state.itemsize), i64(state.little));
        pending();
        return required(jacpy_float(number));
    }
    bits = read_bits(address, state.itemsize, state.little);
    if letter in "uw" {
        if bits > u64(1114111) {
            object_error("ValueError", "character out of range [U+0000; U+10ffff]");
            raise boundary_failure();
        }
        return required(jacpy_unicode_from_ordinal(i64(bits)));
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
        checked(jacpy_bytearray_resize(state.storage, capacity * i64(state.itemsize)));
        state.capacity = capacity;
    }
    state.length = length;
}

def:pub jacpy_array_item(state: array_state, index: i64) -> u64 {
    try {
        if index < 0 or index >= state.length {
            object_error("IndexError", "array index out of range");
            return 0;
        }
        return decode(state, index);
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_array_assign(state: array_state, index: i64, value: u64) -> i64 {
    try {
        bits = encode(state, value);
        if index < 0 or index >= state.length {
            object_error("IndexError", "array assignment index out of range");
            return -1;
        }
        write_bits(
            jacpy_bytes_address(state.storage) + u64(index * i64(state.itemsize)),
            state.itemsize,
            state.little,
            bits
        );
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_insert(state: array_state, index: i64, value: u64) -> i64 {
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
            address + u64((index + 1) * width),
            address + u64(index * width),
            (old_length - index) * width
        );
        write_bits(address + u64(index * width), state.itemsize, state.little, bits);
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

def:pub jacpy_array_extend(state: array_state, values: u64) -> i64 {
    iterator: u64 = 0;
    value: u64 = 0;
    try {
        iterator = required(jacpy_iter(values));
        while True {
            value = jacpy_iter_next(iterator);
            if value == 0 {
                pending();
                return 0;
            }
            checked(jacpy_array_insert(state, state.length, value));
            jacpy_release(value);
            value = 0;
        }
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(value);
        jacpy_release(iterator);
    }
}

def:pub jacpy_array_tolist(state: array_state) -> u64 {
    result: u64 = 0;
    value: u64 = 0;
    try {
        result = required(jacpy_list_new());
        index: i64 = 0;
        while index < state.length {
            value = decode(state, index);
            checked(jacpy_list_append(result, value));
            jacpy_release(value);
            value = 0;
            index += 1;
        }
        answer = result;
        result = 0;
        return answer;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(value);
        jacpy_release(result);
    }
}

def:pub jacpy_array_tobytes(state: array_state) -> u64 {
    return jacpy_bytes_from_memory(
        jacpy_bytes_address(state.storage), state.length * i64(state.itemsize)
    );
}

# Source bytes are held by the boundary across resizing, including self-views.
def:pub jacpy_array_frombytes(state: array_state, address: u64, size: i64) -> i64 {
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
                jacpy_bytes_address(state.storage) + u64(old_length * width),
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
            offset = address + u64(index * width);
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
            left = address + u64(index * width);
            right = address + u64((state.length - index - 1) * width);
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
            jacpy_memory_copy(target, address + u64(start * width), count * width);
        } else {
            i: i64 = 0;
            while i < count {
                jacpy_memory_copy(
                    target + u64(i * width),
                    address + u64((start + i * step) * width),
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
    snapshot: u64 = 0;
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
                    address + u64((start + source_length) * width),
                    address + u64((start + count) * width),
                    tail * width
                );
            }
            if source_length > 0 {
                jacpy_memory_copy(
                    address + u64(start * width), data, source_length * width
                );
            }
        } else {
            i: i64 = 0;
            while i < count {
                jacpy_memory_copy(
                    address + u64((start + i * step) * width),
                    data + u64(i * width),
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
                        address + u64(write * width), address + u64(read * width), width
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

def:pub jacpy_array_pop(state: array_state, index: i64) -> u64 {
    value: u64 = 0;
    try {
        if index < 0 {
            index += state.length;
        }
        if index < 0 or index >= state.length {
            object_error("IndexError", "pop index out of range");
            return 0;
        }
        value = decode(state, index);
        checked(jacpy_array_delete(state, index, 1, 1));
        result = value;
        value = 0;
        return result;
    } except boundary_failure {
        return 0;
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
            jacpy_memory_copy(address + u64(copied * width), address, amount * width);
            copied += amount;
        }
        return 0;
    } except boundary_failure {
        return -1;
    }
}

def:pub jacpy_array_fromlist(state: array_state, values: u64) -> i64 {
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
    state: array_state, value: u64, start: i64, stop: i64, mode: i64
) -> i64 {
    item: u64 = 0;
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
            equal = jacpy_compare_bool(item, value, 2);
            checked(equal);
            jacpy_release(item);
            item = 0;
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
) -> u64 {
    a: u64 = 0;
    b: u64 = 0;
    try {
        if (operation == 2 or operation == 3) and left.length != right.length {
            return jacpy_boolean(i64(operation == 3));
        }
        index: i64 = 0;
        while index < min(left.length, right.length) {
            a = decode(left, index);
            b = decode(right, index);
            equal = jacpy_compare_bool(a, b, 2);
            checked(equal);
            if equal == 0 {
                return jacpy_compare(a, b, operation);
            }
            jacpy_release(a);
            a = 0;
            jacpy_release(b);
            b = 0;
            index += 1;
        }
        a = required(jacpy_int(left.length));
        b = required(jacpy_int(right.length));
        return jacpy_compare(a, b, operation);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(a);
        jacpy_release(b);
    }
}

def:pub jacpy_array_tounicode(state: array_state) -> u64 {
    values: u64 = 0;
    separator: u64 = 0;
    try {
        if chr(state.code) not in "uw" {
            object_error(
                "ValueError", "tounicode() may only be called on unicode type arrays"
            );
            return 0;
        }
        values = required(jacpy_array_tolist(state));
        separator = text_object("");
        return jacpy_unicode_join(separator, values);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(values);
        jacpy_release(separator);
    }
}

def:pub jacpy_array_fromunicode(state: array_state, value: u64) -> i64 {
    if chr(state.code) not in "uw" {
        object_error(
            "ValueError", "fromunicode() may only be called on unicode type arrays"
        );
        return -1;
    }
    return jacpy_array_extend(state, value);
}

def:pub jacpy_array_repr(state: array_state) -> u64 {
    value: u64 = 0;
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
        return 0;
    } finally {
        jacpy_release(value);
    }
}

obj array_cursor {
    has state: (array_state | None),
        owner: u64 = 0,
        index: i64 = 0;
}

def:pub jacpy_array_cursor_new(owner: u64, state: array_state) -> array_cursor {
    return array_cursor(state=state, owner=jacpy_retain(owner));
}

def:pub jacpy_array_cursor_owner(cursor: array_cursor) -> u64 {
    return cursor.owner;
}

def:pub jacpy_array_cursor_index(cursor: array_cursor) -> i64 {
    return cursor.index;
}

def:pub jacpy_array_cursor_clear(cursor: array_cursor) {
    owner = cursor.owner;
    cursor.owner = 0;
    cursor.state = None;
    jacpy_release(owner);
}

def:pub jacpy_array_cursor_set(cursor: array_cursor, index: i64) {
    state = cursor.state;
    if cursor.owner != 0 and state is not None {
        cursor.index = min(state.length, max(i64(0), index));
    }
}

def:pub jacpy_array_cursor_next(cursor: array_cursor) -> u64 {
    state = cursor.state;
    if cursor.owner == 0 or state is None {
        return 0;
    }
    if cursor.index >= state.length {
        jacpy_array_cursor_clear(cursor);
        return 0;
    }
    try {
        value = decode(state, cursor.index);
        cursor.index += 1;
        return value;
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_array_fromfile(state: array_state, file: u64, count: i64) -> i64 {
    method: u64 = 0;
    size: u64 = 0;
    data: u64 = 0;
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
        size = required(jacpy_int(expected));
        method = required(jacpy_getattr_string(file, "read"));
        data = required(jacpy_call_one(method, size));
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

def:pub jacpy_array_tofile(state: array_state, file: u64) -> i64 {
    snapshot: u64 = 0;
    method: u64 = 0;
    block: u64 = 0;
    result: u64 = 0;
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
                    jacpy_bytes_address(snapshot) + u64(offset), amount
                )
            );
            method = required(jacpy_getattr_string(file, "write"));
            result = required(jacpy_call_one(method, block));
            jacpy_release(result);
            result = 0;
            jacpy_release(method);
            method = 0;
            jacpy_release(block);
            block = 0;
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
    state: array_state, type: u64, dictionary: u64, reconstructor: u64, protocol: i64
) -> u64 {
    code: u64 = 0;
    values: u64 = 0;
    format: u64 = 0;
    args: u64 = 0;
    try {
        code = text_object(chr(state.code));
        if protocol < 3 {
            values = required(jacpy_array_tolist(state));
            args = object_tuple([code, values]);
            return object_tuple([type, args, dictionary]);
        }
        values = required(jacpy_array_tobytes(state));
        format = required(jacpy_int(i64(machine_format(state))));
        args = object_tuple([type, code, format, values]);
        return object_tuple([reconstructor, args, dictionary]);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(code);
        jacpy_release(values);
        jacpy_release(format);
        jacpy_release(args);
    }
}

def:pub jacpy_array_cursor_reduce(cursor: array_cursor, iterate: u64) -> u64 {
    args: u64 = 0;
    index: u64 = 0;
    empty: u64 = 0;
    try {
        if cursor.owner == 0 {
            empty = object_tuple([]);
            args = object_tuple([empty]);
            return object_tuple([iterate, args]);
        }
        args = object_tuple([cursor.owner]);
        index = required(jacpy_int(cursor.index));
        return object_tuple([iterate, args, index]);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(args);
        jacpy_release(index);
        jacpy_release(empty);
    }
}

def:priv decode_pickle(state: array_state, format: i64, data: u64) -> u64 {
    value: u64 = 0;
    decoded: u64 = 0;
    values: u64 = 0;
    try {
        if format < 0 or format > 21 {
            object_error(
                "ValueError", "third argument must be a valid machine format code"
            );
            return 0;
        }
        size = jacpy_bytes_length(data);
        address = jacpy_bytes_address(data);
        if format == i64(machine_format(state)) {
            return jacpy_retain(data);
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
            return 0;
        }
        little = format % 2 == 0;
        if format >= 18 {
            encoding = ("utf-16-" if format < 20 else "utf-32-")
                + ("le" if little else "be");
            decoded = required(jacpy_unicode_decode_bytes(data, encoding));
            result = decoded;
            decoded = 0;
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
                    address + u64(offset), i64(width), i64(little)
                );
                pending();
                value = required(jacpy_float(floating));
            } else {
                value = integer_from_bits(
                    read_bits(address + u64(offset), width, little), width, signed
                );
            }
            checked(jacpy_list_append(values, value));
            jacpy_release(value);
            value = 0;
            offset += i64(width);
        }
        result = values;
        values = 0;
        return result;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(value);
        jacpy_release(decoded);
        jacpy_release(values);
    }
}

def:pub jacpy_array_reconstruct_object(
    type: u64, code: i64, format: i64, data: u64
) -> u64 {
    state = array_state();
    values: u64 = 0;
    tag: u64 = 0;
    args: u64 = 0;
    try {
        checked(jacpy_array_init(state, code));
        values = required(decode_pickle(state, format, data));
        tag = text_object(chr(state.code));
        args = object_tuple([tag, values]);
        return jacpy_call(type, args, 0);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_array_clear(state);
        jacpy_release(values);
        jacpy_release(tag);
        jacpy_release(args);
    }
}
