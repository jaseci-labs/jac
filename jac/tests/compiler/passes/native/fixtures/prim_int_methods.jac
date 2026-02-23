"""Int method primitives: conjugate, bit_length, bit_count.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def int_methods_py() -> dict {
    return {
        # conjugate
        "conjugate_pos": (42).conjugate(),
        "conjugate_neg": (-7).conjugate(),
        "conjugate_zero": (0).conjugate(),
        # bit_length
        "bitlen_0": (0).bit_length(),
        "bitlen_1": (1).bit_length(),
        "bitlen_2": (2).bit_length(),
        "bitlen_3": (3).bit_length(),
        "bitlen_255": (255).bit_length(),
        "bitlen_256": (256).bit_length(),
        "bitlen_neg1": (-1).bit_length(),
        "bitlen_neg128": (-128).bit_length(),
        # bit_count
        "bitcnt_0": (0).bit_count(),
        "bitcnt_1": (1).bit_count(),
        "bitcnt_7": (7).bit_count(),
        "bitcnt_255": (255).bit_count(),
        "bitcnt_256": (256).bit_count(),
        "bitcnt_neg1": (-1).bit_count(),
        "bitcnt_neg7": (-7).bit_count()
    };
}

na {
    def int_methods_na() -> dict[str, any] {
        return {
            # conjugate
            "conjugate_pos": (42).conjugate(),
            "conjugate_neg": (-7).conjugate(),
            "conjugate_zero": (0).conjugate(),
            # bit_length
            "bitlen_0": (0).bit_length(),
            "bitlen_1": (1).bit_length(),
            "bitlen_2": (2).bit_length(),
            "bitlen_3": (3).bit_length(),
            "bitlen_255": (255).bit_length(),
            "bitlen_256": (256).bit_length(),
            "bitlen_neg1": (-1).bit_length(),
            "bitlen_neg128": (-128).bit_length(),
            # bit_count
            "bitcnt_0": (0).bit_count(),
            "bitcnt_1": (1).bit_count(),
            "bitcnt_7": (7).bit_count(),
            "bitcnt_255": (255).bit_count(),
            "bitcnt_256": (256).bit_count(),
            "bitcnt_neg1": (-1).bit_count(),
            "bitcnt_neg7": (-7).bit_count()
        };
    }
}
