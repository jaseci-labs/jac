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
