impl DigestCore.update(data: bytes) {
    self.absorb(__bytes_data(data), len(data));
}

impl DigestCore.absorb(address: int, size: int) {
    bs: int = self.block_size;
    base: int = __bytearray_data(self.pending);
    i: int = 0;
    while i < size {
        if self.used == bs {
            self.compressed += bs;
            self.compress(base, False);
            self.used = 0;
        }
        if self.used == 0 {
            while size - i > bs {
                self.compressed += bs;
                self.compress(address + i, False);
                i += bs;
            }
        }
        take: int = bs - self.used;
        if size - i < take {
            take = size - i;
        }
        _copy(base + self.used, address + i, take);
        self.used += take;
        i += take;
    }
}

impl DigestCore.compress(address: int, last: bool) {}

impl DigestCore.finish -> bytes {
    return b"";
}

impl DigestCore.squeeze(size: int) -> bytes {
    return self.finish();
}

impl DigestCore.clone -> DigestCore {
    return self.carry(DigestCore());
}

impl DigestCore.carry(copy: DigestCore) -> DigestCore {
    copy.name = self.name;
    copy.block_size = self.block_size;
    copy.digest_size = self.digest_size;
    copy.pending = bytearray(self.pending);
    copy.used = self.used;
    copy.compressed = self.compressed;
    return copy;
}

impl DigestCore.pad_md(big: bool, length_bytes: int) {
    bs: int = self.block_size;
    base: int = __bytearray_data(self.pending);
    bits: int = (self.compressed + self.used) * 8;
    if self.used == bs {
        self.compress(base, False);
        self.used = 0;
    }
    self.pending[self.used] = 0x80;
    self.used += 1;
    if self.used > bs - length_bytes {
        _zero(base + self.used, bs - self.used);
        self.compress(base, False);
        self.used = 0;
    }
    _zero(base + self.used, bs - self.used);
    k: int = 0;
    while k < 8 {
        self.pending[bs - 1 - k if big else bs - 8 + k] = (bits >> (8 * k)) & 255;
        k += 1;
    }
    self.compress(base, False);
}

impl Md5Core.compress(address: int, last: bool) {
    a: u32 = self.h[0];
    b: u32 = self.h[1];
    c: u32 = self.h[2];
    d: u32 = self.h[3];
    t: u32 = u32(0);
    i: int = 0;
    while i < 16 {
        t = _md5_step(a, b, (b & c) | (~b & d), i, address, i);
        (a, d, c, b) = (d, c, b, t);
        i += 1;
    }
    while i < 32 {
        t = _md5_step(a, b, (d & b) | (~d & c), i, address, (5 * i + 1) & 15);
        (a, d, c, b) = (d, c, b, t);
        i += 1;
    }
    while i < 48 {
        t = _md5_step(a, b, b ^ c ^ d, i, address, (3 * i + 5) & 15);
        (a, d, c, b) = (d, c, b, t);
        i += 1;
    }
    while i < 64 {
        t = _md5_step(a, b, c ^ (b | ~d), i, address, (7 * i) & 15);
        (a, d, c, b) = (d, c, b, t);
        i += 1;
    }
    self.h[0] = wrapping_add(self.h[0], a);
    self.h[1] = wrapping_add(self.h[1], b);
    self.h[2] = wrapping_add(self.h[2], c);
    self.h[3] = wrapping_add(self.h[3], d);
}

impl Md5Core.finish -> bytes {
    t = Md5Core(h=list(self.h));
    self.carry(t);
    t.pad_md(False, 8);
    return _words32(t.h, 16, False);
}

impl Md5Core.clone -> DigestCore {
    return self.carry(Md5Core(h=list(self.h)));
}

impl Sha1Core.compress(address: int, last: bool) {
    w: list[u32] = self.w;
    j: int = 0;
    while j < 16 {
        w[j] = _be32(address + 4 * j);
        j += 1;
    }
    while j < 80 {
        w[j] = _rotl32(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], u32(1));
        j += 1;
    }
    a: u32 = self.h[0];
    b: u32 = self.h[1];
    c: u32 = self.h[2];
    d: u32 = self.h[3];
    e: u32 = self.h[4];
    i: int = 0;
    while i < 80 {
        f: u32 = u32(0);
        k: u32 = u32(0);
        if i < 20 {
            f = (b & c) | (~b & d);
            k = u32(0x5A827999);
        } elif i < 40 {
            f = b ^ c ^ d;
            k = u32(0x6ED9EBA1);
        } elif i < 60 {
            f = (b & c) | (b & d) | (c & d);
            k = u32(0x8F1BBCDC);
        } else {
            f = b ^ c ^ d;
            k = u32(0xCA62C1D6);
        }
        t: u32 = wrapping_add(
            wrapping_add(_rotl32(a, u32(5)), f), wrapping_add(wrapping_add(e, k), w[i])
        );
        e = d;
        d = c;
        c = _rotl32(b, u32(30));
        b = a;
        a = t;
        i += 1;
    }
    self.h[0] = wrapping_add(self.h[0], a);
    self.h[1] = wrapping_add(self.h[1], b);
    self.h[2] = wrapping_add(self.h[2], c);
    self.h[3] = wrapping_add(self.h[3], d);
    self.h[4] = wrapping_add(self.h[4], e);
}

