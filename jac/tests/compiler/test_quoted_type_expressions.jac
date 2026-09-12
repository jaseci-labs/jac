"""Quoted type syntax uses Jac's grammar and evaluator without retaining temporary uses."""

import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.frontend.parser.frontend { parse_expression }
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.ir.identity { MutationScope }
import from jaclang.compiler.ir.types.nodes { TypeBase }
import from jaclang.compiler.api { query_type }

def _resolve(program: JacProgram, source: str, scope: Module) -> TypeBase | None {
    # Exercise the speculative evaluator internals under the same write permit
    # that the scheduled type producer grants while resolving annotations.
    with MutationScope(program.analysis.mutations, 6) {
        return program.get_type_evaluator()._resolve_string_type_expr(source, scope);
    }
}


def _scope(program: JacProgram) -> Module {
    module = program.compile(
        file_path="quoted_types.jac",
        use_str="import typing; obj Item { has value: int = 0; }",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert isinstance(module, Module);
    assert not program.errors_had , str(program.errors_had);
    return module;
}

test "standalone expression parsing consumes the complete input" {
    for source in ["int", "list[int]", "int | None", "Callable[..., int]"] {
        (_expression, failed) = parse_expression(source);
        assert not failed , source;
    }
    for source in ["", "int; str", "list[", "int +"] {
        (_expression, failed) = parse_expression(source);
        assert failed , source;
    }
}

test "quoted generic union and callable annotations share normal type semantics" {
    program = JacProgram();
    scope = _scope(program);
    evaluator = program.get_type_evaluator();
    for (source, expected) in [
        ("int", "int"),
        ("Item", "Item"),
        ("int | None", "int | NoneType"),
        ("(str, int)", "tuple[str, int]"),
        ("Literal[\"x\"]", "Literal[\"x\"]"),
        ("list[Item]", "list[Item]"),
        ("dict[str, list[Item]]", "dict[str, list[Item]]"),
        ("Callable[[int, str], Item]", "Callable[[int, str], Item]"),
        ("Callable[..., Item]", "Callable[..., Item]"),
        ("typing.Callable[[Item], str]", "Callable[[Item], str]")
    ] {
        resolved = _resolve(program, source, scope);
        assert resolved is not None , source;
        assert str(resolved) == expected , f"{source}: {resolved}";
    }
}

test "temporary quoted syntax does not accumulate symbol uses or diagnostics" {
    program = JacProgram();
    scope = _scope(program);
    evaluator = program.get_type_evaluator();
    symbol = scope.lookup("Item");
    assert symbol is not None;
    before = len(symbol.uses);
    errors_before = len(program.errors_had);
    warnings_before = len(program.warnings_had);
    for _ in range(20) {
        resolved = _resolve(program, "list[Item]", scope);
        assert resolved is not None;
        assert str(resolved) == "list[Item]";
        assert _resolve(program, "MissingType", scope) is None;
        assert _resolve(program, "int; str", scope) is None;
    }
    assert len(symbol.uses) == before;
    assert len(program.errors_had) == errors_before;
    assert len(program.warnings_had) == warnings_before;
}

test "type aliases resolve all adjacent literal fragments" {
    program = JacProgram();
    module = program.compile(
        file_path="quoted_aliases.jac",
        use_str="obj Item { has value: int = 0; } type Items = \"list[\" \"Item]\"; type One = \"It\" \"em\";",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert isinstance(module, Module);
    assert not program.errors_had , str(program.errors_had);
    evaluator = program.get_type_evaluator();
    for (name, expected) in [("Items", "list[Item]"), ("One", "Item")] {
        symbol = module.lookup(name);
        assert symbol is not None;
        resolved = query_type(program, symbol);
        assert str(resolved) == expected , str(resolved);
    }
}

test "standalone expression diagnostics retain their source location" {
    program = JacProgram();
    (_expression, failed) = parse_expression(
        "int; str", "quoted_diagnostic.jac", program
    );
    assert failed;
    assert program.errors_had;
    for error in program.errors_had {
        assert error.loc.mod_path == "quoted_diagnostic.jac";
        assert error.loc.first_line == 1;
    }
}

test "speculative type lookup preserves existing and subsequent diagnostics" {
    program = JacProgram();
    module = program.compile(
        file_path="quoted_error.jac",
        use_str="obj Item { has value: int = 0; } type Items = \"list[Item]\"; def wrong -> int { return \"bad\"; }",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert isinstance(module, Module);
    assert any("Cannot return" in str(error) for error in program.errors_had);
    errors = program.errors_had[:];
    evaluator = program.get_type_evaluator();
    assert _resolve(program, "MissingType", module) is None;
    assert program.errors_had == errors;
}

test "quoted generic annotations represent instances" {
    import from jaclang.compiler.ir.types.nodes { ClassType }
    program = JacProgram();
    scope = _scope(program);
    evaluator = program.get_type_evaluator();
    resolved = _resolve(program, "list[Item]", scope);
    assert isinstance(resolved, ClassType);
    assert resolved.is_class_instance();
    assert not resolved.is_instantiable_class();
}
