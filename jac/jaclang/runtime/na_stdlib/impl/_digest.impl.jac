impl DigestCore.update(data: bytes) {
    n: int = len(data);
    bs: int = self.block_size;
    i: int = 0;
    while i < n {
        self.buf.append(data[i]);
        if len(self.buf) == bs {
            self.block(self.buf);
            self.buf = [];
        }
        i += 1;
    }
    self.total += n;
}

impl DigestCore.block(b: list[int]) {}

impl DigestCore.finish -> bytes {
    return b"";
}

impl DigestCore.clone -> DigestCore {
    return DigestCore(block_size=self.block_size, digest_size=self.digest_size);
}

impl _rotl32(x: int, n: int) -> int {
    return ((x << n) | (x >> (32 - n))) & _M32;
}

impl _rotr32(x: int, n: int) -> int {
    return ((x >> n) | (x << (32 - n))) & _M32;
}

impl _rotr64(x: u64, n: int) -> u64 {
    return (x >> u64(n)) | wrapping_shl(x, u64(64 - n));
}

impl _rotl64(x: u64, n: int) -> u64 {
    if n == 0 {
        return x;
    }
    return wrapping_shl(x, u64(n)) | (x >> u64(64 - n));
}

impl _be32(b: list[int], j: int) -> int {
    return (b[j] << 24) | (b[j + 1] << 16) | (b[j + 2] << 8) | b[j + 3];
}

impl _le32(b: list[int], j: int) -> int {
    return b[j] | (b[j + 1] << 8) | (b[j + 2] << 16) | (b[j + 3] << 24);
}

impl _be64(b: list[int], j: int) -> u64 {
    v: u64 = u64(0);
    k: int = 0;
    while k < 8 {
        v = wrapping_shl(v, u64(8)) | u64(b[j + k]);
        k += 1;
    }
    return v;
}

impl _le64(b: list[int], j: int) -> u64 {
    v: u64 = u64(0);
    k: int = 7;
    while k >= 0 {
        v = wrapping_shl(v, u64(8)) | u64(b[j + k]);
        k -= 1;
    }
    return v;
}

impl _pad_md(core: DigestCore, length_bytes: int, little: bool) {
    bits: int = core.total * 8;
    core.update(b"\x80");
    while len(core.buf) != core.block_size - length_bytes {
        core.update(b"\x00");
    }
    tail: list[int] = [];
    k: int = 0;
    while k < length_bytes {
        shift: int = 8 * k if little else 8 * (length_bytes - 1 - k);
        tail.append((bits >> shift) & 255 if shift < 63 else 0);
        k += 1;
    }
    core.update(bytes(tail));
}

impl Md5Core.block(b: list[int]) {
    m: list[int] = [];
    j: int = 0;
    while j < 16 {
        m.append(_le32(b, 4 * j));
        j += 1;
    }
    a: int = self.h[0];
    bb: int = self.h[1];
    c: int = self.h[2];
    d: int = self.h[3];
    i: int = 0;
    while i < 64 {
        f: int = 0;
        g: int = 0;
        if i < 16 {
            f = (bb & c) | (~bb & d);
            g = i;
        } elif i < 32 {
            f = (d & bb) | (~d & c);
            g = (5 * i + 1) % 16;
        } elif i < 48 {
            f = bb ^ c ^ d;
            g = (3 * i + 5) % 16;
        } else {
            f = c ^ (bb | (~d & _M32));
            g = (7 * i) % 16;
        }
        f = (f + a + _MD5_K[i] + m[g]) & _M32;
        a = d;
        d = c;
        c = bb;
        bb = (bb + _rotl32(f, _MD5_S[i])) & _M32;
        i += 1;
    }
    self.h[0] = (self.h[0] + a) & _M32;
    self.h[1] = (self.h[1] + bb) & _M32;
    self.h[2] = (self.h[2] + c) & _M32;
    self.h[3] = (self.h[3] + d) & _M32;
}

