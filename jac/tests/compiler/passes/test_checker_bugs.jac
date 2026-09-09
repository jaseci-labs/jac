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
  #SUPER-1 - super() call returns Unknown instead of parent instance
  #DSTR-1  - Docstring before declaration inside function body triggers W0060 instead of attaching
  #DLOC-1 - Decorated class inside function body parsed as Ability instead of Archetype
  #STUB-VGUARD - Module-level version-guarded stub symbols (e.g. datetime.UTC) resolve as Unknown
  #HOGEN-1 - TypeVars not bound through function-typed args; blocks generic decorator-application
  #WITHAS-1 - `with cm() as x` bound x to the manager not __enter__'s result; async with used sync protocol
  #UNPACK-1 - Assignment unpacking of a non-tuple iterable (bytes/str/range) typed targets as Unknown
  #STARGUARD-1 - version-guarded names re-exported via `from M import *` (e.g. Buffer) fail to resolve
  #BYTES-1 - Byte-string literals (b"...") typed as str instead of bytes
  #EVOLVING-NONE - `x = None` then reassign inside `if` lost the new type post-branch
  #LITWIDEN - literal initializers not widened for mutable vars/attrs/container elements
  #INCLUDE-MEMBER-1 - member access on `include`d (absorb) symbols resolved to
                      Unknown when the included submodule imported back from its
                      own package (circular self-import); poisoned the vendored
                      llvm ir/binding surface and every native pass (#7163)
  #LOOPHDR-1 - loop-header back-edge detection used find_parent_of_type(<same
               kind>), so a back edge originating inside a nested loop of the
               SAME kind was treated as a loop-entry pred and destroyed the
               header narrowing (#7853)
  #LOOPWIDEN-1 - the first statement of a loop body was exempted from the
                 conservative back-edge merge, so a symbol the body reassigns
                 kept its iteration-one (pre-loop) narrowing there (#8039)
  #CYCLE-IMPORT-1 - re-entrant module import while that module's compile was
                    still on the stack fell into a fresh program.compile of the
                    same path instead of answering from the in-flight state
                    (#7853)
  #CYCLE-TAINT-1 - an Unknown born from the symbol-resolution cycle guard was
                   cached on the expression node and diagnosed (W1051 / E1032 /
                   E1053), freezing transient in-flight types that settle once
                   the cycle unwinds (#7853)
  #CYCLE-PRECISION-1 - the #7853 fix suppressed via a global window counter,
                       so ANY Unknown evaluated while a cycle was in flight got
                       amnesty, including genuine unrelated errors; replaced by
                       an is_incomplete flag carried on the Unknown itself
                       (#7871 E)
  #TERNTAIL-1 - a statement whose RHS holds a ternary or a short-circuit chain
                looked wired to _connect_tails (that sub-expression CFG hangs
                off the statement), so a statement ending a block never reached
                the statement after the block and its write stayed invisible to
                the narrowing walk (#8059)
  #TVARSCOPE-1 - a method's own TypeVar was substituted by the enclosing
                 class's inherited type-var solution because solutions are
                 keyed by TypeVar *name*; a generic base specialized anywhere
                 in the MRO pinned every same-named method TypeVar in the
                 whole subtree (#8201)
  #OVLDTVAR-1 - a magic-method overload returned its declared return type
                without solving the overload's own TypeVars from the
                arguments, so `list[A] + list[B]` typed as `list[_S | A]`
                with `_S` free (#8201)
  #COMPRASSIGN-1 - a comprehension on an assignment RHS was linked into the
                   CFG from an ancestor of the assignment instead of from the
                   assignment itself, so the chain back to the preceding
                   guards was cut and no enclosing narrowing reached the
                   comprehension body (#8201)
  #ELIFSC-1 - an elif (or a nested if) whose condition short-circuits got no
              false target, because the search for the following statement
              only looked in the immediate parent's body; the edge out of the
              chain dangled and every narrowing before it was lost. A branch
              edge that cannot compute a narrowing also collapsed the merge
              instead of keeping what its predecessors established (#8201)
  #BLOCKANN-1 - a typed declaration inside a block (a while/if/for/try body)
                was inserted into that block's scope while bare assignments
                hoist to the enclosing function, so one variable became two
                symbols and a reassignment was checked against the first
                branch's type instead of the declared annotation; the
                declaration now binds the function local, so its annotation
                also holds after the block and a sibling block redeclaring
                the name collides with it (#8060)
  #TYPEIS-1 - a user-defined predicate returning TypeIs[T] or TypeGuard[T]
              narrowed nothing at its call sites; the checker knew the two
              names but resolved the annotation to nothing, and the CFG's
              may-narrow set only recognized the builtin guard calls, so a
              helper predicate was invisible to flow narrowing (#8201)
  #ISECT-1 - isinstance narrowing filtered a declared union as a whole, so a
             member above the filter class was thrown away whenever another
             member sat below it, and the guard claimed the more specific
             member for values that are not it (#8201)
  #ANDPOL-1 - the false edge of a conjunction narrowed by the conjunction's
              most specific positive conjunct, but `not (A and B)` says
              nothing about A on its own; the else branch of
              `if isinstance(x, Foo) and x.bar` wrongly excluded Foo (#8201)
  #TVARMETH-1 - a generic archetype's type parameters were not in scope over
                its own methods: an enclosing function short-circuited the
                scope check, and an impl block was not recognized as a scope
                at all, so `impl C.m(v: T)` and every class parameter used in
                a method body reported E1065 (#8230)
  #SELFOVL-1 - overload selection never looked at the receiver, so typeshed's
               `def split(self: LiteralString, ...) -> list[LiteralString]`
               won for a plain `str` and `lines.insert(0, str(1))` was E1053;
               and assignment narrowing read the raw right-hand type where
               the declaration path widens literals, so an annotated
               `list[str]` local was narrowed to `list[LiteralString]` anyway
               (#8982 item 12)
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.transform { Alert }
import from jaclang.compiler.types.type_utils { compute_mro_linearization }
import from jaclang.compiler.types.types {
    ClassDetailsShared,
    ClassType,
    TypeFlags,
    UnknownType
}
import from jaclang.compiler.driver.pass_driver { run_pass }

glob CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "checker"
     );

"""Compile a checker fixture and run the type check pass."""
def compile_and_check(fixture_name: str) -> JacProgram {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, fixture_name),
        options=CompileOptions(default_codespace='server')
    );
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
    assert len(program.errors_had) == 4 , "Bug #1: 'is'/'in' operators return UnknownType instead of bool. "
    f"Expected 4 type errors but got {len(program.errors_had)}. "
    "The missing 'return' in operations.jac:141 causes bool results to be discarded.";
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
    assert len(program.errors_had) >= 1 , "Bug #3: List element type inference only considers the first element. "
    f"Expected at least 1 type error for mixed list assignment but got {len(
        program.errors_had
    )}. "
    "[1, 'hello'] is typed as list[int] instead of list[int | str].";
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
    # Build a diamond hierarchy manually to check MRO order; these hand-built
    # classes deliberately carry no symbol table.
    _no_symtab: any = None;
    a_shared = ClassDetailsShared(
        class_name="A", symbol_table=_no_symtab, mro=[], base_classes=[]
    );
    a_type = ClassType(_shared=a_shared, flags=TypeFlags.Instantiable);
    a_type.shared.mro = [a_type];

    b_shared = ClassDetailsShared(
        class_name="B", symbol_table=_no_symtab, mro=[], base_classes=[a_type]
    );
    b_type = ClassType(_shared=b_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(b_type);

    c_shared = ClassDetailsShared(
        class_name="C", symbol_table=_no_symtab, mro=[], base_classes=[a_type]
    );
    c_type = ClassType(_shared=c_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(c_type);

    d_shared = ClassDetailsShared(
        class_name="D", symbol_table=_no_symtab, mro=[], base_classes=[b_type, c_type]
    );
    d_type = ClassType(_shared=d_shared, flags=TypeFlags.Instantiable);
    compute_mro_linearization(d_type);

    mro_names = [cls.shared.class_name for cls in d_type.shared.mro];

    # Python C3 MRO: [D, B, C, A]
    # Buggy DFS MRO: [D, B, A, C] (A before C)
    expected_c3 = ["D", "B", "C", "A"];

    assert mro_names == expected_c3 , "Bug #6: MRO is not C3 linearized. "
    f"Expected {expected_c3} but got {mro_names}. "
    "In diamond inheritance, C should come before A in the MRO.";
}

# =========================================================================
# Cyclic heritage: compute_mro_linearization must not recurse infinitely
#
# compute_mro_linearization recursed into base_classes with no in-progress
# guard. A malformed or cyclic inheritance graph (a self-referential class,
# or A -> B -> A) recursed until the stack overflowed instead of degrading
# to a best-effort MRO. The fix adds an in-progress guard keyed on the class.
# =========================================================================
test "cyclic_heritage_mro_does_not_recurse" {
    # Hand-built classes deliberately carry no symbol table.
    _no_symtab: any = None;
    # Self-referential: A lists itself as a base.
    a_shared = ClassDetailsShared(
        class_name="A", symbol_table=_no_symtab, mro=[], base_classes=[]
    );
    a_type = ClassType(_shared=a_shared, flags=TypeFlags.Instantiable);
    a_type.shared.base_classes = [a_type];
    compute_mro_linearization(a_type);
    assert a_type.shared.mro and a_type.shared.mro[0] is a_type;

    # Mutual cycle: B -> C -> B.
    b_shared = ClassDetailsShared(
        class_name="B", symbol_table=_no_symtab, mro=[], base_classes=[]
    );
    b_type = ClassType(_shared=b_shared, flags=TypeFlags.Instantiable);
    c_shared = ClassDetailsShared(
        class_name="C", symbol_table=_no_symtab, mro=[], base_classes=[]
    );
    c_type = ClassType(_shared=c_shared, flags=TypeFlags.Instantiable);
    b_type.shared.base_classes = [c_type];
    c_type.shared.base_classes = [b_type];
    compute_mro_linearization(b_type);
    assert b_type.shared.mro and b_type.shared.mro[0] is b_type;
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
    assert len(program.errors_had) >= 1 , "Bug #7: Protocol conformance only checks method names, not signatures. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    "WrongSignature.draw(int)->str should not satisfy Drawable.draw(str)->None.";
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
    assert len(program.errors_had) == 3 , "Bug #8: Dict/tuple/set literals return UnknownType. "
    f"Expected 3 type errors but got {len(program.errors_had)}. "
    "No case handlers exist for DictVal, TupleVal, SetVal in the evaluator.";
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
    assert len(program.errors_had) == 2 , "Bug #11: BoolExpr returns last operand type only. "
    f"Expected 2 type errors but got {len(program.errors_had)}. "
    "'x and y' should be typed as type(x) | type(y), not just type(y).";
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
    assert len(program.errors_had) == 2 , "Bug #12: CompareExpr returns UnknownType instead of bool. "
    f"Expected 2 type errors but got {len(program.errors_had)}. "
    "No case handler exists for CompareExpr in _get_type_of_expression_core.";
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
    assert len(program.errors_had) >= 1 , "Bug #13: IfExpr (ternary) returns UnknownType. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    "No case handler exists for IfExpr in _get_type_of_expression_core.";
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
    assert len(program.errors_had) >= 1 , "Bug #15: No generic type argument checking. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    "list[int] should NOT be assignable to list[str].";
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
    assert len(program.errors_had) == 1 , "Bug #23: With statement alias typed as Unknown. "
    f"Expected 1 type error but got {len(program.errors_had)}. "
    "'with open(...) as f' should type f as TextIOWrapper, not Unknown.";
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
    assert len(program.errors_had) == 5 , "Bug #22: Tuple unpacking in for loops returns UnknownType. "
    f"Expected 5 type errors but got {len(program.errors_had)}. "
    "for (a, b) in list[tuple[A, B]] should type a as A and b as B.";
}

# =========================================================================
# Bug #UNPACK-1: Assignment unpacking of a non-tuple iterable typed as Unknown
# =========================================================================
test "bug_unpack1_assign_non_tuple_iterable" {
    program = compile_and_check("checker_bug_unpack_iterable_assign.jac");
    assert len(program.errors_had) == 3 , "Bug #UNPACK-1: unpacking a non-tuple iterable. "
    f"Expected 3 type errors but got {len(program.errors_had)}.";
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
    assert len(program.errors_had) == 1 , "Bug #ANY-1: Expected 1 error (object.nonexistent), "
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
    assert len(program.errors_had) == 0 , "Bug #FINAL-1: attribute access on Final[T] raised E1030 "
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
    assert len(program.errors_had) >= 1 , "Bug #TVAR-1: _extract_type_params duplicates TypeVars from "
    "multiple generic bases, causing positional mismatch. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    "Without dedup, V in BaseMapping(BaseCollection[K], Generic[K, V]) is unresolved.";
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
    assert len(program.errors_had) >= 1 , "Bug #TVAR-2: build_type_var_solution doesn't propagate TypeVars "
    "through base_classes chain. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    "Without transitive propagation, V2 in BaseReader is unresolved.";
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
    assert len(program.errors_had) >= 1 , "Bug #TVAR-3: Union return types with TypeVars (V | None) resolve "
    "to Unknown due to is_any_type() short-circuit in operations.jac. "
    f"Expected at least 1 type error but got {len(program.errors_had)}. "
    "Without the fix, dict.get() and similar methods return Unknown.";
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
    assert len(program.errors_had) >= 2 , "Bug #TVAR-4: Generic[] base must set canonical TypeVar order. "
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
    "Without fix, dict.values() yields key type instead of value type.";
    assert 30 in error_lines , f"Expected error on line 30 (bad2: str = k), got errors on lines {error_lines}.";
    # The `good` lines should NOT have errors.
    assert 23 not in error_lines , "Line 23 (good: str = v) should not error — values() yields str, "
    f"but got errors on lines {error_lines}. TypeVar order is likely swapped.";
    assert 29 not in error_lines , "Line 29 (good2: int = k) should not error — keys() yields int, "
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

    # Expected: 1 error (str -> int on line 28)
    # Without fix: 2 errors (line 22 would also error because sync returned str)
    assert len(program.errors_had) == 1 , f"Bug #TVAR-5: Expected 1 error but got {len(
        program.errors_had
    )}.";

    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert 28 in error_lines , f"Expected error on line 28, got {error_lines}.";
    assert 22 not in error_lines , f"Line 22 should NOT error, got {error_lines}.";
}

# Bug #TVAR-6: glob-form TypeVar not solved at free-function call sites.
test "bug_tvar6_glob_typevar_in_free_function" {
    program = compile_and_check("checker_bug_typevar_glob_free_func.jac");
    assert len(program.errors_had) == 0 , f"Bug #TVAR-6: Expected 0 errors but got {len(
        program.errors_had
    )}: {[e.msg for e in program.errors_had]}.";
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
    fixture_dir = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "fixtures");
    program = JacProgram();
    program.compile(os.path.join(fixture_dir, "impl_has_var_reassign.jac"));

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

# =========================================================================
# Bug #SUPER-1: super() call returns Unknown
#
# `_get_type_of_super` returned `parent_class_type.clone_as_instance()` for
# the bare `super` Name, giving it the type of an already-instantiated
# parent. When written as `super()`, the FuncCall handler then fell through
# to the generic "call an instance" path and tried to resolve `__call__`
# on the parent instance. With no match it returned Unknown, so
# `super().method()` evaluated to `Unknown.method()` and produced
# cascading E1002/E1001/W1051 diagnostics on the enclosing expression.
#
# Fix: short-circuit in `validate_call_args` when the call target is
# `super` — the return type of `super()` is the same as bare `super`
# (the parent instance), matching Python semantics where attribute
# access through `super()` dispatches via the parent's MRO.
# =========================================================================
test "bug_super1_super_call_returns_parent_instance" {
    program = compile_and_check("checker_bug_super_call_in_method.jac");

    # Expected after fix: 0 errors. Before fix: 1 error (E1002 "Cannot
    # return <Unknown>, expected dict") plus 6 W1051 warnings on every
    # chained use of the Unknown result.
    assert len(program.errors_had) == 0 , (
        "Bug #SUPER-1: `super()` in a method must type-check as the "
        "parent instance so that attribute access dispatches through the "
        "parent's MRO. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_dstr1_docstring_before_local_declaration" {
    program = compile_and_check("checker_bug_docstring_local_decl.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #DSTR-1: a docstring before a declaration inside a function body "
        "must attach to the declaration without producing W0060 or parse errors. "
    );
}

test "bug_dloc1_decorated_class_in_function_body" {
    program = compile_and_check("checker_bug_decorated_local_class.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #DLOC-1: a decorated class inside a function body must parse "
        "as an Archetype so the type checker recognises its constructor and "
        "fields. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_while_loop_narrowing" {
    program = compile_and_check("checker_bug_while_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "`while cur` should narrow cur from Item|None to Item inside the body. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_subscript_index_narrowing" {
    program = compile_and_check("checker_bug_subscript_key_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "items[0], items[-1], config[\"host\"] should all narrow inside isinstance guard. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_subscript_index_narrowing_negative" {
    program = compile_and_check("checker_bug_subscript_key_narrowing_neg.jac");

    assert len(program.errors_had) >= 5 , (
        "Variable index, range slice, and post-narrow subscript writes "
        "(items[0]=, items[-1]=, config[\"host\"]=) must all error. "
        "Expected at least 5 E1099 errors but got "
        f"{len(program.errors_had)}: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_cast_union_instance" {
    program = compile_and_check("checker_bug_cast_union_instance.jac");

    assert len(program.errors_had) == 0 , (
        "instance types so that attribute access on the result does not "
        "produce false-positive E1099 errors. "
    );
}

# =========================================================================
# Bug #NONE-EQ: `x == None` / `x != None` did not narrow `T | None`.
#
# `is None` / `is not None` correctly narrowed Optional unions, but the
# operator-equality forms fell through unhandled in classify_condition,
# leaving attribute access on the narrowed branch typed as `T | None` and
# producing spurious E1099 errors. Pyright, mypy, and TypeScript all
# narrow on both forms; Jac now does too.
# =========================================================================
test "bug_none_eq_neq_narrowing" {
    program = compile_and_check("checker_bug_eq_none_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "`x != None` (true branch) and `x == None` (fall-through) must "
        "narrow `T | None` to `T`, matching the existing `is`/`is not None` "
        "behavior. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #COMPR-NARROW: `T | None` narrowing did not reach comprehension
# iterators or conditionals.
#
# `InnerCompr` is a `UniCFGNode` but is never wired into the CFG. A
# reference to a narrowed symbol inside the comprehension's `collection`
# or `conditional` walks up to the orphan `InnerCompr` and stops, missing
# the narrowing established by an enclosing guard. Pyright and mypy treat
# the comprehension as part of the enclosing flow scope; Jac now does too.
# =========================================================================
test "bug_comprehension_narrowing" {
    program = compile_and_check("checker_bug_compr_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "`T | None` narrowing established by an enclosing guard must "
        "propagate into list/dict/set/gen comprehension iterators, out "
        "expressions, and conditional clauses -- both for early-return "
        "guards and for in-body `if x is not None { ... }` blocks. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #COMPR-NARROW (true-positive guard): the in-body edge classification
# must not over-narrow comprehension edges to the true branch. Inside
# `if r is None { ... }` (and the else of `if r is not None`) the narrowed
# type of `r` really is `None`, so `r.parts` inside a comprehension there
# must still raise. Guards against a regression where the parent-walk
# returns "true" for every nested comprehension, silently dropping errors.
# =========================================================================
test "bug_comprehension_narrowing_negative" {
    program = compile_and_check("checker_bug_compr_narrowing_negative.jac");

    assert len(program.errors_had) == 2 , (
        "Comprehensions inside a branch where `r` is narrowed to `None` "
        "must still raise on `r.parts` -- the in-body edge fix must not "
        "over-classify nested comprehension edges as the true branch. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #JSX-SLOT-NARROW: `T | None` narrowing did not reach JSX statement
# slot bodies (`{for ... { <jsx> }}` / `{if ... { <jsx> }}`).
#
# `ViewLowerPass` rewrites a slot body into `acc = []; ...; return
# <>{acc}</>;` and stores the lowered statements as the slot's `body`
# list. `CFGBuildPass` had no `exit_jsx_slot` handler - the body
# statements were visited individually but never wired sequentially or
# linked back to the slot's enclosing CodeBlockStmt. A name reference
# inside the slot's loop header (e.g. `recipe.ingredients` in `{for ing
# in recipe.ingredients { ... }}`) walked up to its enclosing
# `InForStmt`, found an empty `bb_in`, and dead-ended - losing any
# narrowing from an enclosing `if recipe is None { return; }` guard.
# =========================================================================
test "bug_jsx_slot_narrowing" {
    program = compile_and_check("checker_bug_jsx_slot_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "`T | None` narrowing established by an enclosing guard must "
        "propagate into JSX statement slot bodies (loop iterators, "
        "conditions, and child interpolations). "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #PROP-SETTER: @<name>.setter flagged as duplicate method
#
# ASTValidationPass.enter_archetype scans archetype bodies for duplicate
# method names to emit E0076. It correctly skips `@overload` methods but
# did not skip property accessor decorators (`@<name>.setter`,
# `@<name>.deleter`, `@<name>.getter`). Those decorators extend an existing
# `@property` definition by reusing the same method name — the canonical
# Python property pattern — and must not be reported as duplicates.
#
# Impact: any archetype declaring a property setter (e.g. JacProgram.doc_ir
# in compiler/frontend/codeinfo.jac) triggered a spurious E0076 syntax error.
#
# The fix is *semantic*, not just structural: the dup-check first collects
# names declared with `@property` in the class body, then skips a method
# only when its decorator is `@<name>.setter`/`.getter`/`.deleter`, the
# decorator's target Name matches the method name, AND `<name>` was
# declared `@property` in this class. This preserves dup detection for:
#   (a) accessors targeting non-properties (`@bar.setter def foo`)
#   (b) duplicate accessors of the same kind (two `@x.setter def x`)
# =========================================================================
"""Return E0076 errors emitted while checking a fixture."""
def _e0076_errors_of(fixture_name: str) -> list[Alert] {
    program = compile_and_check(fixture_name);
    return [
        e
        for e in program.errors_had
        if (e.code is not None and e.code.code == "E0076")
    ];
}

test "bug_property_setter_not_duplicate_method" {
    # Canonical property + setter + deleter + multi-property fixture: no E0076.
    errs = _e0076_errors_of("checker_bug_property_setter.jac");
    assert len(errs) == 0 , (
        "Bug #PROP-SETTER: `@<name>.setter`/`.deleter`/`.getter` decorators "
        "extend a property and must not be flagged as duplicate methods. "
        f"Got E0076 errors: {[str(e) for e in errs]}"
    );
}

test "bug_property_setter_strict_masked_dup_still_reported" {
    # `@bar.setter def foo` where `bar` is not a @property must NOT mask
    # a real duplicate of `def foo`. A purely structural skip (any decorator
    # ending in `.setter`/`.getter`/`.deleter`) would silently swallow this;
    # the semantic skip only triggers when the decorator target is a
    # property declared in this class, so the second `def foo` still flags.
    errs = _e0076_errors_of("checker_bug_property_setter_masked_dup.jac");
    assert len(errs) == 1 , (
        "Bug #PROP-SETTER strict: a duplicate `def foo` whose second "
        "occurrence carries `@bar.setter` (with no `@property def bar` in "
        "this class) must still raise E0076 — the property-accessor skip "
        "must be semantic, not just structural. "
        f"Got {len(errs)} E0076 error(s): {[str(e) for e in errs]}"
    );
}

test "bug_property_setter_duplicate_accessor_reported" {
    # Two `@val.setter def val` for the same property is a real dup: a
    # property can have at most one setter, getter, or deleter. The dup-
    # detector tracks `(name, accessor_kind)` pairs alongside plain
    # method names so this case still raises E0076.
    errs = _e0076_errors_of("checker_bug_property_setter_dup_accessor.jac");
    assert len(errs) == 1 , (
        "Bug #PROP-SETTER strict: declaring two `@val.setter def val` for "
        "the same property must raise E0076 — a property has at most one "
        "setter (or getter, or deleter). "
        f"Got {len(errs)} E0076 error(s): {[str(e) for e in errs]}"
    );
}

# Bug #STUB-VGUARD: top-level `if sys.version_info` guards left their symbols
# wrapped in IfStmt by proc_module, so the type checker saw e.g. `datetime.UTC`
# as Unknown and emitted W1051 at every use site.
test "bug_stub_vguard_module_level_symbol_resolves" {
    program = compile_and_check("checker_bug_version_guard_stub_symbol.jac");
    unresolved = [
        w
        for w in program.warnings_had
        if "could not be resolved" in str(w)
    ];
    assert unresolved == [] , (
        "Bug #STUB-VGUARD: `datetime.UTC` (defined under `if sys.version_info "
        ">= (3, 11):` in typeshed) must resolve to its declared type, not Unknown. "
        f"Got W1051 warnings: {[str(w) for w in unresolved]}"
    );
}

# Bug #NARROW-ANY: isinstance on a symbol typed Any (e.g. the element of a
# bare `list`) did not narrow because get_narrowed_type's guard accepted only
# Union/Class/Unknown, so `item.label` after `isinstance(item, Foo)` stayed
# Unknown and raised E1001/E1002.
test "bug_narrow_any_symbol_isinstance" {
    program = compile_and_check("checker_narrow_anytype_isinstance.jac");
    assert program.errors_had == [] , (
        "Bug #NARROW-ANY: isinstance must narrow an Any-typed symbol, so "
        "accessing a member of the narrowed type does not error. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# Bug #HOGEN-1: TypeVars were not bound through function-typed arguments, so
# `apply(f: Callable[[], T]) -> T` returned an unbound T. Fixing the binder
# also enables generic decorator-application (e.g. @contextmanager) with no
# name special-casing.
test "bug_hogen_1_typevar_bound_through_callable_arg" {
    program = compile_and_check("checker_higher_order_typevar.jac");
    assert program.errors_had == [] , (
        "Bug #HOGEN-1: a TypeVar passed through a Callable argument must bind "
        "to the callable's return type. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_hogen_1_contextmanager_generic_apply" {
    program = compile_and_check("checker_contextmanager_generic_apply.jac");
    assert program.errors_had == [] , (
        "Bug #HOGEN-1: an annotated-generator @contextmanager method must type "
        "as a context manager via generic decorator-application, so `with` "
        "produces no errors. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_hogen_1_plain_method_in_with_still_errors" {
    program = compile_and_check("checker_with_plain_method_errors.jac");
    e1091 = sum(
        1
        for e in program.errors_had
        if e.code and e.code.code == "E1091"
    );
    e1092 = sum(
        1
        for e in program.errors_had
        if e.code and e.code.code == "E1092"
    );
    assert e1091 == 1 and e1092 == 1 , (
        "Bug #HOGEN-1 guard: a plain (non-context-manager) method in `with` "
        f"must still produce E1091 + E1092. Got E1091={e1091}, E1092={e1092}."
    );
}

# Bug #WITHAS-1: `with cm() as x` bound x to the context manager rather than
# __enter__'s result, and `async with` was checked against the sync protocol.
# The alias now binds through __enter__/__aenter__ (awaited for async), and the
# protocol check picks the methods by the `async with` flag.
test "bug_withas_1_as_binds_enter_result" {
    program = compile_and_check("checker_with_as_enter_binding.jac");
    assert program.errors_had == [] , (
        "Bug #WITHAS-1: `with cm() as x` must bind x to __enter__'s return "
        f"type. Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_withas_1_async_with_as_binds_and_checks" {
    program = compile_and_check("checker_async_with_as_binding.jac");
    assert program.errors_had == [] , (
        "Bug #WITHAS-1: `async with cm() as x` must verify the async protocol "
        "and bind x to the awaited __aenter__ result. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_starguard_1_guarded_star_reexport_resolves" {
    program = compile_and_check("checker_star_reexport_guard.jac");
    e1055 = sum(
        1
        for e in program.errors_had
        if e.code and e.code.code == "E1055"
    );
    assert e1055 == 1 , (
        "Bug #STARGUARD-1: `bytes + str` must error because str is not a "
        "Buffer. The guarded ReadableBuffer/Buffer re-export must resolve so "
        f"bytes.__add__ rejects str. Expected 1 E1055, got {e1055}."
    );
}

test "bug_starguard_1_single_segment_reexport_resolves" {
    program = compile_and_check(os.path.join("star_reexport_guard", "consumer.jac"));
    e1032 = sum(
        1
        for e in program.errors_had
        if e.code and e.code.code == "E1032"
    );
    assert len(program.errors_had) == 0 , (
        "Bug #STARGUARD-1: a guarded name re-exported via a single-segment "
        "`from M import *` must resolve. Marker was Unknown "
        f"({e1032} E1032). Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_starguard_1_multi_segment_reexport_resolves" {
    program = compile_and_check(
        os.path.join("star_reexport_guard_multiseg", "consumer.jac")
    );
    e1032 = sum(
        1
        for e in program.errors_had
        if e.code and e.code.code == "E1032"
    );
    assert len(program.errors_had) == 0 , (
        "Bug #STARGUARD-1: a guarded name re-exported via a MULTI-SEGMENT "
        "`from pkg.submod import *` must resolve. The buggy extension-probing "
        "appended an extension to an already-extensioned path, so Marker was "
        f"Unknown ({e1032} E1032). Got errors: {[str(e) for e in program.errors_had]}"
    );
}

test "bug_byte_literal_typed_as_bytes" {
    program = compile_and_check("checker_bytes_literal.jac");
    assert program.errors_had == [] , (
        "Bug : a byte-string literal (b\"...\") must be typed as bytes, "
        "so it assigns to bytes and concatenates with other bytes. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# Bug #EVOLVING-NONE: `x = None` then reassigning inside an `if` branch
# was not picked up post-branch — CFG narrowing rejected the new type as
# not assignable to NoneType, producing false E1002 on `return x`.
test "bug_evolving_none_narrowing" {
    program = compile_and_check("checker_bug_evolving_locals_narrowing.jac");
    assert program.errors_had == [] , (
        "Bug #EVOLVING-NONE: `x = None; if cond { x = real_value; }; return x;` "
        "must narrow to the assigned type post-branch (Pyright evolving-locals). "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# Bug #LITWIDEN: literal types inferred from a literal initializer were not
# widened for mutable variables and container elements, so `row = ["."] * 3;
# row[0] = "B";` failed with E1001 (Cannot assign Literal["B"] to Literal["."]).
# Widening must reach into container element types (list/dict/set), matching
# mypy/pyright, while explicit annotations and expression-position literals
# keep their Literal type.
test "bug_literal_widening_for_mutable_declarations" {
    program = compile_and_check("checker_bug_literal_widening.jac");
    assert program.errors_had == [] , (
        "Bug #LITWIDEN: literals inferred for mutable variables and container "
        "elements must widen to their base type (['.'] * 3 -> list[str]) so "
        "later stores of a different value are allowed. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# Bug #INCLUDE-MEMBER-1 / #7163: a class re-exported into a package only via
# `include` (absorb) was Unknown when reached through the package namespace
# (`ir.Value`) if the included submodule imported back from its own package
# (circular self-import, as the vendored llvm ir/binding submodules do). The
# module-item path (`from pkg import X`) already fell back to walking the absorb
# imports via _resolve_star_import_symbol; the member-access path did not, and
# returned UnknownType on the lookup miss. This poisoned the whole llvm surface
# -- the native passes do `import from ...llvm { ir }` then `ir.Value` /
# `ir.Module` / ... -- cascading ~1,700 E1030/E1032 errors across every native
# pass. The base Value class also did not declare its `type` attribute. With the
# absorb-aware fallback in place and Value.type declared, the issue's repro must
# type-check clean.
#
# The reproduction rides the vendored llvm package on purpose: the bug only
# surfaces when the absorbing package is resolved through the type evaluator's
# cross-module import path (external / JIR-cached), which a fixture compiled as
# the main target does not exercise.
test "bug_7163_llvm_ir_boundary_resolves" {
    program = compile_and_check("checker_llvm_ir_boundary.jac");
    assert program.errors_had == [] , (
        "Bug #7163: `import from ...llvm { ir }` then `ir.Value` with `.type` "
        "must resolve. `ir.Value` was Unknown (member access on an absorbed "
        f"symbol). Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #LOOPHDR-1 / #7853: loop-header narrowing merges only loop-entry
# preds; back edges are skipped. Detection used
# `pred.find_parent_of_type(<kind of header>)`, i.e. the NEAREST same-kind
# ancestor, so a back edge originating inside a nested loop of the SAME
# kind (the tail of the inner loop's else clause links straight to the
# outer header) resolved to the inner loop and was mistaken for a
# loop-entry pred. Merging it drops `cur` back to its declared
# `Item | None`, and `cur.val` in the outer body raises a spurious
# "Cannot access attribute ... missing from NoneType" error.
#
# No loop in the fixture reassigns `cur`, so its pre-loop narrowing to
# `Item` is valid on every iteration and a sound checker has nothing to
# report anywhere in the file. The whole file must therefore check clean:
# any diagnostic at all is the bug. (Asserting a count instead would not
# discriminate -- the same diagnostics appear whether or not back-edge
# detection works, once the fixture is allowed to widen `cur` in the body.
# That widening is what #LOOPWIDEN-1 covers, and it is kept out of here on
# purpose so this fixture isolates back-edge detection alone.)
#
# The single-loop control is the unnested equivalent: its back edge
# originates directly in the loop body, whose nearest same-kind ancestor IS
# the header, so it was skipped correctly even by the buggy detection and
# stays clean under both. The nested forms must match it.
# =========================================================================
test "bug_loophdr1_nested_same_kind_loop_back_edge" {
    program = compile_and_check("checker_nested_loop_backedge.jac");
    assert program.errors_had == [] , (
        "Bug #LOOPHDR-1: a back edge into a loop header that originates "
        "inside a nested loop of the same kind must be skipped when "
        "computing the header narrowing, exactly like its unnested "
        "equivalent. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #CYCLE-IMPORT-1 / #7853, part 1: a well-formed two-module import
# cycle where each side uses the other's symbol in a signature must check
# clean end-to-end. (This path is answered from the module hub -- the
# partially-built tree -- and guards the overall cyclic-import contract.)
# =========================================================================
test "bug_cycimp1_cyclic_import_pair_checks_clean" {
    program = compile_and_check("checker_cycle_import_sig_a.jac");
    assert program.errors_had == [] , (
        "Bug #CYCLE-IMPORT-1: a cyclic import pair with signature-level "
        "cross-references must produce no errors. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
    unresolved = [
        w
        for w in program.warnings_had
        if "could not be resolved" in str(w)
    ];
    assert unresolved == [] , (
        "Bug #CYCLE-IMPORT-1: a cyclic import pair must not leave W1051 "
        f"noise. Got: {[str(w) for w in unresolved]}"
    );
}

# =========================================================================
# Bug #CYCLE-IMPORT-1 / #7853, part 2: the re-entrant import guard itself.
# When the evaluator is asked for a module whose compile is still on the
# stack (tracked in `_modules_in_compile`) and the partial tree is not in
# any hub yet -- reachable organically only through the narrow window
# before parse publishes the module (e.g. a parse-failed member of a
# native cyclic pair) -- it must answer with a stub instead of re-entering
# program.compile for the same path (unbounded mutual recursion). This
# test drives the branch directly: it marks the path as in-compile and
# asserts the stub answer, that no compile happened (no diagnostics, path
# still absent from the hub), and that a later, non-re-entrant query does
# compile and resolve the real module.
# =========================================================================
test "bug_cycimp1_reentrant_import_guard_returns_stub" {
    import from pathlib { Path }
    program = JacProgram();
    evaluator = program.get_type_evaluator();
    target = str(
        Path(os.path.join(CHECKER_FIXTURES, "checker_cycle_guard_target.jac")).resolve()
    );
    pre_errs = len(program.errors_had);
    evaluator._modules_in_compile.add(target);
    try {
        stub = evaluator._import_module_from_path(target);
    } finally {
        evaluator._modules_in_compile.discard(target);
    }
    assert stub.stub_only , (
        "Bug #CYCLE-IMPORT-1: a re-entrant import of a mid-compile module "
        "absent from every hub must return a stub module."
    );
    assert target not in program.mod.hub , (
        "Bug #CYCLE-IMPORT-1: the re-entrant import guard must not compile "
        "or publish the module -- that is the in-flight compile's job."
    );
    assert len(program.errors_had) == pre_errs , (
        "Bug #CYCLE-IMPORT-1: the guard path must not emit diagnostics. "
        f"Got errors: {[str(e) for e in program.errors_had[pre_errs:]]}"
    );

    settled = evaluator._import_module_from_path(target);
    assert not settled.stub_only and settled.name == "checker_cycle_guard_target" , (
        "Bug #CYCLE-IMPORT-1: once the module is no longer mid-compile, the "
        "same query must compile and return the real module."
    );
}

# =========================================================================
# Bug #CYCLE-TAINT-1 / #7853: an Unknown produced by the symbol-resolution
# cycle guard (get_type_of_symbol re-entered for a symbol already on the
# resolution stack) is transient: once the cycle unwinds, the type settles.
# The checker used to treat it like any other Unknown -- caching it on the
# expression node, emitting W1051, letting E1032 fire on attribute access
# and E1053 on argument checks, and freezing the assignment's LHS -- so
# code whose types fully settle reported spurious diagnostics and the
# symbol stayed Unknown forever.
#
# Fixture shape (mutually referencing globals across an import cycle):
#   main:    glob CONFIG = REGISTRY.defaults;
#   sibling: glob REGISTRY = Reg() if CONFIG is None else Reg();
# Resolving CONFIG re-enters CONFIG through the sibling's initializer, but
# the re-entrant leg only feeds `is None` (bool either way), so REGISTRY
# settles to Reg and CONFIG to dict. Pre-fix this produced 2 spurious
# errors (E1032-style attribute access, E1053-style len() arg) plus W1051
# noise, and get_type_of_symbol(CONFIG) stayed <Unknown> after the pass.
# =========================================================================
test "bug_cyctaint1_settling_cycle_checks_clean_and_resolves" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_cycle_taint_main.jac"),
        options=CompileOptions(default_codespace='server')
    );

    assert program.errors_had == [] , (
        "Bug #CYCLE-TAINT-1: a symbol-resolution cycle whose types settle "
        "after unwinding must not produce errors. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
    unresolved = [
        w
        for w in program.warnings_had
        if "could not be resolved" in str(w)
    ];
    assert unresolved == [] , (
        "Bug #CYCLE-TAINT-1: the transient in-flight Unknown must not be "
        f"diagnosed as W1051. Got: {[str(w) for w in unresolved]}"
    );

    config_sym = mod.names_in_scope.get("CONFIG");
    assert config_sym is not None , "CONFIG symbol missing from fixture module";
    settled = program.get_type_evaluator().get_type_of_symbol(config_sym);
    assert not isinstance(settled, UnknownType) and str(settled) == "dict" , (
        "Bug #CYCLE-TAINT-1: after the cycle unwinds, a later query must "
        "resolve the settled type (dict via Reg.defaults), not a frozen "
        f"Unknown. Got: {settled}"
    );
}

# =========================================================================
# Bug #CYCLE-PRECISION-1 / #7871 E: the #7853 mechanism suppressed via a
# global depth counter with caller-side window snapshots, which amnestied
# EVERY Unknown evaluated inside a window that saw a cycle bump -- including
# genuine, cycle-independent errors. Completeness now travels with the
# result (UnknownType.is_incomplete), so only types actually contaminated
# by an in-flight resolution are exempt.
#
# Fixture shape: the #CYCLE-TAINT-1 settling cycle, plus a sibling glob
#   JUNK = (N if CONFIG is None else N)();   # N: int -- calling an int
# whose resolution overlaps the cycle window (the condition re-enters
# CONFIG) but whose Unknown-ness is genuine: calling a non-callable int
# yields Unknown no matter what CONFIG settles to. JUNK.oops is a real
# E1032. Under the counter design this fixture checked completely clean
# (verified: zero errors); with the completeness flag the genuine error
# fires while every cycle-transient suppression still holds.
# =========================================================================
test "bug_cycprec1_genuine_error_in_cycle_window_still_fires" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_cycle_precision_main.jac"),
        options=CompileOptions(default_codespace='server')
    );

    oops_errors = [
        e
        for e in program.errors_had
        if "oops" in str(e)
    ];
    assert len(oops_errors) == 1 , (
        "Bug #CYCLE-PRECISION-1: the genuine attribute error on JUNK.oops "
        "must still be diagnosed even though its evaluation overlaps a "
        "resolution cycle. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
    assert len(program.errors_had) == 1 , (
        "Bug #CYCLE-PRECISION-1: the cycle-transient suppressions must "
        "hold (no spurious assignment/argument errors) alongside the one "
        "genuine error. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );

    config_sym = mod.names_in_scope.get("CONFIG");
    assert config_sym is not None , "CONFIG symbol missing from fixture module";
    settled = program.get_type_evaluator().get_type_of_symbol(config_sym);
    assert not isinstance(settled, UnknownType) and str(settled) == "dict" , (
        "Bug #CYCLE-PRECISION-1: CONFIG must still settle to dict. " f"Got: {settled}"
    );
}

# =========================================================================
# Bug #CYCLE-PRECISION-1 / #7871 E, whitebox: the caching layer must never
# store an incomplete result. Simulates the in-flight state by pushing
# CONFIG onto the symbol-resolution stack, then queries the sibling's
# CONFIG-use Name directly through the evaluator API: the answer is an
# incomplete Unknown, nothing is frozen onto the node, and once the stack
# unwinds the same query resolves and caches the settled type.
# =========================================================================
test "bug_cycprec1_node_type_never_stores_incomplete_result" {
    import from pathlib { Path }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_cycle_taint_main.jac"),
        options=CompileOptions(default_codespace='server')
    );
    evaluator = program.get_type_evaluator();
    config_sym = mod.names_in_scope.get("CONFIG");
    assert config_sym is not None , "CONFIG symbol missing from fixture module";

    reg_path = str(
        Path(os.path.join(CHECKER_FIXTURES, "checker_cycle_taint_reg.jac")).resolve()
    );
    reg_mod = evaluator._import_module_from_path(reg_path);
    registry_sym = reg_mod.names_in_scope.get("REGISTRY");
    assert registry_sym is not None , "REGISTRY symbol missing from reg module";
    _reg_assign: any = registry_sym.decl.name_of.parent;
    config_use: any = _reg_assign.value.condition.expr.left;
    assert config_use.value == "CONFIG" , (
        f"fixture navigation broke: expected the CONFIG use, got {config_use}"
    );

    assert evaluator.push_symbol_resolution(config_sym) , (
        "pushing a symbol not on the resolution stack must succeed"
    );
    try {
        during = evaluator.get_type_of_expression(config_use);
    } finally {
        evaluator.pop_symbol_resolution(config_sym);
    }
    assert isinstance(during, UnknownType) and during.is_incomplete , (
        "Bug #CYCLE-PRECISION-1: querying a symbol mid-resolution must "
        f"answer an incomplete Unknown. Got: {during}"
    );
    assert config_use.type is None , (
        "Bug #CYCLE-PRECISION-1: an incomplete result must never be stored "
        f"in node_.type. Got: {config_use.type}"
    );

    settled = evaluator.get_type_of_expression(config_use);
    assert not isinstance(settled, UnknownType) and str(settled) == "dict" , (
        "Bug #CYCLE-PRECISION-1: after the stack unwinds, the same query "
        f"must resolve the settled type. Got: {settled}"
    );
    assert config_use.type is not None and str(config_use.type) == "dict" , (
        "Bug #CYCLE-PRECISION-1: the settled (complete) type must be "
        f"cached on the node. Got: {config_use.type}"
    );
}

# =========================================================================
# Bug #TERNTAIL-1 / #8059: `exit_if_else_expr` / `exit_bool_expr` hang the
# sub-expression CFG of a ternary or a short-circuit chain off the statement
# that contains it, so `v = a if c else b;` leaves the statement with a
# `bb_out` that never leaves the statement. `_connect_tails` read that as
# "already wired" and skipped the fall-through edge, so an assignment ending
# an if arm, an elif arm, a while body or a try body never reached the
# statement after the block: the narrowing walk resolved every later
# `is not None` guard against the pre-block view of the symbol and kept the
# `| NoneType` member inside the guard's own body.
# =========================================================================
test "bug_terntail1_ternary_rhs_at_block_tail_narrows" {
    program = compile_and_check("checker_bug_ternary_rhs_tail.jac");

    # Expected: 0 errors (every guard narrows out NoneType)
    # Actual before the fix: 4 errors (both guards from the issue's repro,
    # the try-body tail, and the short-circuit RHS tail)
    assert program.errors_had == [] , "Bug #TERNTAIL-1: an assignment whose RHS routes through the sub-expression "
    "CFG must still flow to the statement after the block it ends, so a later "
    "'is not None' guard narrows it. "
    f"Got errors: {[str(e) for e in program.errors_had]}";
}

# =========================================================================
# Bug #TERNTAIL-1, negative side: the missing edge also swallowed genuine
# errors. In `dropped_else_arm` the else arm's ternary write never reached
# the join, so the walk saw only the then arm's Leaf2 and the call checked
# clean. Both appends must be reported, and against the *narrowed* union --
# a diagnostic still carrying NoneType would mean the guard never narrowed.
# =========================================================================
test "bug_terntail1_ternary_rhs_union_still_reported" {
    program = compile_and_check("checker_bug_ternary_rhs_tail_err.jac");

    # Expected: 2 errors (Leaf2 | Tok3 is not assignable to list[Leaf2])
    # Actual before the fix: 1 error, and it read Leaf2 | Tok3 | NoneType
    assert len(program.errors_had) == 2 , "Bug #TERNTAIL-1: a ternary-assigned union that outlives its guard must "
    f"still be reported at every use. Expected 2 errors, got "
    f"{len(program.errors_had)}: {[str(e) for e in program.errors_had]}";

    assert not any(["NoneType" in str(e) for e in program.errors_had]) , "Bug #TERNTAIL-1: the guard must narrow NoneType away before the error is "
    f"raised. Got errors: {[str(e) for e in program.errors_had]}";
}

# Bug #BLOCKANN-1: a block-scoped typed declaration lost its annotation
#
# Jac locals are python-scoped: a block (while/if/for/try body) is a symbol
# table scope but not a binding scope, which is why bind_assignment_targets
# hoists a bare assignment to the enclosing function. A typed declaration
# took the other path and was inserted into the block's own scope, so the
# branch assignments that followed it created a SECOND symbol on the
# function, decl-ed by the first branch. get_type_of_symbol then answered
# that branch's type and the next branch was rejected against it:
#   while n > 0 {
#       item: (A | B | None) = None;   # symbol on the WhileStmt scope
#       if c { item = pa(c); }         # new symbol on the Ability, A | None
#       else { item = pb(c); }         # E1001: cannot assign B | None
#   }
# The same declaration at function level was fine, since there the two
# paths land in the same scope.
# =========================================================================
test "bug_blockann1_block_scoped_declaration_keeps_annotation" {
    program = compile_and_check("checker_bug_block_scoped_annotation.jac");

    # Expected: 0 errors, every branch assignment fits (A | B | None)
    # Actual (before the fix): 2 errors, one for the while body and one for
    # the if block; the function-level shape already passed.
    assert len(program.errors_had) == 0 , (
        "Bug #BLOCKANN-1: a typed declaration inside a while body or an if "
        "block must declare in the enclosing function, so reassignments are "
        "checked against the declared annotation. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #BLOCKANN-1, negative: the declared annotation must still constrain.
# Widening a block-scoped declaration to Unknown would silence the bug too,
# so assignments the annotation does not admit have to stay diagnosed.
# =========================================================================
test "bug_blockann1_block_scoped_declaration_still_rejects_bad_assignment" {
    program = compile_and_check("checker_bug_block_scoped_annotation_negative.jac");

    # Expected: 2 errors, one per block shape, for assigning (C | None) to a
    # local declared (A | B | None).
    assert len(program.errors_had) == 2 , (
        "Bug #BLOCKANN-1: an assignment outside the declared annotation must "
        "still be reported for block-scoped declarations. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #BLOCKANN-1, scoping consequences: because the declaration now lands
# in the enclosing function, two shapes that were silently accepted while it
# was stranded on the block scope are diagnosed.
#
#   1. The annotation outlives its block. `if c { z: int = 1; }` then
#      `z = "oops";` after the block: `z` is a function local of type int,
#      so the str is rejected. Jac has no block scope for locals, so the
#      name was always live there; only its declared type was being lost.
#   2. Sibling blocks declaring the same name are one variable. The first
#      declaration owns the symbol and the second is checked against it.
#
# Shape 2 is reported today as an assignment failure at the second
# declaration (E1001). The language reference specifies a redeclaration
# diagnostic for "typed declaration after the name is already bound in this
# scope" (E0064), whose trigger is currently limited to names that rebind an
# *outer* binding, so the code is a known imprecision; the verdict (this is
# an error) is what this test pins.
# =========================================================================
test "bug_blockann1_block_declaration_binds_the_function_local" {
    program = compile_and_check("checker_bug_block_scoped_annotation_scope.jac");

    # Expected: 2 errors, one per shape. Before the fix: 0, because each
    # declaration was stranded on its own block scope.
    assert len(program.errors_had) == 2 , (
        "Bug #BLOCKANN-1: a block-scoped declaration binds a function local, "
        "so its annotation constrains the name after the block and a sibling "
        "block redeclaring it collides. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# Bug #LOOPWIDEN-1 / #8039: a loop body that reassigns a narrowed symbol
# makes every body node see the conservative back-edge merge, `body[0]`
# included. `body[0]` used to be exempted, so it kept the iteration-one
# view: the pre-loop narrowing, leaked into iterations that reach the top
# of the body over the back edge with the widened value instead.
#
# This is the converse of #LOOPHDR-1. There, skipping the back edge at the
# header is right because nothing in the loop rewrites the symbol; here the
# body does rewrite it, so the entry narrowing does not survive to the next
# iteration and the read must fall back to the declared type. Locations are
# asserted, not just counts: the fix must diagnose exactly the two bodies
# that widen and leave the two that do not alone. In particular
# `condition_renarrows` widens `cur` too, but `while cur is not None`
# re-narrows entry into the body over the conservative merge, so a blanket
# "loop bodies are conservative" rule would wrongly flag it.
# =========================================================================
test "bug_loopwiden1_body_reassign_forces_conservative_merge" {
    program = compile_and_check("checker_loop_body_widening.jac");
    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert len(program.errors_had) == 2 , (
        "Bug #LOOPWIDEN-1: exactly the two loop bodies that reassign `cur` "
        "may be diagnosed. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
    assert 35 in error_lines , (
        "Bug #LOOPWIDEN-1: `cur.val` at the top of a while body whose tail "
        "rebinds `cur` to an `Item | None` must be diagnosed -- iteration "
        "two reaches it over the back edge, not from the pre-loop "
        f"`cur = Item()`. Got errors on lines: {error_lines}"
    );
    assert 46 in error_lines , (
        "Bug #LOOPWIDEN-1: the same holds for a for body; the fallback is "
        f"keyed on the loop kind, not on while alone. Got: {error_lines}"
    );
    assert 56 not in error_lines , (
        "Bug #LOOPWIDEN-1: `while cur is not None` re-narrows entry into "
        "the body on every iteration, so the conservative merge must still "
        f"have the loop condition applied over it. Got: {error_lines}"
    );
    assert 67 not in error_lines , (
        "Bug #LOOPWIDEN-1: a body that never writes `cur` has no back-edge "
        "widening to merge, so the pre-loop narrowing must survive. "
        f"Got: {error_lines}"
    );
    for e in program.errors_had {
        assert "Item | NoneType" in str(e) , (
            "Bug #LOOPWIDEN-1: the fallback is to the declared type, so the "
            f"diagnosed type must be the full `Item | None`. Got: {e}"
        );
    }
}

# =========================================================================
# Bug #TVARSCOPE-1 / #8201: TypeVar solutions are keyed by name, so a
# method's own TypeVar collided with a same-named class type parameter
# inherited from a specialized generic base.
#
# `Leaf(Mid)` and `Mid(Carrier[Alpha, Beta])` put `T -> Alpha` in the
# solution built for `Leaf`. `Leaf.pick` declares its own module-level `T`,
# a different type variable that merely shares the name, and it was
# rewritten to `Alpha` at every call site. A static member also dropped the
# receiver class entirely, which turned on the permissive "trust the name"
# rule in apply_solved_type_vars.
#
# The rule is lexical: only the type parameters bound by the class that
# *declares* the member (or one of its enclosing class scopes) may be
# substituted, and a function's own type parameters shadow the class's.
# =========================================================================
test "bug_tvarscope1_method_typevar_not_bound_by_class_solution" {
    program = compile_and_check("checker_bug_method_typevar_scope.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #TVARSCOPE-1: a method's own TypeVar must stay free of the "
        "enclosing class's inherited type-var solution. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #TVARSCOPE-1, negative: the lexical restriction must not stop a real
# class type parameter from being solved through the MRO. `Carrier.move`
# and `Carrier.build` are declared on the generic class, so `T`/`R` are
# theirs and `Leaf` must still see them as `Alpha`/`Beta`.
# =========================================================================
test "bug_tvarscope1_class_typevar_still_solved_through_mro" {
    program = compile_and_check("checker_bug_method_typevar_scope_negative.jac");

    error_text = "\n".join([str(e) for e in program.errors_had]);
    assert len(program.errors_had) == 2 , (
        "Bug #TVARSCOPE-1: an inherited class type parameter must still be "
        "solved from the base specialization, so passing a Beta where Alpha "
        f"is expected stays an error. Got errors: {error_text}"
    );
    assert "Alpha" in error_text , (
        "Bug #TVARSCOPE-1: the expected parameter type must read Alpha, not "
        f"the unsolved type variable. Got: {error_text}"
    );
}

# =========================================================================
# Bug #OVLDTVAR-1 / #8201: get_type_of_magic_method_call returned the
# matched overload's declared return type verbatim. The overload had been
# specialized for the receiver class, so `_T` was bound, but the overload's
# *own* TypeVars were never solved from the arguments.
#
# `list[A] + list[B]` picks `__add__(self, value: list[_S]) -> list[_S | _T]`
# and used to yield `list[_S | A]`, whose element type has no attributes at
# all, so every member access on the result was a false E1099.
# =========================================================================
test "bug_ovldtvar1_magic_overload_solves_own_typevars" {
    program = compile_and_check("checker_bug_magic_overload_typevar.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #OVLDTVAR-1: a magic-method overload must solve its own "
        "TypeVars from the argument types before its return type is used. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #COMPRASSIGN-1 / #8201: a comprehension sitting on an assignment RHS
# was deliberately not linked from the assignment (#6061), to keep
# `out = [t for t in out]` from resolving `out` through the write that is
# still in flight. But the walk went to the assignment's *parent* rather
# than to its predecessors, so the chain back to the preceding guards was
# cut and the comprehension body saw only declared types.
#
# The comprehension now links from the enclosing statement, and the
# narrowing walk treats an assignment predecessor that encloses the node
# being evaluated as a pass-through: the RHS runs before the write, so the
# write is not visible to it. That is both the fix and the original
# protection, stated where it belongs.
# =========================================================================
test "bug_comprassign1_comprehension_on_assignment_rhs_keeps_narrowing" {
    program = compile_and_check("checker_bug_compr_assign_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #COMPRASSIGN-1: a comprehension on an assignment RHS must see "
        "the narrowing that holds at the assignment, and must not resolve "
        "its own target through the in-flight write. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #ELIFSC-1 / #8201: `elif <a> and <b>` produced no false target.
# `exit_if_stmt` looked for the statement after the branch with
# `_find_next_cfg_stmt_after(nd.parent, nd)`, but an elif is its parent's
# `else_body`, not an entry in `parent.body`, so the search found nothing
# and the edge out of the chain dangled. `_connect_tails` could not repair
# it either: the short-circuit entry sitting in `bb_out` made the node look
# like it already had a false branch. Everything after the chain then fell
# back to declared types.
#
# The search now climbs out of the enclosing if/else nesting, and a branch
# edge whose narrowing cannot be computed keeps what its predecessors
# established instead of collapsing the merge -- which is what the
# short-circuit edge case already did.
# =========================================================================
test "bug_elifsc1_short_circuit_elif_keeps_guard_narrowing" {
    program = compile_and_check("checker_bug_elif_shortcircuit_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #ELIFSC-1: the narrowing established by an if guard must "
        "survive an elif whose condition short-circuits. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #TYPEIS-1 / #8201: a user-defined predicate whose return type is
# `TypeIs[T]` (PEP 742) or `TypeGuard[T]` (PEP 647) narrowed nothing.
# `TypeIs`/`TypeGuard` were listed among the known special-form names but had
# no branch in the `_SpecialForm` subscript path, so the annotation resolved
# to nothing; and `collect_narrowing_symbols`, which runs before types exist,
# only credited `isinstance`/`callable`/`hasattr` with narrowing anything, so
# the flow walk skipped the guard's argument outright.
#
# A `TypeIs[T]` call narrows both edges -- positive to T, negative by
# subtracting T -- because PEP 742 requires T to be consistent with the
# argument's declared type. `TypeGuard[T]` narrows the positive edge only,
# and replaces the declared type there rather than intersecting with it.
# =========================================================================
test "bug_typeis1_type_is_narrows_both_polarities" {
    program = compile_and_check("checker_bug_typeis_narrowing.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #TYPEIS-1: a `TypeIs[T]` predicate must narrow its argument to "
        "T on the true edge and subtract T on the false edge, through plain "
        "functions, static methods and bound methods alike. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #TYPEIS-1, TypeGuard half: PEP 647 is one-directional. The positive
# edge takes the guarded type verbatim -- `TypeGuard[list[str]]` on a
# `list[int] | None` yields `list[str]`, not an intersection -- and the
# negative edge narrows by nothing at all.
# =========================================================================
test "bug_typeis1_type_guard_is_positive_only" {
    program = compile_and_check("checker_bug_typeguard_narrowing.jac");
    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert len(program.errors_had) == 1 , (
        "Bug #TYPEIS-1: `TypeGuard` narrows the positive edge only, so the "
        "one diagnosed line must be the negative branch reading `.tag` off a "
        f"still-optional value. Got errors: {[str(e) for e in program.errors_had]}"
    );
    assert 44 in error_lines , (
        "Bug #TYPEIS-1: the negative branch of a TypeGuard keeps the declared "
        f"type, so line 44 must be the diagnosed one. Got: {error_lines}"
    );
}

# =========================================================================
# Bug #ISECT-1 / #8201: `_filter_union_for_isinstance` narrowed a declared
# union as a whole. It kept the members that derive from the filter class
# and, if any did, threw the rest away -- so `isinstance(x, Mid)` on an
# `x: Leaf | Base` answered `Leaf`, claiming a `Base` that passes the guard
# is a `Leaf`. When no member derived from the filter, the whole declared
# type was replaced by the filter instead.
#
# The narrow is applied per union member now: a member below the filter is
# kept whole, a member above it takes the filter class carrying its type
# arguments, and a member unrelated to it drops. Where nothing survives, the
# result is the bare filter class, which is what the old code produced.
#
# A member unrelated to the filter could also hold a value of some class
# deriving from both, which pyright models as a synthesized
# `<subclass of Member and Filter>`. That is deliberately not done here: the
# native lane needs a concrete layout for every type a narrow produces and a
# synthesized class has none, so the precision would cost every guard over
# unrelated classes its lowering.
# =========================================================================
test "bug_isect1_isinstance_narrows_each_union_member" {
    program = compile_and_check("checker_bug_isinstance_intersection.jac");
    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert len(program.errors_had) == 1 , (
        "Bug #ISECT-1: `isinstance(x, Mid)` on a `Leaf | Base` must answer "
        "`Leaf | Mid`, so passing the result where a `Leaf` is wanted is the "
        f"one error. Got errors: {[str(e) for e in program.errors_had]}"
    );
    assert 34 in error_lines , (
        "Bug #ISECT-1: the member above the filter must survive as the "
        f"filter class, so line 34 is the diagnosed one. Got: {error_lines}"
    );
    for e in program.errors_had {
        assert "Leaf | Mid" in str(e) , (
            "Bug #ISECT-1: both members must survive the narrow, so the "
            f"diagnosed type reads `Leaf | Mid`. Got: {e}"
        );
    }
}

# =========================================================================
# Bug #ISECT-1, negative: per-member narrowing must not lose what the
# whole-union narrow had. A guard no member survives still falls back to the
# filter class, the false edge still subtracts it, and a narrowed member
# exposes exactly its own surface.
# =========================================================================
test "bug_isect1_per_member_narrow_keeps_precision" {
    program = compile_and_check("checker_bug_isinstance_intersection_negative.jac");
    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert len(program.errors_had) == 2 , (
        "Bug #ISECT-1: the fallback to the filter class and the false edge "
        "must both survive. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
    assert 33 in error_lines , (
        "Bug #ISECT-1: subtracting Mid from `Base | None` leaves the None, "
        f"so `.label` on line 33 stays an error. Got: {error_lines}"
    );
    assert 40 in error_lines , (
        "Bug #ISECT-1: a narrowed member exposes its own surface and no "
        f"more, so line 40 stays an error. Got: {error_lines}"
    );
}

# =========================================================================
# Bug #ANDPOL-1 / #8201: `_find_predicate_for` reduced an and-chain to its
# most specific positive conjunct and handed that single predicate to both
# edges. `not (A and B)` says nothing about A on its own, so the else branch
# of `if isinstance(x, Foo) and x.bar` wrongly excluded Foo -- a value whose
# `bar` is false takes that branch as a Foo.
#
# The predicate now records which edges it licenses. A conjunction narrows
# the false edge only when every conjunct carries the same predicate, and
# the mirror rule holds for a disjunction's true edge. Where the edge is not
# licensed the walk keeps whatever its predecessors established, which is
# the same fallback an unnarrowable branch edge already used.
# =========================================================================
test "bug_andpol1_conjunction_false_edge_narrows_by_nothing" {
    program = compile_and_check("checker_bug_and_chain_false_edge.jac");
    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert len(program.errors_had) == 3 , (
        "Bug #ANDPOL-1: the false edge of a conjunction and the true edge of "
        "a disjunction may not narrow by one conjunct alone. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
    assert 21 in error_lines , (
        "Bug #ANDPOL-1: the else branch of `isinstance(x, Foo) and x.bar` "
        f"still admits Foo. Got: {error_lines}"
    );
    assert 30 in error_lines , (
        "Bug #ANDPOL-1: the fall-through after a conjunction guard still "
        f"admits Foo. Got: {error_lines}"
    );
    assert 37 in error_lines , (
        "Bug #ANDPOL-1: the true edge of `isinstance(x, Foo) or flag` cannot "
        f"conclude Foo. Got: {error_lines}"
    );
}

# =========================================================================
# Bug #ANDPOL-1, negative: only the unlicensed edges lose their narrowing.
# A lone guard, the true edge of a conjunction, a conjunction whose every
# conjunct is the same predicate, a negated conjunction (which swaps the
# edges), and both edges of a fully matched disjunction all still narrow.
# =========================================================================
test "bug_andpol1_licensed_edges_still_narrow" {
    program = compile_and_check("checker_bug_and_chain_false_edge_negative.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #ANDPOL-1: edge polarity may only remove the narrowing the "
        "condition never licensed. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #TVARMETH-1 / #8230: a generic archetype's type parameters were not in
# scope over its own methods. `validate_typevar_scope` picked the innermost
# Ability and the innermost Archetype and then consulted only one of them:
# an enclosing function short-circuited the whole check, so a class
# parameter used in a method body reported E1065 and never reached the
# class that binds it.
#
# The walk also did not know `ImplDef`. An `impl C.m(v: T)` block sits at
# module level with a FuncSignature hanging off an ImplDef rather than an
# Ability, so neither scope was found at all and every use fell through to
# the unconditional E1065 at the bottom -- which is what blocked the
# contextvars shim (#8220).
#
# Scope resolution is now one lexical walk outward: each enclosing Ability
# contributes its own type parameters, each enclosing Archetype contributes
# the class's, and an ImplDef contributes its own signature and then hands
# the walk to the declaration it implements, so the walk carries on from
# inside the declaring class. The walk ends at the first archetype it
# reaches, which is PEP 484's rule that a nested class does not inherit the
# outer class's type variables.
# =========================================================================
test "bug_tvarmeth1_class_typevar_in_scope_over_methods" {
    program = compile_and_check("checker_bug_class_typevar_method_scope.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #TVARMETH-1: a class type parameter must be in scope over its "
        "methods' signatures and bodies, in the class body and in an impl "
        f"block alike. Got errors: {[str(e) for e in program.errors_had]}"
    );
}

# =========================================================================
# Bug #TVARMETH-1, negative: the walk must still stop where the language
# stops it. A TypeVar no enclosing scope binds has no meaning, whether it is
# used in a non-generic archetype's method body, in that archetype's field,
# or at module level -- and a generic sibling binding the same name
# elsewhere in the file does not put it in scope here.
#
# The walk also ends at the first enclosing archetype rather than climbing
# into the one around it: PEP 484 states outright that a nested class does
# not inherit the outer class's type variables, and both of `Nested`'s uses
# of `Holder`'s `P` are reported for that reason.
# =========================================================================
test "bug_tvarmeth1_unbound_typevar_still_has_no_meaning" {
    program = compile_and_check("checker_bug_class_typevar_method_scope_negative.jac");

    error_lines = [
        e.loc.first_line
        for e in program.errors_had
        if e.loc
    ];
    assert len(program.errors_had) == 5 , (
        "Bug #TVARMETH-1: a TypeVar no enclosing scope binds must still be "
        f"reported. Got errors: {[str(e) for e in program.errors_had]}"
    );
    for line in [18, 24, 31, 34, 40] {
        assert line in error_lines , (
            "Bug #TVARMETH-1: the unbound uses are the reported ones. "
            f"Got lines: {error_lines}"
        );
    }
}

# =========================================================================
# Bug #TVARMETH-1, negative: putting the class parameter in scope must not
# leave it unsolved. `Ctx[Leaf]` still pins `T` to `Leaf` at the call site,
# so a `str` argument is rejected and the returned element is a `Leaf`.
# =========================================================================
test "bug_tvarmeth1_class_typevar_still_solves_at_call_site" {
    program = compile_and_check("checker_bug_class_typevar_still_solved.jac");

    error_text = "\n".join([str(e) for e in program.errors_had]);
    assert len(program.errors_had) == 2 , (
        "Bug #TVARMETH-1: a method's use of the class parameter must still "
        f"solve from the instantiation. Got errors: {error_text}"
    );
    assert "Leaf" in error_text , (
        "Bug #TVARMETH-1: the solved parameter type must read Leaf, not the "
        f"free type variable. Got: {error_text}"
    );
}

# =========================================================================
# Bug #TVARMETH-1, negative: PEP 695 shadowing. A method that declares its
# own parameter of the same name binds it for itself, so `echo` answers the
# argument type rather than the class's `Leaf`, and the class parameter is
# untouched outside it.
# =========================================================================
test "bug_tvarmeth1_method_type_param_shadows_class_param" {
    program = compile_and_check("checker_bug_method_typevar_shadows_class.jac");

    assert len(program.errors_had) == 0 , (
        "Bug #TVARMETH-1: a method's own type parameter shadows the class "
        "parameter of the same name. "
        f"Got errors: {[str(e) for e in program.errors_had]}"
    );
}


test "bug_selfovl1_receiver_selects_the_self_typed_overload" {
    program = compile_and_check("checker_self_typed_overload.jac");
    e1053 = [
        e.pretty_print()
        for e in program.errors_had
        if e.code and e.code.code == "E1053"
    ];
    assert not e1053 , (
        "a `str` receiver still resolved to the LiteralString overload, or a "
        f"declared list[str] was narrowed away:\n"
        + "\n".join(e1053)
    );
    assert len(program.errors_had) == 0 , "\n".join(
        e.pretty_print() for e in program.errors_had
    );
}
