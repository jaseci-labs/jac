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
    used: int = self.used;
    keep: int = __alloca(200);
    _copy(keep, base, used);
    bits: int = (self.compressed + used) * 8;
    if used == bs {
        self.compress(base, False);
        used = 0;
    }
    __mem_store_i8(base + used, i8.wrap(0x80));
    used += 1;
    if used > bs - length_bytes {
        _zero(base + used, bs - used);
        self.compress(base, False);
        used = 0;
    }
    _zero(base + used, bs - used);
    if big {
        __mem_store_i32(base + bs - 8, i32.wrap(int(_bswap32(u32.wrap(bits >> 32)))));
        __mem_store_i32(base + bs - 4, i32.wrap(int(_bswap32(u32.wrap(bits)))));
    } else {
        __mem_store_i64(base + bs - 8, bits);
    }
    self.compress(base, False);
    _copy(base, keep, self.used);
}

impl Md5Core.compress(address: int, last: bool) {
    k = ptr[u64](__list_data_ptr(_MD5_K)).view(64);
    a: u32 = self.h[0];
    b: u32 = self.h[1];
    c: u32 = self.h[2];
    d: u32 = self.h[3];
    i: int = 0;
    while i < 16 {
        a = _md5_r(
            a,
            b,
            d ^ (b & (c ^ d)),
            u32.wrap(k[i]),
            _le32(wrapping_add(address, 4 * (i))),
            u32(7)
        );
        d = _md5_r(
            d,
            a,
            c ^ (a & (b ^ c)),
            u32.wrap(k[i + 1]),
            _le32(wrapping_add(address, 4 * (i + 1))),
            u32(12)
        );
        c = _md5_r(
            c,
            d,
            b ^ (d & (a ^ b)),
            u32.wrap(k[i + 2]),
            _le32(wrapping_add(address, 4 * (i + 2))),
            u32(17)
        );
        b = _md5_r(
            b,
            c,
            a ^ (c & (d ^ a)),
            u32.wrap(k[i + 3]),
            _le32(wrapping_add(address, 4 * (i + 3))),
            u32(22)
        );
        i += 4;
    }
    while i < 32 {
        a = _md5_r(
            a,
            b,
            c ^ (d & (b ^ c)),
            u32.wrap(k[i]),
            _le32(wrapping_add(address, 4 * ((5 * (i) + 1) & 15))),
            u32(5)
        );
        d = _md5_r(
            d,
            a,
            b ^ (c & (a ^ b)),
            u32.wrap(k[i + 1]),
            _le32(wrapping_add(address, 4 * ((5 * (i + 1) + 1) & 15))),
            u32(9)
        );
        c = _md5_r(
            c,
            d,
            a ^ (b & (d ^ a)),
            u32.wrap(k[i + 2]),
            _le32(wrapping_add(address, 4 * ((5 * (i + 2) + 1) & 15))),
            u32(14)
        );
        b = _md5_r(
            b,
            c,
            d ^ (a & (c ^ d)),
            u32.wrap(k[i + 3]),
            _le32(wrapping_add(address, 4 * ((5 * (i + 3) + 1) & 15))),
            u32(20)
        );
        i += 4;
    }
    while i < 48 {
        a = _md5_r(
            a,
            b,
            b ^ c ^ d,
            u32.wrap(k[i]),
            _le32(wrapping_add(address, 4 * ((3 * (i) + 5) & 15))),
            u32(4)
        );
        d = _md5_r(
            d,
            a,
            a ^ b ^ c,
            u32.wrap(k[i + 1]),
            _le32(wrapping_add(address, 4 * ((3 * (i + 1) + 5) & 15))),
            u32(11)
        );
        c = _md5_r(
            c,
            d,
            d ^ a ^ b,
            u32.wrap(k[i + 2]),
            _le32(wrapping_add(address, 4 * ((3 * (i + 2) + 5) & 15))),
            u32(16)
        );
        b = _md5_r(
            b,
            c,
            c ^ d ^ a,
            u32.wrap(k[i + 3]),
            _le32(wrapping_add(address, 4 * ((3 * (i + 3) + 5) & 15))),
            u32(23)
        );
        i += 4;
    }
    while i < 64 {
        a = _md5_r(
            a,
            b,
            c ^ (b | ~d),
            u32.wrap(k[i]),
            _le32(wrapping_add(address, 4 * ((7 * (i)) & 15))),
            u32(6)
        );
        d = _md5_r(
            d,
            a,
            b ^ (a | ~c),
            u32.wrap(k[i + 1]),
            _le32(wrapping_add(address, 4 * ((7 * (i + 1)) & 15))),
            u32(10)
        );
        c = _md5_r(
            c,
            d,
            a ^ (d | ~b),
            u32.wrap(k[i + 2]),
            _le32(wrapping_add(address, 4 * ((7 * (i + 2)) & 15))),
            u32(15)
        );
        b = _md5_r(
            b,
            c,
            d ^ (c | ~a),
            u32.wrap(k[i + 3]),
            _le32(wrapping_add(address, 4 * ((7 * (i + 3)) & 15))),
            u32(21)
        );
        i += 4;
    }
    self.h[0] = wrapping_add(self.h[0], a);
    self.h[1] = wrapping_add(self.h[1], b);
    self.h[2] = wrapping_add(self.h[2], c);
    self.h[3] = wrapping_add(self.h[3], d);
}

