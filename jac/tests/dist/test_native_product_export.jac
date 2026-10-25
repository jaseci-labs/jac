"""A native source export optimizes the merged program before the C backend sees it."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.compiler.backends.native.c_emit as c_emit;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.dist.native_product { write_native_product }

def _defines(text: str) -> int {
    return sum(
        1
        for line in text.splitlines()
        if line.startswith("define ")
    );
}

"""Compile a project's `main.jac` and export it as a shared native product."""
def _export_shared(
    base: Path, main_src: str, helper_src: str, seen: list[str]
) -> tuple[any, dict[str, any]] {
    (base / "jac.toml").write_text('[placement.pins]\nhelper = "server"\n');
    (base / "helper.jac").write_text(helper_src);
    (base / "main.jac").write_text(main_src);
    program = JacProgram();
    module = program.compile(
        str(base / "main.jac"),
        options=CompileOptions(
            aot_mode=True, default_codespace="native", skip_native_engine=True
        )
    );
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    def stub_emit(ir: str) -> str {
        seen.append(ir);
        return "/* captured */";
    }
    with patch.object(c_emit, "emit_c", stub_emit) {
        record = write_native_product(
            module, base, Path("libn"), shared=True, program=program
        );
    }
    return (module, record);
}

test "the exported callback record keeps every field the loader needs" {
    import from jaclang.runtime.interop_bridge { native_callback_of }
    with TemporaryDirectory() as tmp {
        (module, record) = _export_shared(
            Path(tmp),
            "import from helper { answer }\n"
                + "def:pub run -> int {\n"
                + "    answer(7);\n"
                + "    return 0;\n"
                + "}\n",
            "def:pub answer(x: int) -> None {\n    return;\n}\n",
            []
        );
        assert record["callbacks"] , (
            "the pinned server callback must be exported, got: "
            + repr(record["callbacks"])
        );
        saved = record["callbacks"][0];
        assert saved["param_types"] == ["int"] , (
            f"the loader needs param_types to build the trampoline, got {saved}"
        );
        assert saved["ret_type"] == "None" , repr(saved);
        symbol = module.gen.interop_manifest.bindings["answer"].symbol;
        assert saved["symbol"] == symbol , (
            f"the record must carry the symbol the product exports, got {saved}"
        );
        rebuilt = native_callback_of(saved, "libn.so");
        assert rebuilt.symbol == symbol and rebuilt.param_types == ["int"];
        assert rebuilt.name == "answer";
    }
}

test "a product record without an interop symbol asks for a rebuild" {
    import from jaclang.runtime.interop_bridge { native_callback_of }
    old = {"name": "answer", "ret_type": "int", "param_types": []};
    refused = "";
    try {
        native_callback_of(old, "libold.so");
    } except RuntimeError as e {
        refused = str(e);
    }
    assert "libold.so" in refused and "Rebuild" in refused , (
        f"an old record must fail with a rebuild message, got: {refused!r}"
    );
}

test "bare and aliased imports of one function export one callback" {
    with TemporaryDirectory() as tmp {
        seen: list[str] = [];
        (module, record) = _export_shared(
            Path(tmp),
            "import from helper { answer }\n"
                + "import from helper { answer as ans }\n"
                + "def:pub run -> int {\n"
                + "    return answer() + ans();\n"
                + "}\n",
            "def:pub answer -> int {\n    return 21;\n}\n",
            seen
        );
        symbol = module.gen.interop_manifest.bindings["answer"].symbol;
        assert [cb["symbol"] for cb in record["callbacks"]] == [symbol] , (
            f"one function must be exported once, got {record['callbacks']}"
        );
        assert len(seen) == 1;
        binders = [
            line
            for line in seen[0].splitlines()
            if line.startswith("define") and ("__jac_bind_" + symbol) in line
        ];
        assert len(binders) == 1 , (
            f"the shared glue must bind the callback once, got {binders}"
        );
    }
}

test "the shared callback glue binds each symbol once" {
    import from jaclang.compiler.backends.native.link_glue { bind_shared_callbacks }
    import from jaclang.compiler.frontend.codeinfo { InteropBinding, InteropContext }
    symbol = "__jac_na_import_helper_0_answer_0";
    bare = InteropBinding(
        name="answer",
        source_context=InteropContext.SERVER,
        callers={InteropContext.NATIVE},
        symbol=symbol
    );
    aliased = InteropBinding(
        name="answer",
        source_context=InteropContext.SERVER,
        callers={InteropContext.NATIVE},
        symbol=symbol
    );
    (text, callbacks) = bind_shared_callbacks(
        f"declare i64 @{symbol}()", [bare, aliased]
    );
    assert len(callbacks) == 1 , f"one symbol is one callback, got {callbacks}";
    defines = [
        line
        for line in text.splitlines()
        if line.startswith("define")
    ];
    assert len(defines) == 2 , f"one binder and one trampoline, got {defines}";
}


test "a native source export hands the C backend the reachable program only" {
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        build_link_plan,
        whole_program_module
    }
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        source = base / "entry.jac";
        source.write_text(
            "import os;\nimport sys;\nwith entry { print(len(sys.argv)); }\n"
        );
        program = JacProgram();
        module = program.compile(
            str(source),
            options=CompileOptions(aot_mode=True, default_codespace="native")
        );
        assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
        seen: list[str] = [];
        def capture(ir: str) -> str {
            seen.append(ir);
            return "/* captured */";
        }
        with patch.object(c_emit, "emit_c", capture) {
            record = write_native_product(
                module, base, Path("main"), shared=False, program=program
            );
        }
        assert record["source"] == "main.c";
        assert (base / "main.c").read_text() == "/* captured */";
        assert len(seen) == 1;
        optimized = seen[0];
        entry_lines = [
            line
            for line in optimized.splitlines()
            if line.startswith("define") and "@main(" in line
        ];
        assert entry_lines and " internal " not in entry_lines[0] , (
            "the exported C must define an external main: " + repr(entry_lines)
        );
        plan = build_link_plan(program, [module.loc.mod_path], program.options);
        (merged, _) = whole_program_module(
            plan, plan.glue_spec(ArtifactKind.EXECUTABLE, "c", False)
        );
        raw = str(merged);
        assert _defines(optimized) < _defines(raw) , (
            "internalizing must strip the runtime functions the entry never reaches: "
            f"{_defines(optimized)} defined after, {_defines(raw)} before"
        );
    }
}