impl Sha1Core.finish -> bytes {
    t = Sha1Core(h=list(self.h), w=self.w);
    self.carry(t);
    t.pad_md(True, 8);
    return _words32(t.h, 20, True);
}

impl Sha1Core.clone -> DigestCore {
    return self.carry(Sha1Core(h=list(self.h), w=[u32(0)] * 80));
}

impl Sha256Core.compress(address: int, last: bool) {
    w: list[u32] = self.w;
    j: int = 0;
    while j < 16 {
        w[j] = _be32(address + 4 * j);
        j += 1;
    }
    while j < 64 {
        x: u32 = w[j - 15];
        y: u32 = w[j - 2];
        s0: u32 = _rotr32(x, u32(7)) ^ _rotr32(x, u32(18)) ^ (x >> u32(3));
        s1: u32 = _rotr32(y, u32(17)) ^ _rotr32(y, u32(19)) ^ (y >> u32(10));
        w[j] = wrapping_add(wrapping_add(w[j - 16], s0), wrapping_add(w[j - 7], s1));
        j += 1;
    }
    a: u32 = self.h[0];
    b: u32 = self.h[1];
    c: u32 = self.h[2];
    d: u32 = self.h[3];
    e: u32 = self.h[4];
    f: u32 = self.h[5];
    g: u32 = self.h[6];
    h: u32 = self.h[7];
    i: int = 0;
    while i < 64 {
        s1: u32 = _rotr32(e, u32(6)) ^ _rotr32(e, u32(11)) ^ _rotr32(e, u32(25));
        ch: u32 = (e & f) ^ (~e & g);
        t1: u32 = wrapping_add(
            wrapping_add(h, s1), wrapping_add(ch, wrapping_add(_SHA256_K[i], w[i]))
        );
        s0: u32 = _rotr32(a, u32(2)) ^ _rotr32(a, u32(13)) ^ _rotr32(a, u32(22));
        mj: u32 = (a & b) ^ (a & c) ^ (b & c);
        h = g;
        g = f;
        f = e;
        e = wrapping_add(d, t1);
        d = c;
        c = b;
        b = a;
        a = wrapping_add(t1, wrapping_add(s0, mj));
        i += 1;
    }
    self.h[0] = wrapping_add(self.h[0], a);
    self.h[1] = wrapping_add(self.h[1], b);
    self.h[2] = wrapping_add(self.h[2], c);
    self.h[3] = wrapping_add(self.h[3], d);
    self.h[4] = wrapping_add(self.h[4], e);
    self.h[5] = wrapping_add(self.h[5], f);
    self.h[6] = wrapping_add(self.h[6], g);
    self.h[7] = wrapping_add(self.h[7], h);
}

impl Sha256Core.finish -> bytes {
    t = Sha256Core(h=list(self.h), w=self.w);
    self.carry(t);
    t.pad_md(True, 8);
    return _words32(t.h, self.digest_size, True);
}

impl Sha256Core.clone -> DigestCore {
    return self.carry(Sha256Core(h=list(self.h), w=[u32(0)] * 64));
}

