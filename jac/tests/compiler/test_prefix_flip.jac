"""The production flip's machinery: routing, the fallback taxonomy, the outcome table.

Wave A' item A5. The sealed binary compiles through the fused native prefix by
default; a module the prefix cannot take rides the staged pass loop, and every
such decline is counted and NAMED. These tests hold three properties that no
amount of prefix work can supply on its own:

  1. The pins are true. `sealed_prefix_names` claims a schedule head; if the
     real schedule ever leads with a different pass the crossing would execute
     something the driver did not schedule. The pin tests below compare the
     claim against `get_ir_gen_sched` / `get_symtab_ir_sched` directly, and
     also assert the claim is MAXIMAL -- the pass just past the prefix is one
     the image has not sealed, so a seal landing without extending the prefix
     shows up here as a stale claim rather than as silently lost scope.

  2. Every fallback names itself. There is one route out of the prefix and it
     goes through `PREFIX_CLAUSES`; a clause that is not registered has no
     help text and no report line. Each clause below is driven to fire.

  3. A fallback is telemetry, never silence. The counter, the summary line,
     the per-module report and the strict-mode assertion are exercised
     together, because the counter is the seed of the wave-D invariant and a
     counter nobody can read is not an invariant.

The prefix entry is pluggable; these tests install stand-ins from
`fixtures/prefix_reference.jac` rather than waiting for the native crossing.
That is the point of the seam -- the machinery ships and is tested before the
thing it routes to exists.
"""

