"""Previously crashing argument shapes either execute or report a checked refusal."""

import ctypes;
import from tests.support {
    compile_mir,
    compile_native,
    diagnostics_text,
    kernel_compile_source,
    native_force_opts,
    native_str_func,
    unit_symbol
}

glob FIXTURE = "emitter_ice_refusals.jac";

glob _MEMO: list[any] = [];

"""The decision step's verdict on the fixture, computed once."""
def measured -> any {
    if _MEMO {
        return _MEMO[0];
    }
    fx = compile_mir(FIXTURE);
    _MEMO.append(fx);
    return fx;
}


test "tuple prefixes lower and match the correct strings" {
    (eng, fx) = compile_native(FIXTURE);
    assert unit_symbol(fx, "tuple_startswith") not in fx.iface().demoted , (
        fx.iface().demoted
    );
    check = native_str_func(eng, "tuple_startswith", ctypes.c_int64, ctypes.c_char_p);
    assert check(b"'quoted") == 1;
    assert check(b'"quoted') == 1;
    assert check(b"plain") == 0;
    assert check(b"") == 0;
}


test "a mismatched call argument is the checker's refusal, not the emitter's" {
    # With type checking on the critical path a plainly-typed mismatch never
    # reaches codegen: the checker names the parameter at check time, which
    # is this pin now.
    result = kernel_compile_source(
        "obj Holder { has n: int = 0; }\n"
            + "def takes_holder(h: Holder) -> int { return h.n; }\n"
            + "def arg_shape_mismatch(s: str) -> int { return takes_holder(s); }\n",
        "arg_shape_probe.jac",
        native_force_opts()
    );
    hits = [
        diag
        for diag in result.errors
        if diag.code == "E1053" and "'h'" in diag.message
    ];
    assert hits , (
        "the direct mismatch must be refused at check time naming the "
        f"parameter, got:\n{diagnostics_text(result)}"
    );
    # The boxed variant in the fixture reaches the native backend, which must
    # decide it (lower or refuse) rather than fail the compile.
    measured();
}


test "the refusals are granular: their neighbours still lower" {
    fx = measured();
    for fn in ["plain_startswith", "takes_holder"] {
        assert not fx.is_demoted(fn) , (
            f"{fn} lowers on its own and must not be taxed by its neighbour's "
            f"refusal: {fx.reason(fn)}"
        );
    }
}
