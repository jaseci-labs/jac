"""The pass-serving binder: sealed means served, proven end to end.

These tests build REAL artifacts (unitree, the materializer with its
`mat_merge_probe` crossing, and the annex pass) with the real seal, then
present them to the runtime exactly the way a sealed image does, by
patching `native_artifact_for` / `native_artifact_names`, the seams the
binder reads in production.

Four claims, each the runtime half of a manifest claim:

  1. **Binding serves.** First construction of a sealed pass binds every
     sealed pass artifact (dlopen, `__jac_shared_init`, full advertised
     method surface, live `jac_str_new`), runs the annex native-execution
     canary, registers `_NATIVE_SERVED_PASSES`, and construction
     proceeds; a real compile through the pipeline then works.
  2. **The native-execution proof.** `mat_merge_probe` parses a main and
     an annex source natively and runs the compiled
     `JacAnnexPass._merge_annex` over the native trees inside the
     artifact; the materialized module carries the annex's statements
     (their `loc.mod_path` is the annex path), and the bytecode lane,
     computed independently, unparses identically. The bytecode merge
     never ran on the native result: the only code between the two
     parses and the woven module was the artifact's.
  3. **A broken artifact refuses.** A manifest entry whose library
     cannot bind raises at construction, naming the module.
  4. **Unregistered still refuses.** The tripwire's own refusal stands
     when the binder has nothing to bind for a module the image claims
     (`test_sealed_pass_tier.jac` pins that message; here the binder is
     given artifacts and must not launder an unbindable one).
"""

import json;
import os;
import shutil;
import tempfile;
import jaclang;
import jaclang.jac0core.parser.frontend as frontend;
import jaclang.jac0core.sealed as sealed;
import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.parser.lexer { tokenize_full }
import from jaclang.jac0core.parser.parser { Parser }
import from jaclang.jac0core.passes.annex_pass { JacAnnexPass }
import from jaclang.jac0core.passes.pass_serve { _BIND_KEEP }
import from jaclang.jac0core.passes.pass_rim {
    _NATIVE_PASS_TIER_MEMO,
    _NATIVE_SERVED_PASSES
}
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
import from jaclang.utils.precompile_bytecode { seal_native_artifacts }

glob PKG_PATH = Path(jaclang.__file__).parent,
     ANNEX_MODULE: str = "jaclang.jac0core.passes.annex_pass",
     MAT_MODULE: str = "jaclang.compiler.native_materialize",
     SEAL_MODULES: tuple = (
         "jac0core/unitree.jac",
         "compiler/native_materialize.jac",
         "jac0core/passes/annex_pass.jac"
     ),
     _BUILD_MEMO: list = [];

"""Build the three artifacts once for the whole file; (tmpdir, artifacts)."""
def _built -> tuple {
    if native_true_image() {
        testskip(
            "this runtime already serves from its own native seal; the "
            "binder ran for real at first pass construction"
        );
    }
    if _BUILD_MEMO {
        return _BUILD_MEMO[0];
    }
    tmp = tempfile.mkdtemp(prefix="jac_pass_serving_");
    arts = seal_native_artifacts(PKG_PATH, Path(tmp), modules=SEAL_MODULES);
    assert arts is not None , "the seal refused; serving tests need artifacts";
    result = (tmp, arts, );
    _BUILD_MEMO.append(result);
    return result;
}

def native_true_image -> bool {
    return sealed.native_artifact_for(ANNEX_MODULE) is not None;
}

def _artifact_resolver(tmp: str, arts: dict) -> any {
    def _resolve(fullname: str) -> (tuple | None) {
        `entry = arts.get(fullname);
        if `entry is None {
            return None;
        }
        lib_path = os.path.join(tmp, `entry["lib"]);
        layout = json.loads(
            Path(os.path.join(tmp, `entry["layout"])).read_text(encoding="utf-8")
        );
        return (lib_path, layout, );
    }
    return _resolve;
}

def _reset_serving_state {
    _NATIVE_PASS_TIER_MEMO.clear();
    _NATIVE_SERVED_PASSES.clear();
    _BIND_KEEP.clear();
    frontend._NATIVE_PARSE_MEMO.clear();
}