impl Md5Core.finish -> bytes {
    t = self.dup();
    _pad_md(t, 8, True);
    st: list[int] = t.h;
    out: list[int] = [];
    i: int = 0;
    while i < 4 {
        k: int = 0;
        while k < 4 {
            out.append((st[i] >> (8 * k)) & 255);
            k += 1;
        }
        i += 1;
    }
    return bytes(out);
}

impl Md5Core.clone -> DigestCore {
    return self.dup();
}

impl Md5Core.dup -> Md5Core {
    return Md5Core(
        block_size=64,
        digest_size=16,
        buf=list(self.buf),
        total=self.total,
        h=list(self.h)
    );
}

impl Sha1Core.block(b: list[int]) {
    w: list[int] = [];
    j: int = 0;
    while j < 16 {
        w.append(_be32(b, 4 * j));
        j += 1;
    }
    while j < 80 {
        w.append(_rotl32(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1));
        j += 1;
    }
    a: int = self.h[0];
    bb: int = self.h[1];
    c: int = self.h[2];
    d: int = self.h[3];
    e: int = self.h[4];
    i: int = 0;
    while i < 80 {
        f: int = 0;
        k: int = 0;
        if i < 20 {
            f = (bb & c) | (~bb & d);
            k = 0x5A827999;
        } elif i < 40 {
            f = bb ^ c ^ d;
            k = 0x6ED9EBA1;
        } elif i < 60 {
            f = (bb & c) | (bb & d) | (c & d);
            k = 0x8F1BBCDC;
        } else {
            f = bb ^ c ^ d;
            k = 0xCA62C1D6;
        }
        t: int = (_rotl32(a, 5) + (f & _M32) + e + k + w[i]) & _M32;
        e = d;
        d = c;
        c = _rotl32(bb, 30);
        bb = a;
        a = t;
        i += 1;
    }
    self.h[0] = (self.h[0] + a) & _M32;
    self.h[1] = (self.h[1] + bb) & _M32;
    self.h[2] = (self.h[2] + c) & _M32;
    self.h[3] = (self.h[3] + d) & _M32;
    self.h[4] = (self.h[4] + e) & _M32;
}

impl Sha1Core.finish -> bytes {
    t = self.dup();
    _pad_md(t, 8, False);
    st: list[int] = t.h;
    out: list[int] = [];
    i: int = 0;
    while i < 5 {
        k: int = 3;
        while k >= 0 {
            out.append((st[i] >> (8 * k)) & 255);
            k -= 1;
        }
        i += 1;
    }
    return bytes(out);
}

impl Sha1Core.clone -> DigestCore {
    return self.dup();
}

impl Sha1Core.dup -> Sha1Core {
    return Sha1Core(
        block_size=64,
        digest_size=20,
        buf=list(self.buf),
        total=self.total,
        h=list(self.h)
    );
}

impl Sha256Core.block(b: list[int]) {
    w: list[int] = [];
    j: int = 0;
    while j < 16 {
        w.append(_be32(b, 4 * j));
        j += 1;
    }
    while j < 64 {
        x: int = w[j - 15];
        y: int = w[j - 2];
        s0: int = _rotr32(x, 7) ^ _rotr32(x, 18) ^ (x >> 3);
        s1: int = _rotr32(y, 17) ^ _rotr32(y, 19) ^ (y >> 10);
        w.append((w[j - 16] + s0 + w[j - 7] + s1) & _M32);
        j += 1;
    }
    a: int = self.h[0];
    bb: int = self.h[1];
    c: int = self.h[2];
    d: int = self.h[3];
    e: int = self.h[4];
    f: int = self.h[5];
    g: int = self.h[6];
    hh: int = self.h[7];
    i: int = 0;
    while i < 64 {
        big1: int = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
        ch: int = (e & f) ^ (~e & g);
        t1: int = (hh + big1 + (ch & _M32) + _SHA256_K[i] + w[i]) & _M32;
        big0: int = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
        mj: int = (a & bb) ^ (a & c) ^ (bb & c);
        hh = g;
        g = f;
        f = e;
        e = (d + t1) & _M32;
        d = c;
        c = bb;
        bb = a;
        a = (t1 + big0 + mj) & _M32;
        i += 1;
    }
    self.h[0] = (self.h[0] + a) & _M32;
    self.h[1] = (self.h[1] + bb) & _M32;
    self.h[2] = (self.h[2] + c) & _M32;
    self.h[3] = (self.h[3] + d) & _M32;
    self.h[4] = (self.h[4] + e) & _M32;
    self.h[5] = (self.h[5] + f) & _M32;
    self.h[6] = (self.h[6] + g) & _M32;
    self.h[7] = (self.h[7] + hh) & _M32;
}

