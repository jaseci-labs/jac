"""Bundled native `hashlib` — pure-Jac Mechanism-B standard library (issues
#6404 / #6940 / #6964).

On the native (na) pathway `import hashlib;` (or `import from hashlib { sha256 }`)
resolves to this module through the shared bundled-stdlib resolver; on the
sv/Python pathway the identical import binds CPython's real `hashlib`. The two
are held congruent by the tri-backend equivalence suite (prim_hashlib.jac).

Unlike the libz/libcurl floors (Mechanism F), SHA-256 is implemented here in
pure Jac over 32-bit integer arithmetic (FIPS 180-4), so it is **portable to
every native target** (ELF / Mach-O / PE / WASM) with no system library — the
preferred Mechanism-B tier. Native `int` is 64-bit, so each 32-bit lane is kept
canonical with an explicit `& 0xFFFFFFFF` after every add / shift.

SCOPE: `sha256()` (the digest the workload needs — content-addressing release
artifacts). `update(data)` accepts `bytes` and may be called repeatedly;
`hexdigest()` / `digest()` finalize over the full accumulated message. Other
constructors (`sha1`, `sha512`, `md5`, ...) layer on the same skeleton and are a
mechanical follow-up.
"""

# SHA-256 round constants (FIPS 180-4 §4.2.2): first 32 bits of the fractional
# parts of the cube roots of the first 64 primes. Built as a function-local list
# inside `_sha256_state` (see `_sha256_k()`), NOT a module `glob`: a runtime-
# initialized global would need its owning module's `__jac_glob_init` to have
# run, which an entry-less consumer (e.g. an `import from hashlib` fixture with
# no `with entry`) does not chain — leaving the table null and segfaulting. A
# self-contained module needs no cross-module initializer ordering.
"""The 64 SHA-256 round constants (FIPS 180-4 §4.2.2)."""
def _sha256_k() -> list[int] {
    return [
        0x428a2f98,
        0x71374491,
        0xb5c0fbcf,
        0xe9b5dba5,
        0x3956c25b,
        0x59f111f1,
        0x923f82a4,
        0xab1c5ed5,
        0xd807aa98,
        0x12835b01,
        0x243185be,
        0x550c7dc3,
        0x72be5d74,
        0x80deb1fe,
        0x9bdc06a7,
        0xc19bf174,
        0xe49b69c1,
        0xefbe4786,
        0x0fc19dc6,
        0x240ca1cc,
        0x2de92c6f,
        0x4a7484aa,
        0x5cb0a9dc,
        0x76f988da,
        0x983e5152,
        0xa831c66d,
        0xb00327c8,
        0xbf597fc7,
        0xc6e00bf3,
        0xd5a79147,
        0x06ca6351,
        0x14292967,
        0x27b70a85,
        0x2e1b2138,
        0x4d2c6dfc,
        0x53380d13,
        0x650a7354,
        0x766a0abb,
        0x81c2c92e,
        0x92722c85,
        0xa2bfe8a1,
        0xa81a664b,
        0xc24b8b70,
        0xc76c51a3,
        0xd192e819,
        0xd6990624,
        0xf40e3585,
        0x106aa070,
        0x19a4c116,
        0x1e376c08,
        0x2748774c,
        0x34b0bcb5,
        0x391c0cb3,
        0x4ed8aa4a,
        0x5b9cca4f,
        0x682e6ff3,
        0x748f82ee,
        0x78a5636f,
        0x84c87814,
        0x8cc70208,
        0x90befffa,
        0xa4506ceb,
        0xbef9a3f7,
        0xc67178f2
    ];
}


"""32-bit right-rotation of `x` by `n` bits (FIPS 180-4 ROTR)."""
def _rotr(x: int, n: int) -> int {
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
}


"""Lowercase hex string of a 32-bit word, zero-padded to 8 nibbles."""
def _hex32(w: int) -> str {
    digits: str = "0123456789abcdef";
    out: str = "";
    shift: int = 28;
    while shift >= 0 {
        nib: int = (w >> shift) & 0xF;
        out = out + digits[nib];
        shift = shift - 4;
    }
    return out;
}


