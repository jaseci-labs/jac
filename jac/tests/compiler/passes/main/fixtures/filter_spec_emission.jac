"""Fixture for FilterSpec emission tests.

Predicate filters ([?:Type, field op const]) must emit FilterSpec so backends
can push the query down to storage. Type-only filters ([?:Type]) must stay as
a plain lambda so the TopologyIndex optimisation is not bypassed.
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

    # Predicate filter — must emit FilterSpec
    young = [root -->[?:User, age < 28]];

    # Multi-predicate filter — must also emit FilterSpec
    young_users = [root -->[?:User, age < 28, role == 'user']];

    # Type-only filter — must NOT emit FilterSpec (TopologyIndex path)
    all_users = [root -->[?:User]];

    # Condition-only filter (no type annotation) — plain lambda
    young_any = [root -->[?age < 28]];
}
