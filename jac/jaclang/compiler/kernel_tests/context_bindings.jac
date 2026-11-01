"""Dependency bindings resolve before a statement checker visits the body."""

def bound_alias(analysis: Analysis) -> Name {
    context = analysis.module.get_all_sub_nodes(WithStmt)[0];
    binding = context.exprs[0].alias;
    assert isinstance(binding, Name) and binding.sym is not None;
    assert binding.type is None , "the fixture must precede statement type checking";
    return binding;
}

def lazy_context_alias {
    analysis = analyse(
        "import from io { BytesIO }\ndef read_bytes { with BytesIO() as stream { return stream.getvalue(); } }\n",
        "lazy_context.jac",
        CompileOptions(no_cgen=True, symtab_ir_only=True)
    );
    binding = bound_alias(analysis);
    inferred = analysis.program.get_type_evaluator().get_type_of_symbol(binding.sym);
    assert isinstance(inferred, ClassType);
    assert inferred.shared.class_name == "BytesIO";
    assert not analysis.error_codes() , analysis.messages();
}

def lazy_async_context_alias {
    analysis = analyse(
        "obj Manager { async def __aenter__ -> int { return 7; } async def __aexit__(kind: any, value: any, trace: any) {} }\nasync def read_value { async with Manager() as value { return value; } }\n",
        "lazy_async_context.jac",
        CompileOptions(no_cgen=True, symtab_ir_only=True)
    );
    binding = bound_alias(analysis);
    inferred = analysis.program.get_type_evaluator().get_type_of_symbol(binding.sym);
    assert isinstance(inferred, ClassType) and inferred.is_builtin("int");
    assert not analysis.error_codes() , analysis.messages();
}

def context_binding_cases -> list[KernelCase] {
    return [
        KernelCase(
            "a lazy context alias uses the enter result before statement checking",
            lazy_context_alias
        ),
        KernelCase(
            "a lazy async context alias unwraps the enter result",
            lazy_async_context_alias
        )
    ];
}
