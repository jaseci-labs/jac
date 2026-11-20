---
description: The native base64 and binascii modules, as CPython 3.15's, encoding bytes as text in Base16, 32, 64 and 85, and CRC checksums.
keywords: base64, binascii, base64.b64encode, base64.b64decode, base64.urlsafe_b64encode, base64.urlsafe_b64decode, base64.b32encode, base64.b16encode, base64.b85encode, base64.a85encode, base64.z85encode, binascii.hexlify, binascii.unhexlify, binascii.crc32, binascii.crc_hqx, binascii.Error
---
# base64 and binascii

`base64` encodes bytes as ASCII text and decodes it back, in Base16, Base32, Base64, Base85,
Ascii85 and Z85; `binascii` holds the conversions it is built on, with hex and CRC checksums.
Both are native and have every name and keyword of CPython 3.15's modules, with its results,
exceptions and messages (see [The library](index.md), `jac docs library`). Both build for
every target, WASI included.

```jac
import base64;
import binascii;

with entry {
    raw = bytes([251, 255, 254, 0, 63]);
    print(base64.b64encode(raw), base64.urlsafe_b64encode(raw), base64.b64encode(raw, b"*."));
    print(base64.b64decode("+//+AD8="), base64.b32encode(b"jac"), base64.b16encode(b"jac"));
    print(base64.b85encode(b"jac rocks"), base64.a85encode(b"jac"), base64.z85encode(b"jac!"));
    print(base64.b64encode(b"ab", padded=False), base64.b64encode(b"hello, jac!", wrapcol=8));
    print(base64.b64decode(b"aG Vs\nbG8=!"), base64.b64decode(b"aGk", padded=False));
    for bad in [b"aGk", b"aG Vs"] {
        try {
            base64.b64decode(bad, validate=True);
        } except binascii.Error as e {
            print("binascii.Error:", e);
        }
    }
    print(binascii.hexlify(b"jac", "-"), binascii.unhexlify("6a6163"), binascii.b2a_base64(b"jac"));
    print(
        binascii.crc32(b"jac"),
        binascii.crc32(b"c", binascii.crc32(b"ja")),
        binascii.crc_hqx(b"jac", 0),
    );
}
```

```output
b'+//+AD8=' b'-__-AD8=' b'*..*AD8='
b'\xfb\xff\xfe\x00?' b'NJQWG===' b'6A6163'
b'YGGp_a&Kd6a{' b'C11T' b'yggP}'
b'YWI' b'aGVsbG8s\nIGphYyE='
b'hello' b'hi'
binascii.Error: Incorrect padding
binascii.Error: Only base64 data is allowed
b'6a-61-63' b'jac' b'amFj\n'
308084192 308084192 14452
```

## What is there

| Module | Names |
|---|---|
| `base64` | `b64encode`, `b64decode`, `standard_b64encode`, `standard_b64decode`, `urlsafe_b64encode`, `urlsafe_b64decode`, `b32encode`, `b32decode`, `b32hexencode`, `b32hexdecode`, `b16encode`, `b16decode`, `a85encode`, `a85decode`, `b85encode`, `b85decode`, `z85encode`, `z85decode`, `encodebytes`, `decodebytes`, `encode`, `decode` (between file objects) |
| `binascii` | `a2b_base64`, `b2a_base64`, `a2b_base32`, `b2a_base32`, `a2b_ascii85`, `b2a_ascii85`, `a2b_base85`, `b2a_base85`, `a2b_hex`, `b2a_hex`, `hexlify`, `unhexlify`, `a2b_qp`, `b2a_qp`, `a2b_uu`, `b2a_uu`, `crc32`, `crc_hqx`, `Error`, `Incomplete`, the `*_ALPHABET` constants |

An encoder takes a `bytes`, a `bytearray` or a `memoryview`; a decoder also takes a str of
ASCII characters. Python 3.15's keywords are there: `padded=False` leaves out (or accepts the
absence of) the `=` padding, `wrapcol=` breaks the output into lines, `ignorechars=` names the
characters a decoder skips (`validate` is then true by default), and `canonical=True` refuses
padding bits that are not zero. `b32decode` takes `casefold=` and `map01=`, and the
`binascii` functions `alphabet=`, as in CPython.

## Decoding rules

As in CPython:

- A Base64 decoder discards characters outside the alphabet (`b"aG Vs\nbG8=!"` decodes), unless
  `validate=True`, which raises `binascii.Error: Only base64 data is allowed`,
  `Excess data after padding` or `Leading padding not allowed`.
- Input whose length leaves a partial group raises `binascii.Error: Incorrect padding`
  (`b64decode(b"aGk")`), unless `padded=False`.
- A str with a non-ASCII character raises
  `ValueError: string argument should contain only ASCII characters`, and `altchars` that are
  not two bytes raise `ValueError: invalid altchars: b'*'`.
- `binascii.Error` is a `ValueError`.

`binascii.crc32(data, value=0)` is zlib's CRC-32, unsigned, and continues from a running
value: `crc32(b"c", crc32(b"ja")) == crc32(b"jac")`, and `crc32(b"")` is `0`. It gives the same
values on every target, WASI included, where the program carries its own implementation.

## Differences from CPython

- **No warnings are issued**: the `FutureWarning` and `DeprecationWarning` CPython gives for
  `+` and `/` in data decoded with another alphabet are not (see [The library](index.md)).
- **`base64` has no command line**: `base64.main` is not there.

## Where to go next

- Bytes and their methods, `bytes.hex` and `bytes.fromhex`: [bytes](bytes-methods.md).
- Digests and `hmac`: [hashlib](hashlib.md). Compression, and `zlib.crc32`:
  [Compression and archives](compression.md).
