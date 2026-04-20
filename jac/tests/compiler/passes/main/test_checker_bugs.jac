"""Regression tests for previously-identified bugs and soundness issues in the Jac type checker.

Each test documents behavior that was buggy and has since been fixed.
They now serve as regression guards to prevent re-introduction of these bugs.

Bug index:
  #1      - 'is'/'in' operators return UnknownType (missing return)
  #3      - List element type inference only considers first element
  #6      - MRO linearization is not C3 (diamond inheritance)
  #7      - Protocol checking compares only method names, not signatures
  #8      - DictVal/TupleVal/SetVal have no type inference
  #11     - BoolExpr (and/or) always returns last operand's type
  #12     - CompareExpr has no handler (returns UnknownType)
  #13     - IfExpr (ternary) has no handler (returns UnknownType)
  #15     - No generic type argument checking (list[int] -> list[str])
  #21     - _get_method_with_overloads doesn't specialize the base method
  #22     - Tuple unpacking in for loops returns UnknownType
  #23     - With statement alias typed as Unknown (wrong traversal order)
  #ANY-1  - typing.Any attribute access incorrectly raises E1030
  #FINAL-1 - Final[T] not unwrapped for attribute access
  #TVAR-1 - Duplicate TypeVars in _extract_type_params cause positional mismatch
  #TVAR-2 - No transitive TypeVar propagation through base_classes in build_type_var_solution
  #TVAR-3 - Union return types with TypeVars (e.g., V | None) resolve to Unknown
  #TVAR-5 - Module-level TypeVars shadowed by class type parameters
  #IMPL-1 - Has var reassigned in impl body loses its type (shadow local)
  #BASE-1 - Base class name resolved in class's own scope (should be enclosing)
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
    a_type = ClassType(_shared=a_shared, flags=TypeFlags.Instantiable);
    a_type.shared.mro = [a_type];

    b_shared = ClassType.ClassDetailsShared(
        class_name="B", symbol_table=None, mro=[], base_classes=[a_type]
    );
    b_type = ClassType(_shared=b_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(b_type);

    c_shared = ClassType.ClassDetailsShared(
        class_name="C", symbol_table=None, mro=[], base_classes=[a_type]
    );
    c_type = ClassType(_shared=c_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(c_type);

    d_shared = ClassType.ClassDetailsShared(
        class_name="D", symbol_table=None, mro=[], base_classes=[b_type, c_type]
    );
    d_type = ClassType(_shared=d_shared, flags=TypeFlags.Instantiable);
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

# =========================================================================
# Bug #23: With statement alias typed as Unknown
#
# In `with open(...) as f`, the alias `f` was typed as Unknown because
# the type binding happened in exit_with_stmt (after the body was visited)
# instead of enter_with_stmt (before the body was visited).
#
# Impact: `f.write()` fails with "Type is Unknown, cannot access attribute"
# =========================================================================
test "bug_23_with_stmt_alias_unknown" {
    program = compile_and_check("checker_bug_with_stmt_alias_unknown.jac");

    # Expected: 1 error (TextIOWrapper not assignable to int)
    # With the bug: different error (Unknown cannot access "write")
    assert len(program.errors_had) == 1 , f"Bug #23: With statement alias typed as Unknown. "
    f"Expected 1 type error but got {len(program.errors_had)}. "
    f"'with open(...) as f' should type f as TextIOWrapper, not Unknown.";
}

# Bug #22: Tuple unpacking in for loops returns UnknownType
#
# When iterating with destructuring like `for (a, b, c) in items`, the
# type checker only handled tuple unpacking for Assignment targets, not
# for InForStmt/InnerCompr targets.
#
# In type_evaluator.impl.jac, the Name case checked if the grandparent
# was Assignment but not InForStmt, so unpacked variables got UnknownType.
#
# Impact: `for (x, y) in list[tuple[A, B]]` types x and y as Unknown,
#         missing all type errors involving these variables.
# =========================================================================
test "bug_22_tuple_unpack_for_loop_unknown" {
    program = compile_and_check("checker_bug_tuple_unpack_for_loop.jac");

    # Expected errors:
    #   - bad1: int = s (str -> int)
    #   - bad2: str = n (int -> str)
    #   - bad3: str = f (Foo -> str)
    #   - bad_name: int = names[0] (str -> int)
    #   - c: str = num (int -> str)
    # Total: 5 errors
    #
    # With the bug: 0 errors (all unpacked vars are UnknownType)
    assert len(program.errors_had) == 5 , f"Bug #22: Tuple unpacking in for loops returns UnknownType. "
    f"Expected 5 type errors but got {len(program.errors_had)}. "
    f"for (a, b) in list[tuple[A, B]] should type a as A and b as B.";
}

# =========================================================================
# Bug #ANY-1: typing.Any attribute access incorrectly raises E1030
#
# TypeBase.is_any_type() missed ClassType-wrapped typing.Any.
# E1030 guards called lookup_type.is_any_type() (simple) instead of
# self.is_any_type() (TypeEvaluator, checks prefetch.any_class).
# =========================================================================
test "bug_any1_typing_any_attr_access" {
    program = compile_and_check("checker_bug_typing_any_attr.jac");
    # Expect 1 error: object.nonexistent (object does not allow arbitrary attr access)
    # Any still allows all attribute access (0 errors for Any tests)
    assert len(program.errors_had) == 1 , f"Bug #ANY-1: Expected 1 error (object.nonexistent), "
    f"got {len(
        program.errors_had
    )} errors. Any must allow all attribute access, but object must not.";
    # Verify the error is for object.nonexistent, not for Any
    err_str = program.errors_had[0].pretty_print();
    assert "nonexistent" in err_str , f"Expected error for 'nonexistent' attr, got: {err_str}";
    assert "object" in err_str , f"Expected error mentioning 'object' type, got: {err_str}";
}

# =========================================================================
# Bug #FINAL-1: Final[T] not unwrapped for attribute access
#
# Member lookup ran against Final instead of T, so Final[list[int]].count
# raised E1030. Unwrapping existed for assignment checks but not attr access.
# =========================================================================
test "bug_final1_final_unwrap_for_attr_access" {
    program = compile_and_check("checker_bug_final_unwrap_attr.jac");
    assert len(program.errors_had) == 0 , f"Bug #FINAL-1: attribute access on Final[T] raised E1030 "
    f"({len(program.errors_had)} errors). Final[T] must unwrap to T for member lookup.";
}

# =========================================================================
# Bug #TVAR-1: Duplicate TypeVars in _extract_type_params
#
# When a class inherits from multiple generic bases with overlapping TypeVars
# (e.g., BaseMapping(BaseCollection[K], Generic[K, V])), _extract_type_params
# collected K twice, producing type_params=[K, K, V]. This caused positional
# mismatches when mapping type_params to type_args during specialization,
# leaving V unresolved -> Unknown.
#
# Fix: Deduplicate TypeVars by name in _extract_type_params, preserving
# first-occurrence order (matching Python's typing module behavior).
#
# Impact: Methods returning TypeVars from multi-base generic classes had
#         Unknown return types, suppressing legitimate type errors.
# =========================================================================
test "bug_tvar1_typevar_dedup_in_extract_type_params" {
    program = compile_and_check("checker_bug_typevar_dedup.jac");

    # Expected: 1 error (int not assignable to str for `bad: str = m.lookup("key")`)
    # Without fix: 0 errors (V is Unknown, assignable to anything)
    assert len(program.errors_had) >= 1 , f"Bug #TVAR-1: _extract_type_params duplicates TypeVars from "
    f"multiple generic bases, causing positional mismatch. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"Without dedup, V in BaseMapping(BaseCollection[K], Generic[K, V]) is unresolved.";
}

# =========================================================================
# Bug #TVAR-2: No transitive TypeVar propagation in build_type_var_solution
#
# build_type_var_solution only checked MRO entries for type_args (which are
# unspecialized), missing the parameterized base_classes chain. When a class
# like ChildMap[str, int] inherits MiddleMap[K, V] which inherits
# BaseReader[K, V2], the TypeVar V2 was never mapped to V -> int.
#
# Fix: Added a phase in build_type_var_solution that walks each MRO entry's
# base_classes to propagate TypeVar bindings transitively.
#
# Impact: Methods inherited from grandparent+ generic classes had Unknown
#         return types when TypeVars were renamed across inheritance levels.
# =========================================================================
test "bug_tvar2_transitive_typevar_propagation" {
    program = compile_and_check("checker_bug_typevar_transitive.jac");

    # Expected: 1 error (int not assignable to str for `bad: str = c.read("key")`)
    # Without fix: 0 errors (V2 is Unknown, assignable to anything)
    assert len(program.errors_had) >= 1 , f"Bug #TVAR-2: build_type_var_solution doesn't propagate TypeVars "
    f"through base_classes chain. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"Without transitive propagation, V2 in BaseReader is unresolved.";
}

# =========================================================================
# Bug #TVAR-3: Union return types with TypeVars resolve to Unknown
#
# When a generic method returns V | None (a union containing a TypeVar),
# the BinaryExpr with BW_OR operator was evaluated by operations.jac which
# checked is_any_type() on both operands BEFORE handling the union case.
# Since TypeVarType.is_any_type() returns True, the function short-circuited
# to UnknownType, and the union handler at line 276 was never reached.
#
# Fix: Move the BW_OR union-type check before the is_any_type() early return
# and extend is_annotation_type() to recognize TypeVarType as valid.
#
# Impact: dict.get(), Optional-returning methods on generic classes, and any
#         typeshed stub with `-> TypeVar | None` had Unknown return types.
# =========================================================================
test "bug_tvar3_typevar_union_return_type" {
    program = compile_and_check("checker_bug_typevar_union_return.jac");

    # Expected: 1 error (int | None not assignable to str for `bad: str = s.lookup("key")`)
    # Without fix: 0 errors (V | None is Unknown, assignable to anything)
    assert len(program.errors_had) >= 1 , f"Bug #TVAR-3: Union return types with TypeVars (V | None) resolve "
    f"to Unknown due to is_any_type() short-circuit in operations.jac. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    f"Without the fix, dict.get() and similar methods return Unknown.";
}

# =========================================================================
# Bug #TVAR-4: Generic[] base class must establish canonical TypeVar order
# =========================================================================
# Root cause: _extract_type_params processed base classes left-to-right and
# deduplicated by name. For dict_values(ValuesView[_VT_co], Generic[_KT_co,
# _VT_co]), _VT_co was encountered first (from ValuesView), producing
# type_params = [_VT_co, _KT_co]. The correct order per PEP 484 is
# [_KT_co, _VT_co] from the Generic[] declaration, which is the authoritative
# source. Wrong ordering swaps key/value types in dict.keys()/values().
#
# Impact: dict.values() yielded key types instead of value types, and
#         dict.keys() yielded value types instead of key types, for any
#         dict-like class whose typeshed stub lists Generic[] after other
#         parameterized bases.
# =========================================================================
test "bug_tvar4_generic_base_canonical_typevar_order" {
    program = compile_and_check("checker_bug_typevar_generic_order.jac");

    # Expected: 2 errors on the `bad` lines (24 and 30), NOT on the `good` lines (23 and 29).
    # Without fix: 2 errors on the WRONG lines (23 and 30) because key/value types are swapped,
    # so a count-only check would still pass — we must verify the error locations.
    assert len(program.errors_had) >= 2 , f"Bug #TVAR-4: Generic[] base must set canonical TypeVar order. "
    f"Expected at least 2 type errors but got {len(program.errors_had)}.";

    # Verify errors are on the `bad` assignment lines, not the `good` ones.
    # Line 24: `bad: int = v` should error (v is str from values())
    # Line 30: `bad2: str = k` should error (k is int from keys())
    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert 24 in error_lines , f"Expected error on line 24 (bad: int = v), got errors on lines {error_lines}. "
    f"Without fix, dict.values() yields key type instead of value type.";
    assert 30 in error_lines , f"Expected error on line 30 (bad2: str = k), got errors on lines {error_lines}.";
    # The `good` lines should NOT have errors.
    assert 23 not in error_lines , f"Line 23 (good: str = v) should not error — values() yields str, "
    f"but got errors on lines {error_lines}. TypeVar order is likely swapped.";
    assert 29 not in error_lines , f"Line 29 (good2: int = k) should not error — keys() yields int, "
    f"but got errors on lines {error_lines}.";
}

# =========================================================================
# Bug #TVAR-5: Module-level TypeVars shadowed by class type parameters
#
# apply_solved_type_vars matched TypeVars by name only, so module-level
# `glob T = TypeVar('T', bound=int)` was substituted with inherited `str`
# from `Transform[str]`.
#
# Fix: Added is_class_type_param flag and bounds-checking to distinguish
# class type parameters from module-level TypeVars.
# =========================================================================
test "bug_tvar5_module_typevar_shadowed_by_class_param" {
    program = compile_and_check("checker_bug_typevar_shadow.jac");

    # Expected: 1 error (str -> int on line 29)
    # Without fix: 2 errors (line 23 would also error because sync returned str)
    assert len(program.errors_had) == 1 , f"Bug #TVAR-5: Expected 1 error but got {len(
        program.errors_had
    )}.";

    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert 29 in error_lines , f"Expected error on line 29, got {error_lines}.";
    assert 23 not in error_lines , f"Line 23 should NOT error, got {error_lines}.";
}

# =========================================================================
# Bug #IMPL-1: `has` var reassigned in impl body shadows the parent type
#
# When a reactive def-component (e.g. `def:pub app -> None { has todos: ... }`)
# has its method body split into a separate `.impl.jac` file, assignments to
# the has var like `todos = todos + [x]` inside the impl created an untyped
# local "shadow" symbol in SymTabBuildPass. The impl module's parent scope
# is not yet connected at that pass, so the lookup for the enclosing HasVar
# fails and falls through to the local-var branch.
#
# Effect: in the impl body, every reference to the has var is typed as
# Unknown, and any operation on it (e.g. `todos + [{...}]`) breaks overload
# resolution for `__add__`, producing a cascade of spurious E1055 errors
# that don't appear when the same body is written inline.
#
# Fix: After DeclImplMatchPass connects an impl body to its declaration,
# walk the impl body for Assignment targets whose resolved symbol is a
# local shadow of a HasVar in the now-reachable parent ability scope, and
# re-point those Name nodes at the parent HasVar. Only apply this for
# has vars owned by an Ability (reactive component state); archetype
# methods keep normal Python scoping (bare-name assignments stay local).
# =========================================================================
test "bug_impl1_has_var_shadow_in_impl_body" {
    fixture_dir = os.path.join(
        JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
    );
    program = JacProgram();
    program.compile(
        os.path.join(fixture_dir, "impl_has_var_reassign.cl.jac"), type_check=True
    );

    # Expected after fix: 0 errors. The impl body should type-check cleanly:
    #   - `tasks + [task]` resolves via list[dict].__add__
    #   - `x: list[dict] = tasks` is a sound assignment
    assert len(program.errors_had) == 0 , (
        "Bug #IMPL-1: has var `tasks` in impl body should resolve to the "
        "parent HasVar (type list[dict]), not a local shadow (type Unknown). "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #BASE-1: Base class name resolved in class's own scope
#
# For `class Child(Parent) { def Parent -> int {...} }` the name `Parent`
# in the base-classes list was looked up starting from Child's own symbol
# table. The inner ability `Parent` was found first, so Child's MRO
# collapsed to [Child] and inherited members became invisible —
# producing spurious E1030 errors on valid inherited attribute access.
#
# Real-world manifestation: `datetime.datetime.fromisoformat(...)` reported
# "Type datetime has no attribute fromisoformat" because CPython's
# `class datetime(date)` stub has a method `def date(self) -> _Date: ...`
# that shadowed the outer `date` class.
#
# Fix: Introduced `_resolution_scope_for` helper in the type evaluator.
# When a Name reference sits inside an Archetype's `base_classes` list,
# resolution uses the Archetype's parent_scope (Python semantics). PEP 695
# type parameters declared on the class remain visible inside the base
# list (names matching `Archetype.type_params` keep class scope).
# =========================================================================
test "bug_base1_base_class_resolved_in_enclosing_scope" {
    program = compile_and_check("checker_bug_base_class_scope.jac");

    # Expected after fix: 0 errors. Before fix: 4 errors (E1030 on
    # `self.greet()` and `c.greet()`, plus cascading E1002/E1001).
    assert len(program.errors_had) == 0 , (
        "Bug #BASE-1: base class name must resolve in enclosing scope, not "
        "the class's own scope. Inner member shadowing the base identifier "
        "broke MRO and hid inherited attributes. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}
