"""Test for union return types containing TypeVars in generic classes.

When a generic method's return type is a union involving a TypeVar
(e.g., _VT | None from dict.get), the type checker must correctly resolve
the union rather than returning Unknown.

The root cause was that `_VT | None` is evaluated as a BinaryExpr with BW_OR,
and the is_any_type() guard in operations.jac short-circuited to UnknownType
because TypeVarType.is_any_type() returns True. This prevented the BW_OR union
handler from ever running, so the return type was Unknown instead of V | None.
"""

import from typing { TypeVar, Generic }

glob K = TypeVar('K');
glob V = TypeVar('V');

obj Store(Generic[K, V]) {
    """Generic class with a method returning V | None (union with TypeVar)."""
    has data: dict[(K, V)] = {};

    def lookup(key: K) -> (V | None) {
        return self.data.get(key);
    }
}

with entry {
    s = Store[str, int]();

    # If TypeVar union resolution works, lookup returns int | None.
    # Without the fix, V | None resolves to Unknown, suppressing errors.
    good: int | None = s.lookup("key");   # <-- Should be OK
    bad: str = s.lookup("key");           # <-- Should be Error (int | None not assignable to str)
}
