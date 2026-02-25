"""List remove primitive.

Cross-backend equivalence fixture -- Python reference + native implementation.
Tests list.remove() which removes the first occurrence of a value.
"""

def list_remove_py() -> dict {
    a: list[int] = [1, 2, 3, 2, 1];
    a.remove(2);
    b: list[int] = [10, 20, 30];
    b.remove(10);
    c: list[int] = [5, 10, 15];
    c.remove(15);
    return {
        "remove_mid_len": len(a),
        "remove_mid_first": a[0],
        "remove_mid_second": a[1],
        "remove_mid_third": a[2],
        "remove_mid_fourth": a[3],
        "remove_front_len": len(b),
        "remove_front_first": b[0],
        "remove_front_second": b[1],
        "remove_end_len": len(c),
        "remove_end_first": c[0],
        "remove_end_second": c[1]
    };
}

na {
    def list_remove_na() -> dict[str, any] {
        a: list[int] = [1, 2, 3, 2, 1];
        a.remove(2);
        b: list[int] = [10, 20, 30];
        b.remove(10);
        c: list[int] = [5, 10, 15];
        c.remove(15);
        return {
            "remove_mid_len": len(a),
            "remove_mid_first": a[0],
            "remove_mid_second": a[1],
            "remove_mid_third": a[2],
            "remove_mid_fourth": a[3],
            "remove_front_len": len(b),
            "remove_front_first": b[0],
            "remove_front_second": b[1],
            "remove_end_len": len(c),
            "remove_end_first": c[0],
            "remove_end_second": c[1]
        };
    }
}
