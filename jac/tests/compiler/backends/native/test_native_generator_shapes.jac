"""Shapes the compiler's own native generator relies on.

Each of these compiled on the native tier and gave a different answer from
the Python tier. They were found by running the generator natively; the
generator's sources are ordinary Jac, so any program could have hit them."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

def fixture(name: str) -> str {
    return str(Path(__file__).resolve().parent / "fixtures" / name);
}

test "a comprehension that repeats one object keeps every element" {
    out = assert_native_identity(
        fixture("comprehension_shared_element.jac"), profiles=["rc", "managed"]
    );
    assert "7 1 2 7 7 7 | 0 9 9 9 | 2 | 58 | 10" in out , out;
}

test "an untyped value compares with an object through the object's __eq__" {
    out = assert_native_identity(
        fixture("any_eq_user_eq.jac"), profiles=["rc", "managed"]
    );
    assert "eq elem-eq rev-eq typed-eq" in out , out;
    assert "ne elem-eq rev-eq typed-eq" in out , out;
    assert "total 800 a" in out , out;
}