"""Core SHA-256 compression (FIPS 180-4). Returns the 8 final state words for
the complete message `msg`, padded internally. Pure 32-bit integer math."""
def _sha256_state(msg: bytes) -> list[int] {
    # Initial hash values: first 32 bits of the fractional parts of the square
    # roots of the first 8 primes.
    h0: int = 0x6a09e667;
    h1: int = 0xbb67ae85;
    h2: int = 0x3c6ef372;
    h3: int = 0xa54ff53a;
    h4: int = 0x510e527f;
    h5: int = 0x9b05688c;
    h6: int = 0x1f83d9ab;
    h7: int = 0x5be0cd19;
    # Padding: 0x80, then zeros to 56 mod 64, then the 64-bit big-endian bit
    # length (FIPS 180-4 §5.1.1).
    ml: int = len(msg);
    bitlen: int = ml * 8;
    # Zero-pad count so (ml + 1 + nzero + 8) is a multiple of 64. Written with
    # only NON-NEGATIVE operands to `%`: the native backend's `%` follows C
    # truncated semantics (sign of the dividend), not Python's floored modulo,
    # so a `(56 - (ml + 1)) % 64` form would go negative for ml >= 56 and drop
    # the padding entirely. `ml + 9` (= 0x80 byte + 8 length bytes) is always
    # positive, keeping both `%` operands non-negative.
    nzero: int = (64 - (ml + 9) % 64) % 64;
    padded: bytes = msg + b"\x80" + b"\x00" * nzero + bitlen.to_bytes(8, "big");
    k: list[int] = _sha256_k();
    mask: int = 0xFFFFFFFF;
    nblocks: int = len(padded) // 64;
    blk: int = 0;
    while blk < nblocks {
        base: int = blk * 64;
        # Message schedule W[0..63]; W[0..15] are the block's big-endian words.
        w: list[int] = [];
        t: int = 0;
        while t < 16 {
            j: int = base + t * 4;
            word: int = (
                (padded[j] << 24) | (padded[j + 1] << 16) | (padded[j + 2] << 8) | padded[
                    j + 3
                ]
            );
            w.append(word);
            t = t + 1;
        }
        while t < 64 {
            s0: int = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
            s1: int = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
            w.append((w[t - 16] + s0 + w[t - 7] + s1) & mask);
            t = t + 1;
        }
        a: int = h0;
        b: int = h1;
        c: int = h2;
        d: int = h3;
        e: int = h4;
        f: int = h5;
        g: int = h6;
        hh: int = h7;
        t = 0;
        while t < 64 {
            s1c: int = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
            ch: int = (e & f) ^ ((e ^ mask) & g);
            temp1: int = (hh + s1c + ch + k[t] + w[t]) & mask;
            s0c: int = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
            maj: int = (a & b) ^ (a & c) ^ (b & c);
            temp2: int = (s0c + maj) & mask;
            hh = g;
            g = f;
            f = e;
            e = (d + temp1) & mask;
            d = c;
            c = b;
            b = a;
            a = (temp1 + temp2) & mask;
            t = t + 1;
        }
        h0 = (h0 + a) & mask;
        h1 = (h1 + b) & mask;
        h2 = (h2 + c) & mask;
        h3 = (h3 + d) & mask;
        h4 = (h4 + e) & mask;
        h5 = (h5 + f) & mask;
        h6 = (h6 + g) & mask;
        h7 = (h7 + hh) & mask;
        blk = blk + 1;
    }
    return [h0, h1, h2, h3, h4, h5, h6, h7];
}


"""A SHA-256 hash object (CPython `hashlib.sha256`-shaped). `update(data)`
accumulates the message; `hexdigest()` / `digest()` finalize. The message is
buffered and hashed in one finalize pass — correct for the workload's sizes;
incremental block streaming is a follow-up if a huge-input case appears."""
obj _Sha256 {
    has _buf: bytes = b"";
    static has digest_size: int = 32;
    static has block_size: int = 64;

    """Feed more bytes into the running hash."""
    def update(data: bytes) -> None {
        self._buf = self._buf + data;
    }

    """The digest as a 64-character lowercase hex string."""
    def hexdigest() -> str {
        st: list[int] = _sha256_state(self._buf);
        out: str = "";
        i: int = 0;
        while i < 8 {
            out = out + _hex32(st[i]);
            i = i + 1;
        }
        return out;
    }

    """The digest as 32 raw bytes."""
    def digest() -> bytes {
        st: list[int] = _sha256_state(self._buf);
        out: bytes = b"";
        i: int = 0;
        while i < 8 {
            out = out + st[i].to_bytes(4, "big");
            i = i + 1;
        }
        return out;
    }
}


"""Return a new SHA-256 hash object (CPython `hashlib.sha256()`). Seed it with
`sha256().update(data)` — the optional one-shot `sha256(data)` constructor
argument rides on native default-`bytes` parameter support, a separate gap."""
def:pub sha256() -> _Sha256 {
    return _Sha256();
}
