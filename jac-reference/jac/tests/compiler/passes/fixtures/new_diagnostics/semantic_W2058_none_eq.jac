"""Fixture for W2058: Comparison with None should use is/is not."""

with entry {
    x: int | None = None;

    if x == None {      # <-- Warning W2058: use 'is' not '=='
        print("none");
    }

    if x != None {      # <-- Warning W2058: use 'is not' not '!='
        print("not none");
    }

    if x is None {      # <-- Ok
        print("none");
    }

    if x is not None {  # <-- Ok
        print("not none");
    }
}
