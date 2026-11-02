"""Tuple matching must agree across unwinding and error-slot lowering."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native tuple handlers match members subclasses and preserve propagation" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "except_tuple.jac");
    assert assert_native_identity(source).strip() == "tuple handlers pass";
}
