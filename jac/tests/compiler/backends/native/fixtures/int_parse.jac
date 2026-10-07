"""int() over strings, with every base form CPython accepts or refuses."""
def parse(text: str, base: int) -> str {
    try {
        return str(int(text, base));
    } except ValueError {
        return "E";
    }
}

with entry {
    cases: list[str] = [
        "0", "42", "-17", "+8", "  12  ", "\t7\n", "1_000", "1__0", "_1", "1_",
        "007", "00", "0_0", "0x1F", "0X1f", "0o17", "0b1011", "0b_101", "-0x10",
        "0b2", "abc", "", "   ", "12a", "0x", "7fffffffffffffff"
    ];
    out: list[str] = [];
    for text in cases {
        out.append(parse(text, 0));
        out.append(parse(text, 10));
        out.append(parse(text, 16));
        out.append(parse(text, 2));
    }
    print(" ".join(out));
    print(int("36", 36), int("zz", 36), int("777", 8), int("0o777", 8));
}
