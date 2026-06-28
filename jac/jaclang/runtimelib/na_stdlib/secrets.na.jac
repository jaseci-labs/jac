"""Bundled native `secrets` — pure-Jac surface over the libcrypto CSPRNG floor.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6978 Phase 1). On the native (na) pathway
`import secrets` / `import from secrets { token_hex, ... }` resolves to this
module through the shared bundled-stdlib resolver; on the sv/Python pathway the
identical import binds CPython's real `secrets`. The two are held congruent by
the tri-backend equivalence suite (prim_secrets.jac) -- which, since the outputs
are RANDOM, asserts the deterministic *properties* (lengths, hex/urlsafe
alphabets, range bounds, distinctness) rather than exact bytes.

Mechanism-F architecture (#6978): randomness is never reimplemented -- it is
OpenSSL's `RAND_bytes`, reached through the thin FFI floor in
`_csprng_native.na.jac` (the same bundled `libcrypto.a` the hashlib floor uses).
This module is the stable, Python-shaped API on top: the `token_*` helpers and
`randbelow`, mirroring CPython's argument shapes (default entropy = 32 bytes).

Coverage (issue #6978 partial-coverage policy): `token_bytes`, `token_hex`,
`token_urlsafe`, `randbelow`. `choice`/`randbits`/`SystemRandom` and
`compare_digest` are follow-ups.

PORTABILITY: native-host-only (inherited from the libcrypto floor).
"""

import from _csprng_native { csprng_bytes, to_hex }


"""`nbytes` cryptographically-secure random bytes (CPython `secrets.token_bytes`).

CPython defaults `nbytes=None` to 32 (`DEFAULT_ENTROPY`); the native surface
takes the resolved default directly."""
def:pub token_bytes(nbytes: int = 32) -> bytes {
    return csprng_bytes(nbytes);
}


"""A random text token of `nbytes` bytes as a hex string (CPython `token_hex`).

The result is `2 * nbytes` lowercase hex characters."""
def:pub token_hex(nbytes: int = 32) -> str {
    return to_hex(csprng_bytes(nbytes));
}


"""A random URL-safe text token of `nbytes` bytes (CPython `token_urlsafe`).

Base64-url (`A-Za-z0-9-_`) of `nbytes` random bytes with the `=` padding
stripped, exactly as CPython renders it."""
def:pub token_urlsafe(nbytes: int = 32) -> str {
    data = csprng_bytes(nbytes);
    alphabet: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    out: str = "";
    n: int = len(data);
    i: int = 0;
    while i + 3 <= n {
        b0: int = data[i];
        b1: int = data[i + 1];
        b2: int = data[i + 2];
        out += alphabet[b0 >> 2];
        out += alphabet[((b0 & 3) << 4) | (b1 >> 4)];
        out += alphabet[((b1 & 15) << 2) | (b2 >> 6)];
        out += alphabet[b2 & 63];
        i += 3;
    }
    rem: int = n - i;
    if rem == 1 {
        b0: int = data[i];
        out += alphabet[b0 >> 2];
        out += alphabet[(b0 & 3) << 4];
    } elif rem == 2 {
        b0: int = data[i];
        b1: int = data[i + 1];
        out += alphabet[b0 >> 2];
        out += alphabet[((b0 & 3) << 4) | (b1 >> 4)];
        out += alphabet[(b1 & 15) << 2];
    }
    return out;
}


"""A random int in `[0, exclusive_upper_bound)` (CPython `secrets.randbelow`).

Uniform via rejection sampling over the smallest whole number of CSPRNG bytes
covering the bound's bit length -- the same construction as CPython's
`SystemRandom._randbelow`. Raises `ValueError` for a non-positive bound."""
def:pub randbelow(exclusive_upper_bound: int) -> int {
    if exclusive_upper_bound <= 0 {
        raise ValueError("Upper bound must be positive.");
    }
    bits: int = 0;
    t: int = exclusive_upper_bound;
    while t > 0 {
        bits += 1;
        t = t >> 1;
    }
    nbytes: int = (bits + 7) // 8;
    mask: int = (1 << bits) - 1;
    # Seed `r` at the bound so the rejection loop runs at least once; each pass
    # draws `nbytes` CSPRNG bytes, keeps the low `bits` bits, and retries while
    # the value is still >= the bound. (A condition-driven loop rather than
    # `while True` so the checker can see the function always returns.)
    r: int = exclusive_upper_bound;
    while r >= exclusive_upper_bound {
        data = csprng_bytes(nbytes);
        r = 0;
        i: int = 0;
        while i < nbytes {
            r = (r << 8) | data[i];
            i += 1;
        }
        r = r & mask;
    }
    return r;
}
