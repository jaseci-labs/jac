"""Callable ownership contracts survive type construction and interface caching."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.frontend.constant { OwnershipKind }
import from jaclang.compiler.frontend.diagnostics { E1304, E1320 }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.types.types {
    FunctionType,
    Parameter,
    ParameterCategory,
    UnknownType
}
import from jaclang.compiler.types.stubcat.writer { CatalogWriter }
import from jaclang.compiler.types.stubcat.reader { open_catalog_file }

test "callable ownership is preserved when cloning and serializing types" {
    owned = FunctionType(
        return_type=UnknownType(),
        return_ownership=OwnershipKind.OWN,
        return_sources=[0],
        return_linear=True,
        parameters=[
            Parameter(
                name="value",
                category=ParameterCategory.Positional,
                param_type=UnknownType(),
                ownership=OwnershipKind.OWN,
                linear=True
            )
        ]
    );
    borrowed = owned.clone();
    borrowed.parameters[0].ownership = OwnershipKind.BORROW;
    borrowed.parameters[0].linear = False;
    borrowed.return_ownership = OwnershipKind.BORROW;
    borrowed.return_sources = [];
    borrowed.return_linear = False;
    assert owned.parameters[0].ownership == OwnershipKind.OWN;
    assert owned.parameters[0].linear;
    with TemporaryDirectory() as directory {
        writer = CatalogWriter(evaluator=None, pkg_dir=os.getcwd());
        owner_id = writer.ref_type(owned);
        borrow_id = writer.ref_type(borrowed);
        assert owner_id != borrow_id;
        path = Path(directory) / "callables.jscat";
        path.write_bytes(writer.emit(key="ownership", ambient={}));
        catalog = open_catalog_file(str(path), os.getcwd());
        assert catalog is not None;
        restored = catalog.type_of(owner_id);
        loan = catalog.type_of(borrow_id);
        assert isinstance(restored, FunctionType) and isinstance(loan, FunctionType);
        assert restored.return_ownership == OwnershipKind.OWN;
        assert restored.parameters[0].ownership == OwnershipKind.OWN;
        assert restored.parameters[0].linear;
        assert restored.return_sources == [0] and restored.return_linear;
        assert not loan.return_sources and not loan.return_linear;
        assert loan.return_ownership == OwnershipKind.BORROW;
        assert loan.parameters[0].ownership == OwnershipKind.BORROW;
        assert not loan.parameters[0].linear;
    }
}

test "function declarations and callable annotations retain matching ownership" {
    program = JacProgram();
    module = program.compile(
        "callable_annotations.jac",
        use_str="obj Item {} def consume(value: own Item) -> own Item { return value; } "
        "def apply(handler: Callable[[own Item], own Item], value: own Item) -> own Item { return handler(value); }",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert not program.errors_had , "\n".join(
        str(error) for error in program.errors_had
    );
    assert module is not None;
    evaluator = program.get_type_evaluator();
    consume = evaluator.get_type_of_symbol(module.names_in_scope["consume"]);
    apply_type = evaluator.get_type_of_symbol(module.names_in_scope["apply"]);
    assert isinstance(consume, FunctionType) and isinstance(apply_type, FunctionType);
    handler = apply_type.parameters[0].param_type;
    assert isinstance(handler, FunctionType);
    assert handler.return_ownership == consume.return_ownership == OwnershipKind.OWN;
    assert handler.parameters[0].ownership
        == consume.parameters[0].ownership
        == OwnershipKind.OWN;
}

test "named Callable lifetime dependencies use parameter positions" {
    program = JacProgram();
    module = program.compile(
        "lifetime_annotations.jac",
        use_str="obj Item {} def choose(a: &Item, b: &Item, first: bool) -> &Item from (a, b) { if first { return a; } return b; } "
        "def apply(handler: Callable[[left: &Item, right: &Item, first: bool], &Item from (left, right)]) {} "
        "def transfer(handler: Callable[[frame: lin Item, value: own Item from frame], own Item]) {}",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert module is not None;
    assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
    evaluator = program.get_type_evaluator();
    choose = evaluator.get_type_of_symbol(module.names_in_scope["choose"]);
    apply_type = evaluator.get_type_of_symbol(module.names_in_scope["apply"]);
    transfer = evaluator.get_type_of_symbol(module.names_in_scope["transfer"]);
    assert isinstance(choose, FunctionType)
        and isinstance(apply_type, FunctionType)
        and isinstance(transfer, FunctionType);
    handler = apply_type.parameters[0].param_type;
    consuming = transfer.parameters[0].param_type;
    assert isinstance(handler, FunctionType) and isinstance(consuming, FunctionType);
    assert choose.return_sources == handler.return_sources == [0, 1];
    assert consuming.parameters[0].linear;
    assert consuming.parameters[1].lifetime_sources == [0];
}

test "lifetime contract sources must exist and cannot form cycles" {
    for source in [
        "def bad(a: &Item) -> &Item from missing;",
        "def bad(a: &Item from a);",
        "def bad(a: &Item from b, b: &Item from a);",
        "def bad(a: &Item) -> &Item from (a, a);"
    ] {
        program = JacProgram();
        program.compile(
            "bad_lifetime.jac",
            use_str="obj Item {} " + source,
            options=CompileOptions(no_cgen=True, force_target_program=True)
        );
        assert any(e.code == E1320 for e in program.errors_had) , source + "\n" + "\n".join(
            str(e) for e in program.errors_had
        );
    }
}

test "callable dependencies account for implicit receivers and unordered sources" {
    evaluator = JacProgram().get_type_evaluator();
    method = FunctionType(
        return_type=UnknownType(),
        return_ownership=OwnershipKind.BORROW,
        return_sources=[1, 2],
        parameters=[
            Parameter(name="self", category=ParameterCategory.Positional,
                      param_type=UnknownType(), is_self=True,
                      ownership=OwnershipKind.BORROW),
            Parameter(name="owner", category=ParameterCategory.Positional,
                      param_type=UnknownType(), ownership=OwnershipKind.BORROW),
            Parameter(name="child", category=ParameterCategory.Positional,
                      param_type=UnknownType(), ownership=OwnershipKind.BORROW,
                      lifetime_sources=[1])
        ]
    );
    callable_type = method.clone();
    callable_type.parameters = callable_type.parameters[1:];
    callable_type.parameters[1].lifetime_sources = [0];
    callable_type.return_sources = [1, 0];
    assert evaluator.assign_type(method, callable_type);
    method.return_sources = [0];
    callable_type.return_sources = [0];
    assert not evaluator.assign_type(method, callable_type);
    method.return_sources = [1, 2];
    callable_type.return_sources = [1, 0];
    method.parameters[2].lifetime_sources = [0];
    assert not evaluator.assign_type(method, callable_type);
}

test "only the declared foreign destructor may discharge a dependent owner" {
    declarations = '@foreign_resource(abi="word", empty=1, drop=release_handle, aliasing="shared", reentrant_drop=True) obj Handle; '
        'import from c { '
        '@foreign_call(errors="none", reentrant=True) def release_handle(value: own Handle); '
        '@foreign_call(errors="none", reentrant=True) def store_handle(value: own Handle); } ';
    for (callee, rejected) in [("release_handle", False), ("store_handle", True)] {
        program = JacProgram();
        program.compile(
            "dependent_cleanup.jac",
            use_str=declarations
                + 'def finish(owner: &Handle, child: lin Handle from owner) { '
                + callee + '(child); }',
            options=CompileOptions(no_cgen=True, force_target_program=True,
                                   force_codespace="native", memory_profile="nogc")
        );
        if rejected {
            assert any(e.code == E1320 for e in program.errors_had);
        } else {
            assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
        }
    }
}

test "return bodies cannot substitute an undeclared lifetime source" {
    program = JacProgram();
    program.compile(
        "wrong_source.jac",
        use_str="obj Item {} def bad(a: &Item, b: &Item) -> &Item from a { return b; }",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert any(e.code == E1320 for e in program.errors_had) , "\n".join(
        str(e) for e in program.errors_had
    );
}

test "an owned dependent pins its owner after its last ordinary read" {
    program = JacProgram();
    program.compile(
        "owned_dependency.jac",
        use_str="obj Item {} def make_child(parent: &Item) -> own Item from parent { return Item(); } "
        "def release(value: own Item) {} def probe() { parent: own Item = Item(); "
        "child: own Item from parent = make_child(&parent); release(parent); }",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert any(e.code == E1304 for e in program.errors_had) , "\n".join(
        str(e) for e in program.errors_had
    );
}

test "a matching consuming contract transfers an owner and its dependent" {
    program = JacProgram();
    program.compile(
        "cotransfer.jac",
        use_str="obj Item {} def make_child(parent: &Item) -> own Item from parent { return Item(); } "
        "def accept(parent: own Item, child: own Item from parent) {} "
        "def probe() { parent: own Item = Item(); child: own Item from parent = make_child(&parent); "
        "accept(parent, child); }",
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
}

test "foreign resource declarations retain ABI and cleanup contracts" {
    program = JacProgram();
    module = program.compile(
        "foreign_contracts.jac",
        use_str='@foreign_resource(abi="word", empty=1, drop=release_handle, aliasing="shared", reentrant_drop=True) obj Handle; '
        'import from c { @foreign_call(requires=["gil"], errors="none", reentrant=True) def release_handle(value: own Handle); '
        '@foreign_call(requires=["gil"], errors="python", reentrant=True) def read_handle(value: &Handle) -> i64; }',
        options=CompileOptions(
            no_cgen=True,
            force_target_program=True,
            force_codespace="native",
            memory_profile="nogc"
        )
    );
    assert module is not None;
    assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
    evaluator = program.get_type_evaluator();
    handle = evaluator.get_type_of_symbol(module.names_in_scope["Handle"]);
    import from jaclang.compiler.types.types { ClassType }
    assert isinstance(handle, ClassType);
    assert handle.shared.foreign_resource
        == ("word", 1, "release_handle", "shared", True);
    drop = evaluator.get_type_of_symbol(module.names_in_scope["release_handle"]);
    assert isinstance(drop, FunctionType);
    assert drop.required_capabilities == ["gil"]
        and drop.foreign_errors == "none"
        and drop.reentrant;
    with TemporaryDirectory() as directory {
        writer = CatalogWriter(evaluator=None, pkg_dir=os.getcwd());
        type_id = writer.ref_type(handle);
        drop_id = writer.ref_type(drop);
        path = Path(directory) / "foreign.jscat";
        path.write_bytes(writer.emit(key="foreign", ambient={}));
        catalog = open_catalog_file(str(path), os.getcwd());
        assert catalog is not None;
        restored = catalog.type_of(type_id);
        restored_drop = catalog.type_of(drop_id);
        assert isinstance(restored, ClassType)
            and isinstance(restored_drop, FunctionType);
        assert restored.shared.foreign_resource == handle.shared.foreign_resource;
        assert restored_drop.required_capabilities == ["gil"];
        assert restored_drop.foreign_errors == "none" and restored_drop.reentrant;
    }
}

test "a native wrapper preserves a foreign callee's GIL requirement" {
    program = JacProgram();
    module = program.compile(
        "gil_effect.jac",
        use_str='import from c { @foreign_call(requires=["gil"], errors="python", reentrant=True) def api_call -> i64; } '
        'def indirect() -> i64 { return wrapper(); } def wrapper() -> i64 { return api_call(); }',
        options=CompileOptions(
            no_cgen=True,
            force_target_program=True,
            force_codespace="native",
            memory_profile="nogc"
        )
    );
    assert module is not None;
    assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
    evaluator = program.get_type_evaluator();
    wrapper = evaluator.get_type_of_symbol(module.names_in_scope["indirect"]);
    assert isinstance(wrapper, FunctionType);
    assert wrapper.required_capabilities == ["gil"] and wrapper.reentrant;
    assert wrapper.foreign_errors == "jac";
}

test "implicit foreign cleanup contributes its GIL and reentry effects" {
    program = JacProgram();
    module = program.compile(
        "implicit_drop_effect.jac",
        use_str='@foreign_resource(abi="word", empty=1, drop=release_handle, aliasing="shared", reentrant_drop=True) obj Handle; '
        'import from c { @foreign_call(requires=["gil"], errors="none", reentrant=True) def release_handle(value: own Handle); } '
        'def release_later(value: own Handle) {}',
        options=CompileOptions(no_cgen=True, force_target_program=True,
            force_codespace="native", memory_profile="nogc")
    );
    assert module is not None;
    assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
    function = program.get_type_evaluator().get_type_of_symbol(module.names_in_scope["release_later"]);
    assert isinstance(function, FunctionType);
    assert function.required_capabilities == ["gil"] and function.reentrant;
}

test "lambda signatures preserve ownership and named lifetime dependencies" {
    program = JacProgram();
    module = program.compile(
        "lambda_lifetime.jac",
        use_str='obj Item {} def probe() { handler = lambda (owner: &Item) -> &Item from owner { owner; }; }',
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    assert module is not None;
    assert not program.errors_had , "\n".join(str(e) for e in program.errors_had);
    import from jaclang.compiler.frontend.unitree { LambdaExpr }
    lambdas = module.get_all_sub_nodes(LambdaExpr);
    assert len(lambdas) == 1;
    function = program.get_type_evaluator().get_type_of_expression(lambdas[0]);
    assert isinstance(function, FunctionType);
    assert function.return_sources == [0];
    assert function.return_ownership == function.parameters[0].ownership == OwnershipKind.BORROW;
}
