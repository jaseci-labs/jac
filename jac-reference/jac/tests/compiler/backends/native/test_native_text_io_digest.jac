"""Native text I/O takes a UTF-8 encoding, and hashlib offers BLAKE2.

Code the compiler kernel runs reads its inputs with `open(path, "r",
encoding="utf-8")` and names scoped styles with `hashlib.blake2s`; both
have to lower and agree with CPython byte for byte.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "open with a UTF-8 encoding and BLAKE2 digests match CPython" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "text_io_digest_fidelity.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[0] == "13" , out;
}
