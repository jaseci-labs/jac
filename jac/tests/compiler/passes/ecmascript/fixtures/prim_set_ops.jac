"""Set method and operator primitives not covered by prim_jac_runtime.

Covers: add, discard, pop, clear, copy, union, intersection, difference,
symmetric_difference, issubset, issuperset, isdisjoint,
op_or, op_and, op_sub, op_xor, op_contains, op_le, op_ge,
op_ior, op_iand, op_isub, op_ixor.

All set results converted to sorted(list(...)) for JSON serialization.
Note: cl def versions use set([...]) constructor for proper type dispatch.
"""

# ---- Mutation methods ----

def set_mutation_py() -> dict {
    # add
    s1 = {1, 2, 3};
    s1.add(4);
    after_add: list = sorted(list(s1));

    # discard (no error if missing)
    s2 = {1, 2, 3};
    s2.discard(2);
    s2.discard(99);
    after_discard: list = sorted(list(s2));

    # pop (use single-element set for determinism)
    s3 = {42};
    popped: int = s3.pop();
    after_pop: list = sorted(list(s3));

    # clear
    s4 = {1, 2, 3};
    s4.clear();
    after_clear: list = sorted(list(s4));

    # copy
    s5 = {10, 20, 30};
    s5_copy: list = sorted(list(s5.copy()));

    return {
        "after_add": after_add,
        "after_discard": after_discard,
        "popped": popped, "after_pop": after_pop,
        "after_clear": after_clear,
        "copy": s5_copy
    };
}

cl def set_mutation_cl() -> dict {
    s1 = set([1, 2, 3]);
    s1.add(4);
    after_add: list = sorted(list(s1));

    s2 = set([1, 2, 3]);
    s2.discard(2);
    s2.discard(99);
    after_discard: list = sorted(list(s2));

    s3 = set([42]);
    popped: int = s3.pop();
    after_pop: list = sorted(list(s3));

    s4 = set([1, 2, 3]);
    s4.clear();
    after_clear: list = sorted(list(s4));

    s5 = set([10, 20, 30]);
    s5_copy: list = sorted(list(s5.copy()));

    return {
        "after_add": after_add,
        "after_discard": after_discard,
        "popped": popped, "after_pop": after_pop,
        "after_clear": after_clear,
        "copy": s5_copy
    };
}

# ---- Set algebra methods ----

def set_algebra_py() -> dict {
    a = {1, 2, 3, 4};
    b = {3, 4, 5, 6};

    union: list = sorted(list(a.union(b)));
    intersection: list = sorted(list(a.intersection(b)));
    difference: list = sorted(list(a.difference(b)));
    sym_diff: list = sorted(list(a.symmetric_difference(b)));

    # subset / superset / disjoint
    sub_yes: bool = {1, 2}.issubset({1, 2, 3});
    sub_no: bool = {1, 4}.issubset({1, 2, 3});
    super_yes: bool = {1, 2, 3}.issuperset({1, 2});
    super_no: bool = {1, 2}.issuperset({1, 2, 3});
    disj_yes: bool = {1, 2}.isdisjoint({3, 4});
    disj_no: bool = {1, 2}.isdisjoint({2, 3});

    return {
        "union": union, "intersection": intersection,
        "difference": difference, "sym_diff": sym_diff,
        "sub_yes": sub_yes, "sub_no": sub_no,
        "super_yes": super_yes, "super_no": super_no,
        "disj_yes": disj_yes, "disj_no": disj_no
    };
}

cl def set_algebra_cl() -> dict {
    a = set([1, 2, 3, 4]);
    b = set([3, 4, 5, 6]);

    union: list = sorted(list(a.union(b)));
    intersection: list = sorted(list(a.intersection(b)));
    difference: list = sorted(list(a.difference(b)));
    sym_diff: list = sorted(list(a.symmetric_difference(b)));

    sub_yes: bool = set([1, 2]).issubset(set([1, 2, 3]));
    sub_no: bool = set([1, 4]).issubset(set([1, 2, 3]));
    super_yes: bool = set([1, 2, 3]).issuperset(set([1, 2]));
    super_no: bool = set([1, 2]).issuperset(set([1, 2, 3]));
    disj_yes: bool = set([1, 2]).isdisjoint(set([3, 4]));
    disj_no: bool = set([1, 2]).isdisjoint(set([2, 3]));

    return {
        "union": union, "intersection": intersection,
        "difference": difference, "sym_diff": sym_diff,
        "sub_yes": sub_yes, "sub_no": sub_no,
        "super_yes": super_yes, "super_no": super_no,
        "disj_yes": disj_yes, "disj_no": disj_no
    };
}

