"""A `__str__` dunder that reads through an attribute chain must lower natively.

Roadmap item N8b of jaseci-labs/jac#7967: `Constants.__str__` (a
`class C(StrEnum)` whose dunder body is `return self.value;`) demoted to Python
in the seal logs. The root cause is not the dunder: a Python-class-form enum
declaration is a `uni.Archetype`, so it never reached the native enum
machinery, and `self.value` had no lowering.

These tests assert the methods are NOT demoted -- a demoted method still
returns the right string through Python, so a value-only assertion would pass
while the gap stayed open -- by requiring them in the module's MIR and out of
its demoted set, and separately assert the values equal the sv results.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support {
    TESTS_DIR,
    compile_mir,
    compile_native,
    native_address,
    native_str_func,
    source_spelled
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Import the fixture on the sv/bytecode pathway and hand back its module."""
def sv_module(stem: str) -> any {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(stem, None);
        return importlib.import_module(stem);
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
    }
}

test "str dunders reading through a trailer are not demoted to Python" {
    fx = compile_mir("dunder_str_trailer.jac");
    mir = source_spelled(fx.mir());
    demoted = [source_spelled(symbol) for symbol in fx.demoted()];
    for want in ["Kind.__str__", "Outer.__str__", "Indexed.__str__"] {
        assert not any(symbol.endswith("." + want) for symbol in demoted) , (
            f"{want} was demoted: {fx.demoted()}"
        );
        assert f".{want}(" in mir , f"{want} was never lowered; demoted: {demoted}";
    }
}

test "class-form enum members and trailer dunders match the sv values" {
    (eng, _) = compile_native("dunder_str_trailer.jac");
    sv = sv_module("dunder_str_trailer");
    for name in [
        "alpha_value",
        "alpha_str",
        "beta_render",
        "outer_str",
        "indexed_str"
    ] {
        na_out = native_str_func(eng, name, ctypes.c_char_p)();
        sv_out = getattr(sv, name)().encode("utf8");
        assert na_out == sv_out , f"{name}: native {na_out!r} != sv {sv_out!r}";
    }
}

test "a StrEnum member compares equal to its text on both backends" {
    (eng, _) = compile_native("dunder_str_trailer.jac");
    sv = sv_module("dunder_str_trailer");
    addr = native_address(eng, "alpha_is_text");
    assert addr != 0 , "alpha_is_text not found in the JIT engine";
    na_out = ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
    assert na_out == sv.alpha_is_text() , (
        f"alpha_is_text: native {na_out} != sv {sv.alpha_is_text()}"
    );
}
