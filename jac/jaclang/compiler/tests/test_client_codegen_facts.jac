"""Client codegen never runs on a module whose checker facts were not derived.

`jac build --as client main.jac` was clean on a cold cache and failed on the
very next run with `E5101: Client codegen emitted 'init', which the module
never binds`, and a served page threw `ReferenceError: enumerate is not
defined` a dozen times over. The bundle showed the shape exactly:
`_jac.builtin.iter(enumerate(rows))` -- the outer call lowered, the inner one
left as a bare name.

`FuncCall.call_kind` is stamped by the checker, and the ECMAScript backend
routes a call to the builtin emitter only when it reads `"builtin"` there. A
dependency ingested through `JacProgram.load_dependency_module` compiles under
the symtab-only schedule (no analysis, no boundary pass) and is parked in the
program hub under the same key a full compile uses, so once a warm run let the
client-boundary walk serve its facts from the cache instead of tree-compiling,
the bundle builder found that analysis-free module in the hub and emitted from
it: every builtin came out bare and the client-to-native import binding was
never generated.

An analysis-free hub entry is now a miss at the client codegen seam, so a warm
build compiles the source exactly as a cold one does, and the emitted-bundle
audit reports a bare builtin (`E5103`) rather than shipping it, so this class
cannot go silent again.
"""

import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import os;
import shutil;
import tempfile;
import from jaclang.compiler.pipeline.products { require_product }
import from jaclang.compiler.pipeline.contracts { CompilationProduct, AnalysisFact }
import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.pipeline.executor { run_pass }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.ir.schema { Module }


glob _HELPER_SRC: str = (
         "def:pub label_of(i: int) -> str {\n" "    return f\"row-{i}\";\n" "}\n"
     ),
     _WIDGET_SRC: str = (
         "import from .helper { label_of }\n"
         "\n"
         "def:pub Widget(rows: list[str]) -> any {\n"
         "    out: list[str] = [];\n"
         "    for (i, r) in enumerate(rows) {\n"
         "        out.append(label_of(i) + r);\n"
         "    }\n"
         "    for k in range(3) {\n"
         "        out.append(str(k));\n"
         "    }\n"
         "    return <div>{out}</div>;\n"
         "}\n"
     );


"""Write a two-module client project; return (project dir, widget path)."""
def _project -> tuple[str, str] {
    base = os.path.realpath(tempfile.mkdtemp(prefix="jac_codegen_facts_"));
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"codegenfacts\"\nkind = \"web-app\"\n");
    }
    with open(os.path.join(base, "helper.jac"), "w") as f {
        f.write(_HELPER_SRC);
    }
    widget = os.path.join(base, "widget.jac");
    with open(widget, "w") as f {
        f.write(_WIDGET_SRC);
    }
    return (base, widget);
}


"""Compile under the schedule dependency ingestion uses: symbols, no analysis."""
def _ingest_as_dependency(prog: JacProgram, path: str) -> Module {
    return prog.compile(
        path, options=CompileOptions(no_cgen=True, symtab_ir_only=True, iface_ok=True)
    );
}


"""The first handful of lines where two bundles part ways."""
def _first_delta(cold: str, warm: str) -> str {
    import difflib;
    lines = [
        ln
        for ln in difflib.unified_diff(
            cold.splitlines(), warm.splitlines(), "cold", "warm", lineterm=""
        )
        if ln.startswith(("+", "-", "@"))
    ];
    return '\n'.join(lines[:24]);
}


def _codes(prog: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in prog.errors_had
        if e.code
    ];
}

