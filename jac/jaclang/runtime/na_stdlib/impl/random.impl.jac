impl _init_genrand(s: int) {
    _MT[0] = s & 0xffffffff;
    i = 1;
    while i < _N {
        prev = _MT[i - 1];
        _MT[i] = (1812433253 * (prev ^ (prev >> 30)) + i) & 0xffffffff;
        i += 1;
    }
    _INDEX[0] = _N;
}

impl _init_by_array(key: list[int]) {
    _init_genrand(19650218);
    i = 1;
    j = 0;
    count = len(key);
    k = _N if _N > count else count;
    while k > 0 {
        prev = _MT[i - 1];
        _MT[i] = ((_MT[i] ^ ((prev ^ (prev >> 30)) * 1664525)) + key[j] + j)
            & 0xffffffff;
        i += 1;
        j += 1;
        if i >= _N {
            _MT[0] = _MT[_N - 1];
            i = 1;
        }
        if j >= count {
            j = 0;
        }
        k -= 1;
    }
    k = _N - 1;
    while k > 0 {
        prev = _MT[i - 1];
        _MT[i] = ((_MT[i] ^ ((prev ^ (prev >> 30)) * 1566083941)) - i) & 0xffffffff;
        i += 1;
        if i >= _N {
            _MT[0] = _MT[_N - 1];
            i = 1;
        }
        k -= 1;
    }
    _MT[0] = 0x80000000;
    _INDEX[0] = _N;
}

impl _ensure_seeded {
    if _INDEX[0] > _N {
        noise = csprng_bytes(8);
        value = 0;
        for byte in noise {
            value = (value << 8) | byte;
        }
        _init_by_array([value & 0xffffffff, (value >> 32) & 0xffffffff]);
    }
}

impl _genrand -> int {
    _ensure_seeded();
    if _INDEX[0] >= _N {
        kk = 0;
        while kk < _N {
            y = (_MT[kk] & 0x80000000) | (_MT[(kk + 1) % _N] & 0x7fffffff);
            nxt = _MT[(kk + _M) % _N] ^ (y >> 1);
            if y & 1 {
                nxt = nxt ^ 0x9908b0df;
            }
            _MT[kk] = nxt;
            kk += 1;
        }
        _INDEX[0] = 0;
    }
    y = _MT[_INDEX[0]];
    _INDEX[0] += 1;
    y = y ^ (y >> 11);
    y = y ^ ((y << 7) & 0x9d2c5680);
    y = y ^ ((y << 15) & 0xefc60000);
    y = y ^ (y >> 18);
    return y & 0xffffffff;
}

impl _randbelow(n: int) -> int {
    k = n.bit_length();
    r = getrandbits(k);
    while r >= n {
        r = getrandbits(k);
    }
    return r;
}

impl seed(a: (int | None) = None) {
    if a is None {
        _INDEX[0] = _N + 1;
        _ensure_seeded();
        return;
    }
    n = a if a >= 0 else -a;
    key: list[int] = [];
    while n > 0 {
        key.append(n & 0xffffffff);
        n = n >> 32;
    }
    if not key {
        key.append(0);
    }
    _init_by_array(key);
}

impl random -> float {
    a = _genrand() >> 5;
    b = _genrand() >> 6;
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
}

impl getrandbits(k: int) -> int {
    if k < 0 {
        raise ValueError("number of bits must be non-negative");
    }
    if k > 63 {
        raise OverflowError("native getrandbits takes at most 63 bits");
    }
    if k == 0 {
        return 0;
    }
    if k <= 32 {
        return _genrand() >> (32 - k);
    }
    low = _genrand();
    high = _genrand() >> (64 - k);
    return (high << 32) | low;
}

impl randrange(start: int, stop: (int | None) = None, step: int = 1) -> int {
    if stop is None {
        if step != 1 {
            raise TypeError("Missing a non-None stop argument");
        }
        if start > 0 {
            return _randbelow(start);
        }
        raise ValueError("empty range for randrange()");
    }
    width = stop - start;
    if step == 1 {
        if width > 0 {
            return start + _randbelow(width);
        }
        raise ValueError(f"empty range in randrange({start}, {stop})");
    }
    n = 0;
    if step > 0 {
        n = (width + step - 1) // step;
    } elif step < 0 {
        n = (width + step + 1) // step;
    } else {
        raise ValueError("zero step for randrange()");
    }
    if n <= 0 {
        raise ValueError(f"empty range in randrange({start}, {stop}, {step})");
    }
    return start + step * _randbelow(n);
}

impl randint(a: int, b: int) -> int {
    return randrange(a, b + 1);
}

impl uniform(a: float, b: float) -> float {
    return a + (b - a) * random();
}
