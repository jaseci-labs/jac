---
description: The native hashlib and hmac modules, as CPython's, with every guaranteed algorithm written in Jac.
keywords: hashlib, hmac, hashlib.new, hashlib.sha256, hashlib.sha1, hashlib.md5, hashlib.sha512, hashlib.sha3_256, hashlib.blake2b, hashlib.shake_128, hashlib.pbkdf2_hmac, hashlib.scrypt, hashlib.file_digest, hashlib.algorithms_guaranteed, hashlib.algorithms_available, hmac.new, hmac.digest, hmac.compare_digest, hmac.HMAC, hash digest
---
# hashlib and hmac

`hashlib` computes message digests and `hmac` keyed digests, as CPython's modules do: the same
constructors, objects, digests, names and errors. Both are native, and every algorithm is
written in Jac, so a program links no OpenSSL for them (see [The library](index.md),
`jac docs library`).

```jac
import hashlib;
import hmac;

with entry {
    print(hashlib.sha256(b"abc").hexdigest());
    h = hashlib.new("SHA256");
    h.update(b"a");
    h.update(b"bc");
    print(h.name, h.digest_size, h.block_size, h.hexdigest()[:16]);
    print(hashlib.md5(b"").hexdigest(), hashlib.blake2b(b"x", digest_size=8).hexdigest());
    print(hashlib.shake_128(b"").hexdigest(8));
    print(hashlib.pbkdf2_hmac("sha256", b"password", b"salt", 1).hex()[:16]);
    mac = hmac.new(b"key", b"message", "sha256");
    print(mac.name, mac.hexdigest()[:16], hmac.compare_digest(b"abc", b"abc"));
}
```

```output
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
sha256 32 64 ba7816bf8f01cfea
d41d8cd98f00b204e9800998ecf8427e 4adf4367f96e584f
7f9c2ba4e88f827d
120fb6cffcf8b32c
hmac-sha256 6e9ef29b75fffc5b True
```

## What is there

**hashlib:**

| Names | What they are |
|---|---|
| `md5`, `sha1`, `sha224`, `sha256`, `sha384`, `sha512`, `sha3_224`, `sha3_256`, `sha3_384`, `sha3_512`, `shake_128`, `shake_256`, `blake2b`, `blake2s` | Constructors: each takes the first data (`bytes`, `bytearray` or `memoryview`) and `usedforsecurity=`; BLAKE2's take its parameters (`digest_size`, `key`, `salt`, `person`, ...) |
| `new(name, data=b"")` | A hash by name, OpenSSL's spellings included (`"SHA256"`, `"sha3-256"`, `"sha512-224"`, `"blake2b512"`); `.name` is the canonical name |
| A hash object | `update`, `digest`, `hexdigest`, `copy`, `name`, `digest_size`, `block_size`; SHAKE's `digest(length)` and `hexdigest(length)` |
| `pbkdf2_hmac`, `scrypt` | Key derivation, with CPython's checks and messages |
| `file_digest(fileobj, digest)` | The digest of a binary file object read to its end |
| `algorithms_guaranteed`, `algorithms_available` | Sets of names; the second adds `sha512_224` and `sha512_256` |

**hmac:** `new(key, msg=None, digestmod)`, the class `HMAC` (`update`, `copy`, `digest`,
`hexdigest`, `name`, `digest_size`, `block_size`), the one-shot `digest(key, msg, digest)`, and
`compare_digest(a, b)`, which takes two bytes-like values or two ASCII strs. `digestmod` is
required, as in CPython, and may not be a SHAKE algorithm.

The checks and messages are CPython's, among them: `digest_size` and `block_size` (`sha3_256`
32 and 136; `shake_128` 0 and 168); an unknown name raises
`ValueError: unsupported hash algorithm whirlpool`; a non-contiguous `memoryview` raises
`BufferError: memoryview: underlying buffer is not C-contiguous`; `digest(5)` on a fixed-size
hash and a SHAKE `digest()` without a length raise `TypeError`; `pbkdf2_hmac` with 0 iterations
raises `ValueError: iteration value must be greater than 0.`, and `scrypt` with an `n` that is
not a power of 2 `ValueError: n must be a power of 2`; `file_digest` of something that is not a
binary file raises `ValueError: '5' is not a file-like object in binary reading mode.`;
`hmac.new` without `digestmod` raises `TypeError: Missing required argument 'digestmod'.`; and
`compare_digest` of a str and bytes, or of strs with non-ASCII characters, raises `TypeError`.

## Differences from CPython

- **Algorithms only OpenSSL provides are not there**: `new("ripemd160")`, `new("md5-sha1")` and
  `new("sm3")` raise `ValueError: unsupported hash algorithm ripemd160`, as CPython built without
  OpenSSL does.
- **Data must be bytes-like at compile time.** `hashlib.sha256("abc")` is a compile error
  (E1053), where CPython raises `TypeError` as it runs. Encode text first:
  `hashlib.sha256("abc".encode())`.

```jac
# expect: E1053
import hashlib;

with entry {
    print(hashlib.sha256("abc").hexdigest());
}
```

For random tokens and constant-time comparison of secrets, see `secrets` in
[Standard-library modules](stdlib.md).
