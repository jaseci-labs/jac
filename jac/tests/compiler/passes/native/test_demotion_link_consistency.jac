"""A demotion verdict binds every emission in the unit, cycles included.

`_rename_demoted_symbol` moves a demoted body to `X.__jac_demoted` and pops
the original from the module's globals. A caller in another module of the
same unit that emitted BEFORE the callee's verdict landed still calls the
unsuffixed name -- a bare declaration that survives the link and kills the
sealed artifact at dlopen (`undefined symbol: pretty_print_source_location`
was the production instance: `Alert.pretty_print` in `transform.jac` was
compiled while `helpers.jac` sat inflight above it in the import walk, so
`_imported_function_demotions` answered None and the caller assumed live).

The law is #8272's, applied intra-unit: verdict-before-emission. The fix
records every callable declared live under an unknowable verdict
(`_na_unverified_live`), and the link phase -- the top frame, where every
verdict is resolvable -- re-validates the record and re-emits the caller
when a landed verdict disagrees. The re-emission is loud, and a caller that
cannot converge is E5028 rather than a broken artifact.

The fixtures are the production shape in miniature: `demote_cycle_helpers`
defines a function that demotes (`str % int`) and holds an `import type`
back-edge to the caller so the caller compiles under its inflight window;
`demote_cycle_caller.CycleReporter.describe` calls the demoted function;
`demote_cycle_root` imports them callee-first so the walk takes the failing
order deterministically.
"""

import os;
import re;
import jaclang;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image }

glob FIXTURES = os.path.join(
         os.path.dirname(os.path.dirname(os.path.realpath(jaclang.__file__))),
         "tests",
         "compiler",
         "passes",
         "native",
         "fixtures"
     ),
     _MEMO: list = [];

"""Compile the cycle root as a native unit; (linked IR text, coverage)."""
def _linked_unit -> tuple {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, "demote_cycle_root.jac");
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=path,
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    assert ir is not None and ir.gen.llvm_ir is not None , (
        "the cycle root produced no linked native IR, so nothing below "
        "measures anything"
    );
    result = (str(ir.gen.llvm_ir), coverage, );
    _MEMO.append(result);
    return result;
}


"""Symbols the unit declares but never defines, whose demoted twin exists."""
def _dangling_demoted(ir_text: str) -> list[str] {
    name_re = r'@(?:"([^"]+)"|([A-Za-z0-9_.$\-]+))\s*\(';
    defined: set[str] = set();
    declared: set[str] = set();
    for m in re.finditer(r'^define\b[^@\n]*' + name_re, ir_text, re.MULTILINE) {
        defined.add(m.group(1) or m.group(2));
    }
    for m in re.finditer(r'^declare\b[^@\n]*' + name_re, ir_text, re.MULTILINE) {
        declared.add(m.group(1) or m.group(2));
    }
    return sorted(
        n
        for n in (declared - defined)
        if f"{n}.__jac_demoted" in defined
    );
}


test "the fixture's callee still demotes, so the cycle measures something" {
    (ir_text, coverage) = _linked_unit();
    helpers_rec = coverage.get(
        os.path.realpath(os.path.join(FIXTURES, "demote_cycle_helpers.jac"))
    );
    seams = {
        str(s).partition(": ")[0] for s in ((helpers_rec or {}).get("seams") or [])
    };
    assert "cycle_bad_fmt" in seams , (
        "cycle_bad_fmt no longer demotes -- `str % int` learned to lower. "
        "Real progress, but this suite needs a construct that still demotes "
        "or every test here is vacuous; swap the fixture's body and say so"
    );
    assert "cycle_bad_fmt.__jac_demoted" in ir_text , (
        "the demoted stub itself fell out of the linked unit; the rename "
        "convention changed and this scan needs to follow it"
    );
}


test "no emission in the unit calls a symbol its verdict popped" {
    (ir_text, _coverage) = _linked_unit();
    dangling = _dangling_demoted(ir_text);
    assert not dangling , (
        f"the linked unit declares {dangling} without defining them, and "
        "each has a `.__jac_demoted` twin -- a caller was emitted before its "
        "callee's demotion verdict landed and never re-emitted. This is the "
        "shape that reaches dlopen as `undefined symbol` in a sealed "
        "artifact (#8320 / #8323 A1)"
    );
}


