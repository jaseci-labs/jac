"""Methods a generic base defines are callable through its subclasses.

The layout hierarchy used to skip a base written with type arguments
(`Registry[int]`), so a native call to an inherited method found no owner.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a subclass reaches the methods of its generic base" {
    source = str(
        Path(__file__).resolve().parent
            / "fixtures"
            / "generic_base_inherited_method.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines() == ["2", "alpha/2"] , out;
}
