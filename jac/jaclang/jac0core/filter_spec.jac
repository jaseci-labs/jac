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

"""Compile-time carrier for a typed filter comprehension ([?:Type, conditions]).

Emitted by the compiler for *every* typed FilterCompr so the runtime planner
reads `type_name` (and any `predicates`) structurally, with no lambda bytecode
inspection. `func` is the equivalent Python predicate — it is always a correct
fallback, applied per-node whenever a backend can't push the conditions down.

`predicates` is populated only when *every* condition is a simple
`field <op> literal` (in either operand order, including chained comparisons
and `in`/`not in`). When any condition is more complex — a method call, a
nested expression, a field-to-field comparison — `predicates` is left empty and
`func` alone enforces the filter. A type-only filter ([?:Type]) is just the
empty-predicates case.
"""
obj FilterSpec {
    has type_name: str,
        predicates: dict[str, list[FieldPredicate]],
        func: Callable[[Any], bool];

    def __call__(item: Any) -> bool;
}
