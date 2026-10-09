"""Native legality: where a module that prefers native runs is decided from
recorded facts, before any body is lowered where the rules can say so.

A unit the static rules refuse is placed on its Python-only implementation
without lowering it, and so is every unit that reaches it. Module-level
code that reaches a refused unit refuses the module during analysis, so the
native backend never runs for it. A refusal only the backend can see is
recorded on the same table and re-places the module once. A backend crash
is none of these: it is a compiler error."""

import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.native_legality {
    build_native_legality,
    native_unit_name
}
import from jaclang.compiler.placement.placement_pins {
    module_native_demoted,
    native_demotion_code
}

glob SEAM_SRC = (
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
     );

def compile_native_default(text: str) -> tuple[JacProgram, uni.Module, str] {
    import from jaclang.compiler.frontend.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    path = os.path.realpath(os.path.join(tempfile.mkdtemp(), "m.jac"));
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(text);
    }
    previous = get_effective_default_codespace_override();
    prog = JacProgram();
    try {
        mod = prog.compile(path, options=CompileOptions(default_codespace="native"));
    } finally {
        set_effective_default_codespace(previous);
    }
    return (prog, mod, path);
}

def refused_units(mod: uni.Module) -> list[str] {
    legality = build_native_legality(mod);
    return sorted(
        native_unit_name(owner)
        for (key, owner) in legality.owners.items()
        if key in legality.units
    );
}

test "a refused unit and every unit that reaches it are placed in Python statically" {
    (prog, mod, path) = compile_native_default(SEAM_SRC + SEAM_ENTRY);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert mod.decided_codespace == 'native' , "an unreached seam must not cost the module its placement";
    assert refused_units(mod) == ["helper", "mid"];
    assert not build_native_legality(mod).module_refused();
    assert not module_native_demoted(path, prog);
    iface = mod.gen.native_iface;
    assert iface is not None;
    assert "helper" in iface.demoted and "mid" in iface.demoted;
    assert "other" not in iface.demoted;
}

test "module-level code reaching a refused unit refuses the module before the backend runs" {
    import from unittest.mock { patch }
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    real_lower: any = NaIRGenPass._lower_module;
    lowered: list[str] = [];
    def record_lower(this: NaIRGenPass) {
        lowered.append(os.path.realpath(this.module.loc.mod_path));
        real_lower(this);
    }
    with patch.object(NaIRGenPass, "_lower_module", record_lower) {
        (prog, mod, path) = compile_native_default(SEAM_SRC + REACHING_ENTRY);
    }
    assert path not in lowered , "a statically refused module must never reach the native backend";
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert mod.decided_codespace != 'native';
    assert module_native_demoted(path, prog) , "the refusal must be published for pins and importers";
    assert native_demotion_code(path, prog) == "E5090" , "the verdict names the root cause in `helper`, reached through `mid`";
}

test "a refusal only the backend can see re-places the module once, with no error" {
    (prog, mod, path) = compile_native_default(LATE_SRC);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert mod.decided_codespace != 'native';
    assert mod.gen.llvm_ir is None;
    assert module_native_demoted(path, prog);
    assert native_demotion_code(path, prog) == "E5092";
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
        (prog, mod, path) = compile_native_default(CLEAN_SRC);
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
    assert not module_native_demoted(path, prog) , "a crash must not be recorded as a placement verdict";
}
