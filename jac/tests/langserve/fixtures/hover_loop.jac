obj MyString {
    has strings: list[str];
}

obj MyInt {
    has value: int;
}

# Type narrowing in loops
def test_loop_narrowing(expr: MyString | MyInt | None) -> void {
    if isinstance(expr, MyString) {
        # expr narrowed to MyString
        for s in expr.strings {
            # Should not error
            print(s);
        }
        # expr should still be MyString after loop
        print(expr.strings);
    } elif isinstance(expr, MyInt) {
        # expr narrowed to MyInt
        print(expr.value);
    }
}
