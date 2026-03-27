"""TypeVar validation tests for the type checker."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker"
     ),
     TYPEVAR_FIXTURES = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "checker",
         "typevar"
     );

"""Test TypeVar validation errors (Pyright: createTypeVarType, assignTypeToExpression)."""
test "typevar1_validation_errors" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar1.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 3 , f"Expected 3 errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    assert 'TypeVar name "T3"' in all_errors and 'must match' in all_errors , "Expected name mismatch error for T2 = TypeVar('T3')";
    assert 'must be assigned to a simple variable' in all_errors , "Expected index expression error for my_dict['var'] = TypeVar('T5')";
    assert 'requires at least two constrained types' in all_errors , "Expected single constraint error for TypeVar('T5', str)";
}


"""Test TypeVar scope validation errors (Pyright: typeVar3.py)."""
test "typevar3_scope_errors" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar3.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 12 , f"Expected 12 TypeVar scope errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    assert 'is already in use by an outer scope' in all_errors , "Expected error for nested class reusing outer TypeVar (e.g. InnerClass1 reuses _T)";
    assert 'has no meaning in this context' in all_errors , "Expected error for TypeVar used outside its valid scope";
}

"""Test TypeVar variance validation (Pyright: covariant/contravariant checks)."""
test "typevar4_variance_validation" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar4.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    # 5 errors: covariant in param, contravariant in returns (explicit + inferred)
    assert len(program.errors_had) == 5 , f"Expected 5 errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # Covariant in parameter error
    assert "Covariant type variable cannot be used in parameter type" in all_errors , "Expected covariant param error for func2(a: _T_co)";

    # Contravariant in return errors
    assert "Contravariant type variable cannot be used in return type" in all_errors , "Expected contravariant return error";
}

"""Test unbounded TypeVar operation validation (Pyright: typeVar5)."""
test "typevar5_unbounded_operations" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar5.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    # 18 errors: 9 per function (attribute, call, subscript, attribute, binary,
    # unary, augmented assignment, await, iteration)
    assert len(program.errors_had) == 18 , f"Expected 18 errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # Attribute access errors
    assert 'Cannot access attribute "temp" for type "_T1"' in all_errors , "Expected attribute access error for a.temp";

    # Not callable errors
    assert 'Type "_T1" is not callable' in all_errors , "Expected callable error for a(3)";

    # Not subscriptable errors
    assert 'Type "_T1" is not subscriptable' in all_errors , "Expected subscript error for a[0]";

    # Binary operator errors
    assert 'Operator "__add__' in all_errors
    and 'not supported for type' in all_errors , "Expected binary op error for a + 1";

    # Unary operator errors
    assert 'Operator "__neg__' in all_errors
    and 'not supported for type' in all_errors , "Expected unary op error for -a";

    # Await errors
    assert 'Type "_T1" is not awaitable' in all_errors , "Expected await error for await a";

    # Iteration errors
    assert 'Type "_T1" is not iterable' in all_errors , "Expected iteration error for for _ in a";
}

"""Test bounded TypeVar operation validation (Pyright: typeVar6)."""
test "typevar6_bounded_operations" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar6.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # func1 (_T1, bound=Foo): var2 missing, wrong call arg type, no subscript,
    # no binary op, no unary op, no aug-assign, no await, no iter, no do_other_stuff
    # = 9 errors
    assert 'Cannot access attribute "var2"' in all_errors , "Expected attribute error for a.var2 (Foo has no var2)";
    assert 'is not subscriptable' in all_errors , "Expected subscript error for a[0]";
    assert 'is not awaitable' in all_errors , "Expected await error for await a";
    assert 'is not iterable' in all_errors , "Expected iteration error for for _ in a";
    assert 'Cannot access attribute "do_other_stuff"' in all_errors , "Expected error for a.do_other_stuff() on Foo-bounded T1";
}

"""Test constrained TypeVar operation validation."""
test "typevar7_constrained_operations" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar7.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # Key TypeVar-related errors to verify (constraints check each type)
    # Attribute access - Foo doesn't have var2
    assert 'Cannot access attribute "var2" for type "Foo"' in all_errors , "Expected attribute error for a.var2 (Foo has no var2)";

    # Subscript - neither Foo nor Bar is subscriptable
    assert 'is not subscriptable' in all_errors , "Expected subscript error for a[0]";

    # Unary operator - neither Foo nor Bar supports __neg__
    assert '__neg__' in all_errors and 'not supported' in all_errors , "Expected unary op error for -a";

    # Await - neither Foo nor Bar is awaitable
    assert 'is not awaitable' in all_errors , "Expected await error for await a";

    # Iteration - neither Foo nor Bar is iterable
    assert 'is not iterable' in all_errors , "Expected iteration error for for _ in a";

    # Method access - Foo doesn't have do_other_stuff
    assert 'Cannot access attribute "do_other_stuff" for type "Foo"' in all_errors , "Expected error for a.do_other_stuff() on Foo constraint";
}

"""Test that ParamSpec and TypeVarTuple in Callable annotations produce no false E1071 errors."""
test "paramspec_callable_no_false_e1071" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "paramspec.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    errors = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(errors);

    e1071_errors = [
        e
        for e in errors
        if "E1071" in e
    ];
    assert len(e1071_errors) == 0 , f"Expected no E1071 errors for Callable[P, T], got:\n{all_errors}";
}

"""Test constrained TypeVars with ellipsis stub bodies (Pyright: typeVar10.py)."""
test "typevar10_ellipsis_stub_no_error" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar10.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    errors = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(errors);

    # Ellipsis-only stub methods should not trigger E1004
    e1004_errors = [
        e
        for e in errors
        if "E1004" in e
    ];
    assert len(e1004_errors) == 0 , f"Expected no E1004 for ellipsis stubs, got:\n{all_errors}";
}

"""Test that module-level dunder variables (__name__, __file__, etc.) type-check cleanly."""
test "module_dunders_no_errors" {
    program = JacProgram();
    mod = program.compile(os.path.join(CHECKER_FIXTURES, "module_dunders.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    errors = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(errors);

    assert len(program.errors_had) == 0 , f"Expected no errors for module dunder variables, got:\n{all_errors}";
}
