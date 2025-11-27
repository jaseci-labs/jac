obj SomeObj {
    has a: int = 5,
        b: int by postinit;

    def postinit {
        self.b = self.a * 3;
    }
}

with entry {
    ob = SomeObj();
    print(ob.a, ob.b);
}
