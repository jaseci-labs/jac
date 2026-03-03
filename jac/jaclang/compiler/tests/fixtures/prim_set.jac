"""Set emitter: mutation, algebra, operators, in-place assignment.

Cross-backend equivalence fixture.
"""

# --- Set methods, algebra, operators, augmented assignment ---
def set_py() -> dict {
    # set_methods: add, clear, discard, copy
    s1: set[int] = {10, 20, 30};
    s1_len = len(s1);
    s1.add(40);
    s1_add_len = len(s1);
    s1.add(20);
    s1_dup_len = len(s1);

    s2: set[int] = {10, 20, 30};
    s2.clear();
    s2_clear_len = len(s2);

    s3: set[int] = {10, 20, 30};
    s3.discard(20);
    s3_disc_len = len(s3);
    s3_has_10 = 1 if 10 in s3 else 0;
    s3_has_20 = 1 if 20 in s3 else 0;
    s3_has_30 = 1 if 30 in s3 else 0;
    s3.discard(99);
    s3_disc2_len = len(s3);

    s4: set[int] = {10, 20, 30};
    s5: set[int] = s4.copy();
    s5_len = len(s5);
    s5_has_10 = 1 if 10 in s5 else 0;
    s5_has_20 = 1 if 20 in s5 else 0;

    # set_remove: remove and pop
    sr1: set[int] = {10, 20, 30, 40};
    sr1.remove(20);
    sr1_len: int = len(sr1);
    sr1_has_20: int = 1 if 20 in sr1 else 0;
    sr1_has_10: int = 1 if 10 in sr1 else 0;
    sr1_has_30: int = 1 if 30 in sr1 else 0;
    sr1_has_40: int = 1 if 40 in sr1 else 0;
    sr2: set[int] = {42};
    before_len: int = len(sr2);
    popped: int = sr2.pop();
    after_len: int = len(sr2);

    # set_algebra: union, intersection, difference, issubset, issuperset, isdisjoint
    alg_a: set[int] = {1, 2, 3, 4};
    alg_b: set[int] = {3, 4, 5, 6};
    u: set[int] = alg_a.union(alg_b);
    u_len: int = len(u);
    u_has_1: int = 1 if 1 in u else 0;
    u_has_5: int = 1 if 5 in u else 0;
    i_set: set[int] = alg_a.intersection(alg_b);
    i_len: int = len(i_set);
    i_has_3: int = 1 if 3 in i_set else 0;
    i_has_1: int = 1 if 1 in i_set else 0;
    d_set: set[int] = alg_a.difference(alg_b);
    d_len: int = len(d_set);
    d_has_1: int = 1 if 1 in d_set else 0;
    d_has_3: int = 1 if 3 in d_set else 0;
    alg_c: set[int] = {2, 3};
    sub: int = 1 if alg_c.issubset(alg_a) else 0;
    sup: int = 1 if alg_a.issuperset(alg_c) else 0;
    not_sub: int = 1 if alg_a.issubset(alg_c) else 0;
    alg_e: set[int] = {7, 8};
    disj: int = 1 if alg_a.isdisjoint(alg_e) else 0;
    not_disj: int = 1 if alg_a.isdisjoint(alg_b) else 0;

    # set_operators: |, &, -, ^, ==, !=, <=, <, >=, >
    op_a: set[int] = {1, 2, 3, 4};
    op_b: set[int] = {3, 4, 5, 6};
    op_u: set[int] = op_a | op_b;
    op_u_len: int = len(op_u);
    op_u_has_1: int = 1 if 1 in op_u else 0;
    op_u_has_5: int = 1 if 5 in op_u else 0;
    op_i: set[int] = op_a & op_b;
    op_i_len: int = len(op_i);
    op_i_has_3: int = 1 if 3 in op_i else 0;
    op_i_has_1: int = 1 if 1 in op_i else 0;
    op_d: set[int] = op_a - op_b;
    op_d_len: int = len(op_d);
    op_d_has_1: int = 1 if 1 in op_d else 0;
    op_d_has_3: int = 1 if 3 in op_d else 0;
    op_sd: set[int] = op_a ^ op_b;
    op_sd_len: int = len(op_sd);
    op_sd_has_1: int = 1 if 1 in op_sd else 0;
    op_sd_has_3: int = 1 if 3 in op_sd else 0;
    op_sd_has_5: int = 1 if 5 in op_sd else 0;
    c1: set[int] = {1, 2, 3};
    c2: set[int] = {1, 2, 3};
    c3: set[int] = {1, 2};
    c4: set[int] = {1, 2, 3, 4};
    c5: set[int] = {7, 8, 9};
    eq_same: int = 1 if c1 == c2 else 0;
    eq_diff: int = 1 if c1 == c3 else 0;
    ne_same: int = 1 if c1 != c2 else 0;
    ne_diff: int = 1 if c1 != c3 else 0;
    le_sub: int = 1 if c3 <= c1 else 0;
    le_eq: int = 1 if c1 <= c2 else 0;
    le_sup: int = 1 if c1 <= c3 else 0;
    lt_sub: int = 1 if c3 < c1 else 0;
    lt_eq: int = 1 if c1 < c2 else 0;
    ge_sup: int = 1 if c1 >= c3 else 0;
    ge_eq: int = 1 if c1 >= c2 else 0;
    ge_sub: int = 1 if c3 >= c1 else 0;
    gt_sup: int = 1 if c1 > c3 else 0;
    gt_eq: int = 1 if c1 > c2 else 0;

    # set_aug_assign: |=, &=, -=, ^=
    aa_a: set[int] = {1, 2, 3};
    aa_b: set[int] = {3, 4, 5};
    aa_a |= aa_b;
    ior_len: int = len(aa_a);
    ior_has_1: int = 1 if 1 in aa_a else 0;
    ior_has_4: int = 1 if 4 in aa_a else 0;
    ior_has_5: int = 1 if 5 in aa_a else 0;
    aa_c: set[int] = {1, 2, 3, 4};
    aa_d: set[int] = {2, 4, 6};
    aa_c &= aa_d;
    iand_len: int = len(aa_c);
    iand_has_2: int = 1 if 2 in aa_c else 0;
    iand_has_4: int = 1 if 4 in aa_c else 0;
    iand_has_1: int = 1 if 1 in aa_c else 0;
    aa_e: set[int] = {1, 2, 3, 4, 5};
    aa_f: set[int] = {2, 4};
    aa_e -= aa_f;
    isub_len: int = len(aa_e);
    isub_has_1: int = 1 if 1 in aa_e else 0;
    isub_has_2: int = 1 if 2 in aa_e else 0;
    isub_has_3: int = 1 if 3 in aa_e else 0;
    aa_g: set[int] = {1, 2, 3};
    aa_h: set[int] = {2, 3, 4};
    aa_g ^= aa_h;
    ixor_len: int = len(aa_g);
    ixor_has_1: int = 1 if 1 in aa_g else 0;
    ixor_has_2: int = 1 if 2 in aa_g else 0;
    ixor_has_4: int = 1 if 4 in aa_g else 0;

    # set_advanced: symmetric_difference, update, intersection_update, difference_update, symmetric_difference_update
    adv_a: set[int] = {1, 2, 3, 4};
    adv_b: set[int] = {3, 4, 5, 6};
    adv_sd: set[int] = adv_a.symmetric_difference(adv_b);
    adv_sd_len: int = len(adv_sd);
    adv_sd_has_1: int = 1 if 1 in adv_sd else 0;
    adv_sd_has_3: int = 1 if 3 in adv_sd else 0;
    adv_sd_has_5: int = 1 if 5 in adv_sd else 0;
    adv_sd_has_6: int = 1 if 6 in adv_sd else 0;
    adv_c: set[int] = {10, 20};
    adv_d: set[int] = {20, 30, 40};
    adv_c.update(adv_d);
    upd_len: int = len(adv_c);
    upd_has_10: int = 1 if 10 in adv_c else 0;
    upd_has_30: int = 1 if 30 in adv_c else 0;
    upd_has_40: int = 1 if 40 in adv_c else 0;
    adv_e: set[int] = {1, 2, 3, 4, 5};
    adv_f: set[int] = {2, 4, 6};
    adv_e.intersection_update(adv_f);
    iupd_len: int = len(adv_e);
    iupd_has_2: int = 1 if 2 in adv_e else 0;
    iupd_has_4: int = 1 if 4 in adv_e else 0;
    iupd_has_1: int = 1 if 1 in adv_e else 0;
    adv_g: set[int] = {1, 2, 3, 4, 5};
    adv_h: set[int] = {2, 4};
    adv_g.difference_update(adv_h);
    dupd_len: int = len(adv_g);
    dupd_has_1: int = 1 if 1 in adv_g else 0;
    dupd_has_2: int = 1 if 2 in adv_g else 0;
    dupd_has_3: int = 1 if 3 in adv_g else 0;
    dupd_has_5: int = 1 if 5 in adv_g else 0;
    adv_j: set[int] = {1, 2, 3};
    adv_k: set[int] = {2, 3, 4};
    adv_j.symmetric_difference_update(adv_k);
    sdupd_len: int = len(adv_j);
    sdupd_has_1: int = 1 if 1 in adv_j else 0;
    sdupd_has_2: int = 1 if 2 in adv_j else 0;
    sdupd_has_4: int = 1 if 4 in adv_j else 0;

    return {
        "s1_len": s1_len, "s1_add_len": s1_add_len, "s1_dup_len": s1_dup_len,
        "s2_clear_len": s2_clear_len,
        "s3_disc_len": s3_disc_len, "s3_has_10": s3_has_10,
        "s3_has_20": s3_has_20, "s3_has_30": s3_has_30,
        "s3_disc2_len": s3_disc2_len,
        "s5_len": s5_len, "s5_has_10": s5_has_10, "s5_has_20": s5_has_20,
        "remove_len": sr1_len, "remove_has_20": sr1_has_20,
        "remove_has_10": sr1_has_10, "remove_has_30": sr1_has_30,
        "remove_has_40": sr1_has_40,
        "pop_before_len": before_len, "pop_after_len": after_len, "pop_val": popped,
        "u_len": u_len, "u_has_1": u_has_1, "u_has_5": u_has_5,
        "i_len": i_len, "i_has_3": i_has_3, "i_has_1": i_has_1,
        "d_len": d_len, "d_has_1": d_has_1, "d_has_3": d_has_3,
        "sub": sub, "sup": sup, "not_sub": not_sub,
        "disj": disj, "not_disj": not_disj,
        "u_len_op": op_u_len, "u_has_1_op": op_u_has_1, "u_has_5_op": op_u_has_5,
        "i_len_op": op_i_len, "i_has_3_op": op_i_has_3, "i_has_1_op": op_i_has_1,
        "d_len_op": op_d_len, "d_has_1_op": op_d_has_1, "d_has_3_op": op_d_has_3,
        "sd_len": op_sd_len, "sd_has_1": op_sd_has_1, "sd_has_3": op_sd_has_3,
        "sd_has_5": op_sd_has_5,
        "eq_same": eq_same, "eq_diff": eq_diff,
        "ne_same": ne_same, "ne_diff": ne_diff,
        "le_sub": le_sub, "le_eq": le_eq, "le_sup": le_sup,
        "lt_sub": lt_sub, "lt_eq": lt_eq,
        "ge_sup": ge_sup, "ge_eq": ge_eq, "ge_sub": ge_sub,
        "gt_sup": gt_sup, "gt_eq": gt_eq,
        "ior_len": ior_len, "ior_has_1": ior_has_1,
        "ior_has_4": ior_has_4, "ior_has_5": ior_has_5,
        "iand_len": iand_len, "iand_has_2": iand_has_2,
        "iand_has_4": iand_has_4, "iand_has_1": iand_has_1,
        "isub_len": isub_len, "isub_has_1": isub_has_1,
        "isub_has_2": isub_has_2, "isub_has_3": isub_has_3,
        "ixor_len": ixor_len, "ixor_has_1": ixor_has_1,
        "ixor_has_2": ixor_has_2, "ixor_has_4": ixor_has_4,
        "adv_sd_len": adv_sd_len, "adv_sd_has_1": adv_sd_has_1,
        "adv_sd_has_3": adv_sd_has_3, "adv_sd_has_5": adv_sd_has_5,
        "adv_sd_has_6": adv_sd_has_6,
        "upd_len": upd_len, "upd_has_10": upd_has_10,
        "upd_has_30": upd_has_30, "upd_has_40": upd_has_40,
        "iupd_len": iupd_len, "iupd_has_2": iupd_has_2,
        "iupd_has_4": iupd_has_4, "iupd_has_1": iupd_has_1,
        "dupd_len": dupd_len, "dupd_has_1": dupd_has_1,
        "dupd_has_2": dupd_has_2, "dupd_has_3": dupd_has_3,
        "dupd_has_5": dupd_has_5,
        "sdupd_len": sdupd_len, "sdupd_has_1": sdupd_has_1,
        "sdupd_has_2": sdupd_has_2, "sdupd_has_4": sdupd_has_4
    };
}

