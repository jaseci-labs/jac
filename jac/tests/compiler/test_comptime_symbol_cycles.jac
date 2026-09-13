"""Compile-time import resolution terminates on cycles and releases its guards."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.analysis.comptime.evaluator { CtEvaluator, CtNotComptime }
import from jaclang.compiler.ir.identity { MutationScope }
import from jaclang.compiler.ir.schema { ModuleItem, Symbol }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.session.session { JacProgram }

def _check_alias(self_import: bool, second: str, expected: int | None) {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        first = base / 'first.jac';
        target = 'first' if self_import else 'second';
        first.write_text(f'import from {target} {{ VALUE }}');
        (base / 'second.jac').write_text(second);
        program = JacProgram();
        module = program.compile(
            str(first),
            options=CompileOptions(
                symtab_ir_only=True,
                no_cgen=True,
                force_target_program=True,
                default_codespace='server',
                need_full_ast=True
            )
        );
        symbol = module.lookup_local('VALUE');
        assert symbol is not None;
        evaluator = CtEvaluator(evaluator=program.get_type_evaluator());
        original = evaluator._symbol_via_module_item;
        calls: list[int] = [0];
        def resolve(item: ModuleItem) -> Symbol | None {
            calls[0] += 1;
            assert calls[0] <= 64 , 'cyclic aliases repeatedly resolve the same imports';
            return original(item);
        }
        with MutationScope(program.analysis.mutations, 7), patch.object(
            evaluator, '_symbol_via_module_item', side_effect=resolve
        ) {
            for attempt in range(2) {
                if expected is None {
                    with testraises(CtNotComptime) {
                        evaluator._eval_symbol(symbol, symbol.decl);
                    }
                } else {
                    assert evaluator._eval_symbol(symbol, symbol.decl) == expected;
                }
                assert not evaluator._active;
            }
        }
    }
}

test "compile-time resolution stops at a self-imported alias" {
    _check_alias(True, '', None);
}

test "compile-time resolution stops at mutually imported aliases" {
    _check_alias(False, 'import from first { VALUE }', None);
}

test "compile-time resolution can repeatedly evaluate a re-exported constant" {
    _check_alias(False, 'comptime VALUE: int = 7;', 7);
}
