"""Production-grade type checker gap test suite.

These tests document concrete gaps that must be closed for the type
checker to reach production quality. Each test is expected to FAIL
under the current implementation.

Categories:
  A. Comprehension Type Inference (A1-A2)
     — dict/set comprehension parameterized type inference
  B. UnknownType Discipline (B1-B7)
     — Unknown must not silently pass assignments, method calls, propagation,
       function args, returns, or conditionals
     — B7: omitted return annotation must infer None, not Unknown

Note: Generic TypeVar binding (gap #38), basic list comprehension inference
(shortcoming #24), and basic lambda inference (shortcoming #26) are already
covered in test_checker_gaps.jac and test_checker_shortcomings.jac.
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
#  A. COMPREHENSION & LAMBDA TYPE INFERENCE
#
#  A production type checker must infer correct element types for
#  comprehensions and callable types for lambdas. Dict and set
#  comprehensions must infer parameterized types (dict[K,V], set[T]),
#  not just the base container type.
# =========================================================================

# -------------------------------------------------------------------------
# A1: Dict comprehension parameterized type inference
# -------------------------------------------------------------------------
test "prod a1 dict compr type" {
    program = compile_and_check("checker_prod_dict_compr_type.jac");

    # {k: v for ...} must infer as dict[K, V], not just dict
    assert len(program.errors_had) >= 3 , f"A1: Dict comprehension type inference failed. "
    f"Expected >= 3 errors but got {len(program.errors_had)}. "
    f"Dict comprehensions must infer key/value types, not Unknown.";
}

# -------------------------------------------------------------------------
# A2: Set comprehension parameterized type inference
# -------------------------------------------------------------------------
test "prod a2 set compr type" {
    program = compile_and_check("checker_prod_set_compr_type.jac");

    # {x * 2 for x in nums} must infer as set[int], not just set
    assert len(program.errors_had) >= 2 , f"A2: Set comprehension type inference failed. "
    f"Expected >= 2 errors but got {len(program.errors_had)}. "
    f"Set comprehensions must infer element type, not Unknown.";
}

# =========================================================================
#  B. UNKNOWNTYPE DISCIPLINE
#
#  A production type checker must NOT treat UnknownType as a universal
#  "any" type that silently accepts all operations. When type inference
#  fails and produces Unknown, the checker must either:
#    (a) Report a diagnostic (error or warning) about lost type info, or
#    (b) At minimum, not suppress downstream type errors.
#
#  These tests verify that Unknown does not create silent type holes.
# =========================================================================

# -------------------------------------------------------------------------
# B1: Unknown must not silently assign to typed variables
# -------------------------------------------------------------------------
test "prod b1 unknown assign" {
    program = compile_and_check("checker_prod_unknown_assign.jac");

    # Assigning Unknown to int, str, list, bool, float should warn/error
    assert len(program.errors_had) >= 3 , f"B1: Unknown silently assigned to typed variables. "
    f"Expected >= 3 errors/warnings but got {len(program.errors_had)}. "
    f"Unknown must not be a universal 'any' type that accepts all assignments.";
}

# -------------------------------------------------------------------------
# B2: Method calls on Unknown must not silently pass
# -------------------------------------------------------------------------
test "prod b2 unknown method call" {
    program = compile_and_check("checker_prod_unknown_method_call.jac");

    # .nonexistent(), .append(), .upper(), [0] on Unknown should error
    assert len(program.errors_had) >= 3 , f"B2: Method calls on Unknown silently pass. "
    f"Expected >= 3 errors but got {len(program.errors_had)}. "
    f"Calling .nonexistent() on Unknown must not silently succeed.";
}

# -------------------------------------------------------------------------
# B3: Unknown must not propagate silently through expressions
# -------------------------------------------------------------------------
test "prod b3 unknown propagation" {
    program = compile_and_check("checker_prod_unknown_propagation.jac");

    # Unknown + 1, Unknown + "hello", -Unknown should not silently produce Unknown
    assert len(program.errors_had) >= 3 , f"B3: Unknown propagates silently through expressions. "
    f"Expected >= 3 errors but got {len(program.errors_had)}. "
    f"Arithmetic/string ops on Unknown must not silently produce more Unknown.";
}

# -------------------------------------------------------------------------
# B4: Unknown passed to typed function parameters must be flagged
# -------------------------------------------------------------------------
test "prod b4 unknown function arg" {
    program = compile_and_check("checker_prod_unknown_function_arg.jac");

    # Passing Unknown to int, str, list[int] params should error
    assert len(program.errors_had) >= 3 , f"B4: Unknown passed to typed function params silently. "
    f"Expected >= 3 errors but got {len(program.errors_had)}. "
    f"Unknown must not be silently accepted as int, str, or list[int] argument.";
}

# -------------------------------------------------------------------------
# B5: Functions returning Unknown where typed return is declared
# -------------------------------------------------------------------------
test "prod b5 unknown return" {
    program = compile_and_check("checker_prod_unknown_return.jac");

    # Returning Unknown where int or str is declared should error
    assert len(program.errors_had) >= 3 , f"B5: Unknown returned where typed return is declared. "
    f"Expected >= 3 errors but got {len(program.errors_had)}. "
    f"Returning Unknown for declared -> int or -> str must produce a diagnostic.";
}

# -------------------------------------------------------------------------
# B6: Unknown in conditionals must not bypass narrowing
# -------------------------------------------------------------------------
test "prod b6 unknown conditional" {
    program = compile_and_check("checker_prod_unknown_conditional.jac");

    # isinstance on Unknown, ternary with Unknown must produce errors
    assert len(program.errors_had) >= 2 , f"B6: Unknown bypasses conditional type narrowing. "
    f"Expected >= 2 errors but got {len(program.errors_had)}. "
    f"isinstance() on Unknown must narrow or flag, not silently accept.";
}

# -------------------------------------------------------------------------
# B7: Omitted return annotation must infer None, not Unknown
#
# In Jac, omitting the return type annotation is equivalent to -> None.
# This is a deliberate syntax design decision for cleaner function
# signatures. The type checker must NOT assign UnknownType to these
# functions — it must treat them as returning None.
# -------------------------------------------------------------------------
test "prod b7 no return annotation is none" {
    program = compile_and_check("checker_prod_no_return_annotation_is_none.jac");

    # side_effect() and Foo.mutate() have no return annotation -> None.
    # Assigning their result to int/str/list must error.
    assert len(program.errors_had) >= 4 , f"B7: Omitted return annotation infers Unknown instead of None. "
    f"Expected >= 4 errors but got {len(program.errors_had)}. "
    f"Functions without return annotation must be -> None, not Unknown. "
    f"Currently construct_types.impl.jac defaults to UnknownType.";
}
