"""A local read before it is assigned raises UnboundLocalError natively.

CPython raises `UnboundLocalError: cannot access local variable 'x' where it
is not associated with a value` when a read of a local runs before any
assignment to it. The native backend read the local's zeroed slot instead:
a scalar came back as 0, a reference as a null pointer, and when the read
came before the assignment in the source it did not lower at all and the
call it fed was handed a null default (a SIGTRAP or SIGSEGV, not an
exception). A read that may run before the local is assigned must raise the
catchable error, as CPython does.
"""

import from pathlib { Path }
import ctypes;
import from tests.support { assert_native_identity, compile_native, get_func }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures",
     FIXTURE: str = "unbound_locals.jac",
     EXPECTED: list[str] = [
         "3",
         "caught cannot access local variable 'extra' where it is not associated with a value",
         "caught cannot access local variable 'later' where it is not associated with a value",
         "caught cannot access local variable 'z' where it is not associated with a value",
         "5",
         "caught cannot access local variable 'x' where it is not associated with a value",
         "5",
         "caught cannot access local variable 's' where it is not associated with a value",
         "caught cannot access local variable 'total' where it is not associated with a value",
         "3",
         "caught cannot access local variable 'a' where it is not associated with a value",
         "3",
         "caught cannot access local variable 'n' where it is not associated with a value",
         "3",
         "caught cannot access local variable 'found' where it is not associated with a value",
         "[0, 1, 4]",
         "[0, 2, 4]",
         "[7]",
         "caught cannot access local variable 'v' where it is not associated with a value",
         "NameError: cannot access local variable 'w' where it is not associated with a value",
         "18",
         "4 9 9",
         "5",
         "2",
         "5",
         "caught cannot access local variable 'y' where it is not associated with a value",
         "2",
         "caught cannot access local variable 'cb' where it is not associated with a value",
         "caught cannot access local variable 'cb' where it is not associated with a value"
     ];

test "a local read before its assignment raises UnboundLocalError natively" {
    out = assert_native_identity(str(FIXTURES / FIXTURE), profiles=["rc", "managed"]);
    assert out.splitlines() == EXPECTED , out;
}

test "the UnboundLocalError check lowers inside a try body" {
    # The check names the local in a C string; its instruction carries the
    # string's type, or the emitter refuses the module (JacPython's parser).
    (engine, _) = compile_native("unbound_local_read.jac");
    maybe = get_func(engine, "maybe", ctypes.c_int64, ctypes.c_bool);
    assert maybe(True) == 5;
    assert maybe(False) == -1;
}
