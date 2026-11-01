import from c {
    def frexp(value: f64, exponent: &mut i32) -> f64;  obj PyHashFuncDef {
        has hash: Callable[[ptr, i64], i64],
            name: ptr[u8],
            hash_bits: i32,
            seed_bits: i32;
    }  glob _Py_HashSecret: _Py_HashSecret_t = _Py_HashSecret_t(
             expat_hashsalt16_head=u64(0),
             expat_hashsalt16_tail=u64(0),
             expat_hashsalt=0
         ); glob:priv PyHash_Func: PyHashFuncDef = PyHashFuncDef(
             hash=pysiphash, name=ptr[u8]("siphash13"), hash_bits=64, seed_bits=128
         );
}

glob:priv PyHASH_BITS: Final[i32] = 61,
     PyHASH_MODULUS: Final[u64] = u64(0x1FFFFFFFFFFFFFFF),
     PyHASH_INF: Final[i64] = 314159;

def load_le64(p: ptr[u8]) -> u64;

def rotate(x: u64, b: u64) -> u64;

def siphash13(k0: u64, k1: u64, src: ptr[u8], src_sz: i64) -> u64;

def single_round(v0: u64, v1: u64, v2: u64, v3: u64) -> tuple[u64, u64, u64, u64];

def pysiphash(src: ptr, src_sz: i64) -> i64;

def hash_pointer_raw(p: ptr) -> i64;

import from c {
    def _Py_HashDouble(inst: ptr[PyObject], v: f64) -> i64 {
        if not is_finite(v) {
            if is_inf(v) {
                return PyHASH_INF if v > 0.0 else -PyHASH_INF;
            }
            return PyObject_GenericHash(inst);
        }

        e: i32 = 0;
        m = frexp(v, &mut e);

        sign = u64(1);
        if m < 0.0 {
            sign = u64.wrap(-1);
            m = -m;
        }

        x = u64(0);
        while m != 0.0 {
            x = (wrapping_shl(x, u64(28)) & PyHASH_MODULUS)
                | (x >> u64(PyHASH_BITS - 28));
            m *= 268435456.0;

            e -= 28;
            y = u64(m);

            m -= f64(y);
            x += y;
            if x >= PyHASH_MODULUS {
                x -= PyHASH_MODULUS;
            }
        }

        if e >= 0 {
            e = e % PyHASH_BITS;
        } else {
            e = PyHASH_BITS - 1 - ((-1 - e) % PyHASH_BITS);
        }
        x = (wrapping_shl(x, u64(e)) & PyHASH_MODULUS) | (x >> u64(PyHASH_BITS - e));

        x = wrapping_mul(x, sign);
        if x == u64.wrap(-1) {
            x = u64.wrap(-2);
        }
        return i64.wrap(x);
    }  def Py_HashPointer(p: ptr) -> i64 {
        hash = hash_pointer_raw(p);
        if hash == -1 {
            hash = -2;
        }
        return hash;
    }  def PyObject_GenericHash(arg0: ptr[PyObject]) -> i64 {
        return Py_HashPointer(ptr(arg0));
    }  def Py_HashBuffer(ptr_: ptr, len_: i64) -> i64 {
        if len_ == 0 {
            return 0;
        }
        x = pysiphash(ptr_, len_);
        if x == -1 {
            return -2;
        }
        return x;
    }  def _PyHash_Fini {
        return;
    }  def PyHash_GetFuncDef -> ptr {
        return ptr(addressof(PyHash_Func));
    }  def _Py_KeyedHash(key: u64, src: ptr, src_sz: i64) -> u64 {
        return siphash13(key, u64(0), ptr[u8](src), src_sz);
    }
}

impl load_le64(p: ptr[u8]) -> u64 {
    return u64(p.view(8)[0])
        | wrapping_shl(u64(p.view(8)[1]), u64(8))
        | wrapping_shl(u64(p.view(8)[2]), u64(16))
        | wrapping_shl(u64(p.view(8)[3]), u64(24))
        | wrapping_shl(u64(p.view(8)[4]), u64(32))
        | wrapping_shl(u64(p.view(8)[5]), u64(40))
        | wrapping_shl(u64(p.view(8)[6]), u64(48))
        | wrapping_shl(u64(p.view(8)[7]), u64(56));
}

impl rotate(x: u64, b: u64) -> u64 {
    return wrapping_shl(x, b) | (x >> (u64(64) - b));
}

impl siphash13(k0: u64, k1: u64, src: ptr[u8], src_sz: i64) -> u64 {
    b = wrapping_shl(u64.wrap(src_sz), u64(56));
    in_ = src;
    remaining = src_sz;

    v0 = k0 ^ u64(0x736f6d6570736575);
    v1 = k1 ^ u64(0x646f72616e646f6d);
    v2 = k0 ^ u64(0x6c7967656e657261);
    v3 = k1 ^ u64(0x7465646279746573);

    while remaining >= 8 {
        mi = load_le64(in_);
        in_ = in_ + 8;
        remaining -= 8;
        v3 ^= mi;
        (v0, v1, v2, v3) = single_round(v0, v1, v2, v3);
        v0 ^= mi;
    }

    t = u64(0);
    i: i64 = 0;
    while i < remaining {
        t = t | wrapping_shl(u64(in_.view(8)[i]), u64(8 * i));
        i += 1;
    }
    b = b | t;

    v3 ^= b;
    (v0, v1, v2, v3) = single_round(v0, v1, v2, v3);
    v0 ^= b;
    v2 ^= u64(0xff);
    (v0, v1, v2, v3) = single_round(v0, v1, v2, v3);
    (v0, v1, v2, v3) = single_round(v0, v1, v2, v3);
    (v0, v1, v2, v3) = single_round(v0, v1, v2, v3);

    return (v0 ^ v1) ^ (v2 ^ v3);
}

impl single_round(v0: u64, v1: u64, v2: u64, v3: u64) -> tuple[u64, u64, u64, u64] {
    a0 = wrapping_add(v0, v1);
    a2 = wrapping_add(v2, v3);
    a1 = rotate(v1, u64(13)) ^ a0;
    a3 = rotate(v3, u64(16)) ^ a2;
    a0 = rotate(a0, u64(32));
    a2 = wrapping_add(a2, a1);
    a0 = wrapping_add(a0, a3);
    a1 = rotate(a1, u64(17)) ^ a2;
    a3 = rotate(a3, u64(21)) ^ a0;
    a2 = rotate(a2, u64(32));
    return (a0, a1, a2, a3);
}

impl pysiphash(src: ptr, src_sz: i64) -> i64 {
    secret = ptr[u64](addressof(_Py_HashSecret));
    return i64.wrap(
        siphash13(secret.view(2)[0], secret.view(2)[1], ptr[u8](src), src_sz)
    );
}

impl hash_pointer_raw(p: ptr) -> i64 {
    x = u64.wrap(int(p));
    return i64.wrap((x >> u64(4)) | wrapping_shl(x, u64(60)));
}
