"""FFI floor for the bundled native `secrets`/`uuid` CSPRNG — Mechanism F over libcrypto.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6978 Phase 1). It is the thin
cryptographically-secure-randomness primitive the `secrets` surface is built on
(and `uuid.uuid4`, once native `__str__` lands): a single `RAND_bytes` FFI to
OpenSSL's `libcrypto` (the same bundled `libcrypto.a` floor the `hashlib`/`hmac`
modules already link), resolved by logical name `crypto`. CPython's `secrets`
draws from `os.urandom` (the OS CSPRNG); OpenSSL's `RAND_bytes` is seeded from
that same OS entropy, so it is an equivalent CSPRNG source -- and reusing the
libcrypto floor keeps the native CSPRNG cross-platform (Linux/macOS/Windows)
with no new compiler intrinsic.

PORTABILITY: native-host-only (inherited from the libcrypto floor). One clib
`def` per `import from crypto` block keeps each signature diffable (matching the
`_hashlib_native` floor).
"""

# --- libcrypto CSPRNG: `int RAND_bytes(unsigned char *buf, int num)` writes
# `num` cryptographically-secure bytes into buf, returning 1 on success. ---
import from crypto { def RAND_bytes(buf: bytes, num: i32) -> i32;  }


"""`n` cryptographically-secure random bytes (the `os.urandom(n)` equivalent).

A zero-filled, runtime-allocated (hence WRITABLE) `bytes` buffer is handed to
`RAND_bytes`, which fills it in place; a bytes LITERAL would land in read-only
`.rodata` and segfault when the C side writes. `RAND_bytes` returns 0 on failure
(entropy source unavailable) -- surfaced as a `ValueError` rather than handing
back the zero buffer as "randomness" (the worst failure mode for a CSPRNG)."""
def:pub csprng_bytes(n: int) -> bytes {
    if n <= 0 {
        return b"";
    }
    out = b"\x00" * n;
    if RAND_bytes(out, n) != 1 {
        raise ValueError("RAND_bytes failed (CSPRNG entropy unavailable)");
    }
    return out;
}


"""Lowercase hex of `data` (CPython `bytes.hex()` rendering).

Duplicated from the `_hashlib_native` floor so the CSPRNG modules do not pull in
the digest FFI just to render `token_hex` / a `uuid` string."""
def:pub to_hex(data: bytes) -> str {
    digits: str = "0123456789abcdef";
    out: str = "";
    n: int = len(data);
    i: int = 0;
    while i < n {
        v: int = data[i];
        out += digits[(v // 16) % 16];
        out += digits[v % 16];
        i += 1;
    }
    return out;
}