import os;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from tests.compiler.fixtures.prefix_reference {
    diverging_prefix_entry,
    exploding_prefix_entry,
    lying_prefix_entry,
    reference_prefix_entry
}
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { get_ir_gen_sched, get_symtab_ir_sched }
import from jaclang.jac0core.native_brands {
    DRIVER_ORIGIN,
    ensure_native_brands_bound,
    native_brand_origin,
    native_brand_origins,
    native_brands_bound
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.prefix_flip {
    PREFIX_CLAUSES,
    PREFIX_IR_GEN,
    PREFIX_IR_GEN_NO_CGEN,
    PREFIX_SYMTAB_IR,
    clear_prefix_entry,
    drop_executed_prefix,
    prefix_admit_count,
    prefix_outcomes_reset,
    prefix_clause_help,
    prefix_clause_names,
    prefix_entry,
    prefix_fallback_count,
    prefix_fallbacks_by_clause,
    prefix_native_pass_count,
    prefix_quarantine,
    prefix_quarantine_clear,
    prefix_quiet_clauses,
    prefix_report_lines,
    prefix_snapshot,
    prefix_stats_lines,
    prefix_strict_assert,
    prefix_summary_line,
    sealed_prefix_names,
    set_prefix_entry
}

glob PROBE_SRC: str = (
         'glob greeting: str = "hi";\n'
         + "obj Widget {\n"
         + "    has n: int = 1;\n"
         + "    def bump -> int {\n"
         + "        self.n += 1;\n"
         + "        return self.n;\n"
         + "    }\n"
         + "}\n"
         + "with entry {\n"
         + "    w = Widget();\n"
         + "    print(greeting, w.bump());\n"
         + "}\n"
     );

"""Write a standalone .jac module with no annex siblings -- the shape the
predicate admits today -- and hand back its path."""
def _probe_module(tmp: str, name: str, src: str = "") -> str {
    path = os.path.join(tmp, name);
    Path(path).write_text(src or PROBE_SRC, encoding="utf-8");
    return path;
}

def _compile(path: str, no_cgen: bool = True) -> tuple[any] {
    prog = JacProgram();
    mod = prog.compile(
        file_path=path,
        options=CompileOptions(
            type_check=False, no_cgen=no_cgen, force_target_program=True
        )
    );
    return (prog, mod);
}

def _reset {
    clear_prefix_entry();
    prefix_outcomes_reset();
    prefix_quarantine_clear();
}


test "the claimed prefix is exactly the schedule's head" {
    cgen_names = [p.__name__ for p in get_ir_gen_sched(gen_mtir=True)];
    assert cgen_names[:len(PREFIX_IR_GEN)] == list(PREFIX_IR_GEN) , (
        "the ir-gen prefix claim drifted from the schedule: schedule leads "
        f"with {cgen_names[:len(PREFIX_IR_GEN)]}, prefix_flip claims "
        f"{list(PREFIX_IR_GEN)}. Fix sealed_prefix_names, never the crossing."
    );
    nocgen_names = [p.__name__ for p in get_ir_gen_sched(gen_mtir=False)];
    assert nocgen_names[:len(PREFIX_IR_GEN_NO_CGEN)] == list(PREFIX_IR_GEN_NO_CGEN) , (
        f"the no-cgen prefix claim drifted: schedule leads with "
        f"{nocgen_names[:len(PREFIX_IR_GEN_NO_CGEN)]}"
    );
    symtab_names = [p.__name__ for p in get_symtab_ir_sched()];
    assert symtab_names[:len(PREFIX_SYMTAB_IR)] == list(PREFIX_SYMTAB_IR) , (
        f"the symtab-ir prefix claim drifted: schedule leads with "
        f"{symtab_names[:len(PREFIX_SYMTAB_IR)]}"
    );
}

test "the claimed prefix stops at the first unsealed pass" {
    import from jaclang.utils.precompile_bytecode { NATIVE_SEAL_ROOTS }
    sealed_mods = set(NATIVE_SEAL_ROOTS);
    cgen = get_ir_gen_sched(gen_mtir=True);
    nxt = cgen[len(PREFIX_IR_GEN)];
    assert nxt.__name__ == "MTIRGenPass" , (
        f"the pass past the ir-gen prefix is {nxt.__name__}, not MTIRGenPass. "
        "If it is now sealed, extend PREFIX_IR_GEN -- production scope grows "
        "with every seal (wave B' item B2), it does not wait."
    );
    assert nxt.__module__ not in sealed_mods , (
        f"{nxt.__name__} is sealed but sits outside the claimed prefix; the "
        "prefix claim is stale and the binary is executing less than it can."
    );
    nocgen = get_ir_gen_sched(gen_mtir=False);
    nxt2 = nocgen[len(PREFIX_IR_GEN_NO_CGEN)];
    assert nxt2.__name__ == "PlacementApplyPass" , (
        f"the pass past the no-cgen prefix is {nxt2.__name__}"
    );
}

test "every fallback clause is registered, unique, and has help text" {
    names = list(prefix_clause_names());
    assert len(names) == len(set(names)) , f"duplicate clause names: {names}";
    assert len(names) == len(PREFIX_CLAUSES);
    for n in names {
        assert n , "an unnamed clause is a silent fallback";
        assert prefix_clause_help(n) , f"clause {n} carries no help text";
        assert n == n.lower() and " " not in n , (
            f"clause {n} is not a stable machine-readable token"
        );
    }
    assert prefix_clause_help("not-a-clause") == "unregistered clause";
}

"""Drive a real compile if nothing has reached the brand point yet."""
def _force_driver_bind -> None {
    import tempfile;
    if native_brand_origins() {
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        _compile(_probe_module(tmp, "brandbind.jac"));
    }
}

"""Binding the materializer is CLASS-IDENTITY registration: bind_native_parser
runs mat_reset and then mat_set_class(i, id(cls), id(cls.__new__)) for every
class in the manifest. WHEN that happens is therefore observable to the type
checker, and a binder called at a new point can leave two brands of the same
class in play -- which is exactly how this seam once manufactured an E1053
refusing a native lowering with "Cannot assign Source to parameter 'orig_src'
of type Source".

The invariant, adopted with the crossing team: brands bind ONCE, at a
deterministic point the driver owns, that both routes share. Not lazily from
inside a route predicate, not from whichever of parse-first or
pass-construction-first happened to win the race. `ensure_native_brands_bound`
is that point and the only function that reaches the binder; everything else
-- frontend._native_parse, the prefix predicate, the pass-serving merge canary
-- is a consumer that routes through it and records why it asked.

These tests hold the invariant structurally rather than by luck: the FIRST
recorded origin must be the driver's, whatever order the lazy consumers
arrive in."""
test "the driver owns the first native brand binding" {
    _force_driver_bind();
    origins = native_brand_origins();
    assert origins , "nothing reached the brand point during a compile";
    assert origins[0] == DRIVER_ORIGIN , (
        f"the first thing to bind the native brands was {origins[0]!r}, not "
        f"{DRIVER_ORIGIN!r}. A lazy consumer beat the driver to the binder, "
        "which is the reordering that produced the two-brands E1053. The "
        "driver-owned point must dominate every consumer."
    );
}

test "a late consumer cannot become the brand-binding origin" {
    _force_driver_bind();
    first = native_brand_origin();
    assert first == DRIVER_ORIGIN;
    ensure_native_brands_bound("test:late-consumer");
    assert native_brand_origin() == first , (
        "a consumer that arrived after the brand point was first reached "
        "overwrote the origin. The origin records who got there FIRST, and so "
        "who would do the binding, never who asked last."
    );
    import jaclang.jac0core.parser.frontend as _fe;
    assert len(_fe._NATIVE_PARSE_MEMO) <= 1 , (
        f"the raw binder cached {len(_fe._NATIVE_PARSE_MEMO)} results; brands "
        "register at most once per process"
    );
}

"""A negative probe is not a brand registration, so it must not latch. An
image can be registered after the driver has already asked -- the sealed
parser suite does exactly that, serving a freshly built artifact through
`sealed.native_artifact_for` and clearing the parser memo -- and a binding
point that cached the earlier "no image" answer would refuse it forever. Only
a real bind latches; asking is always allowed to try again."""
test "asking before an image exists does not latch the answer" {
    _force_driver_bind();
    if native_brands_bound() {
        testskip("an image is bound in this process; the latch is correct");
    }
    before = len(native_brand_origins());
    assert ensure_native_brands_bound("test:probe") is None;
    assert not native_brands_bound() , (
        "a probe that found no image marked the brands bound; a later "
        "register_image could then never bind"
    );
    assert len(native_brand_origins()) > before , (
        "the attempt was not recorded, so the origin trail has a hole in it"
    );
}

"""Declining must not touch the native parser. `_native_parse` binds the
materializer artifact, and binding registers CLASS IDENTITIES -- mat_set_class
stamps id(cls) for every class in the manifest. Resolving the entry from
inside the predicate therefore used to drag that brand registration earlier in
the compile than the parse would have done it, and on wavea-core @ 569bb113d
that reordering made the checker see two `Source` brands and refuse a native
lowering with E1053 (`Cannot assign Source to parameter 'orig_src' of type
Source`) that neither the tree without this seam nor a later base produced.

The predicate now asks whether the entry SYMBOL exists before it asks whether
an image is bound, so while no crossing exists the decline path never reaches
the binder at all. This test pins that ordering: the flip's central claim is
that a declining compile is indistinguishable from one with no flip in the
tree, and a binder called at a new time breaks it."""
test "declining the prefix does not force the native parser binding" {
    import jaclang.jac0core.parser.frontend as _fe;
    _reset();
    if _fe?.parse_and_run_prefix is not None {
        testskip("the crossing exists; this pins the entry-absent path");
    }
    bound_before = len(_fe._NATIVE_PARSE_MEMO);
    (fn, clause, _detail) = prefix_entry();
    assert fn is None;
    assert clause == "prefix-entry-absent" , (
        f"expected the symbol check to answer first, got {clause}"
    );
    assert len(_fe._NATIVE_PARSE_MEMO) == bound_before , (
        "resolving an absent prefix entry bound the native parser. That "
        "registers the materializer's class identities at a point the "
        "unflipped compiler never would, which is how this seam once "
        "manufactured a two-brands E1053."
    );
    _reset();
}

test "the quiet clauses are exactly the three missing capabilities" {
    quiet = list(prefix_quiet_clauses());
    assert quiet == ["image-unsealed", "prefix-entry-absent", "annex-present"] , (
        f"the quiet set changed to {quiet}. A clause goes quiet only when it "
        "names a whole capability the build lacks -- no image, no prefix "
        "entry, no annex weave -- because those fire for most modules of most "
        "projects and a line each would be noise. Anything that names a "
        "module going wrong stays loud. This tuple empties as the waves land."
    );
    for q in quiet {
        assert q in prefix_clause_names() , (
            f"{q} is quiet but not registered, so it has no help text"
        );
    }
    loud = [
        c
        for c in prefix_clause_names()
        if c not in quiet
    ];
    assert "crossing-error" in loud and "parity-guard-trip" in loud , (
        "a crossing that raised or a module that diverged must never be quiet"
    );
}

test "an unclaimed schedule kind yields an empty prefix" {
    assert sealed_prefix_names("ir-gen") == PREFIX_IR_GEN;
    assert sealed_prefix_names("ir-gen", no_cgen=True) == PREFIX_IR_GEN_NO_CGEN;
    assert sealed_prefix_names("symtab-ir") == PREFIX_SYMTAB_IR;
    assert sealed_prefix_names("codegen") == ();
    assert sealed_prefix_names("") == ();
}

test "drop_executed_prefix trims the head and refuses a mismatch" {
    sched = get_ir_gen_sched(gen_mtir=True);
    assert drop_executed_prefix(sched, ()) == sched;
    trimmed = drop_executed_prefix(sched, PREFIX_IR_GEN);
    assert len(trimmed) == len(sched) - len(PREFIX_IR_GEN);
    assert trimmed[0].__name__ == "MTIRGenPass";
    with testraises(RuntimeError) as excinfo {
        drop_executed_prefix(sched, ("SemDefMatchPass", ));
    }
    assert "does not lead with" in str(excinfo.value);
}

test "with no prefix entry every module falls back under a named clause" {
    _reset();
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        path = _probe_module(tmp, "quiet.jac");
        (_prog, mod) = _compile(path);
        assert mod is not None;
    }
    snap = prefix_snapshot();
    assert len(snap) >= 1 , "the router recorded nothing for a real compile";
    assert prefix_admit_count() == 0;
    assert prefix_fallback_count() == len(snap);
    for (p, rec) in snap.items() {
        assert rec["clause"] in prefix_clause_names() , (
            f"{p} fell back under the unregistered clause {rec['clause']}"
        );
    }
    _reset();
}

