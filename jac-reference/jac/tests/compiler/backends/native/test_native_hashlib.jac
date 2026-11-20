"""Native hashlib and hmac are pure Jac and agree with CPython byte for byte.

The kernel hashes its sources with sha256, sha1 and blake2s, and native
programs reach the rest of hashlib, so every algorithm is checked at each
block boundary, incrementally, through copy(), and under HMAC.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "every hashlib algorithm and its HMAC match CPython at every block boundary" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "hashlib_parity.jac");
    out = assert_native_identity(source, profiles=["managed"]);
    assert len(out.splitlines()) == 12 * 28 + 1 , out[-400:];
    assert "False" not in out , out;
}
