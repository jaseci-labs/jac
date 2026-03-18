"""Test that root() resolves correctly as a builtin."""

node Item {
    has name: str;
}

with entry {
    # root() explicit call
    r = root();
    print(type(r).__name__);

    # root() in graph operations
    root() ++> Item(name="a");
    root() ++> Item(name="b");
    print(len([root() -->]));
}
