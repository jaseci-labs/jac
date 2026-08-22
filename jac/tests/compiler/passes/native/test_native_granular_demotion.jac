"""Granular native-lowering demotion (epic #8201).

A capability violation used to refuse whole-module native codegen: one
dynamic construct anywhere meant zero per-method seam data, so nothing
in the module could seal. These tests pin the granular contract: a
violation demotes its smallest owning unit. An archetype method, an
event ability, a free function, or a constructor becomes a seam exactly
like a NaIRGenPass-time demotion -- recorded in the coverage with a reason
that names the construct, shipped as an abort stub if sealed,
waiver-eligible through `seal_demotion_report` -- while every sibling
still lowers. Module-level constructs with no owning callable (a
module-level Python import feeding a glob initializer) keep the
whole-module refusal, and the diagnostic names the construct.

A demoted constructor is the one seam a caller cannot route around: the
class layout still emits, but native construction has no initializer to
call, so the construction site refuses with E5092 and cascades into a
seam of its own rather than build a half-initialized object (#8234).
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Forced-native options that skip the IR cache so the coverage always runs."""
def _granular_opts -> CompileOptions {
    return CompileOptions(
        type_check=False,
        force_codespace='native',
        force_target_program=True,
        no_ir_cache=True
    );
}

"""Compile a fixture under the coverage; return (program, module, coverage)."""
def _compile_with_coverage(fixture: str) -> tuple {
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture), options=_granular_opts()
        );
    } finally {
        coverage = na_coverage_end();
    }
    return (prog, ir, coverage);
}

"""The coverage seam list recorded for a fixture path."""
def _seams_of(coverage: dict, fixture: str) -> list[str] {
    rec = coverage.get(os.path.realpath(os.path.join(FIXTURES, fixture)));
    if rec is None {
        return [];
    }
    return [str(s) for s in (rec.get("seams") or [])];
}

