# P3.2a — CPython hash algorithms (``Py_HashBuffer`` / ``_Py_HashDouble``).
#
# SipHash13 + float reduction are pure Jac. SipHash keys are process-local:
# honor ``PYTHONHASHSEED`` (CPython LCG / zero / random) via ``os.urandom``,
# without reading the embedding interpreter's ``_Py_HashSecret``.
#
# Leaf module: no ``objects`` import (keeps secret probes free of OSP/ceval).
import os;

glob _U64: int = 0xFFFFFFFFFFFFFFFF,
     _PyHASH_MODULUS: int = 2305843009213693951,
     _PyHASH_BITS: int = 61,
     _PyHASH_INF: int = 314159,
     _MAX_HASH_SEED: int = 4294967295;


def _u64(x: int) -> int {
    return int(x) & _U64;
}

def _pyhash_t(x: int) -> int {
    x = _u64(x);
    if x >= 0x8000000000000000 {
        return x - 0x10000000000000000;
    }
    return x;
}

def _rotl64(x: int, b: int) -> int {
    x = _u64(x);
    return _u64((x << b) | (x >> (64 - b)));
}

def _half_round(a: int, b: int, c: int, d: int, s: int, t: int) -> tuple[int, int, int, int] {
    a = _u64(a + b);
    c = _u64(c + d);
    b = _u64(_rotl64(b, s) ^ a);
    d = _u64(_rotl64(d, t) ^ c);
    a = _rotl64(a, 32);
    return (a, b, c, d);
}

def _single_round(v0: int, v1: int, v2: int, v3: int) -> tuple[int, int, int, int] {
    (v0, v1, v2, v3) = _half_round(v0, v1, v2, v3, 13, 16);
    (v2, v1, v0, v3) = _half_round(v2, v1, v0, v3, 17, 21);
    return (v0, v1, v2, v3);
}

def _le64_from_bytes(data: list[int], off: int) -> int {
    x = 0;
    j = 0;
    while j < 8 {
        x = x | (data[off + j] << (8 * j));
        j = j + 1;
    }
    return _u64(x);
}

def _le64_from_tail(data: list[int], off: int, rem: int) -> int {
    x = 0;
    j = 0;
    while j < rem {
        x = x | (data[off + j] << (8 * j));
        j = j + 1;
    }
    return _u64(x);
}

# CPython ``lcg_urandom`` (``Python/bootstrap_hash.c``) — fill ``size`` bytes.
def _lcg_urandom(seed: int, size: int) -> list[int] {
    x = seed & 0xFFFFFFFF;
    out: list[int] = [];
    i = 0;
    while i < size {
        x = (x * 214013 + 2531011) & 0xFFFFFFFF;
        out.append((x >> 16) & 0xFF);
        i = i + 1;
    }
    return out;
}

# SipHash keys from a numeric ``PYTHONHASHSEED`` (0 → all-zero secret).
def hash_secret_keys_from_seed(seed: int) -> tuple[int, int] {
    if seed == 0 {
        return (0, 0);
    }
    uc = _lcg_urandom(seed, 24);
    return (_le64_from_bytes(uc, 0), _le64_from_bytes(uc, 8));
}

def _hash_secret_keys_random -> tuple[int, int] {
    raw = os.urandom(24);
    uc: list[int] = [];
    for b in raw {
        uc.append(b);
    }
    return (_le64_from_bytes(uc, 0), _le64_from_bytes(uc, 8));
}

# Mirror ``config_init_hash_seed`` + ``_Py_HashRandomization_Init``.
def _jac_siphash_keys -> tuple[int, int] {
    seed_text = os.environ.get("PYTHONHASHSEED");
    if seed_text is None or seed_text == "random" {
        return _hash_secret_keys_random();
    }
    try {
        seed = int(seed_text);
    } except ValueError {
        raise ValueError(
            "PYTHONHASHSEED must be \"random\" "
            + "or an integer in range [0; 4294967295]"
        );
    }
    if seed < 0 or seed > _MAX_HASH_SEED {
        raise ValueError(
            "PYTHONHASHSEED must be \"random\" "
            + "or an integer in range [0; 4294967295]"
        );
    }
    return hash_secret_keys_from_seed(seed);
}

# Single bootstrap call — random mode must not draw two independent secrets.
glob _SIPHASH_KEYS: tuple[int, int] = _jac_siphash_keys(),
     _SIPHASH_K0: int = (_SIPHASH_KEYS[0] as int),
     _SIPHASH_K1: int = (_SIPHASH_KEYS[1] as int);


