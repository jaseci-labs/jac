"""The payload-lane canary manifest, wired to the lanes that run it.

`codegen-ir.md` section 11.2 names nineteen suites that were validated end
to end on the JCIR lane while it still lived behind a flag. With the
cutover they need no flag and no special job: they are the default lane,
and CI's ordinary chunks already collect all nineteen. The manifest is
therefore not a runner but a pin, and it holds two things a plain prose
list cannot.

First, every named suite still exists. A canary that was renamed or
deleted stops being a canary silently, and the only symptom is a coverage
hole nobody sees.

Second, every named suite still falls inside a CI chunk. The compiler
lane collects `tests/compiler/test_*.jac` and the `tests/compiler/passes`
trees; the runtime lane collects `tests/` minus `tests/compiler`. A suite
moved into a directory neither glob reaches would keep passing locally
and stop running in CI, which is the same coverage hole wearing a
different hat.

The third obligation -- that the lane under measurement is actually JCIR
-- is the schedule assertion at the end. Together they say: these
nineteen files exist, CI runs them, and what they run is the container.
"""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.compiler { get_py_code_gen }
import from jaclang.jac0core.passes { JcirBytecodeGenPass, JcirGenPass }

glob CANARY_SUITES: tuple = (
         "tests/compiler/test_compilation.jac",
         "tests/compiler/test_codegen_ir.jac",
         "tests/compiler/test_jcir_gen_pass.jac",
         "tests/compiler/test_importer.jac",
         "tests/compiler/test_archetype_runtime.jac",
         "tests/compiler/test_client_codegen.jac",
         "tests/compiler/test_codespace_inference.jac",
         "tests/compiler/test_placement_evidence.jac",
         "tests/compiler/test_interop_manifest.jac",
         "tests/compiler/test_front_end_native_idioms.jac",
         "tests/runtimelib/test_graph_query.jac",
         "tests/runtimelib/test_osp_edges_contract.jac",
         "tests/runtimelib/test_closures.jac",
         "tests/runtimelib/test_serve.jac",
         "tests/runtimelib/test_serve_bridged_endpoints.jac",
         "tests/runtimelib/test_client_bundle.jac",
         "tests/langserve/test_server.jac",
         "tests/language/test_language.jac",
         "tests/language/test_bugs.jac",

     );

"""True when a CI chunk's collection glob reaches this suite."""
def collected_by_ci(rel: str) -> bool {
    parent = os.path.dirname(rel);
    base = os.path.basename(rel);
    if parent == "tests/compiler" {
        # The compiler lane's `toplevel` chunk: tests/compiler/test_*.jac.
        return base.startswith("test_");
    }
    if parent.startswith("tests/compiler/passes/") {
        # The compiler lane's passes-native and passes-main chunks.
        return True;
    }
    # The runtime lane: tests/ minus tests/compiler.
    return parent.startswith("tests/") and not parent.startswith("tests/compiler");
}

test "every canary suite named in the manifest is still in the tree" {
    missing = sorted(
        rel
        for rel in CANARY_SUITES
        if not os.path.isfile(os.path.join(JAC_ROOT, rel))
    );
    assert not missing , (
        f"{len(missing)} canary suite(s) named in codegen-ir.md section 11.2 "
        "are gone from the tree. A renamed or deleted canary stops covering "
        "the codegen lane without saying so -- repoint the manifest at the "
        "suite's new home, or argue in the doc why the coverage is no longer "
        "needed:\n"
        + "\n".join(f"  {rel}" for rel in missing)
    );
}

test "every canary suite falls inside a CI collection chunk" {
    stranded = sorted(
        rel
        for rel in CANARY_SUITES
        if not collected_by_ci(rel)
    );
    assert not stranded , (
        f"{len(stranded)} canary suite(s) sit outside every CI collection "
        "glob, so they run locally and nowhere else:\n"
        + "\n".join(f"  {rel}" for rel in stranded)
    );
}

test "the manifest has no duplicates and covers both lanes" {
    assert len(set(CANARY_SUITES)) == len(CANARY_SUITES) , (
        "the manifest lists a suite twice"
    );
    compiler_lane = [
        rel
        for rel in CANARY_SUITES
        if rel.startswith("tests/compiler/")
    ];
    runtime_lane = [
        rel
        for rel in CANARY_SUITES
        if not rel.startswith("tests/compiler/")
    ];
    assert compiler_lane and runtime_lane , (
        "the canary manifest has to reach past the compiler's own tests: a "
        "codegen change that only breaks serving, the language server or the "
        "client bundle has to fail something here"
    );
}

test "the lane the canaries measure is the container, with no alternative" {
    sched = get_py_code_gen(native=False);
    assert JcirGenPass in sched , (
        f"the codegen schedule does not emit JCIR: {[p.__name__ for p in sched]}"
    );
    assert JcirBytecodeGenPass in sched , (
        "the codegen schedule emits JCIR but never transcribes it"
    );
    for `entry in sched {
        assert "Pyast" not in `entry.__name__ and "PyBytecode" not in `entry.__name__ , (
            f"a second Python codegen emitter is back in the schedule "
            f"({`entry.__name__}); the manifest measures whichever lane runs, "
            "so two lanes make it ambiguous"
        );
    }
}