impl Sha512Core.compress(address: int, last: bool) {
    w: list[u64] = self.w;
    j: int = 0;
    while j < 16 {
        w[j] = _be64(address + 8 * j);
        j += 1;
    }
    while j < 80 {
        x: u64 = w[j - 15];
        y: u64 = w[j - 2];
        s0: u64 = _rotr64(x, 1) ^ _rotr64(x, 8) ^ (x >> u64(7));
        s1: u64 = _rotr64(y, 19) ^ _rotr64(y, 61) ^ (y >> u64(6));
        w[j] = wrapping_add(wrapping_add(w[j - 16], s0), wrapping_add(w[j - 7], s1));
        j += 1;
    }
    a: u64 = self.h[0];
    b: u64 = self.h[1];
    c: u64 = self.h[2];
    d: u64 = self.h[3];
    e: u64 = self.h[4];
    f: u64 = self.h[5];
    g: u64 = self.h[6];
    h: u64 = self.h[7];
    i: int = 0;
    while i < 80 {
        s1: u64 = _rotr64(e, 14) ^ _rotr64(e, 18) ^ _rotr64(e, 41);
        ch: u64 = (e & f) ^ (~e & g);
        t1: u64 = wrapping_add(
            wrapping_add(h, s1), wrapping_add(ch, wrapping_add(_SHA512_K[i], w[i]))
        );
        s0: u64 = _rotr64(a, 28) ^ _rotr64(a, 34) ^ _rotr64(a, 39);
        mj: u64 = (a & b) ^ (a & c) ^ (b & c);
        h = g;
        g = f;
        f = e;
        e = wrapping_add(d, t1);
        d = c;
        c = b;
        b = a;
        a = wrapping_add(t1, wrapping_add(s0, mj));
        i += 1;
    }
    self.h[0] = wrapping_add(self.h[0], a);
    self.h[1] = wrapping_add(self.h[1], b);
    self.h[2] = wrapping_add(self.h[2], c);
    self.h[3] = wrapping_add(self.h[3], d);
    self.h[4] = wrapping_add(self.h[4], e);
    self.h[5] = wrapping_add(self.h[5], f);
    self.h[6] = wrapping_add(self.h[6], g);
    self.h[7] = wrapping_add(self.h[7], h);
}

impl Sha512Core.finish -> bytes {
    t = Sha512Core(h=list(self.h), w=self.w);
    self.carry(t);
    t.pad_md(True, 16);
    return _words64(t.h, self.digest_size, True);
}

impl Sha512Core.clone -> DigestCore {
    return self.carry(Sha512Core(h=list(self.h), w=[u64(0)] * 80));
}

impl _keccak(a: list[u64], b: list[u64]) {
    r: int = 0;
    while r < 24 {
        c0: u64 = a[0] ^ a[5] ^ a[10] ^ a[15] ^ a[20];
        c1: u64 = a[1] ^ a[6] ^ a[11] ^ a[16] ^ a[21];
        c2: u64 = a[2] ^ a[7] ^ a[12] ^ a[17] ^ a[22];
        c3: u64 = a[3] ^ a[8] ^ a[13] ^ a[18] ^ a[23];
        c4: u64 = a[4] ^ a[9] ^ a[14] ^ a[19] ^ a[24];
        d0: u64 = c4 ^ _rotl64(c1, 1);
        d1: u64 = c0 ^ _rotl64(c2, 1);
        d2: u64 = c1 ^ _rotl64(c3, 1);
        d3: u64 = c2 ^ _rotl64(c4, 1);
        d4: u64 = c3 ^ _rotl64(c0, 1);
        b[0] = a[0] ^ d0;
        b[10] = _rotl64(a[1] ^ d1, 1);
        b[20] = _rotl64(a[2] ^ d2, 62);
        b[5] = _rotl64(a[3] ^ d3, 28);
        b[15] = _rotl64(a[4] ^ d4, 27);
        b[16] = _rotl64(a[5] ^ d0, 36);
        b[1] = _rotl64(a[6] ^ d1, 44);
        b[11] = _rotl64(a[7] ^ d2, 6);
        b[21] = _rotl64(a[8] ^ d3, 55);
        b[6] = _rotl64(a[9] ^ d4, 20);
        b[7] = _rotl64(a[10] ^ d0, 3);
        b[17] = _rotl64(a[11] ^ d1, 10);
        b[2] = _rotl64(a[12] ^ d2, 43);
        b[12] = _rotl64(a[13] ^ d3, 25);
        b[22] = _rotl64(a[14] ^ d4, 39);
        b[23] = _rotl64(a[15] ^ d0, 41);
        b[8] = _rotl64(a[16] ^ d1, 45);
        b[18] = _rotl64(a[17] ^ d2, 15);
        b[3] = _rotl64(a[18] ^ d3, 21);
        b[13] = _rotl64(a[19] ^ d4, 8);
        b[14] = _rotl64(a[20] ^ d0, 18);
        b[24] = _rotl64(a[21] ^ d1, 2);
        b[9] = _rotl64(a[22] ^ d2, 61);
        b[19] = _rotl64(a[23] ^ d3, 56);
        b[4] = _rotl64(a[24] ^ d4, 14);
        k: int = 0;
        while k < 25 {
            b0: u64 = b[k];
            b1: u64 = b[k + 1];
            b2: u64 = b[k + 2];
            b3: u64 = b[k + 3];
            b4: u64 = b[k + 4];
            a[k] = b0 ^ (~b1 & b2);
            a[k + 1] = b1 ^ (~b2 & b3);
            a[k + 2] = b2 ^ (~b3 & b4);
            a[k + 3] = b3 ^ (~b4 & b0);
            a[k + 4] = b4 ^ (~b0 & b1);
            k += 5;
        }
        a[0] = a[0] ^ _KECCAK_RC[r];
        r += 1;
    }
}

