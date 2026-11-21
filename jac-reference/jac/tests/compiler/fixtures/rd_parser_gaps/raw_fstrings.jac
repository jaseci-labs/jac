"""Test raw f-string parsing."""

with entry {
    name = "world";
    msg = rf"Hello \n {name}";
    print(msg);
}
