"""Test unparenthesized lambda with special var ref keyword parameter names."""

with entry {
    a = lambda props: any -> any { return props; };
    print(a("hello"));

    b = lambda root: any -> any { return root; };
    print(b("world"));

    c = lambda here: any -> any { return here; };
    print(c("!"));
}
