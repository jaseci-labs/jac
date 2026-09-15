"""Compile-time operators use Jac semantics through one binary dispatcher."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.types.ct_eval { CtEvaluator, CtError }
import from jaclang.compiler.frontend.constant { Tokens as Tok }

test "compile-time comparison and membership preserve operand order" {
    evaluator = CtEvaluator(evaluator=JacProgram().get_type_evaluator());
    assert evaluator._cmp(Tok.LT.value, -2, 3);
    assert evaluator._cmp(Tok.LTE.value, 3, 3);
    assert evaluator._cmp(Tok.GT.value, "b", "a");
    assert evaluator._cmp(Tok.GTE.value, "a", "a");
    assert evaluator._cmp(Tok.KW_IN.value, "key", {"key": 7});
    assert not evaluator._cmp(Tok.KW_IN.value, 7, {"key": 7});
    assert evaluator._cmp(Tok.KW_NIN.value, "missing", ["key"]);
    assert evaluator._cmp(Tok.KW_IN.value, "bc", "abcd");
}

test "shared compile-time binary operators preserve values and errors" {
    evaluator = CtEvaluator(evaluator=JacProgram().get_type_evaluator());
    assert evaluator._binop_by_name(Tok.PLUS.value, [1], [2]) == [1, 2];
    assert evaluator._binop_by_name(Tok.STAR_MUL.value, "ab", 2) == "abab";
    assert evaluator._binop_by_name(Tok.FLOOR_DIV.value, -7, 3) == -3;
    assert evaluator._binop_by_name(Tok.MOD.value, -7, 3) == 2;
    assert evaluator._binop_by_name(Tok.DIV.value, 7, 2) == 3.5;
    assert evaluator._binop_by_name(Tok.RSHIFT.value, 16, 2) == 4;
    with testraises(ZeroDivisionError) {
        evaluator._binop_by_name(Tok.DIV.value, 1, 0);
    }
    with testraises(CtError) {
        evaluator._binop_by_name("unsupported", 16, 2);
    }
}

test "compile-time probes terminate across imported alias cycles" {
    import os;
    import from tests.support { JAC_ROOT }
    import from unittest.mock { patch }
    import from typing { cast }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.frontend.unitree { Symbol }
    import from jaclang.compiler.types.ct_eval { CtNotComptime }
    count: list[int] = [0];
    original = cast(
        Callable[[CtEvaluator, Symbol], Symbol], CtEvaluator._resolve_symbol_deep
    );
    def counted(self: CtEvaluator, sym: Symbol) -> Symbol {
        count[0] += 1;
        if count[0] > 1000 {
            raise CtNotComptime();
        }
        return original(self, sym);
    }
    program = JacProgram();
    with patch.object(CtEvaluator, "_resolve_symbol_deep", counted) {
        program.compile(
            os.path.join(
                JAC_ROOT,
                "jaclang",
                "compiler",
                "backends",
                "native",
                "llvm",
                "binding",
                "newpassmanagers.jac"
            ),
            options=CompileOptions(no_ir_cache=True, force_codespace="server")
        );
    }
    assert not program.errors_had;
    assert count[0] < 1000 , f"import aliases repeated compile-time resolution {count[
        0
    ]} times";
}

test "compile-time aliases resolve through long acyclic import chains" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    with TemporaryDirectory() as directory {
        package_dir = Path(directory);
        (package_dir / "hop40.jac").write_text("comptime VALUE: int = 42;\n");
        for index in range(40) {
            (package_dir / f"hop{index}.jac").write_text(
                f"comptime import from hop{index + 1} {{ VALUE }}\n"
            );
        }
        entry_file = package_dir / "entry.jac";
        entry_file.write_text(
            "comptime import from hop0 { VALUE }\n"
                + "with entry { comptime assert VALUE == 42; }\n"
        );
        program = JacProgram();
        program.compile(
            str(entry_file),
            options=CompileOptions(
                no_cgen=True,
                no_ir_cache=True,
                force_codespace="server",
                project_root=directory
            )
        );
        assert not program.errors_had , "\n".join(
            error.pretty_print() for error in program.errors_had
        );
    }
}
