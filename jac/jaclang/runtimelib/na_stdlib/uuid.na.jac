"""Bundled native `uuid` (v4 subset) — pure-Jac surface over the CSPRNG floor.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6978 Phase 1). On the native (na) pathway
`import uuid` / `import from uuid { uuid4 }` resolves to this module; on the
sv/Python pathway the identical import binds CPython's real `uuid`. The two are
held congruent by the tri-backend equivalence suite (prim_uuid.jac), which -- the
output being random -- asserts the deterministic *structure* of a v4 UUID: the
`hex`/`str()` lengths, hyphen layout, version nibble (`4`), RFC-4122 variant
nibble (`8`/`9`/`a`/`b`), and that two draws differ.

Mechanism-F architecture (#6978): the randomness is OpenSSL's `RAND_bytes` via
the `_csprng_native.na.jac` floor (the same bundled `libcrypto.a` hashlib uses).

`uuid4` draws 16 CSPRNG bytes and renders them to the 32-char `hex` string,
setting the version (byte 6 high nibble -> `4`) and RFC-4122 variant (byte 8 top
bits -> `10`) bits as it goes. Native `bytes` are immutable (subscript
assignment is unsupported, #7003), so the patched bits are applied during the
hex render rather than rewritten into a buffer; the canonical hyphenated form is
produced by `__str__` (native `str(obj)`/f-string dispatch, #7003). The
surface matches CPython's `UUID.hex` / `str(UUID)` / `UUID.version`; the
`.bytes`/`.int`/`.urn` attributes (which need a constructed `bytes`) are
follow-ups.

PORTABILITY: native-host-only (inherited from the libcrypto floor).
"""

import from _csprng_native { csprng_bytes }


"""A version-4 UUID congruent with CPython's `uuid.UUID` (rendering subset).

`hex` is the 32-char lowercase hex with the v4 version/variant bits already
applied (CPython `UUID.hex`); `str(u)` is the canonical hyphenated `8-4-4-4-12`
form; `version` is `4`."""
obj:pub UUID {
    has hex: str,
        version: int = 4;

    """The canonical hyphenated `8-4-4-4-12` form (CPython `str(UUID)`)."""
    def __str__ -> str {
        h: str = self.hex;
        return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:32];
    }
}


"""A random version-4 UUID (CPython `uuid.uuid4`)."""
def:pub uuid4 -> UUID {
    raw = csprng_bytes(16);
    digits: str = "0123456789abcdef";
    out: str = "";
    i: int = 0;
    while i < 16 {
        v: int = raw[i];
        if i == 6 {
            v = (v & 15) | 64;
        }
        if i == 8 {
            v = (v & 63) | 128;
        }
        out += digits[(v // 16) % 16];
        out += digits[v % 16];
        i += 1;
    }
    return UUID(hex=out, version=4);
}
