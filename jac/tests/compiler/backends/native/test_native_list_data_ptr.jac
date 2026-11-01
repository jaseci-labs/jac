"""`__list_data_ptr(lst)`: the element buffer of an `int` or `float` list, for the `__mem_*` accessors.

The intrinsic is the address of the list's `data` field, as an integer: a
write through it is the list's element, with no bounds check, so code that
owns its indices (an interpreter's register file) reads and writes a
register with one load or store. It is refused (E5095) for a list of
objects, whose elements a raw word store would take out of the reference
count, and for a temporary list, which is freed with the statement; a
non-list operand is a type error.
"""

import ctypes;
import from tests.support {
    compile_mir,
    compile_native,
    diagnostics_text,
    error_codes,
    get_func,
    kernel_compile_source
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.kernel_api { NativeDemotion }

glob FIXTURE: str = "list_data_ptr.jac",
     REFUSALS: str = "list_data_ptr_refusals.jac";

"""The refusal fixture's demotions, by Jac-level function name."""
def refusals -> dict[str, NativeDemotion] {
    fx = compile_mir(REFUSALS);
    by_symbol = {demotion.symbol: demotion for demotion in fx.unit.demoted};
    found: dict[str, NativeDemotion] = {};
    for name in ["make", "objects_list", "str_list", "call_result", "literal_list"] {
        demotion = by_symbol.get(fx.symbol(name));
        if demotion is not None {
            found[name] = demotion;
        }
    }
    return found;
}

test "writes through the buffer are the list's elements, and the other way" {
    (eng, _fx) = compile_native(FIXTURE);
    for (name, x, want) in [
        ("int_roundtrip", 4, 41),
        ("float_roundtrip", 4, 18),
        ("field_operand", 4, 4),
        ("element_operand", 4, 4),
        ("after_growth", 100, 297)
    ] {
        fn = get_func(eng, name, ctypes.c_int64, ctypes.c_int64);
        got = fn(x);
        assert got == want , f"{name}({x}) = {got}, want {want}";
    }
}

test "the intrinsic lowers inline and is never called" {
    fx = compile_mir(FIXTURE);
    assert not fx.demoted() , str(fx.demoted());
    assert "@__list_data_ptr" not in fx.mir() , "a call of __list_data_ptr was left in the MIR";
}

test "a list of objects or strings is refused: its elements are reference counted" {
    found = refusals();
    for name in ["objects_list", "str_list"] {
        demotion = found.get(name);
        assert demotion is not None , f"{name}: {found}";
        assert demotion.code == "E5095" and "__list_data_ptr" in demotion.reason , (
            f"{name}: {demotion.code} {demotion.reason}"
        );
    }
}

test "a temporary list is refused: it is freed with the statement" {
    found = refusals();
    for name in ["call_result", "literal_list"] {
        demotion = found.get(name);
        assert demotion is not None , f"{name}: {found}";
        assert demotion.code == "E5095" and "__list_data_ptr" in demotion.reason , (
            f"{name}: {demotion.code} {demotion.reason}"
        );
    }
    # the function that makes the temporary lowers: only the call site is refused
    assert "make" not in found , str(found);
}

test "a non-list operand is a type error" {
    result = kernel_compile_source(
        "def probe(x: int) -> int { return __list_data_ptr(x); }\n",
        "list_data_probe.jac",
        CompileOptions(force_codespace="native")
    );
    assert "E1053" in error_codes(result) , diagnostics_text(result);
}
