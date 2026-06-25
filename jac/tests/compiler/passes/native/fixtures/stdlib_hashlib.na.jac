"""Bundled native `hashlib` SHA-256 (issue #6964), via the import-from form so
the digest is checked independently of the bare-import routing. Pure-Jac
Mechanism-B: pinned byte-for-byte against the FIPS 180-4 / CPython vectors,
including the empty input and a multi-block (>64-byte) message that exercises
the padding-boundary path.
"""

import from hashlib { sha256 }


def h_empty() -> str {
    return sha256().hexdigest();
}

def h_hello() -> str {
    h = sha256();
    h.update(b"hello");
    return h.hexdigest();
}

def h_abc() -> str {
    h = sha256();
    h.update(b"abc");
    return h.hexdigest();
}

def h_fox() -> str {
    h = sha256();
    h.update(b"The quick brown fox jumps over the lazy dog");
    return h.hexdigest();
}

def h_multiblock() -> str {
    # 100 bytes -> two SHA-256 blocks after padding.
    h = sha256();
    h.update(b"a" * 100);
    return h.hexdigest();
}

def h_incremental() -> str {
    # update() called repeatedly must equal hashing the concatenation.
    h = sha256();
    h.update(b"hel");
    h.update(b"lo");
    return h.hexdigest();
}
