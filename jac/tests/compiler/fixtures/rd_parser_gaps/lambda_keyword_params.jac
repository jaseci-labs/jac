"""Test unparenthesized lambda with special var ref keyword parameter names."""

with entry {
    a = lambda props -> Any { return props; };
    print(a("hello"));

    b = lambda root -> Any { return root; };
    print(b("world"));

    c = lambda here -> Any { return here; };
    print(c("!"));
}
