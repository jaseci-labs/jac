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
answered 5 natively, in silence. Now the construction is refused (E5092
when native is required), which demotes the owning callable to its Python
implementation -- so both lanes answer 103 again and the reason, naming the
class, is on the record.

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
import from tests.support { TESTS_DIR, compile_mir, source_spelled }
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


"""Why the decision step refused `name` in a forced-native compile of
`fixture`, spelled by source names, or "" when it lowered."""
def _refusal(fixture: str, name: str) -> str {
    fx = compile_mir(fixture);
    return source_spelled(fx.reason(name)) if fx.is_demoted(name) else "";
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


test "the generic pass-shaped chain refuses instead of answering wrongly" {
    assert _sv_read_back(GEN) == 103 , "the sv lane runs the override";
    reason = _refusal(GEN, "read_back");
    assert reason , "the hollow construction lowered without a word";
    assert "HollowKid" in reason , f"the refusal does not name the class: {reason}";
}


test "the non-generic control refuses too, so genericity is not the fault" {
    assert _sv_read_back(PLAIN) == 103 , "the sv lane runs the override";
    reason = _refusal(PLAIN, "read_back");
    assert reason , "the same construction with no type parameter must refuse too";
    assert "PlainKid" in reason , f"the refusal does not name the class: {reason}";
}


test "a subclass with its own postinit still constructs" {
    for name in ["run_all", "keep_and_poke"] {
        reason = _refusal(OWN_POSTINIT, name);
        assert not reason , (
            "a native postinit suppresses the base's and chains into it with "
            "`super.postinit()`, which is the supported shape -- refusing it "
            f"would break the interop bridge's own fixture: {name}: {reason}"
        );
    }
}


test "a Python-side base chain with no postinit still constructs" {
    reason = _refusal(NO_BASE_POSTINIT, "run_all");
    assert not reason , (
        "with no shadow-side initializer there is nothing to lose; the "
        f"subscripted generic base alone must not trip the refusal: {reason}"
    );
}
