"""MT19937 state and Python Random protocol implemented in native Jac.

Derived from CPython's _randommodule and the MT2002 algorithm by Makoto
Matsumoto and Takuji Nishimura. See the Mersenne Twister notice in
../LICENSE.cpython. No host random implementation is called.
"""
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_int,
    object_error,
    jacpy_is_long,
    jacpy_long_absolute,
    jacpy_hash_unsigned,
    jacpy_long_bits,
    jacpy_long_bytes,
    jacpy_long_from_bytes,
    jacpy_unsigned_long,
    jacpy_integer_value,
    jacpy_entropy,
    jacpy_clear_error,
    jacpy_error_pending,
    jacpy_wall_time,
    jacpy_monotonic_time,
    jacpy_process_id,
    jacpy_is_tuple,
    jacpy_tuple_size,
    jacpy_tuple_new,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_buffer_size,
    jacpy_buffer_byte,
    jacpy_buffer_new,
    jacpy_buffer_set
}

import from jaclang.runtime.python.bindings.state { NativeState }

obj mt19937(NativeState) {
    has words: list[u32] = [u32(0) for i in range(624)],
        index: int = 0;

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        return i32(0);
    }

    def clear {}
}

def:pub jacpy_random_new -> mt19937 {
    return mt19937();
}

def random_word(state: mt19937) -> u32 {
    if state.index >= 624 {
        for i in range(624) {
            upper = state.words[i] & u32(0x80000000);
            lower = state.words[(i + 1) % 624] & u32(0x7fffffff);
            mixed = upper | lower;
            matrix = u32(0x9908b0df) if (mixed & u32(1)) != u32(0) else u32(0);
            state.words[i] = state.words[(i + 397) % 624] ^ (mixed >> u32(1)) ^ matrix;
        }
        state.index = 0;
    }
    value = state.words[state.index];
    state.index += 1;
    value ^= value >> u32(11);
    value ^= wrapping_shl(value, 7) & u32(0x9d2c5680);
    value ^= wrapping_shl(value, 15) & u32(0xefc60000);
    value ^= value >> u32(18);
    return value;
}

def random_seed_words(state: mt19937, keys: list[u32]) {
    state.words[0] = u32(19650218);
    for i in range(1, 624) {
        previous = state.words[i - 1];
        mixed = previous ^ (previous >> u32(30));
        state.words[i] = wrapping_add(wrapping_mul(u32(1812433253), mixed), u32(i));
    }
    i = 1;
    j = 0;
    for remaining in range(max(624, len(keys))) {
        previous = state.words[i - 1];
        mixed = previous ^ (previous >> u32(30));
        value = state.words[i] ^ wrapping_mul(mixed, u32(1664525));
        state.words[i] = wrapping_add(wrapping_add(value, keys[j]), u32(j));
        i += 1;
        j += 1;
        if i >= 624 {
            state.words[0] = state.words[623];
            i = 1;
        }
        if j >= len(keys) {
            j = 0;
        }
    }
    for remaining in range(623) {
        previous = state.words[i - 1];
        mixed = previous ^ (previous >> u32(30));
        value = state.words[i] ^ wrapping_mul(mixed, u32(1566083941));
        state.words[i] = wrapping_sub(value, u32(i));
        i += 1;
        if i >= 624 {
            state.words[0] = state.words[623];
            i = 1;
        }
    }
    state.words[0] = u32(0x80000000);
    state.index = 624;
}

