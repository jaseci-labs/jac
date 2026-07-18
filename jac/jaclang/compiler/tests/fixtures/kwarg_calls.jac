"""Keyword-argument call lowering: out-of-order kwargs and default filling.

Cross-backend equivalence fixture for jaseci-labs/jaseci#6666. Exercises
callee_decl-dependent kwarg reordering and default-arg filling in ES and native
codegen paths.
"""

def _score(a: int, b: int = 2, c: int = 1) -> int {
    return a * 100 + b * 10 + c;
}

def kwarg_py() -> dict {
    return {
        "reorder": _score(c=3, a=1, b=2),
        "defaults_b": _score(a=5),
        "defaults_c": _score(a=4, b=7),
        "positional_kw": _score(6, c=8),
    };
}

cl def kwarg_cl() -> dict {
    def score(a: int, b: int = 2, c: int = 1) -> int {
        return a * 100 + b * 10 + c;
    }
    return {
        "reorder": score(c=3, a=1, b=2),
        "defaults_b": score(a=5),
        "defaults_c": score(a=4, b=7),
        "positional_kw": score(6, c=8),
    };
}

na {
    def _score_na(a: int, b: int = 2, c: int = 1) -> int {
        return a * 100 + b * 10 + c;
    }

    def kwarg_na() -> dict[str, any] {
        return {
            "reorder": _score_na(c=3, a=1, b=2),
            "defaults_b": _score_na(a=5),
            "defaults_c": _score_na(a=4, b=7),
            "positional_kw": _score_na(6, c=8),
        };
    }
}