impl Sha256Core.finish -> bytes {
    t = self.dup();
    _pad_md(t, 8, False);
    st: list[int] = t.h;
    out: list[int] = [];
    i: int = 0;
    while i < 8 {
        k: int = 3;
        while k >= 0 {
            out.append((st[i] >> (8 * k)) & 255);
            k -= 1;
        }
        i += 1;
    }
    return bytes(out[:self.digest_size]);
}

impl Sha256Core.clone -> DigestCore {
    return self.dup();
}

impl Sha256Core.dup -> Sha256Core {
    return Sha256Core(
        block_size=64,
        digest_size=self.digest_size,
        buf=list(self.buf),
        total=self.total,
        h=list(self.h)
    );
}

impl Sha512Core.block(b: list[int]) {
    w: list[u64] = [];
    j: int = 0;
    while j < 16 {
        w.append(_be64(b, 8 * j));
        j += 1;
    }
    while j < 80 {
        x: u64 = w[j - 15];
        y: u64 = w[j - 2];
        s0: u64 = _rotr64(x, 1) ^ _rotr64(x, 8) ^ (x >> 7);
        s1: u64 = _rotr64(y, 19) ^ _rotr64(y, 61) ^ (y >> 6);
        w.append(wrapping_add(wrapping_add(w[j - 16], s0), wrapping_add(w[j - 7], s1)));
        j += 1;
    }
    a: u64 = self.h[0];
    bb: u64 = self.h[1];
    c: u64 = self.h[2];
    d: u64 = self.h[3];
    e: u64 = self.h[4];
    f: u64 = self.h[5];
    g: u64 = self.h[6];
    hh: u64 = self.h[7];
    i: int = 0;
    while i < 80 {
        big1: u64 = _rotr64(e, 14) ^ _rotr64(e, 18) ^ _rotr64(e, 41);
        ch: u64 = (e & f) ^ (~e & g);
        t1: u64 = wrapping_add(
            wrapping_add(wrapping_add(hh, big1), wrapping_add(ch, _SHA512_K[i])), w[i]
        );
        big0: u64 = _rotr64(a, 28) ^ _rotr64(a, 34) ^ _rotr64(a, 39);
        mj: u64 = (a & bb) ^ (a & c) ^ (bb & c);
        hh = g;
        g = f;
        f = e;
        e = wrapping_add(d, t1);
        d = c;
        c = bb;
        bb = a;
        a = wrapping_add(t1, wrapping_add(big0, mj));
        i += 1;
    }
    self.h[0] = wrapping_add(self.h[0], a);
    self.h[1] = wrapping_add(self.h[1], bb);
    self.h[2] = wrapping_add(self.h[2], c);
    self.h[3] = wrapping_add(self.h[3], d);
    self.h[4] = wrapping_add(self.h[4], e);
    self.h[5] = wrapping_add(self.h[5], f);
    self.h[6] = wrapping_add(self.h[6], g);
    self.h[7] = wrapping_add(self.h[7], hh);
}

