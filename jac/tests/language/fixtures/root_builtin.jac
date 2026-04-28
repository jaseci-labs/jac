"""Test that root resolves correctly as a special var ref and root() remains compatible."""

node Item {
    has name: str;
}

with entry {
    # bare root reference
    r = root;
    print(type(r).__name__);

    # legacy root() call compatibility
    old_r = root();
    print(type(old_r).__name__);

    # root in graph operations, including legacy root()
    root ++> Item(name="a");
    root() ++> Item(name="b");
    print(len([root -->]));
}
