import from jaclang.compiler.frontend.constant { SymbolAccess, SymbolType, Tokens }
import from jaclang.compiler.frontend.unitree { Name, Source }
import from jaclang.compiler.types.types {
    ClassType,
    FunctionType,
    FunctionTypeFlags,
    Parameter,
    ParameterCategory,
    ParamKind,
    TypeBase
}

def install_builtin_extensions(
    list_class: ClassType | None, int_class: ClassType | None
) -> None {
    if list_class is None or int_class is None {
        return;
    }
    scope = list_class.shared.symbol_table;
    if scope is None or "chunks" in scope.names_in_scope {
        return;
    }
    element_types: list[TypeBase] = [t for t in list_class.shared.type_params];
    receiver = list_class.clone_as_instance();
    receiver.private.type_args = element_types;
    result = list_class.clone_as_instance();
    result.private.type_args = [receiver];
    method = FunctionType(
        func_name="chunks",
        return_type=result,
        parameters=[
            Parameter(
                name="self",
                category=ParameterCategory.Positional,
                param_type=receiver,
                is_self=True,
                param_kind=ParamKind.POSONLY
            ),
            Parameter(
                name="n",
                category=ParameterCategory.Positional,
                param_type=int_class.clone_as_instance(),
                param_kind=ParamKind.POSONLY
            )
        ],
        function_flags=FunctionTypeFlags.SynthesizedMethod
    );
    name = Name(
        orig_src=Source("chunks", "<jac builtin extensions>"),
        name=Tokens.NAME.value,
        value="chunks",
        line=1,
        end_line=1,
        col_start=0,
        col_end=6,
        pos_start=0,
        pos_end=6
    );
    name.bind_sym(name, "chunks", SymbolType.ABILITY);
    name.set_parent(scope);
    name.type = method;
    scope.adopt_primary(name.create_symbol(SymbolAccess.PUBLIC, scope));
}
