"""`**` spreads into callees with fixed parameters agree with Python.

A spread binds against the callee's statically known signature: each
declared parameter it names is bound at run time, a parameter already
bound positionally, by keyword, or by an earlier spread raises TypeError,
and a key that names no parameter raises TypeError because there is no
`**kwargs` sink to receive it. The fixture covers functions, methods,
keyword-only parameters, a variadic callee, two spreads, and each error.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "fixed-signature ** spreads match the Python backend" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "kwargs_spread_fixed.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    assert out.splitlines()[:2] == ["12", "5"] , out;
    assert "repeated TypeError" in out , out;
}
