"""Test f-string with nested format spec parsing."""

with entry {
    width = 10;
    value = 3.14;
    msg = f"{value:{width}}";
    print(msg);
}
