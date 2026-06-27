"""FFI floor for the bundled native `hashlib`/`hmac` — Mechanism F over libcrypto.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6978 Phase 1). This is the thin FFI
binding the roadmap calls the bundled-C floor: it never reimplements a digest, it
forwards to OpenSSL's `libcrypto` (resolved by logical name `crypto` →
`libcrypto.so` / `.dylib` / `crypto.dll`), exactly as CPython's `_hashlib` is a
wrapper over the same library. The Python-congruent surfaces that programs call
(`hashlib`, `hmac`) are the pure-Jac modules layered on top of these primitives.

This is the FIRST F-module over `libcrypto` (#6978 Phase 0.2 staged the archive
into the payload; Phase 0.1a built static-archive linking): it proves the large
`libcrypto.a` static-links and runs before the security-critical `ssl` floor is
built on the same archive (Phase 1 proper).

DIGEST STREAMING. CPython's `_hashlib` keeps a live `EVP_MD_CTX` per object and
`EVP_MD_CTX_copy`s it on `.digest()` (so the digest is non-consuming). To avoid
holding an un-freeable C context for the lifetime of a Jac object (the na object
model has no guaranteed finalizer here), this floor instead computes each digest
in one shot over the caller's accumulated `list[bytes]` chunks: a fresh ctx is
created, fed each chunk, finalized, and freed within `evp_digest`/`hmac_digest`.
Output is byte-identical to CPython; `.digest()` stays non-consuming because the
chunk list is re-fed each call. The accumulate-then-digest tradeoff (chunks held
in memory vs. true streaming) is a perf follow-up, not a correctness gap.

A `bytes` argument lowers to its raw data pointer (the C buffer-protocol
convention); the element count travels through the explicit length parameter.
Opaque C handles (`EVP_MD_CTX*`, `HMAC_CTX*`, `const EVP_MD*`) are carried as
plain `int` (pointer-sized, never refcounted), as the urllib/curl floor does.
`EVP_DigestFinal_ex`'s `unsigned int *s` out-param is a 4-byte scratch buffer the
C side writes the digest length into; we ignore it (the length is known from the
algorithm) but must pass a valid pointer.

PORTABILITY: native-host-only (A/F tier). libcrypto exists on Linux/macOS/Windows
native targets but not on bare wasm, so a wasm target gets a clean link error
rather than silent breakage. One clib `def` per `import from crypto` block keeps
each signature on its own readable, diffable line (matching the libz floor).
"""

# --- libcrypto EVP message-digest API (the streaming digest primitives). ---
import from crypto { def EVP_MD_CTX_new -> int;  }
import from crypto { def EVP_MD_CTX_free(ctx: int) -> None;  }
import from crypto { def EVP_DigestInit_ex(ctx: int, md: int, engine: int) -> i32;  }
import from crypto { def EVP_DigestUpdate(ctx: int, data: bytes, n: u64) -> i32;  }
import from crypto {
    def EVP_DigestFinal_ex(ctx: int, md_out: bytes, outlen: bytes) -> i32;
}

# --- libcrypto EVP_MD* selectors (one const handle per algorithm). ---
import from crypto { def EVP_md5 -> int;  }
import from crypto { def EVP_sha1 -> int;  }
import from crypto { def EVP_sha224 -> int;  }
import from crypto { def EVP_sha256 -> int;  }
import from crypto { def EVP_sha384 -> int;  }
import from crypto { def EVP_sha512 -> int;  }
import from crypto { def EVP_sha3_256 -> int;  }
import from crypto { def EVP_sha3_512 -> int;  }

# --- libcrypto HMAC API (legacy HMAC_* ctx; present in the bundled 3.x). ---
import from crypto { def HMAC_CTX_new -> int;  }
import from crypto { def HMAC_CTX_free(ctx: int) -> None;  }
import from crypto {
    def HMAC_Init_ex(ctx: int, key: bytes, keylen: i32, md: int, engine: int) -> i32;
}
import from crypto { def HMAC_Update(ctx: int, data: bytes, n: u64) -> i32;  }
import from crypto { def HMAC_Final(ctx: int, md_out: bytes, outlen: bytes) -> i32;  }


"""The `EVP_MD*` selector for a CPython algorithm name, or 0 if unsupported.

Covers the always-built OpenSSL digests CPython's `hashlib` guarantees
(`md5`/`sha1`/`sha2-*`) plus the `sha3` pair; 0 lets the public surface raise a
Python-shaped `ValueError` for anything else."""
def:pub evp_md_for(name: str) -> int {
    if name == "md5" {
        return EVP_md5();
    } elif name == "sha1" {
        return EVP_sha1();
    } elif name == "sha224" {
        return EVP_sha224();
    } elif name == "sha256" {
        return EVP_sha256();
    } elif name == "sha384" {
        return EVP_sha384();
    } elif name == "sha512" {
        return EVP_sha512();
    } elif name == "sha3_256" {
        return EVP_sha3_256();
    } elif name == "sha3_512" {
        return EVP_sha3_512();
    }
    return 0;
}