impl Sha3Core.compress(address: int, last: bool) {
    lanes: int = self.block_size // 8;
    j: int = 0;
    while j < lanes {
        self.a[j] = self.a[j] ^ _le64(address + 8 * j);
        j += 1;
    }
    _keccak(self.a, self.b);
}

impl Sha3Core.finish -> bytes {
    return self.squeeze(self.digest_size);
}

impl Sha3Core.squeeze(size: int) -> bytes {
    t = Sha3Core(a=list(self.a), b=self.b, suffix=self.suffix);
    self.carry(t);
    bs: int = self.block_size;
    base: int = __bytearray_data(t.pending);
    if t.used == bs {
        t.compress(base, False);
        t.used = 0;
    }
    _zero(base + t.used, bs - t.used);
    t.pending[t.used] = self.suffix;
    t.pending[bs - 1] = t.pending[bs - 1] | 0x80;
    t.compress(base, False);
    out = bytearray(size);
    target: int = __bytearray_data(out);
    done: int = 0;
    while done < size {
        if done > 0 {
            _keccak(t.a, t.b);
        }
        take: int = bs if size - done > bs else size - done;
        _copy(target + done, __list_data_ptr(t.a), take);
        done += take;
    }
    return bytes(out);
}

impl Sha3Core.clone -> DigestCore {
    return self.carry(Sha3Core(a=list(self.a), b=[u64(0)] * 25, suffix=self.suffix));
}

impl Blake2sCore.compress(address: int, last: bool) {
    v0: u32 = self.h[0];
    v1: u32 = self.h[1];
    v2: u32 = self.h[2];
    v3: u32 = self.h[3];
    v4: u32 = self.h[4];
    v5: u32 = self.h[5];
    v6: u32 = self.h[6];
    v7: u32 = self.h[7];
    v8: u32 = _SHA256_IV[0];
    v9: u32 = _SHA256_IV[1];
    v10: u32 = _SHA256_IV[2];
    v11: u32 = _SHA256_IV[3];
    v12: u32 = _SHA256_IV[4] ^ u32.wrap(self.compressed);
    v13: u32 = _SHA256_IV[5] ^ u32.wrap(self.compressed >> 32);
    v14: u32 = _SHA256_IV[6];
    v15: u32 = _SHA256_IV[7];
    if last {
        v14 = ~v14;
        if self.last_node {
            v15 = ~v15;
        }
    }
    r: int = 0;
    while r < 10 {
        s: int = 16 * r;
        v0 = wrapping_add(wrapping_add(v0, v4), _msg32(address, s + 0));
        v12 = _rotr32(v12 ^ v0, u32(16));
        v8 = wrapping_add(v8, v12);
        v4 = _rotr32(v4 ^ v8, u32(12));
        v0 = wrapping_add(wrapping_add(v0, v4), _msg32(address, s + 1));
        v12 = _rotr32(v12 ^ v0, u32(8));
        v8 = wrapping_add(v8, v12);
        v4 = _rotr32(v4 ^ v8, u32(7));
        v1 = wrapping_add(wrapping_add(v1, v5), _msg32(address, s + 2));
        v13 = _rotr32(v13 ^ v1, u32(16));
        v9 = wrapping_add(v9, v13);
        v5 = _rotr32(v5 ^ v9, u32(12));
        v1 = wrapping_add(wrapping_add(v1, v5), _msg32(address, s + 3));
        v13 = _rotr32(v13 ^ v1, u32(8));
        v9 = wrapping_add(v9, v13);
        v5 = _rotr32(v5 ^ v9, u32(7));
        v2 = wrapping_add(wrapping_add(v2, v6), _msg32(address, s + 4));
        v14 = _rotr32(v14 ^ v2, u32(16));
        v10 = wrapping_add(v10, v14);
        v6 = _rotr32(v6 ^ v10, u32(12));
        v2 = wrapping_add(wrapping_add(v2, v6), _msg32(address, s + 5));
        v14 = _rotr32(v14 ^ v2, u32(8));
        v10 = wrapping_add(v10, v14);
        v6 = _rotr32(v6 ^ v10, u32(7));
        v3 = wrapping_add(wrapping_add(v3, v7), _msg32(address, s + 6));
        v15 = _rotr32(v15 ^ v3, u32(16));
        v11 = wrapping_add(v11, v15);
        v7 = _rotr32(v7 ^ v11, u32(12));
        v3 = wrapping_add(wrapping_add(v3, v7), _msg32(address, s + 7));
        v15 = _rotr32(v15 ^ v3, u32(8));
        v11 = wrapping_add(v11, v15);
        v7 = _rotr32(v7 ^ v11, u32(7));
        v0 = wrapping_add(wrapping_add(v0, v5), _msg32(address, s + 8));
        v15 = _rotr32(v15 ^ v0, u32(16));
        v10 = wrapping_add(v10, v15);
        v5 = _rotr32(v5 ^ v10, u32(12));
        v0 = wrapping_add(wrapping_add(v0, v5), _msg32(address, s + 9));
        v15 = _rotr32(v15 ^ v0, u32(8));
        v10 = wrapping_add(v10, v15);
        v5 = _rotr32(v5 ^ v10, u32(7));
        v1 = wrapping_add(wrapping_add(v1, v6), _msg32(address, s + 10));
        v12 = _rotr32(v12 ^ v1, u32(16));
        v11 = wrapping_add(v11, v12);
        v6 = _rotr32(v6 ^ v11, u32(12));
        v1 = wrapping_add(wrapping_add(v1, v6), _msg32(address, s + 11));
        v12 = _rotr32(v12 ^ v1, u32(8));
        v11 = wrapping_add(v11, v12);
        v6 = _rotr32(v6 ^ v11, u32(7));
        v2 = wrapping_add(wrapping_add(v2, v7), _msg32(address, s + 12));
        v13 = _rotr32(v13 ^ v2, u32(16));
        v8 = wrapping_add(v8, v13);
        v7 = _rotr32(v7 ^ v8, u32(12));
        v2 = wrapping_add(wrapping_add(v2, v7), _msg32(address, s + 13));
        v13 = _rotr32(v13 ^ v2, u32(8));
        v8 = wrapping_add(v8, v13);
        v7 = _rotr32(v7 ^ v8, u32(7));
        v3 = wrapping_add(wrapping_add(v3, v4), _msg32(address, s + 14));
        v14 = _rotr32(v14 ^ v3, u32(16));
        v9 = wrapping_add(v9, v14);
        v4 = _rotr32(v4 ^ v9, u32(12));
        v3 = wrapping_add(wrapping_add(v3, v4), _msg32(address, s + 15));
        v14 = _rotr32(v14 ^ v3, u32(8));
        v9 = wrapping_add(v9, v14);
        v4 = _rotr32(v4 ^ v9, u32(7));
        r += 1;
    }
    self.h[0] = self.h[0] ^ v0 ^ v8;
    self.h[1] = self.h[1] ^ v1 ^ v9;
    self.h[2] = self.h[2] ^ v2 ^ v10;
    self.h[3] = self.h[3] ^ v3 ^ v11;
    self.h[4] = self.h[4] ^ v4 ^ v12;
    self.h[5] = self.h[5] ^ v5 ^ v13;
    self.h[6] = self.h[6] ^ v6 ^ v14;
    self.h[7] = self.h[7] ^ v7 ^ v15;
}

