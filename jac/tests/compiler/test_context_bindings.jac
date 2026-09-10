"""Dependency bindings resolve before a statement checker visits the body."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Name, WithStmt }
import from jaclang.compiler.types.types { ClassType }

test "a lazy context alias uses the enter result before statement checking" {
    prog = JacProgram();
    mod = prog.compile(
        "lazy_context.jac",
        use_str="import from io { BytesIO }\ndef read_bytes { with BytesIO() as stream { return stream.getvalue(); } }\n",
        options=CompileOptions(no_cgen=True, symtab_ir_only=True)
    );
    context = mod.get_all_sub_nodes(WithStmt)[0];
    binding = context.exprs[0].alias;
    assert isinstance(binding, Name) and binding.sym is not None;
    assert binding.type is None , "the fixture must precede statement type checking";
    inferred = prog.get_type_evaluator().get_type_of_symbol(binding.sym);
    assert isinstance(inferred, ClassType);
    assert inferred.shared.class_name == "BytesIO";
    assert not prog.errors_had , prog.errors_had;
}

test "a lazy async context alias unwraps the enter result" {
    prog = JacProgram();
    mod = prog.compile(
        "lazy_async_context.jac",
        use_str="obj Manager { async def __aenter__ -> int { return 7; } async def __aexit__(kind: any, value: any, trace: any) {} }\nasync def read_value { async with Manager() as value { return value; } }\n",
        options=CompileOptions(no_cgen=True, symtab_ir_only=True)
    );
    context = mod.get_all_sub_nodes(WithStmt)[0];
    binding = context.exprs[0].alias;
    assert isinstance(binding, Name) and binding.sym is not None;
    assert binding.type is None , "the fixture must precede statement type checking";
    inferred = prog.get_type_evaluator().get_type_of_symbol(binding.sym);
    assert isinstance(inferred, ClassType) and inferred.is_builtin("int");
    assert not prog.errors_had , prog.errors_had;
}