impl Sha512Core.finish -> bytes {
    t = self.dup();
    _pad_md(t, 16, False);
    st: list[u64] = t.h;
    out: list[int] = [];
    i: int = 0;
    while i < 8 {
        k: int = 7;
        while k >= 0 {
            out.append(int((st[i] >> (8 * k)) & u64(255)));
            k -= 1;
        }
        i += 1;
    }
    return bytes(out[:self.digest_size]);
}

impl Sha512Core.clone -> DigestCore {
    return self.dup();
}

impl Sha512Core.dup -> Sha512Core {
    return Sha512Core(
        block_size=128,
        digest_size=self.digest_size,
        buf=list(self.buf),
        total=self.total,
        h=list(self.h)
    );
}

impl _keccak(a: list[u64]) {
    c: list[u64] = [u64(0), u64(0), u64(0), u64(0), u64(0)];
    bl: list[u64] = [];
    k: int = 0;
    while k < 25 {
        bl.append(u64(0));
        k += 1;
    }
    r: int = 0;
    while r < 24 {
        x: int = 0;
        while x < 5 {
            c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
            x += 1;
        }
        x = 0;
        while x < 5 {
            dv: u64 = c[(x + 4) % 5] ^ _rotl64(c[(x + 1) % 5], 1);
            y: int = 0;
            while y < 5 {
                a[x + 5 * y] = a[x + 5 * y] ^ dv;
                y += 1;
            }
            x += 1;
        }
        x = 0;
        while x < 5 {
            y: int = 0;
            while y < 5 {
                bl[y + 5 * ((2 * x + 3 * y) % 5)] = _rotl64(
                    a[x + 5 * y], _KECCAK_ROT[x + 5 * y]
                );
                y += 1;
            }
            x += 1;
        }
        x = 0;
        while x < 5 {
            y: int = 0;
            while y < 5 {
                a[x + 5 * y] = bl[x + 5 * y]
                    ^ (~bl[(x + 1) % 5 + 5 * y] & bl[(x + 2) % 5 + 5 * y]);
                y += 1;
            }
            x += 1;
        }
        a[0] = a[0] ^ _KECCAK_RC[r];
        r += 1;
    }
}

impl Sha3Core.block(b: list[int]) {
    lanes: int = self.block_size // 8;
    j: int = 0;
    while j < lanes {
        self.a[j] = self.a[j] ^ _le64(b, 8 * j);
        j += 1;
    }
    _keccak(self.a);
}