test "a method's capability violation demotes only that method" {
    (prog, ir, coverage) = _compile_with_coverage("granular_method_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"a method-owned violation must demote, not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only one method demotes"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Calc.good" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "Calc.bad" not in layout.methods , (
        "the violating method must be demoted out of the native layout"
    );
    seams = _seams_of(coverage, "granular_method_seam.jac");
    bad_seams = [
        s
        for s in seams
        if s.startswith("Calc.bad: ")
    ];
    assert len(bad_seams) == 1 , (
        f"expected exactly one coverage seam for Calc.bad, got: {seams}"
    );
    assert "collections" in bad_seams[0] , (
        f"the seam reason must name the blocking construct: {bad_seams[0]}"
    );
}

test "a free function's capability violation demotes only that function" {
    (prog, ir, coverage) = _compile_with_coverage("granular_freefn_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"a function-owned violation must demote, not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only one function demotes"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "clean" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "pyonly" not in layout.functions , (
        "the violating function must be demoted out of the native layout"
    );
    seams = _seams_of(coverage, "granular_freefn_seam.jac");
    fn_seams = [
        s
        for s in seams
        if s.startswith("pyonly: ")
    ];
    assert len(fn_seams) == 1 , (
        f"expected exactly one coverage seam for pyonly, got: {seams}"
    );
    assert "collections" in fn_seams[0] , (
        f"the seam reason must name the blocking construct: {fn_seams[0]}"
    );
}

test "an event ability's capability violation demotes only that ability" {
    (prog, ir, coverage) = _compile_with_coverage("granular_event_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"an ability-owned violation must demote, not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only one ability demotes"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "W.done" in layout.methods , (
        f"clean sibling ability was lost: {list(layout.methods)}"
    );
    assert "W.go" not in layout.methods , (
        "the violating ability must be demoted out of the native layout"
    );
    seams = _seams_of(coverage, "granular_event_seam.jac");
    go_seams = [
        s
        for s in seams
        if s.startswith("W.go: ")
    ];
    assert len(go_seams) == 1 , (
        f"expected exactly one coverage seam for W.go, got: {seams}"
    );
    assert "tag" in go_seams[0] , (
        f"the seam reason must name the blocked attribute: {go_seams[0]}"
    );
}

test "a module-level violation stays module-fatal and names the construct" {
    (prog, ir, coverage) = _compile_with_coverage("granular_module_fatal.jac");
    codes = [
        alrt.code.code
        for alrt in prog.errors_had
        if alrt.code is not None
    ];
    assert "E5090" in codes , (
        f"a violation with no owning callable must keep the E5090 refusal, "
        f"got: {[str(e) for e in prog.errors_had]}"
    );
    named = any("collections" in str(e) for e in prog.errors_had);
    assert named , (
        f"the module-fatal diagnostic must name the construct: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    assert ir.gen.llvm_ir is None , (
        "a module-fatal violation must withhold the LLVM IR"
    );
    assert not _seams_of(coverage, "granular_module_fatal.jac") , (
        "a refused module must not also record granular seams"
    );
}

test "a postinit's capability violation demotes only that constructor" {
    (prog, ir, coverage) = _compile_with_coverage("granular_postinit_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"a postinit-owned violation must demote, not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only one constructor demotes"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Boxed" in layout.structs , (
        f"the layout of the demoted constructor's class must still emit: "
        f"{list(layout.structs)}"
    );
    assert "Boxed.good" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "Plain.fine" in layout.methods , (
        f"clean sibling archetype was lost: {list(layout.methods)}"
    );
    assert "Boxed.__post_init__" not in layout.methods , (
        "the violating constructor must be demoted out of the native layout"
    );
    seams = _seams_of(coverage, "granular_postinit_seam.jac");
    pi_seams = [
        s
        for s in seams
        if s.startswith("Boxed.__post_init__: ")
    ];
    assert len(pi_seams) == 1 , (
        f"expected exactly one coverage seam for Boxed.__post_init__, got: {seams}"
    );
    assert "collections" in pi_seams[0] , (
        f"the seam reason must name the blocking construct: {pi_seams[0]}"
    );
}

test "a demoted constructor ships as an abort stub, not a silent fallback" {
    import from jaclang.utils.precompile_bytecode { seal_abort_stubs }
    (_prog, ir, _coverage) = _compile_with_coverage("granular_postinit_seam.jac");
    stubs = seal_abort_stubs(str(ir.gen.llvm_ir));
    assert "Boxed.__post_init__" in stubs , (
        f"a sealed artifact has no Python to fall back to, so the demoted "
        f"constructor must ship as an abort stub: {stubs}"
    );
    assert "Boxed.good" not in stubs , (
        f"a clean sibling must not be stubbed: {stubs}"
    );
}

test "a user init's capability violation demotes only that initializer" {
    (prog, ir, coverage) = _compile_with_coverage("granular_init_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"an init-owned violation must demote, not fail the module: {errors}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Tally.total" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "Bystander.keep" in layout.methods , (
        f"clean sibling archetype was lost: {list(layout.methods)}"
    );
    assert "Tally.init" not in layout.methods , (
        "the violating initializer must be demoted out of the native layout"
    );
    seams = _seams_of(coverage, "granular_init_seam.jac");
    init_seams = [
        s
        for s in seams
        if s.startswith("Tally.init: ")
    ];
    assert len(init_seams) == 1 , (
        f"expected exactly one coverage seam for Tally.init, got: {seams}"
    );
    assert "collections" in init_seams[0] , (
        f"the seam reason must name the blocking construct: {init_seams[0]}"
    );
}

test "constructing a class whose constructor demoted refuses loudly" {
    (prog, ir, coverage) = _compile_with_coverage("granular_ctor_cascade.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"the caller must cascade into a seam, not fail the module: {errors}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Maker.pure" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "Maker.build" not in layout.methods , (
        "a native construction of a class with a demoted constructor must "
        "refuse, not build a half-initialized object"
    );
    seams = _seams_of(coverage, "granular_ctor_cascade.jac");
    build_seams = [
        s
        for s in seams
        if s.startswith("Maker.build: ")
    ];
    assert len(build_seams) == 1 , (
        f"expected exactly one coverage seam for Maker.build, got: {seams}"
    );
    assert "E5092" in build_seams[0] and "Late" in build_seams[0] , (
        f"the cascade reason must name the refused construction: " f"{build_seams[0]}"
    );
}

test "a constructor that fails late still refuses an earlier-lowered caller" {
    (prog, ir, coverage) = _compile_with_coverage("granular_ctor_late_failure.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"the caller must cascade into a seam, not fail the module: {errors}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Early.pure" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "Sink.init" not in layout.methods , (
        "an initializer the emitter could not lower must demote"
    );
    assert "Early.make" not in layout.methods , (
        "a construction site lowered before the initializer demoted must "
        "still refuse; binding it early would call an abort stub with no "
        "diagnostic"
    );
    seams = _seams_of(coverage, "granular_ctor_late_failure.jac");
    make_seams = [
        s
        for s in seams
        if s.startswith("Early.make: ")
    ];
    assert len(make_seams) == 1 , (
        f"expected exactly one coverage seam for Early.make, got: {seams}"
    );
    assert "Sink" in make_seams[0] , (
        f"the cascade reason must name the refused construction: " f"{make_seams[0]}"
    );
}

test "granular seams are waiver-eligible through seal_demotion_report" {
    import from jaclang.utils.precompile_bytecode { seal_demotion_report }
    (_prog, _ir, coverage) = _compile_with_coverage("granular_method_seam.jac");
    rel = "granular_method_seam.jac";
    (err, _waived, _stale) = seal_demotion_report(rel, coverage);
    assert "granular_method_seam.jac::Calc.bad" in err , (
        f"an un-waived granular seam must refuse to seal: {err}"
    );
    waivers = {rel: ("granular_method_seam.jac::Calc.bad", )};
    (err2, waived2, stale2) = seal_demotion_report(rel, coverage, waivers=waivers);
    assert err2 == "" , f"a waived granular seam must seal: {err2}";
    assert "granular_method_seam.jac::Calc.bad" in waived2 , (
        f"the waiver must be reported as consumed: {waived2}"
    );
    assert not stale2 , f"the waiver must not read as stale: {stale2}";
}

test "a demoted constructor is waiver-eligible like any other seam" {
    import from jaclang.utils.precompile_bytecode { seal_demotion_report }
    (_prog, _ir, coverage) = _compile_with_coverage("granular_postinit_seam.jac");
    rel = "granular_postinit_seam.jac";
    (err, _waived, _stale) = seal_demotion_report(rel, coverage);
    assert "granular_postinit_seam.jac::Boxed.__post_init__" in err , (
        f"an un-waived constructor seam must refuse to seal: {err}"
    );
    waivers = {rel: ("granular_postinit_seam.jac::Boxed.__post_init__", )};
    (err2, waived2, stale2) = seal_demotion_report(rel, coverage, waivers=waivers);
    assert err2 == "" , f"a waived constructor seam must seal: {err2}";
    assert "granular_postinit_seam.jac::Boxed.__post_init__" in waived2 , (
        f"the waiver must be reported as consumed: {waived2}"
    );
    assert not stale2 , f"the waiver must not read as stale: {stale2}";
}

# An argument the emitter drops is the silent-miscompile class, not a seam
# reason, unless the emitter says so out loud. `_emit_open` reads `open`
# positionally and ignores everything past the mode, so `encoding=` has to
# refuse. It also has to be reachable: with `encoding` absent from the text
# overload the call was a type error instead, and a type error in a native
# module refuses the module rather than the function that wrote it.
test "an open() keyword argument demotes its function instead of miscompiling" {
    (prog, ir, coverage) = _compile_with_coverage("granular_open_kwarg.jac");
    assert not prog.errors_had , (
        f"`open(path, 'r', encoding=...)` type-checks -- `encoding` is on the "
        f"text overload in `na_builtins.pyi` -- so the emitter's refusal has "
        f"to demote its owning function, not refuse the module: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "reads_plain" in layout.functions , (
        f"the sibling that opens the same file positionally must still lower: "
        f"{sorted(layout.functions)}"
    );
    assert "reads_with_encoding" not in layout.functions , (
        "silently dropping `encoding=` would emit a `fopen` that ignores what "
        "the source asked for; the function must leave the native layout"
    );
    seams = [
        s
        for s in _seams_of(coverage, "granular_open_kwarg.jac")
        if s.startswith("reads_with_encoding: ")
    ];
    assert len(seams) == 1 , (
        f"expected exactly one coverage seam for reads_with_encoding, got: "
        f"{_seams_of(coverage, 'granular_open_kwarg.jac')}"
    );
    assert "open" in seams[0] , (
        f"the seam reason must name the construct it refused: {seams[0]}"
    );
}

# A signature is resolved when the ability is declared, before any body opens a
# demotion window, so an annotation the backend cannot lower had no owner and
# cost the whole module its IR -- and every importer with it (#8285). The
# owning callable is known at declaration time, so it demotes there.
test "an unresolvable signature annotation demotes its callable" {
    (prog, ir, coverage) = _compile_with_coverage("sig_unknown_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"a signature the backend cannot resolve must demote its own callable, "
        f"not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only the annotated callables demote"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "clean" in layout.functions , (
        f"clean sibling function was lost: {sorted(layout.functions)}"
    );
    assert "Holder.also_clean" in layout.methods , (
        f"clean sibling method was lost: {sorted(layout.methods)}"
    );
    assert "takes_peer" not in layout.functions , (
        "the function whose parameter type never resolved must leave the "
        "native layout"
    );
    seams = _seams_of(coverage, "sig_unknown_seam.jac");
    owned = [
        s
        for s in seams
        if s.startswith("takes_peer: ")
    ];
    assert len(owned) == 1 , (
        f"expected exactly one coverage seam for takes_peer, got: {seams}"
    );
    assert "E5092" in owned[0] and "Peer" in owned[0] , (
        f"the seam reason must name the annotation it could not resolve: " f"{owned[0]}"
    );
    assert "signature type" in owned[0] , (
        f"the seam reason must say the refusal came from a signature, not a "
        f"body: {owned[0]}"
    );
}


# The contrast to the case above: a method signature erases a known-but-
# unlowerable type to an opaque pointer (#8206), so it never opened a refusal
# in the first place. Only the free-function declaration path resolved without
# erasing, which is why that one was the module-fatal hole.
test "a method signature keeps erasing the same annotation" {
    (_prog, ir, coverage) = _compile_with_coverage("sig_unknown_seam.jac");
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Holder.holds_peer" in layout.methods , (
        f"a method carrying the annotation the free function refused must "
        f"still erase it and lower: {sorted(layout.methods)}"
    );
    assert not [
        s
        for s in _seams_of(coverage, "sig_unknown_seam.jac")
        if s.startswith("Holder.holds_peer: ")
    ] , "an erased method signature must not also record a seam";
}

test "a signature seam is waiver-eligible like any other seam" {
    import from jaclang.utils.precompile_bytecode { seal_demotion_report }
    (_prog, _ir, coverage) = _compile_with_coverage("sig_unknown_seam.jac");
    rel = "sig_unknown_seam.jac";
    (err, _waived, _stale) = seal_demotion_report(rel, coverage);
    assert "sig_unknown_seam.jac::takes_peer" in err , (
        f"an un-waived signature seam must refuse to seal: {err}"
    );
    waivers = {rel: ("sig_unknown_seam.jac::takes_peer", )};
    (err2, waived2, stale2) = seal_demotion_report(rel, coverage, waivers=waivers);
    assert err2 == "" , f"a waived signature seam must seal: {err2}";
    assert "sig_unknown_seam.jac::takes_peer" in waived2 , (
        f"the waiver must be reported as consumed: {waived2}"
    );
    assert not stale2 , f"the waiver must not read as stale: {stale2}";
}
