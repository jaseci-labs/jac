def foo;

impl foo{
    print("foo");
}

obj out {
    has cnt: int;

    def bar;
    def baz;
}

impl out.bar{
    print("bar");
}

impl out.baz{
    print("baz");
}

with entry {
    foo();
    new = out();
    new.cnt;
    out(1).bar();
}
