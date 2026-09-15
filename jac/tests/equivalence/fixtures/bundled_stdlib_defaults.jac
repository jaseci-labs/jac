"""Omitted default arguments in natively lowered bundled-stdlib calls.

A call into a bundled `na_stdlib` function that omits a defaulted parameter
must fill that slot from the bundled `.jac` declaration (the one that is
actually linked and run), not zero-fill it. The stub catalog binds a bundled
stdlib name to a bare symbol that carries no signature, so the native call
lowering cannot take the default from the checker-bound `callee_decl`; it
has to come from the natively linked declaration itself.

`zlib.adler32(data, value=1)` and `secrets.token_hex(nbytes=32)` both have
nonzero defaults, so a zero-filled slot gives a visibly different answer:
adler32 seeded with 0 is 103219732 instead of CPython's 103547413, and
token_hex of 0 bytes is the empty string instead of 64 hex characters.
"""

import from zlib { adler32 }
import from secrets { token_hex }

def adler32_default_seed() -> int {
    return adler32(b"hello");
}

def token_hex_default_len() -> int {
    return len(token_hex());
}