def _run_annex -> object {
    return JacAnnexPass(ir_in=uni.Module.make_stub(), prog=JacProgram());
}


test "binding serves a sealed pass and a real compile runs" {
    (tmp, arts) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, arts);
    sealed.native_artifact_names = lambda { list(arts.keys()); };
    try {
        inst = _run_annex();
        assert isinstance(inst.ir_out, uni.Module) , "annex pass did not run";
        assert ANNEX_MODULE in _NATIVE_SERVED_PASSES , (
            "construction succeeded without the binder registering the module"
        );
        prog = JacProgram();
        src = "def probe_fn -> int { return 41 + 1; }";
        mod = prog.compile(file_path="__serving_smoke__.jac", use_str=src);
        assert mod is not None and not prog.errors_had , (
            f"sealed-lane compile failed: {[str(e) for e in prog.errors_had][:3]}"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
}


test "the merge probe proves the annex method body executed natively" {
    (tmp, arts) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, arts);
    sealed.native_artifact_names = lambda { list(arts.keys()); };
    try {
        np = frontend._native_parse();
        assert np is not None , "the temp materializer artifact did not bind";
        nl = chr(10);
        main_src = nl.join(
            [
                "obj Crate {",
                "    has load: int = 0;",
                "    def fill(n: int) -> int;",
                "}"
            ]
        );
        annex_src = nl.join(
            [
                "impl Crate.fill(n: int) -> int {",
                "    self.load += n;",
                "    return self.load;",
                "}"
            ]
        );
        main_path = "__serve_proof__.jac";
        annex_path = "__serve_proof__.impl.jac";
        (merged, m_errs, a_errs) = np.merge_probe(
            main_src, main_path, annex_src, annex_path
        );
        assert m_errs == 0 and a_errs == 0 , f"probe parses errored {m_errs}/{a_errs}";
        woven = [
            stmt
            for stmt in merged.body
            if stmt.loc.mod_path == annex_path
        ];
        assert woven , (
            "no statement in the woven module comes from the annex source; "
            "the native JacAnnexPass._merge_annex did not execute"
        );
        (mt, _mc, _mld, _mle) = tokenize_full(main_src, main_path);
        py_main = Parser(tokens=mt, file_path=main_path, source_code=main_src).parse();
        (at, _ac, _ald, _ale) = tokenize_full(annex_src, annex_path);
        py_annex = Parser(
            tokens=at, file_path=annex_path, source_code=annex_src
        ).parse();
        JacAnnexPass._merge_annex(py_main, py_annex);
        assert unparse_node(merged) == unparse_node(py_main) , (
            "the natively woven module and the bytecode-lane merge diverged"
        );
        assert len(merged.body) == len(py_main.body) , (
            f"woven body lengths diverged ({len(merged.body)} vs "
            f"{len(py_main.body)})"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
}


test "a sealed pass whose artifact cannot bind refuses construction" {
    (tmp, arts) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    broken = dict(arts);
    `entry = dict(broken[ANNEX_MODULE]);
    `entry["lib"] = "native/definitely/not/there.so";
    broken[ANNEX_MODULE] = `entry;
    sealed.native_artifact_for = _artifact_resolver(tmp, broken);
    sealed.native_artifact_names = lambda { list(broken.keys()); };
    try {
        with testraises(RuntimeError, `match=ANNEX_MODULE) {
            _run_annex();
        }
        assert ANNEX_MODULE not in _NATIVE_SERVED_PASSES , (
            "a failed bind still registered the module as served"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
}


test "the merge canary refuses a merge that did not weave" {
    (tmp, arts) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    only_annex = {ANNEX_MODULE: arts[ANNEX_MODULE]};
    sealed.native_artifact_for = _artifact_resolver(tmp, only_annex);
    sealed.native_artifact_names = lambda { list(only_annex.keys()); };
    try {
        with testraises(RuntimeError, `match="no native parser") {
            _run_annex();
        }
        assert ANNEX_MODULE not in _NATIVE_SERVED_PASSES;
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
}