impl Sha3Core.finish -> bytes {
    t = self.dup();
    blk: list[int] = list(self.buf);
    blk.append(0x06);
    while len(blk) < self.block_size {
        blk.append(0);
    }
    blk[self.block_size - 1] = blk[self.block_size - 1] | 0x80;
    t.block(blk);
    st: list[u64] = t.a;
    out: list[int] = [];
    i: int = 0;
    while len(out) < self.digest_size {
        out.append(int((st[i // 8] >> (8 * (i % 8))) & u64(255)));
        i += 1;
    }
    return bytes(out);
}

impl Sha3Core.clone -> DigestCore {
    return self.dup();
}

impl Sha3Core.dup -> Sha3Core {
    return Sha3Core(
        block_size=self.block_size,
        digest_size=self.digest_size,
        buf=list(self.buf),
        total=self.total,
        a=list(self.a)
    );
}

impl Blake2sCore.update(data: bytes) {
    n: int = len(data);
    i: int = 0;
    while i < n {
        if len(self.buf) == 64 {
            self.t += 64;
            self.compress(self.buf, False);
            self.buf = [];
        }
        self.buf.append(data[i]);
        i += 1;
    }
    self.total += n;
}

impl Blake2sCore.block(b: list[int]) {
    self.compress(b, False);
}

impl Blake2sCore.compress(b: list[int], last: bool) {
    m: list[int] = [];
    j: int = 0;
    while j < 16 {
        m.append(_le32(b, 4 * j));
        j += 1;
    }
    v: list[int] = list(self.h);
    j = 0;
    while j < 8 {
        v.append(_SHA256_IV[j]);
        j += 1;
    }
    v[12] = v[12] ^ (self.t & _M32);
    v[13] = v[13] ^ ((self.t >> 32) & _M32);
    if last {
        v[14] = v[14] ^ _M32;
    }
    rnd: int = 0;
    while rnd < 10 {
        s: int = 16 * (rnd % 10);
        q: int = 0;
        while q < 8 {
            ia: int = q % 4;
            ib: int = 4 + ((q + (q // 4)) % 4);
            ic: int = 8 + ((q + 2 * (q // 4)) % 4);
            id: int = 12 + ((q + 3 * (q // 4)) % 4);
            mx: int = m[_BLAKE2_SIGMA[s + 2 * q]];
            my: int = m[_BLAKE2_SIGMA[s + 2 * q + 1]];
            v[ia] = (v[ia] + v[ib] + mx) & _M32;
            v[id] = _rotr32(v[id] ^ v[ia], 16);
            v[ic] = (v[ic] + v[id]) & _M32;
            v[ib] = _rotr32(v[ib] ^ v[ic], 12);
            v[ia] = (v[ia] + v[ib] + my) & _M32;
            v[id] = _rotr32(v[id] ^ v[ia], 8);
            v[ic] = (v[ic] + v[id]) & _M32;
            v[ib] = _rotr32(v[ib] ^ v[ic], 7);
            q += 1;
        }
        rnd += 1;
    }
    j = 0;
    while j < 8 {
        self.h[j] = self.h[j] ^ v[j] ^ v[j + 8];
        j += 1;
    }
}

impl Blake2sCore.finish -> bytes {
    t = self.dup();
    t.t = self.t + len(self.buf);
    blk: list[int] = list(self.buf);
    while len(blk) < 64 {
        blk.append(0);
    }
    t.compress(blk, True);
    out: list[int] = [];
    i: int = 0;
    while i < 8 {
        k: int = 0;
        while k < 4 {
            out.append((t.h[i] >> (8 * k)) & 255);
            k += 1;
        }
        i += 1;
    }
    return bytes(out);
}

impl Blake2sCore.clone -> DigestCore {
    return self.dup();
}

impl Blake2sCore.dup -> Blake2sCore {
    return Blake2sCore(
        block_size=64,
        digest_size=32,
        buf=list(self.buf),
        total=self.total,
        h=list(self.h),
        t=self.t
    );
}

impl Blake2bCore.update(data: bytes) {
    n: int = len(data);
    i: int = 0;
    while i < n {
        if len(self.buf) == 128 {
            self.t += 128;
            self.compress(self.buf, False);
            self.buf = [];
        }
        self.buf.append(data[i]);
        i += 1;
    }
    self.total += n;
}

impl Blake2bCore.block(b: list[int]) {
    self.compress(b, False);
}

impl Blake2bCore.compress(b: list[int], last: bool) {
    m: list[u64] = [];
    j: int = 0;
    while j < 16 {
        m.append(_le64(b, 8 * j));
        j += 1;
    }
    v: list[u64] = list(self.h);
    j = 0;
    while j < 8 {
        v.append(_SHA512_IV[j]);
        j += 1;
    }
    v[12] = v[12] ^ u64(self.t);
    if last {
        v[14] = ~v[14];
    }
    rnd: int = 0;
    while rnd < 12 {
        s: int = 16 * (rnd % 10);
        q: int = 0;
        while q < 8 {
            ia: int = q % 4;
            ib: int = 4 + ((q + (q // 4)) % 4);
            ic: int = 8 + ((q + 2 * (q // 4)) % 4);
            id: int = 12 + ((q + 3 * (q // 4)) % 4);
            mx: u64 = m[_BLAKE2_SIGMA[s + 2 * q]];
            my: u64 = m[_BLAKE2_SIGMA[s + 2 * q + 1]];
            v[ia] = wrapping_add(wrapping_add(v[ia], v[ib]), mx);
            v[id] = _rotr64(v[id] ^ v[ia], 32);
            v[ic] = wrapping_add(v[ic], v[id]);
            v[ib] = _rotr64(v[ib] ^ v[ic], 24);
            v[ia] = wrapping_add(wrapping_add(v[ia], v[ib]), my);
            v[id] = _rotr64(v[id] ^ v[ia], 16);
            v[ic] = wrapping_add(v[ic], v[id]);
            v[ib] = _rotr64(v[ib] ^ v[ic], 63);
            q += 1;
        }
        rnd += 1;
    }
    j = 0;
    while j < 8 {
        self.h[j] = self.h[j] ^ v[j] ^ v[j + 8];
        j += 1;
    }
}

impl Blake2bCore.finish -> bytes {
    t = self.dup();
    t.t = self.t + len(self.buf);
    blk: list[int] = list(self.buf);
    while len(blk) < 128 {
        blk.append(0);
    }
    t.compress(blk, True);
    out: list[int] = [];
    i: int = 0;
    while i < 8 {
        k: int = 0;
        while k < 8 {
            out.append(int((t.h[i] >> (8 * k)) & u64(255)));
            k += 1;
        }
        i += 1;
    }
    return bytes(out);
}

impl Blake2bCore.clone -> DigestCore {
    return self.dup();
}

impl Blake2bCore.dup -> Blake2bCore {
    return Blake2bCore(
        block_size=128,
        digest_size=64,
        buf=list(self.buf),
        total=self.total,
        h=list(self.h),
        t=self.t
    );
}

impl new_core(name: str) -> (DigestCore | None) {
    if name == "md5" {
        return Md5Core(block_size=64, digest_size=16);
    } elif name == "sha1" {
        return Sha1Core(block_size=64, digest_size=20);
    } elif name == "sha224" {
        return Sha256Core(block_size=64, digest_size=28, h=list(_SHA224_IV));
    } elif name == "sha256" {
        return Sha256Core(block_size=64, digest_size=32, h=list(_SHA256_IV));
    } elif name == "sha384" {
        return Sha512Core(block_size=128, digest_size=48, h=list(_SHA384_IV));
    } elif name == "sha512" {
        return Sha512Core(block_size=128, digest_size=64, h=list(_SHA512_IV));
    } elif name in ["sha3_224", "sha3_256", "sha3_384", "sha3_512"] {
        size: int = core_digest_size(name);
        lanes: list[u64] = [];
        while len(lanes) < 25 {
            lanes.append(u64(0));
        }
        return Sha3Core(block_size=200 - 2 * size, digest_size=size, a=lanes);
    } elif name == "blake2s" {
        hs: list[int] = list(_SHA256_IV);
        hs[0] = hs[0] ^ 0x01010020;
        return Blake2sCore(block_size=64, digest_size=32, h=hs);
    } elif name == "blake2b" {
        hb: list[u64] = list(_SHA512_IV);
        hb[0] = hb[0] ^ u64(0x01010040);
        return Blake2bCore(block_size=128, digest_size=64, h=hb);
    }
    return None;
}

impl core_block_size(name: str) -> int {
    if name in ["md5", "sha1", "sha224", "sha256", "blake2s"] {
        return 64;
    } elif name in ["sha384", "sha512", "blake2b"] {
        return 128;
    } elif name in ["sha3_224", "sha3_256", "sha3_384", "sha3_512"] {
        return 200 - 2 * core_digest_size(name);
    }
    return 0;
}

impl core_digest_size(name: str) -> int {
    if name == "md5" {
        return 16;
    } elif name == "sha1" {
        return 20;
    } elif name in ["sha224", "sha3_224"] {
        return 28;
    } elif name in ["sha256", "sha3_256", "blake2s"] {
        return 32;
    } elif name in ["sha384", "sha3_384"] {
        return 48;
    } elif name in ["sha512", "sha3_512", "blake2b"] {
        return 64;
    }
    return 0;
}
