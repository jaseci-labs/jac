"""A compound `has` default (a list containing a multi-statement lambda) must
give each instance its own fresh list, never a class-level shared default.

The lambda helper hoists to the enclosing scope and the field uses a plain
``field(factory=lambda: <expr>)`` so the factory re-runs on every instantiation.
"""

obj B {
    has cbs: list = [
        lambda (x: int) -> int {
            a = x + 1;
            a
        }
    ];
}

with entry {
    b1 = B();
    b2 = B();
    print(b1.cbs is b2.cbs);
    b1.cbs.append(99);
    print(99 in b2.cbs);
}