def random_seed_buffer(state: mt19937, data: u64) {
    keys: list[u32] = [];
    count = int(jacpy_buffer_size(data) // 4);
    for i in range(count) {
        value = u32(0);
        for byte in range(4) {
            value |= u32(jacpy_buffer_byte(data, i64(i * 4 + byte))) << u32(byte * 8);
        }
        keys.append(value);
    }
    random_seed_words(state, keys);
}

def:pub jacpy_random_seed(state: mt19937, argument: u64) -> i64 {
    if argument == 0 {
        entropy = jacpy_entropy(2496);
        if entropy != 0 {
            random_seed_buffer(state, entropy);
            jacpy_release(entropy);
            return 0;
        }
        jacpy_clear_error();
        now = jacpy_wall_time();
        if jacpy_error_pending() != 0 {
            return -1;
        }
        monotonic = jacpy_monotonic_time();
        if jacpy_error_pending() != 0 {
            return -1;
        }
        random_seed_words(
            state,
            [
                u32.wrap(now),
                u32(u64(now) >> u64(32)),
                u32(jacpy_process_id()),
                u32.wrap(monotonic),
                u32(u64(monotonic) >> u64(32))
            ]
        );
        return 0;
    }
    number = jacpy_long_absolute(argument)
        if jacpy_is_long(argument) != 0
        else jacpy_hash_unsigned(argument);
    if number == 0 {
        return -1;
    }
    bits = jacpy_long_bits(number);
    size = max(i64(1), (bits + 31) // 32) * 4;
    data = jacpy_long_bytes(number, size);
    jacpy_release(number);
    if data == 0 {
        return -1;
    }
    random_seed_buffer(state, data);
    jacpy_release(data);
    return 0;
}

def:pub jacpy_random_float(state: mt19937) -> f64 {
    a = random_word(state) >> u32(5);
    b = random_word(state) >> u32(6);
    return (f64(a) * f64(67108864.0) + f64(b)) * f64(1.0 / 9007199254740992.0);
}

def:pub jacpy_random_getstate(state: mt19937) -> u64 {
    result = jacpy_tuple_new(625);
    if result == 0 {
        return 0;
    }
    for i in range(624) {
        if jacpy_tuple_set_owned(result, i64(i), jacpy_int(i64(state.words[i]))) < 0 {
            jacpy_release(result);
            return 0;
        }
    }
    if jacpy_tuple_set_owned(result, 624, jacpy_int(i64(state.index))) < 0 {
        jacpy_release(result);
        return 0;
    }
    return result;
}

def:pub jacpy_random_setstate(state: mt19937, value: u64) -> i64 {
    if jacpy_is_tuple(value) == 0 {
        object_error("TypeError", "state vector must be a tuple");
        return -1;
    }
    if jacpy_tuple_size(value) != 625 {
        object_error("ValueError", "state vector is the wrong size");
        return -1;
    }
    words: list[u32] = [];
    for i in range(624) {
        item = jacpy_tuple_item(value, i64(i));
        if item == 0 {
            return -1;
        }
        word = jacpy_unsigned_long(item);
        jacpy_release(item);
        if jacpy_error_pending() != 0 {
            return -1;
        }
        words.append(u32.wrap(word));
    }
    item = jacpy_tuple_item(value, 624);
    if item == 0 {
        return -1;
    }
    index = jacpy_integer_value(item);
    jacpy_release(item);
    if jacpy_error_pending() != 0 {
        return -1;
    }
    if index < 0 or index > 624 {
        object_error("ValueError", "invalid state");
        return -1;
    }
    state.words = words;
    state.index = int(index);
    return 0;
}

def:pub jacpy_random_bits(state: mt19937, bits: u64) -> u64 {
    if bits == 0 {
        return jacpy_int(0);
    }
    if bits <= 32 {
        return jacpy_int(i64(random_word(state) >> u32(32 - bits)));
    }
    count = (bits - 1) // 32 + 1;
    if count > u64(0x7fffffffffffffff) // 4 {
        object_error("MemoryError", "");
        return 0;
    }
    data = jacpy_buffer_new(i64(count * 4));
    if data == 0 {
        return 0;
    }
    for i in range(int(count)) {
        word = random_word(state);
        if bits < 32 {
            word >>= u32(32 - bits);
        }
        for byte in range(4) {
            jacpy_buffer_set(
                data, i64(i * 4 + byte), i64((word >> u32(byte * 8)) & u32(255))
            );
        }
        if bits > 32 {
            bits -= 32;
        }
    }
    result = jacpy_long_from_bytes(data);
    jacpy_release(data);
    return result;
}
