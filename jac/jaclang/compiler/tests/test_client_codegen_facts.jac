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

import os;
import shutil;
import tempfile;


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


test "a second client build lowers exactly what the first one did" {
    (base, widget) = _project();
    try {
        cold = JacProgram();
        cold_mod = cold.compile(widget, options=CompileOptions(no_cgen=True));
        run_pass(EsastGenPass, cold_mod, cold);
        assert _codes(cold) == [] , _codes(cold);
        assert _client_target_module(widget, cold) is cold_mod , (
            "a fully compiled module is the client codegen target for its source"
        );

        warm = JacProgram();
        warm_dep = _ingest_as_dependency(warm, widget);
        assert not warm.analysis.provides(warm_dep, "TypeOf") , (
            "the dependency schedule is supposed to leave the module unanalyzed;"
            " this test no longer reproduces the warm shape"
        );
        assert _client_target_module(widget, warm) is None , (
            "an analysis-free hub entry was handed to client codegen as a target"
        );

        warm_mod = warm.compile(widget, options=CompileOptions(no_cgen=True));
        assert _client_target_module(widget, warm) is warm_mod , (
            "the warm build never reached a module carrying checker facts"
        );
        _ensure_js_generated(warm_mod, warm);
        assert _codes(warm) == [] , _codes(warm);
        assert warm_mod.gen.js == cold_mod.gen.js , (
            "the warm bundle differs from the cold one:\n"
            + _first_delta(cold_mod.gen.js, warm_mod.gen.js)
        );
        assert "_jac.builtin.enumerate(" in warm_mod.gen.js , warm_mod.gen.js;
        assert "_jac.builtin.range(" in warm_mod.gen.js , warm_mod.gen.js;
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
# repo's `[check.lint]` selects `all`, which strips comments and docstrings, and
# `*/tests/*` is the exclusion that lets a note like this survive.)
test "an unlowered builtin in the bundle is an error, never silence" {
    (base, widget) = _project();
    try {
        prog = JacProgram();
        mod = _ingest_as_dependency(prog, widget);
        run_pass(EsastGenPass, mod, prog);
        codes = _codes(prog);
        assert "E5103" in codes , (
            f"a bare builtin call shipped without a diagnostic: {codes}\n"
            f"{mod.gen.js}"
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


# The toolchain precompile (jaclang's own seal) compiles every module with
# `skip_analysis`, which stops analysis for code that runs on the server. A
# module that declares client code still needs the checker's facts, because its
# client codegen reads them: without them `len(xs)` was emitted bare (E5103).
# The error used to be reported and then ignored, since a blocking error raised
# during codegen blocked nothing, so jaclang/client/auth_contract.jac and three
# siblings sealed with bare builtins in their client code.
test "a client module compiled without asked-for analysis still lowers its builtins" {
    base = os.path.realpath(tempfile.mkdtemp(prefix="jac_codegen_facts_"));
    try {
        with open(os.path.join(base, "jac.toml"), "w") as f {
            f.write(
                '[project]\nname = "counts"\n\n[placement.pins]\n"counts" = "client"\n'
            );
        }
        path = os.path.join(base, "counts.jac");
        with open(path, "w") as f {
            f.write(
                "def:pub count(xs: list[str]) -> int {\n"
                "    return len(xs) + len([x for x in range(3)]);\n"
                "}\n"
            );
        }
        prog = JacProgram();
        code = prog._get_compiler().get_bytecode(
            full_target=path, target_program=prog, skip_analysis=True
        );
        assert "E5103" not in _codes(prog) , _codes(prog);
        assert code is not None , f"no bytecode: {_codes(prog)}";
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


# An enum that client code reads is emitted into the bundle as a boundary type
# stub, so a client function pinned beside server code can read `Color.RED`. The
# unbound-reference audit (E5086) did not count those stubs as bindings, so it
# reported every such read: an error that blocked nothing until blocking errors
# raised during codegen began to block, and then a false one that stopped the
# module (the cross-backend `prim_enums` fixture).
test "a client function reading a module enum binds it once and reports nothing" {
    base = os.path.realpath(tempfile.mkdtemp(prefix="jac_codegen_facts_"));
    try {
        with open(os.path.join(base, "jac.toml"), "w") as f {
            f.write(
                '[project]\nname = "shades"\n\n[placement.pins]\n"shades.pick_cl" = "client"\n'
            );
        }
        path = os.path.join(base, "shades.jac");
        with open(path, "w") as f {
            f.write(
                "enum Color: int { RED, GREEN, BLUE }\n\n"
                "def pick_py -> int {\n    return int(Color.GREEN);\n}\n\n"
                "def pick_cl -> int {\n    return int(Color.GREEN);\n}\n"
            );
        }
        prog = JacProgram();
        compiler = prog._get_compiler();
        assert compiler.get_bytecode(full_target=path, target_program=prog)
            is not None , _codes(prog);
        artifact = compiler.get_client_artifact(path, prog);
        assert "E5086" not in _codes(prog) , _codes(prog);
        assert artifact is not None , _codes(prog);
        assert artifact.js.count("const Color =") == 1 , artifact.js;
        assert "GREEN: 2" in artifact.js , artifact.js;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
