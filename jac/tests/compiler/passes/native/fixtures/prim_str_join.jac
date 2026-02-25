"""String join primitive.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def str_join_py() -> dict {
    words: list[str] = ["hello", "world", "foo"];
    joined: str = "-".join(words);
    comma_joined: str = ", ".join(words);
    empty_sep: str = "".join(words);
    single: list[str] = ["only"];
    single_joined: str = ",".join(single);
    return {
        "joined": joined,
        "comma_joined": comma_joined,
        "empty_sep": empty_sep,
        "single_joined": single_joined
    };
}

na {
    def str_join_na() -> dict[str, any] {
        words: list[str] = ["hello", "world", "foo"];
        joined: str = "-".join(words);
        comma_joined: str = ", ".join(words);
        empty_sep: str = "".join(words);
        single: list[str] = ["only"];
        single_joined: str = ",".join(single);
        return {
            "joined": joined,
            "comma_joined": comma_joined,
            "empty_sep": empty_sep,
            "single_joined": single_joined
        };
    }
}
