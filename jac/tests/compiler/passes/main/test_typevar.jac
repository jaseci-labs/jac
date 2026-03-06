"""TypeVar validation tests for the type checker."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     TYPEVAR_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker", "typevar"
     );

"""Test TypeVar validation errors (Pyright: createTypeVarType, assignTypeToExpression)."""
test "typevar1_validation_errors" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar1.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    assert len(program.errors_had) == 3,
        f"Expected 3 errors, got {len(program.errors_had)}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    assert 'TypeVar name "T3 ' in all_errors and 'must match' in all_errors,
        "Expected name mismatch error for T2 = TypeVar('T3')";
    assert 'must be assigned to a simple variable' in all_errors,
        "Expected index expression error for my_dict['var'] = TypeVar('T5')";
    assert 'requires at least two constrained types' in all_errors,
        "Expected single constraint error for TypeVar('T5', str)";
}

"""Test TypeVar scope validation (Pyright: validateTypeVarUsage, enforceClassTypeVarScope)."""
test "typevar3_scope_validation" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar3.jac"));
    TypeCheckPass(ir_in=mod, prog=program);

    # Should match Pyright's 12 errors exactly
    assert len(program.errors_had) == 12,
        f"Expected 12 errors, got {len(program.errors_had)}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # "already in use by outer scope" errors (declaration-site)
    assert 'TypeVar "_T" is already in use by an outer scope' in all_errors,
        "Expected outer scope error for InnerClass1(Generic[_T])";
    assert 'TypeVar "AnyStr" is already in use by an outer scope' in all_errors,
        "Expected outer scope error for InnerClass2(Generic[_S, AnyStr])";

    # "has no meaning in this context" errors (use-site)
    assert 'Type variable "_S" has no meaning in this context' in all_errors,
        "Expected scope error for _S used in OuterClass without being in Generic[]";
    assert 'Type variable "_T" has no meaning in this context' in all_errors,
        "Expected scope error for _T used in nested non-generic class";
}
