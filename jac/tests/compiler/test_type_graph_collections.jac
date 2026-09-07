"""Typed semantic graph collections preserve identity and cache invalidation."""
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.types.types {
    AnyType,
    ClassDetailsPrivate,
    ClassDetailsShared,
    FunctionType,
    TypeVarType
}

test "class relations return typed lists and regenerate from graph edges" {
    shared = ClassDetailsShared(
        class_name="Example", symbol_table=Module.make_stub("graph")
    );
    parameter = TypeVarType(name="T");
    base = AnyType();
    assert shared.type_params == [];
    assert shared.base_classes == [];
    shared.type_params = [parameter];
    shared.base_classes = [base];
    assert shared.type_params[0] is parameter;
    assert shared.base_classes[0] is base;
    shared._acc_cache = None;
    assert shared.type_params[0] is parameter;
    assert shared.base_classes[0] is base;
    shared.type_params = None;
    shared.base_classes = None;
    assert shared.type_params == [];
    assert shared.base_classes == [];
}

test "type arguments and function parameters normalize absent input to empty lists" {
    argument = AnyType();
    details = ClassDetailsPrivate();
    assert details.type_args == [];
    details.type_args = [argument];
    details._targs_cache = None;
    assert details.type_args[0] is argument;
    details.type_args = None;
    assert details.type_args == [];
    function = FunctionType(func_name="generic", return_type=argument, parameters=[]);
    parameter = TypeVarType(name="U");
    function.type_params = [parameter];
    function._acc_cache = None;
    assert function.type_params[0] is parameter;
    function.type_params = None;
    assert function.type_params == [];
}
