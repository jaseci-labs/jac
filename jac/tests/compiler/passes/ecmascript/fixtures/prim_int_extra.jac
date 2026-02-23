"""Int method primitives not covered by prim_numeric / prim_jac_runtime.

Covers: as_integer_ratio, conjugate, to_bytes, from_bytes.
"""

def int_extra_py() -> dict {
    n: int = 42;

    # as_integer_ratio — returns (n, 1) for integers
    ratio: tuple = n.as_integer_ratio();
    ratio_list: list = list(ratio);

    # conjugate — identity for integers
    conj: int = n.conjugate();

    # to_bytes — returns bytes, convert to list for JSON
    tb_big: list = list((1024).to_bytes(2, "big"));
    tb_little: list = list((1024).to_bytes(2, "little"));
    tb_zero: list = list((0).to_bytes(1, "big"));
    tb_255: list = list((255).to_bytes(1, "big"));

    # from_bytes — static method
    fb_big: int = int.from_bytes([4, 0], "big");
    fb_little: int = int.from_bytes([0, 4], "big");
    fb_single: int = int.from_bytes([255], "big");

    return {
        "ratio": ratio_list,
        "conj": conj,
        "tb_big": tb_big, "tb_little": tb_little,
        "tb_zero": tb_zero, "tb_255": tb_255,
        "fb_big": fb_big, "fb_little": fb_little,
        "fb_single": fb_single
    };
}

cl def int_extra_cl() -> dict {
    n: int = 42;

    ratio: tuple = n.as_integer_ratio();
    ratio_list: list = list(ratio);

    conj: int = n.conjugate();

    tb_big: list = list((1024).to_bytes(2, "big"));
    tb_little: list = list((1024).to_bytes(2, "little"));
    tb_zero: list = list((0).to_bytes(1, "big"));
    tb_255: list = list((255).to_bytes(1, "big"));

    fb_big: int = int.from_bytes([4, 0], "big");
    fb_little: int = int.from_bytes([0, 4], "big");
    fb_single: int = int.from_bytes([255], "big");

    return {
        "ratio": ratio_list,
        "conj": conj,
        "tb_big": tb_big, "tb_little": tb_little,
        "tb_zero": tb_zero, "tb_255": tb_255,
        "fb_big": fb_big, "fb_little": fb_little,
        "fb_single": fb_single
    };
}
