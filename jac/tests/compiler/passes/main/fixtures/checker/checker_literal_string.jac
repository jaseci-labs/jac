"""Tests for Literal and LiteralString type checking."""

glob ok_str: str = "hello";
glob ok_str2: str = "a" + "b";
glob ok_fstring: str = f"value: {ok_str}";
glob inferred_literal = "inferred";

glob err_literal_to_int: int = "not an int";  # Error: Literal["not an int"] to int

def take_str(s: str) -> str { return s; }
def take_int(n: int) -> int { return n; }

with entry {
    x: str = "literal";
    a = take_str("arg");
    b = take_str(x);

    err1 = take_int("wrong");  # Error: Literal["wrong"] to int param
}
