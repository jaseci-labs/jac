"""Type system __str__ method tests – migrated from test_types_str.py.

Tests that all type classes produce correct string representations.
"""

import from pathlib { Path }
import from unittest.mock { MagicMock }
import from jaclang.compiler.type_system { types }
import from jaclang.jac0core.unitree { Module }

test "all type str methods" {
    # UnboundType
    unbound = types.UnboundType();
    assert str(unbound) == "<Unbound>";

    # UnknownType
    unknown = types.UnknownType();
    assert str(unknown) == "<Unknown>";

    # NeverType
    never = types.NeverType();
    assert str(never) == "<Never>";

    # AnyType
    any_type = types.AnyType();
    assert str(any_type) == "<Any>";

    # TypeVarType
    type_var = types.TypeVarType();
    assert str(type_var) == "<TypeVar>";

    # ModuleType - with mod_name
    module1 = types.ModuleType(mod_name="test_module");
    assert str(module1) == "<module test_module>";

    # ModuleType - with file_uri
    module2 = types.ModuleType(file_uri=Path("/path/to/module.jac"));
    assert str(module2) == "<module /path/to/module.jac>";

    # ModuleType - with empty/default values
    module3 = types.ModuleType();
    assert str(module3) == "<module>";

    # FunctionType - no parameters
    func1 = types.FunctionType(func_name="test_func");
    assert str(func1) == "<function test_func()>";

    # FunctionType - with parameters
    param1 = types.Parameter(
        name="x",
        category=types.ParameterCategory.Positional,
        param_type=types.AnyType()
    );
    param2 = types.Parameter(
        name="y",
        category=types.ParameterCategory.Positional,
        param_type=types.AnyType()
    );
    func2 = types.FunctionType(
        func_name="add", parameters=[param1, param2], return_type=types.AnyType()
    );
    assert str(func2) == "<function add(x: <Any>, y: <Any>) -> <Any>>";

    # FunctionType - return type only
    func3 = types.FunctionType(func_name="get_value", return_type=types.AnyType());
    assert str(func3) == "<function get_value() -> <Any>>";

    # FunctionType - anonymous
    func4 = types.FunctionType();
    assert str(func4) == "Callable[[], Unknown]";

    # OverloadedType - no overloads
    overload1 = types.OverloadedType();
    assert str(overload1) == "<overload 0 overloads>";

    # OverloadedType - with overloads
    func1_overload = types.FunctionType(func_name="test");
    func2_overload = types.FunctionType(func_name="test");
    overload2 = types.OverloadedType(overloads=[func1_overload, func2_overload]);
    assert str(overload2) == "<overload 2 overloads>";

    # UnionType - empty
    union1 = types.UnionType(types=[]);
    assert str(union1) == "<Union>";

    # UnionType - with types
    int_type = types.AnyType();
    str_type = types.AnyType();
    union2 = types.UnionType(types=[int_type, str_type]);
    assert str(union2) == "<Any> | <Any>";

    # UnionType - different types
    union3 = types.UnionType(
        types=[types.UnknownType(), types.NeverType(), types.AnyType()]
    );
    assert str(union3) == "<Unknown> | <Never> | <Any>";

    # ClassType
    mock_module = MagicMock(spec=Module);
    mock_module.names_in_scope = {};
    mock_module.names_in_scope_overload = {};

    shared = types.ClassType.ClassDetailsShared(
        class_name="TestClass", symbol_table=mock_module, mro=[]
    );
    class_type = types.ClassType(shared=shared);
    assert str(class_type) == "<class TestClass>";
}