test "cached walker imports retain their client endpoint contract" {
    import json;
    import from pathlib { Path }
    import from jaclang.compiler.session.context { artifact_cache_path }
    with tempfile.TemporaryDirectory() as base {
        project = Path(base);
        (project / "jac.toml").write_text(
            "[project]\nname = 'walker-contract'\n"
            "[apps.service]\nkind = 'service'\nentry-point = 'provider'\n"
            "[placement.pins]\nclient = 'client'\n"
        );
        provider = str(project / "provider.jac");
        Path(provider).write_text(
            "walker:pub Report { has value: int; "
            "can run with Root entry { report self.value; } }\n"
        );
        client = str(project / "client.jac");
        Path(client).write_text(
            "import from provider { Report as RemoteReport }\n"
            "async def invoke -> any { return root spawn RemoteReport(value=3); }\n"
        );
        options = CompileOptions(
            no_cgen=True,
            native_parity=True,
            force_target_program=True,
            iface_ok=True,
            entry_point=client,
            project_root=base
        );
        cold = JacProgram();
        cold_mod = cold.compile(client, options=options);
        assert not cold.errors_had , _codes(cold);
        context = cold.module_context(cold_mod);
        assert isinstance(context, JacProgram);
        cache = artifact_cache_path(client, context);
        cold.release_compile_closure(collect=False);
        cache.unlink(missing_ok=True);
        warm = JacProgram();
        mod = warm.compile(client, options=options);
        assert not warm.errors_had , _codes(warm);
        assert warm.analysis.cache_events.get('dep_hydrate', 0) > 0 , (
            "the regression must exercise a cached provider interface"
        );
        binding = artifact_for(mod).interop_manifest.bindings.get('RemoteReport');
        assert binding is not None , "walker binding was not prepared";
        expected = '["service","provider.jac","walker","Report"]';
        assert binding.endpoint_id == expected;
        assert require_product(warm, mod, CompilationProduct.CLIENT);
        assert json.dumps(expected) in artifact_for(mod).js , (
            "client code generation dropped the prepared endpoint contract"
        );
    }
}


test "a second client build lowers exactly what the first one did" {
    (base, widget) = _project();
    try {
        cold = JacProgram();
        cold_mod = cold.compile(widget, options=CompileOptions(no_cgen=True));
        run_pass(PassIdentity.EsastGenPass, cold_mod, cold);
        assert _codes(cold) == [] , _codes(cold);
        assert cold._get_compiler().client_codegen_target(widget, cold) is cold_mod , (
            "a fully compiled module is the client codegen target for its source"
        );

        warm = JacProgram();
        warm_dep = _ingest_as_dependency(warm, widget);
        assert not warm.analysis.provides(warm_dep, AnalysisFact.TYPE_OF) , (
            "the dependency schedule is supposed to leave the module unanalyzed;"
            " this test no longer reproduces the warm shape"
        );
        assert warm._get_compiler().client_codegen_target(widget, warm) is None , (
            "an analysis-free hub entry was handed to client codegen as a target"
        );

        warm_mod = warm.compile(widget, options=CompileOptions(no_cgen=True));
        assert warm._get_compiler().client_codegen_target(widget, warm) is warm_mod , (
            "the warm build never reached a module carrying checker facts"
        );
        assert require_product(warm, warm_mod, CompilationProduct.CLIENT);
        assert _codes(warm) == [] , _codes(warm);
        assert artifact_for(warm_mod).js == artifact_for(cold_mod).js , (
            "the warm bundle differs from the cold one:\n"
            + _first_delta(artifact_for(cold_mod).js, artifact_for(warm_mod).js)
        );
        assert "_jac.builtin.enumerate(" in artifact_for(warm_mod).js , artifact_for(
            warm_mod
        ).js;
        assert "_jac.builtin.range(" in artifact_for(warm_mod).js , artifact_for(
            warm_mod
        ).js;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


# `_audit_free_identifiers` scans for bare builtins BEFORE its `has_client`
# early return, and that ordering is the point of this test. A module whose
# checker facts were never derived carries no `call_kind` on any call, so the
# backend never routes one to the builtin emitter -- and, for the same reason,
# `client_manifest.has_client` is False. Gating the whole audit on `has_client`
# therefore skipped exactly the modules that needed it, which is how a bundle
# full of bare `enumerate(` shipped without one diagnostic. The scan stays
# unconditional; if that early return is ever hoisted back above it, this test
# fails. (The rationale lives here because jaclang source is deslopped: the
# repo's `[check.lint]` selects `strip-comments`/`strip-docstrings`, and
# `*/tests/*` is the exclusion that lets a note like this survive.)
test "an unlowered builtin in the bundle is an error, never silence" {
    (base, widget) = _project();
    try {
        prog = JacProgram();
        mod = _ingest_as_dependency(prog, widget);
        run_pass(PassIdentity.EsastGenPass, mod, prog);
        codes = _codes(prog);
        assert "E5103" in codes , (
            f"a bare builtin call shipped without a diagnostic: {codes}\n"
            f"{artifact_for(mod).js}"
        );
        named = [
            str(e)
            for e in prog.errors_had
            if e.code and e.code.code == "E5103"
        ];
        assert any(["enumerate" in m for m in named]) , named;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
