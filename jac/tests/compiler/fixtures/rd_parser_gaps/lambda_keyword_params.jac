"""Test unparenthesized lambda with special var ref keyword parameter names."""

with entry {
    a = lambda props: Any -> Any { return props; };
    print(a("hello"));

    b = lambda root: Any -> Any { return root; };
    print(b("world"));

    c = lambda here: Any -> Any { return here; };
    print(c("!"));
}
