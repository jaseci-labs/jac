"""FilterSpec — compile-time predicate carrier for [?:Type, conditions] filters.
"""
import from typing { Any, Callable }
"""

Emitted by the compiler when a FilterCompr has both a type annotation and
field-level comparison predicates. The Python lambda (func) is always usable
as a fallback. Storage backends read type_name and predicates to build
backend-native queries (MongoDB filter dict, SQL WHERE clause, etc.) without
evaluating the lambda per-node.

Only emitted when all predicates are simple (field op constant). Complex
conditions — method calls, nested expressions — keep the plain lambda so
behaviour is unchanged.
"""
obj FilterSpec {
    has type_name: str,
        predicates: dict[str, Any],
        func: Callable[[Any], bool];

    def __call__(item: Any) -> bool;
}