test "the betrayed caller re-emits and cascades honestly" {
    (_ir_text, coverage) = _linked_unit();
    caller_rec = coverage.get(
        os.path.realpath(os.path.join(FIXTURES, "demote_cycle_caller.jac"))
    );
    seams = {
        str(s).partition(": ")[0] for s in ((caller_rec or {}).get("seams") or [])
    };
    assert "CycleReporter.describe" in seams , (
        "CycleReporter.describe kept a live body against a demoted callee "
        "(or its cascade demotion went unrecorded). The re-emission must "
        "produce the same verdict the acyclic order produces: the caller of "
        "a demoted function demotes, and the coverage says so"
    );
}


test "an oversized composition trips the blast-radius guard fast and loud" {
    import from jaclang.compiler.passes.native.na_compile_pass {
        NATIVE_LINK_COMPILE_BOUND,
        NATIVE_VERDICT_MISS_BOUND,
        NATIVE_VERDICT_TAINT_BOUND,
        native_verdict_blast_guard
    }

    prog = JacProgram();
    assert native_verdict_blast_guard(prog, 0) == "" , (
        "a fresh program tripped the guard; the bounds are below healthy "
        "baseline and every build would refuse"
    );

    fabricated: dict = {};
    per_mod = 64;
    mods = (NATIVE_VERDICT_TAINT_BOUND // per_mod) + 2;
    for i in range(mods) {
        fabricated[f"/fab/mod_{i}.jac"] = {
            "/fab/callee.jac": {f"name_{i}_{j}" for j in range(per_mod)}
        };
    }
    prog._na_unverified_live = fabricated;
    msg = native_verdict_blast_guard(prog, 0);
    assert msg != "" , (
        "a fabricated unverified-live set larger than the taint bound did "
        "not trip the guard; the avalanche class can present as a silent "
        "hour again"
    );
    assert str(mods * per_mod) in msg and str(mods) in msg , (
        f"the refusal must carry the numbers that tripped it, got: {msg}"
    );

    prog2 = JacProgram();
    msg2 = native_verdict_blast_guard(prog2, NATIVE_LINK_COMPILE_BOUND + 1);
    assert msg2 != "" and str(NATIVE_LINK_COMPILE_BOUND + 1) in msg2 , (
        "an oversized link-time composition did not trip the guard or the "
        f"refusal hid the count: {msg2}"
    );

    prog3 = JacProgram();
    prog3._na_verdict_misses = NATIVE_VERDICT_MISS_BOUND + 7;
    msg3 = native_verdict_blast_guard(prog3, 0);
    assert msg3 != "" and str(NATIVE_VERDICT_MISS_BOUND + 7) in msg3 , (
        "systematic fail-closed verdict misses did not trip the guard or "
        f"the refusal hid the count: {msg3}"
    );

    assert native_verdict_blast_guard(prog, 0, aot_lane=True) == "" , (
        "the aot lane's taint is pending convergence work, not pathology; "
        "bounding it below a healthy seal baseline refuses every large "
        "sealed unit (the unitree root alone carries thousands of "
        "provisional names mid-walk)"
    );
    assert native_verdict_blast_guard(prog3, 0, aot_lane=True) != "" , (
        "fail-closed misses must trip the guard in every lane; aot "
        "tolerance is for the taint lever only"
    );
}

"""The verdict apparatus is an aot-lane contract, and its resolver is bounded.

Two pins from the pack-smoke stall hunt. First, the lane: in the JIT /
bytecode-precompile lane, `_imported_function_demotions` answers None from
its not-aot arm -- that None means "this lane does not do cross-module
verdicts", not "verdict pending" -- so the emission-side recorder must stay
silent there, or every import edge becomes taint whose link-time
re-validation compiles callees (installed runtime sources included) as a
silent avalanche. Second, the resolver: `native_unit_demotions`' compile
arm must refuse a callee that is inflight, mid-compile (hub tree with no
IR yet), or already being resolved -- answering fail-closed (None, read
as conflict-on-every-tainted-name) at worst costing one E5028-bounded
re-emission -- because compiling such a callee re-enters its own schedule
and the recursion has no other floor.
"""
test "the non-aot lane records no verdict taint" {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    path = os.path.join(FIXTURES, "demote_cycle_root.jac");
    prog = JacProgram();
    ir = prog.compile(
        file_path=path,
        options=CompileOptions(
            force_codespace='native', force_target_program=True, no_ir_cache=True
        )
    );
    assert ir is not None , "the JIT-lane compile produced no module";
    assert not prog._na_unverified_live , (
        f"a non-aot compile recorded verdict taint for "
        f"{len(prog._na_unverified_live)} module(s). The not-aot None from "
        "_imported_function_demotions is a lane statement, not a pending "
        "verdict; recording it makes link-time re-validation compile "
        "callees in a lane that never asked for verdicts"
    );
}


test "the verdict resolver refuses an inflight or mid-compile callee" {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    import from jaclang.compiler.passes.native.na_compile_pass { native_unit_demotions }
    import from jaclang.jac0core.compile_options { CompileOptions as _Opts }
    helpers_path = os.path.realpath(os.path.join(FIXTURES, "demote_cycle_helpers.jac"));
    prog = JacProgram();
    prog._na_dep_inflight.add(helpers_path);
    demoted = native_unit_demotions(prog, helpers_path, _Opts(aot_mode=True));
    assert helpers_path not in prog._na_dep_units , (
        "the resolver compiled an inflight callee -- that compile re-enters "
        "the callee's own schedule and the recursion has no floor"
    );
    assert demoted is None , (
        "an unresolvable callee must answer None -- the fail-closed signal "
        "the conflict check reads as conflict-on-every-tainted-name -- "
        f"not {demoted!r}"
    );
    prog._na_dep_inflight.discard(helpers_path);
}


test "the wheel-shaped lane stays quiet on the live closure" {
    import from jaclang.compiler.passes.native.na_compile_pass {
        native_verdict_blast_guard
    }

    pkg = os.path.dirname(os.path.abspath(jaclang.__file__));
    target = os.path.join(pkg, "runtimelib", "sealed_serve.jac");
    if not os.path.isfile(target) {
        testskip("sealed_serve.jac is absent from this payload");
    }
    prog = JacProgram();
    mod = prog.compile(file_path=target);
    assert mod is not None;
    assert len(prog._na_unverified_live) == 0 , (
        "a plain (non-aot) compile of the pack-smoke closure recorded "
        f"{len(prog._na_unverified_live)} tainted module(s); the emission "
        "recorder is out of its lane and the #8360 avalanche class is back"
    );
    assert prog._na_verdict_misses == 0 , (
        f"{prog._na_verdict_misses} verdict lookup(s) failed closed during "
        "a lane that must never consult the resolver at link time"
    );
    assert native_verdict_blast_guard(prog, 0) == "" , (
        "the blast-radius guard tripped on the live closure; either the "
        "lane regressed or the bounds dipped below healthy baseline"
    );
}


"""The methods-side twin of the free-function trust hole, pinned closed.

A consumer method reading `CodeGenTarget.doc_ir` -- an accessor its
jaclang-internal defining module demotes -- must end in one of two honest
states: the verdict binds and the consumer demotes with the coverage saying
so, or the module never joins the unit and the read refuses by name. What
it must never do is dangle: a declared symbol whose only definition was
renamed away. The same `_dangling_demoted` scan the cycle tests use is the
arbiter here, over a unit whose betrayal vector is a method rather than a
free function.
"""
test "an internal module's demoted method cannot dangle through a consumer" {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    path = os.path.join(FIXTURES, "demote_internal_method.jac");
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=path,
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    assert ir is not None and ir.gen.llvm_ir is not None , (
        "the internal-method probe produced no linked native IR, so nothing "
        "here measures anything"
    );
    ir_text = str(ir.gen.llvm_ir);
    dangling = _dangling_demoted(ir_text);
    assert not dangling , (
        f"the linked unit declares {dangling} without defining them, each "
        "with a `.__jac_demoted` twin -- the methods-side emission ran "
        "ahead of its callee module's verdict (#8323 A10b's scenario)"
    );
    rec = coverage.get(os.path.realpath(path));
    seams = {str(s).partition(": ")[0] for s in ((rec or {}).get("seams") or [])};
    assert "InternalProbe.read_docir" in seams , (
        "the consumer's read of a demoted internal accessor neither demoted "
        "nor refused -- if it lowers now, the internal module's accessor "
        "learned to cross, which needs its own measurement; re-pin this "
        "with the mechanism named"
    );
}
