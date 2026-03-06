"""Tests exposing known shortcomings in the Jac type checker.

These tests document incomplete type checking behavior that should
be addressed in future improvements. Each test is expected to FAIL
under the current implementation, confirming the shortcoming exists.

Shortcoming index:
  #22 - No type checking on destructuring RHS (non-iterable accepted)
  #23 - set is assignable to frozenset (unsound mutability coercion)
  #24 - List comprehensions return UnknownType
  #25 - Dict comprehensions return UnknownType
  #26 - Lambda expressions return UnknownType
  #30 - Try/except does not narrow exception types
  #31 - With statement does not check context manager protocol
  #33 - For loop does not check iterability of target expression
  #34 - Functions with non-None return type can implicitly return None
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker"
     );

def compile_and_check(fixture_name: str) -> JacProgram {
    """Compile a checker fixture and run the type check pass."""
    program = JacProgram();
    mod = program.compile(os.path.join(CHECKER_FIXTURES, fixture_name));
    TypeCheckPass(ir_in=mod, prog=program);
    return program;
}

# =========================================================================
# Shortcoming #22: No type checking on destructuring RHS
# =========================================================================
test "shortcoming_22_destructure_non_iterable" {
    program = compile_and_check("checker_bug_destructure_non_iterable.jac");

    # Expected: 3 errors (int, bool, NoneType are not iterable)
    assert len(program.errors_had) >= 3 , f"#22: No type checking on destructuring RHS. "
    f"Expected at least 3 type errors but got {len(program.errors_had)}. "
    f"'(a, b) = 5' should error because int is not iterable.";
}

# =========================================================================
# Shortcoming #23: set is assignable to frozenset without error
# =========================================================================
test "shortcoming_23_set_to_frozenset_unsound" {
    program = compile_and_check("checker_bug_set_to_frozenset.jac");

    # Expected: 2 errors (set not assignable to frozenset)
    assert len(program.errors_had) >= 2 , f"#23: set assignable to frozenset. "
    f"Expected at least 2 type errors but got {len(program.errors_had)}. "
    f"set should NOT be assignable to frozenset (different mutability).";
}

# =========================================================================
# Shortcoming #24: List comprehensions return UnknownType
#
# No case for ListCompr in _get_type_of_expression_core.
# Impact: [x*2 for x in nums] is typed as Unknown, not list[int].
# =========================================================================
test "shortcoming_24_list_compr_unknown" {
    program = compile_and_check("checker_bug_list_compr_unknown.jac");

    # Expected: at least 1 error (list assigned to str)
    assert len(program.errors_had) >= 1 , f"#24: List comprehensions return UnknownType. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"[x*2 for x in nums] should infer as list, not Unknown.";
}

# =========================================================================
# Shortcoming #25: Dict comprehensions return UnknownType
#
# No case for DictCompr in _get_type_of_expression_core.
# =========================================================================
test "shortcoming_25_dict_compr_unknown" {
    program = compile_and_check("checker_bug_dict_compr_unknown.jac");

    # Expected: 1 error (dict assigned to str)
    assert len(program.errors_had) >= 1 , f"#25: Dict comprehensions return UnknownType. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"Dict comprehensions should infer as dict, not Unknown.";
}

# =========================================================================
# Shortcoming #26: Lambda expressions return UnknownType
#
# No case for LambdaExpr in _get_type_of_expression_core.
# Impact: Lambda return types and parameter types are never checked.
# =========================================================================
test "shortcoming_26_lambda_unknown" {
    program = compile_and_check("checker_bug_lambda_unknown.jac");

    # Expected: at least 1 error (callable assigned to str, or wrong return type)
    assert len(program.errors_had) >= 1 , f"#26: Lambda expressions return UnknownType. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"Lambda should infer as callable, not Unknown.";
}

# =========================================================================
# Shortcoming #30: Try/except does not narrow exception types
#
# No exit_try_stmt or exception narrowing in type checker.
# Impact: Exception variables in except blocks are untyped.
# =========================================================================
test "shortcoming_30_try_except_no_narrowing" {
    program = compile_and_check("checker_bug_try_except_no_narrowing.jac");

    # Expected: at least 1 error (ValueError assigned to int, or raise non-exception)
    assert len(program.errors_had) >= 1 , f"#30: Try/except has no exception type narrowing. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"'except ValueError as e:' should narrow e to ValueError.";
}

# =========================================================================
# Shortcoming #31: With statement does not check context manager protocol
#
# No exit_with_stmt method. Objects in `with` blocks are not validated
# as context managers, and `as` variables get no __enter__ return type.
# =========================================================================
test "shortcoming_31_with_stmt_no_check" {
    program = compile_and_check("checker_bug_with_stmt_no_check.jac");

    # Expected: at least 1 error (int is not a context manager, or file assigned to int)
    assert len(program.errors_had) >= 1 , f"#31: With statement does not check context managers. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"'with 42 as x:' should error because int is not a context manager.";
}

# =========================================================================
# Shortcoming #33: For loop does not check iterability of target
#
# The type checker does not verify that the expression in `for x in expr`
# is actually iterable. Non-iterable values produce no error.
# =========================================================================
test "shortcoming_33_for_iter_type" {
    program = compile_and_check("checker_bug_for_iter_type.jac");

    # Expected: 2 errors (int and bool are not iterable)
    assert len(program.errors_had) >= 2 , f"#33: For loop does not check iterability. "
    f"Expected at least 2 type errors but got {len(program.errors_had)}. "
    f"'for x in 42:' should error because int is not iterable.";
}

# =========================================================================
# Shortcoming #34: Functions with non-None return type can return None
#
# The type checker validates explicit return statements but does not
# verify that all code paths return a value. A function declared as
# `-> int` can fall off the end without returning.
# =========================================================================
test "shortcoming_34_return_none_implicit" {
    program = compile_and_check("checker_bug_return_none_implicit.jac");

    # Expected: 2 errors (maybe_return and always_missing can implicitly return None)
    assert len(program.errors_had) >= 2 , f"#34: Missing return not detected. "
    f"Expected at least 2 type errors but got {len(program.errors_had)}. "
    f"Functions declared -> int should error if they can return None.";
}
