"""Type hints aren't that much work."""

def foo(a: int, b: str) -> int {  # type hint needed here
    c = a + (b |> int);  # no type hint needed here
    return c;
}

obj Bar {
    has a_list: list[int] = [1, 2, 3],
        b_list: list[str] = ["5", "6", "7"];

    def init -> None {
        for i in self.b_list {
            foo(5, i) |> print;
        }
    }
}
# type hint needed here
