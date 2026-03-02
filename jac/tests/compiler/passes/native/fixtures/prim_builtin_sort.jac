"""Builtin sorted() and reversed() functions.

Cross-backend equivalence fixture -- Python reference + native implementation.
Note: empty list sort excluded due to unsigned underflow in bubble sort.
"""

def builtin_sort_py() -> dict {
    nums: list[int] = [3, 1, 4, 1, 5, 9, 2, 6];
    desc: list[int] = [5, 4, 3, 2, 1];
    single: list[int] = [42];
    asc: list[int] = [1, 2, 3, 4, 5];

    s_nums: list[int] = sorted(nums);
    s_desc: list[int] = sorted(desc);
    s_single: list[int] = sorted(single);
    s_asc: list[int] = sorted(asc);

    r_nums: list[int] = list(reversed(nums));
    r_desc: list[int] = list(reversed(desc));
    r_single: list[int] = list(reversed(single));

    return {
        # sorted
        "s_len": len(s_nums),
        "s0": s_nums[0], "s1": s_nums[1], "s2": s_nums[2], "s3": s_nums[3],
        "s4": s_nums[4], "s5": s_nums[5], "s6": s_nums[6], "s7": s_nums[7],
        "s_desc0": s_desc[0], "s_desc4": s_desc[4],
        "s_single0": s_single[0],
        "s_asc0": s_asc[0], "s_asc4": s_asc[4],
        # reversed
        "r_len": len(r_nums),
        "r0": r_nums[0], "r7": r_nums[7],
        "r_desc0": r_desc[0], "r_desc4": r_desc[4],
        "r_single0": r_single[0],
        # originals unchanged
        "orig0": nums[0],
        "desc0": desc[0]
    };
}

na {
    def builtin_sort_na() -> dict[str, any] {
        nums: list[int] = [3, 1, 4, 1, 5, 9, 2, 6];
        desc: list[int] = [5, 4, 3, 2, 1];
        single: list[int] = [42];
        asc: list[int] = [1, 2, 3, 4, 5];

        s_nums: list[int] = sorted(nums);
        s_desc: list[int] = sorted(desc);
        s_single: list[int] = sorted(single);
        s_asc: list[int] = sorted(asc);

        r_nums: list[int] = reversed(nums);
        r_desc: list[int] = reversed(desc);
        r_single: list[int] = reversed(single);

        return {
            "s_len": len(s_nums),
            "s0": s_nums[0], "s1": s_nums[1], "s2": s_nums[2], "s3": s_nums[3],
            "s4": s_nums[4], "s5": s_nums[5], "s6": s_nums[6], "s7": s_nums[7],
            "s_desc0": s_desc[0], "s_desc4": s_desc[4],
            "s_single0": s_single[0],
            "s_asc0": s_asc[0], "s_asc4": s_asc[4],
            "r_len": len(r_nums),
            "r0": r_nums[0], "r7": r_nums[7],
            "r_desc0": r_desc[0], "r_desc4": r_desc[4],
            "r_single0": r_single[0],
            "orig0": nums[0],
            "desc0": desc[0]
        };
    }
}
