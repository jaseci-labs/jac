"""`print` of a str predicate's result, the shape that first showed 1 and 0."""

def show(x: str) {
    print(x.isdigit(), [x.isdigit(), x.isalpha()], (x.isalnum(), 1));
}

with entry {
    print("12".isdigit(), "ab".isdigit(), "".isdigit());
    print("ab".isalpha(), "a1".isalnum(), "  ".isspace());
    print("AB".isupper(), "ab".islower(), "Ab".istitle());
    print("abc".startswith("a"), "abc".endswith("z"), "abc".endswith(("x", "c")));
    show("12");
}
