"""FilterSpec — compile-time predicate carrier for [?:Type, conditions] filters.
"""
import from typing { Any, Callable }

"""Backend-neutral field predicate: one constraint on a single archetype field.

`op` is a lowercase, backend-neutral operator name:
  ``eq``  ``ne``  ``lt``  ``lte``  ``gt``  ``gte``  ``in``  ``nin``

Backends translate to their native syntax:
  - MongoDB: ``{"$" + op: value}``
  - Postgres: ``field < %s`` / ``field = ANY(%s)`` etc.

Multiple ``FieldPredicate`` objects on the same field (same key in
``FilterSpec.predicates``) are ANDed: e.g. ``age >= 20 AND age < 28``.
"""
obj FieldPredicate {
    has op: str,
        value: Any;
}

"""

Emitted by the compiler when a FilterCompr has both a type annotation and
field-level comparison predicates. The Python lambda (func) is always usable
as a fallback. Storage backends read type_name and predicates to build
backend-native queries without evaluating the lambda per-node.

Only emitted when all predicates are simple (field op constant). Complex
conditions — method calls, nested expressions — keep the plain lambda so
behaviour is unchanged.
"""
obj FilterSpec {
    has type_name: str,
        predicates: dict[str, list[FieldPredicate]],
        func: Callable[[Any], bool];

    def __call__(item: Any) -> bool;
}