impl Md5Core.finish -> bytes {
    h = self.h;
    self.h = list(h);
    self.pad_md(False, 8);
    out = _words32(self.h, self.digest_size, False);
    self.h = h;
    return out;
}

impl Md5Core.clone -> DigestCore {
    return self.carry(Md5Core(h=list(self.h)));
}

impl Sha1Core.compress(address: int, last: bool) {
    w = ptr[u32](__alloca(320)).view(80);
    j: int = 0;
    while j < 16 {
        w[j] = _be32(wrapping_add(address, 4 * j));
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
    h = self.h;
    self.h = list(h);
    self.pad_md(True, 8);
    out = _words32(self.h, self.digest_size, True);
    self.h = h;
    return out;
}

impl Sha1Core.clone -> DigestCore {
    return self.carry(Sha1Core(h=list(self.h)));
}

impl Sha256Core.compress(address: int, last: bool) {
    w = ptr[u32](__alloca(512)).view(128);
    k = ptr[u64](__list_data_ptr(_SHA256_K)).view(64);
    j: int = 0;
    while j < 16 {
        w[j] = _be32(wrapping_add(address, 4 * j));
        w[64 + j] = wrapping_add(w[j], u32.wrap(k[j]));
        j += 1;
    }
    y: u32 = w[14];
    z: u32 = w[15];
    while j < 64 {
        x: u32 = w[j - 15];
        v: u32 = wrapping_add(
            wrapping_add(
                w[j - 16], _rotr32(x, u32(7)) ^ _rotr32(x, u32(18)) ^ (x >> u32(3))
            ),
            wrapping_add(
                w[j - 7], _rotr32(y, u32(17)) ^ _rotr32(y, u32(19)) ^ (y >> u32(10))
            )
        );
        w[j] = v;
        w[64 + j] = wrapping_add(v, u32.wrap(k[j]));
        y = z;
        z = v;
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
    x: u32 = u32(0);
    t: u32 = u32(0);
    i: int = 0;
    while i < 64 {
        x = wrapping_add(h, w[64 + i]);
        t = _e256(e, f, g);
        d = wrapping_add(wrapping_add(d, x), t);
        h = wrapping_add(wrapping_add(x, t), _a256(a, b, c));
        x = wrapping_add(g, w[64 + i + 1]);
        t = _e256(d, e, f);
        c = wrapping_add(wrapping_add(c, x), t);
        g = wrapping_add(wrapping_add(x, t), _a256(h, a, b));
        x = wrapping_add(f, w[64 + i + 2]);
        t = _e256(c, d, e);
        b = wrapping_add(wrapping_add(b, x), t);
        f = wrapping_add(wrapping_add(x, t), _a256(g, h, a));
        x = wrapping_add(e, w[64 + i + 3]);
        t = _e256(b, c, d);
        a = wrapping_add(wrapping_add(a, x), t);
        e = wrapping_add(wrapping_add(x, t), _a256(f, g, h));
        x = wrapping_add(d, w[64 + i + 4]);
        t = _e256(a, b, c);
        h = wrapping_add(wrapping_add(h, x), t);
        d = wrapping_add(wrapping_add(x, t), _a256(e, f, g));
        x = wrapping_add(c, w[64 + i + 5]);
        t = _e256(h, a, b);
        g = wrapping_add(wrapping_add(g, x), t);
        c = wrapping_add(wrapping_add(x, t), _a256(d, e, f));
        x = wrapping_add(b, w[64 + i + 6]);
        t = _e256(g, h, a);
        f = wrapping_add(wrapping_add(f, x), t);
        b = wrapping_add(wrapping_add(x, t), _a256(c, d, e));
        x = wrapping_add(a, w[64 + i + 7]);
        t = _e256(f, g, h);
        e = wrapping_add(wrapping_add(e, x), t);
        a = wrapping_add(wrapping_add(x, t), _a256(b, c, d));
        i += 8;
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
    h = self.h;
    self.h = list(h);
    self.pad_md(True, 8);
    out = _words32(self.h, self.digest_size, True);
    self.h = h;
    return out;
}

impl Sha256Core.clone -> DigestCore {
    return self.carry(Sha256Core(h=list(self.h)));
}

impl Sha512Core.compress(address: int, last: bool) {
    w = ptr[u64](__alloca(1280)).view(160);
    k = ptr[u64](__list_data_ptr(_SHA512_K)).view(80);
    j: int = 0;
    while j < 16 {
        w[j] = _be64(wrapping_add(address, 8 * j));
        w[80 + j] = wrapping_add(w[j], k[j]);
        j += 1;
    }
    y: u64 = w[14];
    z: u64 = w[15];
    while j < 80 {
        x: u64 = w[j - 15];
        v: u64 = wrapping_add(
            wrapping_add(w[j - 16], _rotr64(x, 1) ^ _rotr64(x, 8) ^ (x >> u64(7))),
            wrapping_add(w[j - 7], _rotr64(y, 19) ^ _rotr64(y, 61) ^ (y >> u64(6)))
        );
        w[j] = v;
        w[80 + j] = wrapping_add(v, k[j]);
        y = z;
        z = v;
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
    x: u64 = u64(0);
    t: u64 = u64(0);
    i: int = 0;
    while i < 80 {
        x = wrapping_add(h, w[80 + i]);
        t = _e512(e, f, g);
        d = wrapping_add(wrapping_add(d, x), t);
        h = wrapping_add(wrapping_add(x, t), _a512(a, b, c));
        x = wrapping_add(g, w[80 + i + 1]);
        t = _e512(d, e, f);
        c = wrapping_add(wrapping_add(c, x), t);
        g = wrapping_add(wrapping_add(x, t), _a512(h, a, b));
        x = wrapping_add(f, w[80 + i + 2]);
        t = _e512(c, d, e);
        b = wrapping_add(wrapping_add(b, x), t);
        f = wrapping_add(wrapping_add(x, t), _a512(g, h, a));
        x = wrapping_add(e, w[80 + i + 3]);
        t = _e512(b, c, d);
        a = wrapping_add(wrapping_add(a, x), t);
        e = wrapping_add(wrapping_add(x, t), _a512(f, g, h));
        x = wrapping_add(d, w[80 + i + 4]);
        t = _e512(a, b, c);
        h = wrapping_add(wrapping_add(h, x), t);
        d = wrapping_add(wrapping_add(x, t), _a512(e, f, g));
        x = wrapping_add(c, w[80 + i + 5]);
        t = _e512(h, a, b);
        g = wrapping_add(wrapping_add(g, x), t);
        c = wrapping_add(wrapping_add(x, t), _a512(d, e, f));
        x = wrapping_add(b, w[80 + i + 6]);
        t = _e512(g, h, a);
        f = wrapping_add(wrapping_add(f, x), t);
        b = wrapping_add(wrapping_add(x, t), _a512(c, d, e));
        x = wrapping_add(a, w[80 + i + 7]);
        t = _e512(f, g, h);
        e = wrapping_add(wrapping_add(e, x), t);
        a = wrapping_add(wrapping_add(x, t), _a512(b, c, d));
        i += 8;
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
    h = self.h;
    self.h = list(h);
    self.pad_md(True, 16);
    out = _words64(self.h, self.digest_size, True);
    self.h = h;
    return out;
}

impl Sha512Core.clone -> DigestCore {
    return self.carry(Sha512Core(h=list(self.h)));
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
    a = self.a;
    self.a = list(a);
    bs: int = self.block_size;
    base: int = __bytearray_data(self.pending);
    used: int = self.used;
    keep: int = __alloca(200);
    _copy(keep, base, used);
    if used == bs {
        self.compress(base, False);
        used = 0;
    }
    _zero(base + used, bs - used);
    __mem_store_i8(base + used, i8(self.suffix));
    __mem_store_i8(base + bs - 1, i8.wrap(int(__mem_load_i8(base + bs - 1)) | 0x80));
    self.compress(base, False);
    out = bytes(size);
    target: int = __bytes_data(out);
    done: int = 0;
    while done < size {
        if done > 0 {
            _keccak(self.a, self.b);
        }
        take: int = bs if size - done > bs else size - done;
        _copy(target + done, __list_data_ptr(self.a), take);
        done += take;
    }
    self.a = a;
    _copy(base, keep, self.used);
    return out;
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
        sigma: int = wrapping_add(__list_data_ptr(_BLAKE2_SIGMA), 128 * r);
        v0 = wrapping_add(wrapping_add(v0, v4), _msg32(address, sigma + 0));
        v12 = _rotr32(v12 ^ v0, u32(16));
        v8 = wrapping_add(v8, v12);
        v4 = _rotr32(v4 ^ v8, u32(12));
        v0 = wrapping_add(wrapping_add(v0, v4), _msg32(address, sigma + 8));
        v12 = _rotr32(v12 ^ v0, u32(8));
        v8 = wrapping_add(v8, v12);
        v4 = _rotr32(v4 ^ v8, u32(7));
        v1 = wrapping_add(wrapping_add(v1, v5), _msg32(address, sigma + 16));
        v13 = _rotr32(v13 ^ v1, u32(16));
        v9 = wrapping_add(v9, v13);
        v5 = _rotr32(v5 ^ v9, u32(12));
        v1 = wrapping_add(wrapping_add(v1, v5), _msg32(address, sigma + 24));
        v13 = _rotr32(v13 ^ v1, u32(8));
        v9 = wrapping_add(v9, v13);
        v5 = _rotr32(v5 ^ v9, u32(7));
        v2 = wrapping_add(wrapping_add(v2, v6), _msg32(address, sigma + 32));
        v14 = _rotr32(v14 ^ v2, u32(16));
        v10 = wrapping_add(v10, v14);
        v6 = _rotr32(v6 ^ v10, u32(12));
        v2 = wrapping_add(wrapping_add(v2, v6), _msg32(address, sigma + 40));
        v14 = _rotr32(v14 ^ v2, u32(8));
        v10 = wrapping_add(v10, v14);
        v6 = _rotr32(v6 ^ v10, u32(7));
        v3 = wrapping_add(wrapping_add(v3, v7), _msg32(address, sigma + 48));
        v15 = _rotr32(v15 ^ v3, u32(16));
        v11 = wrapping_add(v11, v15);
        v7 = _rotr32(v7 ^ v11, u32(12));
        v3 = wrapping_add(wrapping_add(v3, v7), _msg32(address, sigma + 56));
        v15 = _rotr32(v15 ^ v3, u32(8));
        v11 = wrapping_add(v11, v15);
        v7 = _rotr32(v7 ^ v11, u32(7));
        v0 = wrapping_add(wrapping_add(v0, v5), _msg32(address, sigma + 64));
        v15 = _rotr32(v15 ^ v0, u32(16));
        v10 = wrapping_add(v10, v15);
        v5 = _rotr32(v5 ^ v10, u32(12));
        v0 = wrapping_add(wrapping_add(v0, v5), _msg32(address, sigma + 72));
        v15 = _rotr32(v15 ^ v0, u32(8));
        v10 = wrapping_add(v10, v15);
        v5 = _rotr32(v5 ^ v10, u32(7));
        v1 = wrapping_add(wrapping_add(v1, v6), _msg32(address, sigma + 80));
        v12 = _rotr32(v12 ^ v1, u32(16));
        v11 = wrapping_add(v11, v12);
        v6 = _rotr32(v6 ^ v11, u32(12));
        v1 = wrapping_add(wrapping_add(v1, v6), _msg32(address, sigma + 88));
        v12 = _rotr32(v12 ^ v1, u32(8));
        v11 = wrapping_add(v11, v12);
        v6 = _rotr32(v6 ^ v11, u32(7));
        v2 = wrapping_add(wrapping_add(v2, v7), _msg32(address, sigma + 96));
        v13 = _rotr32(v13 ^ v2, u32(16));
        v8 = wrapping_add(v8, v13);
        v7 = _rotr32(v7 ^ v8, u32(12));
        v2 = wrapping_add(wrapping_add(v2, v7), _msg32(address, sigma + 104));
        v13 = _rotr32(v13 ^ v2, u32(8));
        v8 = wrapping_add(v8, v13);
        v7 = _rotr32(v7 ^ v8, u32(7));
        v3 = wrapping_add(wrapping_add(v3, v4), _msg32(address, sigma + 112));
        v14 = _rotr32(v14 ^ v3, u32(16));
        v9 = wrapping_add(v9, v14);
        v4 = _rotr32(v4 ^ v9, u32(12));
        v3 = wrapping_add(wrapping_add(v3, v4), _msg32(address, sigma + 120));
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
    h = self.h;
    self.h = list(h);
    base: int = __bytearray_data(self.pending);
    done: int = self.compressed;
    _zero(base + self.used, self.block_size - self.used);
    self.compressed += self.used;
    self.compress(base, True);
    out = _words32(self.h, self.digest_size, False);
    self.compressed = done;
    self.h = h;
    return out;
}

impl Blake2sCore.clone -> DigestCore {
    return self.carry(Blake2sCore(h=list(self.h), last_node=self.last_node));
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
        sigma: int = wrapping_add(__list_data_ptr(_BLAKE2_SIGMA), 128 * (r % 10));
        v0 = wrapping_add(wrapping_add(v0, v4), _msg64(address, sigma + 0));
        v12 = _rotr64(v12 ^ v0, 32);
        v8 = wrapping_add(v8, v12);
        v4 = _rotr64(v4 ^ v8, 24);
        v0 = wrapping_add(wrapping_add(v0, v4), _msg64(address, sigma + 8));
        v12 = _rotr64(v12 ^ v0, 16);
        v8 = wrapping_add(v8, v12);
        v4 = _rotr64(v4 ^ v8, 63);
        v1 = wrapping_add(wrapping_add(v1, v5), _msg64(address, sigma + 16));
        v13 = _rotr64(v13 ^ v1, 32);
        v9 = wrapping_add(v9, v13);
        v5 = _rotr64(v5 ^ v9, 24);
        v1 = wrapping_add(wrapping_add(v1, v5), _msg64(address, sigma + 24));
        v13 = _rotr64(v13 ^ v1, 16);
        v9 = wrapping_add(v9, v13);
        v5 = _rotr64(v5 ^ v9, 63);
        v2 = wrapping_add(wrapping_add(v2, v6), _msg64(address, sigma + 32));
        v14 = _rotr64(v14 ^ v2, 32);
        v10 = wrapping_add(v10, v14);
        v6 = _rotr64(v6 ^ v10, 24);
        v2 = wrapping_add(wrapping_add(v2, v6), _msg64(address, sigma + 40));
        v14 = _rotr64(v14 ^ v2, 16);
        v10 = wrapping_add(v10, v14);
        v6 = _rotr64(v6 ^ v10, 63);
        v3 = wrapping_add(wrapping_add(v3, v7), _msg64(address, sigma + 48));
        v15 = _rotr64(v15 ^ v3, 32);
        v11 = wrapping_add(v11, v15);
        v7 = _rotr64(v7 ^ v11, 24);
        v3 = wrapping_add(wrapping_add(v3, v7), _msg64(address, sigma + 56));
        v15 = _rotr64(v15 ^ v3, 16);
        v11 = wrapping_add(v11, v15);
        v7 = _rotr64(v7 ^ v11, 63);
        v0 = wrapping_add(wrapping_add(v0, v5), _msg64(address, sigma + 64));
        v15 = _rotr64(v15 ^ v0, 32);
        v10 = wrapping_add(v10, v15);
        v5 = _rotr64(v5 ^ v10, 24);
        v0 = wrapping_add(wrapping_add(v0, v5), _msg64(address, sigma + 72));
        v15 = _rotr64(v15 ^ v0, 16);
        v10 = wrapping_add(v10, v15);
        v5 = _rotr64(v5 ^ v10, 63);
        v1 = wrapping_add(wrapping_add(v1, v6), _msg64(address, sigma + 80));
        v12 = _rotr64(v12 ^ v1, 32);
        v11 = wrapping_add(v11, v12);
        v6 = _rotr64(v6 ^ v11, 24);
        v1 = wrapping_add(wrapping_add(v1, v6), _msg64(address, sigma + 88));
        v12 = _rotr64(v12 ^ v1, 16);
        v11 = wrapping_add(v11, v12);
        v6 = _rotr64(v6 ^ v11, 63);
        v2 = wrapping_add(wrapping_add(v2, v7), _msg64(address, sigma + 96));
        v13 = _rotr64(v13 ^ v2, 32);
        v8 = wrapping_add(v8, v13);
        v7 = _rotr64(v7 ^ v8, 24);
        v2 = wrapping_add(wrapping_add(v2, v7), _msg64(address, sigma + 104));
        v13 = _rotr64(v13 ^ v2, 16);
        v8 = wrapping_add(v8, v13);
        v7 = _rotr64(v7 ^ v8, 63);
        v3 = wrapping_add(wrapping_add(v3, v4), _msg64(address, sigma + 112));
        v14 = _rotr64(v14 ^ v3, 32);
        v9 = wrapping_add(v9, v14);
        v4 = _rotr64(v4 ^ v9, 24);
        v3 = wrapping_add(wrapping_add(v3, v4), _msg64(address, sigma + 120));
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
    h = self.h;
    self.h = list(h);
    base: int = __bytearray_data(self.pending);
    done: int = self.compressed;
    _zero(base + self.used, self.block_size - self.used);
    self.compressed += self.used;
    self.compress(base, True);
    out = _words64(self.h, self.digest_size, False);
    self.compressed = done;
    self.h = h;
    return out;
}

impl Blake2bCore.clone -> DigestCore {
    return self.carry(Blake2bCore(h=list(self.h), last_node=self.last_node));
}

impl HmacCore.absorb(address: int, size: int) {
    self.inner.absorb(address, size);
}

impl HmacCore.finish -> bytes {
    outer = self.outer;
    if outer.used != 0 {
        outer = outer.clone();
    }
    used: int = outer.used;
    done: int = outer.compressed;
    outer.update(self.inner.finish());
    out = outer.finish();
    outer.used = used;
    outer.compressed = done;
    return out;
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
                ]
            ),
            name,
            64,
            20
        );
    } elif name == "sha224" or name == "sha256" {
        small: bool = name == "sha224";
        return _setup(
            Sha256Core(h=list(_SHA224_IV if small else _SHA256_IV)),
            name,
            64,
            28 if small else 32
        );
    } elif name == "sha384" or name == "sha512" {
        short: bool = name == "sha384";
        return _setup(
            Sha512Core(h=list(_SHA384_IV if short else _SHA512_IV)),
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
    p: int = __alloca(64);
    _zero(p, 8 * width);
    __mem_store_i32(
        p, i32.wrap(digest_size | (key_size << 8) | (fanout << 16) | (depth << 24))
    );
    __mem_store_i32(p + 4, i32.wrap(leaf_size));
    __mem_store_i32(p + 8, i32.wrap(int(node_offset & u64(0xFFFFFFFF))));
    __mem_store_i32(p + 12, i32.wrap(int(node_offset >> u64(32))));
    __mem_store_i16(p + (16 if wide else 14), i16.wrap(node_depth | (inner_size << 8)));
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
            Blake2bCore(h=hb, last_node=last_node), "blake2b", 128, digest_size
        );
    } else {
        hs: list[u32] = list(_SHA256_IV);
        k: int = 0;
        while k < 8 {
            hs[k] = hs[k] ^ _le32(p + 4 * k);
            k += 1;
        }
        core = _setup(
            Blake2sCore(h=hs, last_node=last_node), "blake2s", 64, digest_size
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
    p: int = __alloca(400);
    _zero(p, 2 * bs);
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
        word: int = __mem_load_i64(p + i);
        __mem_store_i64(p + bs + i, word ^ 0x5C5C5C5C5C5C5C5C);
        __mem_store_i64(p + i, word ^ 0x3636363636363636);
        i += 8;
    }
    inner.absorb(p, bs);
    outer.absorb(p + bs, bs);
    if not isinstance(outer, Blake2sCore) and not isinstance(outer, Blake2bCore) {
        outer.compressed += bs;
        outer.compress(p + bs, False);
        outer.used = 0;
    }
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
    while i + 8 <= size {
        __mem_store_i64(target + i, 0);
        i += 8;
    }
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
    return wrapping_shl(u64(_be32(address)), u64(32))
        | u64(_be32(wrapping_add(address, 4)));
}

impl _words32(h: list[u32], size: int, big: bool) -> bytes {
    buf: int = __alloca(64);
    j: int = 0;
    while j < len(h) {
        __mem_store_i32(buf + 4 * j, i32.wrap(int(_bswap32(h[j]) if big else h[j])));
        j += 1;
    }
    out = bytes(size);
    _copy(__bytes_data(out), buf, size);
    return out;
}

impl _words64(h: list[u64], size: int, big: bool) -> bytes {
    buf: int = __alloca(64);
    j: int = 0;
    while j < len(h) {
        x: u64 = h[j];
        if big {
            x = wrapping_shl(u64(_bswap32(u32.wrap(x))), u64(32))
                | u64(_bswap32(u32.wrap(x >> u64(32))));
        }
        __mem_store_i64(buf + 8 * j, i64.wrap(x));
        j += 1;
    }
    out = bytes(size);
    _copy(__bytes_data(out), buf, size);
    return out;
}

impl _msg32(address: int, sigma: int) -> u32 {
    return _le32(wrapping_add(address, wrapping_shl(__mem_load_i64(sigma), 2)));
}

impl _msg64(address: int, sigma: int) -> u64 {
    return _le64(wrapping_add(address, wrapping_shl(__mem_load_i64(sigma), 3)));
}

impl _e256(e: u32, f: u32, g: u32) -> u32 {
    return wrapping_add(
        _rotr32(e, u32(6)) ^ _rotr32(e, u32(11)) ^ _rotr32(e, u32(25)),
        g ^ (e & (f ^ g))
    );
}

impl _a256(a: u32, b: u32, c: u32) -> u32 {
    return wrapping_add(
        _rotr32(a, u32(2)) ^ _rotr32(a, u32(13)) ^ _rotr32(a, u32(22)),
        (a & b) | (c & (a | b))
    );
}

impl _md5_r(a: u32, b: u32, f: u32, k: u32, m: u32, s: u32) -> u32 {
    return wrapping_add(
        b, _rotl32(wrapping_add(wrapping_add(a, f), wrapping_add(k, m)), s)
    );
}

impl _e512(e: u64, f: u64, g: u64) -> u64 {
    return wrapping_add(
        _rotr64(e, 14) ^ _rotr64(e, 18) ^ _rotr64(e, 41), g ^ (e & (f ^ g))
    );
}

impl _a512(a: u64, b: u64, c: u64) -> u64 {
    return wrapping_add(
        _rotr64(a, 28) ^ _rotr64(a, 34) ^ _rotr64(a, 39), (a & b) | (c & (a | b))
    );
}
