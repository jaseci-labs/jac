"""Lowering verdicts keep ABI-preserving method names and fail native-only builds."""
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support {
    compile_mir,
    compile_native_refused,
    diagnostics_text,
    fixture_path,
    kernel_check_file,
    source_spelled
}

test "method demotion is visible without changing the method ABI name" {
    fx = compile_mir("partial_native.jac");
    demoted = [source_spelled(symbol) for symbol in fx.demoted()];
    assert any(symbol.endswith(".Literal.evaluate") for symbol in demoted) , demoted;
}

test "native-only checking rejects a method that mixed compilation demotes" {
    checked = kernel_check_file(
        fixture_path("partial_native.jac"),
        CompileOptions(native_parity=True, native_required=True)
    );
    assert not checked.ok() , "Native-only checking accepted eval fallback";
    assert any("eval" in error.message for error in checked.errors) , diagnostics_text(
        checked
    );
    built = compile_native_refused(
        "partial_native.jac",
        options=CompileOptions(aot_mode=True, native_required=True)
    );
    assert any("eval" in error.message for error in built.errors) , diagnostics_text(
        built
    );
}

test "native-only checks link providers outside the entry directory" {
    import tempfile;
    import from pathlib { Path }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        build_link_plan,
        whole_program_module,
        _platform_of
    }
    import from jaclang.compiler.backends.native.llvm.binding.value { ValueRef }
    import from tests.support { adopt_native_units, kernel_compile_file, warning_codes }
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
        checked = kernel_check_file(
            str(entry_file), CompileOptions(native_parity=True, native_required=True)
        );
        assert checked.ok() , diagnostics_text(checked);
        assert "W5023" not in warning_codes(checked) , diagnostics_text(checked);
        options = CompileOptions(aot_mode=True, native_required=True);
        built = kernel_compile_file(str(entry_file), options, ["mir"]);
        assert built.ok() , diagnostics_text(built);
        assert "W5023" not in warning_codes(built) , diagnostics_text(built);
        program = JacProgram();
        program.options = options;
        adopt_native_units(program, built, options);
        plan = build_link_plan(program, [str(entry_file)], options);
        (linked, _) = whole_program_module(
            plan, plan.glue_spec(ArtifactKind.SHARED, _platform_of(plan.triple), False)
        );
        provider = next(
            unit
            for unit in plan.units
            if unit.path.endswith("/nested/numbers.jac")
        );
        function = linked.get_function(provider.iface.exports["increment"].symbol);
        assert isinstance(function, ValueRef);
        assert not function.is_declaration;
    }
}
