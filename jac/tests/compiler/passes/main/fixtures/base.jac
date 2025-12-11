"""Test for base classes."""

import from impl.imps { test_glob as mine }
# import impl.imps;
obj Test {
    def init;
    def say_hi;
}

with entry {
    print(f"{mine}");
}
