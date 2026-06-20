"""Fixture for FilterSpec emission tests.

Every typed filter ([?:Type, ...]) emits a FilterSpec carrier so the runtime
planner can read the archetype type and field predicates structurally instead
of inspecting the lambda's bytecode. Field predicates are pushed to storage
when every clause is a simple `field <op> literal` (in either operand order,
including chained comparisons and `in`/`not in`). Condition-only filters
([?cond], no type) stay a plain lambda — there is nothing for a backend to
key a type-scan off of.
"""

node User {
    has name: str = '', age: int = 0, role: str = 'user';
}

node Post {
    has title: str = '', views: int = 0;
}

with entry {
    root ++> User(name='Alice', age=30, role='admin');
    root ++> User(name='Bob', age=25, role='user');
    root ++> User(name='Carol', age=22, role='user');

    # Simple predicate — FilterSpec with one lt predicate.
    young = [root -->[?:User, age < 28]];

    # Multi-field predicate — FilterSpec with two fields.
    young_users = [root -->[?:User, age < 28, role == 'user']];

    # Type-only filter — FilterSpec carrier with empty predicates (so the
    # planner reads type_name structurally, no bytecode inspection).
    all_users = [root -->[?:User]];

    # Condition-only filter (no type) — plain lambda, not a FilterSpec.
    young_any = [root -->[?age < 28]];

    # Negative literal — must fold UnaryOp(USub, 1) into value=-1.
    weird_posts = [root -->[?:Post, views < -1]];

    # Constant on the left (field on the right) — normalize to `age < 28`.
    young_flipped = [root -->[?:User, 28 > age]];

    # Chained comparison — expand into two ANDed predicates on `age`.
    middle_aged = [root -->[?:User, 20 <= age < 50]];

    # Membership — `in` / `not in` operators with a literal collection.
    privileged = [root -->[?:User, role in ['admin', 'mod']]];
    non_guests = [root -->[?:User, role not in ['guest']]];
}
