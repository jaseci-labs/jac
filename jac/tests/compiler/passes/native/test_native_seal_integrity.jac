"""Seal integrity: a native demotion must never ship as an abort stub.

In-process, a method the native backend cannot lower is demoted and falls back
to its Python implementation -- congruence survives and only speed is lost. A
*sealed* artifact has no Python left to fall back to, so the same demotion is
emitted as an `abort()` stub and the first call kills the process with no
diagnostic. Every congruence gap therefore turns from "slower" into "runtime
crash", which is what made the old sealed native parser artifact segfault for
weeks without an explanation.

These tests pin the build-time gate that closes that hole:

1. a module the backend lowers in full still seals, and its artifact passes the
   dlopen + canary smoke before it is written into the manifest;
2. a module carrying an un-lowerable method *fails* the seal, with a diagnostic
   that names the method, says what shipping it would cost, and points at both
   the waiver list and the debug gate; nothing is written to the output tree;
3. the same holds for a demotion one hop out in the sealed closure, it survives
   a warm native IR cache, and the abort-stub scan that guarantees it reads the
   IR that actually ships rather than the census;
4. naming that exact method in the waiver list lets the seal through and says
   so on stderr -- while waiving some *other* method does not launder it, and a
   waiver matching no real demotion is reported as stale;
5. the canary rejects a broken artifact, and a canary failure inside the seal
   deletes the artifact and refuses the seal;
6. `JAC_NA_DEBUG=1` explains the demotion behind the refusal.

Assertions on the seal's own diagnostic go through `_seal_diag`, which slices
stderr from the first `NATIVE SEAL:` marker. The pre-existing
`warning: native seam -- demoting ...` line is printed by the codegen pass
before the seal ever runs and already names the method and `eval`, so asserting
against the raw stderr buffer would pass without this gate existing at all.
"""

import contextlib;
import hashlib;
import io;
import json;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.jir { get_native_cache_dir }
import from jaclang.jac0core.program { JacProgram }
import jaclang.utils.precompile_bytecode as pb;
import from jaclang.utils.precompile_bytecode {
    seal_abort_stubs,
    seal_native_artifacts,
    seal_native_canary
}

glob FIXTURES = Path(TESTS_DIR) / "compiler" / "passes" / "native" / "fixtures";


"""Seal one fixture into a fresh temp tree.

Returns (artifacts, captured_stderr, tmpdir). `JAC_SEAL_NO_NATIVE` is dropped
for the duration so an ambient setting cannot turn the seal into a no-op.
"""
def _seal(rel: str, waivers: (dict | None) = None, na_debug: bool = False) -> tuple {
    tmp = tempfile.mkdtemp(prefix="jac_seal_integrity_");
    saved_skip = os.environ.pop("JAC_SEAL_NO_NATIVE", None);
    saved_dbg = os.environ.pop("JAC_NA_DEBUG", None);
    if na_debug {
        os.environ["JAC_NA_DEBUG"] = "1";
    }
    buf = io.StringIO();
    try {
        with contextlib.redirect_stderr(buf) {
            arts = seal_native_artifacts(
                FIXTURES, Path(tmp), modules=(rel, ), waivers=waivers
            );
        }
    } finally {
        os.environ.pop("JAC_NA_DEBUG", None);
        if saved_skip is not None {
            os.environ["JAC_SEAL_NO_NATIVE"] = saved_skip;
        }
        if saved_dbg is not None {
            os.environ["JAC_NA_DEBUG"] = saved_dbg;
        }
    }
    return (arts, buf.getvalue(), tmp);
}


"""stderr from the first `NATIVE SEAL:` marker on: the seal's own diagnostics,
with the codegen pass's pre-existing seam warning excluded."""
def _seal_diag(err: str) -> str {
    idx = err.find("NATIVE SEAL:");
    return err[idx:] if idx >= 0 else "";
}


