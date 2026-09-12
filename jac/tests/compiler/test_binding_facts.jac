"""Binding products classify derived syntax nodes throughout a module."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.ir.enums { SymbolStorage }
import from jaclang.compiler.ir.schema { HasVar, ParamVar, Name, LambdaExpr }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }

test "binding facts classify fields parameters locals and captures" {
    with TemporaryDirectory() as tmp {
        path = Path(tmp) / 'bindings.jac';
        path.write_text(
            '''
obj Box {
    has value: int = 0;
    def bump(amount: int) -> int {
        updated = self.value + amount;
        return updated;
    }
}

def outer(seed: int) -> int {
    saved = seed;
    def inner -> int { return saved; }
    return inner();
}
'''
        );
        program = JacProgram();
        module = program.compile(
            str(path),
            options=CompileOptions(
                no_cgen=True,
                symtab_ir_only=True,
                force_target_program=True,
                default_codespace='server'
            )
        );
        assert not program.errors_had;
        for field in module.get_all_sub_nodes(HasVar) {
            assert field.name.sym is not None;
            assert field.name.sym.storage == SymbolStorage.CLASS_FIELD;
        }
        for parameter in module.get_all_sub_nodes(ParamVar) {
            assert parameter.name.sym is not None;
            assert parameter.name.sym.storage == SymbolStorage.PARAM;
        }
        found: set[str] = set();
        for name in module.get_all_sub_nodes(Name) {
            if name.value in ('updated', 'saved') and name.sym is not None {
                expected = SymbolStorage.LOCAL
                    if name.value == 'updated'
                    else SymbolStorage.CAPTURED;
                assert name.sym.storage == expected , (name.value, name.sym.storage);
                found.add(name.value);
            }
        }
        assert found == {'updated', 'saved'};
    }
}

test "binding facts capture lowered graph and comprehension scopes" {
    program = JacProgram();
    module = program.compile(
        "lowered_captures.jac",
        use_str='''
node Item { has value: int; }
def build(seed: Item) -> any {
    return graph { seed ++> [Item(i) ++> Item(i + 1) for i in [1, 2]]; };
}
''',
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert not program.errors_had , [str(e) for e in program.errors_had];
    closures = module.get_all_sub_nodes(LambdaExpr);
    assert len(closures) == 2;
    captures = [
        {symbol.sym_name for symbol in closure.captures} for closure in closures
    ];
    assert any('seed' in names for names in captures) , captures;
    nested = [
        names
        for names in captures
        if 'i' in names
    ];
    assert len(nested) == 1 , captures;
    assert any(name.startswith('__jac_graph_value_') for name in nested[0]);
}
