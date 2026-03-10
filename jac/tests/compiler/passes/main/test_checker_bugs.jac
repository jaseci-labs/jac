"""Regression tests for previously-identified bugs and soundness issues in the Jac type checker.

Each test documents behavior that was buggy and has since been fixed.
They now serve as regression guards to prevent re-introduction of these bugs.

Bug index:
  #1  - 'is'/'in' operators return UnknownType (missing return)
  #3  - List element type inference only considers first element
  #6  - MRO linearization is not C3 (diamond inheritance)
  #7  - Protocol checking compares only method names, not signatures
  #8  - DictVal/TupleVal/SetVal have no type inference
  #11 - BoolExpr (and/or) always returns last operand's type
  #12 - CompareExpr has no handler (returns UnknownType)
  #13 - IfExpr (ternary) has no handler (returns UnknownType)
  #15 - No generic type argument checking (list[int] -> list[str])
  #21 - _get_method_with_overloads doesn't specialize the base method
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.type_system.type_utils { compute_mro_linearization }
import from jaclang.compiler.type_system.types { ClassType, TypeFlags }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker"
     );

"""Compile a checker fixture and run the type check pass."""
def compile_and_check(fixture_name: str) -> JacProgram {
    program = JacProgram();
    mod = program.compile(os.path.join(CHECKER_FIXTURES, fixture_name));
    TypeCheckPass(ir_in=mod, prog=program);
    return program;
}

# =========================================================================
# Bug #1: 'is'/'in' operators return UnknownType instead of bool
#
# In operations.jac:141-142, the bool result is computed but not returned:
#   evaluator._convert_to_instance(evaluator.prefetch.bool_class);
# This discards the result and falls through to UnknownType.
#
# Impact: `x is y` and `x in y` are typed as Unknown, so type errors
#         involving these expressions are silently missed.
# =========================================================================
test "bug_1_is_in_returns_unknown_type" {
    program = compile_and_check("checker_bug_is_in_returns_unknown.jac");

    # Expected: 4 errors (assigning bool to str for is/is_not/in/not_in)
    # Actual: 0 errors (all expressions are UnknownType, assignable to anything)
    assert len(program.errors_had) == 4 , f"Bug #1: 'is'/'in' operators return UnknownType instead of bool. "
    f"Expected 4 type errors but got {len(program.errors_had)}. "
    f"The missing 'return' in operations.jac:141 causes bool results to be discarded.";
}

# =========================================================================
# Bug #3: List element type inference only uses the first element
#
# In type_evaluator.impl.jac:99-112, the ListVal handler breaks after
# the first ClassType element, ignoring heterogeneous list contents.
#
# Impact: [1, "hello"] is typed as list[int] instead of list[int|str]
# =========================================================================
test "bug_3_list_element_type_first_only" {
    program = compile_and_check("checker_bug_list_elem_type.jac");

    # Expected: at least 1 error (list[int|str] not assignable to list[int])
    # Actual: 0 errors (list inferred as list[int], so list[int] -> list[int] is ok)
    assert len(program.errors_had) >= 1 , f"Bug #3: List element type inference only considers the first element. "
    f"Expected at least 1 type error for mixed list assignment but got {len(
        program.errors_had
    )}. "
    f"[1, 'hello'] is typed as list[int] instead of list[int | str].";
}

# =========================================================================
# Bug #6: MRO linearization is not C3
#
# The compute_mro_linearization function uses simple DFS dedup instead
# of the C3 linearization algorithm. For diamond inheritance:
#   A <- B <- D and A <- C <- D
# Python C3 gives: [D, B, C, A, object]
# Buggy DFS gives: [D, B, A, object, C] (A appears before C)
# =========================================================================
test "bug_6_mro_not_c3_diamond" {
    # Build a diamond hierarchy manually to check MRO order
    a_shared = ClassType.ClassDetailsShared(
        class_name="A", symbol_table=None, mro=[], base_classes=[]
    );
    a_type = ClassType(shared=a_shared, flags=TypeFlags.Instantiable);
    a_type.shared.mro = [a_type];

    b_shared = ClassType.ClassDetailsShared(
        class_name="B", symbol_table=None, mro=[], base_classes=[a_type]
    );
    b_type = ClassType(shared=b_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(b_type);

    c_shared = ClassType.ClassDetailsShared(
        class_name="C", symbol_table=None, mro=[], base_classes=[a_type]
    );
    c_type = ClassType(shared=c_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(c_type);

    d_shared = ClassType.ClassDetailsShared(
        class_name="D", symbol_table=None, mro=[], base_classes=[b_type, c_type]
    );
    d_type = ClassType(shared=d_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(d_type);

    mro_names = [cls.shared.class_name for cls in d_type.shared.mro];

    # Python C3 MRO: [D, B, C, A]
    # Buggy DFS MRO: [D, B, A, C] (A before C)
    expected_c3 = ["D", "B", "C", "A"];

    assert mro_names == expected_c3 , f"Bug #6: MRO is not C3 linearized. "
    f"Expected {expected_c3} but got {mro_names}. "
    f"In diamond inheritance, C should come before A in the MRO.";
}

# =========================================================================
# Bug #7: Protocol checking only compares method names, not signatures
#
# class_implements_protocol checks proto_method_names.issubset(cls_method_names)
# but never verifies parameter types, return types, or arity.
#
# Impact: A class with def draw(x: int) -> str satisfies a protocol
#         requiring def draw(canvas: str) -> None
# =========================================================================
test "bug_7_protocol_name_only_check" {
    program = compile_and_check("checker_bug_protocol_signature.jac");

    # Expected: 1 error (WrongSignature.draw has wrong param/return types)
    # Actual: 0 errors (protocol check only validates method names exist)
    assert len(program.errors_had) >= 1 , f"Bug #7: Protocol conformance only checks method names, not signatures. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"WrongSignature.draw(int)->str should not satisfy Drawable.draw(str)->None.";
}

# =========================================================================
# Bug #8: DictVal, TupleVal, SetVal have no type inference
#
# _get_type_of_expression_core has no case for these AST node types,
# so they fall through and return UnknownType.
#
# Impact: All type errors involving dict/tuple/set literals are missed.
# =========================================================================
test "bug_8_dict_tuple_set_return_unknown" {
    program = compile_and_check("checker_bug_dict_tuple_set_unknown.jac");

    # Expected: 3 errors (dict->str, tuple->str, set->str assignments)
    # Actual: 0 errors (all literals are UnknownType, assignable to anything)
    assert len(program.errors_had) == 3 , f"Bug #8: Dict/tuple/set literals return UnknownType. "
    f"Expected 3 type errors but got {len(program.errors_had)}. "
    f"No case handlers exist for DictVal, TupleVal, SetVal in the evaluator.";
}

# =========================================================================
# Bug #11: BoolExpr (and/or) always returns the last operand's type
#
# Python: `x and y` has type Union[type(x), type(y)]
# Current: always returns operand_types[-1] (last operand)
#
# Impact: `get_str() and get_int()` is typed as int, losing str info
# =========================================================================
test "bug_11_bool_expr_last_operand_only" {
    program = compile_and_check("checker_bug_bool_expr_type.jac");

    # `get_str() and get_int()` should have type str|int (Python semantics).
    # With the bug, it has type int (last operand only).
    #
    # check_and_int: int = result_and  -- should Error (str|int -> int invalid)
    # check_or_int: int = result_or   -- should Error (str|int -> int invalid)
    #
    # With the bug: both pass because result is typed as int (last operand).
    # Expected: 2 errors. Actual: 0 errors.
    assert len(program.errors_had) == 2 , f"Bug #11: BoolExpr returns last operand type only. "
    f"Expected 2 type errors but got {len(program.errors_had)}. "
    f"'x and y' should be typed as type(x) | type(y), not just type(y).";
}

# =========================================================================
# Bug #12: CompareExpr has no handler — returns UnknownType
#
# There is no `case uni.CompareExpr()` in _get_type_of_expression_core.
# Comparison operators (< > <= >= == !=) should return bool.
#
# Impact: Type errors involving comparison results go undetected.
# =========================================================================
test "bug_12_compare_returns_unknown" {
    program = compile_and_check("checker_bug_compare_returns_unknown.jac");

    # Expected: 2 errors (assigning comparison bool to str)
    # Actual: 0 errors (comparisons return UnknownType)
    assert len(program.errors_had) == 2 , f"Bug #12: CompareExpr returns UnknownType instead of bool. "
    f"Expected 2 type errors but got {len(program.errors_had)}. "
    f"No case handler exists for CompareExpr in _get_type_of_expression_core.";
}

# =========================================================================
# Bug #13: IfExpr (ternary) has no handler — returns UnknownType
#
# The expression `x if cond else y` has no case in the evaluator.
# It should return the union of the two branch types.
#
# Impact: Ternary expression results lose all type information.
# =========================================================================
test "bug_13_ternary_returns_unknown" {
    program = compile_and_check("checker_bug_ternary_missing.jac");

    # Expected: 1 error (int|str not assignable to int for mixed ternary)
    # Actual: 0 errors (ternary returns UnknownType)
    #
    # Note: even check1: str = r1 and check3: str = ... should be ok,
    # but they won't produce errors either way since Unknown is assignable
    # to everything. The bug is that check2 should error but doesn't.
    assert len(program.errors_had) >= 1 , f"Bug #13: IfExpr (ternary) returns UnknownType. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"No case handler exists for IfExpr in _get_type_of_expression_core.";
}

# =========================================================================
# Bug #15: No generic type argument checking in class assignment
#
# _assign_class checks `src_type.shared == dest_type.shared` (same class)
# but never validates that type arguments are compatible.
#
# Impact: list[int] is assignable to list[str], which is unsound.
# =========================================================================
test "bug_15_no_generic_variance_check" {
    program = compile_and_check("checker_bug_no_generic_variance.jac");

    # Expected: 2 errors (list[int] not assignable to list[str])
    # Actual: 0 errors (same ClassType.shared means assignable)
    assert len(program.errors_had) >= 1 , f"Bug #15: No generic type argument checking. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"list[int] should NOT be assignable to list[str].";
}
