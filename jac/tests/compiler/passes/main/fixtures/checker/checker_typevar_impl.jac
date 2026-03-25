"""Test for TypeVar scoping in impl blocks.

Root Cause 10: TypeVar T defined at module level should be valid in impl blocks.
Currently the checker reports E1065: "Type variable T has no meaning in this context."

Mirrors: runtime.jac line 76 (glob T = TypeVar('T')) and
runtime.impl.jac line 1506 (impl JacBasics.assign_all(target: list[T]) -> list[T])
"""

import from typing { TypeVar, Any }

glob T = TypeVar("T");

obj Basics {
    def assign_all(target: list[T], attr_val: tuple[tuple[str], tuple[Any]]) -> list[T];
}