"""Output size in bytes for a supported algorithm name (CPython `digest_size`)."""
def:pub digest_size_for(name: str) -> int {
    if name == "md5" {
        return 16;
    } elif name == "sha1" {
        return 20;
    } elif name == "sha224" {
        return 28;
    } elif name == "sha256" {
        return 32;
    } elif name == "sha384" {
        return 48;
    } elif name == "sha512" {
        return 64;
    } elif name == "sha3_256" {
        return 32;
    } elif name == "sha3_512" {
        return 64;
    }
    return 0;
}


"""Internal block size in bytes for a supported algorithm (CPython `block_size`)."""
def:pub block_size_for(name: str) -> int {
    if name == "md5" {
        return 64;
    } elif name == "sha1" {
        return 64;
    } elif name == "sha224" {
        return 64;
    } elif name == "sha256" {
        return 64;
    } elif name == "sha384" {
        return 128;
    } elif name == "sha512" {
        return 128;
    } elif name == "sha3_256" {
        return 136;
    } elif name == "sha3_512" {
        return 72;
    }
    return 0;
}


"""One-shot EVP digest of the concatenation of `chunks` under selector `md`.

A fresh `EVP_MD_CTX` is created, fed each chunk in order, finalized into a
`digest_size`-byte buffer, and freed — so no C context outlives the call. The
output buffer is a zero-filled `bytes` the C side writes into (the libz floor's
scratch-buffer convention); `outlen` is the required-but-ignored length scratch.

OpenSSL failures are not silent: `EVP_MD_CTX_new` returning NULL (`0`) would be
dereferenced by the next call (segfault), and the digest primitives return `1`
on success / `0` on failure (FIPS restrictions, engine errors, ...) — ignoring
them would hand back the zero-filled buffer as a "digest" for security-critical
data. Each is checked and surfaced as a `ValueError`, mirroring CPython's
`_hashlib`; the live context is freed before raising so a failure never leaks
it."""
def:pub evp_digest(md: int, chunks: list[bytes], digest_size: int) -> bytes {
    ctx: int = EVP_MD_CTX_new();
    if ctx == 0 {
        raise ValueError("EVP_MD_CTX_new failed (out of memory)");
    }
    if EVP_DigestInit_ex(ctx, md, 0) != 1 {
        EVP_MD_CTX_free(ctx);
        raise ValueError("EVP_DigestInit_ex failed");
    }
    for c in chunks {
        if EVP_DigestUpdate(ctx, c, len(c)) != 1 {
            EVP_MD_CTX_free(ctx);
            raise ValueError("EVP_DigestUpdate failed");
        }
    }
    out = b"\x00" * digest_size;
    # A repeat (`b"\x00" * 4`) is a runtime-allocated, WRITABLE buffer; a bytes
    # LITERAL would land in read-only .rodata and segfault when the C side writes
    # the digest length back through this `unsigned int *` out-param.
    outlen = b"\x00" * 4;
    if EVP_DigestFinal_ex(ctx, out, outlen) != 1 {
        EVP_MD_CTX_free(ctx);
        raise ValueError("EVP_DigestFinal_ex failed");
    }
    EVP_MD_CTX_free(ctx);
    return out;
}


"""One-shot HMAC of the concatenation of `chunks` under key `key`, selector `md`.

Same lifecycle as `evp_digest` over the legacy `HMAC_CTX` API: create, init with
the key + digest, update per chunk, finalize, free. NULL-ctx and `0` return
codes are checked and raised as `ValueError` (freeing the live context first),
exactly as in `evp_digest` — an unchecked HMAC failure would silently return a
zero buffer as an authentication tag."""
def:pub hmac_digest(
    md: int, key: bytes, chunks: list[bytes], digest_size: int
) -> bytes {
    ctx: int = HMAC_CTX_new();
    if ctx == 0 {
        raise ValueError("HMAC_CTX_new failed (out of memory)");
    }
    if HMAC_Init_ex(ctx, key, len(key), md, 0) != 1 {
        HMAC_CTX_free(ctx);
        raise ValueError("HMAC_Init_ex failed");
    }
    for c in chunks {
        if HMAC_Update(ctx, c, len(c)) != 1 {
            HMAC_CTX_free(ctx);
            raise ValueError("HMAC_Update failed");
        }
    }
    out = b"\x00" * digest_size;
    # A repeat (`b"\x00" * 4`) is a runtime-allocated, WRITABLE buffer; a bytes
    # LITERAL would land in read-only .rodata and segfault when the C side writes
    # the digest length back through this `unsigned int *` out-param.
    outlen = b"\x00" * 4;
    if HMAC_Final(ctx, out, outlen) != 1 {
        HMAC_CTX_free(ctx);
        raise ValueError("HMAC_Final failed");
    }
    HMAC_CTX_free(ctx);
    return out;
}


"""Lowercase hex of `data` (CPython `bytes.hex()` / `hexdigest()` rendering)."""
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
