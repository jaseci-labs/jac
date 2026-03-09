"""Bug #26: Lambda expressions return UnknownType.

_get_type_of_expression_core has no case for LambdaExpr, so lambda
expressions fall through to UnknownType. This means lambda return
types and parameter types are never checked.

Expected: `lambda a: int: a + 1` should infer as callable returning int.
"""

with entry {
    fn = lambda a: int: a + 1;

    # Should infer as callable, so assigning to str should error
    bad: str = fn;  # <-- Should be Error (callable not assignable to str)

    # Calling lambda with wrong arg type should also error
    result: str = fn(5);  # <-- Should be Error (int return not assignable to str)
}
