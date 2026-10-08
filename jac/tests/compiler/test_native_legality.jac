"""Native placement is one judgment over a module that was typed once.

Every module is type-checked by the same rules, whatever codespace it ends
up in. What only matters natively is recorded on the typed module as a
note, a requirement or a library gap, and the legality pass reads those
after analysis to decide placement. A module that cannot be native is not
analyzed a second time and nothing about it is remembered between
compiles; a refusal only the backend can see places the module on the
server in place. A backend crash is none of these: it is a compiler error."""

import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.codeinfo { InteropBinding, InteropContext }
import from jaclang.compiler.capability_notes { capability_notes_of }
import from jaclang.compiler.passes.placement_pass {
    build_native_legality,
    native_unit_name
}
import from jaclang.compiler.driver.session_compile { drop_native_bindings }
import from jaclang.compiler.placement.placement_solver {
    invalidate_importers_es,
    native_placement_candidate
}
import from tests.support { JAC_ROOT }

glob PIN_FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "native_demoted_pin"
     ),
     SEAM_SRC = (
         "def helper(x: int) -> str {\n"
         "    s = \"abc\";\n"
         "    return f\"{s!a}{x}\";\n"
         "}\n\n"
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "def mid(x: int) -> str {\n"
         "    return helper(other(x));\n"
         "}\n\n"
     ),
     SEAM_ENTRY = "with entry {\n    print(other(2));\n}\n",
     REACHING_ENTRY = "with entry {\n    print(other(2));\n    print(mid(3));\n}\n",
     LATE_SRC = (
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    s = {1, \"a\"};\n"
         "    print(other(2), len(s));\n"
         "}\n"
     ),
     CLEAN_SRC = (
         "def other(x: int) -> int {\n"
         "    return x * 2;\n"
         "}\n\n"
         "with entry {\n"
         "    print(other(2));\n"
         "}\n"
     ),
     GAP_SRC = (
         "import json;\n\n"
         "def pretty(x: dict[str, int]) -> str {\n"
         "    return json.dumps(x, indent=2);\n"
         "}\n\n"
         "def plain(x: dict[str, int]) -> str {\n"
         "    return json.dumps(x);\n"
         "}\n\n"
         "with entry {\n"
         "    print(plain({\"a\": 1}));\n"
         "}\n"
     ),
     ERASED_SRC = (
         "import json;\n\n"
         "with entry {\n"
         "    data = json.loads(\"[1, 2]\");\n"
         "    print(1 in data);\n"
         "}\n"
     ),
     NATIVE_ONLY_SRC = (
         "with entry {\n"
         "    a = [1];\n"
         "    b = [2];\n"
         "    swap(a, b);\n"
         "    s = \"x\";\n"
         "    print(f\"{s!a}\", a, b);\n"
         "}\n"
     );

"""Compile `text` under the native default, counting how often it is parsed."""
def compile_native_default(text: str) -> tuple[JacProgram, uni.Module, str, int] {
    import from unittest.mock { patch }
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    path = os.path.realpath(os.path.join(tempfile.mkdtemp(), "m.jac"));
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(text);
    }
    real_parse: any = getattr(JacProgram, "parse_source");
    parsed: list[str] = [];
    def count_parse(this: JacProgram, *args: any, **kwargs: any) -> uni.Module {
        parsed.append(os.path.realpath(str(args[1])));
        return real_parse(this, *args, **kwargs);
    }
    previous = get_effective_default_codespace_override();
    prog = JacProgram();
    try {
        with patch.object(JacProgram, "parse_source", count_parse) {
            mod = prog.compile(
                path, options=CompileOptions(default_codespace="native")
            );
        }
    } finally {
        set_effective_default_codespace(previous);
    }
    return (prog, mod, path, parsed.count(path));
}

"""Where each top-level function and the entry block were placed."""
def placed_by_name(mod: uni.Module) -> dict[str, str] {
    out: dict[str, str] = {};
    for stmt in mod.body {
        if isinstance(stmt, uni.Ability) and stmt.name_ref is not None {
            out[stmt.name_ref.sym_name] = stmt.code_context.value;
        } elif isinstance(stmt, uni.ModuleCode) {
            out["entry"] = stmt.code_context.value;
        }
    }
    return out;
}

def refused_units(prog: JacProgram, mod: uni.Module) -> list[str] {
    legality = build_native_legality(mod, prog);
    return sorted(
        native_unit_name(owner)
        for (key, owner) in legality.owners.items()
        if key in legality.units
    );
}

