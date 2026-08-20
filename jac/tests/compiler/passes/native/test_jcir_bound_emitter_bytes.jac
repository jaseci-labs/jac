"""Binding the JCIR artifact does not change the bytes the emitter emits.

Read the name carefully, because an earlier one promised more than the
file can deliver. This was `test_jcir_sealed_bytes.jac`, and it claimed
to compare **sealed-emitter** bytes against **source-lane** bytes. It
does not, and it cannot yet.

The #8288 M1 crossing coverage measured why. `pass_serve._bind_one`
resolves the artifact, `dlopen`s it, calls `__jac_shared_init`, checks
that every advertised export resolves by `dlsym`, and probes
`jac_str_new` for liveness -- and then retains the engine and **no
function pointer**. `require_native_pass_tier` runs from the rim's
construction seam, raises when the image claims a module the binder
could not bind, and on the success path falls straight through to the
pass's bytecode body. So `JcirGenPass(...).ir_bytes()` executes Python
on both sides of the comparison below.

What the file therefore proves, and what is worth proving:

  - the real artifact **builds** from the real seal, with the real
    closure, and binds and verifies cleanly;
  - the binder **registers** the emitter, so the serving path is
    genuinely entered rather than skipped;
  - and the container bytes are **identical either way**, which rules
    out the binder perturbing the emitter it attests -- a real
    invariant, and not the one the old name promised.

The limit is not left as prose. The last test pins it as a mechanism:
it observes that an internal visitor of the Python body still runs
during the bound emission. When the artifact genuinely serves the pass,
that observation fails, and this file has to be rewritten to make the
stronger claim. That is #8288 M1 rung 3's acceptance -- the fused root
with `transform.jac` in its closure -- and it cannot happen before rung
1 (the pass base chain stops being generic) and rung 2 land, because a
natively constructed pass has no way to exist until then.

The comparison is on the container bytes, which is the artifact the
cutover ships on. Where a mismatch is found the code objects are also
compared field by field, never by marshal bytes (internals section 10),
so the failure names a field rather than an offset.

The corpus is the one the cutover requirements name: comments,
diagnostics, string-named tests, and circular includes.
"""

