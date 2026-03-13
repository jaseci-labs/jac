"""Fixture for W3035: Comparison using is with a literal."""

with entry {
    x = 5;
    if x is 5 {           # <-- Warning W3035: use == for literals
        print("five");
    }
    if x is "hello" {     # <-- Warning W3035: use == for literals
        print("hello");
    }
    if x is None {        # <-- Ok: None is a singleton
        print("none");
    }
    if x is True {        # <-- Ok: bool singletons are fine
        print("true");
    }
}