test "a module is parsed and analyzed once and placed native after analysis" {
    (prog, mod, path, parses) = compile_native_default(CLEAN_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1;
    assert mod.decided_codespace == 'native' and mod.codespace_inferred;
    assert mod.gen.llvm_ir is not None;
}

test "a refused unit and every unit that reaches it are placed in Python statically" {
    (prog, mod, path, parses) = compile_native_default(SEAM_SRC + SEAM_ENTRY);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert refused_units(prog, mod) == ["helper", "mid"];
    assert not build_native_legality(mod, prog).module_refused();
    placed = placed_by_name(mod);
    assert placed["helper"] == 'server' and placed["mid"] == 'server' , placed;
    assert placed["other"] == 'native' , placed;
    iface = mod.gen.native_iface;
    assert iface is not None and "other" not in iface.demoted;
}

test "placement is per element: what cannot be native stays in Python, the rest is native" {
    (prog, mod, path, parses) = compile_native_default(SEAM_SRC + REACHING_ENTRY);
    assert parses == 1 , "placement must not parse or analyze the module again";
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    placed = placed_by_name(mod);
    assert placed["other"] == 'native' , placed;
    assert placed["helper"] == 'server' and placed["mid"] == 'server' , placed;
    assert placed["entry"] == 'server' , (
        f"the entry reaches `mid`, whose str result cannot cross into native code: {placed}"
    );
    assert mod.decided_codespace != 'native' , "a mixed module is not whole-module native";
}

test "a refusal only the backend can see places the module on the server in place" {
    (prog, mod, path, parses) = compile_native_default(LATE_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1 , "a late refusal must not recompile the module";
    assert mod.decided_codespace != 'native';
    assert mod.gen.llvm_ir is None;
    assert mod.gen.py_ast , "the Python backend emits the module in the same compile";
}

test "a native library gap refuses the function that uses it, not the module" {
    (prog, mod, path, parses) = compile_native_default(GAP_SRC);
    assert not prog.errors_had , (
        f"a parameter the native json lacks is a placement fact, not a type "
        f"error: {[str(e) for e in prog.errors_had]}"
    );
    assert refused_units(prog, mod) == ["pretty"];
    placed = placed_by_name(mod);
    assert placed["pretty"] == 'server' and placed["plain"] == 'native' , placed;
}

test "what only matters natively is a note on the typed module, never a type error" {
    (prog, mod, path, parses) = compile_native_default(ERASED_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert parses == 1;
    assert mod.decided_codespace != 'native';
    assert "E1124" in [note.code for note in capability_notes_of(prog, path, "native")];
}

test "a native-only construct in code that cannot be placed native is an error" {
    (prog, mod, path, parses) = compile_native_default(NATIVE_ONLY_SRC);
    unmet = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5090" and "native-only" in str(e)
    ];
    assert unmet , f"expected the unmet native requirement: {[
        str(e) for e in prog.errors_had
    ]}";
    assert "cannot be placed native" in (unmet[0].help_text or "");
}

test "a backend crash is a compiler error, never a placement decision" {
    import from unittest.mock { patch }
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    real_body: any = NaIRGenPass._codegen_body;
    calls: list[int] = [];
    def crash_once(this: NaIRGenPass, *args: any) {
        calls.append(1);
        if len(calls) == 1 {
            raise RuntimeError("boom");
        }
        real_body(this, *args);
    }
    with patch.object(NaIRGenPass, "_codegen_body", crash_once) {
        (prog, mod, path, parses) = compile_native_default(CLEAN_SRC);
    }
    crashes = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5092"
    ];
    assert crashes , f"a backend crash must surface as an error: {[
        str(e) for e in prog.errors_had
    ]}";
    assert "compiler bug" in (crashes[0].help_text or "");
    assert mod.decided_codespace == 'native' , "a crash must not move the module";
}

test "a docstring-only module is not a candidate for native placement" {
    path = os.path.join(tempfile.mkdtemp(), "__init__.jac");
    with open(path, "w") as fh {
        fh.write('"""pkg."""\n');
    }
    prog = JacProgram();
    mod = prog.compile(path, options=CompileOptions(no_cgen=True));
    (ok, why) = native_placement_candidate(mod, prog);
    assert not ok , "an empty module was a native candidate";
    assert "empty module" in why , why;
}

test "importer invalidation clears ES output and NATIVE bindings" {
    prog = JacProgram();
    app = prog.compile(os.path.join(PIN_FIXTURE_DIR, "app.jac"));
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    models_path = os.path.realpath(os.path.join(PIN_FIXTURE_DIR, "models.jac"));
    app.gen.js = "stale na glue";
    manifest = app.gen.interop_manifest;
    manifest.bindings["double"] = InteropBinding(
        name="double",
        source_context=InteropContext.NATIVE,
        callers={InteropContext.CLIENT},
        source_module=models_path
    );
    manifest.bindings["unrelated"] = InteropBinding(
        name="unrelated",
        source_context=InteropContext.SERVER,
        callers={InteropContext.CLIENT},
        source_module=models_path
    );
    cleared = invalidate_importers_es(prog, models_path);
    assert app in cleared , "the importer must be found by the hub walk";
    assert app.gen.js == "" , "stale ES output must be cleared";
    for m in cleared {
        drop_native_bindings(m, models_path);
    }
    assert "double" not in manifest.bindings , "the NATIVE binding naming the module must be dropped";
    assert "unrelated" in manifest.bindings , "bindings in other contexts must survive";
}
