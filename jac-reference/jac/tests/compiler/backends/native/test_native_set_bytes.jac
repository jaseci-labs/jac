"""Bytes-to-set conversion preserves unsigned values and independent ownership."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native bytes set and frozenset constructors agree with Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "set_bytes.jac");
    assert assert_native_identity(source).strip() == "bytes sets pass";
}