test "JAC_PREFIX=off names itself as the reason" {
    _reset();
    import tempfile;
    prev = os.environ.get("JAC_PREFIX");
    os.environ["JAC_PREFIX"] = "off";
    try {
        set_prefix_entry(reference_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "off.jac");
            (_prog, mod) = _compile(path);
            assert mod is not None;
        }
        by_clause = prefix_fallbacks_by_clause();
        assert by_clause.get("disabled-by-env", 0) >= 1 , (
            f"JAC_PREFIX=off did not name itself: {by_clause}"
        );
    } finally {
        if prev is None {
            os.environ.pop("JAC_PREFIX", None);
        } else {
            os.environ["JAC_PREFIX"] = prev;
        }
        _reset();
    }
}

test "a quarantined module reports the parity-guard trip by name" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(reference_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "quarantined.jac");
            prefix_quarantine(path, "prefix and staged unparse diverged");
            (_prog, mod) = _compile(path);
            assert mod is not None;
        }
        by_clause = prefix_fallbacks_by_clause();
        assert by_clause.get("parity-guard-trip", 0) >= 1 , (
            f"the quarantine did not surface: {by_clause}"
        );
        joined = chr(10).join(prefix_report_lines());
        assert "prefix and staged unparse diverged" in joined , (
            f"the quarantine detail was dropped from the report: {joined}"
        );
    } finally {
        _reset();
    }
}

