"""Test unparenthesized lambda with special var ref keyword parameter names."""

with entry {
    a = lambda props: Any -> any { return props; };
    print(a("hello"));

    b = lambda root: Any -> any { return root; };
    print(b("world"));

    c = lambda here: Any -> any { return here; };
    print(c("!"));
}
