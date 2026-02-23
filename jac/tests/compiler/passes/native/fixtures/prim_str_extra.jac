"""String extra method primitives: title, rfind, ljust, rjust, zfill.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def str_extra_py() -> dict {
    return {
        # title
        "title_basic": "hello world".title(),
        "title_upper": "HELLO WORLD".title(),
        "title_mixed": "hELLO wORLD".title(),
        "title_single": "hello".title(),
        "title_empty": "".title(),
        "title_spaces": "hello  world".title(),
        # rfind
        "rfind_basic": "hello world hello".rfind("hello"),
        "rfind_single": "abcabc".rfind("abc"),
        "rfind_miss": "hello".rfind("xyz"),
        "rfind_start": "hello".rfind("hello"),
        "rfind_empty_sub": "hello".rfind(""),
        # ljust
        "ljust_pad": "hi".ljust(5),
        "ljust_exact": "hello".ljust(5),
        "ljust_nopad": "hello world".ljust(5),
        # rjust
        "rjust_pad": "hi".rjust(5),
        "rjust_exact": "hello".rjust(5),
        "rjust_nopad": "hello world".rjust(5),
        # zfill
        "zfill_pad": "42".zfill(5),
        "zfill_exact": "12345".zfill(5),
        "zfill_nopad": "123456".zfill(5),
        "zfill_neg": "-42".zfill(5),
        "zfill_plus": "+42".zfill(5)
    };
}

na {
    def str_extra_na() -> dict[str, any] {
        return {
            # title
            "title_basic": "hello world".title(),
            "title_upper": "HELLO WORLD".title(),
            "title_mixed": "hELLO wORLD".title(),
            "title_single": "hello".title(),
            "title_empty": "".title(),
            "title_spaces": "hello  world".title(),
            # rfind
            "rfind_basic": "hello world hello".rfind("hello"),
            "rfind_single": "abcabc".rfind("abc"),
            "rfind_miss": "hello".rfind("xyz"),
            "rfind_start": "hello".rfind("hello"),
            "rfind_empty_sub": "hello".rfind(""),
            # ljust
            "ljust_pad": "hi".ljust(5),
            "ljust_exact": "hello".ljust(5),
            "ljust_nopad": "hello world".ljust(5),
            # rjust
            "rjust_pad": "hi".rjust(5),
            "rjust_exact": "hello".rjust(5),
            "rjust_nopad": "hello world".rjust(5),
            # zfill
            "zfill_pad": "42".zfill(5),
            "zfill_exact": "12345".zfill(5),
            "zfill_nopad": "123456".zfill(5),
            "zfill_neg": "-42".zfill(5),
            "zfill_plus": "+42".zfill(5)
        };
    }
}
