"""Bundled native `hashlib` cross-backend equivalence fixture (#6964).

The SAME `import from hashlib { sha256 }` binds CPython's `hashlib` on the sv
(Python) backend and the bundled `na_stdlib/hashlib.na.jac` pure-Jac
(Mechanism-B) SHA-256 on the na (native LLVM) backend. This fixture pins the two
implementations byte-for-byte congruent across the empty input, single-block
inputs, a multi-block (>64-byte) message that exercises the padding-boundary
path, and an incremental `update()` sequence. Only the CPython-shared API
(`sha256()` / `update()` / `hexdigest()`) is used so the identical source runs
on both backends. ES/JS opts out.
"""

import from hashlib { sha256 }

def hashlib_py() -> dict {
    h_hello = sha256();
    h_hello.update(b"hello");
    h_abc = sha256();
    h_abc.update(b"abc");
    h_fox = sha256();
    h_fox.update(b"The quick brown fox jumps over the lazy dog");
    h_multi = sha256();
    h_multi.update(b"a" * 100);
    h_incr = sha256();
    h_incr.update(b"hel");
    h_incr.update(b"lo");
    return {
        "empty": sha256().hexdigest(),
        "hello": h_hello.hexdigest(),
        "abc": h_abc.hexdigest(),
        "fox": h_fox.hexdigest(),
        "multi": h_multi.hexdigest(),
        "incr": h_incr.hexdigest(),

    };
}

cl def hashlib_cl() -> dict {
    return {};
}

na {
    def hashlib_na() -> dict[str, any] {
        h_hello = sha256();
        h_hello.update(b"hello");
        h_abc = sha256();
        h_abc.update(b"abc");
        h_fox = sha256();
        h_fox.update(b"The quick brown fox jumps over the lazy dog");
        h_multi = sha256();
        h_multi.update(b"a" * 100);
        h_incr = sha256();
        h_incr.update(b"hel");
        h_incr.update(b"lo");
        return {
            "empty": sha256().hexdigest(),
            "hello": h_hello.hexdigest(),
            "abc": h_abc.hexdigest(),
            "fox": h_fox.hexdigest(),
            "multi": h_multi.hexdigest(),
            "incr": h_incr.hexdigest(),

        };
    }
}
