"""MT19937 state and Python Random protocol implemented in native Jac.

Derived from Python's _randommodule and the MT2002 algorithm by Makoto
Matsumoto and Takuji Nishimura. See the Mersenne Twister notice in
../LICENSE.cpython. No host random implementation is called.
"""

glob RANDOM_RECORD_SIZE: Final[int] = 2504,
     MT_N: Final[i64] = 624,
     MT_M: Final[i64] = 397;

glob Random_token = ClassToken();

glob:priv random_record_offset: i64 = 0;

def:priv mt_index(record: ptr[u8]) -> ptr[i64] {
    return ptr[i64](record);
}

def:priv mt_words(record: ptr[u8]) -> ptr[u32] {
    return ptr[u32](record + 8);
}

def:priv mt_mix(upper: u32, lower: u32, far: u32) -> u32 {
    y = (upper & u32(0x80000000)) | (lower & u32(0x7fffffff));
    matrix = u32(0x9908b0df) if (y & u32(1)) != u32(0) else u32(0);
    return far ^ (y >> u32(1)) ^ matrix;
}

def:priv mt_refill(mt: ptr[u32]) {
    kk: i64 = 0;
    while kk < MT_N - MT_M {
        (mt + kk).view(1)[0] = mt_mix(
            (mt + kk).view(1)[0], (mt + kk + 1).view(1)[0], (mt + kk + MT_M).view(1)[0]
        );
        kk += 1;
    }
    while kk < MT_N - 1 {
        (mt + kk).view(1)[0] = mt_mix(
            (mt + kk).view(1)[0],
            (mt + kk + 1).view(1)[0],
            (mt + kk + MT_M - MT_N).view(1)[0]
        );
        kk += 1;
    }
    (mt + MT_N - 1).view(1)[0] = mt_mix(
        (mt + MT_N - 1).view(1)[0], mt.view(1)[0], (mt + MT_M - 1).view(1)[0]
    );
}

def random_word(record: ptr[u8]) -> u32 {
    mt = mt_words(record);
    index = mt_index(record);
    i = index.view(1)[0];
    if i >= MT_N {
        mt_refill(mt);
        i = 0;
    }
    value = (mt + i).view(1)[0];
    index.view(1)[0] = i + 1;
    value ^= value >> u32(11);
    value ^= wrapping_shl(value, 7) & u32(0x9d2c5680);
    value ^= wrapping_shl(value, 15) & u32(0xefc60000);
    value ^= value >> u32(18);
    return value;
}

def random_seed_words(record: ptr[u8], keys: list[u32]) {
    mt = mt_words(record);
    mt.view(1)[0] = u32(19650218);
    for i in range(1, 624) {
        previous = (mt + (i - 1)).view(1)[0];
        mixed = previous ^ (previous >> u32(30));
        (mt + i).view(1)[0] = wrapping_add(
            wrapping_mul(u32(1812433253), mixed), u32(i)
        );
    }
    i = 1;
    j = 0;
    for remaining in range(max(624, len(keys))) {
        previous = (mt + (i - 1)).view(1)[0];
        mixed = previous ^ (previous >> u32(30));
        value = (mt + i).view(1)[0] ^ wrapping_mul(mixed, u32(1664525));
        (mt + i).view(1)[0] = wrapping_add(wrapping_add(value, keys[j]), u32(j));
        i += 1;
        j += 1;
        if i >= 624 {
            mt.view(1)[0] = (mt + 623).view(1)[0];
            i = 1;
        }
        if j >= len(keys) {
            j = 0;
        }
    }
    for remaining in range(623) {
        previous = (mt + (i - 1)).view(1)[0];
        mixed = previous ^ (previous >> u32(30));
        value = (mt + i).view(1)[0] ^ wrapping_mul(mixed, u32(1566083941));
        (mt + i).view(1)[0] = wrapping_sub(value, u32(i));
        i += 1;
        if i >= 624 {
            mt.view(1)[0] = (mt + 623).view(1)[0];
            i = 1;
        }
    }
    mt.view(1)[0] = u32(0x80000000);
    mt_index(record).view(1)[0] = MT_N;
}

