"""Set remove and pop primitives.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def set_ops_py() -> dict {
    # set.remove
    s1: set[int] = {10, 20, 30, 40};
    s1.remove(20);
    s1_len: int = len(s1);
    s1_has_20: int = 1 if 20 in s1 else 0;
    s1_has_10: int = 1 if 10 in s1 else 0;
    s1_has_30: int = 1 if 30 in s1 else 0;
    s1_has_40: int = 1 if 40 in s1 else 0;
    # set.pop on single-element set (deterministic)
    s2: set[int] = {42};
    before_len: int = len(s2);
    popped: int = s2.pop();
    after_len: int = len(s2);
    return {
        "remove_len": s1_len,
        "remove_has_20": s1_has_20,
        "remove_has_10": s1_has_10,
        "remove_has_30": s1_has_30,
        "remove_has_40": s1_has_40,
        "pop_before_len": before_len,
        "pop_after_len": after_len,
        "pop_val": popped
    };
}

na {
    def set_ops_na() -> dict[str, any] {
        # set.remove
        s1: set[int] = {10, 20, 30, 40};
        s1.remove(20);
        s1_len: int = len(s1);
        s1_has_20: int = 1 if 20 in s1 else 0;
        s1_has_10: int = 1 if 10 in s1 else 0;
        s1_has_30: int = 1 if 30 in s1 else 0;
        s1_has_40: int = 1 if 40 in s1 else 0;
        # set.pop on single-element set (deterministic)
        s2: set[int] = {42};
        before_len: int = len(s2);
        popped: int = s2.pop();
        after_len: int = len(s2);
        return {
            "remove_len": s1_len,
            "remove_has_20": s1_has_20,
            "remove_has_10": s1_has_10,
            "remove_has_30": s1_has_30,
            "remove_has_40": s1_has_40,
            "pop_before_len": before_len,
            "pop_after_len": after_len,
            "pop_val": popped
        };
    }
}