"""AOT-compile a fixture the way the seal does, returning (ir_text, seam_count).

`no_ir_cache` is threaded through so a test can deliberately reproduce the warm
native IR cache the seal itself refuses to read.
"""
def _compile_native(rel: str, no_ir_cache: bool) -> tuple[str, int] {
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=str(FIXTURES / rel),
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=no_ir_cache
            )
        );
    } finally {
        census = na_census_end();
    }
    assert ir is not None and ir.gen.llvm_ir is not None , f"no native IR for {rel}";
    seams = 0;
    for rec in census.values() {
        seams += len(rec["seams"]);
    }
    return (str(ir.gen.llvm_ir), seams);
}


def _dep_cache_entries(rel: str) -> list[str] {
    src = str(FIXTURES / rel);
    cache_dir = str(get_native_cache_dir(src));
    stem = os.path.splitext(os.path.basename(src))[0];
    if not os.path.isdir(cache_dir) {
        return [];
    }
    return sorted(
        f
        for f in os.listdir(cache_dir)
        if f.startswith(f"{stem}.") and f.endswith((".ir_cache", ".ir_meta"))
    );
}


test "a fully lowerable module still seals and its artifact is live" {
    (arts, err, tmp) = _seal("seal_clean.jac");
    try {
        assert arts is not None , f"clean module failed the seal:\n{err}";
        assert "fixtures.seal_clean" in arts , f"unexpected artifacts: {list(arts)}";
        rec = arts["fixtures.seal_clean"];
        lib = Path(tmp) / rec["lib"];
        assert lib.is_file() , f"no shared library at {lib}";
        assert hashlib.sha256(lib.read_bytes()).hexdigest() == rec["lib_sha256"] , (
            "manifest lib_sha256 does not match the artifact on disk"
        );
        layout = json.loads((Path(tmp) / rec["layout"]).read_text(encoding="utf-8"));
        assert "run" in layout["functions"] , f"exports: {sorted(layout['functions'])}";
        assert "Counter.bump" in layout["methods"] , (
            f"methods: {sorted(layout['methods'])}"
        );
        assert "canary" in err.lower() , (
            f"the seal accepted an artifact without running the canary:\n{err}"
        );
        assert _seal_diag(err) == "" , (
            f"a clean seal must raise no NATIVE SEAL diagnostic:\n{err}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "an un-lowerable method fails the seal with an actionable diagnostic" {
    (arts, err, tmp) = _seal("seal_demoted_method.jac");
    try {
        assert arts is None , (
            "the seal accepted a module whose Gauge.unlowerable demoted; in a "
            f"sealed artifact that demotion ships as an abort stub. Got: {arts}"
        );
        diag = _seal_diag(err);
        assert diag , f"the seal refused without any NATIVE SEAL diagnostic:\n{err}";
        assert "Gauge.unlowerable" in diag , (
            f"the seal diagnostic does not name the offending method:\n{diag}"
        );
        assert "abort stub" in diag , (
            f"the seal diagnostic does not say what shipping it costs:\n{diag}"
        );
        assert "NATIVE_SEAL_DEMOTION_WAIVERS" in diag , (
            f"the seal diagnostic does not point at the waiver hatch:\n{diag}"
        );
        assert "JAC_NA_DEBUG" in diag , (
            f"the seal diagnostic does not name the debug gate:\n{diag}"
        );
        assert "eval" in diag , (
            f"the seal diagnostic drops the reason it could not lower:\n{diag}"
        );
        assert not list(Path(tmp).rglob("*.so")) , (
            "a refused seal still wrote a shared library into the output tree"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a demotion one hop out cannot hide behind a warm native IR cache" {
    # One test, not three: every stage below touches the same on-disk cache
    # entries for seal_xmod_dep.jac, so splitting them would race under xdist.

    # Stage 1: the demotion is in a transitive native import, not in the sealed
    # module itself. The census loop must see more than one module.
    (arts, err, tmp) = _seal("seal_xmod_root.jac");
    try {
        assert arts is None , (
            f"a demotion one hop out in the sealed closure was accepted: {arts}"
        );
        diag = _seal_diag(err);
        assert "Meter.unlowerable" in diag , (
            f"the seal diagnostic does not name the transitive demotion:\n{diag}"
        );
        assert "seal_xmod_dep" in diag , (
            f"the seal diagnostic does not say which module demoted:\n{diag}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }

    # Stage 2: the refused seal must not leave the demoted dependency's IR in
    # the on-disk cache, or the next seal would inherit it.
    assert _dep_cache_entries("seal_xmod_dep.jac") == [] , (
        "a refused seal left the demoted dependency's native IR cached; a "
        f"re-run would link it: {_dep_cache_entries('seal_xmod_dep.jac')}"
    );

    # Stage 3: same sources, now with whatever cache state stage 1 left. The
    # verdict must be identical -- it is a function of the sources, not of
    # cache warmth.
    (arts2, err2, tmp2) = _seal("seal_xmod_root.jac");
    try {
        assert arts2 is None , (
            "the seal verdict flipped on a second run with identical sources; "
            f"cache warmth decided it. Got: {arts2}"
        );
        assert "Meter.unlowerable" in _seal_diag(err2) , _seal_diag(err2);
    } finally {
        shutil.rmtree(tmp2, ignore_errors=True);
    }

    # Stage 4: why the seal cannot rely on the census alone. Compiling with the
    # native IR cache enabled twice makes the second compile serve the demoted
    # dependency straight from disk, so NaIRGenPass never runs for it and the
    # census records no seam at all. The abort-stub scan reads the IR that
    # actually ships, so it still finds the stub.
    _compile_native("seal_xmod_root.jac", False);
    (warm_ir, warm_seams) = _compile_native("seal_xmod_root.jac", False);
    assert warm_seams == 0 , (
        "expected the warm native IR cache to produce an empty census (that is "
        f"the hole the scan backstops), got {warm_seams} seam(s)"
    );
    assert "Meter.unlowerable" in seal_abort_stubs(warm_ir) , (
        "the abort-stub scan missed a demotion the census could not see; the "
        f"gate is only as good as cache warmth. stubs={seal_abort_stubs(warm_ir)}"
    );

    # And it must not cry wolf on a module that lowers in full.
    (clean_ir, clean_seams) = _compile_native("seal_clean.jac", True);
    assert clean_seams == 0;
    assert seal_abort_stubs(clean_ir) == [] , (
        f"the scan reported stubs in a fully lowered module: "
        f"{seal_abort_stubs(clean_ir)}"
    );

    # Stage 5: stage 4 left the dependency's demoted IR warm in the cache
    # *without* a seal having run, so this is the one point where the two
    # mechanisms are distinguishable. If the seal read that warm cache its
    # census would be empty and only the abort-stub scan could refuse, giving
    # the "would link N abort stub(s)" wording. Getting the per-method census
    # diagnostic here proves the seal recompiled the closure itself.
    assert _dep_cache_entries("seal_xmod_dep.jac") , (
        "stage 4 was expected to leave a warm native IR cache entry"
    );
    (arts3, err3, tmp3) = _seal("seal_xmod_root.jac");
    try {
        assert arts3 is None , f"warm-cache seal was accepted: {arts3}";
        diag3 = _seal_diag(err3);
        assert "demoted 1 method" in diag3 , (
            "the seal trusted a warm native IR cache instead of recompiling the "
            f"closure under the census:\n{diag3}"
        );
        assert "eval" in diag3 , (
            f"the per-method reason is missing, so the census did not run:\n{diag3}"
        );
    } finally {
        shutil.rmtree(tmp3, ignore_errors=True);
    }

    pb.purge_native_ir_cache(str(FIXTURES / "seal_xmod_dep.jac"));
}


test "waiving that exact method seals and says so; waiving another does not" {
    (arts, err, tmp) = _seal(
        "seal_demoted_method.jac",
        waivers={
            "seal_demoted_method.jac": ("seal_demoted_method.jac::Gauge.unlowerable", )
        }
    );
    try {
        assert arts is not None , f"a waived demotion still failed the seal:\n{err}";
        assert "fixtures.seal_demoted_method" in arts , f"artifacts: {list(arts)}";
        diag = _seal_diag(err);
        assert "Gauge.unlowerable" in diag , (
            f"a waived demotion must still be announced by name:\n{diag}"
        );
        assert "waiv" in diag.lower() , (
            f"the seal did not say the demotion was waived:\n{diag}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }

    (other, err2, tmp2) = _seal(
        "seal_demoted_method.jac",
        waivers={"seal_demoted_method.jac": ("seal_demoted_method.jac::Gauge.good", )}
    );
    try {
        assert other is None , (
            "the waiver list is per-method: naming Gauge.good must not launder "
            f"Gauge.unlowerable. Got: {other}"
        );
        assert "Gauge.unlowerable" in _seal_diag(err2) , _seal_diag(err2);
    } finally {
        shutil.rmtree(tmp2, ignore_errors=True);
    }
}


test "a waiver names one module's method and cannot silence another's" {
    # Two modules in one sealed closure demoting the *same* Type.method name.
    # Driven through seal_demotion_report directly with a census built to the
    # shape na_census_seam writes, because two modules defining the same symbol
    # could not link into one artifact anyway -- the property under test is that
    # a waiver carries module identity, independent of that.
    census = {
        str(FIXTURES / "seal_xmod_dep.jac"): {
            "outcome": "native",
            "code": "",
            "detail": "",
            "seams": ["Meter.unlowerable: Native lowering failed for 'eval'"]
        },
        str(FIXTURES / "seal_clean.jac"): {
            "outcome": "native",
            "code": "",
            "detail": "",
            "seams": ["Meter.unlowerable: Native lowering failed for 'eval'"]
        }
    };

    (err, waived, stale) = pb.seal_demotion_report(
        "root.jac",
        census,
        {"root.jac": ("seal_xmod_dep.jac::Meter.unlowerable", )},
        FIXTURES
    );
    assert err , (
        "waiving seal_xmod_dep's Meter.unlowerable silenced seal_clean's "
        "identically named method too; the waiver lost module identity"
    );
    assert "seal_clean.jac::Meter.unlowerable" in err , (
        f"the unwaived module's demotion is not named:\n{err}"
    );
    assert "seal_xmod_dep.jac::Meter.unlowerable" not in err.split("Fix the")[0] , (
        f"the waived module's demotion is still reported as offending:\n{err}"
    );
    assert waived == ["seal_xmod_dep.jac::Meter.unlowerable"] , waived;
    assert stale == [] , stale;

    # Waiving both, by module, clears the seal.
    (err2, waived2, stale2) = pb.seal_demotion_report(
        "root.jac",
        census,
        {
            "root.jac": (
                "seal_xmod_dep.jac::Meter.unlowerable",
                "seal_clean.jac::Meter.unlowerable"
            )
        },
        FIXTURES
    );
    assert err2 == "" , f"both demotions waived by module but still refused:\n{err2}";
    assert len(waived2) == 2 , waived2;

    # A bare, unqualified name waives nothing: the module half is required.
    (err3, waived3, _stale3) = pb.seal_demotion_report(
        "root.jac", census, {"root.jac": ("Meter.unlowerable", )}, FIXTURES
    );
    assert err3 , "an unqualified waiver silenced a demotion";
    assert waived3 == [] , waived3;
}


test "a waiver that matches no demotion is reported as stale" {
    (arts, err, tmp) = _seal(
        "seal_clean.jac",
        waivers={"seal_clean.jac": ("seal_clean.jac::Counter.retired", )}
    );
    try {
        assert arts is not None , f"a stale waiver must not fail a clean seal:\n{err}";
        diag = _seal_diag(err);
        assert "Counter.retired" in diag , (
            f"the stale waiver was not reported:\n{diag}"
        );
        assert "stale" in diag.lower() , (
            f"the report does not say the waiver is stale:\n{diag}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "the canary rejects a broken artifact and accepts a live one" {
    (arts, err, tmp) = _seal("seal_clean.jac");
    try {
        assert arts is not None , err;
        rec = arts["fixtures.seal_clean"];
        lib = Path(tmp) / rec["lib"];
        layout = json.loads((Path(tmp) / rec["layout"]).read_text(encoding="utf-8"));
        exports = sorted(layout["functions"].keys());

        assert seal_native_canary(str(lib), exports) == "" , (
            "the canary rejected a live artifact the seal just produced"
        );

        # Break a *copy*: truncating a mapped ELF in place drops even the
        # copy-on-write pages holding glibc's relocated .dynamic entries, and
        # the next dlopen in this process would segfault walking the stale
        # soname (glibc _dl_map_object, dl-load.c).
        broken = Path(tmp) / "broken_copy.so";
        broken.write_bytes(lib.read_bytes()[:256]);
        why = seal_native_canary(str(broken), exports);
        assert why , "a truncated artifact passed the canary";
        assert "dlopen" in why.lower() , f"unhelpful canary reason: {why}";

        absent = seal_native_canary(str(lib), exports + ["__jac_no_such_export"]);
        assert "__jac_no_such_export" in absent , (
            f"the canary did not name the absent export: {absent}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a failed canary deletes the artifact and refuses the seal" {
    # Corrupt the freshly linked artifact on disk at the exact moment the seal
    # hands it to the canary, so the real canary runs against a genuinely
    # broken ELF and the seal's own rejection path executes.
    real_canary = pb.seal_native_canary;
    probed: list[str] = [];

    def _corrupt_then_check(lib_path: str, exports: list) -> str {
        probed.append(lib_path);
        Path(lib_path).write_bytes(Path(lib_path).read_bytes()[:256]);
        return real_canary(lib_path, exports);
    }
    pb.seal_native_canary = _corrupt_then_check;
    try {
        (arts, err, tmp) = _seal("seal_clean.jac");
    } finally {
        pb.seal_native_canary = real_canary;
    }
    try {
        assert probed , "the seal never reached the canary";
        assert arts is None , (
            f"the seal accepted an artifact its canary rejected: {arts}"
        );
        diag = _seal_diag(err);
        assert "canary" in diag.lower() , (
            f"the refusal does not say the canary failed:\n{diag}"
        );
        assert "dlopen" in diag.lower() , (
            f"the refusal drops the canary's reason:\n{diag}"
        );
        assert not Path(probed[0]).exists() , (
            "a canary-rejected artifact was left on disk at "
            f"{probed[0]}; a later step could still pick it up"
        );
        assert not list(Path(tmp).rglob("*.so")) , (
            "a canary-rejected seal left a shared library in the output tree"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "JAC_NA_DEBUG explains the demotion behind a refused seal" {
    (arts, err, tmp) = _seal("seal_demoted_method.jac", na_debug=True);
    try {
        assert arts is None , f"gate did not fire under JAC_NA_DEBUG: {arts}";
        assert "NA_DEBUG demote Gauge.unlowerable" in err , (
            f"JAC_NA_DEBUG=1 did not explain the demotion:\n{err}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }

    (quiet_arts, quiet_err, tmp2) = _seal("seal_demoted_method.jac");
    try {
        assert quiet_arts is None;
        assert "NA_DEBUG demote" not in quiet_err , (
            f"the NA_DEBUG trace leaked with the gate off:\n{quiet_err}"
        );
    } finally {
        shutil.rmtree(tmp2, ignore_errors=True);
    }
}
