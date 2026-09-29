"""A C function defined in Jac returns or takes a struct by value across modules.

A call to another module's C function defined in Jac went through its interop
binding with Jac-ABI types, which an adapter reconciles with the C-ABI
declaration only for scalars and pointers. A struct returned in registers or
through sret, or passed by value, failed to lower ("Incompatible native extern
declaration"), so `_decimal` could not call object_model's
PyComplex_AsCComplex. Such a call now goes through the C-ABI declaration.
"""

import from tests.support { assert_native_identity }

import from pathlib { Path }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "another module's C function returns and takes a struct by value" {
    out = assert_native_identity(str(FIXTURES / "clib_struct_value_xmod_main.jac"));
    assert out.split("\n")[:2] == ["pair 1.5 2.5 4.0", "wide 7 14 21"] , out;
}