test "a module with annexes declines before it is parsed" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(reference_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(
                tmp, "annexed.jac", "obj Gadget {\n    def bump -> int;\n}\n"
            );
            Path(os.path.join(tmp, "annexed.impl.jac")).write_text(
                "impl Gadget.bump -> int {\n    return 1;\n}\n", encoding="utf-8"
            );
            (_prog, mod) = _compile(path);
            assert mod is not None;
        }
        by_clause = prefix_fallbacks_by_clause();
        assert by_clause.get("annex-present", 0) >= 1 , (
            f"an annexed module was not declined by name: {by_clause}"
        );
    } finally {
        _reset();
    }
}

test "a crossing that raises is counted, named, and still yields a module" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(exploding_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "boom.jac");
            (_prog, mod) = _compile(path);
            assert mod is not None , (
                "a raising crossing must fall back, not fail the compile"
            );
        }
        by_clause = prefix_fallbacks_by_clause();
        assert by_clause.get("crossing-error", 0) >= 1 , (
            f"a raising crossing was not named: {by_clause}"
        );
        joined = chr(10).join(prefix_report_lines());
        assert "the crossing exploded" in joined , (
            "the crossing's own message must survive into the report"
        );
    } finally {
        _reset();
    }
}

test "a crossing that reports passes the schedule lacks is refused loudly" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(lying_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "liar.jac");
            with testraises(RuntimeError) as excinfo {
                _compile(path);
            }
            assert "not a prefix of the claimed" in str(excinfo.value) , (
                f"the refusal did not name the violation: {excinfo.value}"
            );
        }
    } finally {
        _reset();
    }
}

