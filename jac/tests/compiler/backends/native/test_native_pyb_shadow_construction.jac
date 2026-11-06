"""Constructing over a Python-side base whose postinit runs refuses (#8301).

A native class over a Python-side base owns two halves: its own slots in
the native struct, the base's on a Python shadow the bridge keeps beside
it. Construction lowered to a `_pyb_instantiate` bridge whose result was
immediately dropped, so the base's `__post_init__` ran on that discarded
shadow -- where the subclass's native slots do not exist and its
overrides are not on the shadow's class. The field read afterwards came
back as the slot's declared default and nothing was diagnosed: a wrong
answer, not a gap, and the worst class in the ledger.

Both fixtures answer 103 in the sv lane. Before the refusal both
answered 5 natively, in silence. Now the construction refuses, which
demotes the owning callable to its Python implementation -- so both lanes
answer 103 again and the reason is on the record.

The non-generic control is what places the fault. The compiler's own
pass chain reached this path through `BaseTransform[T_in, T_out]`, which
is what put the defect on the M1 ladder, but genericity is not why the
path is wrong: the same construction with no type parameter anywhere was
equally hollow, and refuses the same way.

The two shapes that stay legal are pinned here too, because a refusal
that swallowed them would be worse than the silence it replaces: a
subclass with a `postinit` of its own suppresses the base's and chains
into it with `super.postinit()`, which does bridge; and a base chain
carrying no `postinit` has no shadow-side initializer to lose.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     GEN = "pyb_hollow_gen_main.jac",
     PLAIN = "pyb_hollow_plain_main.jac",
     OWN_POSTINIT = "pyb_native_main.jac",
     NO_BASE_POSTINIT = "pyb_gen_base_main.jac";


"""The refusals a forced-native compile of a fixture reported: each demotion
it wrote to stderr, and any E5088 / E5092 error."""
def _refusals(fixture: str) -> list[str] {
    import contextlib;
    import io;
    prog = JacProgram();
    buf = io.StringIO();
    with contextlib.redirect_stderr(buf) {
        prog.compile(
            file_path=os.path.join(FIXTURES, fixture),
            options=CompileOptions(force_codespace='native')
        );
    }
    return [
        line
        for line in buf.getvalue().splitlines()
        if "demoting" in line
    ]
        + [
            str(e)
            for e in prog.errors_had
            if e.code is not None and e.code.code in ("E5088", "E5092")
        ];
}


"""The fixture's answer through the sv/bytecode pathway."""
def _sv_read_back(fixture: str) -> int {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=fixture[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , f"sv import of {fixture} produced no module";
    return mods[0].read_back();
}


test "the generic pass-shaped chain refuses or answers as Python does, never 5" {
    assert _sv_read_back(GEN) == 103 , "the sv lane runs the override";
    hits = _refusals(GEN);
    if hits {
        assert any("HollowKid" in hit for hit in hits) , (
            f"the refusal does not name the class: {hits}"
        );
    } else {
        import ctypes;
        import from tests.support { compile_native, get_func }
        (eng, _ir) = compile_native(GEN);
        native = get_func(eng, "read_back", ctypes.c_int64)();
        assert native == 103 , (
            f"the construction lowered but skipped the override: native answered {native}"
        );
    }
}


test "the non-generic control refuses or answers as Python does, never 5" {
    assert _sv_read_back(PLAIN) == 103 , "the sv lane runs the override";
    hits = _refusals(PLAIN);
    if hits {
        assert any("PlainKid" in hit for hit in hits) , (
            f"the refusal does not name the class: {hits}"
        );
    } else {
        import ctypes;
        import from tests.support { compile_native, get_func }
        (eng, _ir) = compile_native(PLAIN);
        native = get_func(eng, "read_back", ctypes.c_int64)();
        assert native == 103 , (
            f"the construction lowered but skipped the override: native answered {native}"
        );
    }
}


test "a subclass with its own postinit still constructs" {
    hits = _refusals(OWN_POSTINIT);
    assert not hits , (
        "a native postinit suppresses the base's and chains into it with "
        "`super.postinit()`, which is the supported shape -- refusing it "
        f"would break the interop bridge's own fixture: {hits}"
    );
}


test "a Python-side base chain with no postinit still constructs" {
    hits = _refusals(NO_BASE_POSTINIT);
    assert not hits , (
        "with no shadow-side initializer there is nothing to lose; the "
        f"subscripted generic base alone must not trip the refusal: {hits}"
    );
}
