"""Frozenset operator and method primitives.

Covers all 18 FrozensetEmitter interfaces: copy, union, intersection,
difference, symmetric_difference, issubset, issuperset, isdisjoint,
op_or, op_and, op_sub, op_xor, op_eq, op_ne, op_le, op_lt, op_ge, op_gt.

All results converted to sorted lists or bools for JSON serialization.
"""

def frozenset_ops_py() -> dict {
    a = frozenset([1, 2, 3, 4]);
    b = frozenset([3, 4, 5, 6]);

    # Methods
    copy_a: list = sorted(list(a.copy()));
    union: list = sorted(list(a.union(b)));
    intersection: list = sorted(list(a.intersection(b)));
    difference: list = sorted(list(a.difference(b)));
    sym_diff: list = sorted(list(a.symmetric_difference(b)));

    # Subset / superset / disjoint
    sub_yes: bool = frozenset([1, 2]).issubset(frozenset([1, 2, 3]));
    sub_no: bool = frozenset([1, 4]).issubset(frozenset([1, 2, 3]));
    super_yes: bool = frozenset([1, 2, 3]).issuperset(frozenset([1, 2]));
    super_no: bool = frozenset([1, 2]).issuperset(frozenset([1, 2, 3]));
    disj_yes: bool = frozenset([1, 2]).isdisjoint(frozenset([3, 4]));
    disj_no: bool = frozenset([1, 2]).isdisjoint(frozenset([2, 3]));

    # Operators
    or_op: list = sorted(list(a | b));
    and_op: list = sorted(list(a & b));
    sub_op: list = sorted(list(a - b));
    xor_op: list = sorted(list(a ^ b));

    # Comparisons
    eq_yes: bool = frozenset([1, 2]) == frozenset([1, 2]);
    eq_no: bool = frozenset([1, 2]) == frozenset([1, 3]);
    ne_yes: bool = frozenset([1, 2]) != frozenset([1, 3]);
    ne_no: bool = frozenset([1, 2]) != frozenset([1, 2]);

    # Subset/superset via operators
    le_yes: bool = frozenset([1, 2]) <= frozenset([1, 2, 3]);
    le_eq: bool = frozenset([1, 2]) <= frozenset([1, 2]);
    lt_yes: bool = frozenset([1, 2]) < frozenset([1, 2, 3]);
    lt_no: bool = frozenset([1, 2]) < frozenset([1, 2]);
    ge_yes: bool = frozenset([1, 2, 3]) >= frozenset([1, 2]);
    ge_eq: bool = frozenset([1, 2]) >= frozenset([1, 2]);
    gt_yes: bool = frozenset([1, 2, 3]) > frozenset([1, 2]);
    gt_no: bool = frozenset([1, 2]) > frozenset([1, 2]);

    return {
        "copy": copy_a,
        "union": union, "intersection": intersection,
        "difference": difference, "sym_diff": sym_diff,
        "sub_yes": sub_yes, "sub_no": sub_no,
        "super_yes": super_yes, "super_no": super_no,
        "disj_yes": disj_yes, "disj_no": disj_no,
        "or_op": or_op, "and_op": and_op,
        "sub_op": sub_op, "xor_op": xor_op,
        "eq_yes": eq_yes, "eq_no": eq_no,
        "ne_yes": ne_yes, "ne_no": ne_no,
        "le_yes": le_yes, "le_eq": le_eq,
        "lt_yes": lt_yes, "lt_no": lt_no,
        "ge_yes": ge_yes, "ge_eq": ge_eq,
        "gt_yes": gt_yes, "gt_no": gt_no
    };
}

cl def frozenset_ops_cl() -> dict {
    a = frozenset([1, 2, 3, 4]);
    b = frozenset([3, 4, 5, 6]);

    copy_a: list = sorted(list(a.copy()));
    union: list = sorted(list(a.union(b)));
    intersection: list = sorted(list(a.intersection(b)));
    difference: list = sorted(list(a.difference(b)));
    sym_diff: list = sorted(list(a.symmetric_difference(b)));

    sub_yes: bool = frozenset([1, 2]).issubset(frozenset([1, 2, 3]));
    sub_no: bool = frozenset([1, 4]).issubset(frozenset([1, 2, 3]));
    super_yes: bool = frozenset([1, 2, 3]).issuperset(frozenset([1, 2]));
    super_no: bool = frozenset([1, 2]).issuperset(frozenset([1, 2, 3]));
    disj_yes: bool = frozenset([1, 2]).isdisjoint(frozenset([3, 4]));
    disj_no: bool = frozenset([1, 2]).isdisjoint(frozenset([2, 3]));

    or_op: list = sorted(list(a | b));
    and_op: list = sorted(list(a & b));
    sub_op: list = sorted(list(a - b));
    xor_op: list = sorted(list(a ^ b));

    eq_yes: bool = frozenset([1, 2]) == frozenset([1, 2]);
    eq_no: bool = frozenset([1, 2]) == frozenset([1, 3]);
    ne_yes: bool = frozenset([1, 2]) != frozenset([1, 3]);
    ne_no: bool = frozenset([1, 2]) != frozenset([1, 2]);

    le_yes: bool = frozenset([1, 2]) <= frozenset([1, 2, 3]);
    le_eq: bool = frozenset([1, 2]) <= frozenset([1, 2]);
    lt_yes: bool = frozenset([1, 2]) < frozenset([1, 2, 3]);
    lt_no: bool = frozenset([1, 2]) < frozenset([1, 2]);
    ge_yes: bool = frozenset([1, 2, 3]) >= frozenset([1, 2]);
    ge_eq: bool = frozenset([1, 2]) >= frozenset([1, 2]);
    gt_yes: bool = frozenset([1, 2, 3]) > frozenset([1, 2]);
    gt_no: bool = frozenset([1, 2]) > frozenset([1, 2]);

    return {
        "copy": copy_a,
        "union": union, "intersection": intersection,
        "difference": difference, "sym_diff": sym_diff,
        "sub_yes": sub_yes, "sub_no": sub_no,
        "super_yes": super_yes, "super_no": super_no,
        "disj_yes": disj_yes, "disj_no": disj_no,
        "or_op": or_op, "and_op": and_op,
        "sub_op": sub_op, "xor_op": xor_op,
        "eq_yes": eq_yes, "eq_no": eq_no,
        "ne_yes": ne_yes, "ne_no": ne_no,
        "le_yes": le_yes, "le_eq": le_eq,
        "lt_yes": lt_yes, "lt_no": lt_no,
        "ge_yes": ge_yes, "ge_eq": ge_eq,
        "gt_yes": gt_yes, "gt_no": gt_no
    };
}
