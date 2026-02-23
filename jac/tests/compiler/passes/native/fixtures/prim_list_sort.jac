"""List sort primitive.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def list_sort_py() -> dict {
    nums: list[int] = [5, 3, 8, 1, 4, 2, 7, 6];
    nums.sort();
    return {
        "s0": nums[0],
        "s1": nums[1],
        "s2": nums[2],
        "s3": nums[3],
        "s4": nums[4],
        "s5": nums[5],
        "s6": nums[6],
        "s7": nums[7],
        "slen": len(nums)
    };
}

na {
    def list_sort_na() -> dict[str, any] {
        nums: list[int] = [5, 3, 8, 1, 4, 2, 7, 6];
        nums.sort();
        return {
            "s0": nums[0],
            "s1": nums[1],
            "s2": nums[2],
            "s3": nums[3],
            "s4": nums[4],
            "s5": nums[5],
            "s6": nums[6],
            "s7": nums[7],
            "slen": len(nums)
        };
    }
}