impl Blake2sCore.finish -> bytes {
    t = Blake2sCore(h=list(self.h), v=self.v, last_node=self.last_node);
    self.carry(t);
    base: int = __bytearray_data(t.pending);
    _zero(base + t.used, t.block_size - t.used);
    t.compressed += t.used;
    t.compress(base, True);
    return _words32(t.h, self.digest_size, False);
}

impl Blake2sCore.clone -> DigestCore {
    return self.carry(
        Blake2sCore(h=list(self.h), v=[u32(0)] * 16, last_node=self.last_node)
    );
}

impl Blake2bCore.compress(address: int, last: bool) {
    v0: u64 = self.h[0];
    v1: u64 = self.h[1];
    v2: u64 = self.h[2];
    v3: u64 = self.h[3];
    v4: u64 = self.h[4];
    v5: u64 = self.h[5];
    v6: u64 = self.h[6];
    v7: u64 = self.h[7];
    v8: u64 = _SHA512_IV[0];
    v9: u64 = _SHA512_IV[1];
    v10: u64 = _SHA512_IV[2];
    v11: u64 = _SHA512_IV[3];
    v12: u64 = _SHA512_IV[4] ^ u64(self.compressed);
    v13: u64 = _SHA512_IV[5];
    v14: u64 = _SHA512_IV[6];
    v15: u64 = _SHA512_IV[7];
    if last {
        v14 = ~v14;
        if self.last_node {
            v15 = ~v15;
        }
    }
    r: int = 0;
    while r < 12 {
        s: int = 16 * (r % 10);
        v0 = wrapping_add(wrapping_add(v0, v4), _msg64(address, s + 0));
        v12 = _rotr64(v12 ^ v0, 32);
        v8 = wrapping_add(v8, v12);
        v4 = _rotr64(v4 ^ v8, 24);
        v0 = wrapping_add(wrapping_add(v0, v4), _msg64(address, s + 1));
        v12 = _rotr64(v12 ^ v0, 16);
        v8 = wrapping_add(v8, v12);
        v4 = _rotr64(v4 ^ v8, 63);
        v1 = wrapping_add(wrapping_add(v1, v5), _msg64(address, s + 2));
        v13 = _rotr64(v13 ^ v1, 32);
        v9 = wrapping_add(v9, v13);
        v5 = _rotr64(v5 ^ v9, 24);
        v1 = wrapping_add(wrapping_add(v1, v5), _msg64(address, s + 3));
        v13 = _rotr64(v13 ^ v1, 16);
        v9 = wrapping_add(v9, v13);
        v5 = _rotr64(v5 ^ v9, 63);
        v2 = wrapping_add(wrapping_add(v2, v6), _msg64(address, s + 4));
        v14 = _rotr64(v14 ^ v2, 32);
        v10 = wrapping_add(v10, v14);
        v6 = _rotr64(v6 ^ v10, 24);
        v2 = wrapping_add(wrapping_add(v2, v6), _msg64(address, s + 5));
        v14 = _rotr64(v14 ^ v2, 16);
        v10 = wrapping_add(v10, v14);
        v6 = _rotr64(v6 ^ v10, 63);
        v3 = wrapping_add(wrapping_add(v3, v7), _msg64(address, s + 6));
        v15 = _rotr64(v15 ^ v3, 32);
        v11 = wrapping_add(v11, v15);
        v7 = _rotr64(v7 ^ v11, 24);
        v3 = wrapping_add(wrapping_add(v3, v7), _msg64(address, s + 7));
        v15 = _rotr64(v15 ^ v3, 16);
        v11 = wrapping_add(v11, v15);
        v7 = _rotr64(v7 ^ v11, 63);
        v0 = wrapping_add(wrapping_add(v0, v5), _msg64(address, s + 8));
        v15 = _rotr64(v15 ^ v0, 32);
        v10 = wrapping_add(v10, v15);
        v5 = _rotr64(v5 ^ v10, 24);
        v0 = wrapping_add(wrapping_add(v0, v5), _msg64(address, s + 9));
        v15 = _rotr64(v15 ^ v0, 16);
        v10 = wrapping_add(v10, v15);
        v5 = _rotr64(v5 ^ v10, 63);
        v1 = wrapping_add(wrapping_add(v1, v6), _msg64(address, s + 10));
        v12 = _rotr64(v12 ^ v1, 32);
        v11 = wrapping_add(v11, v12);
        v6 = _rotr64(v6 ^ v11, 24);
        v1 = wrapping_add(wrapping_add(v1, v6), _msg64(address, s + 11));
        v12 = _rotr64(v12 ^ v1, 16);
        v11 = wrapping_add(v11, v12);
        v6 = _rotr64(v6 ^ v11, 63);
        v2 = wrapping_add(wrapping_add(v2, v7), _msg64(address, s + 12));
        v13 = _rotr64(v13 ^ v2, 32);
        v8 = wrapping_add(v8, v13);
        v7 = _rotr64(v7 ^ v8, 24);
        v2 = wrapping_add(wrapping_add(v2, v7), _msg64(address, s + 13));
        v13 = _rotr64(v13 ^ v2, 16);
        v8 = wrapping_add(v8, v13);
        v7 = _rotr64(v7 ^ v8, 63);
        v3 = wrapping_add(wrapping_add(v3, v4), _msg64(address, s + 14));
        v14 = _rotr64(v14 ^ v3, 32);
        v9 = wrapping_add(v9, v14);
        v4 = _rotr64(v4 ^ v9, 24);
        v3 = wrapping_add(wrapping_add(v3, v4), _msg64(address, s + 15));
        v14 = _rotr64(v14 ^ v3, 16);
        v9 = wrapping_add(v9, v14);
        v4 = _rotr64(v4 ^ v9, 63);
        r += 1;
    }
    self.h[0] = self.h[0] ^ v0 ^ v8;
    self.h[1] = self.h[1] ^ v1 ^ v9;
    self.h[2] = self.h[2] ^ v2 ^ v10;
    self.h[3] = self.h[3] ^ v3 ^ v11;
    self.h[4] = self.h[4] ^ v4 ^ v12;
    self.h[5] = self.h[5] ^ v5 ^ v13;
    self.h[6] = self.h[6] ^ v6 ^ v14;
    self.h[7] = self.h[7] ^ v7 ^ v15;
}