cl def set_cl() -> dict {
    # set_methods
    s1: set = set([10, 20, 30]);
    s1_len = len(s1);
    s1.add(40);
    s1_add_len = len(s1);
    s1.add(20);
    s1_dup_len = len(s1);

    s2: set = set([10, 20, 30]);
    s2.clear();
    s2_clear_len = len(s2);

    s3: set = set([10, 20, 30]);
    s3.discard(20);
    s3_disc_len = len(s3);
    s3_has_10 = 1 if 10 in s3 else 0;
    s3_has_20 = 1 if 20 in s3 else 0;
    s3_has_30 = 1 if 30 in s3 else 0;
    s3.discard(99);
    s3_disc2_len = len(s3);

    s4: set = set([10, 20, 30]);
    s5: set = s4.copy();
    s5_len = len(s5);
    s5_has_10 = 1 if 10 in s5 else 0;
    s5_has_20 = 1 if 20 in s5 else 0;

    # set_remove
    sr1: set = set([10, 20, 30, 40]);
    sr1.remove(20);
    sr1_len: int = len(sr1);
    sr1_has_20: int = 1 if 20 in sr1 else 0;
    sr1_has_10: int = 1 if 10 in sr1 else 0;
    sr1_has_30: int = 1 if 30 in sr1 else 0;
    sr1_has_40: int = 1 if 40 in sr1 else 0;
    sr2: set = set([42]);
    before_len: int = len(sr2);
    popped: int = sr2.pop();
    after_len: int = len(sr2);

    # set_algebra
    alg_a: set = set([1, 2, 3, 4]);
    alg_b: set = set([3, 4, 5, 6]);
    u: set = alg_a.union(alg_b);
    u_len: int = len(u);
    u_has_1: int = 1 if 1 in u else 0;
    u_has_5: int = 1 if 5 in u else 0;
    i_set: set = alg_a.intersection(alg_b);
    i_len: int = len(i_set);
    i_has_3: int = 1 if 3 in i_set else 0;
    i_has_1: int = 1 if 1 in i_set else 0;
    d_set: set = alg_a.difference(alg_b);
    d_len: int = len(d_set);
    d_has_1: int = 1 if 1 in d_set else 0;
    d_has_3: int = 1 if 3 in d_set else 0;
    alg_c: set = set([2, 3]);
    sub: int = 1 if alg_c.issubset(alg_a) else 0;
    sup: int = 1 if alg_a.issuperset(alg_c) else 0;
    not_sub: int = 1 if alg_a.issubset(alg_c) else 0;
    alg_e: set = set([7, 8]);
    disj: int = 1 if alg_a.isdisjoint(alg_e) else 0;
    not_disj: int = 1 if alg_a.isdisjoint(alg_b) else 0;

    # set_operators
    op_a: set = set([1, 2, 3, 4]);
    op_b: set = set([3, 4, 5, 6]);
    op_u: set = op_a | op_b;
    op_u_len: int = len(op_u);
    op_u_has_1: int = 1 if 1 in op_u else 0;
    op_u_has_5: int = 1 if 5 in op_u else 0;
    op_i: set = op_a & op_b;
    op_i_len: int = len(op_i);
    op_i_has_3: int = 1 if 3 in op_i else 0;
    op_i_has_1: int = 1 if 1 in op_i else 0;
    op_d: set = op_a - op_b;
    op_d_len: int = len(op_d);
    op_d_has_1: int = 1 if 1 in op_d else 0;
    op_d_has_3: int = 1 if 3 in op_d else 0;
    op_sd: set = op_a ^ op_b;
    op_sd_len: int = len(op_sd);
    op_sd_has_1: int = 1 if 1 in op_sd else 0;
    op_sd_has_3: int = 1 if 3 in op_sd else 0;
    op_sd_has_5: int = 1 if 5 in op_sd else 0;
    c1: set = set([1, 2, 3]);
    c2: set = set([1, 2, 3]);
    c3: set = set([1, 2]);
    c4: set = set([1, 2, 3, 4]);
    c5: set = set([7, 8, 9]);
    eq_same: int = 1 if c1 == c2 else 0;
    eq_diff: int = 1 if c1 == c3 else 0;
    ne_same: int = 1 if c1 != c2 else 0;
    ne_diff: int = 1 if c1 != c3 else 0;
    le_sub: int = 1 if c3 <= c1 else 0;
    le_eq: int = 1 if c1 <= c2 else 0;
    le_sup: int = 1 if c1 <= c3 else 0;
    lt_sub: int = 1 if c3 < c1 else 0;
    lt_eq: int = 1 if c1 < c2 else 0;
    ge_sup: int = 1 if c1 >= c3 else 0;
    ge_eq: int = 1 if c1 >= c2 else 0;
    ge_sub: int = 1 if c3 >= c1 else 0;
    gt_sup: int = 1 if c1 > c3 else 0;
    gt_eq: int = 1 if c1 > c2 else 0;

    # set_aug_assign
    aa_a: set = set([1, 2, 3]);
    aa_b: set = set([3, 4, 5]);
    aa_a |= aa_b;
    ior_len: int = len(aa_a);
    ior_has_1: int = 1 if 1 in aa_a else 0;
    ior_has_4: int = 1 if 4 in aa_a else 0;
    ior_has_5: int = 1 if 5 in aa_a else 0;
    aa_c: set = set([1, 2, 3, 4]);
    aa_d: set = set([2, 4, 6]);
    aa_c &= aa_d;
    iand_len: int = len(aa_c);
    iand_has_2: int = 1 if 2 in aa_c else 0;
    iand_has_4: int = 1 if 4 in aa_c else 0;
    iand_has_1: int = 1 if 1 in aa_c else 0;
    aa_e: set = set([1, 2, 3, 4, 5]);
    aa_f: set = set([2, 4]);
    aa_e -= aa_f;
    isub_len: int = len(aa_e);
    isub_has_1: int = 1 if 1 in aa_e else 0;
    isub_has_2: int = 1 if 2 in aa_e else 0;
    isub_has_3: int = 1 if 3 in aa_e else 0;
    aa_g: set = set([1, 2, 3]);
    aa_h: set = set([2, 3, 4]);
    aa_g ^= aa_h;
    ixor_len: int = len(aa_g);
    ixor_has_1: int = 1 if 1 in aa_g else 0;
    ixor_has_2: int = 1 if 2 in aa_g else 0;
    ixor_has_4: int = 1 if 4 in aa_g else 0;

    # set_advanced
    adv_a: set = set([1, 2, 3, 4]);
    adv_b: set = set([3, 4, 5, 6]);
    adv_sd: set = adv_a.symmetric_difference(adv_b);
    adv_sd_len: int = len(adv_sd);
    adv_sd_has_1: int = 1 if 1 in adv_sd else 0;
    adv_sd_has_3: int = 1 if 3 in adv_sd else 0;
    adv_sd_has_5: int = 1 if 5 in adv_sd else 0;
    adv_sd_has_6: int = 1 if 6 in adv_sd else 0;
    adv_c: set = set([10, 20]);
    adv_d: set = set([20, 30, 40]);
    adv_c.update(adv_d);
    upd_len: int = len(adv_c);
    upd_has_10: int = 1 if 10 in adv_c else 0;
    upd_has_30: int = 1 if 30 in adv_c else 0;
    upd_has_40: int = 1 if 40 in adv_c else 0;
    adv_e: set = set([1, 2, 3, 4, 5]);
    adv_f: set = set([2, 4, 6]);
    adv_e.intersection_update(adv_f);
    iupd_len: int = len(adv_e);
    iupd_has_2: int = 1 if 2 in adv_e else 0;
    iupd_has_4: int = 1 if 4 in adv_e else 0;
    iupd_has_1: int = 1 if 1 in adv_e else 0;
    adv_g: set = set([1, 2, 3, 4, 5]);
    adv_h: set = set([2, 4]);
    adv_g.difference_update(adv_h);
    dupd_len: int = len(adv_g);
    dupd_has_1: int = 1 if 1 in adv_g else 0;
    dupd_has_2: int = 1 if 2 in adv_g else 0;
    dupd_has_3: int = 1 if 3 in adv_g else 0;
    dupd_has_5: int = 1 if 5 in adv_g else 0;
    adv_j: set = set([1, 2, 3]);
    adv_k: set = set([2, 3, 4]);
    adv_j.symmetric_difference_update(adv_k);
    sdupd_len: int = len(adv_j);
    sdupd_has_1: int = 1 if 1 in adv_j else 0;
    sdupd_has_2: int = 1 if 2 in adv_j else 0;
    sdupd_has_4: int = 1 if 4 in adv_j else 0;

    return {
        "s1_len": s1_len, "s1_add_len": s1_add_len, "s1_dup_len": s1_dup_len,
        "s2_clear_len": s2_clear_len,
        "s3_disc_len": s3_disc_len, "s3_has_10": s3_has_10,
        "s3_has_20": s3_has_20, "s3_has_30": s3_has_30,
        "s3_disc2_len": s3_disc2_len,
        "s5_len": s5_len, "s5_has_10": s5_has_10, "s5_has_20": s5_has_20,
        "remove_len": sr1_len, "remove_has_20": sr1_has_20,
        "remove_has_10": sr1_has_10, "remove_has_30": sr1_has_30,
        "remove_has_40": sr1_has_40,
        "pop_before_len": before_len, "pop_after_len": after_len, "pop_val": popped,
        "u_len": u_len, "u_has_1": u_has_1, "u_has_5": u_has_5,
        "i_len": i_len, "i_has_3": i_has_3, "i_has_1": i_has_1,
        "d_len": d_len, "d_has_1": d_has_1, "d_has_3": d_has_3,
        "sub": sub, "sup": sup, "not_sub": not_sub,
        "disj": disj, "not_disj": not_disj,
        "u_len_op": op_u_len, "u_has_1_op": op_u_has_1, "u_has_5_op": op_u_has_5,
        "i_len_op": op_i_len, "i_has_3_op": op_i_has_3, "i_has_1_op": op_i_has_1,
        "d_len_op": op_d_len, "d_has_1_op": op_d_has_1, "d_has_3_op": op_d_has_3,
        "sd_len": op_sd_len, "sd_has_1": op_sd_has_1, "sd_has_3": op_sd_has_3,
        "sd_has_5": op_sd_has_5,
        "eq_same": eq_same, "eq_diff": eq_diff,
        "ne_same": ne_same, "ne_diff": ne_diff,
        "le_sub": le_sub, "le_eq": le_eq, "le_sup": le_sup,
        "lt_sub": lt_sub, "lt_eq": lt_eq,
        "ge_sup": ge_sup, "ge_eq": ge_eq, "ge_sub": ge_sub,
        "gt_sup": gt_sup, "gt_eq": gt_eq,
        "ior_len": ior_len, "ior_has_1": ior_has_1,
        "ior_has_4": ior_has_4, "ior_has_5": ior_has_5,
        "iand_len": iand_len, "iand_has_2": iand_has_2,
        "iand_has_4": iand_has_4, "iand_has_1": iand_has_1,
        "isub_len": isub_len, "isub_has_1": isub_has_1,
        "isub_has_2": isub_has_2, "isub_has_3": isub_has_3,
        "ixor_len": ixor_len, "ixor_has_1": ixor_has_1,
        "ixor_has_2": ixor_has_2, "ixor_has_4": ixor_has_4,
        "adv_sd_len": adv_sd_len, "adv_sd_has_1": adv_sd_has_1,
        "adv_sd_has_3": adv_sd_has_3, "adv_sd_has_5": adv_sd_has_5,
        "adv_sd_has_6": adv_sd_has_6,
        "upd_len": upd_len, "upd_has_10": upd_has_10,
        "upd_has_30": upd_has_30, "upd_has_40": upd_has_40,
        "iupd_len": iupd_len, "iupd_has_2": iupd_has_2,
        "iupd_has_4": iupd_has_4, "iupd_has_1": iupd_has_1,
        "dupd_len": dupd_len, "dupd_has_1": dupd_has_1,
        "dupd_has_2": dupd_has_2, "dupd_has_3": dupd_has_3,
        "dupd_has_5": dupd_has_5,
        "sdupd_len": sdupd_len, "sdupd_has_1": sdupd_has_1,
        "sdupd_has_2": sdupd_has_2, "sdupd_has_4": sdupd_has_4
    };
}

