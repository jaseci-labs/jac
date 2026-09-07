"""Typed semantic graph collections preserve identity and cache invalidation."""
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.types.types {
    AnyType,
    ClassDetailsPrivate,
    ClassDetailsShared,
    ClassType,
    FunctionType,
    OverloadedType,
    UnionType,
    TypeVarType
}

test "union mangles normalize repeated storage types without erasing generics" {
    module = Module.make_stub("union_mangles");
    string = ClassType(
        _shared=ClassDetailsShared(class_name="str", symbol_table=module)
    );
    literal_a = ClassType(
        _shared=string.shared, private=ClassDetailsPrivate(literal_value="a")
    );
    literal_b = ClassType(
        _shared=string.shared, private=ClassDetailsPrivate(literal_value="b")
    );
    assert UnionType(types=[literal_a, literal_b]).mangle() == "str";
    integer = ClassType(
        _shared=ClassDetailsShared(class_name="int", symbol_table=module)
    );
    sequence = ClassType(
        _shared=ClassDetailsShared(class_name="list", symbol_table=module)
    );
    ints = sequence.specialize_generics([integer]);
    strings = sequence.specialize_generics([string]);
    assert UnionType(types=[strings, ints, strings]).mangle() == "list[int]|list[str]";
    nested = sequence.specialize_generics(
        [UnionType(types=[integer, string, integer])]
    );
    assert nested.mangle() == "list[int|str]";
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


test "union overload and constraint collections survive graph cache invalidation" {
    argument = AnyType();
    parameter = TypeVarType(name="T", constraints=[argument]);
    function = FunctionType(func_name="f", return_type=argument, parameters=[]);
    overload = OverloadedType(overloads=[function]);
    union = UnionType(types=[parameter, argument]);
    parameter._acc_cache = None;
    overload._acc_cache = None;
    union._acc_cache = None;
    assert parameter.constraints[0] is argument;
    assert overload.overloads[0] is function;
    assert union.types[0] is parameter;
    assert union.types[1] is argument;
    parameter.constraints = None;
    overload.overloads = None;
    union.types = None;
    parameter._acc_cache = None;
    overload._acc_cache = None;
    union._acc_cache = None;
    assert parameter.constraints == [];
    assert overload.overloads == [];
    assert union.types == [];
}