impl Blake2bCore.finish -> bytes {
    t = Blake2bCore(h=list(self.h), v=self.v, last_node=self.last_node);
    self.carry(t);
    base: int = __bytearray_data(t.pending);
    _zero(base + t.used, t.block_size - t.used);
    t.compressed += t.used;
    t.compress(base, True);
    return _words64(t.h, self.digest_size, False);
}

impl Blake2bCore.clone -> DigestCore {
    return self.carry(
        Blake2bCore(h=list(self.h), v=[u64(0)] * 16, last_node=self.last_node)
    );
}

impl HmacCore.absorb(address: int, size: int) {
    self.inner.absorb(address, size);
}

impl HmacCore.finish -> bytes {
    outer = self.outer.clone();
    outer.update(self.inner.finish());
    return outer.finish();
}

impl HmacCore.clone -> DigestCore {
    return self.carry(HmacCore(inner=self.inner.clone(), outer=self.outer.clone()));
}

impl new_core(name: str) -> (DigestCore | None) {
    if name == "md5" {
        return _setup(
            Md5Core(
                h=[u32(0x67452301), u32(0xefcdab89), u32(0x98badcfe), u32(0x10325476)]
            ),
            name,
            64,
            16
        );
    } elif name == "sha1" {
        return _setup(
            Sha1Core(
                h=[
                    u32(0x67452301),
                    u32(0xEFCDAB89),
                    u32(0x98BADCFE),
                    u32(0x10325476),
                    u32(0xC3D2E1F0)
                ],
                w=[u32(0)] * 80
            ),
            name,
            64,
            20
        );
    } elif name == "sha224" or name == "sha256" {
        small: bool = name == "sha224";
        return _setup(
            Sha256Core(h=list(_SHA224_IV if small else _SHA256_IV), w=[u32(0)] * 64),
            name,
            64,
            28 if small else 32
        );
    } elif name == "sha384" or name == "sha512" {
        short: bool = name == "sha384";
        return _setup(
            Sha512Core(h=list(_SHA384_IV if short else _SHA512_IV), w=[u64(0)] * 80),
            name,
            128,
            48 if short else 64
        );
    } elif name in ["sha3_224", "sha3_256", "sha3_384", "sha3_512"] {
        size: int = int(name[5:]) // 8;
        return _setup(
            Sha3Core(a=[u64(0)] * 25, b=[u64(0)] * 25), name, 200 - 2 * size, size
        );
    } elif name in ["shake_128", "shake_256"] {
        return _setup(
            Sha3Core(a=[u64(0)] * 25, b=[u64(0)] * 25, suffix=0x1F),
            name,
            200 - int(name[6:]) // 4,
            0
        );
    } elif name == "blake2b" {
        return new_blake2(True, 64, 0, 0, 0, 0, 0, 0, 1, 1, 0, u64(0), 0, 0, False);
    } elif name == "blake2s" {
        return new_blake2(False, 32, 0, 0, 0, 0, 0, 0, 1, 1, 0, u64(0), 0, 0, False);
    }
    return None;
}

