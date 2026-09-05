"""A base method that self-dispatches past a native override refuses.

The pyb shadow is built as `type(name, (base,), {})`: it carries the
Python-side base chain and none of the native subclass's bodies. E5088
(#8301) closed the entry into that hollow class through `postinit`, at the
construction site. This is the same hole one call deeper (#8310): any base
method invoked through the shadow resolves its own `self.X()` against the
same hollow class, so a name the native subclass overrides is dispatched to
the BASE's body. No diagnostic, no seam -- the wrong body simply runs.

Per the class-tier doctrine (#7685) the answer is the refusal arm, not
override marshalling: the shadow is not taught to delegate back across the
boundary, the call that would diverge is refused with E5089 and its owning
callable demotes to the Python lane, where the whole chain agrees again.

The detection is deliberately narrow, and the controls here are the point of
the test. A subclass that overrides nothing the base dispatches to, and a
base method that reaches nothing on `self`, both keep lowering. Refusing on
"has a Python-side base" would be trivially safe and would cost every
interop call in the tree.

What is NOT detected is stated honestly in `_pyb_shadowed_dispatch`: a body
written inside an inline `::py::` block is opaque text rather than unitree,
and reflective dispatch cannot be read statically. Those shapes stay
unreported; this closes the divergence the tree can prove.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     MAIN = "pyb_shadow_dispatch_main.jac";


"""The coverage seams a forced-native compile of a fixture recorded."""
def _seams(fixture: str) -> list[str] {
    prog = JacProgram();
    na_coverage_begin();
    try {
        prog.compile(
            file_path=os.path.join(FIXTURES, fixture),
            options=CompileOptions(
                force_codespace='native', force_target_program=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(os.path.realpath(os.path.join(FIXTURES, fixture)));
    return [str(s) for s in ((rec.get("seams") or []) if rec is not None else [])];
}


"""The seams recorded for one function of the fixture."""
def _seams_for(fixture: str, fn: str) -> list[str] {
    return [
        s
        for s in _seams(fixture)
        if s.startswith(f"{fn}: ")
    ];
}


"""The fixture's module through the sv/bytecode pathway."""
def _sv_module(fixture: str) -> any {
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
    return mods[0];
}


test "the sv lane runs the override, which is the answer native must not miss" {
    sv = _sv_module(MAIN);
    assert sv.overridden_dispatch() == 1020 , (
        "`dispatches(2)` is `self.hook(2) * 10`, and Overrider's hook adds "
        "100: the override runs, so the answer is 1020. Running the base's "
        "hook instead would give 30 -- a plausible number, which is what "
        "makes the silent version dangerous"
    );
    assert sv.overridden_dispatch_twice() == 108 , (
        "`plain(2)` is 6, plus Overrider's `hook(2)` of 102"
    );
    assert sv.bystander_dispatch() == 30 , (
        "Bystander overrides nothing the base dispatches to, so the base's "
        "own hook is the right body: 30"
    );
}


test "a base method self-dispatching past an override refuses" {
    hits = _seams_for(MAIN, "overridden_dispatch");
    assert len(hits) == 1 , (
        f"`Overrider.hook` overrides what `DispatchBase.dispatches` "
        f"dispatches to, so the shadow call must refuse rather than run the "
        f"base's hook and answer 30. Got: {_seams(MAIN)}"
    );
    assert "E5089" in hits[0] , f"the refusal must be E5089, got: {hits[0]}";
    assert "Overrider" in hits[0] and "hook" in hits[0] , (
        f"the refusal must name the class and the overridden method it would "
        f"have skipped, got: {hits[0]}"
    );
    assert "DispatchBase" in hits[0] , (
        f"the refusal must name the Python-side base whose body would have "
        f"run, got: {hits[0]}"
    );
}


test "the hazard is found through a longer base body, not just a one-liner" {
    hits = _seams_for(MAIN, "overridden_dispatch_twice");
    assert len(hits) == 1 and "E5089" in hits[0] , (
        f"`dispatches_twice` reaches `self.hook` after an unrelated "
        f"`self.plain` call; the walk must not stop at the first "
        f"self-dispatch it sees. Got: {_seams(MAIN)}"
    );
}


test "a base method that reaches nothing on self still lowers" {
    assert not _seams_for(MAIN, "overrider_calls_plain") , (
        f"`DispatchBase.plain` dispatches to nothing, so calling it through "
        f"the shadow cannot diverge and must not refuse. Got: "
        f"{_seams_for(MAIN, 'overrider_calls_plain')}"
    );
    assert not _seams_for(MAIN, "overrider_calls_free") , (
        f"`DispatchBase.calls_free` reaches a module function rather than "
        f"`self`, so it carries no shadow hazard. Got: "
        f"{_seams_for(MAIN, 'overrider_calls_free')}"
    );
}


test "a subclass that overrides nothing dispatched to still lowers" {
    assert not _seams_for(MAIN, "bystander_dispatch") , (
        f"`Bystander` overrides only a name the base never dispatches to, so "
        f"the shadow's answer and the native answer are the same body. "
        f"Refusing here would mean refusing on 'has a Python-side base', "
        f"which would cost every interop call in the tree. Got: "
        f"{_seams_for(MAIN, 'bystander_dispatch')}"
    );
}


test "the refused call still gives the right answer through sv" {
    sv = _sv_module(MAIN);
    assert sv.overridden_dispatch() == 1020 , (
        "the demoted callable must still run the override on the Python lane"
    );
}
