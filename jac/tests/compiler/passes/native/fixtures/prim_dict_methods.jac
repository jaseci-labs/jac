"""Dict method primitives: set, get, contains, len.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def dict_methods_py() -> dict {
    d: dict[str, int] = {"a": 100, "b": 200, "c": 300};
    return {
        "len": len(d),
        "get_a": d["a"],
        "get_b": d["b"],
        "get_c": d["c"]
    };
}

na {
    def dict_methods_na() -> dict[str, any] {
        d: dict[str, int] = {"a": 100, "b": 200, "c": 300};
        return {
            "len": len(d),
            "get_a": d["a"],
            "get_b": d["b"],
            "get_c": d["c"]
        };
    }
}
