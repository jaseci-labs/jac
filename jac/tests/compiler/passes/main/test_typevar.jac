"""TypeVar validation tests for the type checker."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
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

    assert 'TypeVar name "T3 ' in all_errors and 'must match' in all_errors , "Expected name mismatch error for T2 = TypeVar('T3')";
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
