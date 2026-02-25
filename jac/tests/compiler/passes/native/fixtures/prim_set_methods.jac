"""Set method primitives: add, clear, discard, copy, len, contains.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def set_methods_py() -> dict {
    # add + len
    s1: set[int] = {10, 20, 30};
    s1_len = len(s1);
    s1.add(40);
    s1_add_len = len(s1);
    s1.add(20);  # duplicate
    s1_dup_len = len(s1);

    # clear
    s2: set[int] = {10, 20, 30};
    s2.clear();
    s2_clear_len = len(s2);

    # discard
    s3: set[int] = {10, 20, 30};
    s3.discard(20);
    s3_disc_len = len(s3);
    s3_has_10 = 1 if 10 in s3 else 0;
    s3_has_20 = 1 if 20 in s3 else 0;
    s3_has_30 = 1 if 30 in s3 else 0;
    s3.discard(99);  # discard non-existent (no error)
    s3_disc2_len = len(s3);

    # copy
    s4: set[int] = {10, 20, 30};
    s5: set[int] = s4.copy();
    s5_len = len(s5);
    s5_has_10 = 1 if 10 in s5 else 0;
    s5_has_20 = 1 if 20 in s5 else 0;

    return {
        "s1_len": s1_len,
        "s1_add_len": s1_add_len,
        "s1_dup_len": s1_dup_len,
        "s2_clear_len": s2_clear_len,
        "s3_disc_len": s3_disc_len,
        "s3_has_10": s3_has_10,
        "s3_has_20": s3_has_20,
        "s3_has_30": s3_has_30,
        "s3_disc2_len": s3_disc2_len,
        "s5_len": s5_len,
        "s5_has_10": s5_has_10,
        "s5_has_20": s5_has_20
    };
}

na {
    def set_methods_na() -> dict[str, any] {
        # add + len
        s1: set[int] = {10, 20, 30};
        s1_len: int = len(s1);
        s1.add(40);
        s1_add_len: int = len(s1);
        s1.add(20);
        s1_dup_len: int = len(s1);

        # clear
        s2: set[int] = {10, 20, 30};
        s2.clear();
        s2_clear_len: int = len(s2);

        # discard
        s3: set[int] = {10, 20, 30};
        s3.discard(20);
        s3_disc_len: int = len(s3);
        s3_has_10 = 1 if 10 in s3 else 0;
        s3_has_20 = 1 if 20 in s3 else 0;
        s3_has_30 = 1 if 30 in s3 else 0;
        s3.discard(99);
        s3_disc2_len: int = len(s3);

        # copy
        s4: set[int] = {10, 20, 30};
        s5: set[int] = s4.copy();
        s5_len: int = len(s5);
        s5_has_10 = 1 if 10 in s5 else 0;
        s5_has_20 = 1 if 20 in s5 else 0;

        return {
            "s1_len": s1_len,
            "s1_add_len": s1_add_len,
            "s1_dup_len": s1_dup_len,
            "s2_clear_len": s2_clear_len,
            "s3_disc_len": s3_disc_len,
            "s3_has_10": s3_has_10,
            "s3_has_20": s3_has_20,
            "s3_has_30": s3_has_30,
            "s3_disc2_len": s3_disc2_len,
            "s5_len": s5_len,
            "s5_has_10": s5_has_10,
            "s5_has_20": s5_has_20
        };
    }
}
