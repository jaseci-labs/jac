"""Calls through a value whose native type carries no call signature (#10541).

A value typed `any` has no signature to call through, and a bare `Callable`
lowers to a closure taking no arguments. Such calls are refused with a hint
naming the `Callable[[...], R]` binding, instead of dropping a keyword
argument, crashing the backend on a positional one, or jumping through a
class name read out of `any`.
"""

import os;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build, native_build_fails, native_run }

glob FIXTURES = Path(__file__).resolve().parent / "fixtures";

test "a call through a value with no native signature is refused with a hint" {
    out = native_build_fails(str(FIXTURES / "call_through_value_refused.jac"));
    for fn_name in ["call_any", "call_bare_keyword", "call_bare_positional"] {
        assert f"demoting {fn_name} to Python-only" in out , out[-1500:];
    }
    assert "E9003" not in out , out[-1500:];
    assert "If it holds a function, bind it to a `Callable[[...], R]` local" in out , out[-1500:];
    assert out.count("so these arguments would be lost") == 2 , out[-1500:];
}

test "a class read out of any as a Callable raises TypeError natively" {
    out_bin = os.path.join(tempfile.mkdtemp(), "any_class");
    native_build(str(FIXTURES / "any_class_as_callable.jac"), out_bin);
    out = native_run(out_bin);
    assert out
        == "label:a\nTypeError: only a function stored in `any` can be called natively through a Callable\n" , out;
}
