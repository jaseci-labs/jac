"""A local first bound to None takes its checked type, not None's.

An unannotated local's slot used to take the LLVM type of its first value,
so `value = None` gave it a bare pointer; an object assigned later lost its
struct type, and boxing it into an `any` tagged it a str.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a None-initialized local keeps the type of what it later holds" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "none_initialized_local.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-1] == "cg:Constant none" , out;
}