test "a crossing that declines short names its own reason" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(diverging_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "short.jac");
            (_prog, mod) = _compile(path);
            assert mod is not None;
        }
        by_clause = prefix_fallbacks_by_clause();
        assert by_clause.get("prefix-declined", 0) >= 1 , (
            f"a short executed list was not named: {by_clause}"
        );
        joined = chr(10).join(prefix_report_lines());
        assert "divergence fixture" in joined;
    } finally {
        _reset();
    }
}

test "the reference prefix is admitted and its passes are counted" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(reference_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "admitted.jac");
            (_prog, mod) = _compile(path);
            assert mod is not None;
            snap = prefix_snapshot();
            rec = snap.get(os.path.realpath(path));
            assert rec is not None , f"the router did not record {path}: {snap}";
            assert rec["admitted"] , (
                f"the reference prefix was declined: "
                f"{rec['clause']} -- {rec['detail']}"
            );
            assert list(rec["executed"]) == list(PREFIX_IR_GEN_NO_CGEN) , (
                f"executed {rec['executed']}, claimed {rec['claimed']}"
            );
        }
        assert prefix_admit_count() >= 1;
        assert prefix_native_pass_count() >= len(PREFIX_IR_GEN_NO_CGEN);
    } finally {
        _reset();
    }
}

test "the summary line is silent on quiet clauses and loud on real declines" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(exploding_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "loud.jac");
            _compile(path);
        }
        line = prefix_summary_line();
        assert line , "a real decline produced no summary line";
        assert "crossing-error" in line , (
            f"the summary line does not name the clause: {line}"
        );
        assert "JAC_PREFIX_REPORT" in line , (
            "the summary must point at the per-module surface"
        );
    } finally {
        _reset();
    }
    assert prefix_summary_line() == "" , (
        "an empty outcome table must produce no line at all"
    );
}

test "strict mode turns any fallback into a named hard error" {
    _reset();
    import tempfile;
    prev = os.environ.get("JAC_PREFIX_STRICT");
    try {
        set_prefix_entry(exploding_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "strict.jac");
            _compile(path);
        }
        os.environ.pop("JAC_PREFIX_STRICT", None);
        prefix_strict_assert();
        os.environ["JAC_PREFIX_STRICT"] = "1";
        with testraises(RuntimeError) as excinfo {
            prefix_strict_assert();
        }
        msg = str(excinfo.value);
        assert "JAC_PREFIX_STRICT=1" in msg;
        assert "crossing-error" in msg , (
            f"strict mode did not name the clause: {msg}"
        );
        assert "strict.jac" in msg , f"strict mode did not name the module: {msg}";
    } finally {
        if prev is None {
            os.environ.pop("JAC_PREFIX_STRICT", None);
        } else {
            os.environ["JAC_PREFIX_STRICT"] = prev;
        }
        _reset();
    }
    os.environ.pop("JAC_PREFIX_STRICT", None);
    prefix_strict_assert();
}

test "the stats surface reports natively executed passes per module" {
    _reset();
    import tempfile;
    try {
        set_prefix_entry(reference_prefix_entry);
        with tempfile.TemporaryDirectory() as tmp {
            path = _probe_module(tmp, "stats.jac");
            _compile(path);
            lines = prefix_stats_lines();
            assert lines , "the stats surface said nothing after a compile";
            assert "compile stats:" in lines[0];
            assert "native prefix" in lines[0] or "module(s)" in lines[0];
            body = chr(10).join(lines);
            assert "SymTabBuildPass" in body , (
                f"the per-module pass list is missing: {body}"
            );
            assert "%" in lines[0] , (
                "the scope percentage is the point of the surface"
            );
        }
    } finally {
        _reset();
    }
    assert "no module reached the prefix router" in prefix_stats_lines()[0];
}
