"""Test for base classes."""

include impl.imps;
# import impl.imps;
obj Test {
    def init;
    def say_hi;
}

with entry {
    print(f"{test_glob}");
}