impl new_blake2(
    wide: bool,
    digest_size: int,
    key: int,
    key_size: int,
    salt: int,
    salt_size: int,
    person: int,
    person_size: int,
    fanout: int,
    depth: int,
    leaf_size: int,
    node_offset: u64,
    node_depth: int,
    inner_size: int,
    last_node: bool
) -> DigestCore {
    width: int = 8 if wide else 4;
    block = bytearray(8 * width);
    p: int = __bytearray_data(block);
    block[0] = digest_size;
    block[1] = key_size;
    block[2] = fanout;
    block[3] = depth;
    __mem_store_i32(p + 4, i32.wrap(leaf_size));
    __mem_store_i32(p + 8, i32.wrap(int(node_offset & u64(0xFFFFFFFF))));
    __mem_store_i32(p + 12, i32.wrap(int(node_offset >> u64(32))));
    block[16 if wide else 14] = node_depth;
    block[17 if wide else 15] = inner_size;
    _copy(p + 4 * width, salt, salt_size);
    _copy(p + 6 * width, person, person_size);
    core: DigestCore = DigestCore();
    if wide {
        hb: list[u64] = list(_SHA512_IV);
        j: int = 0;
        while j < 8 {
            hb[j] = hb[j] ^ _le64(p + 8 * j);
            j += 1;
        }
        core = _setup(
            Blake2bCore(h=hb, v=[u64(0)] * 16, last_node=last_node),
            "blake2b",
            128,
            digest_size
        );
    } else {
        hs: list[u32] = list(_SHA256_IV);
        k: int = 0;
        while k < 8 {
            hs[k] = hs[k] ^ _le32(p + 4 * k);
            k += 1;
        }
        core = _setup(
            Blake2sCore(h=hs, v=[u32(0)] * 16, last_node=last_node),
            "blake2s",
            64,
            digest_size
        );
    }
    if key_size > 0 {
        pad = bytearray(core.block_size);
        _copy(__bytearray_data(pad), key, key_size);
        core.absorb(__bytearray_data(pad), core.block_size);
    }
    return core;
}

