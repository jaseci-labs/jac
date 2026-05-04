"""Test bracket filter comprehension syntax [?:Type, cond]."""

node A {
    has val: int;
}

node B {
    has val: int;
}

glob my_list: list = [];

with entry {
    for i in range(5) {
        root ++> A(val=i);
        root ++> B(val=i + 10);
        my_list.append(A(val=i));
        my_list.append(B(val=i + 10));
    }
    # Bracket filter on edge traversal — type only
    print([root-->][?:A]);
    # Bracket filter on edge traversal — type + condition
    print([root-->][?:A, val<3]);
    # Bracket filter on edge traversal — condition only
    print([root-->][?val<12]);
    # Bracket filter on list — type + condition
    print(my_list[?:A, val<3]);
    # Bracket filter on list — condition only
    print(my_list[?val<3]);
}
