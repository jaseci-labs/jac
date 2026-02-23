"""Dict clear and copy primitives.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def dict_copy_py() -> dict {
    # Test clear
    d1: dict[str, int] = {"x": 10, "y": 20};
    d1.clear();
    # Test copy
    d2: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    d3: dict[str, int] = d2.copy();
    # Modify original to prove independence
    d2["a"] = 999;
    return {
        "clear_len": len(d1),
        "copy_len": len(d3),
        "copy_a": d3["a"],
        "copy_b": d3["b"],
        "copy_c": d3["c"],
        "orig_modified": d2["a"]
    };
}

na {
    def dict_copy_na() -> dict[str, any] {
        # Test clear
        d1: dict[str, int] = {"x": 10, "y": 20};
        d1.clear();
        # Test copy
        d2: dict[str, int] = {"a": 1, "b": 2, "c": 3};
        d3: dict[str, int] = d2.copy();
        # Modify original to prove independence
        d2["a"] = 999;
        return {
            "clear_len": len(d1),
            "copy_len": len(d3),
            "copy_a": d3["a"],
            "copy_b": d3["b"],
            "copy_c": d3["c"],
            "orig_modified": d2["a"]
        };
    }
}
