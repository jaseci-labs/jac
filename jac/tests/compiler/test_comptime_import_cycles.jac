"""Compile-time symbol resolution terminates across cyclic and long reexports."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from typing { cast }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Symbol, UniNode }
import from jaclang.compiler.types.ct_eval { CtEvaluator, CtError, CtNotComptime }

test "compile-time evaluation guards self imports and cyclic reexports through evaluation" {
    original = cast(
        Callable[[CtEvaluator, Symbol, UniNode], object], CtEvaluator._eval_symbol
    );
    depth: list[int] = [0, 0];
    def bounded(evaluator: CtEvaluator, symbol: Symbol, use: UniNode) -> object {
        depth[0] += 1;
        depth[1] = max(depth);
        try {
            if depth[0] > 16 {
                raise CtError("cyclic symbol evaluation did not terminate");
            }
            return original(evaluator, symbol, use);
        } finally {
            depth[0] -= 1;
        }
    }
    for count in (1, 2) {
        with TemporaryDirectory() as directory {
            base = Path(directory);
            for index in range(count) {
                (base / f"link{index}.jac").write_text(
                    f"import from .link{(index + 1) % count} {{ value }}\n"
                    "def probe() { return value; }\n"
                );
            }
            program = JacProgram();
            module = program.compile(
                str(base / "link0.jac"),
                options=CompileOptions(symtab_ir_only=True, no_ir_cache=True)
            );
            evaluator = program.get_type_evaluator().ct_eval;
            depth[:] = [0, 0];
            with patch.object(CtEvaluator, "_eval_symbol", bounded) {
                with testraises(CtNotComptime) {
                    evaluator._eval_symbol(module.names_in_scope["value"], module);
                }
            }
            assert depth[1] > 0;
            assert depth[1] <= 3 , "cyclic aliases reentered compile-time evaluation";
            assert not evaluator._active;
            program.release_compile_closure(retain_stubs=False);
        }
    }
}

test "compile-time values remain available through long acyclic reexport chains" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        for index in range(32) {
            (base / f"link{index}.jac").write_text(
                f"comptime import from .link{index + 1} {{ VALUE }}\n"
            );
        }
        (base / "link32.jac").write_text("comptime VALUE: int = 42;\n");
        source = base / "main.jac";
        source.write_text(
            "comptime import from .link0 { VALUE }\n"
            "with entry { comptime assert VALUE == 42; }\n"
        );
        program = JacProgram();
        program.compile(
            str(source), options=CompileOptions(no_cgen=True, no_ir_cache=True)
        );
        assert not program.errors_had , "\n".join(
            alert.pretty_print() for alert in program.errors_had
        );
        assert not program.get_type_evaluator().ct_eval._active;
        program.release_compile_closure(retain_stubs=False);
    }
}