impl new_hmac(name: str, key: int, key_size: int) -> (DigestCore | None) {
    inner = new_core(name);
    outer = new_core(name);
    if inner is None or outer is None {
        return None;
    }
    bs: int = inner.block_size;
    pads = bytearray(2 * bs);
    p: int = __bytearray_data(pads);
    if key_size > bs {
        shrink = outer.clone();
        shrink.absorb(key, key_size);
        hashed: bytes = shrink.finish();
        _copy(p, __bytes_data(hashed), len(hashed));
    } else {
        _copy(p, key, key_size);
    }
    i: int = 0;
    while i < bs {
        pads[bs + i] = pads[i] ^ 0x5c;
        pads[i] = pads[i] ^ 0x36;
        i += 1;
    }
    inner.absorb(p, bs);
    outer.absorb(p + bs, bs);
    return _setup(HmacCore(inner=inner, outer=outer), name, bs, inner.digest_size);
}

impl _setup(
    core: DigestCore, name: str, block_size: int, digest_size: int
) -> DigestCore {
    core.name = name;
    core.block_size = block_size;
    core.digest_size = digest_size;
    core.pending = bytearray(block_size);
    return core;
}

impl _copy(target: int, source: int, size: int) {
    i: int = 0;
    while i + 8 <= size {
        __mem_store_i64(target + i, __mem_load_i64(source + i));
        i += 8;
    }
    while i < size {
        __mem_store_i8(target + i, __mem_load_i8(source + i));
        i += 1;
    }
}

impl _zero(target: int, size: int) {
    i: int = 0;
    while i < size {
        __mem_store_i8(target + i, i8(0));
        i += 1;
    }
}

impl _rotl32(x: u32, n: u32) -> u32 {
    return wrapping_shl(x, n) | (x >> ((u32(32) - n) & u32(31)));
}

impl _rotr32(x: u32, n: u32) -> u32 {
    return (x >> n) | wrapping_shl(x, (u32(32) - n) & u32(31));
}

impl _rotr64(x: u64, n: int) -> u64 {
    return (x >> u64(n)) | wrapping_shl(x, u64((64 - n) & 63));
}

impl _rotl64(x: u64, n: int) -> u64 {
    return wrapping_shl(x, u64(n)) | (x >> u64((64 - n) & 63));
}

impl _bswap32(x: u32) -> u32 {
    return wrapping_shl(x, u32(24))
        | wrapping_shl(x & u32(0xFF00), u32(8))
        | ((x >> u32(8)) & u32(0xFF00))
        | (x >> u32(24));
}

impl _le32(address: int) -> u32 {
    return u32.wrap(__mem_load_i32(address));
}

impl _be32(address: int) -> u32 {
    return _bswap32(_le32(address));
}

impl _le64(address: int) -> u64 {
    return u64.wrap(__mem_load_i64(address));
}

impl _be64(address: int) -> u64 {
    return wrapping_shl(u64(_be32(address)), u64(32)) | u64(_be32(address + 4));
}

impl _words32(h: list[u32], size: int, big: bool) -> bytes {
    out = bytearray(4 * len(h));
    p: int = __bytearray_data(out);
    j: int = 0;
    while j < len(h) {
        __mem_store_i32(p + 4 * j, i32.wrap(int(_bswap32(h[j]) if big else h[j])));
        j += 1;
    }
    return bytes(out[:size]);
}

impl _words64(h: list[u64], size: int, big: bool) -> bytes {
    words: list[u32] = [];
    for x in h {
        high: u32 = u32(x >> u64(32));
        low: u32 = u32(x & u64(0xFFFFFFFF));
        words.append(high if big else low);
        words.append(low if big else high);
    }
    return _words32(words, size, big);
}

impl _md5_step(a: u32, b: u32, f: u32, i: int, address: int, word: int) -> u32 {
    return wrapping_add(
        b,
        _rotl32(
            wrapping_add(
                wrapping_add(f, a),
                wrapping_add(
                    _MD5_K[i], _le32(wrapping_add(address, wrapping_shl(word, 2)))
                )
            ),
            _MD5_S[i]
        )
    );
}


impl _msg32(address: int, s: int) -> u32 {
    return _le32(wrapping_add(address, wrapping_shl(_BLAKE2_SIGMA[s], 2)));
}

impl _msg64(address: int, s: int) -> u64 {
    return _le64(wrapping_add(address, wrapping_shl(_BLAKE2_SIGMA[s], 3)));
}