def _siphash13(k0: int, k1: int, data: list[int]) -> int {
    src_sz = len(data);
    b = _u64(src_sz << 56);
    off = 0;
    remain = src_sz;
    v0 = _u64(k0 ^ 0x736F6D6570736575);
    v1 = _u64(k1 ^ 0x646F72616E646F6D);
    v2 = _u64(k0 ^ 0x6C7967656E657261);
    v3 = _u64(k1 ^ 0x7465646279746573);
    while remain >= 8 {
        mi = _le64_from_bytes(data, off);
        off = off + 8;
        remain = remain - 8;
        v3 = _u64(v3 ^ mi);
        (v0, v1, v2, v3) = _single_round(v0, v1, v2, v3);
        v0 = _u64(v0 ^ mi);
    }
    t = _le64_from_tail(data, off, remain);
    b = _u64(b | t);
    v3 = _u64(v3 ^ b);
    (v0, v1, v2, v3) = _single_round(v0, v1, v2, v3);
    v0 = _u64(v0 ^ b);
    v2 = _u64(v2 ^ 0xFF);
    (v0, v1, v2, v3) = _single_round(v0, v1, v2, v3);
    (v0, v1, v2, v3) = _single_round(v0, v1, v2, v3);
    (v0, v1, v2, v3) = _single_round(v0, v1, v2, v3);
    return _pyhash_t(_u64((v0 ^ v1) ^ (v2 ^ v3)));
}

def _unicode_max_ord(s: str) -> int {
    m = 0;
    for c in s {
        o = ord(c);
        if o > m {
            m = o;
        }
    }
    return m;
}

def _unicode_utf16le_bytes(s: str) -> list[int] {
    out: list[int] = [];
    for c in s {
        cp = ord(c);
        out.append(cp & 0xFF);
        out.append((cp >> 8) & 0xFF);
    }
    return out;
}

def _unicode_utf32le_bytes(s: str) -> list[int] {
    out: list[int] = [];
    for c in s {
        cp = ord(c);
        out.append(cp & 0xFF);
        out.append((cp >> 8) & 0xFF);
        out.append((cp >> 16) & 0xFF);
        out.append((cp >> 24) & 0xFF);
    }
    return out;
}

def _unicode_hash_payload(s: str) -> list[int] {
    if len(s) == 0 {
        return [];
    }
    m = _unicode_max_ord(s);
    if m < 256 {
        out: list[int] = [];
        for c in s {
            out.append(ord(c));
        }
        return out;
    }
    if m <= 0xFFFF {
        return _unicode_utf16le_bytes(s);
    }
    return _unicode_utf32le_bytes(s);
}

def _hash_buffer(data: list[int]) -> int {
    if len(data) == 0 {
        return 0;
    }
    x = _siphash13(_SIPHASH_K0, _SIPHASH_K1, data);
    if x == -1 {
        return -2;
    }
    return x;
}

def _hash_pointer(ptr: int) -> int {
    x = _u64(ptr);
    x = _u64((x >> 4) | (x << 60));
    if x == -1 {
        return -2;
    }
    return x;
}

def _frexp(v: float) -> tuple[float, int] {
    if v == 0.0 {
        return (0.0, 0);
    }
    e = 0;
    m = v;
    av = m;
    if av < 0.0 {
        av = -av;
    }
    if av >= 1.0 {
        while av >= 1.0 {
            av = av * 0.5;
            e = e + 1;
        }
    } elif av < 0.5 {
        while av < 0.5 {
            av = av * 2.0;
            e = e - 1;
        }
    }
    if m < 0.0 {
        m = -av;
    } else {
        m = av;
    }
    return (m, e);
}

def _hash_double(v: float) -> int {
    if v != v {
        return 0;
    }
    if v * 0.0 != 0.0 {
        if v > 0.0 {
            return _PyHASH_INF;
        }
        return -_PyHASH_INF;
    }
    (m, e) = _frexp(v);
    sign = 1;
    if m < 0.0 {
        sign = -1;
        m = -m;
    }
    x = 0;
    while m != 0.0 {
        x = ((x << 28) & _PyHASH_MODULUS) | (x >> (_PyHASH_BITS - 28));
        m = m * 268435456.0;
        e = e - 28;
        y = int(m);
        m = m - float(y);
        x = x + y;
        if x >= _PyHASH_MODULUS {
            x = x - _PyHASH_MODULUS;
        }
    }
    if e >= 0 {
        e = e % _PyHASH_BITS;
    } else {
        e = _PyHASH_BITS - 1 - ((-1 - e) % _PyHASH_BITS);
    }
    x = ((x << e) & _PyHASH_MODULUS) | (x >> (_PyHASH_BITS - e));
    x = x * sign;
    if x == -1 {
        return -2;
    }
    return x;
}

def str_hash_text(s: str) -> int {
    return _hash_buffer(_unicode_hash_payload(s));
}

# ``Py_HashBuffer`` on raw byte values (``bytes_hash`` / ``bytearray`` lane).
def bytes_hash_data(data: list[int]) -> int {
    return _hash_buffer(data);
}

def float_hash_value(val: float, obj_id: int) -> int {
    if val != val {
        return _hash_pointer(obj_id);
    }
    return _hash_double(val);
}
