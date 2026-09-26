"""Lowering failures survive IR linking and retain ABI-preserving method names."""
import from jaclang.compiler.backends.native.llvm { ir, binding as llvm }
import from jaclang.compiler.backends.native.lowering {
    NativeLoweringIssue,
    NativeLoweringKind,
    native_lowering_issues
}
import from jaclang.compiler.backends.native.na_compile_pass {
    native_demoted_ir_symbols
}
import from tests.support { compile_native, native_arch }

test "method demotion is visible without changing the method ABI name" {
    (_, module) = compile_native("partial_native.jac");
    text = str(module.gen.llvm_ir);
    issues = native_lowering_issues(text);
    symbol = f"{native_arch('partial_native.jac', 'Literal')}.evaluate";
    assert any(issue.symbol == symbol for issue in issues);
    assert symbol in native_demoted_ir_symbols(text);
}

test "lowering records retain details through bitcode and linking" {
    left = ir.Module(name="left");
    right = ir.Module(name="right");
    NativeLoweringIssue(
        symbol="Model.value",
        kind=NativeLoweringKind.FIELD,
        source="quoted\"/source.jac",
        code="E5092",
        detail="field\n☃"
    ).record(
        left
    );
    NativeLoweringIssue(
        symbol="Model.run",
        kind=NativeLoweringKind.CALLABLE,
        source="other.jac",
        code="E5090",
        detail="unsupported call"
    ).record(
        right
    );
    linked = llvm.parse_assembly(str(left));
    linked.link_in(llvm.parse_assembly(str(right)));
    restored = llvm.parse_bitcode(linked.as_bitcode());
    restored.verify();
    issues = native_lowering_issues(str(restored));
    assert len(issues) == 2;
    fields = [
        issue
        for issue in issues
        if issue.kind == NativeLoweringKind.FIELD
    ];
    assert len(fields) == 1;
    assert fields[0].source == "quoted\"/source.jac";
    assert fields[0].detail == "field\n☃";
    assert native_demoted_ir_symbols(str(restored)) == ["Model.run"];
}

test "invalid lowering metadata cannot silently pass coverage" {
    failed = False;
    try {
        native_lowering_issues("!jac.native.lowering.v1 = !{!12}\n");
    } except (KeyError, ValueError) {
        failed = True;
    }
    assert failed;
}

test "native-only checking rejects a method that mixed compilation demotes" {
    import os;
    import from tests.support { JAC_ROOT }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    path = os.path.join(
        JAC_ROOT, "tests/compiler/backends/native/fixtures/partial_native.jac"
    );
    for checking in (True, False) {
        program = JacProgram();
        module = program.compile(
            path,
            options=CompileOptions(
                no_cgen=checking,
                native_parity=checking,
                aot_mode=not checking,
                native_required=True,
            )
        );
        assert program.errors_had , "Native-only compilation accepted eval fallback";
        assert any("eval" in str(error) for error in program.errors_had);
        assert module.gen.native_engine is None;
    }
}

test "native-only output validation rejects erased fields and legacy demotions" {
    import from jaclang.compiler.backends.native.na_compile_pass { require_native_ir }
    module = ir.Module(name="erased");
    NativeLoweringIssue(
        symbol="Record.data",
        kind=NativeLoweringKind.FIELD,
        source="record.jac",
        code="E5092",
        detail="field has no native layout"
    ).record(
        module
    );
    for text in (str(module), 'define i64 @"legacy.__jac_demoted"() { ret i64 0 }') {
        failed = False;
        try {
            require_native_ir(text);
        } except ValueError {
            failed = True;
        }
        assert failed , "Native-only validation accepted an incomplete artifact";
    }
}

test "native-only checks link providers outside the entry directory" {
    import tempfile;
    import from pathlib { Path }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        build_link_plan,
        whole_program_module,
        _platform_of
    }
    with tempfile.TemporaryDirectory() as directory {
        fixture_dir = Path(directory);
        (fixture_dir / "library").mkdir();
        (fixture_dir / "application").mkdir();
        (fixture_dir / "library" / "nested").mkdir();
        (fixture_dir / "library" / "nested" / "numbers.jac").write_text(
            "def increment(value: int) -> int { return value + 1; }\n"
        );
        (fixture_dir / "library" / "relay.jac").write_text(
            "import from .nested.numbers { increment }\n"
                + "def relay(value: int) -> int { return increment(value); }\n"
        );
        entry_file = fixture_dir / "application" / "main.jac";
        entry_file.write_text(
            "import from ..library.relay { relay }\n"
                + "def answer -> int { return relay(41); }\n"
        );
        for checking in (True, False) {
            program = JacProgram();
            module = program.compile(
                str(entry_file),
                options=CompileOptions(
                    no_cgen=checking,
                    native_parity=checking,
                    aot_mode=not checking,
                    native_required=True,
                )
            );
            assert not program.errors_had , str(program.errors_had);
            assert not any(
                error.code is not None and error.code.code == "W5023"
                for error in program.warnings_had
            );
            plan = build_link_plan(program, [str(entry_file)], program.options);
            (linked, _) = whole_program_module(
                plan,
                plan.glue_spec(ArtifactKind.SHARED, _platform_of(plan.triple), False)
            );
            provider = next(
                unit
                for unit in plan.units
                if unit.path.endswith("/nested/numbers.jac")
            );
            import from jaclang.compiler.backends.native.llvm.binding.value { ValueRef }
            function = linked.get_function(provider.iface.exports["increment"].symbol);
            assert isinstance(function, ValueRef);
            assert not function.is_declaration;
        }
    }
}