def random_seed_buffer(record: ptr[u8], data: ptr[PyObject]) {
    keys: list[u32] = [];
    count = int(jacpy_buffer_size(data) // 4);
    for i in range(count) {
        value = u32(0);
        for byte in range(4) {
            value |= u32(jacpy_buffer_byte(data, i64(i * 4 + byte))) << u32(byte * 8);
        }
        keys.append(value);
    }
    random_seed_words(record, keys);
}

def:pub jacpy_random_seed(record: ptr[u8], argument: ptr[PyObject]) -> i64 {
    if argument == 0 {
        entropy = jacpy_entropy(2496);
        if entropy != 0 {
            random_seed_buffer(record, entropy);
            jacpy_release(entropy);
            return 0;
        }
        PyErr_Clear();
        now = jacpy_wall_time();
        if jacpy_error_pending() != 0 {
            return -1;
        }
        monotonic = jacpy_monotonic_time();
        if jacpy_error_pending() != 0 {
            return -1;
        }
        random_seed_words(
            record,
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
    bits = _PyLong_NumBits(number);
    size = max(i64(1), (bits + 31) // 32) * 4;
    data = jacpy_long_bytes(number, size);
    jacpy_release(number);
    if data == 0 {
        return -1;
    }
    random_seed_buffer(record, data);
    jacpy_release(data);
    return 0;
}

def:pub jacpy_random_float(record: ptr[u8]) -> f64 {
    a = random_word(record) >> u32(5);
    b = random_word(record) >> u32(6);
    return (f64(a) * f64(67108864.0) + f64(b)) * f64(1.0 / 9007199254740992.0);
}

def:pub jacpy_random_getstate(record: ptr[u8]) -> ptr[PyObject] {
    result = PyTuple_New(625);
    if result == 0 {
        return NULL;
    }
    mt = mt_words(record);
    for i in range(624) {
        if jacpy_tuple_set_owned(
            result, i64(i), PyLong_FromLongLong(i64((mt + i).view(1)[0]))
        )
            < 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    if jacpy_tuple_set_owned(
        result, 624, PyLong_FromLongLong(mt_index(record).view(1)[0])
    )
        < 0 {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def:pub jacpy_random_setstate(record: ptr[u8], value: ptr[PyObject]) -> i64 {
    if jacpy_is_tuple(value) == 0 {
        object_error(PyExc_TypeError, "state vector must be a tuple");
        return -1;
    }
    if PyTuple_Size(value) != 625 {
        object_error(PyExc_ValueError, "state vector is the wrong size");
        return -1;
    }
    words: list[u32] = [];
    for i in range(624) {
        item = jacpy_tuple_item(value, i64(i));
        if item == 0 {
            return -1;
        }
        word = PyLong_AsUnsignedLong(item);
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
    index = PyLong_AsLongLong(item);
    jacpy_release(item);
    if jacpy_error_pending() != 0 {
        return -1;
    }
    if index < 0 or index > 624 {
        object_error(PyExc_ValueError, "invalid state");
        return -1;
    }
    mt = mt_words(record);
    for i in range(624) {
        (mt + i).view(1)[0] = words[i];
    }
    mt_index(record).view(1)[0] = index;
    return 0;
}

def:pub jacpy_random_bits(record: ptr[u8], bits: u64) -> ptr[PyObject] {
    if bits == 0 {
        return PyLong_FromLongLong(0);
    }
    if bits <= 32 {
        return PyLong_FromLongLong(i64(random_word(record) >> u32(32 - bits)));
    }
    count = (bits - 1) // 32 + 1;
    if count > u64(0x7fffffffffffffff) // 4 {
        object_error(PyExc_MemoryError, "");
        return NULL;
    }
    words = ptr[u32](PyMem_Malloc(count * u64(4)));
    if not words {
        return PyErr_NoMemory();
    }
    i: i64 = 0;
    while i < i64(count) {
        word = random_word(record);
        if bits < 32 {
            word >>= u32(32 - bits);
        }
        (words + i).view(1)[0] = word;
        if bits > 32 {
            bits -= 32;
        }
        i += 1;
    }
    result = _PyLong_FromByteArray(ptr[u8](words), count * u64(4), 1, 0);
    PyMem_Free(ptr(words));
    return result;
}

def:priv random_state(instance: ptr[PyObject]) -> ptr[u8] {
    offset = random_record_offset;
    if offset != 0 {
        return ptr[u8](instance) + offset;
    }
    record = ptr[u8](jacpy_binding_record(instance, Random_token.handle));
    if not record {
        object_error(PyExc_SystemError, "native Random state is unavailable");
        return record;
    }
    random_record_offset = int(record) - int(instance);
    return record;
}

def:priv seeded(instance: ptr[PyObject], seed: ptr[PyObject]) -> i64 {
    record = random_state(instance);
    if not record {
        return -1;
    }
    return jacpy_random_seed(record, NULL if seed == Py_None else seed);
}

def _random_Random_random_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    record = random_state(instance);
    if not record {
        return NULL;
    }
    return PyFloat_FromDouble(jacpy_random_float(record));
}

def _random_Random_seed_impl(
    instance: ptr[PyObject], n: ptr[PyObject]
) -> ptr[PyObject] {
    if seeded(instance, n) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def _random_Random_getstate_impl(instance: ptr[PyObject]) -> ptr[PyObject] {
    record = random_state(instance);
    if not record {
        return NULL;
    }
    return jacpy_random_getstate(record);
}

def _random_Random_setstate_impl(
    instance: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject] {
    record = random_state(instance);
    if not record or jacpy_random_setstate(record, state) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def _random_Random_getrandbits_impl(instance: ptr[PyObject], k: u64) -> ptr[PyObject] {
    record = random_state(instance);
    if not record {
        return NULL;
    }
    return jacpy_random_bits(record, k);
}

def random_init_impl(instance: ptr[PyObject], seed: ptr[PyObject]) -> i32 {
    return i32(seeded(instance, NULL if seed == 0 else seed));
}