na {
    def set_na() -> dict[str, any] {
        # set_methods
        s1: set[int] = {10, 20, 30};
        s1_len: int = len(s1);
        s1.add(40);
        s1_add_len: int = len(s1);
        s1.add(20);
        s1_dup_len: int = len(s1);

        s2: set[int] = {10, 20, 30};
        s2.clear();
        s2_clear_len: int = len(s2);

        s3: set[int] = {10, 20, 30};
        s3.discard(20);
        s3_disc_len: int = len(s3);
        s3_has_10 = 1 if 10 in s3 else 0;
        s3_has_20 = 1 if 20 in s3 else 0;
        s3_has_30 = 1 if 30 in s3 else 0;
        s3.discard(99);
        s3_disc2_len: int = len(s3);

        s4: set[int] = {10, 20, 30};
        s5: set[int] = s4.copy();
        s5_len: int = len(s5);
        s5_has_10 = 1 if 10 in s5 else 0;
        s5_has_20 = 1 if 20 in s5 else 0;

        # set_remove
        sr1: set[int] = {10, 20, 30, 40};
        sr1.remove(20);
        sr1_len: int = len(sr1);
        sr1_has_20: int = 1 if 20 in sr1 else 0;
        sr1_has_10: int = 1 if 10 in sr1 else 0;
        sr1_has_30: int = 1 if 30 in sr1 else 0;
        sr1_has_40: int = 1 if 40 in sr1 else 0;
        sr2: set[int] = {42};
        before_len: int = len(sr2);
        popped: int = sr2.pop();
        after_len: int = len(sr2);

        # set_algebra
        alg_a: set[int] = {1, 2, 3, 4};
        alg_b: set[int] = {3, 4, 5, 6};
        u: set[int] = alg_a.union(alg_b);
        u_len: int = len(u);
        u_has_1: int = 1 if 1 in u else 0;
        u_has_5: int = 1 if 5 in u else 0;
        i_set: set[int] = alg_a.intersection(alg_b);
        i_len: int = len(i_set);
        i_has_3: int = 1 if 3 in i_set else 0;
        i_has_1: int = 1 if 1 in i_set else 0;
        d_set: set[int] = alg_a.difference(alg_b);
        d_len: int = len(d_set);
        d_has_1: int = 1 if 1 in d_set else 0;
        d_has_3: int = 1 if 3 in d_set else 0;
        alg_c: set[int] = {2, 3};
        sub: int = 1 if alg_c.issubset(alg_a) else 0;
        sup: int = 1 if alg_a.issuperset(alg_c) else 0;
        not_sub: int = 1 if alg_a.issubset(alg_c) else 0;
        alg_e: set[int] = {7, 8};
        disj: int = 1 if alg_a.isdisjoint(alg_e) else 0;
        not_disj: int = 1 if alg_a.isdisjoint(alg_b) else 0;

        # set_operators
        op_a: set[int] = {1, 2, 3, 4};
        op_b: set[int] = {3, 4, 5, 6};
        op_u: set[int] = op_a | op_b;
        op_u_len: int = len(op_u);
        op_u_has_1: int = 1 if 1 in op_u else 0;
        op_u_has_5: int = 1 if 5 in op_u else 0;
        op_i: set[int] = op_a & op_b;
        op_i_len: int = len(op_i);
        op_i_has_3: int = 1 if 3 in op_i else 0;
        op_i_has_1: int = 1 if 1 in op_i else 0;
        op_d: set[int] = op_a - op_b;
        op_d_len: int = len(op_d);
        op_d_has_1: int = 1 if 1 in op_d else 0;
        op_d_has_3: int = 1 if 3 in op_d else 0;
        op_sd: set[int] = op_a ^ op_b;
        op_sd_len: int = len(op_sd);
        op_sd_has_1: int = 1 if 1 in op_sd else 0;
        op_sd_has_3: int = 1 if 3 in op_sd else 0;
        op_sd_has_5: int = 1 if 5 in op_sd else 0;
        c1: set[int] = {1, 2, 3};
        c2: set[int] = {1, 2, 3};
        c3: set[int] = {1, 2};
        c4: set[int] = {1, 2, 3, 4};
        c5: set[int] = {7, 8, 9};
        eq_same: int = 1 if c1 == c2 else 0;
        eq_diff: int = 1 if c1 == c3 else 0;
        ne_same: int = 1 if c1 != c2 else 0;
        ne_diff: int = 1 if c1 != c3 else 0;
        le_sub: int = 1 if c3 <= c1 else 0;
        le_eq: int = 1 if c1 <= c2 else 0;
        le_sup: int = 1 if c1 <= c3 else 0;
        lt_sub: int = 1 if c3 < c1 else 0;
        lt_eq: int = 1 if c1 < c2 else 0;
        ge_sup: int = 1 if c1 >= c3 else 0;
        ge_eq: int = 1 if c1 >= c2 else 0;
        ge_sub: int = 1 if c3 >= c1 else 0;
        gt_sup: int = 1 if c1 > c3 else 0;
        gt_eq: int = 1 if c1 > c2 else 0;

        # set_aug_assign
        aa_a: set[int] = {1, 2, 3};
        aa_b: set[int] = {3, 4, 5};
        aa_a |= aa_b;
        ior_len: int = len(aa_a);
        ior_has_1: int = 1 if 1 in aa_a else 0;
        ior_has_4: int = 1 if 4 in aa_a else 0;
        ior_has_5: int = 1 if 5 in aa_a else 0;
        aa_c: set[int] = {1, 2, 3, 4};
        aa_d: set[int] = {2, 4, 6};
        aa_c &= aa_d;
        iand_len: int = len(aa_c);
        iand_has_2: int = 1 if 2 in aa_c else 0;
        iand_has_4: int = 1 if 4 in aa_c else 0;
        iand_has_1: int = 1 if 1 in aa_c else 0;
        aa_e: set[int] = {1, 2, 3, 4, 5};
        aa_f: set[int] = {2, 4};
        aa_e -= aa_f;
        isub_len: int = len(aa_e);
        isub_has_1: int = 1 if 1 in aa_e else 0;
        isub_has_2: int = 1 if 2 in aa_e else 0;
        isub_has_3: int = 1 if 3 in aa_e else 0;
        aa_g: set[int] = {1, 2, 3};
        aa_h: set[int] = {2, 3, 4};
        aa_g ^= aa_h;
        ixor_len: int = len(aa_g);
        ixor_has_1: int = 1 if 1 in aa_g else 0;
        ixor_has_2: int = 1 if 2 in aa_g else 0;
        ixor_has_4: int = 1 if 4 in aa_g else 0;

        # set_advanced
        adv_a: set[int] = {1, 2, 3, 4};
        adv_b: set[int] = {3, 4, 5, 6};
        adv_sd: set[int] = adv_a.symmetric_difference(adv_b);
        adv_sd_len: int = len(adv_sd);
        adv_sd_has_1: int = 1 if 1 in adv_sd else 0;
        adv_sd_has_3: int = 1 if 3 in adv_sd else 0;
        adv_sd_has_5: int = 1 if 5 in adv_sd else 0;
        adv_sd_has_6: int = 1 if 6 in adv_sd else 0;
        adv_c: set[int] = {10, 20};
        adv_d: set[int] = {20, 30, 40};
        adv_c.update(adv_d);
        upd_len: int = len(adv_c);
        upd_has_10: int = 1 if 10 in adv_c else 0;
        upd_has_30: int = 1 if 30 in adv_c else 0;
        upd_has_40: int = 1 if 40 in adv_c else 0;
        adv_e: set[int] = {1, 2, 3, 4, 5};
        adv_f: set[int] = {2, 4, 6};
        adv_e.intersection_update(adv_f);
        iupd_len: int = len(adv_e);
        iupd_has_2: int = 1 if 2 in adv_e else 0;
        iupd_has_4: int = 1 if 4 in adv_e else 0;
        iupd_has_1: int = 1 if 1 in adv_e else 0;
        adv_g: set[int] = {1, 2, 3, 4, 5};
        adv_h: set[int] = {2, 4};
        adv_g.difference_update(adv_h);
        dupd_len: int = len(adv_g);
        dupd_has_1: int = 1 if 1 in adv_g else 0;
        dupd_has_2: int = 1 if 2 in adv_g else 0;
        dupd_has_3: int = 1 if 3 in adv_g else 0;
        dupd_has_5: int = 1 if 5 in adv_g else 0;
        adv_j: set[int] = {1, 2, 3};
        adv_k: set[int] = {2, 3, 4};
        adv_j.symmetric_difference_update(adv_k);
        sdupd_len: int = len(adv_j);
        sdupd_has_1: int = 1 if 1 in adv_j else 0;
        sdupd_has_2: int = 1 if 2 in adv_j else 0;
        sdupd_has_4: int = 1 if 4 in adv_j else 0;

        return {
            "s1_len": s1_len, "s1_add_len": s1_add_len, "s1_dup_len": s1_dup_len,
            "s2_clear_len": s2_clear_len,
            "s3_disc_len": s3_disc_len, "s3_has_10": s3_has_10,
            "s3_has_20": s3_has_20, "s3_has_30": s3_has_30,
            "s3_disc2_len": s3_disc2_len,
            "s5_len": s5_len, "s5_has_10": s5_has_10, "s5_has_20": s5_has_20,
            "remove_len": sr1_len, "remove_has_20": sr1_has_20,
            "remove_has_10": sr1_has_10, "remove_has_30": sr1_has_30,
            "remove_has_40": sr1_has_40,
            "pop_before_len": before_len, "pop_after_len": after_len, "pop_val": popped,
            "u_len": u_len, "u_has_1": u_has_1, "u_has_5": u_has_5,
            "i_len": i_len, "i_has_3": i_has_3, "i_has_1": i_has_1,
            "d_len": d_len, "d_has_1": d_has_1, "d_has_3": d_has_3,
            "sub": sub, "sup": sup, "not_sub": not_sub,
            "disj": disj, "not_disj": not_disj,
            "u_len_op": op_u_len, "u_has_1_op": op_u_has_1, "u_has_5_op": op_u_has_5,
            "i_len_op": op_i_len, "i_has_3_op": op_i_has_3, "i_has_1_op": op_i_has_1,
            "d_len_op": op_d_len, "d_has_1_op": op_d_has_1, "d_has_3_op": op_d_has_3,
            "sd_len": op_sd_len, "sd_has_1": op_sd_has_1, "sd_has_3": op_sd_has_3,
            "sd_has_5": op_sd_has_5,
            "eq_same": eq_same, "eq_diff": eq_diff,
            "ne_same": ne_same, "ne_diff": ne_diff,
            "le_sub": le_sub, "le_eq": le_eq, "le_sup": le_sup,
            "lt_sub": lt_sub, "lt_eq": lt_eq,
            "ge_sup": ge_sup, "ge_eq": ge_eq, "ge_sub": ge_sub,
            "gt_sup": gt_sup, "gt_eq": gt_eq,
            "ior_len": ior_len, "ior_has_1": ior_has_1,
            "ior_has_4": ior_has_4, "ior_has_5": ior_has_5,
            "iand_len": iand_len, "iand_has_2": iand_has_2,
            "iand_has_4": iand_has_4, "iand_has_1": iand_has_1,
            "isub_len": isub_len, "isub_has_1": isub_has_1,
            "isub_has_2": isub_has_2, "isub_has_3": isub_has_3,
            "ixor_len": ixor_len, "ixor_has_1": ixor_has_1,
            "ixor_has_2": ixor_has_2, "ixor_has_4": ixor_has_4,
            "adv_sd_len": adv_sd_len, "adv_sd_has_1": adv_sd_has_1,
            "adv_sd_has_3": adv_sd_has_3, "adv_sd_has_5": adv_sd_has_5,
            "adv_sd_has_6": adv_sd_has_6,
            "upd_len": upd_len, "upd_has_10": upd_has_10,
            "upd_has_30": upd_has_30, "upd_has_40": upd_has_40,
            "iupd_len": iupd_len, "iupd_has_2": iupd_has_2,
            "iupd_has_4": iupd_has_4, "iupd_has_1": iupd_has_1,
            "dupd_len": dupd_len, "dupd_has_1": dupd_has_1,
            "dupd_has_2": dupd_has_2, "dupd_has_3": dupd_has_3,
            "dupd_has_5": dupd_has_5,
            "sdupd_len": sdupd_len, "sdupd_has_1": sdupd_has_1,
            "sdupd_has_2": sdupd_has_2, "sdupd_has_4": sdupd_has_4
        };
    }
}
