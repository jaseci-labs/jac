"""bytes.decode honours its encoding and errors arguments natively.

The native emitter used to copy the bytes and ignore both arguments, so
`data.decode("utf-8", errors="replace")` kept the invalid bytes, "ignore"
kept them too, and strict decoding never raised. The fixture sweeps
utf-8/latin-1/ascii (under alias spellings, literal and run-time) against
every decode error handler over CPython's maximal-subpart error cases, and
catches the UnicodeDecodeError, LookupError and TypeError paths. Identity
with the Python backend under every memory profile proves the semantics;
a native build refuses any demoted function, so it also proves the native
path was taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native bytes.decode honours encoding and errors like CPython" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "bytes_decode.jac");
    out = assert_native_identity(source);
    assert "ab\\xef\\xbf\\xbdcd" in out , out[:400];
    assert "'utf-8' codec can't decode byte 0xff in position 2: invalid start byte"
        in out;
    assert "'utf-8' codec can't decode bytes in position 0-1: unexpected end of data"
        in out;
    assert "'ascii' codec can't decode byte 0x80 in position 0: ordinal not in range(128)"
        in out;
    assert "unknown error handler name 'no-such-handler'" in out;
    assert "don't know how to handle UnicodeDecodeError in error callback" in out;
    assert out.rstrip().endswith("unknown encoding: no-such-codec");
}
