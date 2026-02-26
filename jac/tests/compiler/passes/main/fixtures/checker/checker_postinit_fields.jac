obj SomeObj {
    has a: int = 5,
        b: int by postinit,
        c: int by postinit;

    def postinit -> None;
}

impl SomeObj.postinit {
    self.b = self.a * 3;
    self.c = 5 + 6;
}

with entry {
    # This line should NOT trigger a type check error
    ob = SomeObj();
    print(ob.a, ob.b, ob.c);
}
