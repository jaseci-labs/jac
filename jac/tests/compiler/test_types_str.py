"""Tests for type system __str__ methods."""

from pathlib import Path
from unittest.mock import MagicMock

from jaclang.compiler.type_system import types
from jaclang.pycore.unitree import Module


def test_all_type_str_methods() -> None:
    """Test all type __str__ method implementations."""
    # Test UnboundType
    unbound = types.UnboundType()
    assert str(unbound) == "<Unbound>"

    # Test UnknownType
    unknown = types.UnknownType()
    assert str(unknown) == "<Unknown>"

    # Test NeverType
    never = types.NeverType()
    assert str(never) == "<Never>"

    # Test AnyType
    any_type = types.AnyType()
    assert str(any_type) == "<Any>"

    # Test TypeVarType
    type_var = types.TypeVarType()
    assert str(type_var) == "<TypeVar>"

    # Test ModuleType - with mod_name
    module1 = types.ModuleType(mod_name="test_module")
    assert str(module1) == "<module test_module>"

    # Test ModuleType - with file_uri
    module2 = types.ModuleType(file_uri=Path("/path/to/module.jac"))
    assert str(module2) == "<module /path/to/module.jac>"

    # Test ModuleType - with empty/default values
    module3 = types.ModuleType()
    assert str(module3) == "<module>"

    # Test FunctionType - with no parameters
    func1 = types.FunctionType(func_name="test_func")
    assert str(func1) == "<function test_func()>"

    # Test FunctionType - with parameters
    param1 = types.Parameter(
        name="x",
        category=types.ParameterCategory.Positional,
        param_type=types.AnyType(),
    )
    param2 = types.Parameter(
        name="y",
        category=types.ParameterCategory.Positional,
        param_type=types.AnyType(),
    )
    func2 = types.FunctionType(
        func_name="add",
        parameters=[param1, param2],
        return_type=types.AnyType(),
    )
    assert str(func2) == "<function add(x: <Any>, y: <Any>) -> <Any>>"

    # Test FunctionType - with return type only
    func3 = types.FunctionType(
        func_name="get_value",
        return_type=types.AnyType(),
    )
    assert str(func3) == "<function get_value() -> <Any>>"

    # Test FunctionType - anonymous function
    func4 = types.FunctionType()
    assert str(func4) == "<function <anonymous>()>"

    # Test OverloadedType - with no overloads
    overload1 = types.OverloadedType()
    assert str(overload1) == "<overload 0 overloads>"

    # Test OverloadedType - with overloads
    func1_overload = types.FunctionType(func_name="test")
    func2_overload = types.FunctionType(func_name="test")
    overload2 = types.OverloadedType(overloads=[func1_overload, func2_overload])
    assert str(overload2) == "<overload 2 overloads>"

    # Test UnionType - empty union
    union1 = types.UnionType(types=[])
    assert str(union1) == "<Union>"

    # Test UnionType - union with types
    int_type = types.AnyType()  # Using AnyType as placeholder
    str_type = types.AnyType()
    union2 = types.UnionType(types=[int_type, str_type])
    # Since both are AnyType, they'll both stringify to "<Any>"
    assert str(union2) == "<Any> | <Any>"

    # Test UnionType - union with different types
    union3 = types.UnionType(
        types=[
            types.UnknownType(),
            types.NeverType(),
            types.AnyType(),
        ]
    )
    assert str(union3) == "<Unknown> | <Never> | <Any>"

    # Test ClassType
    # Create a mock symbol table with required attributes
    mock_module = MagicMock(spec=Module)
    mock_module.names_in_scope = {}
    mock_module.names_in_scope_overload = {}

    shared = types.ClassType.ClassDetailsShared(
        class_name="TestClass",
        symbol_table=mock_module,
        mro=[],
    )
    class_type = types.ClassType(shared=shared)
    assert str(class_type) == "<class TestClass>"
