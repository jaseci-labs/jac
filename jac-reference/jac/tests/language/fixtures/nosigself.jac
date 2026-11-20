obj Foo {
    has a: int = 5;

    def say {
        print(self.a);
    }

    def say2;
}

impl Foo.say2{
    print(self.a);
}

with entry {
    f = Foo();
    f.say();
    f.say2();
}
