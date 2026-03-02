"""List multiplication: list * int (repetition).

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def list_mul_py() -> dict {
    a: list[int] = [1, 2, 3];
    r3: list[int] = a * 3;
    r1: list[int] = a * 1;
    r0: list[int] = a * 0;
    r_rev: list[int] = 2 * a;

    return {
        "r3_len": len(r3),
        "r3_0": r3[0], "r3_1": r3[1], "r3_2": r3[2],
        "r3_3": r3[3], "r3_4": r3[4], "r3_5": r3[5],
        "r3_6": r3[6], "r3_7": r3[7], "r3_8": r3[8],
        "r1_len": len(r1), "r1_0": r1[0],
        "r0_len": len(r0),
        "r_rev_len": len(r_rev),
        "r_rev_0": r_rev[0], "r_rev_3": r_rev[3],
        "orig_len": len(a)
    };
}

na {
    def list_mul_na() -> dict[str, any] {
        a: list[int] = [1, 2, 3];
        r3: list[int] = a * 3;
        r1: list[int] = a * 1;
        r0: list[int] = a * 0;
        r_rev: list[int] = 2 * a;

        return {
            "r3_len": len(r3),
            "r3_0": r3[0], "r3_1": r3[1], "r3_2": r3[2],
            "r3_3": r3[3], "r3_4": r3[4], "r3_5": r3[5],
            "r3_6": r3[6], "r3_7": r3[7], "r3_8": r3[8],
            "r1_len": len(r1), "r1_0": r1[0],
            "r0_len": len(r0),
            "r_rev_len": len(r_rev),
            "r_rev_0": r_rev[0], "r_rev_3": r_rev[3],
            "orig_len": len(a)
        };
    }
}
