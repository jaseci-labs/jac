"""Test that root resolves correctly as a special var ref."""

node Item {
    has name: str;
}

with entry {
    # bare root reference
    r = root;
    print(type(r).__name__);

    # root in graph operations
    root ++> Item(name="a");
    root ++> Item(name="b");
    print(len([root -->]));
}
