"""Fixture for W2085: Walker has no visit statements."""

walker UselessWalker {
    can do_nothing with `root entry {
        print("I do nothing");
        # No visit statements!  # <-- Warning W2085
    }
}

walker GoodWalker {
    can traverse with `root entry {
        visit [-->];  # <-- Ok: has visit
    }
}