import ast as pyast;
import json;
import os;
import shutil;
import tempfile;
import types;
import jaclang;
import jaclang.jac0core.parser.frontend as frontend;
import jaclang.jac0core.sealed as sealed;
import jaclang.jac0core.unitree as uni;
import from builtins { compile as pycompile }
import from pathlib { Path }
import from jaclang.jac0core.codegen_shim { transcribe }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.passes.pass_serve { _BIND_KEEP }
import from jaclang.jac0core.passes.pass_rim {
    _NATIVE_PASS_TIER_MEMO,
    _NATIVE_SERVED_PASSES
}
import from jaclang.jac0core.passes.jcir_gen_pass { JcirGenPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.utils.precompile_bytecode { seal_native_artifacts }

glob PKG_PATH = Path(jaclang.__file__).parent,
     JCIR_MODULE: str = "jaclang.jac0core.passes.jcir_gen_pass",
     SEAL_MODULES: tuple = (
         "jac0core/unitree.jac",
         "jac0core/passes/jcir_gen_pass.jac"
     ),
     _BUILD_MEMO: list = [];

glob CORPUS: tuple = (
         (
             "comments",
             "\"\"\"Doc.\"\"\"\n# leading\nglob seeded: int = 1;\n\n"
                 + "def widen(n: int) -> int {\n    total = n + seeded;  # tail\n"
                 + "    return total;\n}\n\nwith entry { widened = widen(2); }\n",
             "sealed_comments.jac"
         ),
         (
             "string-named tests",
             "def triple(x: int) -> int {\n    return x * 3;\n}\n\n"
                 + "test \"a named test with 'quotes'\" { assert triple(3) == 9; }\n",
             "sealed_tests.jac"
         ),
         (
             "diagnostics",
             "def tail(n: int) -> int {\n    return n;\n    stranded = n + 1;\n}\n"
                 + "\nwith entry { kept = tail(4); }\n",
             "sealed_diags.jac"
         ),
         (
             "circular include a",
             "import from circular_b { beta }\n\ndef alpha(n: int) -> int {\n"
                 + "    return n + 1;\n}\n\nwith entry { a_result = alpha(1); }\n",
             "circular_a.jac"
         ),
         (
             "circular include b",
             "import from circular_a { alpha }\n\ndef beta(n: int) -> int {\n"
                 + "    return n + 2;\n}\n\nwith entry { b_result = beta(1); }\n",
             "circular_b.jac"
         )
     );

"""True when this runtime already serves jcir from its own native seal."""
def native_true_image -> bool {
    return sealed.native_artifact_for(JCIR_MODULE) is not None;
}

"""Build the jcir artifact once for the whole file; (tmpdir, artifacts)."""
def _built -> tuple {
    if native_true_image() {
        testskip(
            "this runtime already serves jcir from its own native seal, so "
            "both sides of the comparison would be the sealed lane"
        );
    }
    if _BUILD_MEMO {
        return _BUILD_MEMO[0];
    }
    tmp = tempfile.mkdtemp(prefix="jac_jcir_bytes_");
    arts = seal_native_artifacts(PKG_PATH, Path(tmp), modules=SEAL_MODULES);
    assert arts is not None , (
        "the seal refused; the sealed-versus-source comparison needs an "
        "artifact. If the jcir root was refused, this file is the thing "
        "that should have caught it"
    );
    assert JCIR_MODULE in arts , (
        f"the seal produced no artifact for {JCIR_MODULE}: {sorted(arts)}"
    );
    result = (tmp, arts, );
    _BUILD_MEMO.append(result);
    return result;
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

"""Container bytes plus the shim tree, for one source, in this runtime."""
def _emit(src: str, path: str) -> tuple {
    prog = JacProgram();
    mod = prog.compile(
        use_str=src,
        file_path=path,
        options=CompileOptions(
            force_codespace="server",
            skip_native_engine=True,
            no_ir_cache=True,
            suppress_codes=["E5092"]
        )
    );
    assert len(prog.errors_had) == 0 , str([str(e) for e in prog.errors_had]);
    blob = JcirGenPass(ir_in=mod, prog=prog).ir_bytes();
    (mods, _diags) = transcribe(blob);
    assert len(mods) == 1;
    return (blob, mods[0][1], );
}

glob _CODE_FIELDS: tuple = (
         "co_name",
         "co_qualname",
         "co_filename",
         "co_firstlineno",
         "co_argcount",
         "co_posonlyargcount",
         "co_kwonlyargcount",
         "co_nlocals",
         "co_stacksize",
         "co_flags",
         "co_code",
         "co_names",
         "co_varnames",
         "co_freevars",
         "co_cellvars",
         "co_linetable",
         "co_exceptiontable"
     );

"""Field-by-field code comparison, recursive through co_consts."""
def code_field_diffs(a: any, b: any, at: str, out: list[str]) -> list[str] {
    for attr in _CODE_FIELDS {
        av = getattr(a, attr, None);
        bv = getattr(b, attr, None);
        if av != bv {
            out.append(f"{at}.{attr}: source {av!r} vs sealed {bv!r}");
        }
    }
    if len(a.co_consts) != len(b.co_consts) {
        out.append(f"{at}.co_consts length {len(a.co_consts)} vs {len(b.co_consts)}");
        return out;
    }
    for (i, (x, y)) in enumerate(zip(a.co_consts, b.co_consts)) {
        if (isinstance(x, types.CodeType) and isinstance(y, types.CodeType)) {
            code_field_diffs(x, y, f"{at}.consts[{i}]", out);
        } elif (x != y or type(x) is not type(y)) {
            out.append(f"{at}.consts[{i}]: source {x!r} vs sealed {y!r}");
        }
    }
    return out;
}


test "the emitter's artifact builds, binds and registers" {
    (tmp, arts) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, arts);
    sealed.native_artifact_names = lambda { list(arts.keys()); };
    try {
        _emit("with entry { probe = 1; }", "bind_probe.jac");
        assert JCIR_MODULE in _NATIVE_SERVED_PASSES , (
            "the emitter ran without the binder registering it, so the "
            "byte comparison below would never have entered the serving "
            "path at all"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
}


test "container bytes are the same with the artifact bound and without" {
    (tmp, arts) = _built();
    source_side: dict[(str, tuple)] = {};
    for (label, src, path) in CORPUS {
        source_side[label] = _emit(src, path);
    }
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, arts);
    sealed.native_artifact_names = lambda { list(arts.keys()); };
    failures: list[str] = [];
    try {
        assert JCIR_MODULE in arts;
        for (label, src, path) in CORPUS {
            (sealed_blob, sealed_tree) = _emit(src, path);
            (source_blob, source_tree) = source_side[label];
            if sealed_blob == source_blob {
                continue;
            }
            detail = (
                f"{label} ({path}): sealed {len(sealed_blob)} bytes vs source "
                f"{len(source_blob)} bytes"
            );
            i = 0;
            n = min(len(sealed_blob), len(source_blob));
            while (i < n and sealed_blob[i] == source_blob[i]) {
                i += 1;
            }
            detail += f", first difference at offset {i}";
            diffs = code_field_diffs(
                pycompile(source_tree, path, "exec"),
                pycompile(sealed_tree, path, "exec"),
                "<module>",
                []
            );
            if diffs {
                detail += "\n    " + "\n    ".join(diffs[:8]);
            } else {
                detail += (
                    " (the code objects agree field for field, so the "
                    "divergence is in the container encoding, not the recipe)"
                );
            }
            failures.append(detail);
        }
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
    assert not failures , (
        f"{len(failures)} corpus module(s) produced different JCIR bytes "
        "with the artifact bound than without it. Binding attests an "
        "artifact; it must not perturb the emitter it attests:\n  "
        + "\n  ".join(failures)
    );
}


test "the bound emission still runs the Python body, and says so" {
    # The self-clearing half of this file's honesty. The binder retains an
    # engine and no function pointer, so `require_native_pass_tier` falls
    # through to the bytecode body and an internal visitor of that body is
    # observable from here. On the day the artifact genuinely serves the
    # pass, this observation stops holding -- and the two tests above have
    # to be rewritten to claim the sealed-versus-source comparison they
    # were once named for. That day is #8288 M1 rung 3.
    (tmp, arts) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    real_exit = JcirGenPass.exit_module;
    seen: list = [];
    def _counting_exit(self: any, nd: any) -> any {
        seen.append(1);
        return real_exit(self, nd);
    }
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, arts);
    sealed.native_artifact_names = lambda { list(arts.keys()); };
    JcirGenPass.exit_module = _counting_exit;
    try {
        _emit("with entry { probe = 1; }", "body_probe.jac");
    } finally {
        JcirGenPass.exit_module = real_exit;
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
    assert seen , (
        "the emitter's Python `exit_module` did not run while its artifact "
        "was bound, which means the artifact is now serving the pass. That "
        "is the goal, and it retires this file's limitation: rename the two "
        "tests above back to the sealed-versus-source claim, emit one side "
        "with the artifact served and the other without, and delete this "
        "test"
    );
}
