"""A base method that self-dispatches past a native override (#8310).

The old backend kept a Python-side base on a pyb shadow built as
`type(name, (base,), {})`, which carried none of the native subclass's
bodies, so a base method invoked through it resolved `self.hook()` to the
BASE's body and answered 30 where Python answers 1020. It refused that call
with E5089.

MIR has no shadow. A base it can lower lowers natively, and the subclass's
vtable holds the base's slots and its own overrides, so the override runs and
the controls keep lowering. A base that stays Python-side keeps its instance
state in Python, which native code does not hold: the subclass refuses, and
every callable constructing it demotes to the Python lane, where the whole
chain agrees again.
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
            options=CompileOptions(force_codespace='native')
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


test "a base method self-dispatching past an override runs the override" {
    # The base lowers natively, so the subclass carries the base's slots and
    # its own overrides in one vtable: `dispatches` reaches `Overrider.hook`
    # and answers what sv answers, never the base's 30.
    import ctypes;
    import from tests.support { compile_native, get_func }
    (eng, _ir) = compile_native(MAIN);
    assert get_func(eng, "overridden_dispatch", ctypes.c_int64)() == 1020 , (
        "`dispatches(2)` must run Overrider's hook, not the base's"
    );
    assert get_func(eng, "overridden_dispatch_twice", ctypes.c_int64)() == 108 , (
        "`dispatches_twice` reaches the override after an unrelated `self.plain`"
    );
    assert get_func(eng, "bystander_dispatch", ctypes.c_int64)() == 30 , (
        "Bystander inherits the base's hook through its own vtable"
    );
    assert not _seams_for(MAIN, "overridden_dispatch") , _seams(MAIN);
    assert not _seams_for(MAIN, "overridden_dispatch_twice") , _seams(MAIN);
}


test "a native class over a base that stays Python-side refuses" {
    # A base the project pins to the server keeps its instance state in
    # Python, which native code does not hold, so the subclass refuses and
    # every callable constructing it demotes to the Python lane, where the
    # whole chain agrees again. The refusal names the class and the base.
    import shutil;
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "jac.toml"), "w") as f {
            f.write(
                '[project]\nname = "pyb_pinned"\n\n[placement.pins]\n"lib" = "server"\n'
            );
        }
        shutil.copyfile(
            os.path.join(FIXTURES, "pyb_shadow_dispatch_lib.jac"),
            os.path.join(tmp, "lib.jac")
        );
        with open(os.path.join(FIXTURES, MAIN)) as f {
            text = f.read().replace("pyb_shadow_dispatch_lib", "lib");
        }
        main = os.path.join(tmp, "main.jac");
        with open(main, "w") as f {
            f.write(text);
        }
        prog = JacProgram();
        na_coverage_begin();
        try {
            prog.compile(
                file_path=main, options=CompileOptions(force_codespace='native')
            );
        } finally {
            coverage = na_coverage_end();
        }
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        rec = coverage.get(os.path.realpath(main));
        seams = [str(s) for s in ((rec.get("seams") or []) if rec is not None else [])];
    }
    hits = [s for s in seams if s.startswith("overridden_dispatch: ")];
    assert len(hits) == 1 , f"the constructing callable must demote: {seams}";
    assert "Overrider" in hits[0] and "DispatchBase" in hits[0] , (
        f"the refusal must name the class and its Python-side base: {hits[0]}"
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