# ---- Set operators ----

def set_operators_py() -> dict {
    a = {1, 2, 3, 4};
    b = {3, 4, 5, 6};

    # binary operators
    or_op: list = sorted(list(a | b));
    and_op: list = sorted(list(a & b));
    sub_op: list = sorted(list(a - b));
    xor_op: list = sorted(list(a ^ b));

    # contains
    in_yes: bool = 2 in a;
    in_no: bool = 9 in a;

    # subset/superset via <= >=
    le_yes: bool = {1, 2} <= {1, 2, 3};
    le_eq: bool = {1, 2} <= {1, 2};
    le_no: bool = {1, 4} <= {1, 2, 3};
    ge_yes: bool = {1, 2, 3} >= {1, 2};
    ge_eq: bool = {1, 2} >= {1, 2};
    ge_no: bool = {1, 2} >= {1, 2, 3};

    # augmented assignment
    s1 = {1, 2, 3};
    s1 |= {4, 5};
    ior: list = sorted(list(s1));

    s2 = {1, 2, 3, 4};
    s2 &= {2, 3, 5};
    iand: list = sorted(list(s2));

    s3 = {1, 2, 3, 4};
    s3 -= {2, 4};
    isub: list = sorted(list(s3));

    s4 = {1, 2, 3};
    s4 ^= {2, 3, 4};
    ixor: list = sorted(list(s4));

    return {
        "or_op": or_op, "and_op": and_op,
        "sub_op": sub_op, "xor_op": xor_op,
        "in_yes": in_yes, "in_no": in_no,
        "le_yes": le_yes, "le_eq": le_eq, "le_no": le_no,
        "ge_yes": ge_yes, "ge_eq": ge_eq, "ge_no": ge_no,
        "ior": ior, "iand": iand,
        "isub": isub, "ixor": ixor
    };
}

cl def set_operators_cl() -> dict {
    a = set([1, 2, 3, 4]);
    b = set([3, 4, 5, 6]);

    or_op: list = sorted(list(a | b));
    and_op: list = sorted(list(a & b));
    sub_op: list = sorted(list(a - b));
    xor_op: list = sorted(list(a ^ b));

    in_yes: bool = 2 in a;
    in_no: bool = 9 in a;

    le_yes: bool = set([1, 2]) <= set([1, 2, 3]);
    le_eq: bool = set([1, 2]) <= set([1, 2]);
    le_no: bool = set([1, 4]) <= set([1, 2, 3]);
    ge_yes: bool = set([1, 2, 3]) >= set([1, 2]);
    ge_eq: bool = set([1, 2]) >= set([1, 2]);
    ge_no: bool = set([1, 2]) >= set([1, 2, 3]);

    s1 = set([1, 2, 3]);
    s1 |= set([4, 5]);
    ior: list = sorted(list(s1));

    s2 = set([1, 2, 3, 4]);
    s2 &= set([2, 3, 5]);
    iand: list = sorted(list(s2));

    s3 = set([1, 2, 3, 4]);
    s3 -= set([2, 4]);
    isub: list = sorted(list(s3));

    s4 = set([1, 2, 3]);
    s4 ^= set([2, 3, 4]);
    ixor: list = sorted(list(s4));

    return {
        "or_op": or_op, "and_op": and_op,
        "sub_op": sub_op, "xor_op": xor_op,
        "in_yes": in_yes, "in_no": in_no,
        "le_yes": le_yes, "le_eq": le_eq, "le_no": le_no,
        "ge_yes": ge_yes, "ge_eq": ge_eq, "ge_no": ge_no,
        "ior": ior, "iand": iand,
        "isub": isub, "ixor": ixor
    };
}
